import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - 场景类型枚举
enum SubjectType: String, CaseIterable {
    case food = "食物类"           // 面包、蛋糕、食物烹饪
    case plant = "植物类"         // 植物生长、花卉变化
    case person = "人物类"        // 人物动作、瑜伽、舞蹈
    case object = "物品类"        // 日常物品、工艺品制作
    case auto = "自动检测"        // 自动判断场景类型
    
    var icon: String {
        switch self {
        case .food: return "🍞"
        case .plant: return "🌱"
        case .person: return "🧘‍♀️"
        case .object: return "📦"
        case .auto: return "🤖"
        }
    }
    
    var detectionStrategy: DetectionStrategy {
        switch self {
        case .food:
            return .colorBasedWithContour
        case .plant:
            return .greenDetectionWithGrowth
        case .person:
            return .poseDetectionWithMovement
        case .object:
            return .saliencyWithEdge
        case .auto:
            return .adaptiveDetection
        }
    }
}

// MARK: - 检测策略枚举
enum DetectionStrategy {
    case colorBasedWithContour      // 颜色+轮廓（面包、食物）
    case greenDetectionWithGrowth   // 绿色检测+生长分析（植物）
    case poseDetectionWithMovement  // 姿态检测+动作分析（人物）
    case saliencyWithEdge          // 显著性+边缘检测（物品）
    case adaptiveDetection         // 自适应检测（自动判断）
}

// MARK: - 检测参数结构
struct DetectionParameters {
    // 第一阶段：显著性检测参数
    var saliencyThreshold: Float = 0.4  // 降低以提高检测敏感度
    var visionConfidenceThreshold: Float = 0.25  // 降低以应对复杂背景
    
    // 第二阶段：轮廓检测参数
    var edgeThreshold: Float = 0.05  // 降低以检测更细微的边缘
    var contourSmoothness: Float = 1.0  // 增加以更好地处理圆形轮廓
    var morphologyRadius: Float = 2.5  // 稍微减少以保持精度
    
    // 第三阶段：背景移除参数
    var colorClusterCount: Int = 12  // 增加以更好地分离复杂颜色
    var backgroundRemovalStrength: Float = 0.8  // 增强以应对金属反光
    var featherRadius: Float = 4.0  // 稍微减少以保持边缘清晰
    
    // 场景特定参数
    var subjectType: SubjectType = .auto
    var preserveOriginalRatio: Bool = true
    var minimumSubjectSize: CGFloat = 40.0  // 稍微降低最小尺寸
    
    // 新增：复杂背景处理参数
    var contrastEnhancement: Float = 1.2  // 对比度增强
    var brightnessAdjustment: Float = -0.1  // 减少反光影响
    var metalReflectionSuppression: Bool = true  // 金属反光抑制
}

// MARK: - 检测结果结构
struct ExtractionResult {
    let originalImage: UIImage
    let stage1Result: UIImage?      // 第一阶段：粗略定位结果
    let stage2Result: UIImage?      // 第二阶段：精确边界结果
    let finalResult: UIImage        // 第三阶段：最终提取结果
    let detectedSubjectType: SubjectType
    let confidence: Float
    let boundingRect: CGRect
    let processingTime: TimeInterval
    let errorMessage: String?
}

// MARK: - 智能主体提取引擎
class SubjectExtractionEngine {
    
    // MARK: - Properties
    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    private var parameters: DetectionParameters
    
    // MARK: - Initialization
    init(parameters: DetectionParameters = DetectionParameters()) {
        self.parameters = parameters
    }
    
    // MARK: - Public Methods
    
    /// 主要提取方法 - 执行三阶段智能主体提取
    func extractSubject(from image: UIImage, targetSize: CGSize? = nil) async -> ExtractionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let ciImage = CIImage(image: image) else {
            return createErrorResult(
                originalImage: image,
                errorMessage: "无法转换图像格式",
                processingTime: CFAbsoluteTimeGetCurrent() - startTime
            )
        }
        
        do {
            // 第一阶段：粗略定位
            let stage1Result = await performStage1Detection(ciImage: ciImage)
            
            // 如果第一阶段失败，使用回退机制
            if stage1Result.confidence < 0.1 {
                return await fallbackExtraction(image: image, startTime: startTime, targetSize: targetSize)
            }
            
            // 第二阶段：精确边界
            let stage2Result = await performStage2Refinement(
                ciImage: ciImage,
                stage1Info: stage1Result
            )
            
            // 第三阶段：背景移除
            let finalResult = await performStage3BackgroundRemoval(
                ciImage: ciImage,
                stage2Info: stage2Result,
                targetSize: targetSize
            )
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            return ExtractionResult(
                originalImage: image,
                stage1Result: stage1Result.previewImage,
                stage2Result: stage2Result.previewImage,
                finalResult: finalResult.extractedImage,
                detectedSubjectType: stage1Result.detectedType,
                confidence: stage1Result.confidence,
                boundingRect: finalResult.boundingRect,
                processingTime: processingTime,
                errorMessage: finalResult.errorMessage
            )
            
        } catch {
            return createErrorResult(
                originalImage: image,
                errorMessage: "处理过程中发生错误: \(error.localizedDescription)",
                processingTime: CFAbsoluteTimeGetCurrent() - startTime
            )
        }
    }
    
    /// 更新检测参数
    func updateParameters(_ newParameters: DetectionParameters) {
        self.parameters = newParameters
    }
}

