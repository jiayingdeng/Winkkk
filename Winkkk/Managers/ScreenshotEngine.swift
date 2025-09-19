//
//  ScreenshotEngine.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图引擎 - AVAssetImageGenerator高质量截图功能
//

import AVFoundation
import UIKit
import CoreData
import Photos

class ScreenshotEngine {
    
    // MARK: - Properties
    private let persistenceController = PersistenceController.shared
    private let videoSegmentExtractor = VideoSegmentExtractor()
    private let livePhotoMaker = LivePhotoMaker.shared
    
    // MARK: - Public Methods
    
    /// 从视频中捕获指定时间点的帧
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - time: 捕获时间点
    ///   - completion: 完成回调
    func captureFrame(from videoURL: URL, at time: CMTime, completion: @escaping (Result<UIImage, ScreenshotError>) -> Void) {
        let asset = AVAsset(url: videoURL)
        
        // 检查视频是否有效
        guard asset.isReadable else {
            completion(.failure(.invalidVideo))
            return
        }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        configureImageGenerator(imageGenerator)
        
        // 异步生成图像
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, actualTime, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.generationFailed(error.localizedDescription)))
                } else if let cgImage = cgImage {
                    let image = UIImage(cgImage: cgImage)
                    completion(.success(image))
                } else {
                    completion(.failure(.generationFailed("Unknown error")))
                }
            }
        }
    }
    
    /// 批量捕获多个时间点的帧
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - times: 时间点数组
    ///   - completion: 完成回调，返回图片数组
    func captureFrames(from videoURL: URL, at times: [CMTime], completion: @escaping (Result<[UIImage], ScreenshotError>) -> Void) {
        let asset = AVAsset(url: videoURL)
        
        guard asset.isReadable else {
            completion(.failure(.invalidVideo))
            return
        }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        configureImageGenerator(imageGenerator)
        
        var images: [UIImage] = []
        var processedCount = 0
        let totalCount = times.count
        
        let timeValues = times.map { NSValue(time: $0) }
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: timeValues) { _, cgImage, actualTime, result, error in
            processedCount += 1
            
            if let cgImage = cgImage {
                let image = UIImage(cgImage: cgImage)
                images.append(image)
            }
            
            if processedCount == totalCount {
                DispatchQueue.main.async {
                    if images.isEmpty {
                        completion(.failure(.generationFailed("No images generated")))
                    } else {
                        completion(.success(images))
                    }
                }
            }
        }
    }
    
    /// 捕获帧并保存到数据库
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - time: 捕获时间点
    ///   - videoItem: 关联的视频项目
    ///   - completion: 完成回调
    func captureAndSave(from videoURL: URL, at time: CMTime, for videoItem: VideoItem, completion: @escaping (Result<ScreenshotItem, ScreenshotError>) -> Void) {
        
        captureFrame(from: videoURL, at: time) { [weak self] result in
            switch result {
            case .success(let image):
                self?.saveScreenshot(image, timestamp: time.seconds, for: videoItem, completion: completion)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 配置图像生成器
    /// - Parameter imageGenerator: 图像生成器实例
    private func configureImageGenerator(_ imageGenerator: AVAssetImageGenerator) {
        // 应用视频的首选变换（处理旋转）
        imageGenerator.appliesPreferredTrackTransform = true
        
        // 设置精确的时间容差
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        // 设置最大尺寸以控制内存使用
        let devicePerformance = DeviceInfo.performanceLevel
        let maxSize: CGSize
        
        switch devicePerformance {
        case .high:
            maxSize = CGSize(width: 4096, height: 4096) // 支持4K截图
        case .medium:
            maxSize = CGSize(width: 2048, height: 2048) // 2K截图
        case .low:
            maxSize = CGSize(width: 1280, height: 1280) // HD截图
        }
        
        imageGenerator.maximumSize = maxSize
        
        // 设置视频合成指令（如果需要）
        imageGenerator.apertureMode = .cleanAperture
    }
    
    /// 保存截图到数据库和文件系统
    /// - Parameters:
    ///   - image: 截图图像
    ///   - timestamp: 时间戳
    ///   - videoItem: 关联的视频项目
    ///   - completion: 完成回调
    private func saveScreenshot(_ image: UIImage, timestamp: Double, for videoItem: VideoItem, completion: @escaping (Result<ScreenshotItem, ScreenshotError>) -> Void) {
        
        // 异步保存到后台队列
        persistenceController.performBackgroundTask { context in
            do {
                // 生成文件名和路径
                let fileName = self.generateScreenshotFileName()
                let imageURL = FileManagerHelper.screenshotsDirectory.appendingPathComponent(fileName)
                
                // 保存图片到文件系统
                try self.saveImageToFile(image, at: imageURL)
                
                // 获取图片尺寸和文件大小
                let imageSize = image.size
                let fileSize = imageURL.fileSize
                
                // 在后台上下文中查找对应的video item
                guard let backgroundVideoItem = context.object(with: videoItem.objectID) as? VideoItem else {
                    throw ScreenshotError.saveFailed("Failed to find video item in context")
                }
                
                // 创建截图项目
                let screenshotItem = self.persistenceController.createScreenshotItem(
                    originalImagePath: imageURL,
                    timestamp: timestamp,
                    width: Int32(imageSize.width),
                    height: Int32(imageSize.height),
                    originalFileSize: fileSize,
                    videoSource: backgroundVideoItem
                )
                
                DispatchQueue.main.async {
                    completion(.success(screenshotItem))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.saveFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// 保存图片到文件
    /// - Parameters:
    ///   - image: 要保存的图片
    ///   - url: 保存路径
    /// - Throws: 保存错误
    private func saveImageToFile(_ image: UIImage, at url: URL) throws {
        // 使用JPEG格式保存，质量95%
        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
            throw ScreenshotError.saveFailed("Failed to convert image to JPEG data")
        }
        
        try imageData.write(to: url)
    }
    
    /// 生成截图文件名
    /// - Returns: 唯一的文件名
    private func generateScreenshotFileName() -> String {
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        return "screenshot_\(timestamp)_\(uuid).jpg"
    }
}

// MARK: - Convenience Methods
extension ScreenshotEngine {
    
    /// 获取视频的关键帧时间点
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - count: 需要的帧数量
    ///   - completion: 完成回调，返回时间点数组
    func getKeyFrameTimes(from videoURL: URL, count: Int, completion: @escaping (Result<[CMTime], ScreenshotError>) -> Void) {
        let asset = AVAsset(url: videoURL)
        
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            DispatchQueue.main.async {
                var error: NSError?
                let status = asset.statusOfValue(forKey: "duration", error: &error)
                
                guard status == .loaded else {
                    completion(.failure(.invalidVideo))
                    return
                }
                
                let duration = asset.duration
                guard duration.isValid && duration.value > 0 else {
                    completion(.failure(.invalidVideo))
                    return
                }
                
                var times: [CMTime] = []
                let durationSeconds = duration.seconds
                
                if count == 1 {
                    // 如果只需要一帧，取中间位置
                    let time = CMTime(seconds: durationSeconds * 0.5, preferredTimescale: duration.timescale)
                    times.append(time)
                } else {
                    // 均匀分布多个时间点
                    for i in 0..<count {
                        let percentage = Double(i) / Double(count - 1)
                        let timeSeconds = durationSeconds * percentage
                        let time = CMTime(seconds: timeSeconds, preferredTimescale: duration.timescale)
                        times.append(time)
                    }
                }
                
                completion(.success(times))
            }
        }
    }
    
    /// 批量生成视频预览图
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - thumbnailCount: 缩略图数量
    ///   - size: 缩略图尺寸
    ///   - completion: 完成回调
    func generateVideoThumbnails(from videoURL: URL, count thumbnailCount: Int, size: CGSize, completion: @escaping (Result<[UIImage], ScreenshotError>) -> Void) {
        
        getKeyFrameTimes(from: videoURL, count: thumbnailCount) { [weak self] result in
            switch result {
            case .success(let times):
                self?.captureFrames(from: videoURL, at: times) { captureResult in
                    switch captureResult {
                    case .success(let images):
                        // 调整图片尺寸
                        let resizedImages = images.compactMap { image in
                            image.resize(to: size)
                        }
                        completion(.success(resizedImages))
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 估算截图文件大小
    /// - Parameters:
    ///   - image: 图片
    ///   - quality: JPEG质量
    /// - Returns: 估算的文件大小（字节）
    func estimateFileSize(for image: UIImage, quality: CGFloat) -> Int64 {
        guard let data = image.jpegData(compressionQuality: quality) else {
            return 0
        }
        return Int64(data.count)
    }
}

// MARK: - Error Types
enum ScreenshotError: LocalizedError {
    case invalidVideo
    case generationFailed(String)
    case saveFailed(String)
    case insufficientStorage
    case permissionDenied
    case imageProcessingFailed
    case fileSaveFailed
    case directoryCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "无效的视频文件"
        case .generationFailed(let message):
            return "截图生成失败: \(message)"
        case .saveFailed(let message):
            return "保存截图失败: \(message)"
        case .insufficientStorage:
            return "存储空间不足"
        case .permissionDenied:
            return "权限被拒绝"
        case .imageProcessingFailed:
            return "图片处理失败"
        case .fileSaveFailed:
            return "文件保存失败"
        case .directoryCreationFailed:
            return "目录创建失败"
        }
    }
}

// MARK: - Quality Settings
extension ScreenshotEngine {
    
    enum ScreenshotQuality: CaseIterable {
        case high      // 95% JPEG质量
        case medium    // 85% JPEG质量
        case low       // 70% JPEG质量
        
        var jpegQuality: CGFloat {
            switch self {
            case .high: return 0.95
            case .medium: return 0.85
            case .low: return 0.70
            }
        }
        
        var displayName: String {
            switch self {
            case .high: return "高质量"
            case .medium: return "中等质量"
            case .low: return "低质量"
            }
        }
        
        var maxDimension: CGFloat {
            switch self {
            case .high: return 4096
            case .medium: return 2048
            case .low: return 1280
            }
        }
    }
    
    /// 使用指定质量捕获帧
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - time: 捕获时间点
    ///   - quality: 截图质量
    ///   - completion: 完成回调
    func captureFrame(from videoURL: URL, at time: CMTime, quality: ScreenshotQuality, completion: @escaping (Result<UIImage, ScreenshotError>) -> Void) {
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // 根据质量设置配置
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.maximumSize = CGSize(width: quality.maxDimension, height: quality.maxDimension)
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, actualTime, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.generationFailed(error.localizedDescription)))
                } else if let cgImage = cgImage {
                    let image = UIImage(cgImage: cgImage)
                    completion(.success(image))
                } else {
                    completion(.failure(.generationFailed("Unknown error")))
                }
            }
        }
    }
    
    // MARK: - Live Photo Support
    
    /// 从视频中捕获Live Photo
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - time: 捕获时间点（Live Photo的中心时间）
    ///   - videoItem: 关联的视频项目
    ///   - completion: 完成回调
    func captureLivePhoto(from videoURL: URL, at time: CMTime, for videoItem: VideoItem, completion: @escaping (Result<ScreenshotItem, ScreenshotError>) -> Void) {
        
        Task {
            do {
                // 验证视频是否适合创建Live Photo
                let validation = try await videoSegmentExtractor.validateVideoForLivePhoto(at: videoURL)
                guard validation.isValid else {
                    DispatchQueue.main.async {
                        completion(.failure(.generationFailed(validation.reason ?? "视频不适合创建Live Photo")))
                    }
                    return
                }
                
                // 计算Live Photo的时间范围
                let startTime = max(CMTime.zero, time - CMTime(seconds: LivePhotoConfig.keyPhotoOffset, preferredTimescale: 600))
                let duration = CMTime(seconds: LivePhotoConfig.duration, preferredTimescale: 600)
                
                // 创建临时文件URL
                let tempVideoURL = VideoSegmentExtractor.generateTempURL(for: "livephoto_segment")
                let tempImageURL = VideoSegmentExtractor.generateTempURL(for: "livephoto_cover").appendingPathExtension("jpg")
                
                // 提取视频片段
                let segmentURL = try await videoSegmentExtractor.extractSegment(
                    from: videoURL,
                    startTime: startTime,
                    duration: duration,
                    to: tempVideoURL
                )
                
                // 生成封面帧（Live Photo中心时间）
                let coverTime = CMTime(seconds: LivePhotoConfig.keyPhotoOffset, preferredTimescale: 600)
                let coverImage = try await videoSegmentExtractor.generateCoverFrame(
                    from: segmentURL,
                    at: coverTime
                )
                
                // 保存封面图片
                guard let imageData = coverImage.jpegData(compressionQuality: 0.9) else {
                    throw ScreenshotError.generationFailed("封面图片保存失败")
                }
                try imageData.write(to: tempImageURL)
                
                // 生成配对标识符
                let identifier = UUID().uuidString
                
                // 创建最终存储目录
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let livePhotoDir = documentsDir.appendingPathComponent("LivePhotos")
                
                // 保存Live Photo文件
                let (finalVideoURL, finalImageURL) = try await livePhotoMaker.saveLivePhotoFiles(
                    videoURL: segmentURL,
                    imageURL: tempImageURL,
                    identifier: identifier,
                    to: livePhotoDir
                )
                
                // 清理临时文件
                VideoSegmentExtractor.cleanupTempFile(at: tempVideoURL)
                VideoSegmentExtractor.cleanupTempFile(at: tempImageURL)
                
                // 保存到数据库
                let screenshotItem = try await self.saveLivePhotoToDatabase(
                    imageURL: finalImageURL,
                    videoURL: finalVideoURL,
                    identifier: identifier,
                    timestamp: time.seconds,
                    coverImage: coverImage,
                    videoItem: videoItem
                )
                
                DispatchQueue.main.async {
                    completion(.success(screenshotItem))
                }
                
            } catch {
                DispatchQueue.main.async {
                    if let screenshotError = error as? ScreenshotError {
                        completion(.failure(screenshotError))
                    } else {
                        completion(.failure(.generationFailed(error.localizedDescription)))
                    }
                }
            }
        }
    }
    
    /// 保存Live Photo到数据库
    private func saveLivePhotoToDatabase(
        imageURL: URL,
        videoURL: URL,
        identifier: String,
        timestamp: Double,
        coverImage: UIImage,
        videoItem: VideoItem
    ) async throws -> ScreenshotItem {
        
        return try await withCheckedThrowingContinuation { continuation in
            let context = persistenceController.container.viewContext
            
            context.perform {
                do {
                    let screenshotItem = ScreenshotItem(context: context)
                    screenshotItem.id = UUID()
                    screenshotItem.originalImagePath = imageURL
                    screenshotItem.timestamp = timestamp
                    screenshotItem.createdDate = Date()
                    screenshotItem.enhanceLevel = 0
                    screenshotItem.isEnhanced = false
                    screenshotItem.videoSource = videoItem
                    
                    // Live Photo特有属性
                    screenshotItem.setAsLivePhoto(
                        videoPath: videoURL,
                        identifier: identifier,
                        duration: LivePhotoConfig.duration,
                        keyPhotoOffset: LivePhotoConfig.keyPhotoOffset
                    )
                    
                    // 设置图片尺寸和文件大小
                    screenshotItem.width = Int32(coverImage.size.width)
                    screenshotItem.height = Int32(coverImage.size.height)
                    
                    if let imageData = try? Data(contentsOf: imageURL) {
                        screenshotItem.originalFileSize = Int64(imageData.count)
                    }
                    
                    // 设置会话状态
                    screenshotItem.mode = .livePhoto
                    screenshotItem.status = .original
                    screenshotItem.isSelected = false
                    screenshotItem.selectionOrder = 0
                    
                    try context.save()
                    continuation.resume(returning: screenshotItem)
                    
                } catch {
                    continuation.resume(throwing: ScreenshotError.saveFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// 验证视频是否支持Live Photo创建
    /// - Parameter videoURL: 视频URL
    /// - Returns: 验证结果
    func validateForLivePhoto(videoURL: URL) async -> (isValid: Bool, reason: String?) {
        do {
            let result = try await videoSegmentExtractor.validateVideoForLivePhoto(at: videoURL)
            return (result.isValid, result.reason)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
