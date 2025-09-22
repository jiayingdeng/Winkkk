//
//  EnhancedSubjectSegmentationManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/22.
//  增强的主体分割管理器 - 支持DETR模型和多类别分割
//

import UIKit
import CoreML
import Vision
import CoreImage
import Accelerate

class EnhancedSubjectSegmentationManager {
    
    // MARK: - Singleton
    static let shared = EnhancedSubjectSegmentationManager()
    private init() {}
    
    // MARK: - Properties
    
    // COCO数据集完整类别映射
    private let cocoClassNames: [String] = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light",
        "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
        "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
        "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard",
        "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
        "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
        "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote", "keyboard", "cell phone",
        "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
        "hair drier", "toothbrush"
    ]
    
    // 分类配置
    enum SegmentationCategory: String, CaseIterable {
        case person = "人物"
        case animal = "动物"
        case plant = "植物"
        case food = "食物"
        case object = "物品"
        case all = "全部"
        
        var targetClasses: Set<Int> {
            switch self {
            case .person:
                return [0] // person
            case .animal:
                return [14, 15, 16, 17, 18, 19, 20, 21, 22, 23] // bird, cat, dog, horse, sheep, cow, elephant, bear, zebra, giraffe
            case .plant:
                return [58] // potted plant
            case .food:
                return [46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61] // banana, apple, sandwich, orange, broccoli, carrot, hot dog, pizza, donut, cake
            case .object:
                return [39, 40, 41, 42, 43, 44, 45] // bottle, wine glass, cup, fork, knife, spoon, bowl
            case .all:
                return Set(0...79) // 所有COCO类别
            }
        }
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    private var currentCategory: SegmentationCategory = .all
    private var model: DETRResnet50SemanticSegmentationF16P8?
    private var visionModel: VNCoreMLModel?
    private let context = CIContext()
    
    // 分割结果回调
    typealias EnhancedSegmentationCompletion = (Result<EnhancedSegmentationResult, SegmentationError>) -> Void
    
    // MARK: - Public Methods
    
    /// 初始化分割管理器
    func initialize() throws {
        let modelConfig = MLModelConfiguration()
        modelConfig.computeUnits = .all
        
        model = try DETRResnet50SemanticSegmentationF16P8(configuration: modelConfig)
        guard let model = model else {
            throw SegmentationError.modelLoadFailed
        }
        
        visionModel = try VNCoreMLModel(for: model.model)
        
        print("✅ EnhancedSubjectSegmentationManager (DETR) 初始化成功")
        print("✅ 支持类别: \(SegmentationCategory.allCases.map { $0.displayName }.joined(separator: ", "))")
    }
    
    /// 设置分割类别
    func setSegmentationCategory(_ category: SegmentationCategory) {
        currentCategory = category
        print("🎯 分割类别设置为: \(category.displayName)")
    }
    
    /// 获取当前分割类别
    func getCurrentCategory() -> SegmentationCategory {
        return currentCategory
    }
    
    /// 检查模型是否已准备就绪
    func isModelReady() -> Bool {
        return model != nil && visionModel != nil
    }
    
    /// 对图片进行主体分割
    func segmentSubject(from image: UIImage, completion: @escaping EnhancedSegmentationCompletion) {
        guard let visionModel = visionModel else {
            completion(.failure(.modelNotInitialized))
            return
        }
        
        guard let inputImage = preprocessImage(image) else {
            completion(.failure(.imagePreprocessingFailed))
            return
        }
        
        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            if let error = error {
                completion(.failure(.predictionFailed(error)))
                return
            }
            
            guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                  let segmentationMap = results.first?.featureValue.multiArrayValue else {
                completion(.failure(.invalidPredictionResult))
                return
            }
            
            self?.processEnhancedSegmentationResult(
                originalImage: image,
                segmentationMap: segmentationMap,
                completion: completion
            )
        }
        
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: inputImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(.predictionFailed(error)))
            }
        }
    }
    
    /// 获取检测到的类别信息
    func getDetectedClasses(from segmentationMap: MLMultiArray) -> [DetectedClass] {
        var detectedClasses: [Int: Int] = [:]
        
        // 安全检查shape维度，防止数组越界
        print("🔍 segmentationMap.shape: \(segmentationMap.shape), 维度数: \(segmentationMap.shape.count)")
        guard segmentationMap.shape.count >= 2 else {
            print("❌ segmentationMap.shape 维度不足: \(segmentationMap.shape)")
            return []
        }
        
        let height: Int
        let width: Int
        
        // 根据shape的维度数来确定height和width的位置
        if segmentationMap.shape.count == 2 {
            // 2D: [height, width]
            height = segmentationMap.shape[0].intValue
            width = segmentationMap.shape[1].intValue
        } else {
            // 3D: [batch, height, width] 或其他格式
            height = segmentationMap.shape[1].intValue
            width = segmentationMap.shape[2].intValue
        }
        
        // 统计每个类别的像素数量
        for y in 0..<height {
            for x in 0..<width {
                let classIndex: Int
                if segmentationMap.shape.count == 2 {
                    // 2D数组访问: [y, x]
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    // 3D数组访问: [batch, y, x]
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                detectedClasses[classIndex, default: 0] += 1
            }
        }
        
        let totalPixels = width * height
        
        // 转换为DetectedClass对象并排序
        return detectedClasses.compactMap { (classIndex, pixelCount) -> DetectedClass? in
            guard classIndex < cocoClassNames.count && pixelCount > totalPixels / 1000 else { return nil } // 过滤掉占比太小的类别
            
            let confidence = Float(pixelCount) / Float(totalPixels)
            return DetectedClass(
                classIndex: classIndex,
                className: cocoClassNames[classIndex],
                confidence: confidence,
                pixelCount: pixelCount
            )
        }.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Private Methods
    
    private func preprocessImage(_ image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let targetSize = CGSize(width: 800, height: 800)
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
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        return context.makeImage()
    }
    
    private func processEnhancedSegmentationResult(
        originalImage: UIImage,
        segmentationMap: MLMultiArray,
        completion: @escaping EnhancedSegmentationCompletion
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 获取检测到的类别
                let detectedClasses = self.getDetectedClasses(from: segmentationMap)
                
                // 创建遮罩
                let mask = try self.createEnhancedMask(from: segmentationMap)
                
                // 提取主体
                let subjectImage = try self.extractSubject(from: originalImage, with: mask)
                
                // 计算置信度
                let confidence = self.calculateCategoryConfidence(segmentationMap)
                
                // 创建增强结果
                let result = EnhancedSegmentationResult(
                    originalImage: originalImage,
                    subjectImage: subjectImage,
                    maskImage: mask,
                    confidence: confidence,
                    detectedClasses: detectedClasses,
                    category: self.currentCategory
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
    
    private func createEnhancedMask(from segmentationMap: MLMultiArray) throws -> UIImage {
        // 安全获取尺寸
        guard segmentationMap.shape.count >= 2 else {
            throw SegmentationError.invalidPredictionResult
        }
        
        let height: Int
        let width: Int
        
        if segmentationMap.shape.count == 2 {
            height = segmentationMap.shape[0].intValue
            width = segmentationMap.shape[1].intValue
        } else {
            height = segmentationMap.shape[1].intValue
            width = segmentationMap.shape[2].intValue
        }
        
        let targetClasses = currentCategory.targetClasses
        var maskData = [UInt8](repeating: 0, count: width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let classIndex: Int
                if segmentationMap.shape.count == 2 {
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                
                if targetClasses.contains(classIndex) {
                    maskData[index] = 255 // 白色（前景）
                } else {
                    maskData[index] = 0   // 黑色（背景）
                }
            }
        }
        
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
    
    private func extractSubject(from originalImage: UIImage, with mask: UIImage) throws -> UIImage {
        guard let originalCGImage = originalImage.cgImage,
              let maskCGImage = mask.cgImage else {
            throw SegmentationError.subjectExtractionFailed
        }
        
        let originalCIImage = CIImage(cgImage: originalCGImage)
        let maskCIImage = CIImage(cgImage: maskCGImage)
        
        let scaleX = originalCIImage.extent.width / maskCIImage.extent.width
        let scaleY = originalCIImage.extent.height / maskCIImage.extent.height
        let scaledMask = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
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
    
    private func calculateCategoryConfidence(_ segmentationMap: MLMultiArray) -> Float {
        // 安全获取尺寸
        guard segmentationMap.shape.count >= 2 else {
            return 0.0
        }
        
        let height: Int
        let width: Int
        
        if segmentationMap.shape.count == 2 {
            height = segmentationMap.shape[0].intValue
            width = segmentationMap.shape[1].intValue
        } else {
            height = segmentationMap.shape[1].intValue
            width = segmentationMap.shape[2].intValue
        }
        
        let targetClasses = currentCategory.targetClasses
        let totalPixels = width * height
        var foregroundPixels = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let classIndex: Int
                if segmentationMap.shape.count == 2 {
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                if targetClasses.contains(classIndex) {
                    foregroundPixels += 1
                }
            }
        }
        
        return Float(foregroundPixels) / Float(totalPixels)
    }
}

// MARK: - Enhanced Data Structures

struct EnhancedSegmentationResult {
    let originalImage: UIImage
    let subjectImage: UIImage
    let maskImage: UIImage
    let confidence: Float
    let detectedClasses: [DetectedClass]
    let category: EnhancedSubjectSegmentationManager.SegmentationCategory
}

struct DetectedClass {
    let classIndex: Int
    let className: String
    let confidence: Float
    let pixelCount: Int
}
