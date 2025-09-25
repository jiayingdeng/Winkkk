//
//  DeepLabV3Manager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/25.
//  DeepLabV3 分割管理器 - 专门用于人物分割测试
//

import UIKit
import CoreML
import Vision
import CoreImage

class DeepLabV3Manager {
    
    // MARK: - Singleton
    static let shared = DeepLabV3Manager()
    private init() {}
    
    // MARK: - Properties
    private var model: DeepLabV3Int8LUT?
    private var visionModel: VNCoreMLModel?
    private let context = CIContext()
    
    // DeepLabV3支持的类别（仅人物和动物）
    private let targetClasses: Set<Int> = [
        // 人物
        15, // person (人)
        
        // 动物类别
        3,  // bird (鸟)
        8,  // cat (猫)  
        10, // cow (牛)
        12, // dog (狗)
        13, // horse (马)
        17  // sheep (羊)
    ]
    
    // 分割结果回调
    typealias DeepLabSegmentationCompletion = (Result<DeepLabSegmentationResult, DeepLabSegmentationError>) -> Void
    
    // MARK: - Initialization
    func initialize() throws {
        // 加载DeepLabV3 CoreML模型
        let modelConfig = MLModelConfiguration()
        modelConfig.computeUnits = .all // 使用所有可用计算单元
        
        do {
            model = try DeepLabV3Int8LUT(configuration: modelConfig)
            guard let model = model else {
                throw DeepLabSegmentationError.modelLoadFailed
            }
            
            // 创建Vision模型
            visionModel = try VNCoreMLModel(for: model.model)
            
            print("✅ DeepLabV3Manager 初始化成功")
            print("✅ 支持多类别分割：人物、动物")
            
        } catch {
            print("❌ DeepLabV3Manager 初始化失败: \(error)")
            throw DeepLabSegmentationError.modelLoadFailed
        }
    }
    
    // MARK: - Public Methods
    
    /// 对图片进行多类别分割（支持人物、动物类别）
    /// - Parameters:
    ///   - image: 输入图片
    ///   - completion: 完成回调
    func segmentSubjects(from image: UIImage, completion: @escaping DeepLabSegmentationCompletion) {
        guard let visionModel = visionModel else {
            completion(.failure(.modelNotInitialized))
            return
        }
        
        // 🎯 关键优化10：质量检测机制
        let qualityScore = evaluateImageQuality(image)
        print("📊 输入图像质量评分: \(String(format: "%.1f", qualityScore * 100))%")
        
        // 🎯 关键优化11：多分辨率处理策略
        let optimizedImage = applyResolutionStrategy(image, qualityScore: qualityScore)
        
        // 预处理图片
        guard let inputImage = preprocessImage(optimizedImage) else {
            completion(.failure(.imagePreprocessingFailed))
            return
        }
        
        // 创建Vision请求
        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            if let error = error {
                completion(.failure(.predictionFailed(error)))
                return
            }
            
            // 获取分割结果
            guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                  let segmentationMap = results.first?.featureValue.multiArrayValue else {
                completion(.failure(.invalidPredictionResult))
                return
            }
            
            // 处理分割结果
            self?.processSegmentationResult(
                originalImage: image,
                segmentationMap: segmentationMap,
                completion: completion
            )
        }
        
        // 使用 centerCrop 保持长宽比
        request.imageCropAndScaleOption = .centerCrop
        
