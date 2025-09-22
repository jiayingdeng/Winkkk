//
//  SubjectSegmentationManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/22.
//  主体分割管理器 - 封装DeepLabV3模型使用逻辑
//

import UIKit
import CoreML
import Vision
import CoreImage
import Accelerate

class SubjectSegmentationManager {
    
    // MARK: - Singleton
    static let shared = SubjectSegmentationManager()
    private init() {}
    
    // MARK: - Properties
    
    // COCO数据集类别配置 - 支持多种主体类别
    private let targetClasses: Set<Int> = [
        0,   // person (人)
        16,  // bird (鸟)
        17,  // cat (猫)
        18,  // dog (狗)
        19,  // horse (马)
        20,  // sheep (羊)
        21,  // cow (牛)
        22,  // elephant (大象)
        23,  // bear (熊)
        24,  // zebra (斑马)
        25,  // giraffe (长颈鹿)
        // 植物相关
        51,  // banana (香蕉)
        52,  // apple (苹果)
        53,  // sandwich (三明治)
        54,  // orange (橙子)
        55,  // broccoli (西兰花)
        56,  // carrot (胡萝卜)
        57,  // hot dog (热狗)
        58,  // pizza (披萨)
        59,  // donut (甜甜圈)
        60,  // cake (蛋糕)
        // 更多食物
        47,  // cup (杯子)
        46,  // wine glass (酒杯)
        48,  // fork (叉子)
        49,  // knife (刀)
        50   // spoon (勺子)
    ]
    
    private var model: DETRResnet50SemanticSegmentationF16P8?
    private var visionModel: VNCoreMLModel?
    private let context = CIContext()
    
    // 分割结果回调
    typealias SegmentationCompletion = (Result<SegmentationResult, SegmentationError>) -> Void
    
    // MARK: - Initialization
    func initialize() throws {
        // 加载DETR CoreML模型
        let modelConfig = MLModelConfiguration()
        modelConfig.computeUnits = .all // 使用所有可用计算单元（CPU + GPU + Neural Engine）
        
        model = try DETRResnet50SemanticSegmentationF16P8(configuration: modelConfig)
        guard let model = model else {
            throw SegmentationError.modelLoadFailed
        }
        
        // 创建Vision模型
        visionModel = try VNCoreMLModel(for: model.model)
        
        print("✅ SubjectSegmentationManager (DETR) 初始化成功")
        print("✅ 支持类别: 人物、动物、植物、食物等多种主体")
    }
    
    // MARK: - Public Methods
    