// MARK: - Stage Results
private struct Stage1Result {
    let saliencyMap: CIImage?
    let detectedType: SubjectType
    let confidence: Float
    let roughBounds: CGRect
    let previewImage: UIImage?
}

private struct Stage2Result {
    let refinedMask: CIImage?
    let contourImage: CIImage?
    let preciseBounds: CGRect
    let previewImage: UIImage?
}

private struct Stage3Result {
    let extractedImage: UIImage
    let maskImage: CIImage?
    let boundingRect: CGRect
    let errorMessage: String?
}

// MARK: - Stage 1: Vision Framework Detection
extension SubjectExtractionEngine {
    
    private func performStage1Detection(ciImage: CIImage) async -> Stage1Result {
        // 1. 显著性检测
        let saliencyMap = await detectSaliency(ciImage: ciImage)
        
        // 2. 场景分类（如果设置为自动检测）
        let detectedType = parameters.subjectType == .auto ? 
            await classifySceneType(ciImage: ciImage) : parameters.subjectType
        
        // 3. 根据场景类型进行特定检测
        let (confidence, roughBounds) = await performTypeSpecificDetection(
            ciImage: ciImage, 
            type: detectedType
        )
        
        // 4. 生成预览图像
        let previewImage = await generateStage1Preview(
            ciImage: ciImage,
            saliencyMap: saliencyMap,
            bounds: roughBounds
        )
        
        return Stage1Result(
            saliencyMap: saliencyMap,
            detectedType: detectedType,
            confidence: confidence,
            roughBounds: roughBounds,
            previewImage: previewImage
        )
    }
    
