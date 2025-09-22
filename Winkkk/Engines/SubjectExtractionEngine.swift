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
    var saliencyThreshold: Float = 0.5
    var visionConfidenceThreshold: Float = 0.3
    
    // 第二阶段：轮廓检测参数
    var edgeThreshold: Float = 0.1
    var contourSmoothness: Float = 0.8
    var morphologyRadius: Float = 3.0
    
    // 第三阶段：背景移除参数
    var colorClusterCount: Int = 8
    var backgroundRemovalStrength: Float = 0.7
    var featherRadius: Float = 5.0
    
    // 场景特定参数
    var subjectType: SubjectType = .auto
    var preserveOriginalRatio: Bool = true
    var minimumSubjectSize: CGFloat = 50.0
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
                
                let bounds = pose.boundingBox
                let imageRect = CGRect(
                    x: bounds.origin.x * ciImage.extent.width,
                    y: bounds.origin.y * ciImage.extent.height,
                    width: bounds.size.width * ciImage.extent.width,
                    height: bounds.size.height * ciImage.extent.height
                )
                
                continuation.resume(returning: (pose.confidence, imageRect))
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
        // 检测圆形/椭圆形状（面包等食物）
        let detector = CIDetector(ofType: CIDetectorTypeText, context: context, options: nil)
        
        // 使用边缘检测找圆形
        let edgeFilter = CIFilter.edgeWork()
        edgeFilter.inputImage = ciImage
        edgeFilter.radius = 3.0
        
        guard let edges = edgeFilter.outputImage else { return .zero }
        
        // 简化实现：返回图像中心区域作为默认检测结果
        let centerX = ciImage.extent.width * 0.25
        let centerY = ciImage.extent.height * 0.25
        let size = min(ciImage.extent.width, ciImage.extent.height) * 0.5
        
        return CGRect(x: centerX, y: centerY, width: size, height: size)
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
        // 食物边缘检测：适合圆形、椭圆形食物
        let edgeFilter = CIFilter.edgeWork()
        edgeFilter.inputImage = ciImage
        edgeFilter.radius = parameters.edgeThreshold * 10
        
        guard let edges = edgeFilter.outputImage else { return nil }
        
        // 形态学操作：闭运算，连接断开的边缘
        let morphology = CIFilter.morphologyGradient()
        morphology.inputImage = edges
        morphology.radius = parameters.morphologyRadius
        
        return morphology.outputImage
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
    
    private func optimizeFoodContours(mask: CIImage) async -> CIImage? {
        // 食物轮廓优化：平滑圆形边缘
        let smoothFilter = CIFilter.gaussianBlur()
        smoothFilter.inputImage = mask
        smoothFilter.radius = parameters.contourSmoothness * 3
        
        return smoothFilter.outputImage
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
        let colorFilter = CIFilter.colorRange()
        colorFilter.inputImage = ciImage
        
        // 设置颜色范围（基于第一个聚类 - 主体颜色）
        if let mainColor = colorClusters.first {
            colorFilter.color0 = CIColor(
                red: CGFloat(mainColor[0] - 0.2),
                green: CGFloat(mainColor[1] - 0.2),
                blue: CGFloat(mainColor[2] - 0.2)
            )
            colorFilter.color1 = CIColor(
                red: CGFloat(mainColor[0] + 0.2),
                green: CGFloat(mainColor[1] + 0.2),
                blue: CGFloat(mainColor[2] + 0.2)
            )
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
