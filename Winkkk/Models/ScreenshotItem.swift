//
//  ScreenshotItem.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图项目数据模型
//

import Foundation
import CoreData

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