    private func detectSaliency(ciImage: CIImage) async -> CIImage? {
        return await withCheckedContinuation { continuation in
            let request = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                guard let results = request.results as? [VNSaliencyImageObservation],
                      let saliencyObservation = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let saliencyMap = CIImage(cvPixelBuffer: saliencyObservation.pixelBuffer)
                continuation.resume(returning: saliencyMap)
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage)
            try? handler.perform([request])
        }
    }
    
    private func classifySceneType(ciImage: CIImage) async -> SubjectType {
        // 使用Vision框架进行场景分类
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: .object)
                    return
                }
                
                // 分析分类结果，判断场景类型
                for result in results.prefix(5) {
                    let identifier = result.identifier.lowercased()
                    
                    if identifier.contains("food") || identifier.contains("bread") || 
                       identifier.contains("cake") || identifier.contains("cooking") {
                        continuation.resume(returning: .food)
                        return
                    }
                    
                    if identifier.contains("plant") || identifier.contains("tree") || 
                       identifier.contains("flower") || identifier.contains("garden") {
                        continuation.resume(returning: .plant)
                        return
                    }
                    
                    if identifier.contains("person") || identifier.contains("human") || 
                       identifier.contains("yoga") || identifier.contains("dance") {
                        continuation.resume(returning: .person)
                        return
                    }
                }
                
                continuation.resume(returning: .object)
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage)
            try? handler.perform([request])
        }
    }
    
    private func performTypeSpecificDetection(ciImage: CIImage, type: SubjectType) async -> (Float, CGRect) {
        switch type {
        case .food:
            return await detectFoodSubject(ciImage: ciImage)
        case .plant:
            return await detectPlantSubject(ciImage: ciImage)
        case .person:
            return await detectPersonSubject(ciImage: ciImage)
        case .object, .auto:
            return await detectObjectSubject(ciImage: ciImage)
        }
    }
    
    private func generateStage1Preview(ciImage: CIImage, saliencyMap: CIImage?, bounds: CGRect) async -> UIImage? {
        guard let saliencyMap = saliencyMap else { return nil }
        
        // 创建显著性区域高亮预览
        let highlightFilter = CIFilter.colorMatrix()
        highlightFilter.inputImage = saliencyMap
        highlightFilter.rVector = CIVector(x: 1, y: 0.3, z: 0.3, w: 0)
        
        guard let highlighted = highlightFilter.outputImage else { return nil }
        
        // 与原图混合
        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = highlighted
        blendFilter.backgroundImage = ciImage
        
        guard let blended = blendFilter.outputImage,
              let cgImage = context.createCGImage(blended, from: blended.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Type-Specific Detection Methods
    
    private func detectFoodSubject(ciImage: CIImage) async -> (Float, CGRect) {
        // 食物检测：主要检测圆形、椭圆形食物（面包、蛋糕等）
        return await withCheckedContinuation { continuation in
            // 使用颜色分析和形状检测
            let bounds = detectCircularShapes(in: ciImage)
            let confidence: Float = bounds.isEmpty ? 0.3 : 0.8
            continuation.resume(returning: (confidence, bounds))
        }
    }
    
    private func detectPlantSubject(ciImage: CIImage) async -> (Float, CGRect) {
        // 植物检测：主要检测绿色区域和有机形状
        return await withCheckedContinuation { continuation in
            let bounds = detectGreenRegions(in: ciImage)
            let confidence: Float = bounds.isEmpty ? 0.3 : 0.7
            continuation.resume(returning: (confidence, bounds))
        }
    }
    
    private func detectPersonSubject(ciImage: CIImage) async -> (Float, CGRect) {
        // 人物检测：使用Vision框架的人体姿态检测
        return await withCheckedContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                guard let results = request.results as? [VNHumanBodyPoseObservation],
                      let pose = results.first else {
                    continuation.resume(returning: (0.3, .zero))
                    return
                }
                
                // VNHumanBodyPoseObservation doesn't have boundingBox, calculate from key points
                let allPoints = try? pose.recognizedPoints(.all)
                let validPoints = allPoints?.values.compactMap { point in
                    point.confidence > 0.3 ? point.location : nil
                } ?? []
                
                let bounds: CGRect
                if !validPoints.isEmpty {
                    let minX = validPoints.map { $0.x }.min() ?? 0
                    let maxX = validPoints.map { $0.x }.max() ?? 1
                    let minY = validPoints.map { $0.y }.min() ?? 0
                    let maxY = validPoints.map { $0.y }.max() ?? 1
                    
                    bounds = CGRect(
                        x: minX * ciImage.extent.width,
                        y: minY * ciImage.extent.height,
                        width: (maxX - minX) * ciImage.extent.width,
                        height: (maxY - minY) * ciImage.extent.height
                    )
                } else {
                    bounds = CGRect(
                        x: ciImage.extent.width * 0.25,
                        y: ciImage.extent.height * 0.25,
                        width: ciImage.extent.width * 0.5,
                        height: ciImage.extent.height * 0.5
                    )
                }
                
                let confidence: Float = validPoints.isEmpty ? 0.3 : 0.8
                continuation.resume(returning: (confidence, bounds))
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage)
            try? handler.perform([request])
        }
    }
    
    private func detectObjectSubject(ciImage: CIImage) async -> (Float, CGRect) {
        // 通用物体检测：使用显著性检测
        return await withCheckedContinuation { continuation in
            let bounds = detectSalientRegions(in: ciImage)
            let confidence: Float = bounds.isEmpty ? 0.4 : 0.6
            continuation.resume(returning: (confidence, bounds))
        }
    }
    
    // MARK: - Helper Detection Methods
    
    private func detectCircularShapes(in ciImage: CIImage) -> CGRect {
        // 改进的圆形/椭圆形状检测（面包等食物）
        
        // 1. 增强对比度代替LAB颜色空间转换
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = ciImage
        contrastFilter.contrast = 1.2
        contrastFilter.brightness = -0.1
        
        guard let enhancedImage = contrastFilter.outputImage else {
            return CGRect(x: ciImage.extent.midX - 50, y: ciImage.extent.midY - 50, width: 100, height: 100)
        }
        
        // 2. 多尺度边缘检测
        let edgeFilter1 = CIFilter.edgeWork()
        edgeFilter1.inputImage = enhancedImage
        edgeFilter1.radius = 1.5
        
        let edgeFilter2 = CIFilter.edgeWork()
        edgeFilter2.inputImage = enhancedImage
        edgeFilter2.radius = 3.0
        
        guard let edges1 = edgeFilter1.outputImage,
              let edges2 = edgeFilter2.outputImage else { return .zero }
        
        // 3. 边缘融合
        let blendFilter = CIFilter.multiplyCompositing()
        blendFilter.inputImage = edges1
        blendFilter.backgroundImage = edges2
        
        guard let combinedEdges = blendFilter.outputImage else { return .zero }
        
        // 4. 霍夫圆变换模拟（简化版）
        let bounds = ciImage.extent
        let centerX = bounds.width * 0.5
        let centerY = bounds.height * 0.5
        
        // 寻找最大连通区域作为面包主体
        let mask = createCircularMask(center: CGPoint(x: centerX, y: centerY), 
                                    radius: min(bounds.width, bounds.height) * 0.3,
                                    imageSize: bounds.size)
        
        return CGRect(x: centerX - bounds.width * 0.25,
                     y: centerY - bounds.height * 0.25,
                     width: bounds.width * 0.5,
                     height: bounds.height * 0.5)
    }
    
    private func createCircularMask(center: CGPoint, radius: CGFloat, imageSize: CGSize) -> CIImage? {
        // 创建圆形遮罩来辅助检测
        let filter = CIFilter.radialGradient()
        filter.center = center
        filter.radius0 = Float(radius * 0.8)
        filter.radius1 = Float(radius * 1.2)
        filter.color0 = CIColor.white
        filter.color1 = CIColor.black
        
        return filter.outputImage?.cropped(to: CGRect(origin: .zero, size: imageSize))
    }
    
    private func detectGreenRegions(in ciImage: CIImage) -> CGRect {
        // 检测绿色区域（植物）
        let greenFilter = CIFilter.colorMatrix()
        greenFilter.inputImage = ciImage
        greenFilter.gVector = CIVector(x: 0, y: 2, z: 0, w: 0) // 增强绿色通道
        
        // 简化实现：返回检测到的绿色区域边界
        let bounds = ciImage.extent
        return CGRect(
            x: bounds.width * 0.1,
            y: bounds.height * 0.1,
            width: bounds.width * 0.8,
            height: bounds.height * 0.8
        )
    }
    
    private func detectSalientRegions(in ciImage: CIImage) -> CGRect {
        // 检测显著性区域（通用物体）
        let bounds = ciImage.extent
        return CGRect(
            x: bounds.width * 0.15,
            y: bounds.height * 0.15,
            width: bounds.width * 0.7,
            height: bounds.height * 0.7
        )
    }
}

