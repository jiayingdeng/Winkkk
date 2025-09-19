//
//  ScreenshotItem.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图项目数据模型
//

import Foundation
import CoreData
import UIKit

@objc(ScreenshotItem)
public class ScreenshotItem: NSManagedObject {
    
}

extension ScreenshotItem {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScreenshotItem> {
        return NSFetchRequest<ScreenshotItem>(entityName: "ScreenshotItem")
    }
    
    /// 唯一标识符
    @NSManaged public var id: UUID
    
    /// 原始图片文件路径
    @NSManaged public var originalImagePath: URL
    
    /// 修复后图片文件路径
    @NSManaged public var enhancedImagePath: URL?
    
    /// 截图在视频中的时间点（秒）
    @NSManaged public var timestamp: Double
    
    /// 画质修复强度等级 (0: 无修复, 1: 轻度, 2: 中度, 3: 重度)
    @NSManaged public var enhanceLevel: Int16
    
    /// 创建时间
    @NSManaged public var createdDate: Date
    
    /// 是否已经应用画质修复
    @NSManaged public var isEnhanced: Bool
    
    /// 图片宽度
    @NSManaged public var width: Int32
    
    /// 图片高度
    @NSManaged public var height: Int32
    
    /// 原始图片文件大小
    @NSManaged public var originalFileSize: Int64
    
    /// 修复后图片文件大小
    @NSManaged public var enhancedFileSize: Int64
    
    /// 关联的视频源
    @NSManaged public var videoSource: VideoItem?
}

// MARK: - 新增属性（会话隔离支持）
extension ScreenshotItem {
    
    /// 截图模式（存储为字符串）
    @NSManaged public var captureMode: String
    
    /// 选择顺序（在当前会话中的顺序）
    @NSManaged public var selectionOrder: Int16
    
    /// 是否被选中（用于批量操作）
    @NSManaged public var isSelected: Bool
    
    /// 处理状态
    @NSManaged public var processingStatus: String
}

// MARK: - Live Photo支持属性
extension ScreenshotItem {
    
    /// Live Photo视频文件路径
    @NSManaged public var livePhotoVideoPath: URL?
    
    /// Live Photo配对标识符
    @NSManaged public var livePhotoIdentifier: String?
    
    /// Live Photo持续时间（秒）
    @NSManaged public var livePhotoDuration: Double
    
    /// 封面帧偏移时间（相对于Live Photo开始时间，秒）
    @NSManaged public var keyPhotoOffset: Double
    
    /// 是否为Live Photo
    @NSManaged public var isLivePhoto: Bool
}

// MARK: - Computed Properties
extension ScreenshotItem {
    
    /// 格式化的时间戳
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        let milliseconds = Int((timestamp.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    /// 图片分辨率字符串
    var resolutionString: String {
        return "\(width) × \(height)"
    }
    
    /// 修复强度描述
    var enhanceLevelDescription: String {
        switch enhanceLevel {
        case 0:
            return "未修复"
        case 1:
            return "轻度修复"
        case 2:
            return "中度修复"
        case 3:
            return "重度修复"
        default:
            return "未知"
        }
    }
    
    /// 获取要显示的图片路径（优先显示修复后的）
    var displayImagePath: URL {
        return enhancedImagePath ?? originalImagePath
    }
    
    /// 格式化的原始文件大小
    var formattedOriginalFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: originalFileSize)
    }
    
    /// 格式化的修复后文件大小
    var formattedEnhancedFileSize: String {
        guard enhancedFileSize > 0 else { return "未知" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: enhancedFileSize)
    }
}

// MARK: - 处理状态枚举
enum ProcessingStatus: String, CaseIterable {
    case original = "original"               // 原始图片
    case enhancing = "enhancing"             // 修复中
    case enhanced = "enhanced"               // 已修复
    case failed = "failed"                   // 处理失败
    
    var displayName: String {
        switch self {
        case .original: return "原始"
        case .enhancing: return "处理中"
        case .enhanced: return "已修复"
        case .failed: return "失败"
        }
    }
    
    var color: UIColor {
        switch self {
        case .original: return UIColor.systemGray
        case .enhancing: return UIColor.systemBlue
        case .enhanced: return UIColor.systemGreen
        case .failed: return UIColor.systemRed
        }
    }
}

// MARK: - 会话隔离扩展方法
extension ScreenshotItem {
    
    /// 获取截图模式
    var mode: CaptureMode {
        get {
            return CaptureMode(rawValue: captureMode) ?? .stillImage
        }
        set {
            captureMode = newValue.rawValue
        }
    }
    
    /// 获取处理状态
    var status: ProcessingStatus {
        get {
            return ProcessingStatus(rawValue: processingStatus) ?? .original
        }
        set {
            processingStatus = newValue.rawValue
        }
    }
    
    /// 设置选择状态
    func setSelected(_ selected: Bool, order: Int? = nil) {
        isSelected = selected
        if let order = order {
            selectionOrder = Int16(order)
        }
    }
    
    /// 重置会话状态
    func resetSessionState() {
        isSelected = false
        selectionOrder = 0
        status = .original
    }
    
    /// 获取要显示的图片
    var image: UIImage? {
        let imagePath = displayImagePath
        return UIImage(contentsOfFile: imagePath.path)
    }
    
    /// 设置为Live Photo
    func setAsLivePhoto(videoPath: URL, identifier: String, duration: Double = 3.0, keyPhotoOffset: Double = 1.5) {
        isLivePhoto = true
        livePhotoVideoPath = videoPath
        livePhotoIdentifier = identifier
        livePhotoDuration = duration
        keyPhotoOffset = keyPhotoOffset
        captureMode = CaptureMode.livePhoto.rawValue
    }
    
    /// 清除Live Photo数据
    func clearLivePhotoData() {
        isLivePhoto = false
        livePhotoVideoPath = nil
        livePhotoIdentifier = nil
        livePhotoDuration = 0
        keyPhotoOffset = 0
    }
}

// MARK: - Helper Methods
extension ScreenshotItem {
    
    /// 设置画质修复等级
    func setEnhanceLevel(_ level: Int) {
        enhanceLevel = Int16(max(0, min(3, level)))
    }
    
    /// 标记为已修复
    func markAsEnhanced(enhancedPath: URL, fileSize: Int64) {
        enhancedImagePath = enhancedPath
        enhancedFileSize = fileSize
        isEnhanced = true
    }
    
    /// 重置修复状态
    func resetEnhancement() {
        enhancedImagePath = nil
        enhancedFileSize = 0
        isEnhanced = false
        enhanceLevel = 0
    }
}

extension ScreenshotItem: Identifiable {
    
}
