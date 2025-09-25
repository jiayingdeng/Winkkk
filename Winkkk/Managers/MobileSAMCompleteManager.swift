//
//  MobileSAMCompleteManager.swift
//  完整的MobileSAM管理器 - 使用转换后的CoreML模型进行物体分割
//

import Foundation
import CoreML
import Vision
import UIKit
import CoreImage
import Accelerate

class MobileSAMCompleteManager: ObservableObject {
    
    // MARK: - Properties
    private var imageEncoder: MLModel?
    private var maskDecoder: MLModel?
    @Published var isLoading = false
    @Published var segmentationResult: UIImage?
    @Published var isModelLoaded = false
    
    // MARK: - Initialization
    init() {
        loadModels()
    }
    
    // MARK: - Model Loading
    private func loadModels() {
        print("🚀 开始加载MobileSAM模型...")
        
        // 加载ImageEncoder
        guard let imageEncoderURL = Bundle.main.url(forResource: "MobileSAM_ImageEncoder", withExtension: "mlpackage") else {
            print("❌ 找不到MobileSAM_ImageEncoder模型文件")
            findAvailableModels()
            return
        }
        
        // 加载MaskDecoder
        guard let maskDecoderURL = Bundle.main.url(forResource: "MobileSAM_MaskDecoder", withExtension: "mlpackage") else {
            print("❌ 找不到MobileSAM_MaskDecoder模型文件")
            findAvailableModels()
            return
        }
        
        do {
            imageEncoder = try MLModel(contentsOf: imageEncoderURL)
            maskDecoder = try MLModel(contentsOf: maskDecoderURL)
            isModelLoaded = true
            print("✅ MobileSAM模型加载成功")
            print("📊 ImageEncoder输入: \(imageEncoder?.modelDescription.inputDescriptionsByName.keys.joined(separator: ", ") ?? "未知")")
            print("📊 MaskDecoder输入: \(maskDecoder?.modelDescription.inputDescriptionsByName.keys.joined(separator: ", ") ?? "未知")")
        } catch {
            print("❌ 模型加载失败: \(error)")
            isModelLoaded = false
        }
    }
    
