//
//  Extensions.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  通用扩展和工具方法
//

import UIKit
import SwiftUI
import AVFoundation

// MARK: - UIColor扩展
extension UIColor {
    
    /// 从十六进制字符串创建颜色
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let length = hexSanitized.count
        if length == 6 {
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else if length == 8 {
            let r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgb & 0x000000FF) / 255.0
            
            self.init(red: r, green: g, blue: b, alpha: a)
        } else {
            return nil
        }
    }
    
    /// 转换为十六进制字符串
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255) << 0
        
        return String(format: "#%06x", rgb)
    }
}

// MARK: - UIView扩展
extension UIView {
    
    /// 添加渐变背景
    func addGradientBackground(colors: [UIColor], startPoint: CGPoint = CGPoint(x: 0, y: 0), endPoint: CGPoint = CGPoint(x: 1, y: 1)) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// 添加圆角阴影
    func addCornerRadiusWithShadow(cornerRadius: CGFloat, shadowColor: UIColor = .black, shadowOpacity: Float = 0.1, shadowOffset: CGSize = CGSize(width: 0, height: 4), shadowRadius: CGFloat = 8) {
        layer.cornerRadius = cornerRadius
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowOffset = shadowOffset
        layer.shadowRadius = shadowRadius
        layer.masksToBounds = false
    }
    
    /// 添加边框
    func addBorder(width: CGFloat, color: UIColor) {
        layer.borderWidth = width
        layer.borderColor = color.cgColor
    }
    
    /// 截取视图为图片
    func asImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
    
    /// 添加点击手势
    func addTapGesture(target: Any?, action: Selector?) {
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: target, action: action)
        addGestureRecognizer(tapGesture)
    }
}

// MARK: - String扩展
extension String {
    
    /// 格式化文件大小
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 格式化时间
    static func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    /// 格式化精确时间（包含毫秒）
    static func formatPreciseTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, secs, milliseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, secs, milliseconds)
        }
    }
}

// MARK: - Date扩展
extension Date {
    
    /// 格式化为相对时间字符串
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// 格式化为短时间字符串
    var shortString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - URL扩展
extension URL {
    
    /// 获取文件大小
    var fileSize: Int64 {
        do {
            let resourceValues = try resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    /// 获取创建时间
    var creationDate: Date? {
        do {
            let resourceValues = try resourceValues(forKeys: [.creationDateKey])
            return resourceValues.creationDate
        } catch {
            return nil
        }
    }
    
    /// 获取修改时间
    var modificationDate: Date? {
        do {
            let resourceValues = try resourceValues(forKeys: [.contentModificationDateKey])
            return resourceValues.contentModificationDate
        } catch {
            return nil
        }
    }
}

// MARK: - CMTime扩展
extension CMTime {
    
    /// 转换为秒数
    var seconds: Double {
        return CMTimeGetSeconds(self)
    }
    
    /// 从秒数创建CMTime
    static func fromSeconds(_ seconds: Double) -> CMTime {
        return CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    }
    
    /// 格式化为时间字符串
    var formattedString: String {
        return String.formatTime(seconds)
    }
    
    /// 格式化为精确时间字符串
    var preciseFormattedString: String {
        return String.formatPreciseTime(seconds)
    }
}

// MARK: - AVAsset扩展
extension AVAsset {
    
    /// 获取视频尺寸
    var videoSize: CGSize {
        guard let track = tracks(withMediaType: .video).first else {
            return .zero
        }
        
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    /// 获取视频时长（秒）
    var durationInSeconds: Double {
        return duration.seconds
    }
    
    /// 是否包含音频
    var hasAudio: Bool {
        return !tracks(withMediaType: .audio).isEmpty
    }
    
    /// 是否包含视频
    var hasVideo: Bool {
        return !tracks(withMediaType: .video).isEmpty
    }
}

// MARK: - UIImage扩展
extension UIImage {
    
    /// 调整图片大小
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// 裁剪为正方形
    func cropToSquare() -> UIImage? {
        let originalWidth = size.width
        let originalHeight = size.height
        let cropSize = min(originalWidth, originalHeight)
        
        let cropX = (originalWidth - cropSize) / 2
        let cropY = (originalHeight - cropSize) / 2
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)
        
        guard let cgImage = cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    /// 添加圆角
    func withRoundedCorners(radius: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        path.addClip()
        
        draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - 设备信息
struct DeviceInfo {
    
    /// 获取设备性能等级
    static var performanceLevel: PerformanceLevel {
        let processorInfo = ProcessInfo.processInfo
        let activeProcessorCount = processorInfo.activeProcessorCount
        let physicalMemory = processorInfo.physicalMemory
        
        // 根据处理器核心数和内存判断性能等级
        if activeProcessorCount >= 6 && physicalMemory >= 6_000_000_000 { // 6GB+
            return .high
        } else if activeProcessorCount >= 4 && physicalMemory >= 3_000_000_000 { // 3GB+
            return .medium
        } else {
            return .low
        }
    }
    
    enum PerformanceLevel {
        case low
        case medium
        case high
        
        var maxVideoResolution: String {
            switch self {
            case .low: return AVCaptureSession.Preset.hd1280x720.rawValue
            case .medium: return AVCaptureSession.Preset.hd1920x1080.rawValue
            case .high: return AVCaptureSession.Preset.hd4K3840x2160.rawValue
            }
        }
        
        var recommendedImageProcessingLevel: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            }
        }
    }
    
    /// 是否为iPad
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// 是否为iPhone
    static var isIPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    /// 屏幕尺寸
    static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
}

// MARK: - VideoItem扩展
extension VideoItem {
    
    /// 格式化时长
    var formattedDuration: String {
        return String.formatTime(duration)
    }
    
    /// 格式化文件大小
    var formattedFileSize: String {
        return String.formatFileSize(fileSize)
    }
    
    /// 格式化创建日期
    var formattedCreationDate: String {
        guard let date = createdDate else { return "未知日期" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ScreenshotItem扩展
extension ScreenshotItem {
    
    /// 格式化时间戳
    var formattedTimestamp: String {
        return String.formatTime(timestamp)
    }
    
    /// 格式化创建日期
    var formattedCreationDate: String {
        guard let date = createdDate else { return "未知日期" }
        return date.shortString
    }
}

// MARK: - 相机管理代理
protocol CameraManagerDelegate: AnyObject {
    func cameraManagerDidStartSession()
    func cameraManagerDidStopSession()
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
}

// MARK: - 文件管理辅助
struct FileManagerHelper {
    
    /// 应用文档目录
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// 视频存储目录
    static var videosDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Videos")
        createDirectoryIfNeeded(url)
        return url
    }
    
    /// 截图存储目录
    static var screenshotsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Screenshots")
        createDirectoryIfNeeded(url)
        return url
    }
    
    /// 缩略图存储目录
    static var thumbnailsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Thumbnails")
        createDirectoryIfNeeded(url)
        return url
    }
    
    /// 创建目录（如果不存在）
    private static func createDirectoryIfNeeded(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    /// 生成唯一文件名
    static func generateUniqueFileName(withExtension ext: String) -> String {
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        return "\(timestamp)_\(uuid).\(ext)"
    }
    
    /// 删除文件
    static func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// 获取目录大小
    static func sizeOfDirectory(_ url: URL) -> Int64 {
        var size: Int64 = 0
        
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                size += fileURL.fileSize
            }
        }
        
        return size
    }
}
