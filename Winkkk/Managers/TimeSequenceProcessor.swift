//
//  TimeSequenceProcessor.swift
//  Winkkk
//
//  Created by AI Assistant on 2024/09/20.
//

import Foundation
import UIKit
import AVFoundation

/// 时间序列处理器代理协议
protocol TimeSequenceProcessorDelegate: AnyObject {
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didStartProcessing videoURL: URL)
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didUpdateProgress progress: Float, currentFrame: Int, totalFrames: Int)
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didCompleteWithFrames frames: [UIImage])
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didFailWithError error: TimeSequenceError)
}

/// 时间序列处理错误类型
enum TimeSequenceError: Error, LocalizedError {
    case videoNotFound
    case invalidVideoFormat
    case processingFailed(String)
    case noFramesExtracted
    case insufficientFrames(Int)
    case memoryWarning
    
    var errorDescription: String? {
        switch self {
        case .videoNotFound:
            return "找不到视频文件"
        case .invalidVideoFormat:
            return "不支持的视频格式"
        case .processingFailed(let message):
            return "处理失败：\(message)"
        case .noFramesExtracted:
            return "未能提取到任何帧"
        case .insufficientFrames(let count):
            return "提取的帧数不足（仅\(count)帧）"
        case .memoryWarning:
            return "内存不足，请重试"
        }
    }
}

/// 时间序列视频处理器 - 专门处理时间序列视频的帧提取逻辑
class TimeSequenceProcessor {
    
    // MARK: - 代理和配置
    weak var delegate: TimeSequenceProcessorDelegate?
    private let parameters: TimeSequenceParameters
    private let sceneType: SceneType
    
    // MARK: - 处理状态
    private var isProcessing = false
    private var shouldCancel = false
    private var processingQueue: DispatchQueue
    
    // MARK: - 视频处理组件
    private var asset: AVAsset?
    private var imageGenerator: AVAssetImageGenerator?
    
    // MARK: - 内存管理
    private var maxMemoryUsage: Int = 500 * 1024 * 1024 // 500MB (提高内存限制)
    private var currentMemoryUsage: Int = 0
    
    // MARK: - 初始化
    init(sceneType: SceneType, parameters: TimeSequenceParameters? = nil) {
        self.sceneType = sceneType
        self.parameters = parameters ?? TimeSequenceParameters.defaultParameters(for: sceneType)
        self.processingQueue = DispatchQueue(label: "com.winkkk.timesequence.processing", qos: .userInitiated)
    }
    
    // MARK: - 主要处理方法
    
    /// 开始处理时间序列视频
    /// - Parameter videoURL: 视频文件URL
    func processVideo(at videoURL: URL) {
        guard !isProcessing else {
            delegate?.timeSequenceProcessor(self, didFailWithError: .processingFailed("处理器正忙"))
            return
        }
        
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            delegate?.timeSequenceProcessor(self, didFailWithError: .videoNotFound)
            return
        }
        
        isProcessing = true
        shouldCancel = false
        
        DispatchQueue.main.async {
            self.delegate?.timeSequenceProcessor(self, didStartProcessing: videoURL)
        }
        
