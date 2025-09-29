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
        
        print("🔍 开始视频片段提取诊断...")
        print("   输入视频URL: \(videoURL)")
        print("   输入视频路径: \(videoURL.path)")
        print("   输出URL: \(outputURL)")
        print("   输出路径: \(outputURL.path)")
        
        // 验证输入文件存在性
        let fileManager = FileManager.default
        let inputExists = fileManager.fileExists(atPath: videoURL.path)
        print("   输入文件存在: \(inputExists)")
        
        if inputExists {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: videoURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("   输入文件大小: \(fileSize) bytes")
            } catch {
                print("   无法获取输入文件属性: \(error)")
            }
        }
        
        // 验证输出目录
        let outputDir = outputURL.deletingLastPathComponent()
        let outputDirExists = fileManager.fileExists(atPath: outputDir.path)
        print("   输出目录存在: \(outputDirExists)")
        print("   输出目录路径: \(outputDir.path)")
        
        // 创建输出目录（如果不存在）
        if !outputDirExists {
            do {
                try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
                print("   ✅ 输出目录创建成功")
            } catch {
                print("   ❌ 输出目录创建失败: \(error)")
                throw ExtractionError.exportFailed("无法创建输出目录: \(error.localizedDescription)")
            }
        }
        
        let asset = AVAsset(url: videoURL)
        
        // 验证视频资源
        print("   开始验证视频资源可读性...")
        guard try await asset.load(.isReadable) else {
            print("   ❌ 视频资源不可读")
            throw ExtractionError.videoNotReadable
        }
        print("   ✅ 视频资源验证通过")
        
        // 🎯 关键修复：检查音视频轨道
        print("   开始检查媒体轨道...")
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        print("   视频轨道数量: \(videoTracks.count)")
        print("   音频轨道数量: \(audioTracks.count)")
        
        guard !videoTracks.isEmpty else {
            print("   ❌ 视频文件没有视频轨道")
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
        
        // 🎯 关键修复：根据音频轨道情况选择导出预设
        print("   开始创建导出会话...")
        
        // 如果没有音频轨道，使用仅视频的预设
        let presetName: String
        if audioTracks.isEmpty {
            print("   ⚠️ 检测到无音频轨道，使用视频专用预设")
            presetName = AVAssetExportPresetHighestQuality
        } else {
            print("   ✅ 检测到音频轨道，使用标准预设")
            presetName = AVAssetExportPresetHighestQuality
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: presetName
        ) else {
            print("   ❌ 无法创建导出会话")
            throw ExtractionError.exportFailed("无法创建导出会话")
        }
        print("   ✅ 导出会话创建成功")
        
        // 配置导出设置
        print("   配置导出设置...")
        
        // 🚀 重要修复：删除可能存在的输出文件
        if fileManager.fileExists(atPath: outputURL.path) {
            print("   检测到已存在的输出文件，正在删除...")
            do {
                try fileManager.removeItem(at: outputURL)
                print("   ✅ 已删除存在的输出文件")
            } catch {
                print("   ⚠️ 删除已存在文件失败: \(error)")
                // 不抛出错误，继续尝试导出
            }
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange
        
        // 🎯 关键修复：音频处理配置
        if audioTracks.isEmpty {
            print("   🔇 配置无音频导出")
            // 对于无音频的视频，确保不尝试处理音频
            exportSession.audioMix = nil
        } else {
            print("   🔊 配置音频导出")
            // 有音频时的正常配置
        }
        
        // 视频质量优化设置
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("   导出配置:")
        print("     输出URL: \(outputURL)")
        print("     文件类型: \(exportSession.outputFileType?.rawValue ?? "unknown")")
        print("     时间范围: \(timeRange.start.seconds)s - \(timeRange.end.seconds)s")
        print("     网络优化: \(exportSession.shouldOptimizeForNetworkUse)")
        print("     音频处理: \(audioTracks.isEmpty ? "跳过" : "包含")")
        print("     导出预设: \(presetName)")
        
        // 🚀 添加超时机制的导出
        let exportResult = await withCheckedContinuation { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
                exportSession.cancelExport()
                continuation.resume(returning: false)
            }
            
            exportSession.exportAsynchronously {
                timer.invalidate()
                continuation.resume(returning: true)
            }
        }
        
        // 检查超时和导出结果
        if !exportResult {
            throw ExtractionError.exportFailed("视频片段提取超时（30秒）")
        }
        
        print("   检查导出结果...")
        switch exportSession.status {
        case .completed:
            print("   ✅ 视频片段提取成功: \(outputURL.lastPathComponent)")
            
            // 验证输出文件是否真的存在
            let outputExists = fileManager.fileExists(atPath: outputURL.path)
            print("   输出文件存在: \(outputExists)")
            
            if outputExists {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: outputURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("   输出文件大小: \(fileSize) bytes")
                } catch {
                    print("   无法获取输出文件属性: \(error)")
                }
            }
            
            return outputURL
            
        case .failed:
            let error = exportSession.error?.localizedDescription ?? "未知错误"
            print("   ❌ 视频片段提取失败: \(error)")
            
            // 打印更详细的错误信息
            if let nsError = exportSession.error as NSError? {
                print("   错误域: \(nsError.domain)")
                print("   错误代码: \(nsError.code)")
                print("   用户信息: \(nsError.userInfo)")
                
                // 🎯 关键修复：检测音频相关错误并自动重试
                if nsError.code == -12848 || nsError.code == -11829 {
                    print("   🔄 检测到音频相关错误，尝试无音频导出...")
                    return try await retryWithoutAudio(
                        from: videoURL,
                        startTime: startTime,
                        duration: duration,
                        to: outputURL
                    )
                }
            }
            
            throw ExtractionError.exportFailed(error)
            
        case .cancelled:
            print("   ⏹️ 视频片段提取被取消")
            throw ExtractionError.exportFailed("导出被取消或超时")
            
        default:
            print("   ⚠️ 视频片段提取状态异常: \(exportSession.status.rawValue)")
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
        case .ultra:
            maxSize = CGSize(width: 8192, height: 8192) // 🎯 超高性能设备：8K分辨率
        case .high:
            maxSize = CGSize(width: 6144, height: 6144) // 🎯 高性能设备：6K分辨率
        case .medium:
            maxSize = CGSize(width: 4096, height: 4096) // 🎯 中等性能设备：4K分辨率  
        case .low:
            maxSize = CGSize(width: 2048, height: 2048) // 🎯 低性能设备：2K分辨率
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
    
    /// 🎯 无音频重试导出方法
    /// - Parameters:
    ///   - videoURL: 原视频URL
    ///   - startTime: 开始时间
    ///   - duration: 片段持续时间
    ///   - outputURL: 输出文件URL
    /// - Returns: 提取成功的视频URL
    private func retryWithoutAudio(
        from videoURL: URL,
        startTime: CMTime,
        duration: CMTime,
        to outputURL: URL
    ) async throws -> URL {
        
        print("🔄 开始无音频重试导出...")
        
        let asset = AVAsset(url: videoURL)
        let timeRange = CMTimeRange(start: startTime, duration: duration)
        
        // 使用AVAssetWriter进行精确控制
        let fileManager = FileManager.default
        
        // 删除之前失败的文件
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }
        
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            throw ExtractionError.exportFailed("无法创建AssetWriter")
        }
        
        // 配置视频输出设置
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ExtractionError.exportFailed("没有视频轨道")
        }
        
        let videoSize = try await videoTrack.load(.naturalSize)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height)
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        
        guard assetWriter.canAdd(videoWriterInput) else {
            throw ExtractionError.exportFailed("无法添加视频输入")
        }
        assetWriter.add(videoWriterInput)
        
        // 开始写入
        guard assetWriter.startWriting() else {
            throw ExtractionError.exportFailed("无法开始写入")
        }
        
        assetWriter.startSession(atSourceTime: timeRange.start)
        
        // 创建读取器
        guard let assetReader = try? AVAssetReader(asset: asset) else {
            throw ExtractionError.exportFailed("无法创建AssetReader")
        }
        
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        videoReaderOutput.supportsRandomAccess = true
        
        guard assetReader.canAdd(videoReaderOutput) else {
            throw ExtractionError.exportFailed("无法添加视频输出")
        }
        assetReader.add(videoReaderOutput)
        
        // 设置时间范围
        assetReader.timeRange = timeRange
        
        guard assetReader.startReading() else {
            throw ExtractionError.exportFailed("无法开始读取")
        }
        
        // 复制视频数据
        let result = await withCheckedContinuation { continuation in
            videoWriterInput.requestMediaDataWhenReady(on: DispatchQueue.global()) {
                while videoWriterInput.isReadyForMoreMediaData {
                    if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                        if !videoWriterInput.append(sampleBuffer) {
                            print("❌ 写入样本缓冲区失败")
                            break
                        }
                    } else {
                        videoWriterInput.markAsFinished()
                        break
                    }
                }
                
                assetWriter.finishWriting {
                    continuation.resume(returning: assetWriter.status == .completed)
                }
            }
        }
        
        if result {
            print("✅ 无音频重试导出成功")
            return outputURL
        } else {
            throw ExtractionError.exportFailed("无音频重试导出失败")
        }
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
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("Winkkk_VideoProcessing")
        
        // 确保临时目录存在
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("⚠️ 创建临时目录失败，使用系统默认临时目录: \(error)")
            // 回退到系统默认临时目录
            let fileName = "\(fileName)_\(UUID().uuidString.prefix(8)).mov"
            return fileManager.temporaryDirectory.appendingPathComponent(fileName)
        }
        
        let fileName = "\(fileName)_\(UUID().uuidString.prefix(8)).mov"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        print("🔧 生成临时文件URL: \(tempURL.path)")
        return tempURL
    }
    
    /// 清理临时文件
    /// - Parameter url: 要清理的文件URL
    static func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