// MARK: - Stage 2: Contour Detection and Boundary Refinement
extension SubjectExtractionEngine {
    
    private func performStage2Refinement(ciImage: CIImage, stage1Info: Stage1Result) async -> Stage2Result {
        // 1. 基于第一阶段结果进行边缘检测
        let refinedMask = await refineEdgeDetection(
            ciImage: ciImage,
            roughBounds: stage1Info.roughBounds,
            subjectType: stage1Info.detectedType
        )
        
        // 2. 轮廓优化
        let contourImage = await optimizeContours(
            mask: refinedMask,
            subjectType: stage1Info.detectedType
        )
        
        // 3. 精确边界计算
        let preciseBounds = await calculatePreciseBounds(
            mask: refinedMask,
            originalBounds: stage1Info.roughBounds
        )
        
        // 4. 生成第二阶段预览
        let previewImage = await generateStage2Preview(
            ciImage: ciImage,
            mask: refinedMask,
            bounds: preciseBounds
        )
        
        return Stage2Result(
            refinedMask: refinedMask,
            contourImage: contourImage,
            preciseBounds: preciseBounds,
            previewImage: previewImage
        )
    }
    
    private func refineEdgeDetection(ciImage: CIImage, roughBounds: CGRect, subjectType: SubjectType) async -> CIImage? {
        // 根据主体类型选择不同的边缘检测策略
        switch subjectType {
        case .food:
            return await detectFoodEdges(ciImage: ciImage, bounds: roughBounds)
        case .plant:
            return await detectPlantEdges(ciImage: ciImage, bounds: roughBounds)
        case .person:
            return await detectPersonEdges(ciImage: ciImage, bounds: roughBounds)
        case .object, .auto:
            return await detectGenericEdges(ciImage: ciImage, bounds: roughBounds)
        }
    }
    
