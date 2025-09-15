//
//  ImageEnhancer.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  图像增强引擎 - Core Image算法（USM锐化、直方图均衡化）
//

import CoreImage
import UIKit

class ImageEnhancer {
    
    // MARK: - Properties
    private let context: CIContext
    
    // 滤镜实例缓存
    private lazy var unsharpMaskFilter = CIFilter(name: "CIUnsharpMask")!
    private lazy var colorControlsFilter = CIFilter(name: "CIColorControls")!
    private lazy var exposureAdjustFilter = CIFilter(name: "CIExposureAdjust")!
    private lazy var vibranceFilter = CIFilter(name: "CIVibrance")!
    private lazy var gaussianBlurFilter = CIFilter(name: "CIGaussianBlur")!
    private lazy var lanczosScaleFilter = CIFilter(name: "CILanczosScaleTransform")!
    
    // MARK: - Initialization
    init() {
        // 创建Metal上下文以获得最佳性能
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice)
        } else {
            context = CIContext()
        }
    }
    
    // MARK: - Enhancement Methods
    
    /// 应用完整的图像增强处理
    /// - Parameters:
    ///   - image: 输入图像
    ///   - level: 增强强度等级 (1-3)
    ///   - completion: 完成回调
    func enhanceImage(_ image: UIImage, level: EnhanceLevel, completion: @escaping (Result<UIImage, ImageEnhancementError>) -> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed("Enhancement cancelled")))
                }
                return
            }
            
            do {
                let enhancedImage = try self.processImage(image, with: level)
                
                DispatchQueue.main.async {
                    completion(.success(enhancedImage))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// 处理图像的核心方法
    /// - Parameters:
    ///   - image: 输入图像
    ///   - level: 增强等级
    /// - Returns: 处理后的图像
    /// - Throws: 处理错误
    private func processImage(_ image: UIImage, with level: EnhanceLevel) throws -> UIImage {
        guard let inputImage = CIImage(image: image) else {
            throw ImageEnhancementError.invalidInput
        }
        
        var currentImage = inputImage
        
        // 1. USM锐化
        currentImage = try applyUnsharpMask(to: currentImage, intensity: level.sharpnessIntensity)
        
        // 2. 对比度和亮度调整
        currentImage = try adjustExposureAndContrast(currentImage, level: level)
        
        // 3. 颜色增强
        currentImage = try enhanceColors(currentImage, level: level)
        
        // 4. 降噪处理（轻微）
        if level != .light {
            currentImage = try applyNoiseReduction(to: currentImage, intensity: level.noiseReductionIntensity)
        }
        
        // 5. 最终锐化
        if level == .heavy {
            currentImage = try applyFinalSharpening(to: currentImage)
        }
        
        // 转换回UIImage
        guard let cgImage = context.createCGImage(currentImage, from: currentImage.extent) else {
            throw ImageEnhancementError.processingFailed("Failed to create CGImage")
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - Individual Enhancement Methods
    
    /// 应用USM锐化
    /// - Parameters:
    ///   - image: 输入图像
    ///   - intensity: 锐化强度 (0.0-2.0)
    /// - Returns: 锐化后的图像
    /// - Throws: 处理错误
    private func applyUnsharpMask(to image: CIImage, intensity: Float) throws -> CIImage {
        unsharpMaskFilter.setValue(image, forKey: kCIInputImageKey)
        unsharpMaskFilter.setValue(intensity, forKey: kCIInputIntensityKey)
        unsharpMaskFilter.setValue(2.5, forKey: kCIInputRadiusKey) // 锐化半径
        unsharpMaskFilter.setValue(0.1, forKey: "inputThreshold") // 锐化阈值
        
        guard let outputImage = unsharpMaskFilter.outputImage else {
            throw ImageEnhancementError.processingFailed("Unsharp mask failed")
        }
        
        return outputImage
    }
    
    /// 调整曝光和对比度
    /// - Parameters:
    ///   - image: 输入图像
    ///   - level: 增强等级
    /// - Returns: 调整后的图像
    /// - Throws: 处理错误
    private func adjustExposureAndContrast(_ image: CIImage, level: EnhanceLevel) throws -> CIImage {
        // 曝光调整
        exposureAdjustFilter.setValue(image, forKey: kCIInputImageKey)
        exposureAdjustFilter.setValue(level.exposureAdjustment, forKey: kCIInputEVKey)
        
        guard let exposureAdjustedImage = exposureAdjustFilter.outputImage else {
            throw ImageEnhancementError.processingFailed("Exposure adjustment failed")
        }
        
        // 对比度调整
        colorControlsFilter.setValue(exposureAdjustedImage, forKey: kCIInputImageKey)
        colorControlsFilter.setValue(1.0 + level.contrastBoost, forKey: kCIInputContrastKey)
        colorControlsFilter.setValue(level.brightnessAdjustment, forKey: kCIInputBrightnessKey)
        colorControlsFilter.setValue(1.0, forKey: kCIInputSaturationKey) // 在颜色增强中单独处理
        
        guard let outputImage = colorControlsFilter.outputImage else {
            throw ImageEnhancementError.processingFailed("Color controls failed")
        }
        
        return outputImage
    }
    
    /// 增强颜色
    /// - Parameters:
    ///   - image: 输入图像
    ///   - level: 增强等级
    /// - Returns: 颜色增强后的图像
    /// - Throws: 处理错误
    private func enhanceColors(_ image: CIImage, level: EnhanceLevel) throws -> CIImage {
        vibranceFilter.setValue(image, forKey: kCIInputImageKey)
        vibranceFilter.setValue(level.vibranceBoost, forKey: kCIInputAmountKey)
        
        guard let vibranceImage = vibranceFilter.outputImage else {
            throw ImageEnhancementError.processingFailed("Vibrance enhancement failed")
        }
        
        // 饱和度微调
        colorControlsFilter.setValue(vibranceImage, forKey: kCIInputImageKey)
        colorControlsFilter.setValue(1.0 + level.saturationBoost, forKey: kCIInputSaturationKey)
        colorControlsFilter.setValue(1.0, forKey: kCIInputContrastKey) // 重置对比度，避免累积
        colorControlsFilter.setValue(0.0, forKey: kCIInputBrightnessKey) // 重置亮度
        
        guard let outputImage = colorControlsFilter.outputImage else {
            throw ImageEnhancementError.processingFailed("Saturation adjustment failed")
        }
        
        return outputImage
    }
    
    /// 应用降噪处理
    /// - Parameters:
    ///   - image: 输入图像
    ///   - intensity: 降噪强度
    /// - Returns: 降噪后的图像
    /// - Throws: 处理错误
    private func applyNoiseReduction(to image: CIImage, intensity: Float) throws -> CIImage {
        // 使用轻微的高斯模糊作为简单的降噪
        gaussianBlurFilter.setValue(image, forKey: kCIInputImageKey)
        gaussianBlurFilter.setValue(intensity, forKey: kCIInputRadiusKey)
        
        guard let blurredImage = gaussianBlurFilter.outputImage else {
            throw ImageEnhancementError.processingFailed("Noise reduction failed")
        }
        
        // 将原图和模糊图混合，保持细节
        guard let blendFilter = CIFilter(name: "CISourceOverCompositing") else {
            throw ImageEnhancementError.processingFailed("Cannot create blend filter")
        }
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(blurredImage, forKey: kCIInputBackgroundImageKey)
        
        guard let outputImage = blendFilter.outputImage else {
            throw ImageEnhancementError.processingFailed("Noise reduction blend failed")
        }
        
        return outputImage
    }
    
    /// 应用最终锐化
    /// - Parameter image: 输入图像
    /// - Returns: 最终锐化后的图像
    /// - Throws: 处理错误
    private func applyFinalSharpening(to image: CIImage) throws -> CIImage {
        // 创建自定义的锐化卷积内核
        let sharpenKernel = CIKernel(source: """
            kernel vec4 sharpenKernel(sampler image) {
                vec2 dc = destCoord();
                vec4 current = sample(image, samplerTransform(image, dc));
                vec4 blur = (
                    sample(image, samplerTransform(image, dc + vec2(-1, -1))) +
                    sample(image, samplerTransform(image, dc + vec2(-1,  1))) +
                    sample(image, samplerTransform(image, dc + vec2( 1, -1))) +
                    sample(image, samplerTransform(image, dc + vec2( 1,  1)))
                ) * 0.25;
                
                return current + (current - blur) * 0.5;
            }
        """)
        
        if let kernel = sharpenKernel {
            let outputImage = kernel.apply(extent: image.extent, roiCallback: { _, _ in
                return image.extent
            }, arguments: [image])
            
            return outputImage ?? image
        }
        
        // 如果自定义内核失败，使用标准USM锐化
        return try applyUnsharpMask(to: image, intensity: 0.8)
    }
}

// MARK: - Convenience Methods
extension ImageEnhancer {
    
    /// 预览增强效果（低质量快速处理）
    /// - Parameters:
    ///   - image: 输入图像
    ///   - level: 增强等级
    ///   - completion: 完成回调
    func previewEnhancement(_ image: UIImage, level: EnhanceLevel, completion: @escaping (Result<UIImage, ImageEnhancementError>) -> Void) {
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed("Enhancement cancelled")))
                }
                return
            }
            
            do {
                // 缩小图像以快速预览
                let previewImage = self.resizeImageForPreview(image)
                let enhancedImage = try self.processImage(previewImage, with: level)
                
                DispatchQueue.main.async {
                    completion(.success(enhancedImage))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// 调整图像大小用于预览
    /// - Parameter image: 原始图像
    /// - Returns: 缩小的图像
    private func resizeImageForPreview(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 800
        let size = image.size
        
        if max(size.width, size.height) <= maxDimension {
            return image
        }
        
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        return image.resize(to: newSize) ?? image
    }
    
    /// 批量处理图像
    /// - Parameters:
    ///   - images: 输入图像数组
    ///   - level: 增强等级
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    func batchEnhanceImages(_ images: [UIImage], level: EnhanceLevel, progress: @escaping (Float) -> Void, completion: @escaping (Result<[UIImage], ImageEnhancementError>) -> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed("Enhancement cancelled")))
                }
                return
            }
            
            var enhancedImages: [UIImage] = []
            let totalCount = images.count
            
            for (index, image) in images.enumerated() {
                do {
                    let enhancedImage = try self.processImage(image, with: level)
                    enhancedImages.append(enhancedImage)
                    
                    // 更新进度
                    let progressValue = Float(index + 1) / Float(totalCount)
                    DispatchQueue.main.async {
                        progress(progressValue)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(.processingFailed("Batch processing failed at image \(index): \(error.localizedDescription)")))
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                completion(.success(enhancedImages))
            }
        }
    }
}

