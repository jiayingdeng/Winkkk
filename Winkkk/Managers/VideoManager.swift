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

class VideoManager {
    
    // MARK: - Singleton
    static let shared = VideoManager()
    private init() {}
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let persistenceController = PersistenceController.shared
    
    private lazy var backgroundContext: NSManagedObjectContext = {
        return persistenceController.newBackgroundContext()
    }()
    
    // MARK: - Video Loading
    func loadVideos(completion: @escaping (Result<[VideoItem], Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            let request: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
            
            do {
                let videos = try self.backgroundContext.fetch(request)
                
                // 验证文件是否存在，清理无效记录
                let validVideos = videos.filter { video in
                    let exists = self.fileManager.fileExists(atPath: video.filePath.path)
                    if !exists {
                        self.backgroundContext.delete(video)
                    }
                    return exists
                }
                
                // 如果有删除操作，保存上下文
                if validVideos.count != videos.count {
                    try self.backgroundContext.save()
                }
                
                DispatchQueue.main.async {
                    completion(.success(validVideos))
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
                
                // 创建数据库记录
                let videoItem = self.persistenceController.createVideoItem(
                    fileName: fileName,
                    filePath: destinationURL,
                    duration: videoInfo.duration,
                    isFromCamera: false,
                    width: videoInfo.width,
                    height: videoInfo.height,
                    fileSize: destinationURL.fileSize
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
                    fileSize: destinationURL.fileSize
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
            
            // 更新数据库记录
            await MainActor.run {
                videoItem.thumbnailPath = thumbnailURL
                self.persistenceController.save()
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
    case thumbnailGenerationFailed
    case thumbnailSaveFailed
    case insufficientStorage
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidVideoFile:
            return "无效的视频文件"
        case .fileNotFound:
            return "文件不存在"
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