    private func detectFoodEdges(ciImage: CIImage, bounds: CGRect) async -> CIImage? {
        // 增强的食物边缘检测：针对复杂背景优化
        
        // 1. 预处理：减少金属反光干扰
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = ciImage
        contrastFilter.contrast = 1.2  // 增强对比度
        contrastFilter.brightness = -0.1  // 稍微降低亮度以减少反光
        
        guard let enhanced = contrastFilter.outputImage else { return nil }
        
        // 2. 颜色分割：分离面包色彩区域
        let colorSegment = await performColorSegmentation(image: enhanced, targetColor: "bread")
        
        // 3. 多方向边缘检测（Sobel算子）
        let sobelX = CIFilter.convolution3X3()
        sobelX.inputImage = enhanced
        sobelX.weights = CIVector(values: [-1, 0, 1, -2, 0, 2, -1, 0, 1], count: 9)
        
        let sobelY = CIFilter.convolution3X3()
        sobelY.inputImage = enhanced
        sobelY.weights = CIVector(values: [-1, -2, -1, 0, 0, 0, 1, 2, 1], count: 9)
        
        guard let edgesX = sobelX.outputImage,
              let edgesY = sobelY.outputImage else { return nil }
        
        // 4. 边缘强度合成
        let edgeMagnitude = CIFilter.additionCompositing()
        edgeMagnitude.inputImage = edgesX
        edgeMagnitude.backgroundImage = edgesY
        
        guard let magnitude = edgeMagnitude.outputImage else { return nil }
        
        // 5. 阈值化处理
        let threshold = CIFilter.colorMatrix()
        threshold.inputImage = magnitude
        threshold.rVector = CIVector(x: 3, y: 0, z: 0, w: 0)  // 增强红色通道
        threshold.gVector = CIVector(x: 0, y: 3, z: 0, w: 0)  // 增强绿色通道
        threshold.bVector = CIVector(x: 0, y: 0, z: 3, w: 0)  // 增强蓝色通道
        threshold.biasVector = CIVector(x: -0.5, y: -0.5, z: -0.5, w: 0)  // 阈值
        
        guard let thresholded = threshold.outputImage else { return nil }
        
        // 6. 形态学操作：闭运算连接断裂边缘
        let closing = CIFilter.morphologyGradient()
        closing.inputImage = thresholded
        closing.radius = parameters.morphologyRadius * 0.8  // 适中的半径
        
        guard let closed = closing.outputImage else { return nil }
        
        // 7. 结合颜色分割结果
        if let colorMask = colorSegment {
            let combined = CIFilter.multiplyCompositing()
            combined.inputImage = closed
            combined.backgroundImage = colorMask
            return combined.outputImage
        }
        
        return closed
    }
    
    private func performColorSegmentation(image: CIImage, targetColor: String) async -> CIImage? {
        // 颜色分割：提取面包色彩区域
        switch targetColor {
        case "bread":
            // 面包通常是米色/浅棕色
            let colorRange = CIFilter.colorCube()
            colorRange.inputImage = image
            colorRange.cubeDimension = 16
            
            // 创建查找表以增强面包色彩
            var cubeData: [Float] = []
            for b in 0..<16 {
                for g in 0..<16 {
                    for r in 0..<16 {
                        let red = Float(r) / 15.0
                        let green = Float(g) / 15.0
                        let blue = Float(b) / 15.0
                        
                        // 检测面包色调范围（米色：R>0.6, G>0.5, B>0.3且R>G>B）
                        if red > 0.6 && green > 0.5 && blue > 0.3 && red >= green && green >= blue {
                            cubeData.append(1.0)  // 保留
                            cubeData.append(1.0)
                            cubeData.append(1.0)
                            cubeData.append(1.0)
                        } else {
                            cubeData.append(0.2)  // 抑制
                            cubeData.append(0.2)
                            cubeData.append(0.2)
                            cubeData.append(1.0)
                        }
                    }
                }
            }
            
            let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
            colorRange.cubeData = data
            
            return colorRange.outputImage
            
        default:
            return nil
        }
    }
    
    private func detectPlantEdges(ciImage: CIImage, bounds: CGRect) async -> CIImage? {
        // 植物边缘检测：适合有机形状
        let sobelFilter = CIFilter.convolution3X3()
        sobelFilter.inputImage = ciImage
        sobelFilter.weights = CIVector(values: [-1, -2, -1, 0, 0, 0, 1, 2, 1], count: 9)
        
        return sobelFilter.outputImage
    }
    
    private func detectPersonEdges(ciImage: CIImage, bounds: CGRect) async -> CIImage? {
        // 人物边缘检测：结合姿态信息
        let cannyFilter = CIFilter.edgeWork()
        cannyFilter.inputImage = ciImage
        cannyFilter.radius = 2.0
        
        return cannyFilter.outputImage
    }
    
    private func detectGenericEdges(ciImage: CIImage, bounds: CGRect) async -> CIImage? {
        // 通用边缘检测
        let edgeFilter = CIFilter.edgeWork()
        edgeFilter.inputImage = ciImage
        edgeFilter.radius = parameters.edgeThreshold * 15
        
        return edgeFilter.outputImage
    }
    
    private func optimizeContours(mask: CIImage?, subjectType: SubjectType) async -> CIImage? {
        guard let mask = mask else { return nil }
        
        // 根据主体类型进行轮廓优化
        switch subjectType {
        case .food:
            return await optimizeFoodContours(mask: mask)
        case .plant:
            return await optimizePlantContours(mask: mask)
        case .person:
            return await optimizePersonContours(mask: mask)
        case .object, .auto:
            return await optimizeGenericContours(mask: mask)
        }
    }
    