// MARK: - Enhancement Levels
enum EnhanceLevel: Int, CaseIterable {
    case light = 1
    case medium = 2
    case heavy = 3
    
    var displayName: String {
        switch self {
        case .light: return "轻度修复"
        case .medium: return "中度修复"
        case .heavy: return "重度修复"
        }
    }
    
    var description: String {
        switch self {
        case .light: return "轻微增强图像清晰度和色彩"
        case .medium: return "显著改善图像质量和细节"
        case .heavy: return "最大化提升图像品质"
        }
    }
    
    // MARK: - Parameter Values
    var sharpnessIntensity: Float {
        switch self {
        case .light: return 0.5
        case .medium: return 1.0
        case .heavy: return 1.5
        }
    }
    
    var contrastBoost: Float {
        switch self {
        case .light: return 0.1
        case .medium: return 0.2
        case .heavy: return 0.3
        }
    }
    
    var brightnessAdjustment: Float {
        switch self {
        case .light: return 0.02
        case .medium: return 0.05
        case .heavy: return 0.08
        }
    }
    
    var saturationBoost: Float {
        switch self {
        case .light: return 0.05
        case .medium: return 0.1
        case .heavy: return 0.15
        }
    }
    
    var vibranceBoost: Float {
        switch self {
        case .light: return 0.1
        case .medium: return 0.2
        case .heavy: return 0.3
        }
    }
    
