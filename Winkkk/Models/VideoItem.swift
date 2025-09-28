//
//  VideoItem.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频项目数据模型
//

import Foundation
import CoreData

// MARK: - Enums
/// 视频来源类型
public enum VideoSourceType: String, CaseIterable {
    case appRecorded = "app_recorded"    // App内录制
    case systemImported = "system_imported"  // 系统导入
    
    var displayName: String {
        switch self {
        case .appRecorded:
            return "App录制"
        case .systemImported:
            return "系统导入"
        }
    }
    
    var icon: String {
        switch self {
        case .appRecorded:
            return "📱"
        case .systemImported:
            return "📥"
        }
    }
}

/// 导出状态类型
public enum ExportStatusType: String, CaseIterable {
    case exported = "exported"      // 已导出
    case pending = "pending"        // 待导出
    
    var displayName: String {
        switch self {
        case .exported:
            return "已导出"
        case .pending:
            return "待导出"
        }
    }
    
    var icon: String {
        switch self {
        case .exported:
            return "✅"
        case .pending:
            return "⏳"
        }
    }
}

@objc(VideoItem)
public class VideoItem: NSManagedObject {
    
}

extension VideoItem {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VideoItem> {
        return NSFetchRequest<VideoItem>(entityName: "VideoItem")
    }
    
    /// 唯一标识符
    @NSManaged public var id: UUID
    
    /// 文件名称
    @NSManaged public var fileName: String
    
    /// 文件路径
    @NSManaged public var filePath: URL
    
    /// 视频时长（秒）
    @NSManaged public var duration: Double
    
    /// 创建时间
    @NSManaged public var createdDate: Date
    
    /// 缩略图路径
    @NSManaged public var thumbnailPath: URL?
    
    /// 是否来自相机录制
    @NSManaged public var isFromCamera: Bool
    
    /// 视频尺寸宽度
    @NSManaged public var width: Int32
    
    /// 视频尺寸高度  
    @NSManaged public var height: Int32
    
    /// 文件大小（字节）
    @NSManaged public var fileSize: Int64
    
    /// 视频来源类型（app录制/系统导入）
    @NSManaged public var videoSource: String
    
    /// 导出状态（已导出/待导出）
    @NSManaged public var exportStatus: String
    
    /// 关联的截图项目
    @NSManaged public var screenshots: NSSet?
}

// MARK: - Computed Properties
extension VideoItem {
    
    /// 格式化的视频时长
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 格式化的文件大小
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// 视频分辨率字符串
    var resolutionString: String {
        return "\(width) × \(height)"
    }
    
    /// 视频来源类型枚举
    var sourceType: VideoSourceType {
        get {
            return VideoSourceType(rawValue: videoSource) ?? .appRecorded
        }
        set {
            videoSource = newValue.rawValue
        }
    }
    
    /// 导出状态类型枚举
    var exportStatusType: ExportStatusType {
        get {
            return ExportStatusType(rawValue: exportStatus) ?? .pending
        }
        set {
            exportStatus = newValue.rawValue
        }
    }
    
    /// 状态标签文本（图标+状态）
    var statusLabel: String {
        let sourceIcon = sourceType.icon
        let statusIcon = exportStatusType.icon
        
        if sourceType == .appRecorded {
            return "\(sourceIcon)\(statusIcon)"
        } else {
            return sourceIcon
        }
    }
    
    /// 详细状态描述
    var detailedStatus: String {
        if sourceType == .appRecorded {
            return "\(sourceType.displayName)，\(exportStatusType.displayName)"
        } else {
            return sourceType.displayName
        }
    }
}

// MARK: - Generated accessors for screenshots
extension VideoItem {
    
    @objc(addScreenshotsObject:)
    @NSManaged public func addToScreenshots(_ value: ScreenshotItem)
    
    @objc(removeScreenshotsObject:)
    @NSManaged public func removeFromScreenshots(_ value: ScreenshotItem)
    
    @objc(addScreenshots:)
    @NSManaged public func addToScreenshots(_ values: NSSet)
    
    @objc(removeScreenshots:)
    @NSManaged public func removeFromScreenshots(_ values: NSSet)
}

extension VideoItem: Identifiable {
    
}
