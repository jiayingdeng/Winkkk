//
//  WatermarkManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  水印管理器 - 可选透明水印添加和自定义选项
//

import UIKit
import CoreImage

class WatermarkManager {
    
    // MARK: - Singleton
    static let shared = WatermarkManager()
    private init() {}
    
    // MARK: - Properties
    private let context = CIContext()
    
    // MARK: - Public Methods
    
    /// 添加水印到图片
    /// - Parameters:
    ///   - image: 原始图片
    ///   - style: 水印样式
    ///   - completion: 完成回调
    func addWatermark(to image: UIImage, style: WatermarkStyle, completion: @escaping (Result<UIImage, WatermarkError>) -> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed("Watermark manager released")))
                }
                return
            }
            
            do {
                let watermarkedImage = try self.processWatermark(image: image, style: style)
                
                DispatchQueue.main.async {
                    completion(.success(watermarkedImage))
                }
                
            } catch let error as WatermarkError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// 批量添加水印
    /// - Parameters:
    ///   - images: 图片数组
    ///   - style: 水印样式
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    func addWatermarkToImages(_ images: [UIImage], style: WatermarkStyle, progress: @escaping (Float) -> Void, completion: @escaping (Result<[UIImage], WatermarkError>) -> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.processingFailed("Watermark manager released")))
                }
                return
            }
            
            var watermarkedImages: [UIImage] = []
            let totalCount = images.count
            
            for (index, image) in images.enumerated() {
                do {
                    let watermarkedImage = try self.processWatermark(image: image, style: style)
                    watermarkedImages.append(watermarkedImage)
                    
                    // 更新进度
                    let progressValue = Float(index + 1) / Float(totalCount)
                    DispatchQueue.main.async {
                        progress(progressValue)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(.processingFailed("Failed at image \(index): \(error.localizedDescription)")))
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                completion(.success(watermarkedImages))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 处理水印添加的核心方法
    /// - Parameters:
    ///   - image: 原始图片
    ///   - style: 水印样式
    /// - Returns: 添加水印后的图片
    /// - Throws: 处理错误
    private func processWatermark(image: UIImage, style: WatermarkStyle) throws -> UIImage {
        switch style.type {
        case .text:
            return try addTextWatermark(to: image, style: style)
        case .logo:
            return try addLogoWatermark(to: image, style: style)
        case .textWithLogo:
            return try addTextWithLogoWatermark(to: image, style: style)
        }
    }
    
    /// 添加文字水印
    /// - Parameters:
    ///   - image: 原始图片
    ///   - style: 水印样式
    /// - Returns: 添加水印后的图片
    /// - Throws: 处理错误
    private func addTextWatermark(to image: UIImage, style: WatermarkStyle) throws -> UIImage {
        let size = image.size
        let scale = image.scale
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        // 绘制原始图片
        image.draw(in: CGRect(origin: .zero, size: size))
        
        // 获取图形上下文
        guard let context = UIGraphicsGetCurrentContext() else {
            throw WatermarkError.processingFailed("Failed to get graphics context")
        }
        
        // 配置文字属性
        let attributes = getTextAttributes(for: style, imageSize: size)
        let attributedText = NSAttributedString(string: style.text, attributes: attributes)
        
        // 计算文字尺寸
        let textSize = attributedText.boundingRect(
            with: CGSize(width: size.width * 0.8, height: size.height * 0.2),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        // 计算文字位置
        let textRect = calculateTextRect(
            textSize: textSize,
            imageSize: size,
            position: style.position,
            margin: style.margin
        )
        
        // 绘制背景（如果需要）
        if style.hasBackground {
            drawTextBackground(in: textRect, context: context, style: style)
        }
        
        // 绘制文字
        attributedText.draw(in: textRect)
        
        // 获取结果图片
        guard let watermarkedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            throw WatermarkError.processingFailed("Failed to create watermarked image")
        }
        
        return watermarkedImage
    }
    
    /// 添加Logo水印
    /// - Parameters:
    ///   - image: 原始图片
    ///   - style: 水印样式
    /// - Returns: 添加水印后的图片
    /// - Throws: 处理错误
    private func addLogoWatermark(to image: UIImage, style: WatermarkStyle) throws -> UIImage {
        guard let logoImage = style.logoImage else {
            throw WatermarkError.invalidStyle("No logo image provided")
        }
        
        let size = image.size
        let scale = image.scale
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        // 绘制原始图片
        image.draw(in: CGRect(origin: .zero, size: size))
        
        // 计算Logo尺寸和位置
        let logoSize = calculateLogoSize(originalSize: logoImage.size, imageSize: size, style: style)
        let logoRect = calculateLogoRect(logoSize: logoSize, imageSize: size, position: style.position, margin: style.margin)
        
        // 绘制Logo（带透明度）
        logoImage.draw(in: logoRect, blendMode: .normal, alpha: style.opacity)
        
        // 获取结果图片
        guard let watermarkedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            throw WatermarkError.processingFailed("Failed to create watermarked image")
        }
        
        return watermarkedImage
    }
    
    /// 添加文字+Logo水印
    /// - Parameters:
    ///   - image: 原始图片
    ///   - style: 水印样式
    /// - Returns: 添加水印后的图片
    /// - Throws: 处理错误
    private func addTextWithLogoWatermark(to image: UIImage, style: WatermarkStyle) throws -> UIImage {
        // 首先添加Logo
        let logoWatermarked = try addLogoWatermark(to: image, style: style)
        
        // 然后添加文字（调整位置避免重叠）
        var textStyle = style
        textStyle.position = getAlternativePosition(for: style.position)
        
        return try addTextWatermark(to: logoWatermarked, style: textStyle)
    }
    
    // MARK: - Helper Methods
    
    /// 获取文字属性
    /// - Parameters:
    ///   - style: 水印样式
    ///   - imageSize: 图片尺寸
    /// - Returns: 文字属性字典
    private func getTextAttributes(for style: WatermarkStyle, imageSize: CGSize) -> [NSAttributedString.Key: Any] {
        let fontSize = calculateFontSize(for: imageSize, style: style)
        let font = UIFont.systemFont(ofSize: fontSize, weight: style.fontWeight)
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.textColor.withAlphaComponent(style.opacity)
        ]
        
        // 添加描边效果
        if style.hasStroke {
            attributes[.strokeColor] = style.strokeColor
            attributes[.strokeWidth] = style.strokeWidth
        }
        
        // 添加阴影效果
        if style.hasShadow {
            let shadow = NSShadow()
            shadow.shadowColor = style.shadowColor
            shadow.shadowOffset = style.shadowOffset
            shadow.shadowBlurRadius = style.shadowBlurRadius
            attributes[.shadow] = shadow
        }
        
        return attributes
    }
    
    /// 计算字体大小
    /// - Parameters:
    ///   - imageSize: 图片尺寸
    ///   - style: 水印样式
    /// - Returns: 计算出的字体大小
    private func calculateFontSize(for imageSize: CGSize, style: WatermarkStyle) -> CGFloat {
        let baseSize: CGFloat
        
        switch style.size {
        case .small:
            baseSize = min(imageSize.width, imageSize.height) * 0.03
        case .medium:
            baseSize = min(imageSize.width, imageSize.height) * 0.05
        case .large:
            baseSize = min(imageSize.width, imageSize.height) * 0.08
        }
        
        return max(12, min(100, baseSize)) // 限制在合理范围内
    }
    
    /// 计算Logo尺寸
    /// - Parameters:
    ///   - originalSize: Logo原始尺寸
    ///   - imageSize: 图片尺寸
    ///   - style: 水印样式
    /// - Returns: 计算出的Logo尺寸
    private func calculateLogoSize(originalSize: CGSize, imageSize: CGSize, style: WatermarkStyle) -> CGSize {
        let maxDimension = min(imageSize.width, imageSize.height)
        let scaleFactor: CGFloat
        
        switch style.size {
        case .small:
            scaleFactor = maxDimension * 0.1 / max(originalSize.width, originalSize.height)
        case .medium:
            scaleFactor = maxDimension * 0.15 / max(originalSize.width, originalSize.height)
        case .large:
            scaleFactor = maxDimension * 0.2 / max(originalSize.width, originalSize.height)
        }
        
        return CGSize(
            width: originalSize.width * scaleFactor,
            height: originalSize.height * scaleFactor
        )
    }
    
    /// 计算文字矩形
    /// - Parameters:
    ///   - textSize: 文字尺寸
    ///   - imageSize: 图片尺寸
    ///   - position: 位置
    ///   - margin: 边距
    /// - Returns: 文字矩形
    private func calculateTextRect(textSize: CGSize, imageSize: CGSize, position: WatermarkPosition, margin: CGFloat) -> CGRect {
        let x: CGFloat
        let y: CGFloat
        
        switch position {
        case .topLeft:
            x = margin
            y = margin
        case .topCenter:
            x = (imageSize.width - textSize.width) / 2
            y = margin
        case .topRight:
            x = imageSize.width - textSize.width - margin
            y = margin
        case .centerLeft:
            x = margin
            y = (imageSize.height - textSize.height) / 2
        case .center:
            x = (imageSize.width - textSize.width) / 2
            y = (imageSize.height - textSize.height) / 2
        case .centerRight:
            x = imageSize.width - textSize.width - margin
            y = (imageSize.height - textSize.height) / 2
        case .bottomLeft:
            x = margin
            y = imageSize.height - textSize.height - margin
        case .bottomCenter:
            x = (imageSize.width - textSize.width) / 2
            y = imageSize.height - textSize.height - margin
        case .bottomRight:
            x = imageSize.width - textSize.width - margin
            y = imageSize.height - textSize.height - margin
        }
        
        return CGRect(x: x, y: y, width: textSize.width, height: textSize.height)
    }
    
    /// 计算Logo矩形
    /// - Parameters:
    ///   - logoSize: Logo尺寸
    ///   - imageSize: 图片尺寸
    ///   - position: 位置
    ///   - margin: 边距
    /// - Returns: Logo矩形
    private func calculateLogoRect(logoSize: CGSize, imageSize: CGSize, position: WatermarkPosition, margin: CGFloat) -> CGRect {
        return calculateTextRect(textSize: logoSize, imageSize: imageSize, position: position, margin: margin)
    }
    
    /// 绘制文字背景
    /// - Parameters:
    ///   - rect: 文字矩形
    ///   - context: 图形上下文
    ///   - style: 水印样式
    private func drawTextBackground(in rect: CGRect, context: CGGraphicsContext, style: WatermarkStyle) {
        let backgroundRect = rect.insetBy(dx: -style.backgroundPadding, dy: -style.backgroundPadding)
        
        context.setFillColor(style.backgroundColor.withAlphaComponent(style.backgroundOpacity).cgColor)
        
        if style.backgroundCornerRadius > 0 {
            let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: style.backgroundCornerRadius)
            context.addPath(path.cgPath)
            context.fillPath()
        } else {
            context.fill(backgroundRect)
        }
    }
    
    /// 获取备选位置（避免重叠）
    /// - Parameter position: 原始位置
    /// - Returns: 备选位置
    private func getAlternativePosition(for position: WatermarkPosition) -> WatermarkPosition {
        switch position {
        case .topLeft: return .bottomRight
        case .topCenter: return .bottomCenter
        case .topRight: return .bottomLeft
        case .centerLeft: return .centerRight
        case .center: return .bottomCenter
        case .centerRight: return .centerLeft
        case .bottomLeft: return .topRight
        case .bottomCenter: return .topCenter
        case .bottomRight: return .topLeft
        }
    }
}

