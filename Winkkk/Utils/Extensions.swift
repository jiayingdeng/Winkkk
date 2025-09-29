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
    
    /// 获取设备性能等级（增强版本，包含更精确的设备检测）
    static var performanceLevel: PerformanceLevel {
        // 优先使用精确的设备型号检测
        if let deviceModel = getDeviceModel() {
            if let levelFromModel = PerformanceLevel.fromDeviceModel(deviceModel) {
                print("📱 设备型号检测: \(deviceModel) -> \(levelFromModel)")
                return levelFromModel
            }
        }
        
        // 回退到处理器和内存检测
        let processorInfo = ProcessInfo.processInfo
        let activeProcessorCount = processorInfo.activeProcessorCount
        let physicalMemory = processorInfo.physicalMemory
        
        if activeProcessorCount >= 6 && physicalMemory >= 6_000_000_000 {
            return .high
        } else if activeProcessorCount >= 4 && physicalMemory >= 3_000_000_000 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 获取当前设备的实时性能状态
    static func getCurrentPerformanceStatus() -> PerformanceStatus {
        let memoryInfo = getMemoryInfo()
        let thermalState = ProcessInfo.processInfo.thermalState
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        return PerformanceStatus(
            memoryInfo: memoryInfo,
            thermalState: thermalState,
            batteryLevel: batteryLevel,
            isLowPowerMode: isLowPowerMode
        )
    }
    
    /// 检查是否可以安全进行高性能录制
    static func canPerformHighQualityRecording() -> (canPerform: Bool, reason: String?) {
        let status = getCurrentPerformanceStatus()
        
        // 检查内存是否充足
        // 🚨 临时注释：降低内存限制敏感度，允许录像测试
        // if status.memoryInfo.availableMemory < 500_000_000 { // 小于500MB
        //     return (false, "可用内存不足，建议关闭其他应用")
        // }
        
        // 检查设备温度
        if status.thermalState == .critical || status.thermalState == .serious {
            return (false, "设备温度过高，需要等待降温")
        }
        
        // 检查电量
        if status.batteryLevel > 0 && status.batteryLevel < 0.15 { // 低于15%
            return (false, "电量过低，建议连接电源")
        }
        
        // 检查低电量模式
        if status.isLowPowerMode {
            return (false, "低电量模式已开启，将自动降低录制质量")
        }
        
        return (true, nil)
    }
    
    private static func getDeviceModel() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? nil : identifier
    }
    
    private static func getMemoryInfo() -> MemoryInfo {
        let host = mach_host_self()
        var hostInfo = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<natural_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let pageSize = UInt64(vm_kernel_page_size)
            let freeMemory = UInt64(hostInfo.free_count) * pageSize
            let usedMemory = totalMemory - freeMemory
            let availableMemory = freeMemory
            
            return MemoryInfo(
                totalMemory: totalMemory,
                usedMemory: usedMemory,
                availableMemory: availableMemory
            )
        }
        
        return MemoryInfo(totalMemory: 0, usedMemory: 0, availableMemory: 0)
    }
    
    enum PerformanceLevel {
        case low
        case medium
        case high
        case ultra // 新增超高性能级别
        
        var maxVideoResolution: String {
            switch self {
            case .low: return AVCaptureSession.Preset.hd1280x720.rawValue
            case .medium: return AVCaptureSession.Preset.hd1920x1080.rawValue
            case .high: return AVCaptureSession.Preset.hd4K3840x2160.rawValue
            case .ultra: return AVCaptureSession.Preset.hd4K3840x2160.rawValue
            }
        }
        
        var recommendedImageProcessingLevel: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .ultra: return 4
            }
        }
        
        var displayName: String {
            switch self {
            case .low: return "低性能"
            case .medium: return "中等性能"
            case .high: return "高性能"
            case .ultra: return "超高性能"
            }
        }
        
        /// 根据设备型号返回性能等级
        static func fromDeviceModel(_ model: String) -> PerformanceLevel? {
            // iPhone 15系列及以上 - Ultra级别
            if model.hasPrefix("iPhone16") || // iPhone 16系列
               model.hasPrefix("iPhone15,4") || model.hasPrefix("iPhone15,5") { // iPhone 15 Pro系列
                return .ultra
            }
            
            // iPhone 13-14系列，M1/M2 iPad - High级别  
            if model.hasPrefix("iPhone14") || model.hasPrefix("iPhone15,2") || model.hasPrefix("iPhone15,3") || // iPhone 14/15系列
               model.hasPrefix("iPad13") || model.hasPrefix("iPad14") { // M1/M2 iPad
                return .high
            }
            
            // iPhone 11-12系列，A12-A14设备 - Medium级别
            if model.hasPrefix("iPhone11") || model.hasPrefix("iPhone12") || model.hasPrefix("iPhone13") ||
               model.hasPrefix("iPad11") || model.hasPrefix("iPad12") {
                return .medium
            }
            
            // 更老的设备 - Low级别
            if model.hasPrefix("iPhone8") || model.hasPrefix("iPhone9") || model.hasPrefix("iPhone10") ||
               model.hasPrefix("iPad6") || model.hasPrefix("iPad7") || model.hasPrefix("iPad8") {
                return .low
            }
            
            return nil
        }
    }
    
    struct PerformanceStatus {
        let memoryInfo: MemoryInfo
        let thermalState: ProcessInfo.ThermalState
        let batteryLevel: Float
        let isLowPowerMode: Bool
        
        var canPerformHighQualityRecording: Bool {
            // 🚨 临时注释：降低内存限制敏感度，允许录像测试
            // return memoryInfo.availableMemory > 500_000_000 && // 500MB可用内存
            return // memoryInfo.availableMemory > 100_000_000 && // 临时降低到100MB
                   thermalState != .critical &&
                   thermalState != .serious &&
                   !isLowPowerMode &&
                   (batteryLevel <= 0 || batteryLevel > 0.15) // 电量大于15%或者正在充电
        }
        
        var recommendedMaxQuality: VideoQuality {
            if !canPerformHighQualityRecording {
                return .low
            }
            
            if memoryInfo.availableMemory > 1_000_000_000 && thermalState == .nominal {
                return .high
            } else if memoryInfo.availableMemory > 700_000_000 {
                return .medium
            } else {
                return .low
            }
        }
    }
    
    struct MemoryInfo {
        let totalMemory: UInt64
        let usedMemory: UInt64
        let availableMemory: UInt64
        
        var memoryPressure: MemoryPressure {
            let usageRatio = Double(usedMemory) / Double(totalMemory)
            if usageRatio > 0.9 {
                return .critical
            } else if usageRatio > 0.8 {
                return .high
            } else if usageRatio > 0.6 {
                return .medium
            } else {
                return .low
            }
        }
    }
    
    enum MemoryPressure {
        case low, medium, high, critical
        
        var displayName: String {
            switch self {
            case .low: return "内存充足"
            case .medium: return "内存适中"
            case .high: return "内存紧张"
            case .critical: return "内存严重不足"
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



// MARK: - 相机管理代理

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
    
    /// 获取可用存储空间(GB)
    static func getAvailableSpaceInGB() -> Double {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = attributes[.systemFreeSize] as? Int64 else {
            return 0.0
        }
        
        // 转换为GB (1GB = 1024^3 bytes)
        let gbSpace = Double(freeSpace) / (1024.0 * 1024.0 * 1024.0)
        return gbSpace
    }
}