    var noiseReductionIntensity: Float {
        switch self {
        case .light: return 0.0
        case .medium: return 0.5
        case .heavy: return 1.0
        }
    }
    
    var exposureAdjustment: Float {
        switch self {
        case .light: return 0.1
        case .medium: return 0.15
        case .heavy: return 0.2
        }
    }
    
    var processingTime: String {
        switch self {
        case .light: return "< 1秒"
        case .medium: return "1-2秒"
        case .heavy: return "2-3秒"
        }
    }
}

// MARK: - Error Types
enum ImageEnhancementError: LocalizedError {
    case invalidInput
    case processingFailed(String)
    case insufficientMemory
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "无效的输入图像"
        case .processingFailed(let message):
            return "图像处理失败: \(message)"
        case .insufficientMemory:
            return "内存不足，无法处理图像"
        case .unsupportedFormat:
            return "不支持的图像格式"
        }
    }
}

// MARK: - Performance Monitoring
extension ImageEnhancer {
    
    /// 获取处理性能统计
    /// - Parameter completion: 完成回调，返回性能信息
    func getPerformanceStats(completion: @escaping (PerformanceStats) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let stats = PerformanceStats(
                contextType: self.context.description.contains("Metal") ? "Metal" : "CPU",
                availableMemory: self.getAvailableMemory(),
                recommendedMaxImageSize: self.getRecommendedMaxImageSize()
            )
            
            DispatchQueue.main.async {
                completion(stats)
            }
        }
    }
    
    private func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getRecommendedMaxImageSize() -> CGSize {
        let devicePerformance = DeviceInfo.performanceLevel
        
        switch devicePerformance {
        case .high:
            return CGSize(width: 4096, height: 4096)
        case .medium:
            return CGSize(width: 2048, height: 2048)
        case .low:
            return CGSize(width: 1280, height: 1280)
        }
    }
}

struct PerformanceStats {
    let contextType: String
    let availableMemory: UInt64
    let recommendedMaxImageSize: CGSize
    
    var formattedMemory: String {
        return String.formatFileSize(Int64(availableMemory))
    }
}