// MARK: - Watermark Style
struct WatermarkStyle {
    
    // 基础属性
    let type: WatermarkType
    let text: String
    let position: WatermarkPosition
    let size: WatermarkSize
    let opacity: CGFloat
    let margin: CGFloat
    
    // 文字相关
    let textColor: UIColor
    let fontWeight: UIFont.Weight
    
    // 描边
    let hasStroke: Bool
    let strokeColor: UIColor
    let strokeWidth: CGFloat
    
    // 阴影
    let hasShadow: Bool
    let shadowColor: UIColor
    let shadowOffset: CGSize
    let shadowBlurRadius: CGFloat
    
    // 背景
    let hasBackground: Bool
    let backgroundColor: UIColor
    let backgroundOpacity: CGFloat
    let backgroundPadding: CGFloat
    let backgroundCornerRadius: CGFloat
    
    // Logo相关
    let logoImage: UIImage?
    
    // MARK: - 预设样式
    static let `default` = WatermarkStyle(
        type: .text,
        text: "用 Winkkk 截取的精彩瞬间✨",
        position: .bottomRight,
        size: .small,
        opacity: 0.7,
        margin: 20,
        textColor: .white,
        fontWeight: .medium,
        hasStroke: true,
        strokeColor: .black,
        strokeWidth: -2,
        hasShadow: true,
        shadowColor: UIColor.black.withAlphaComponent(0.5),
        shadowOffset: CGSize(width: 1, height: 1),
        shadowBlurRadius: 3,
        hasBackground: true,
        backgroundColor: .black,
        backgroundOpacity: 0.3,
        backgroundPadding: 8,
        backgroundCornerRadius: 8,
        logoImage: nil
    )
    