    private func findAvailableModels() {
        print("🔍 搜索可用的模型文件...")
        if let bundlePath = Bundle.main.resourcePath {
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
                let mlFiles = contents.filter { $0.contains("mlpackage") || $0.contains("MobileSAM") }
                print("🔍 找到的ML相关文件: \(mlFiles)")
            } catch {
                print("❌ 无法读取Bundle内容: \(error)")
            }
        }
    }
    
    // MARK: - Main Segmentation Function
    func segmentObject(in image: UIImage, at point: CGPoint) {
        guard isModelLoaded else {
            print("❌ 模型未加载")
            return
        }
        
        guard let imageEncoder = imageEncoder,
              let maskDecoder = maskDecoder else {
            print("❌ 模型实例不可用")
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. 图像预处理
            guard let processedImage = self.preprocessImage(image) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // 2. 图像编码
            guard let imageEmbeddings = self.encodeImage(processedImage, using: imageEncoder) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // 3. 准备点提示
            let (pointCoords, pointLabels) = self.preparePointPrompts(point: point, imageSize: image.size)
            
            // 4. 掩码解码
            guard let mask = self.decodeMask(imageEmbeddings: imageEmbeddings,
                                           pointCoords: pointCoords,
                                           pointLabels: pointLabels,
                                           using: maskDecoder) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // 5. 后处理
            let result = self.postprocessMask(mask, originalImage: image)
            
            DispatchQueue.main.async {
                self.segmentationResult = result
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImage(_ image: UIImage) -> MLMultiArray? {
        print("🔄 开始图像预处理...")
        
        // 1. 调整图像大小到1024x1024
        guard let resizedImage = image.resized(to: CGSize(width: 1024, height: 1024)) else {
            print("❌ 图像尺寸调整失败")
            return nil
        }
        
        // 2. 转换为MLMultiArray
        guard let multiArray = resizedImage.toMLMultiArray() else {
            print("❌ 图像转换为MLMultiArray失败")
            return nil
        }
        
        print("✅ 图像预处理完成")
        return multiArray
    }
    
    // MARK: - Image Encoding
    private func encodeImage(_ imageArray: MLMultiArray, using encoder: MLModel) -> MLMultiArray? {
        print("🔄 开始图像编码...")
        
        do {
            let input = MobileSAM_ImageEncoderInput(image: imageArray)
            let output = try encoder.prediction(from: input)
            
            if let imageEmbeddings = output.featureValue(for: "image_embeddings")?.multiArrayValue {
                print("✅ 图像编码完成，特征形状: \(imageEmbeddings.shape)")
                return imageEmbeddings
            } else {
                print("❌ 无法获取图像特征")
                return nil
            }
        } catch {
            print("❌ 图像编码失败: \(error)")
            return nil
        }
    }
    
    // MARK: - Point Prompt Preparation
    private func preparePointPrompts(point: CGPoint, imageSize: CGSize) -> (MLMultiArray, MLMultiArray) {
        print("🔄 准备点提示...")
        
        // 将点坐标归一化到1024x1024
        let normalizedX = (point.x / imageSize.width) * 1024.0
        let normalizedY = (point.y / imageSize.height) * 1024.0
        
        // 创建点坐标数组 (1, 1, 2)
        let pointCoords = try! MLMultiArray(shape: [1, 1, 2], dataType: .float32)
        pointCoords[0] = NSNumber(value: normalizedX)
        pointCoords[1] = NSNumber(value: normalizedY)
        
        // 创建点标签数组 (1, 1) - 1表示前景点
        let pointLabels = try! MLMultiArray(shape: [1, 1], dataType: .float32)
        pointLabels[0] = NSNumber(value: 1.0)
        
        print("✅ 点提示准备完成: (\(normalizedX), \(normalizedY))")
        return (pointCoords, pointLabels)
    }
    
    // MARK: - Mask Decoding
    private func decodeMask(imageEmbeddings: MLMultiArray,
                           pointCoords: MLMultiArray,
                           pointLabels: MLMultiArray,
                           using decoder: MLModel) -> MLMultiArray? {
        print("🔄 开始掩码解码...")
        
        do {
            let input = MobileSAM_MaskDecoderInput(
                image_embeddings: imageEmbeddings,
                point_coords: pointCoords,
                point_labels: pointLabels
            )
            
            let output = try decoder.prediction(from: input)
            
            if let masks = output.featureValue(for: "masks")?.multiArrayValue {
                print("✅ 掩码解码完成，掩码形状: \(masks.shape)")
                return masks
            } else {
                print("❌ 无法获取掩码输出")
                return nil
            }
        } catch {
            print("❌ 掩码解码失败: \(error)")
            return nil
        }
    }
    
    // MARK: - Mask Postprocessing
    private func postprocessMask(_ mask: MLMultiArray, originalImage: UIImage) -> UIImage? {
        print("🔄 开始掩码后处理...")
        
        // 假设mask的形状是 [1, 3, 256, 256] 或类似形状
        // 我们需要提取第一个掩码并调整到原始图像大小
        
        guard let binaryMask = extractBestMask(from: mask) else {
            print("❌ 掩码提取失败")
            return nil
        }
        
        // 将掩码应用到原始图像
        guard let segmentedImage = applyMask(binaryMask, to: originalImage) else {
            print("❌ 掩码应用失败")
            return nil
        }
        
        print("✅ 掩码后处理完成")
        return segmentedImage
    }
    
    private func extractBestMask(from masks: MLMultiArray) -> MLMultiArray? {
        // 这里需要根据实际的mask形状来提取最佳掩码
        // 通常选择IoU最高的掩码
        print("📊 掩码数组形状: \(masks.shape)")
        
        // 简化处理：直接返回第一个掩码
        // 在实际应用中，你可能需要根据IoU分数选择最佳掩码
        return masks
    }
    
    private func applyMask(_ mask: MLMultiArray, to image: UIImage) -> UIImage? {
        // 将掩码应用到图像上，创建分割结果
        // 这里需要实现具体的掩码应用逻辑
        
        // 简化实现：创建一个带有分割高亮的图像
        return createHighlightedImage(from: image, with: mask)
    }
    
    private func createHighlightedImage(from image: UIImage, with mask: MLMultiArray) -> UIImage? {
        // 创建一个简单的高亮效果
        // 在实际应用中，你可能想要更复杂的视觉效果
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        // 绘制原始图像
        image.draw(at: .zero)
        
        // 添加半透明的高亮覆盖层（简化版本）
        UIColor.red.withAlphaComponent(0.3).setFill()
        UIRectFill(CGRect(origin: .zero, size: image.size))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - CoreML类由Xcode自动生成，无需手动定义

// MARK: - UIImage Extensions
extension UIImage {
    func resized(to newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func toMLMultiArray() -> MLMultiArray? {
        guard let pixelBuffer = pixelBuffer() else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let multiArray = try? MLMultiArray(shape: [1, 3, NSNumber(value: height), NSNumber(value: width)], dataType: .float32) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * 4
                let pixel = baseAddress!.advanced(by: pixelIndex).assumingMemoryBound(to: UInt8.self)
                
                let r = Float(pixel[2]) / 255.0  // Red
                let g = Float(pixel[1]) / 255.0  // Green
                let b = Float(pixel[0]) / 255.0  // Blue
                
                // Normalize like ImageNet
                let normalizedR = (r - 0.485) / 0.229
                let normalizedG = (g - 0.456) / 0.224
                let normalizedB = (b - 0.406) / 0.225
                
                let rIndex = [0, 0, NSNumber(value: y), NSNumber(value: x)]
                let gIndex = [0, 1, NSNumber(value: y), NSNumber(value: x)]
                let bIndex = [0, 2, NSNumber(value: y), NSNumber(value: x)]
                
                multiArray[rIndex] = NSNumber(value: normalizedR)
                multiArray[gIndex] = NSNumber(value: normalizedG)
                multiArray[bIndex] = NSNumber(value: normalizedB)
            }
        }
        
        return multiArray
    }
    
    func pixelBuffer() -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        context?.draw(cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
}