        // 执行请求
        let handler = VNImageRequestHandler(cgImage: inputImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(.predictionFailed(error)))
            }
        }
    }
    
    /// 批量处理多帧图像（用于视频分割测试）
    /// - Parameters:
    ///   - frames: 输入图像数组
    ///   - progressCallback: 进度回调 (当前索引, 总数)
    ///   - completion: 单帧完成回调
    ///   - finalCompletion: 全部完成回调
    func segmentMultipleFrames(
        _ frames: [UIImage],
        progressCallback: @escaping (Int, Int) -> Void,
        frameCompletion: @escaping (Int, Result<DeepLabSegmentationResult, DeepLabSegmentationError>) -> Void,
        finalCompletion: @escaping ([Result<DeepLabSegmentationResult, DeepLabSegmentationError>]) -> Void
    ) {
        guard !frames.isEmpty else {
            finalCompletion([])
            return
        }
        
        var results: [Result<DeepLabSegmentationResult, DeepLabSegmentationError>] = []
        results.reserveCapacity(frames.count)
        
        // 使用DispatchQueue进行顺序处理，避免内存压力过大
        let processingQueue = DispatchQueue(label: "com.winkkk.deeplabv3.batch", qos: .userInitiated)
        
        func processNextFrame(index: Int) {
            guard index < frames.count else {
                // 所有帧处理完成
                DispatchQueue.main.async {
                    finalCompletion(results)
                }
                return
            }
            
            // 更新进度
            DispatchQueue.main.async {
                progressCallback(index, frames.count)
            }
            
            let frame = frames[index]
            
            // 处理当前帧
            self.segmentSubjects(from: frame) { result in
                // 保存结果
                if results.count <= index {
                    results.append(result)
                } else {
                    results[index] = result
                }
                
                // 通知单帧完成
                DispatchQueue.main.async {
                    frameCompletion(index, result)
                }
                
                // 处理下一帧（添加小延迟避免内存峰值）
                processingQueue.asyncAfter(deadline: .now() + 0.05) {
                    processNextFrame(index: index + 1)
                }
            }
        }
        
        // 开始处理第一帧
        processingQueue.async {
            processNextFrame(index: 0)
        }
    }
    
    /// 并发批量处理（适用于性能较好的设备）
    /// - Parameters:
    ///   - frames: 输入图像数组
    ///   - maxConcurrency: 最大并发数，默认为2
    ///   - progressCallback: 进度回调
    ///   - completion: 完成回调
    func segmentMultipleFramesConcurrently(
        _ frames: [UIImage],
        maxConcurrency: Int = 2,
        progressCallback: @escaping (Int, Int) -> Void,
        completion: @escaping ([Result<DeepLabSegmentationResult, DeepLabSegmentationError>]) -> Void
    ) {
        guard !frames.isEmpty else {
            completion([])
            return
        }
        
        var results: [Result<DeepLabSegmentationResult, DeepLabSegmentationError>?] = Array(repeating: nil, count: frames.count)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: maxConcurrency)
        let resultQueue = DispatchQueue(label: "com.winkkk.deeplabv3.results", attributes: .concurrent)
        
        var completedCount = 0
        
        for (index, frame) in frames.enumerated() {
            group.enter()
            
            DispatchQueue.global(qos: .userInitiated).async {
                semaphore.wait() // 限制并发数
                
                self.segmentSubjects(from: frame) { result in
                    resultQueue.async(flags: .barrier) {
                        results[index] = result
                        completedCount += 1
                        
                        DispatchQueue.main.async {
                            progressCallback(completedCount, frames.count)
                        }
                    }
                    
                    semaphore.signal()
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            let finalResults = results.compactMap { $0 }
            completion(finalResults)
        }
    }
    
    // MARK: - Utility Methods
    
    /// 计算批量处理统计信息
    /// - Parameter results: 处理结果数组
    /// - Returns: 统计信息
    func calculateBatchStatistics(_ results: [Result<DeepLabSegmentationResult, DeepLabSegmentationError>]) -> BatchProcessingStatistics {
        let successResults = results.compactMap { result -> DeepLabSegmentationResult? in
            if case .success(let segmentationResult) = result {
                return segmentationResult
            }
            return nil
        }
        
        let failedCount = results.count - successResults.count
        
        guard !successResults.isEmpty else {
            return BatchProcessingStatistics(
                totalFrames: results.count,
                successfulFrames: 0,
                failedFrames: failedCount,
                averageConfidence: 0.0,
                averageSubjectRatio: 0.0,
                averageProcessingTime: 0.0,
                consistencyScore: 0.0
            )
        }
        
        let averageConfidence = successResults.map { $0.confidence }.reduce(0, +) / Float(successResults.count)
        let averageSubjectRatio = successResults.map { $0.subjectPixelRatio }.reduce(0, +) / Float(successResults.count)
        
        // 计算一致性评分（相邻帧的相似度）
        var consistencyScore: Float = 1.0
        if successResults.count > 1 {
            var totalDifference: Float = 0.0
            for i in 1..<successResults.count {
                let diff = abs(successResults[i].subjectPixelRatio - successResults[i-1].subjectPixelRatio)
                totalDifference += diff
            }
            let averageDifference = totalDifference / Float(successResults.count - 1)
            consistencyScore = max(0.0, 1.0 - (averageDifference * 5.0))
        }
        
        return BatchProcessingStatistics(
            totalFrames: results.count,
            successfulFrames: successResults.count,
            failedFrames: failedCount,
            averageConfidence: averageConfidence,
            averageSubjectRatio: averageSubjectRatio,
            averageProcessingTime: 0.0, // 这里需要外部计算
            consistencyScore: consistencyScore
        )
    }
    
    // MARK: - Private Methods
    
    /// 预处理输入图片 - 针对DeepLabV3优化
    private func preprocessImage(_ image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // DeepLabV3通常使用513x513的输入尺寸
        let targetSize = CGSize(width: 513, height: 513)
        
        // 🎯 关键优化7：智能裁剪策略
        let processedImage = applyIntelligentCropping(image)
        guard let processedCGImage = processedImage.cgImage else { return nil }
        
        // 🎯 关键优化8：色彩空间优化
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(targetSize.width) * 4, // 明确指定字节行数
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // 🎯 关键优化9：高质量缩放设置
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        
        // 绘制缩放后的图片
        context.draw(processedCGImage, in: CGRect(origin: .zero, size: targetSize))
        
        return context.makeImage()
    }
    
    /// 🎯 智能裁剪策略 - 尽可能保持人物特征
    private func applyIntelligentCropping(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // 如果图像已经接近正方形，直接返回
        let aspectRatio = originalSize.width / originalSize.height
        if aspectRatio > 0.8 && aspectRatio < 1.25 {
            return image
        }
        
        // 🎯 策略1：中心裁剪，保持更多细节
        let cropSize: CGFloat
        if aspectRatio > 1.0 {
            // 宽图：以高度为准
            cropSize = originalSize.height
        } else {
            // 高图：以宽度为准
            cropSize = originalSize.width
        }
        
        let cropRect = CGRect(
            x: (originalSize.width - cropSize) / 2,
            y: (originalSize.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: croppedCGImage)
    }
    
    /// 🎯 图像质量评估
    private func evaluateImageQuality(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        let pixelCount = width * height
        
        // 分辨率评分 (0.0-1.0)
        let resolutionScore = min(1.0, Double(pixelCount) / (1920 * 1080)) // 以1080p为满分
        
        // 长宽比评分 (接近正方形得分更高，因为DeepLabV3喜欢正方形输入)
        let aspectRatio = Double(width) / Double(height)
        let aspectScore = 1.0 - abs(aspectRatio - 1.0) / max(aspectRatio, 1.0)
        
        // 综合评分
        let totalScore = resolutionScore * 0.7 + aspectScore * 0.3
        
        return max(0.0, min(1.0, totalScore))
    }
    
    /// 🎯 多分辨率处理策略
    private func applyResolutionStrategy(_ image: UIImage, qualityScore: Double) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        let originalPixels = originalWidth * originalHeight
        
        // 策略选择基于质量评分和原始分辨率
        if qualityScore >= 0.8 {
            // 高质量图像：保持原分辨率
            print("📊 分辨率策略: 保持原分辨率 (\(originalWidth)×\(originalHeight))")
            return image
        } else if qualityScore >= 0.5 {
            // 中等质量：适度提升
            let scaleFactor: CGFloat = qualityScore < 0.6 ? 1.2 : 1.1
            return scaleImage(image, scaleFactor: scaleFactor)
        } else {
            // 低质量图像：需要更多预处理
            print("📊 分辨率策略: 低质量图像增强")
            return enhanceLowQualityImage(image)
        }
    }
    
    /// 缩放图像
    private func scaleImage(_ image: UIImage, scaleFactor: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let newWidth = Int(CGFloat(cgImage.width) * scaleFactor)
        let newHeight = Int(CGFloat(cgImage.height) * scaleFactor)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        guard let scaledCGImage = context.makeImage() else { return image }
        
        print("📊 图像缩放: \(cgImage.width)×\(cgImage.height) → \(newWidth)×\(newHeight)")
        return UIImage(cgImage: scaledCGImage)
    }
    
    /// 低质量图像增强
    private func enhanceLowQualityImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // 应用降噪滤镜
        guard let noiseReductionFilter = CIFilter(name: "CINoiseReduction") else { return image }
        noiseReductionFilter.setValue(ciImage, forKey: kCIInputImageKey)
        noiseReductionFilter.setValue(0.02, forKey: "inputNoiseLevel")
        noiseReductionFilter.setValue(0.40, forKey: "inputSharpness")
        
        // 应用锐化滤镜
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance"),
              let intermediateImage = noiseReductionFilter.outputImage else { return image }
        sharpenFilter.setValue(intermediateImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.6, forKey: kCIInputSharpnessKey)
        
        // 应用对比度增强
        guard let colorControlsFilter = CIFilter(name: "CIColorControls"),
              let sharpenedImage = sharpenFilter.outputImage else { return image }
        colorControlsFilter.setValue(sharpenedImage, forKey: kCIInputImageKey)
        colorControlsFilter.setValue(1.15, forKey: kCIInputContrastKey)
        colorControlsFilter.setValue(1.05, forKey: kCIInputSaturationKey)
        colorControlsFilter.setValue(0.05, forKey: kCIInputBrightnessKey)
        
        guard let finalImage = colorControlsFilter.outputImage else { return image }
        
        guard let enhancedCGImage = context.createCGImage(finalImage, from: finalImage.extent) else { return image }
        
        print("📊 低质量图像增强完成")
        return UIImage(cgImage: enhancedCGImage)
    }
    
    /// 处理分割结果
    private func processSegmentationResult(
        originalImage: UIImage,
        segmentationMap: MLMultiArray,
        completion: @escaping DeepLabSegmentationCompletion
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 创建主体遮罩
                let mask = try self.createSubjectMask(from: segmentationMap)
                
                // 提取分割主体
                let subjectImage = try self.extractSubject(from: originalImage, with: mask)
                
                // 计算分割质量指标
                let metrics = self.calculateSegmentationMetrics(segmentationMap)
                
                // 创建结果
                let result = DeepLabSegmentationResult(
                    originalImage: originalImage,
                    subjectImage: subjectImage,
                    maskImage: mask,
                    confidence: metrics.confidence,
                    subjectPixelRatio: metrics.subjectPixelRatio,
                    maskQuality: metrics.maskQuality
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.postProcessingFailed(error)))
                }
            }
        }
    }
    
    /// 从分割结果创建主体遮罩（支持多类别）
    private func createSubjectMask(from segmentationMap: MLMultiArray) throws -> UIImage {
        print("DeepLabV3 分割结果形状: \(segmentationMap.shape)")
        
        // DeepLabV3输出通常是 [1, 1, height, width] 或 [height, width]
        let height: Int
        let width: Int
        
        if segmentationMap.shape.count == 4 {
            // 形状: [1, 1, height, width]
            height = segmentationMap.shape[2].intValue
            width = segmentationMap.shape[3].intValue
        } else if segmentationMap.shape.count == 3 {
            // 形状: [1, height, width]
            height = segmentationMap.shape[1].intValue
            width = segmentationMap.shape[2].intValue
        } else if segmentationMap.shape.count == 2 {
            // 形状: [height, width]
            height = segmentationMap.shape[0].intValue
            width = segmentationMap.shape[1].intValue
        } else {
            throw DeepLabSegmentationError.invalidSegmentationShape
        }
        
        // 创建遮罩数据
        var maskData = [UInt8](repeating: 0, count: width * height)
        
        // 遍历分割结果，查找人物像素
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                
                // 根据形状选择正确的索引方式
                let classIndex: Int
                if segmentationMap.shape.count == 4 {
                    classIndex = segmentationMap[[0, 0, NSNumber(value: y), NSNumber(value: x)]].intValue
                } else if segmentationMap.shape.count == 3 {
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                
                // 检查是否为目标类别（人物、动物）
                if targetClasses.contains(classIndex) {
                    maskData[index] = 255 // 白色（前景）
                } else {
                    maskData[index] = 0   // 黑色（背景）
                }
            }
        }
        
        // 创建CGImage
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &maskData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let cgImage = context?.makeImage() else {
            throw DeepLabSegmentationError.maskCreationFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 使用遮罩提取主体
    private func extractSubject(from originalImage: UIImage, with mask: UIImage) throws -> UIImage {
        guard let originalCGImage = originalImage.cgImage,
              let maskCGImage = mask.cgImage else {
            throw DeepLabSegmentationError.subjectExtractionFailed
        }
        
        // 使用Core Image进行遮罩处理
        let originalCIImage = CIImage(cgImage: originalCGImage)
        let maskCIImage = CIImage(cgImage: maskCGImage)
        
        // 缩放遮罩到原图尺寸
        let scaleX = originalCIImage.extent.width / maskCIImage.extent.width
        let scaleY = originalCIImage.extent.height / maskCIImage.extent.height
        let scaledMask = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 应用遮罩
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            throw DeepLabSegmentationError.subjectExtractionFailed
        }
        
        filter.setValue(originalCIImage, forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: CIColor.clear).cropped(to: originalCIImage.extent), forKey: kCIInputBackgroundImageKey)
        filter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw DeepLabSegmentationError.subjectExtractionFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 计算分割质量指标
    private func calculateSegmentationMetrics(_ segmentationMap: MLMultiArray) -> SegmentationMetrics {
        let height: Int
        let width: Int
        
        if segmentationMap.shape.count == 4 {
            height = segmentationMap.shape[2].intValue
            width = segmentationMap.shape[3].intValue
        } else if segmentationMap.shape.count == 3 {
            height = segmentationMap.shape[1].intValue
            width = segmentationMap.shape[2].intValue
        } else {
            height = segmentationMap.shape[0].intValue
            width = segmentationMap.shape[1].intValue
        }
        
        let totalPixels = width * height
        var subjectPixels = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let classIndex: Int
                if segmentationMap.shape.count == 4 {
                    classIndex = segmentationMap[[0, 0, NSNumber(value: y), NSNumber(value: x)]].intValue
                } else if segmentationMap.shape.count == 3 {
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                
                if targetClasses.contains(classIndex) {
                    subjectPixels += 1
                }
            }
        }
        
        let subjectPixelRatio = Float(subjectPixels) / Float(totalPixels)
        
        // 计算置信度（基于主体像素比例和分布）
        let confidence: Float
        if subjectPixelRatio > 0.01 { // 至少1%的像素是目标主体
            confidence = min(subjectPixelRatio * 10.0, 1.0) // 缩放到合理范围
        } else {
            confidence = 0.1 // 很低的置信度
        }
        
        // 计算遮罩质量（基于主体像素的连续性）
        let maskQuality: Float = subjectPixelRatio > 0.05 ? 0.8 : 0.5
        
        return SegmentationMetrics(
            confidence: confidence,
            subjectPixelRatio: subjectPixelRatio,
            maskQuality: maskQuality
        )
    }
}