    static let minimal = WatermarkStyle(
        type: .text,
        text: "Winkkk",
        position: .bottomRight,
        size: .small,
        opacity: 0.5,
        margin: 15,
        textColor: .white,
        fontWeight: .light,
        hasStroke: false,
        strokeColor: .clear,
        strokeWidth: 0,
        hasShadow: false,
        shadowColor: .clear,
        shadowOffset: .zero,
        shadowBlurRadius: 0,
        hasBackground: false,
        backgroundColor: .clear,
        backgroundOpacity: 0,
        backgroundPadding: 0,
        backgroundCornerRadius: 0,
        logoImage: nil
    )
    
    static let elegant = WatermarkStyle(
        type: .text,
        text: "Made with ❤️ by Winkkk",
        position: .bottomCenter,
        size: .medium,
        opacity: 0.8,
        margin: 30,
        textColor: ThemeManager.buttonPrimary,
        fontWeight: .regular,
        hasStroke: false,
        strokeColor: .clear,
        strokeWidth: 0,
        hasShadow: true,
        shadowColor: UIColor.black.withAlphaComponent(0.3),
        shadowOffset: CGSize(width: 0, height: 2),
        shadowBlurRadius: 4,
        hasBackground: true,
        backgroundColor: .white,
        backgroundOpacity: 0.9,
        backgroundPadding: 12,
        backgroundCornerRadius: 20,
        logoImage: nil
    )
}

// MARK: - Enums
enum WatermarkType {
    case text
    case logo
    case textWithLogo
}

enum WatermarkPosition {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight
}

enum WatermarkSize {
    case small, medium, large
}

enum WatermarkError: LocalizedError {
    case invalidStyle(String)
    case processingFailed(String)
    case insufficientMemory
    
    var errorDescription: String? {
        switch self {
        case .invalidStyle(let message):
            return "无效的水印样式: \(message)"
        case .processingFailed(let message):
            return "水印处理失败: \(message)"
        case .insufficientMemory:
            return "内存不足，无法处理水印"
        }
    }
}