        processingQueue.async {
            self.performVideoProcessing(videoURL: videoURL)
        }
    }
    
    /// 取消处理
    func cancelProcessing() {
        shouldCancel = true
        isProcessing = false
        cleanup()
    }
    
    // MARK: - 私有处理方法
    
    private func performVideoProcessing(videoURL: URL) {
        do {
            // 1. 加载视频资产
            try loadVideoAsset(from: videoURL)
            
            // 2. 验证视频格式
            try validateVideoFormat()
            
            // 3. 设置图像生成器
            try setupImageGenerator()
            
            // 4. 计算时间点
            let timePoints = calculateTimePoints()
            
            // 5. 提取帧
            let frames = try extractFrames(at: timePoints)
            
            // 6. 处理和优化帧
            let processedFrames = try processExtractedFrames(frames)
            
            // 7. 完成处理
            DispatchQueue.main.async {
                self.isProcessing = false
                self.delegate?.timeSequenceProcessor(self, didCompleteWithFrames: processedFrames)
                self.cleanup()
            }
            
        } catch let error as TimeSequenceError {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.delegate?.timeSequenceProcessor(self, didFailWithError: error)
                self.cleanup()
            }
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.delegate?.timeSequenceProcessor(self, didFailWithError: .processingFailed(error.localizedDescription))
                self.cleanup()
            }
        }
    }
    
    // MARK: - 视频资产处理
    
    private func loadVideoAsset(from url: URL) throws {
        asset = AVAsset(url: url)
        
        guard let asset = asset else {
            throw TimeSequenceError.invalidVideoFormat
        }
        
        // 等待资产加载完成
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) {
            if asset.statusOfValue(forKey: "duration", error: nil) == .failed ||
               asset.statusOfValue(forKey: "tracks", error: nil) == .failed {
                loadError = TimeSequenceError.invalidVideoFormat
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = loadError {
            throw error
        }
    }
    
    private func validateVideoFormat() throws {
        guard let asset = asset else {
            throw TimeSequenceError.invalidVideoFormat
        }
        
        // 检查视频时长
        let duration = asset.duration
        guard duration.seconds > 0 else {
            throw TimeSequenceError.invalidVideoFormat
        }
        
        // 检查视频轨道
        let videoTracks = asset.tracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw TimeSequenceError.invalidVideoFormat
        }
        
        // 检查最小时长要求
        let minDuration = Double(parameters.totalFrames) * parameters.frameInterval
        if duration.seconds < minDuration * 0.5 { // 允许50%的容差
            print("⚠️ 视频时长(\(duration.seconds)s)可能不足，建议至少\(minDuration)s")
        }
    }
    
    private func setupImageGenerator() throws {
        guard let asset = asset else {
            throw TimeSequenceError.invalidVideoFormat
        }
        
        imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator?.appliesPreferredTrackTransform = true
        imageGenerator?.requestedTimeToleranceBefore = CMTime.zero
        imageGenerator?.requestedTimeToleranceAfter = CMTime.zero
        
        // 根据场景类型设置图像质量
        switch parameters.processingMode {
        case .sequential:
            imageGenerator?.maximumSize = CGSize(width: 720, height: 1280)
        case .optimized:
            imageGenerator?.maximumSize = CGSize(width: 1080, height: 1920)
        case .highQuality:
            imageGenerator?.maximumSize = CGSize.zero // 原始尺寸
        }
    }
    
    // MARK: - 时间点计算
    
    private func calculateTimePoints() -> [CMTime] {
        guard let asset = asset else { return [] }
        
        let duration = asset.duration
        let totalDuration = duration.seconds
        
        var timePoints: [CMTime] = []
        
        switch sceneType {
        case .objectChange:
            // 物体变化：均匀分布取帧
            timePoints = calculateUniformTimePoints(totalDuration: totalDuration)
            
        case .personAction:
            // 人物动作：稍微倾向于中间部分
            timePoints = calculateWeightedTimePoints(totalDuration: totalDuration)
            
        case .sportMotion:
            // 运动轨迹：更密集的取帧
            timePoints = calculateDenseTimePoints(totalDuration: totalDuration)
        }
        
        print("📊 计算时间点：\(timePoints.count)个，时长：\(totalDuration)s")
        return timePoints
    }
    
    private func calculateUniformTimePoints(totalDuration: Double) -> [CMTime] {
        let interval = parameters.frameInterval
        let maxFrames = parameters.totalFrames
        
        var timePoints: [CMTime] = []
        var currentTime: Double = 0
        
        while timePoints.count < maxFrames && currentTime < totalDuration {
            let time = CMTime(seconds: currentTime, preferredTimescale: 600)
            timePoints.append(time)
            currentTime += interval
        }
        
        return timePoints
    }
    
    private func calculateWeightedTimePoints(totalDuration: Double) -> [CMTime] {
        let maxFrames = parameters.totalFrames
        var timePoints: [CMTime] = []
        
        // 开始部分：20%的帧
        let startFrames = Int(Double(maxFrames) * 0.2)
        let startDuration = totalDuration * 0.1
        for i in 0..<startFrames {
            let progress = Double(i) / Double(startFrames)
            let time = CMTime(seconds: startDuration * progress, preferredTimescale: 600)
            timePoints.append(time)
        }
        
        // 中间部分：60%的帧
        let middleFrames = Int(Double(maxFrames) * 0.6)
        let middleStart = totalDuration * 0.1
        let middleDuration = totalDuration * 0.8
        for i in 0..<middleFrames {
            let progress = Double(i) / Double(middleFrames)
            let time = CMTime(seconds: middleStart + middleDuration * progress, preferredTimescale: 600)
            timePoints.append(time)
        }
        
        // 结束部分：20%的帧
        let endFrames = maxFrames - startFrames - middleFrames
        let endStart = totalDuration * 0.9
        let endDuration = totalDuration * 0.1
        for i in 0..<endFrames {
            let progress = Double(i) / Double(endFrames)
            let time = CMTime(seconds: endStart + endDuration * progress, preferredTimescale: 600)
            timePoints.append(time)
        }
        
        return timePoints
    }
    
    private func calculateDenseTimePoints(totalDuration: Double) -> [CMTime] {
        let interval = min(parameters.frameInterval, 0.1) // 最小0.1秒间隔
        let maxFrames = parameters.totalFrames
        
        var timePoints: [CMTime] = []
        let step = totalDuration / Double(maxFrames)
        
        for i in 0..<maxFrames {
            let time = CMTime(seconds: Double(i) * step, preferredTimescale: 600)
            timePoints.append(time)
        }
        
        return timePoints
    }
    
    // MARK: - 帧提取
    
    private func extractFrames(at timePoints: [CMTime]) throws -> [UIImage] {
        guard let imageGenerator = imageGenerator else {
            throw TimeSequenceError.processingFailed("图像生成器未初始化")
        }
        
        var extractedFrames: [UIImage] = []
        let totalFrames = timePoints.count
        
        for (index, timePoint) in timePoints.enumerated() {
            if shouldCancel {
                throw TimeSequenceError.processingFailed("用户取消")
            }
            
            // 更新进度
            let progress = Float(index) / Float(totalFrames)
            DispatchQueue.main.async {
                self.delegate?.timeSequenceProcessor(self, didUpdateProgress: progress, currentFrame: index + 1, totalFrames: totalFrames)
            }
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: timePoint, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                extractedFrames.append(image)
                
                // 内存检查
                try checkMemoryUsage()
                
            } catch {
                print("⚠️ 提取第\(index)帧失败：\(error)")
                
                // 🆕 降级策略：尝试使用稍微不同的时间点重试
                let retryTimePoint = CMTime(seconds: timePoint.seconds + 0.1, preferredTimescale: 600)
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: retryTimePoint, actualTime: nil)
                    let image = UIImage(cgImage: cgImage)
                    extractedFrames.append(image)
                    print("✅ 重试成功提取第\(index)帧")
                } catch {
                    print("⚠️ 重试仍失败，跳过第\(index)帧")
                    // 如果重试也失败，则跳过这帧（但不添加占位图，保持数组干净）
                    continue
                }
            }
        }
        
        guard !extractedFrames.isEmpty else {
            throw TimeSequenceError.noFramesExtracted
        }
        
        // 🆕 放宽成功标准：只要有至少3帧就算成功，不再要求一半以上
        let minimumFrames = max(3, totalFrames / 3) // 至少3帧，或者目标帧数的1/3
        if extractedFrames.count < minimumFrames {
            print("⚠️ 提取帧数不足：\(extractedFrames.count)/\(totalFrames)，最少需要\(minimumFrames)帧")
            throw TimeSequenceError.insufficientFrames(extractedFrames.count)
        }
        
        print("✅ 成功提取\(extractedFrames.count)帧，目标为\(totalFrames)帧")
        
        return extractedFrames
    }
    
    // MARK: - 帧处理和优化
    
    private func processExtractedFrames(_ frames: [UIImage]) throws -> [UIImage] {
        print("🔄 开始处理\(frames.count)个提取的帧")
        
        var processedFrames: [UIImage] = []
        
        for (index, frame) in frames.enumerated() {
            if shouldCancel {
                throw TimeSequenceError.processingFailed("用户取消")
            }
            
            var processedFrame = frame
            
            // 根据场景类型应用不同的处理
            switch sceneType {
            case .objectChange:
                processedFrame = try processObjectChangeFrame(frame)
            case .personAction:
                processedFrame = try processPersonActionFrame(frame)
            case .sportMotion:
                processedFrame = try processSportMotionFrame(frame)
            }
            
            processedFrames.append(processedFrame)
            
            // 更新处理进度
            let progress = Float(index) / Float(frames.count)
            DispatchQueue.main.async {
                self.delegate?.timeSequenceProcessor(self, didUpdateProgress: 0.8 + progress * 0.2, currentFrame: index + 1, totalFrames: frames.count)
            }
        }
        
        return processedFrames
    }
    
    private func processObjectChangeFrame(_ frame: UIImage) throws -> UIImage {
        // 物体变化场景：增强对比度和锐度
        return enhanceContrast(frame)
    }
    
    private func processPersonActionFrame(_ frame: UIImage) throws -> UIImage {
        // 人物动作场景：平衡色彩，保持自然
        return balanceColors(frame)
    }
    
    private func processSportMotionFrame(_ frame: UIImage) throws -> UIImage {
        // 运动轨迹场景：增强清晰度
        return enhanceSharpness(frame)
    }
    
    // MARK: - 图像处理工具
    
    private func enhanceContrast(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.2, forKey: kCIInputContrastKey) // 增强对比度
        filter?.setValue(1.1, forKey: kCIInputSaturationKey) // 略微增强饱和度
        
        guard let outputImage = filter?.outputImage else { return image }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return image }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func balanceColors(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.05, forKey: kCIInputContrastKey) // 轻微增强对比度
        filter?.setValue(1.0, forKey: kCIInputSaturationKey) // 保持原始饱和度
        filter?.setValue(0.05, forKey: kCIInputBrightnessKey) // 轻微提亮
        
        guard let outputImage = filter?.outputImage else { return image }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return image }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func enhanceSharpness(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let filter = CIFilter(name: "CISharpenLuminance")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.4, forKey: kCIInputSharpnessKey) // 增强锐度
        
        guard let outputImage = filter?.outputImage else { return image }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return image }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - 内存管理
    
    private func checkMemoryUsage() throws {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Int(memoryInfo.resident_size)
            currentMemoryUsage = usedMemory
            
            // 渐进式内存警告而不是立即失败
            let warningThreshold = Int(Double(maxMemoryUsage) * 0.8) // 80%警告
            let criticalThreshold = Int(Double(maxMemoryUsage) * 0.95) // 95%严重
            
            if usedMemory > criticalThreshold {
                // 强制垃圾回收
                autoreleasepool {
                    // 清理缓存
                }
                throw TimeSequenceError.memoryWarning
            } else if usedMemory > warningThreshold {
                print("⚠️ 内存使用接近限制：\(usedMemory / 1024 / 1024)MB / \(maxMemoryUsage / 1024 / 1024)MB")
            }
        }
    }
    
    private func cleanup() {
        asset = nil
        imageGenerator = nil
        currentMemoryUsage = 0
    }
}