    /// 对图片进行主体分割
    /// - Parameters:
    ///   - image: 输入图片
    ///   - completion: 完成回调
    func segmentSubject(from image: UIImage, completion: @escaping SegmentationCompletion) {
        guard let visionModel = visionModel else {
            completion(.failure(.modelNotInitialized))
            return
        }
        
        // 预处理图片
        guard let inputImage = preprocessImage(image) else {
            completion(.failure(.imagePreprocessingFailed))
            return
        }
        
        // 创建Vision请求
        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            if let error = error {
                completion(.failure(.predictionFailed(error)))
                return
            }
            
            // 调试：打印所有结果
            print("Vision request results count: \(request.results?.count ?? 0)")
            if let results = request.results {
                for (index, result) in results.enumerated() {
                    print("Result \(index): \(type(of: result))")
                    if let featureResult = result as? VNCoreMLFeatureValueObservation {
                        print("Feature name: \(featureResult.featureName ?? "unknown")")
                        if let multiArray = featureResult.featureValue.multiArrayValue {
                            print("Shape: \(multiArray.shape), dataType: \(multiArray.dataType.rawValue)")
                        }
                    }
                }
            }
            
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
        
        // 使用 centerCrop 保持长宽比，避免图片变形
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
    
    // MARK: - Private Methods
    
    /// 预处理输入图片
    private func preprocessImage(_ image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // DETR模型通常需要更大的输入尺寸，我们使用800x800以获得更好的分割效果
        let targetSize = CGSize(width: 800, height: 800)
        
        // 创建上下文
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // 绘制缩放后的图片
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        
        return context.makeImage()
    }
    
    /// 处理分割结果
    private func processSegmentationResult(
        originalImage: UIImage,
        segmentationMap: MLMultiArray,
        completion: @escaping SegmentationCompletion
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 创建遮罩
                let mask = try self.createMaskFromSegmentation(segmentationMap)
                
                // 提取主体
                let subjectImage = try self.extractSubject(from: originalImage, with: mask)
                
                // 创建结果
                let result = SegmentationResult(
                    originalImage: originalImage,
                    subjectImage: subjectImage,
                    maskImage: mask,
                    confidence: self.calculateConfidence(segmentationMap)
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
    
    /// 从分割结果创建遮罩
    private func createMaskFromSegmentation(_ segmentationMap: MLMultiArray) throws -> UIImage {
        // 打印形状以调试
        print("Segmentation map shape: \(segmentationMap.shape)")
        
        // DeepLabV3输出形状通常是 [1, height, width] 或 [height, width]
        let height: Int
        let width: Int
        
        if segmentationMap.shape.count == 3 {
            // 形状: [1, height, width]
            height = segmentationMap.shape[1].intValue
            width = segmentationMap.shape[2].intValue
        } else if segmentationMap.shape.count == 2 {
            // 形状: [height, width]
            height = segmentationMap.shape[0].intValue
            width = segmentationMap.shape[1].intValue
        } else {
            throw NSError(domain: "SubjectSegmentationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected segmentation map shape: \(segmentationMap.shape)"])
        }
        
        // 创建灰度图像数据
        var maskData = [UInt8](repeating: 0, count: width * height)
        
        // 遍历分割结果
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                
                // 根据形状选择正确的索引方式
                let classIndex: Int
                if segmentationMap.shape.count == 3 {
                    // 形状: [1, height, width]
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    // 形状: [height, width]
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                
                // 检查是否为目标类别（主要是人物）
                let isTargetClass = self.isTargetClass(classIndex)
                
                if isTargetClass {
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
            throw SegmentationError.maskCreationFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 使用遮罩提取主体
    private func extractSubject(from originalImage: UIImage, with mask: UIImage) throws -> UIImage {
        guard let originalCGImage = originalImage.cgImage,
              let maskCGImage = mask.cgImage else {
            throw SegmentationError.subjectExtractionFailed
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
            throw SegmentationError.subjectExtractionFailed
        }
        
        filter.setValue(originalCIImage, forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: CIColor.clear).cropped(to: originalCIImage.extent), forKey: kCIInputBackgroundImageKey)
        filter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw SegmentationError.subjectExtractionFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 计算分割置信度
    private func calculateConfidence(_ segmentationMap: MLMultiArray) -> Float {
        // 根据形状确定宽度和高度
        let height: Int
        let width: Int
        
        if segmentationMap.shape.count == 3 {
            // 形状: [1, height, width]
            height = segmentationMap.shape[1].intValue
            width = segmentationMap.shape[2].intValue
        } else {
            // 形状: [height, width]
            height = segmentationMap.shape[0].intValue
            width = segmentationMap.shape[1].intValue
        }
        
        let totalPixels = width * height
        var foregroundPixels = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let classIndex: Int
                if segmentationMap.shape.count == 3 {
                    // 形状: [1, height, width]
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    // 形状: [height, width]
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                
                let isTargetClass = self.isTargetClass(classIndex)
                if isTargetClass {
                    foregroundPixels += 1
                }
            }
        }
        
        return Float(foregroundPixels) / Float(totalPixels)
    }
    
    /// 检查类别是否为目标类别
    private func isTargetClass(_ classIndex: Int) -> Bool {
        return targetClasses.contains(classIndex)
    }
}

// MARK: - Data Structures

struct SegmentationResult {
    let originalImage: UIImage
    let subjectImage: UIImage      // 提取的主体（带透明背景）
    let maskImage: UIImage         // 分割遮罩
    let confidence: Float          // 分割置信度 (0.0 - 1.0)
}

enum SegmentationError: LocalizedError {
    case modelNotInitialized
    case modelLoadFailed
    case imagePreprocessingFailed
    case predictionFailed(Error)
    case invalidPredictionResult
    case postProcessingFailed(Error)
    case maskCreationFailed
    case subjectExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "模型未初始化"
        case .modelLoadFailed:
            return "模型加载失败"
        case .imagePreprocessingFailed:
            return "图片预处理失败"
        case .predictionFailed(let error):
            return "预测失败: \(error.localizedDescription)"
        case .invalidPredictionResult:
            return "无效的预测结果"
        case .postProcessingFailed(let error):
            return "后处理失败: \(error.localizedDescription)"
        case .maskCreationFailed:
            return "遮罩创建失败"
        case .subjectExtractionFailed:
            return "主体提取失败"
        }
    }
}
