//
//  PersistenceController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  Core Data 数据持久化控制器
//

import CoreData
import Foundation

struct PersistenceController {
    
    /// 共享实例 - 使用自定义Code Data模型
    static let shared = PersistenceController.createWithCustomModel()
    
    /// 预览用实例（用于SwiftUI预览）
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建示例数据
        let sampleVideo = VideoItem(context: viewContext)
        sampleVideo.id = UUID()
        sampleVideo.fileName = "sample_video.mp4"
        sampleVideo.filePath = URL(fileURLWithPath: "/tmp/sample.mp4")
        sampleVideo.duration = 120.0
        sampleVideo.createdDate = Date()
        sampleVideo.isFromCamera = true
        sampleVideo.width = 1080
        sampleVideo.height = 1920
        sampleVideo.fileSize = 15_000_000
        
        let sampleScreenshot = ScreenshotItem(context: viewContext)
        sampleScreenshot.id = UUID()
        sampleScreenshot.originalImagePath = URL(fileURLWithPath: "/tmp/screenshot.jpg")
        sampleScreenshot.timestamp = 30.5
        sampleScreenshot.enhanceLevel = 1
        sampleScreenshot.createdDate = Date()
        sampleScreenshot.isEnhanced = false
        sampleScreenshot.width = 1080
        sampleScreenshot.height = 1920
        sampleScreenshot.originalFileSize = 2_500_000
        sampleScreenshot.videoSource = sampleVideo
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("创建预览数据失败: \(nsError), \(nsError.userInfo)")
        }
        
        return result
    }()
    
    /// Core Data 容器
    let container: NSPersistentContainer
    
    /// 默认初始化方法
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WinkkkDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // 配置持久化存储描述
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.shouldInferMappingModelAutomatically = true
            storeDescription.shouldMigrateStoreAutomatically = true
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // 在生产环境中，应该适当处理这个错误
                fatalError("Core Data 加载失败: \(error), \(error.userInfo)")
            }
        }
        
        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }
    
    /// 使用自定义container初始化
    init(container: NSPersistentContainer) {
        self.container = container
        
        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }
}

// MARK: - 便捷方法
extension PersistenceController {
    
    /// 保存上下文
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("保存 Core Data 上下文失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// 创建后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return context
    }
    
    /// 在后台上下文中执行操作
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}

// MARK: - 数据操作辅助方法
extension PersistenceController {
    
    /// 创建新的视频项目
    func createVideoItem(
        fileName: String,
        filePath: URL,
        duration: Double,
        isFromCamera: Bool,
        width: Int32,
        height: Int32,
        fileSize: Int64,
        thumbnailPath: URL? = nil
    ) -> VideoItem {
        let context = container.viewContext
        let videoItem = VideoItem(context: context)
        
        videoItem.id = UUID()
        videoItem.fileName = fileName
        videoItem.filePath = filePath
        videoItem.duration = duration
        videoItem.createdDate = Date()
        videoItem.isFromCamera = isFromCamera
        videoItem.width = width
        videoItem.height = height
        videoItem.fileSize = fileSize
        videoItem.thumbnailPath = thumbnailPath
        
        save()
        return videoItem
    }
    
    /// 创建新的截图项目
    func createScreenshotItem(
        originalImagePath: URL,
        timestamp: Double,
        width: Int32,
        height: Int32,
        originalFileSize: Int64,
        videoSource: VideoItem
    ) -> ScreenshotItem {
        let context = container.viewContext
        let screenshotItem = ScreenshotItem(context: context)
        
        screenshotItem.id = UUID()
        screenshotItem.originalImagePath = originalImagePath
        screenshotItem.timestamp = timestamp
        screenshotItem.enhanceLevel = 0
        screenshotItem.createdDate = Date()
        screenshotItem.isEnhanced = false
        screenshotItem.width = width
        screenshotItem.height = height
        screenshotItem.originalFileSize = originalFileSize
        screenshotItem.enhancedFileSize = 0
        screenshotItem.videoSource = videoSource
        
        // 初始化会话隔离相关属性
        screenshotItem.captureMode = CaptureMode.stillImage.rawValue
        screenshotItem.selectionOrder = 0
        screenshotItem.isSelected = false
        screenshotItem.processingStatus = ProcessingStatus.original.rawValue
        
        save()
        return screenshotItem
    }
    
    /// 删除视频项目及其相关截图
    func deleteVideoItem(_ videoItem: VideoItem) {
        let context = container.viewContext
        
        // 删除相关截图
        if let screenshots = videoItem.screenshots as? Set<ScreenshotItem> {
            for screenshot in screenshots {
                context.delete(screenshot)
            }
        }
        
        context.delete(videoItem)
        save()
    }
    
    /// 删除截图项目
    func deleteScreenshotItem(_ screenshotItem: ScreenshotItem) {
        let context = container.viewContext
        context.delete(screenshotItem)
        save()
    }
}