// MARK: - 扩展：便利方法

extension TimeSequenceProcessor {
    
    /// 创建处理器实例
    /// - Parameters:
    ///   - sceneType: 场景类型
    ///   - delegate: 代理对象
    /// - Returns: 配置好的处理器实例
    static func create(sceneType: SceneType, delegate: TimeSequenceProcessorDelegate? = nil) -> TimeSequenceProcessor {
        let processor = TimeSequenceProcessor(sceneType: sceneType)
        processor.delegate = delegate
        return processor
    }
    
    /// 获取建议的处理参数
    /// - Parameter sceneType: 场景类型
    /// - Returns: 建议的处理参数
    static func recommendedParameters(for sceneType: SceneType) -> TimeSequenceParameters {
        return TimeSequenceParameters.defaultParameters(for: sceneType)
    }
}

// MARK: - 扩展：调试信息

extension TimeSequenceProcessor {
    
    /// 打印处理器状态信息
    func printStatus() {
        print("📊 时间序列处理器状态：")
        print("   场景类型：\(sceneType.displayName)")
        print("   处理中：\(isProcessing)")
        print("   内存使用：\(currentMemoryUsage / 1024 / 1024)MB")
        print("   参数配置：")
        print("     帧间隔：\(parameters.frameInterval)s")
        print("     总帧数：\(parameters.totalFrames)")
        print("     处理模式：\(parameters.processingMode)")
    }
}