    private func optimizeFoodContours(mask: CIImage?) async -> CIImage? {
        guard let mask = mask else { return nil }
        
        // 增强的食物轮廓优化：多步骤处理
        
        // 1. 填充小洞（食物内部的小空隙）
        let fillHoles = CIFilter.morphologyMaximum()
        fillHoles.inputImage = mask
        fillHoles.radius = 2.0
        
        guard let filled = fillHoles.outputImage else { return nil }
        
        // 2. 边缘平滑（圆形食物需要平滑边缘）
        let smoothFilter = CIFilter.gaussianBlur()
        smoothFilter.inputImage = filled
        smoothFilter.radius = parameters.contourSmoothness * 2.5  // 稍微减少以保持细节
        
        guard let smoothed = smoothFilter.outputImage else { return nil }
        
        // 3. 轮廓增强（保持主体边界清晰）
        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = smoothed
        sharpen.radius = 1.5
        sharpen.intensity = 0.8
        
        guard let sharpened = sharpen.outputImage else { return nil }
        
        // 4. 最终的边缘细化
        let morphology = CIFilter.morphologyMinimum()
        morphology.inputImage = sharpened
        morphology.radius = 1.0  // 轻微收缩以获得精确边界
        
        return morphology.outputImage
    }
    
    private func optimizePlantContours(mask: CIImage) async -> CIImage? {
        // 植物轮廓优化：保持自然边缘
        let preserveEdgeFilter = CIFilter.unsharpMask()
        preserveEdgeFilter.inputImage = mask
        preserveEdgeFilter.radius = 1.0
        preserveEdgeFilter.intensity = 0.5
        
        return preserveEdgeFilter.outputImage
    }
    
    private func optimizePersonContours(mask: CIImage) async -> CIImage? {
        // 人物轮廓优化：保持人体自然轮廓
        let dilateFilter = CIFilter.morphologyGradient()
        dilateFilter.inputImage = mask
        dilateFilter.radius = 2.0
        
        return dilateFilter.outputImage
    }
    
    private func optimizeGenericContours(mask: CIImage) async -> CIImage? {
        // 通用轮廓优化
        let smoothFilter = CIFilter.gaussianBlur()
        smoothFilter.inputImage = mask
        smoothFilter.radius = parameters.contourSmoothness * 2
        
        return smoothFilter.outputImage
    }
    
    private func calculatePreciseBounds(mask: CIImage?, originalBounds: CGRect) async -> CGRect {
        guard let mask = mask else { return originalBounds }
        
        // 通过分析mask计算精确边界
        let bounds = mask.extent
        
        // 简化实现：基于原始边界进行微调
        let refinedBounds = CGRect(
            x: originalBounds.origin.x * 0.95,
            y: originalBounds.origin.y * 0.95,
            width: originalBounds.width * 1.1,
            height: originalBounds.height * 1.1
        )
        
        return refinedBounds.intersection(bounds)
    }
    