// MARK: - Data Structures

struct DeepLabSegmentationResult {
    let originalImage: UIImage
    let subjectImage: UIImage     // 提取的主体（带透明背景）
    let maskImage: UIImage        // 分割遮罩
    let confidence: Float         // 分割置信度 (0.0 - 1.0)
    let subjectPixelRatio: Float  // 主体像素占比
    let maskQuality: Float        // 遮罩质量评分
}

struct SegmentationMetrics {
    let confidence: Float
    let subjectPixelRatio: Float
    let maskQuality: Float
}

struct BatchProcessingStatistics {
    let totalFrames: Int
    let successfulFrames: Int
    let failedFrames: Int
    let averageConfidence: Float
    let averageSubjectRatio: Float
    let averageProcessingTime: TimeInterval
    let consistencyScore: Float
    
    var successRate: Float {
        guard totalFrames > 0 else { return 0.0 }
        return Float(successfulFrames) / Float(totalFrames)
    }
    
    var formattedSummary: String {
        return """
        📊 批量处理统计
        • 总帧数: \(totalFrames)
        • 成功率: \(String(format: "%.1f%%", successRate * 100))
        • 平均置信度: \(String(format: "%.1f%%", averageConfidence * 100))
        • 平均主体占比: \(String(format: "%.1f%%", averageSubjectRatio * 100))
        • 帧间一致性: \(String(format: "%.1f%%", consistencyScore * 100))
        """
    }
}

enum DeepLabSegmentationError: LocalizedError {
    case modelNotInitialized
    case modelLoadFailed
    case imagePreprocessingFailed
    case predictionFailed(Error)
    case invalidPredictionResult
    case invalidSegmentationShape
    case postProcessingFailed(Error)
    case maskCreationFailed
    case subjectExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "DeepLabV3模型未初始化"
        case .modelLoadFailed:
            return "DeepLabV3模型加载失败"
        case .imagePreprocessingFailed:
            return "图片预处理失败"
        case .predictionFailed(let error):
            return "DeepLabV3预测失败: \(error.localizedDescription)"
        case .invalidPredictionResult:
            return "无效的预测结果"
        case .invalidSegmentationShape:
            return "分割结果形状不正确"
        case .postProcessingFailed(let error):
            return "后处理失败: \(error.localizedDescription)"
        case .maskCreationFailed:
            return "遮罩创建失败"
        case .subjectExtractionFailed:
            return "主体提取失败"
        }
    }
}
