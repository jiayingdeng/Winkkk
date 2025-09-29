//
//  VideoManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频管理器 - 本地文件管理和缩略图生成
//

import Foundation
import AVFoundation
import UIKit
import CoreData
import Photos

class VideoManager: NSObject {
    
    // MARK: - Singleton
    static let shared = VideoManager()
    private override init() {}
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let persistenceController = PersistenceController.shared
    
    private lazy var backgroundContext: NSManagedObjectContext = {
        return persistenceController.newBackgroundContext()
    }()
    
    // MARK: - Video Loading
    func loadVideos(completion: @escaping (Result<[VideoItem], Error>) -> Void) {
        // 🔧 修复死锁问题：使用主上下文进行简单查询，避免与NSFetchedResultsController冲突
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let mainContext = PersistenceController.shared.container.viewContext
            let request: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
            
            do {
                let videos = try mainContext.fetch(request)
                print("📱 VideoManager: 从主上下文加载了 \(videos.count) 个视频记录")
                
                // 🔧 不在这里进行孤儿记录清理，避免与NSFetchedResultsController冲突
                // 孤儿记录清理已移到延迟执行的performDeferredCleanup中
                
                completion(.success(videos))
                
            } catch {
                print("❌ VideoManager: 加载视频失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Database Cleanup
    
    // 🆕 检查孤儿记录数量（不执行删除）
    func checkForOrphanRecords(completion: @escaping (Result<Int, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                let request: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
                let allVideos = try self.backgroundContext.fetch(request)
                
                var orphanCount = 0
                for video in allVideos {
                    if !self.fileManager.fileExists(atPath: video.filePath.path) {
                        orphanCount += 1
                        print("🔍 发现孤儿记录: \(video.fileName) (文件不存在: \(video.filePath.path))")
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(orphanCount))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func forceCleanupOrphanRecords(completion: @escaping (Result<Int, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                let request: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
                let allVideos = try self.backgroundContext.fetch(request)
                
                var deletedCount = 0
                for video in allVideos {
                    if !self.fileManager.fileExists(atPath: video.filePath.path) {
                        print("🗑️ 删除孤儿记录: \(video.fileName)")
                        self.backgroundContext.delete(video)
                        deletedCount += 1
                    }
                }
                
                if deletedCount > 0 {
                    try self.backgroundContext.save()
                    
                    // 🔧 修复死锁问题：使用通知而不是强制刷新主上下文
                    // Core Data会自动通过NSPersistentContainer同步上下文变化
                    print("✅ VideoManager: 后台上下文已保存，等待自动同步到主上下文")
                }
                
                DispatchQueue.main.async {
                    completion(.success(deletedCount))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Video Import
    func importVideo(from sourceURL: URL, completion: @escaping (Result<VideoItem, Error>) -> Void) {
        print("📥 VideoManager: 开始导入视频 from \(sourceURL)")
        
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                // 检查源文件是否存在
                guard self.fileManager.fileExists(atPath: sourceURL.path) else {
                    print("❌ VideoManager: 源文件不存在: \(sourceURL.path)")
                    DispatchQueue.main.async {
                        completion(.failure(VideoManagerError.fileNotFound))
                    }
                    return
                }
                
                print("✅ VideoManager: 源文件存在，开始处理")
                
                // 生成目标文件路径
                let fileName = self.generateUniqueFileName(from: sourceURL)
                let destinationURL = FileManagerHelper.videosDirectory.appendingPathComponent(fileName)
                
                print("📂 VideoManager: 目标路径: \(destinationURL)")
                
                // 复制文件
                try self.fileManager.copyItem(at: sourceURL, to: destinationURL)
                print("✅ VideoManager: 文件复制成功")
                
                // 获取视频信息
                let videoInfo = try self.extractVideoInfo(from: destinationURL)
                
                // 🔧 二次确认文件复制成功，避免孤儿记录
                guard self.fileManager.fileExists(atPath: destinationURL.path) else {
                    print("❌ VideoManager: 文件复制后验证失败，文件不存在: \(destinationURL.path)")
                    DispatchQueue.main.async {
                        completion(.failure(VideoManagerError.fileCopyFailed))
                    }
                    return
                }
                
                // 创建数据库记录
                let videoItem = self.persistenceController.createVideoItem(
                    fileName: fileName,
                    filePath: destinationURL,
                    duration: videoInfo.duration,
                    isFromCamera: false,
                    width: videoInfo.width,
                    height: videoInfo.height,
                    fileSize: destinationURL.fileSize,
                    videoSource: VideoSourceType.systemImported.rawValue,
                    exportStatus: ExportStatusType.exported.rawValue  // 系统导入的视频默认已导出
                )
                
                // 异步生成缩略图
                Task {
                    await self.generateThumbnail(for: videoItem)
                }
                
                print("✅ VideoManager: 视频导入完成，数据库记录已创建")
                DispatchQueue.main.async {
                    completion(.success(videoItem))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Video Save (from Camera)
    func saveVideo(from tempURL: URL, completion: @escaping (Result<VideoItem, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                // 生成目标文件路径
                let fileName = FileManagerHelper.generateUniqueFileName(withExtension: "mp4")
                let destinationURL = FileManagerHelper.videosDirectory.appendingPathComponent(fileName)
                
                // 移动文件（从临时位置移动到永久位置）
                try self.fileManager.moveItem(at: tempURL, to: destinationURL)
                
                // 获取视频信息
                let videoInfo = try self.extractVideoInfo(from: destinationURL)
                
                // 创建数据库记录
                let videoItem = self.persistenceController.createVideoItem(
                    fileName: fileName,
                    filePath: destinationURL,
                    duration: videoInfo.duration,
                    isFromCamera: true,
                    width: videoInfo.width,
                    height: videoInfo.height,
                    fileSize: destinationURL.fileSize,
                    videoSource: VideoSourceType.appRecorded.rawValue,
                    exportStatus: ExportStatusType.pending.rawValue  // App录制的视频默认待导出
                )
                
                // 异步生成缩略图
                Task {
                    await self.generateThumbnail(for: videoItem)
                }
                
                DispatchQueue.main.async {
                    completion(.success(videoItem))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Video Deletion
    func deleteVideo(_ videoItem: VideoItem, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                // 删除视频文件
                if self.fileManager.fileExists(atPath: videoItem.filePath.path) {
                    try self.fileManager.removeItem(at: videoItem.filePath)
                }
                
                // 删除缩略图文件
                if let thumbnailPath = videoItem.thumbnailPath,
                   self.fileManager.fileExists(atPath: thumbnailPath.path) {
                    try self.fileManager.removeItem(at: thumbnailPath)
                }
                
                // 删除数据库记录
                self.backgroundContext.delete(videoItem)
                try self.backgroundContext.save()
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Video Information Extraction
    private func extractVideoInfo(from url: URL) throws -> VideoInfo {
        let asset = AVAsset(url: url)
        
        // 获取视频轨道
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoManagerError.invalidVideoFile
        }
        
        // 获取视频尺寸
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let width = Int32(abs(size.width))
        let height = Int32(abs(size.height))
        
        // 获取时长
        let duration = asset.duration.seconds
        
        guard duration.isFinite && duration > 0 else {
            throw VideoManagerError.invalidVideoFile
        }
        
        return VideoInfo(width: width, height: height, duration: duration)
    }
    
    // MARK: - Thumbnail Generation
    func generateThumbnail(for videoItem: VideoItem) async {
        do {
            let thumbnail = try await generateThumbnailImage(from: videoItem.filePath)
            let thumbnailURL = try saveThumbnail(thumbnail, for: videoItem)
            
            // 使用后台上下文更新数据库记录，避免递归保存
            await withCheckedContinuation { continuation in
                backgroundContext.perform { [weak self] in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    // 在后台上下文中找到对应的对象
                    do {
                        let request: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
                        request.predicate = NSPredicate(format: "id == %@", videoItem.id as CVarArg)
                        request.fetchLimit = 1
                        
                        if let bgVideoItem = try self.backgroundContext.fetch(request).first {
                            bgVideoItem.thumbnailPath = thumbnailURL
                            
                            if self.backgroundContext.hasChanges {
                                try self.backgroundContext.save()
                            }
                        }
                    } catch {
                        print("更新缩略图路径失败: \(error)")
                    }
                    
                    continuation.resume()
                }
            }
            
        } catch {
            print("生成缩略图失败: \(error)")
        }
    }
    
    private func generateThumbnailImage(from videoURL: URL, at time: CMTime? = nil) async throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // 配置图像生成器
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.maximumSize = CGSize(width: 300, height: 300) // 限制缩略图大小
        
        // 确定缩略图时间点
        let targetTime: CMTime
        if let time = time {
            targetTime = time
        } else {
            // 默认在视频25%位置生成缩略图
            let duration = try await asset.load(.duration)
            targetTime = CMTime(seconds: duration.seconds * 0.25, preferredTimescale: 600)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: targetTime)]) { _, cgImage, _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let cgImage = cgImage {
                    let image = UIImage(cgImage: cgImage)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: VideoManagerError.thumbnailGenerationFailed)
                }
            }
        }
    }
    
    private func saveThumbnail(_ image: UIImage, for videoItem: VideoItem) throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
            throw VideoManagerError.thumbnailSaveFailed
        }
        
        let fileName = "\(videoItem.id.uuidString)_thumbnail.jpg"
        let thumbnailURL = FileManagerHelper.thumbnailsDirectory.appendingPathComponent(fileName)
        
        try imageData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    // MARK: - Utility Methods
    private func generateUniqueFileName(from sourceURL: URL) -> String {
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        
        return "\(originalName)_\(timestamp)_\(uuid).\(fileExtension)"
    }
    
    // MARK: - Cache Management
    func cleanupCache(completion: @escaping (Result<CacheCleanupResult, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                var deletedVideoSize: Int64 = 0
                var deletedThumbnailSize: Int64 = 0
                var deletedVideoCount = 0
                var deletedThumbnailCount = 0
                
                // 清理无效的视频文件记录
                let videoRequest: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
                let videoItems = try self.backgroundContext.fetch(videoRequest)
                
                for videoItem in videoItems {
                    if !self.fileManager.fileExists(atPath: videoItem.filePath.path) {
                        deletedVideoCount += 1
                        deletedVideoSize += videoItem.fileSize
                        self.backgroundContext.delete(videoItem)
                    }
                }
                
                // 清理孤儿缩略图文件
                let thumbnailsDirectory = FileManagerHelper.thumbnailsDirectory
                let thumbnailFiles = try self.fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: [.fileSizeKey])
                
                let validThumbnailNames = Set(videoItems.compactMap { item in
                    item.thumbnailPath?.lastPathComponent
                })
                
                for thumbnailURL in thumbnailFiles {
                    if !validThumbnailNames.contains(thumbnailURL.lastPathComponent) {
                        deletedThumbnailSize += thumbnailURL.fileSize
                        deletedThumbnailCount += 1
                        try self.fileManager.removeItem(at: thumbnailURL)
                    }
                }
                
                // 保存更改
                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                }
                
                let result = CacheCleanupResult(
                    deletedVideoCount: deletedVideoCount,
                    deletedVideoSize: deletedVideoSize,
                    deletedThumbnailCount: deletedThumbnailCount,
                    deletedThumbnailSize: deletedThumbnailSize
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func getCacheSize(completion: @escaping (Result<CacheSizeInfo, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                let videosSize = FileManagerHelper.sizeOfDirectory(FileManagerHelper.videosDirectory)
                let thumbnailsSize = FileManagerHelper.sizeOfDirectory(FileManagerHelper.thumbnailsDirectory)
                
                let videoRequest: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
                let videoCount = try self.backgroundContext.count(for: videoRequest)
                
                let screenshotRequest: NSFetchRequest<ScreenshotItem> = ScreenshotItem.fetchRequest()
                let screenshotCount = try self.backgroundContext.count(for: screenshotRequest)
                let screenshotsSize = FileManagerHelper.sizeOfDirectory(FileManagerHelper.screenshotsDirectory)
                
                let result = CacheSizeInfo(
                    videoCount: videoCount,
                    videosSize: videosSize,
                    thumbnailsSize: thumbnailsSize,
                    screenshotCount: screenshotCount,
                    screenshotsSize: screenshotsSize,
                    totalSize: videosSize + thumbnailsSize + screenshotsSize
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Export to Photo Library
    func exportToPhotoLibrary(video: VideoItem, completion: @escaping (Result<Void, Error>) -> Void) {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: video.filePath.path) else {
            completion(.failure(VideoManagerError.fileNotFound))
            return
        }
        
        // 使用现代的 PHPhotoLibrary API
        Task {
            do {
                try await checkPhotoLibraryPermission()
                
                // 权限获得，使用现代API执行导出
                try await performVideoExport(video: video)
                
                // 导出成功，更新状态
                await MainActor.run {
                    self.updateVideoExportStatus(video, to: .exported)
                    completion(.success(()))
                }
                
            } catch {
                await MainActor.run {
                    print("❌ 视频导出失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 使用现代PHPhotoLibrary API执行导出
    private func performVideoExport(video: VideoItem) async throws {
        let videoURL = video.filePath
        
        // 验证文件格式兼容性
        try validateVideoForExport(at: videoURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                if success {
                    print("✅ 视频导出成功: \(video.title)")
                    continuation.resume()
                } else {
                    // 根据具体错误类型返回更准确的错误信息
                    let exportError: Error
                    if let phError = error as? PHPhotosError {
                        switch phError.code {
                        case .accessRestricted, .accessUserDenied:
                            exportError = VideoManagerError.exportPermissionDenied
                        case .networkAccessRequired:
                            exportError = VideoManagerError.networkError
                        case .libraryVolumeOffline, .libraryInFileProviderSyncRoot:
                            exportError = VideoManagerError.insufficientStorage
                        default:
                            exportError = VideoManagerError.exportFailed
                        }
                    } else if let nsError = error as? NSError {
                        switch nsError.code {
                        case NSFileReadNoSuchFileError:
                            exportError = VideoManagerError.fileNotFound
                        case NSFileWriteFileExistsError, NSFileWriteVolumeReadOnlyError:
                            exportError = VideoManagerError.insufficientStorage
                        default:
                            exportError = VideoManagerError.exportFailed
                        }
                    } else {
                        exportError = error ?? VideoManagerError.exportFailed
                    }
                    
                    print("❌ 视频导出失败: \(exportError.localizedDescription)")
                    continuation.resume(throwing: exportError)
                }
            }
        }
    }
    
    // 验证视频文件是否适合导出
    private func validateVideoForExport(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoManagerError.fileNotFound
        }
        
        // 检查文件扩展名
        let supportedExtensions = ["mov", "mp4", "m4v", "3gp"]
        let fileExtension = url.pathExtension.lowercased()
        
        guard supportedExtensions.contains(fileExtension) else {
            print("❌ 不支持的视频格式: \(fileExtension)")
            throw VideoManagerError.exportUnsupportedFormat
        }
        
        // 检查文件大小（避免过大的文件导致导出失败）
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                let maxFileSize: Int64 = 2 * 1024 * 1024 * 1024 // 2GB
                if fileSize > maxFileSize {
                    print("❌ 视频文件过大: \(fileSize) bytes")
                    throw VideoManagerError.insufficientStorage
                }
            }
        } catch {
            print("❌ 无法获取文件信息: \(error)")
            throw VideoManagerError.invalidVideoFile
        }
    }
    
    
    // MARK: - Export Status Management
    func updateVideoExportStatus(_ videoItem: VideoItem, to status: ExportStatusType) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            do {
                // 在后台上下文中找到对应的对象
                let request: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", videoItem.id as CVarArg)
                request.fetchLimit = 1
                
                if let bgVideoItem = try self.backgroundContext.fetch(request).first {
                    bgVideoItem.exportStatusType = status
                    
                    if self.backgroundContext.hasChanges {
                        try self.backgroundContext.save()
                        print("✅ 更新视频导出状态为: \(status.displayName)")
                    }
                }
            } catch {
                print("❌ 更新视频导出状态失败: \(error)")
            }
        }
    }
    
    // MARK: - Permission Management
    private func checkPhotoLibraryPermission() async throws {
        // iOS 14.0+ 支持 .addOnly 权限类型
        if #available(iOS 14.0, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            
            switch status {
            case .authorized, .limited:
                return
            case .denied, .restricted:
                throw VideoManagerError.exportPermissionDenied
            case .notDetermined:
                let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                if newStatus != .authorized && newStatus != .limited {
                    throw VideoManagerError.exportPermissionDenied
                }
            @unknown default:
                throw VideoManagerError.exportPermissionDenied
            }
        } else {
            // iOS 13.x 及以下版本的兼容性处理
            let status = PHPhotoLibrary.authorizationStatus()
            
            switch status {
            case .authorized:
                return
            case .denied, .restricted:
                throw VideoManagerError.exportPermissionDenied
            case .notDetermined:
                return try await withCheckedThrowingContinuation { continuation in
                    PHPhotoLibrary.requestAuthorization { newStatus in
                        if newStatus == .authorized {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: VideoManagerError.exportPermissionDenied)
                        }
                    }
                }
            @unknown default:
                throw VideoManagerError.exportPermissionDenied
            }
        }
    }
}


// MARK: - Data Structures
struct VideoInfo {
    let width: Int32
    let height: Int32
    let duration: Double
}



// MARK: - Error Types
enum VideoManagerError: LocalizedError {
    case invalidVideoFile
    case fileNotFound
    case fileCopyFailed
    case thumbnailGenerationFailed
    case thumbnailSaveFailed
    case insufficientStorage
    case networkError
    case permissionDenied
    case exportFailed
    case exportPermissionDenied
    case exportUnsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidVideoFile:
            return "无效的视频文件"
        case .fileNotFound:
            return "文件不存在"
        case .fileCopyFailed:
            return "文件复制失败"
        case .thumbnailGenerationFailed:
            return "缩略图生成失败"
        case .thumbnailSaveFailed:
            return "缩略图保存失败"
        case .insufficientStorage:
            return "存储空间不足"
        case .networkError:
            return "网络错误"
        case .permissionDenied:
            return "权限被拒绝"
        case .exportFailed:
            return "视频导出失败"
        case .exportPermissionDenied:
            return "相册访问权限被拒绝，请在设置中允许访问相册"
        case .exportUnsupportedFormat:
            return "不支持的视频格式"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidVideoFile:
            return "视频文件格式不正确或已损坏"
        case .fileNotFound:
            return "视频文件可能已被删除或移动"
        case .fileCopyFailed:
            return "无法复制视频文件，可能是存储空间不足"
        case .thumbnailGenerationFailed:
            return "无法从视频生成缩略图"
        case .thumbnailSaveFailed:
            return "缩略图保存到磁盘时发生错误"
        case .insufficientStorage:
            return "设备存储空间不足，请清理后重试"
        case .networkError:
            return "网络连接异常，请检查网络设置"
        case .permissionDenied:
            return "应用没有必要的访问权限"
        case .exportFailed:
            return "导出过程中发生未知错误"
        case .exportPermissionDenied:
            return "需要相册访问权限才能保存视频"
        case .exportUnsupportedFormat:
            return "当前视频格式不支持导出到相册"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidVideoFile:
            return "请选择其他视频文件"
        case .fileNotFound:
            return "请重新选择视频文件"
        case .fileCopyFailed, .insufficientStorage:
            return "请清理设备存储空间后重试"
        case .thumbnailGenerationFailed, .thumbnailSaveFailed:
            return "请重启应用后重试"
        case .networkError:
            return "请检查网络连接后重试"
        case .permissionDenied, .exportPermissionDenied:
            return "请在设置-隐私-照片中允许应用访问相册"
        case .exportFailed:
            return "请重试，如问题持续请重启应用"
        case .exportUnsupportedFormat:
            return "请使用其他视频编辑工具转换格式"
        }
    }
}

// MARK: - Extensions
extension VideoManager {
    
    /// 获取支持的视频格式
    static var supportedVideoFormats: [String] {
        return ["mp4", "mov", "m4v", "avi"]
    }
    
    /// 检查文件是否为支持的视频格式
    static func isSupportedVideoFormat(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return supportedVideoFormats.contains(fileExtension)
    }
    
    /// 估算视频文件压缩后的大小
    func estimateCompressedSize(for videoURL: URL, quality: VideoQuality) -> Int64 {
        let originalSize = videoURL.fileSize
        
        switch quality {
        case .high:
            return Int64(Double(originalSize) * 0.8)
        case .medium:
            return Int64(Double(originalSize) * 0.5)
        case .low:
            return Int64(Double(originalSize) * 0.3)
        }
    }
}

enum VideoQuality: CaseIterable {
    case high
    case medium
    case low
    
    var displayName: String {
        switch self {
        case .high: return "高质量"
        case .medium: return "中等质量"
        case .low: return "低质量"
        }
    }
    
    var compressionSettings: [String: Any] {
        switch self {
        case .high:
            return [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 5_000_000
                ]
            ]
        case .medium:
            return [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1280,
                AVVideoHeightKey: 720,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2_500_000
                ]
            ]
        case .low:
            return [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 854,
                AVVideoHeightKey: 480,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 1_000_000
                ]
            ]
        }
    }
}

// MARK: - Cache Management Helper Methods
extension VideoManager {
    
    private func calculateDirectorySize(_ directory: URL) throws -> Int64 {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isRegularFile == true {
                totalSize += Int64(resourceValues.fileAllocatedSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    private func cleanupDirectory(_ directory: URL, keepDirectory: Bool) throws -> (size: Int64, count: Int) {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return (0, 0)
        }
        
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileAllocatedSizeKey], options: [])
        
        var totalSize: Int64 = 0
        var totalCount = 0
        
        for fileURL in contents {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey])
            let fileSize = Int64(resourceValues.fileAllocatedSize ?? 0)
            
            try FileManager.default.removeItem(at: fileURL)
            totalSize += fileSize
            totalCount += 1
        }
        
        if keepDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return (totalSize, totalCount)
    }
}

// MARK: - Cache Data Structures
struct CacheSizeInfo {
    let videoCount: Int
    let videosSize: Int64
    let thumbnailsSize: Int64
    let screenshotCount: Int
    let screenshotsSize: Int64
    let totalSize: Int64
    
    var formattedTotalSize: String {
        return String.formatFileSize(totalSize)
    }
}

struct CacheCleanupResult {
    let deletedVideoCount: Int
    let deletedVideoSize: Int64
    let deletedThumbnailCount: Int
    let deletedThumbnailSize: Int64
    
    var totalDeletedSize: Int64 {
        return deletedVideoSize + deletedThumbnailSize
    }
    
    var totalDeletedCount: Int {
        return deletedVideoCount + deletedThumbnailCount
    }
}
