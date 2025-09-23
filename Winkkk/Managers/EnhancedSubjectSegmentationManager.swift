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
                return [64] // potted plant (正确索引)
            case .food:
                // 根据COCO数据集的正确索引: 52=banana, 53=apple, 54=sandwich, 55=orange, 56=broccoli, 57=carrot, 58=hot dog, 59=pizza, 60=donut, 61=cake
                return [52, 53, 54, 55, 56, 57, 58, 59, 60, 61]
            case .object:
                // 日常用品: 39=bottle, 40=wine glass, 41=cup, 42=fork, 43=knife, 44=spoon, 45=bowl, 46=banana等被移除
                // 家具: 62=chair, 63=couch, 65=bed, 67=dining table, 70=toilet等
                // 电子设备: 72=tv, 73=laptop, 74=mouse, 75=remote, 76=keyboard, 77=cell phone等
                return [39, 40, 41, 42, 43, 44, 45, 62, 63, 65, 67, 70, 72, 73, 74, 75, 76, 77, 78, 79]
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
        print("🎯 EnhancedSubjectSegmentationManager.segmentSubject 开始处理")
        print("📋 当前分割类别: \(currentCategory.displayName)")
        
        guard let visionModel = visionModel else {
            print("❌ 模型未初始化")
            completion(.failure(.modelNotInitialized))
            return
        }
        
        // 直接使用原图的CGImage，让Vision框架处理预处理
        guard let inputImage = image.cgImage else {
            print("❌ 无法获取CGImage")
            completion(.failure(.imagePreprocessingFailed))
            return
        }
        
        print("✅ 图片准备成功，开始DETR模型推理（通过Vision框架）")
        
        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            if let error = error {
                print("❌ DETR模型推理错误: \(error.localizedDescription)")
                completion(.failure(.predictionFailed(error)))
                return
            }
            
            print("📊 DETR模型推理完成，处理结果...")
            print("📊 结果数量: \(request.results?.count ?? 0)")
            
            // 详细分析所有输出
            if let results = request.results {
                for (index, result) in results.enumerated() {
                    print("🔍 输出 \(index): \(type(of: result))")
                    if let featureResult = result as? VNCoreMLFeatureValueObservation {
                        print("   特征名: \(featureResult.featureName ?? "unknown")")
                        if let multiArray = featureResult.featureValue.multiArrayValue {
                            print("   📐 实际模型输出形状: \(multiArray.shape) (分辨率: \(multiArray.shape[0])x\(multiArray.shape[1]))")
                            print("   🔢 数据类型: \(multiArray.dataType.rawValue)")
                            print("   💾 数据总量: \(multiArray.count) 个值")
                        }
                    }
                }
            }
            
            guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                  let segmentationMap = results.first?.featureValue.multiArrayValue else {
                print("❌ 无效的预测结果格式")
                completion(.failure(.invalidPredictionResult))
                return
            }
            
            print("✅ 获取到分割映射，shape: \(segmentationMap.shape)")
            
            self?.processEnhancedSegmentationResult(
                originalImage: image,
                segmentationMap: segmentationMap,
                completion: completion
            )
        }
        
        // 预处理方式选择 - 测试不同选项来优化效果
        // .centerCrop - 裁剪中心区域，可能丢失边缘重要信息
        // .scaleFit - 等比缩放，保持完整图像，短边会有透明区域  
        // .scaleFill - 等比缩放填充，可能改变纵横比，但物体更大更清晰
        request.imageCropAndScaleOption = .scaleFill // 改为填充模式，提升物体识别精度
        print("🖼️ 图像预处理设置: scaleFill (填充缩放，物体更大更清晰，可能轻微变形)")
        print("📐 原始图像尺寸: \(inputImage.width) x \(inputImage.height)")
        print("📐 模型输入尺寸: 将被缩放到模型要求的尺寸")
        
        // 高分辨率处理选项 - 尝试提升模型输入质量
        let handlerOptions: [VNImageOption : Any] = [
            .ciContext: CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()]),
            .properties: [:]
        ]
        
        let handler = VNImageRequestHandler(cgImage: inputImage, options: handlerOptions)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                print("🔄 执行DETR模型推理...")
                print("🔧 图像处理选项: 使用高质量CIContext")
                try handler.perform([request])
            } catch {
                print("❌ DETR模型推理执行失败: \(error.localizedDescription)")
                completion(.failure(.predictionFailed(error)))
            }
        }
    }
    
    /// 智能类别聚合 - 判断某个类别是否应该包含在指定分割类别中
    private func shouldIncludeClassForCategory(classIndex: Int, category: SegmentationCategory) -> Bool {
        // 获取类别名称
        let className = classIndex < cocoClassNames.count ? cocoClassNames[classIndex] : ""
        
        switch category {
        case .food:
            // 对于食物类别，包含一些可能与食物相关的类别
            // 例如：dining table(餐桌)可能与食物场景相关
            return classIndex == 67 // dining table - 在餐桌上的物体可能是食物
            
        case .object:
            // 对于物品类别，扩展包含更多日常用品
            return false // 暂时保持严格匹配
            
        case .person:
            // 人物相关，可能包含一些人体部位或相关物品
            return false
            
        case .animal:
            // 动物相关
            return false
            
        case .plant:
            // 植物相关，可能包含一些植物制品
            return false
            
        case .all:
            return false // 全部模式不需要额外聚合
        }
    }
    
    /// 获取检测到的类别信息
    func getDetectedClasses(from segmentationMap: MLMultiArray) -> [DetectedClass] {
        print("🔍 === 开始详细分析分割映射 ===")
        var detectedClasses: [Int: Int] = [:]
        
        // 安全检查shape维度，防止数组越界
        print("🔍 segmentationMap.shape: \(segmentationMap.shape), 维度数: \(segmentationMap.shape.count)")
        print("🔍 segmentationMap数据类型: \(segmentationMap.dataType)")
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
        
        print("📐 分割映射尺寸: \(width) x \(height) = \(width * height) 像素")
        
        // 统计每个类别的像素数量
        print("📊 开始统计像素分布...")
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
        print("📈 检测到 \(detectedClasses.count) 个不同的类别索引")
        
        // 分析原始类别分布
        print("🎯 原始类别分布（按像素数排序）:")
        let sortedRawClasses = detectedClasses.sorted { $0.value > $1.value }
        for (index, (classIndex, pixelCount)) in sortedRawClasses.enumerated() {
            let percentage = Double(pixelCount) / Double(totalPixels) * 100
            let className = classIndex < cocoClassNames.count ? cocoClassNames[classIndex] : "未知类别"
            print("   \(index + 1). 类别\(classIndex)(\(className)): \(pixelCount)像素 (\(String(format: "%.3f", percentage))%)")
            if index >= 9 { // 只显示前10个
                print("   ... (\(detectedClasses.count - 10)个其他类别)")
                break
            }
        }
        
        // 应用筛选条件并转换为DetectedClass对象
        let minPixelThreshold = totalPixels / 10000 // 放宽筛选条件，便于调试
        print("🎯 筛选阈值: \(minPixelThreshold) 像素 (\(String(format: "%.4f", Double(minPixelThreshold)/Double(totalPixels)*100))%)")
        
        let validClasses = detectedClasses.compactMap { (classIndex, pixelCount) -> DetectedClass? in
            let isValidIndex = classIndex < cocoClassNames.count
            let meetsThreshold = pixelCount > minPixelThreshold
            
            if !isValidIndex {
                print("   ❌ 类别\(classIndex): 索引超出范围 (最大: \(cocoClassNames.count-1))")
                return nil
            }
            
            if !meetsThreshold {
                let className = cocoClassNames[classIndex]
                print("   ❌ 类别\(classIndex)(\(className)): 像素数\(pixelCount)低于阈值\(minPixelThreshold)")
                return nil
            }
            
            let confidence = Float(pixelCount) / Float(totalPixels)
            let className = cocoClassNames[classIndex]
            print("   ✅ 类别\(classIndex)(\(className)): \(pixelCount)像素 (\(String(format: "%.2f", confidence*100))%)")
            
            return DetectedClass(
                classIndex: classIndex,
                className: className,
                confidence: confidence,
                pixelCount: pixelCount
            )
        }.sorted { $0.confidence > $1.confidence }
        
        print("🎉 最终有效检测结果: \(validClasses.count)个类别")
        for (index, detectedClass) in validClasses.enumerated() {
            print("   \(index + 1). \(detectedClass.className) - \(String(format: "%.2f", detectedClass.confidence * 100))% (\(detectedClass.pixelCount)像素)")
        }
        
        return validClasses
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
        print("🔧 开始处理增强分割结果")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                print("❌ self 已释放")
                return 
            }
            
            do {
                print("📊 获取检测到的类别...")
                // 获取检测到的类别
                let detectedClasses = self.getDetectedClasses(from: segmentationMap)
                print("✅ 检测到 \(detectedClasses.count) 个类别")
                
                print("🎭 创建遮罩...")
                // 创建遮罩
                let mask = try self.createEnhancedMask(from: segmentationMap)
                print("✅ 遮罩创建成功")
                
                print("✂️ 提取主体...")
                // 提取主体
                let subjectImage = try self.extractSubject(from: originalImage, with: mask)
                print("✅ 主体提取成功")
                
                print("📊 计算置信度...")
                // 计算置信度
                let confidence = self.calculateCategoryConfidence(segmentationMap)
                print("✅ 置信度: \(confidence)")
                
                // 创建增强结果
                let result = EnhancedSegmentationResult(
                    originalImage: originalImage,
                    subjectImage: subjectImage,
                    maskImage: mask,
                    confidence: confidence,
                    detectedClasses: detectedClasses,
                    category: self.currentCategory
                )
                
                print("🎉 分割结果创建成功，返回主线程")
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                
            } catch {
                print("❌ 后处理失败: \(error.localizedDescription)")
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
        print("🎯 === 开始创建遮罩 ===")
        print("🎯 当前分割类别: \(currentCategory)")
        print("🎯 目标类别索引: \(targetClasses)")
        print("🎯 目标类别名称: \(targetClasses.compactMap { $0 < cocoClassNames.count ? cocoClassNames[$0] : "未知(\($0))" })")
        print("📐 遮罩尺寸: \(width) x \(height) = \(width * height) 像素")
        
        var maskData = [UInt8](repeating: 0, count: width * height)
        var foregroundPixels = 0
        var classPixelCounts: [Int: Int] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let classIndex: Int
                if segmentationMap.shape.count == 2 {
                    classIndex = segmentationMap[[NSNumber(value: y), NSNumber(value: x)]].intValue
                } else {
                    classIndex = segmentationMap[[0, NSNumber(value: y), NSNumber(value: x)]].intValue
                }
                
                classPixelCounts[classIndex, default: 0] += 1
                
                // 智能类别聚合 - 检查是否为目标类别或相似类别
                let isTargetClass = targetClasses.contains(classIndex) || 
                                   shouldIncludeClassForCategory(classIndex: classIndex, category: currentCategory)
                
                if isTargetClass {
                    maskData[index] = 255 // 白色（前景）
                    foregroundPixels += 1
                } else {
                    maskData[index] = 0   // 黑色（背景）
                }
            }
        }
        
        // 输出遮罩创建统计信息
        print("📊 === 遮罩创建统计 ===")
        print("🎨 前景像素数: \(foregroundPixels) / \(width * height) (\(String(format: "%.2f", Double(foregroundPixels) / Double(width * height) * 100))%)")
        print("🎭 各类别像素分布:")
        for (classIndex, count) in classPixelCounts.sorted(by: { $0.value > $1.value }) {
            let className = classIndex < cocoClassNames.count ? cocoClassNames[classIndex] : "未知"
            let percentage = Double(count) / Double(width * height) * 100
            let isDirectTarget = targetClasses.contains(classIndex)
            let isSmartTarget = shouldIncludeClassForCategory(classIndex: classIndex, category: currentCategory)
            let status = isDirectTarget ? "✅目标" : (isSmartTarget ? "🧠智能" : "❌背景")
            print("   \(className)(\(classIndex)): \(count) 像素 (\(String(format: "%.2f", percentage))%) \(status)")
        }
        
        if foregroundPixels == 0 {
            print("⚠️ 警告: 没有检测到任何目标类别的像素，遮罩将完全为黑色！")
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