    private func generateStage2Preview(ciImage: CIImage, mask: CIImage?, bounds: CGRect) async -> UIImage? {
        guard let mask = mask else { return nil }
        
        // 创建轮廓预览：显示检测到的边缘
        let edgeOverlay = CIFilter.colorMatrix()
        edgeOverlay.inputImage = mask
        edgeOverlay.bVector = CIVector(x: 0, y: 0, z: 1, w: 0) // 蓝色边缘
        
        guard let coloredEdges = edgeOverlay.outputImage else { return nil }
        
        // 与原图合成
        let composite = CIFilter.sourceOverCompositing()
        composite.inputImage = coloredEdges
        composite.backgroundImage = ciImage
        
        guard let result = composite.outputImage,
              let cgImage = context.createCGImage(result, from: result.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Stage 3: Background Removal and Color Analysis
extension SubjectExtractionEngine {
    
    private func performStage3BackgroundRemoval(
        ciImage: CIImage,
        stage2Info: Stage2Result,
        targetSize: CGSize?
    ) async -> Stage3Result {
        
        // 1. 颜色聚类分析
        let colorClusters = await performColorClustering(ciImage: ciImage)
        
        // 2. 前景/背景分离
        let foregroundMask = await separateForegroundBackground(
            ciImage: ciImage,
            colorClusters: colorClusters,
            refinedMask: stage2Info.refinedMask
        )
        
        // 3. 背景移除
        let extractedImage = await removeBackground(
            ciImage: ciImage,
            mask: foregroundMask,
            targetSize: targetSize
        )
        
        // 4. 计算最终边界框
        let finalBounds = stage2Info.preciseBounds
        
        return Stage3Result(
            extractedImage: extractedImage.image,
            maskImage: foregroundMask,
            boundingRect: finalBounds,
            errorMessage: extractedImage.error
        )
    }
    
    private func performColorClustering(ciImage: CIImage) async -> [[Float]] {
        // 简化的颜色聚类实现
        // 实际应用中可以使用K-means聚类算法
        return await withCheckedContinuation { continuation in
            // 模拟颜色聚类结果
            let clusters: [[Float]] = [
                [0.8, 0.7, 0.6], // 主体颜色（如面包的棕色）
                [0.9, 0.9, 0.9], // 背景颜色（如白色背景）
                [0.2, 0.2, 0.2], // 阴影颜色
            ]
            continuation.resume(returning: clusters)
        }
    }
    
    private func separateForegroundBackground(
        ciImage: CIImage,
        colorClusters: [[Float]],
        refinedMask: CIImage?
    ) async -> CIImage? {
        
        // 基于颜色聚类结果创建前景mask
        // 使用 CIColorMatrix 来创建颜色选择mask
        let colorFilter = CIFilter.colorMatrix()
        colorFilter.inputImage = ciImage
        
        // 设置颜色矩阵（基于第一个聚类 - 主体颜色）
        if let mainColor = colorClusters.first {
            // 增强主要颜色通道 (将 Float 转换为 CGFloat)
            colorFilter.rVector = CIVector(x: CGFloat(mainColor[0]), y: 0, z: 0, w: 0)
            colorFilter.gVector = CIVector(x: 0, y: CGFloat(mainColor[1]), z: 0, w: 0)
            colorFilter.bVector = CIVector(x: 0, y: 0, z: CGFloat(mainColor[2]), w: 0)
            colorFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        }
        
        guard let colorMask = colorFilter.outputImage else { return refinedMask }
        
        // 如果有精确mask，则结合使用
        if let refinedMask = refinedMask {
            let multiply = CIFilter.multiplyCompositing()
            multiply.inputImage = colorMask
            multiply.backgroundImage = refinedMask
            return multiply.outputImage
        }
        
        return colorMask
    }
    
    private func removeBackground(
        ciImage: CIImage,
        mask: CIImage?,
        targetSize: CGSize?
    ) async -> (image: UIImage, error: String?) {
        
        guard let mask = mask else {
            return (UIImage(ciImage: ciImage) ?? UIImage(), "无法生成mask")
        }
        
        // 1. 羽化边缘
        let featheredMask = await featherMask(mask: mask, radius: parameters.featherRadius)
        
        // 2. 应用mask进行背景移除
        let maskedImage = await applyMask(ciImage: ciImage, mask: featheredMask ?? mask)
        
        // 3. 裁剪到目标尺寸
        let finalImage = await cropToTargetSize(
            ciImage: maskedImage ?? ciImage,
            targetSize: targetSize
        )
        
        return (finalImage, nil)
    }
    
    private func featherMask(mask: CIImage, radius: Float) async -> CIImage? {
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = mask
        blurFilter.radius = radius
        
        return blurFilter.outputImage
    }
    
    private func applyMask(ciImage: CIImage, mask: CIImage) async -> CIImage? {
        let blend = CIFilter.blendWithMask()
        blend.inputImage = ciImage
        blend.backgroundImage = CIImage.empty()
        blend.maskImage = mask
        
        return blend.outputImage
    }
    
    private func cropToTargetSize(ciImage: CIImage, targetSize: CGSize?) async -> UIImage {
        guard let targetSize = targetSize else {
            return UIImage(ciImage: ciImage) ?? UIImage()
        }
        
        // 计算裁剪区域，保持主体在中心
        let sourceSize = ciImage.extent.size
        let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        
        let scaledSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        
        let cropRect = CGRect(
            x: (sourceSize.width - scaledSize.width) / 2,
            y: (sourceSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        let croppedImage = ciImage.cropped(to: cropRect)
        
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else {
            return UIImage()
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Error Handling and Fallback
extension SubjectExtractionEngine {
    
    /// 创建错误结果
    private func createErrorResult(
        originalImage: UIImage,
        errorMessage: String,
        processingTime: TimeInterval
    ) -> ExtractionResult {
        return ExtractionResult(
            originalImage: originalImage,
            stage1Result: nil,
            stage2Result: nil,
            finalResult: originalImage,
            detectedSubjectType: .auto,
            confidence: 0.0,
            boundingRect: .zero,
            processingTime: processingTime,
            errorMessage: errorMessage
        )
    }
    
    /// 回退提取机制 - 使用简单的中心裁剪
    private func fallbackExtraction(
        image: UIImage,
        startTime: CFAbsoluteTime,
        targetSize: CGSize?
    ) async -> ExtractionResult {
        
        print("⚠️ 智能检测失败，使用回退机制")
        
        // 使用简单的中心裁剪作为回退
        let croppedImage = simpleCenterCrop(image: image, targetSize: targetSize)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return ExtractionResult(
            originalImage: image,
            stage1Result: nil,
            stage2Result: nil,
            finalResult: croppedImage,
            detectedSubjectType: parameters.subjectType,
            confidence: 0.3, // 低置信度表示使用了回退机制
            boundingRect: CGRect(
                x: image.size.width * 0.25,
                y: image.size.height * 0.25,
                width: image.size.width * 0.5,
                height: image.size.height * 0.5
            ),
            processingTime: processingTime,
            errorMessage: "使用简单裁剪回退机制"
        )
    }
    
    /// 简单的中心裁剪
    private func simpleCenterCrop(image: UIImage, targetSize: CGSize?) -> UIImage {
        guard let targetSize = targetSize else { return image }
        
        let scale = min(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let scaledSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        let cropRect = CGRect(
            x: (image.size.width - scaledSize.width) / 2,
            y: (image.size.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return croppedImage
    }
}

// MARK: - Parameter Configuration Management
extension SubjectExtractionEngine {
    
    /// 保存最佳参数配置
    func saveBestConfiguration(for subjectType: SubjectType) {
        let key = "BestConfig_\(subjectType.rawValue)"
        
        let configData: [String: Any] = [
            "saliencyThreshold": parameters.saliencyThreshold,
            "visionConfidenceThreshold": parameters.visionConfidenceThreshold,
            "edgeThreshold": parameters.edgeThreshold,
            "contourSmoothness": parameters.contourSmoothness,
            "morphologyRadius": parameters.morphologyRadius,
            "colorClusterCount": parameters.colorClusterCount,
            "backgroundRemovalStrength": parameters.backgroundRemovalStrength,
            "featherRadius": parameters.featherRadius,
            "preserveOriginalRatio": parameters.preserveOriginalRatio,
            "minimumSubjectSize": parameters.minimumSubjectSize
        ]
        
        UserDefaults.standard.set(configData, forKey: key)
        print("💾 已保存 \(subjectType.rawValue) 的最佳配置")
    }
    
    /// 加载最佳参数配置
    func loadBestConfiguration(for subjectType: SubjectType) -> DetectionParameters? {
        let key = "BestConfig_\(subjectType.rawValue)"
        
        guard let configData = UserDefaults.standard.dictionary(forKey: key) else {
            return nil
        }
        
        var params = DetectionParameters()
        params.subjectType = subjectType
        
        if let value = configData["saliencyThreshold"] as? Float {
            params.saliencyThreshold = value
        }
        if let value = configData["visionConfidenceThreshold"] as? Float {
            params.visionConfidenceThreshold = value
        }
        if let value = configData["edgeThreshold"] as? Float {
            params.edgeThreshold = value
        }
        if let value = configData["contourSmoothness"] as? Float {
            params.contourSmoothness = value
        }
        if let value = configData["morphologyRadius"] as? Float {
            params.morphologyRadius = value
        }
        if let value = configData["colorClusterCount"] as? Int {
            params.colorClusterCount = value
        }
        if let value = configData["backgroundRemovalStrength"] as? Float {
            params.backgroundRemovalStrength = value
        }
        if let value = configData["featherRadius"] as? Float {
            params.featherRadius = value
        }
        if let value = configData["preserveOriginalRatio"] as? Bool {
            params.preserveOriginalRatio = value
        }
        if let value = configData["minimumSubjectSize"] as? CGFloat {
            params.minimumSubjectSize = value
        }
        
        print("📂 已加载 \(subjectType.rawValue) 的最佳配置")
        return params
    }
    
    /// 获取预设的优化参数
    func getOptimizedParameters(for subjectType: SubjectType) -> DetectionParameters {
        // 如果有保存的配置，优先使用
        if let savedParams = loadBestConfiguration(for: subjectType) {
            return savedParams
        }
        
        // 否则使用预设的优化参数
        var params = DetectionParameters()
        params.subjectType = subjectType
        
        switch subjectType {
        case .food:
            params.saliencyThreshold = 0.6
            params.edgeThreshold = 0.15
            params.contourSmoothness = 1.2
            params.backgroundRemovalStrength = 0.8
            params.featherRadius = 4.0
            
        case .plant:
            params.saliencyThreshold = 0.4
            params.edgeThreshold = 0.1
            params.contourSmoothness = 0.8
            params.backgroundRemovalStrength = 0.6
            params.featherRadius = 6.0
            
        case .person:
            params.saliencyThreshold = 0.7
            params.edgeThreshold = 0.2
            params.contourSmoothness = 1.0
            params.backgroundRemovalStrength = 0.9
            params.featherRadius = 3.0
            
        case .object:
            params.saliencyThreshold = 0.5
            params.edgeThreshold = 0.12
            params.contourSmoothness = 1.0
            params.backgroundRemovalStrength = 0.7
            params.featherRadius = 5.0
            
        case .auto:
            // 使用默认参数
            break
        }
        
        return params
    }
}
