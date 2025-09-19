//
//  VideoSegmentExtractor.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频片段提取器 - Live Photo支持
//

import AVFoundation
import UIKit
import CoreMedia

/// 视频片段提取器
/// 负责从原视频中提取指定时间段的片段，用于Live Photo创建
class VideoSegmentExtractor {
    
    // MARK: - Error Types
    enum ExtractionError: LocalizedError {
        case invalidVideoURL
        case videoNotReadable
        case exportFailed(String)
        case frameGenerationFailed(String)
        case invalidTimeRange
        case insufficientDuration
        
        var errorDescription: String? {
            switch self {
            case .invalidVideoURL:
                return "无效的视频URL"
            case .videoNotReadable:
                return "视频文件无法读取"
            case .exportFailed(let reason):
                return "视频导出失败: \(reason)"
            case .frameGenerationFailed(let reason):
                return "帧生成失败: \(reason)"
            case .invalidTimeRange:
                return "无效的时间范围"
            case .insufficientDuration:
                return "视频时长不足，无法创建Live Photo"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 从原视频中提取指定时间段的片段
    /// - Parameters:
    ///   - videoURL: 原视频URL
    ///   - startTime: 开始时间
    ///   - duration: 片段持续时间
    ///   - outputURL: 输出文件URL
    /// - Returns: 提取成功的视频URL
    func extractSegment(
        from videoURL: URL,
        startTime: CMTime,
        duration: CMTime,
        to outputURL: URL
    ) async throws -> URL {
        
        let asset = AVAsset(url: videoURL)
        
        // 验证视频资源
        guard try await asset.load(.isReadable) else {
            throw ExtractionError.videoNotReadable
        }
        
        let videoDuration = try await asset.load(.duration)
        
        // 验证时间范围
        let timeRange = CMTimeRange(start: startTime, duration: duration)
        guard timeRange.isValid && CMTimeRangeContainsTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            otherRange: timeRange
        ) else {
            throw ExtractionError.invalidTimeRange
        }
        
        // 创建导出会话
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExtractionError.exportFailed("无法创建导出会话")
        }
        
        // 配置导出设置
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange
        
        // 视频质量优化设置
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 执行导出
        await exportSession.export()
        
        // 检查导出结果
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            let error = exportSession.error?.localizedDescription ?? "未知错误"
            throw ExtractionError.exportFailed(error)
        case .cancelled:
            throw ExtractionError.exportFailed("导出被取消")
        default:
            throw ExtractionError.exportFailed("导出状态异常: \(exportSession.status.rawValue)")
        }
    }
    
    /// 生成高质量的封面帧
    /// - Parameters:
    ///   - videoURL: 视频URL（可以是原视频或片段视频）
    ///   - time: 提取帧的时间点
    /// - Returns: 生成的封面图像
    func generateCoverFrame(from videoURL: URL, at time: CMTime) async throws -> UIImage {
        
        let asset = AVAsset(url: videoURL)
        
        // 验证视频资源
        guard try await asset.load(.isReadable) else {
            throw ExtractionError.videoNotReadable
        }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // 配置高质量生成
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        // 根据设备性能设置最大尺寸
        let devicePerformance = DeviceInfo.performanceLevel
        let maxSize: CGSize
        
        switch devicePerformance {
        case .high:
            maxSize = CGSize(width: 1125, height: 2436) // iPhone屏幕分辨率
        case .medium:
            maxSize = CGSize(width: 828, height: 1792)  // 较低分辨率
        case .low:
            maxSize = CGSize(width: 750, height: 1334)  // 基础分辨率
        }
        
        imageGenerator.maximumSize = maxSize
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            throw ExtractionError.frameGenerationFailed(error.localizedDescription)
        }
    }
    
    /// 批量生成预览帧（用于时间轴预览）
    /// - Parameters:
    ///   - videoURL: 视频URL
    ///   - times: 时间点数组
    /// - Returns: 生成的图像数组
    func generatePreviewFrames(from videoURL: URL, at times: [CMTime]) async throws -> [UIImage] {
        
        let asset = AVAsset(url: videoURL)
        
        guard try await asset.load(.isReadable) else {
            throw ExtractionError.videoNotReadable
        }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        // 预览图使用较小尺寸
        imageGenerator.maximumSize = CGSize(width: 200, height: 200)
        
        var images: [UIImage] = []
        
        for time in times {
            do {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                images.append(UIImage(cgImage: cgImage))
            } catch {
                // 如果某一帧失败，使用空白图像占位
                let placeholderImage = UIImage(systemName: "photo") ?? UIImage()
                images.append(placeholderImage)
            }
        }
        
        return images
    }
    
    /// 验证视频是否适合创建Live Photo
    /// - Parameter videoURL: 视频URL
    /// - Returns: 验证结果和视频信息
    func validateVideoForLivePhoto(at videoURL: URL) async throws -> (isValid: Bool, duration: Double, reason: String?) {
        
        let asset = AVAsset(url: videoURL)
        
        guard try await asset.load(.isReadable) else {
            return (false, 0, "视频文件无法读取")
        }
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // 检查最小时长要求
        if durationSeconds < LivePhotoConfig.minimumVideoDuration {
            return (false, durationSeconds, "视频时长至少需要\(LivePhotoConfig.minimumVideoDuration)秒才能创建Live Photo")
        }
        
        // 检查视频轨道
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            return (false, durationSeconds, "视频文件没有视频轨道")
        }
        
        return (true, durationSeconds, nil)
    }
}

// MARK: - Helper Extensions
extension VideoSegmentExtractor {
    
    /// 生成临时输出URL
    /// - Parameter fileName: 文件名（不含扩展名）
    /// - Returns: 临时文件URL
    static func generateTempURL(for fileName: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(fileName)_\(UUID().uuidString.prefix(8)).mov"
        return tempDir.appendingPathComponent(fileName)
    }
    
    /// 清理临时文件
    /// - Parameter url: 要清理的文件URL
    static func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
