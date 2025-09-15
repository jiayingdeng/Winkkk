//
//  VideoItem.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频项目数据模型
//

import Foundation
import CoreData

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
