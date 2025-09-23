
//
//  MobileSAMManager.swift
//  图像分割管理器 - 使用MobileSAM进行物体分割
//

import Foundation
import CoreML
import Vision
import UIKit
import CoreImage

class MobileSAMManager: ObservableObject {
    
    // MARK: - Properties
    private var imageEncoder: MLModel?
    @Published var isLoading = false
    @Published var segmentationResult: UIImage?
    
    // MARK: - Initialization
    init() {
        loadModel()
    }
    
    // MARK: - Model Loading
    private func loadModel() {
        // 调试：列出Bundle中的所有.mlpackage文件
        if let bundlePath = Bundle.main.resourcePath {
            print("🔍 Bundle路径: \(bundlePath)")
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
                let mlFiles = contents.filter { $0.contains("mlpackage") || $0.contains("MobileSAM") }
                print("🔍 找到的ML相关文件: \(mlFiles)")
            } catch {
                print("❌ 无法读取Bundle内容: \(error)")
            }
        }
        
        // 尝试多种可能的文件名和路径
        let possibleNames = [
            "MobileSAM_ImageEncoder",
            "MobileSAM_imageencoder", 
            "mobilesam_imageencoder",
            "MobileSAM"
        ]
        
        var modelURL: URL?
        for name in possibleNames {
            // 首先尝试编译后的 .mlmodelc 格式
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                modelURL = url
                print("✅ 找到编译后的模型文件: \(name).mlmodelc")
                break
            }
            // 然后尝试原始的 .mlpackage 格式
            else if let url = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
                modelURL = url
                print("✅ 找到模型文件: \(name).mlpackage")
                break
            } else {
                print("🔍 未找到: \(name).mlpackage 或 \(name).mlmodelc")
            }
        }
        
        guard let finalModelURL = modelURL else {
            print("❌ 找不到MobileSAM模型文件 - 已尝试所有可能的文件名")
            print("💡 请确保MobileSAM_ImageEncoder.mlpackage已添加到Xcode项目的Bundle Resources中")
            return
        }
        
        do {
            // 创建模型配置，强制使用CPU避免ANE编译问题
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuOnly
            
            imageEncoder = try MLModel(contentsOf: finalModelURL, configuration: configuration)
            print("✅ MobileSAM模型加载成功，路径: \(finalModelURL.lastPathComponent)")
            print("🔧 使用计算单元: CPU Only (避免ANE编译问题)")
        } catch let firstError {
            print("❌ CPU模式加载失败: \(firstError)")
            print("📁 模型文件路径: \(finalModelURL.path)")
            
            // 如果CPU模式失败，尝试默认配置
            print("🔄 尝试使用默认配置重新加载...")
            do {
                imageEncoder = try MLModel(contentsOf: finalModelURL)
                print("✅ 使用默认配置加载成功")
            } catch let secondError {
                print("❌ 默认配置也失败: \(secondError)")
                print("💡 请检查模型文件是否完整或尝试重新下载")
            }
        }
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImage(_ image: UIImage) -> MLMultiArray? {
        print("📐 原始图像尺寸: \(image.size)")
        
        // 1. 保持宽高比，添加padding到1024x1024（避免变形）
        guard let paddedImage = image.resizedWithPadding(to: CGSize(width: 1024, height: 1024)) else {
            print("❌ 图像预处理失败")
            return nil
        }
        
        print("📐 padding后图像尺寸: \(paddedImage.size)")
        
        // 2. 转换为MLMultiArray
        guard let pixelBuffer = paddedImage.mobileSAMPixelBuffer() else {
            print("❌ 无法创建像素缓冲区")
            return nil
        }
        
        return pixelBuffer.toMLMultiArray()
    }
    
    // MARK: - Segmentation
    func segmentObject(in image: UIImage, at point: CGPoint) {
        print("🎯 开始图像分割，点击位置: (\(point.x), \(point.y))")
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. 预处理图像
            print("🔄 开始预处理图像...")
            guard let inputArray = self.preprocessImage(image) else {
                print("❌ 图像预处理失败")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            print("✅ 图像预处理完成，输入数组形状: \(inputArray.shape)")
            
            // 2. 运行图像编码器
            guard let encoder = self.imageEncoder else {
                print("❌ 模型编码器不可用")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                print("🔄 开始模型推理...")
                let input = try MLDictionaryFeatureProvider(dictionary: ["image": inputArray])
                let output = try encoder.prediction(from: input)
                
                // 打印模型输出信息
                print("✅ 模型推理完成")
                print("📊 模型输出特征名称: \(output.featureNames)")
                
                // 3. 提取特征 - 尝试不同的输出名称
                var features: MLMultiArray?
                let possibleOutputNames = ["features", "output", "image_embeddings", "embeddings"]
                
                for outputName in possibleOutputNames {
                    if let featureValue = output.featureValue(for: outputName)?.multiArrayValue {
                        features = featureValue
                        print("✅ 找到输出特征: \(outputName)，形状: \(featureValue.shape)")
                        break
                    }
                }
                
                guard let validFeatures = features else {
                    print("❌ 无法找到有效的输出特征，尝试的名称: \(possibleOutputNames)")
                    print("📊 实际可用的输出名称: \(output.featureNames)")
                    throw NSError(domain: "MobileSAM", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法提取特征"])
                }
                
                // 4. 简单的点击分割
                print("🔄 开始生成分割掩码...")
                let mask = self.generateMask(from: validFeatures, clickPoint: point, imageSize: image.size)
                print("✅ 分割掩码生成完成")
                
                // 5. 生成分割结果
                print("🔄 开始应用掩码到图像...")
                let resultImage = self.applyMask(mask, to: image)
                print("✅ 分割结果生成完成")
                
                DispatchQueue.main.async {
                    self.segmentationResult = resultImage
                    self.isLoading = false
                    print("🎉 图像分割流程完成！")
                }
                
            } catch {
                print("❌ 分割失败: \(error)")
                if let mlError = error as? MLModelError {
                    print("📊 ML模型错误详情: \(mlError.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Mask Generation (基于特征的智能版本)
    private func generateMask(from features: MLMultiArray, clickPoint: CGPoint, imageSize: CGSize) -> [[Float]] {
        print("🧠 开始基于模型特征生成智能掩码...")
        print("📊 输入特征形状: \(features.shape)")
        print("🎯 点击位置: (\(clickPoint.x), \(clickPoint.y)), 图像尺寸: \(imageSize)")
        
        // 模型输出特征: [1, 256, 64, 64]
        // 需要将64x64的特征图映射到256x256的掩码
        let featureHeight = features.shape[2].intValue  // 64
        let featureWidth = features.shape[3].intValue   // 64
        let channels = features.shape[1].intValue       // 256
        
        let maskSize = 256
        var mask: [[Float]] = Array(repeating: Array(repeating: 0.0, count: maskSize), count: maskSize)
        
        // 将点击位置映射到特征图坐标
        let featureX = Int(Float(clickPoint.x) / Float(imageSize.width) * Float(featureWidth))
        let featureY = Int(Float(clickPoint.y) / Float(imageSize.height) * Float(featureHeight))
        
        // 确保坐标在有效范围内
        let clampedFeatureX = max(0, min(featureWidth - 1, featureX))
        let clampedFeatureY = max(0, min(featureHeight - 1, featureY))
        
        print("🗺️ 特征图点击位置: (\(clampedFeatureX), \(clampedFeatureY))")
        
        // 提取点击位置的特征向量
        var clickFeatureVector: [Float] = []
        for c in 0..<channels {
            let index = [0, NSNumber(value: c), NSNumber(value: clampedFeatureY), NSNumber(value: clampedFeatureX)]
            let value = features[index].floatValue
            clickFeatureVector.append(value)
        }
        
        // 计算每个特征图位置与点击位置的相似度
        var similarityMap: [[Float]] = Array(repeating: Array(repeating: 0.0, count: featureWidth), count: featureHeight)
        
        for y in 0..<featureHeight {
            for x in 0..<featureWidth {
                var similarity: Float = 0.0
                var clickMagnitude: Float = 0.0
                var currentMagnitude: Float = 0.0
                
                for c in 0..<channels {
                    let index = [0, NSNumber(value: c), NSNumber(value: y), NSNumber(value: x)]
                    let currentValue = features[index].floatValue
                    let clickValue = clickFeatureVector[c]
                    
                    similarity += currentValue * clickValue
                    currentMagnitude += currentValue * currentValue
                    clickMagnitude += clickValue * clickValue
                }
                
                // 余弦相似度
                let magnitude = sqrt(currentMagnitude * clickMagnitude)
                if magnitude > 0 {
                    similarity = similarity / magnitude
                } else {
                    similarity = 0
                }
                
                similarityMap[y][x] = similarity
            }
        }
        
        // 找到相似度阈值（更智能的自适应方法）
        let flatSimilarities = similarityMap.flatMap { $0 }
        let sortedSimilarities = flatSimilarities.sorted(by: >)
        
        // 使用更保守的阈值，提高精度
        let maxSimilarity = sortedSimilarities.first ?? 0
        let minSimilarity = sortedSimilarities.last ?? 0
        let range = maxSimilarity - minSimilarity
        
        // 动态阈值：高相似度区域 + 一定的容忍度
        let threshold = maxSimilarity - range * 0.4 // 取前40%高相似度的区域
        
        print("🎯 相似度阈值: \(threshold)")
        
        // 将64x64的相似度图上采样到256x256
        let scaleX = Float(maskSize) / Float(featureWidth)
        let scaleY = Float(maskSize) / Float(featureHeight)
        
        var maskCount = 0
        for y in 0..<maskSize {
            for x in 0..<maskSize {
                let featureY_f = Float(y) / scaleY
                let featureX_f = Float(x) / scaleX
                
                // 双线性插值
                let y0 = Int(floor(featureY_f))
                let y1 = min(y0 + 1, featureHeight - 1)
                let x0 = Int(floor(featureX_f))
                let x1 = min(x0 + 1, featureWidth - 1)
                
                let dy = featureY_f - Float(y0)
                let dx = featureX_f - Float(x0)
                
                let similarity = similarityMap[y0][x0] * (1 - dx) * (1 - dy) +
                               similarityMap[y0][x1] * dx * (1 - dy) +
                               similarityMap[y1][x0] * (1 - dx) * dy +
                               similarityMap[y1][x1] * dx * dy
                
                if similarity > threshold {
                    mask[y][x] = min(1.0, similarity) // 使用相似度作为掩码强度
                    maskCount += 1
                }
            }
        }
        
        print("✅ 智能掩码生成完成，掩码像素数: \(maskCount)/\(maskSize * maskSize)")
        return mask
    }
    
    // MARK: - Mask Application
    private func applyMask(_ mask: [[Float]], to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // 绘制原图
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 应用掩码（绿色覆盖）
        context.setFillColor(UIColor.green.withAlphaComponent(0.5).cgColor)
        
        let maskHeight = mask.count
        let maskWidth = mask[0].count
        let scaleX = Float(width) / Float(maskWidth)
        let scaleY = Float(height) / Float(maskHeight)
        
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                if mask[y][x] > 0.5 {
                    let rect = CGRect(
                        x: CGFloat(Float(x) * scaleX),
                        y: CGFloat(Float(y) * scaleY),
                        width: CGFloat(scaleX),
                        height: CGFloat(scaleY)
                    )
                    context.fill(rect)
                }
            }
        }
        
        guard let resultCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: resultCGImage)
    }
}

// MARK: - UIImage Extensions
extension UIImage {
    func mobileSAMResized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func resizedWithPadding(to size: CGSize) -> UIImage? {
        let originalSize = self.size
        let targetSize = size
        
        // 计算缩放比例，保持宽高比
        let scaleX = targetSize.width / originalSize.width
        let scaleY = targetSize.height / originalSize.height
        let scale = min(scaleX, scaleY)
        
        // 计算缩放后的尺寸
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale
        
        // 计算居中位置
        let x = (targetSize.width - scaledWidth) / 2
        let y = (targetSize.height - scaledHeight) / 2
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // 用黑色填充背景
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))
        
        // 绘制缩放后的图像
        draw(in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func mobileSAMPixelBuffer() -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}

// CVPixelBuffer到MLMultiArray转换
extension CVPixelBuffer {
    func toMLMultiArray() -> MLMultiArray? {
        print("🔄 开始转换CVPixelBuffer到MLMultiArray...")
        
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        
        guard let mlArray = try? MLMultiArray(shape: [1, 3, NSNumber(value: height), NSNumber(value: width)], dataType: .float32) else {
            print("❌ 无法创建MLMultiArray")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0)) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
            print("❌ 无法获取CVPixelBuffer基地址")
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // 转换ARGB像素数据到RGB float数组
        // ImageNet标准化: mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
        let mean: [Float] = [0.485, 0.456, 0.406]
        let std: [Float] = [0.229, 0.224, 0.225]
        
        var pixelIndex = 0
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x * 4
                
                // ARGB格式: A=buffer[pixelOffset], R=buffer[pixelOffset+1], G=buffer[pixelOffset+2], B=buffer[pixelOffset+3]
                let r = Float(buffer[pixelOffset + 1]) / 255.0
                let g = Float(buffer[pixelOffset + 2]) / 255.0
                let b = Float(buffer[pixelOffset + 3]) / 255.0
                
                // 应用ImageNet标准化
                let normalizedR = (r - mean[0]) / std[0]
                let normalizedG = (g - mean[1]) / std[1]
                let normalizedB = (b - mean[2]) / std[2]
                
                // MLMultiArray格式: [batch, channel, height, width]
                let rIndex = [0, 0, NSNumber(value: y), NSNumber(value: x)]
                let gIndex = [0, 1, NSNumber(value: y), NSNumber(value: x)]
                let bIndex = [0, 2, NSNumber(value: y), NSNumber(value: x)]
                
                mlArray[rIndex] = NSNumber(value: normalizedR)
                mlArray[gIndex] = NSNumber(value: normalizedG)
                mlArray[bIndex] = NSNumber(value: normalizedB)
                
                pixelIndex += 1
            }
        }
        
        print("✅ CVPixelBuffer转换完成，形状: \(mlArray.shape)")
        return mlArray
    }
}
