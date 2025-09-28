//
//  WinkkkDataModel.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  Core Data 数据模型定义
//

import CoreData
import Foundation

extension PersistenceController {
    
    /// 创建Core Data数据模型
    static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // 创建VideoItem实体
        let videoEntity = NSEntityDescription()
        videoEntity.name = "VideoItem"
        videoEntity.managedObjectClassName = NSStringFromClass(VideoItem.self)
        
        // VideoItem属性
        let videoIdAttribute = NSAttributeDescription()
        videoIdAttribute.name = "id"
        videoIdAttribute.attributeType = .UUIDAttributeType
        videoIdAttribute.isOptional = false
        
        let fileNameAttribute = NSAttributeDescription()
        fileNameAttribute.name = "fileName"
        fileNameAttribute.attributeType = .stringAttributeType
        fileNameAttribute.isOptional = false
        
        let filePathAttribute = NSAttributeDescription()
        filePathAttribute.name = "filePath"
        filePathAttribute.attributeType = .URIAttributeType
        filePathAttribute.isOptional = false
        
        let durationAttribute = NSAttributeDescription()
        durationAttribute.name = "duration"
        durationAttribute.attributeType = .doubleAttributeType
        durationAttribute.isOptional = false
        durationAttribute.defaultValue = 0.0
        
        let createdDateAttribute = NSAttributeDescription()
        createdDateAttribute.name = "createdDate"
        createdDateAttribute.attributeType = .dateAttributeType
        createdDateAttribute.isOptional = false
        
        let thumbnailPathAttribute = NSAttributeDescription()
        thumbnailPathAttribute.name = "thumbnailPath"
        thumbnailPathAttribute.attributeType = .URIAttributeType
        thumbnailPathAttribute.isOptional = true
        
        let isFromCameraAttribute = NSAttributeDescription()
        isFromCameraAttribute.name = "isFromCamera"
        isFromCameraAttribute.attributeType = .booleanAttributeType
        isFromCameraAttribute.isOptional = false
        isFromCameraAttribute.defaultValue = false
        
        let widthAttribute = NSAttributeDescription()
        widthAttribute.name = "width"
        widthAttribute.attributeType = .integer32AttributeType
        widthAttribute.isOptional = false
        widthAttribute.defaultValue = 0
        
        let heightAttribute = NSAttributeDescription()
        heightAttribute.name = "height"
        heightAttribute.attributeType = .integer32AttributeType
        heightAttribute.isOptional = false
        heightAttribute.defaultValue = 0
        
        let fileSizeAttribute = NSAttributeDescription()
        fileSizeAttribute.name = "fileSize"
        fileSizeAttribute.attributeType = .integer64AttributeType
        fileSizeAttribute.isOptional = false
        fileSizeAttribute.defaultValue = 0
        
        let videoSourceAttribute = NSAttributeDescription()
        videoSourceAttribute.name = "videoSource"
        videoSourceAttribute.attributeType = .stringAttributeType
        videoSourceAttribute.isOptional = false
        videoSourceAttribute.defaultValue = "app_recorded"
        
        let exportStatusAttribute = NSAttributeDescription()
        exportStatusAttribute.name = "exportStatus"
        exportStatusAttribute.attributeType = .stringAttributeType
        exportStatusAttribute.isOptional = false
        exportStatusAttribute.defaultValue = "pending"
        
        videoEntity.properties = [
            videoIdAttribute, fileNameAttribute, filePathAttribute,
            durationAttribute, createdDateAttribute, thumbnailPathAttribute,
            isFromCameraAttribute, widthAttribute, heightAttribute, fileSizeAttribute,
            videoSourceAttribute, exportStatusAttribute
        ]
        
        // 创建ScreenshotItem实体
        let screenshotEntity = NSEntityDescription()
        screenshotEntity.name = "ScreenshotItem"
        screenshotEntity.managedObjectClassName = NSStringFromClass(ScreenshotItem.self)
        
        // ScreenshotItem属性
        let screenshotIdAttribute = NSAttributeDescription()
        screenshotIdAttribute.name = "id"
        screenshotIdAttribute.attributeType = .UUIDAttributeType
        screenshotIdAttribute.isOptional = false
        
        let originalImagePathAttribute = NSAttributeDescription()
        originalImagePathAttribute.name = "originalImagePath"
        originalImagePathAttribute.attributeType = .URIAttributeType
        originalImagePathAttribute.isOptional = false
        
        let enhancedImagePathAttribute = NSAttributeDescription()
        enhancedImagePathAttribute.name = "enhancedImagePath"
        enhancedImagePathAttribute.attributeType = .URIAttributeType
        enhancedImagePathAttribute.isOptional = true
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .doubleAttributeType
        timestampAttribute.isOptional = false
        timestampAttribute.defaultValue = 0.0
        
        let enhanceLevelAttribute = NSAttributeDescription()
        enhanceLevelAttribute.name = "enhanceLevel"
        enhanceLevelAttribute.attributeType = .integer16AttributeType
        enhanceLevelAttribute.isOptional = false
        enhanceLevelAttribute.defaultValue = 0
        
        let screenshotCreatedDateAttribute = NSAttributeDescription()
        screenshotCreatedDateAttribute.name = "createdDate"
        screenshotCreatedDateAttribute.attributeType = .dateAttributeType
        screenshotCreatedDateAttribute.isOptional = false
        
        let isEnhancedAttribute = NSAttributeDescription()
        isEnhancedAttribute.name = "isEnhanced"
        isEnhancedAttribute.attributeType = .booleanAttributeType
        isEnhancedAttribute.isOptional = false
        isEnhancedAttribute.defaultValue = false
        
        let screenshotWidthAttribute = NSAttributeDescription()
        screenshotWidthAttribute.name = "width"
        screenshotWidthAttribute.attributeType = .integer32AttributeType
        screenshotWidthAttribute.isOptional = false
        screenshotWidthAttribute.defaultValue = 0
        
        let screenshotHeightAttribute = NSAttributeDescription()
        screenshotHeightAttribute.name = "height"
        screenshotHeightAttribute.attributeType = .integer32AttributeType
        screenshotHeightAttribute.isOptional = false
        screenshotHeightAttribute.defaultValue = 0
        
        let originalFileSizeAttribute = NSAttributeDescription()
        originalFileSizeAttribute.name = "originalFileSize"
        originalFileSizeAttribute.attributeType = .integer64AttributeType
        originalFileSizeAttribute.isOptional = false
        originalFileSizeAttribute.defaultValue = 0
        
        let enhancedFileSizeAttribute = NSAttributeDescription()
        enhancedFileSizeAttribute.name = "enhancedFileSize"
        enhancedFileSizeAttribute.attributeType = .integer64AttributeType
        enhancedFileSizeAttribute.isOptional = false
        enhancedFileSizeAttribute.defaultValue = 0
        
        // 会话隔离相关属性
        let captureModeAttribute = NSAttributeDescription()
        captureModeAttribute.name = "captureMode"
        captureModeAttribute.attributeType = .stringAttributeType
        captureModeAttribute.isOptional = false
        captureModeAttribute.defaultValue = CaptureMode.stillImage.rawValue
        
        let selectionOrderAttribute = NSAttributeDescription()
        selectionOrderAttribute.name = "selectionOrder"
        selectionOrderAttribute.attributeType = .integer16AttributeType
        selectionOrderAttribute.isOptional = false
        selectionOrderAttribute.defaultValue = 0
        
        let isSelectedAttribute = NSAttributeDescription()
        isSelectedAttribute.name = "isSelected"
        isSelectedAttribute.attributeType = .booleanAttributeType
        isSelectedAttribute.isOptional = false
        isSelectedAttribute.defaultValue = false
        
        let processingStatusAttribute = NSAttributeDescription()
        processingStatusAttribute.name = "processingStatus"
        processingStatusAttribute.attributeType = .stringAttributeType
        processingStatusAttribute.isOptional = false
        processingStatusAttribute.defaultValue = ProcessingStatus.original.rawValue
        
        // Live Photo相关属性
        let livePhotoVideoPathAttribute = NSAttributeDescription()
        livePhotoVideoPathAttribute.name = "livePhotoVideoPath"
        livePhotoVideoPathAttribute.attributeType = .URIAttributeType
        livePhotoVideoPathAttribute.isOptional = true
        
        let livePhotoIdentifierAttribute = NSAttributeDescription()
        livePhotoIdentifierAttribute.name = "livePhotoIdentifier"
        livePhotoIdentifierAttribute.attributeType = .stringAttributeType
        livePhotoIdentifierAttribute.isOptional = true
        
        let livePhotoDurationAttribute = NSAttributeDescription()
        livePhotoDurationAttribute.name = "livePhotoDuration"
        livePhotoDurationAttribute.attributeType = .doubleAttributeType
        livePhotoDurationAttribute.isOptional = false
        livePhotoDurationAttribute.defaultValue = 0.0
        
        let keyPhotoOffsetAttribute = NSAttributeDescription()
        keyPhotoOffsetAttribute.name = "keyPhotoOffset"
        keyPhotoOffsetAttribute.attributeType = .doubleAttributeType
        keyPhotoOffsetAttribute.isOptional = false
        keyPhotoOffsetAttribute.defaultValue = 0.0
        
        let isLivePhotoAttribute = NSAttributeDescription()
        isLivePhotoAttribute.name = "isLivePhoto"
        isLivePhotoAttribute.attributeType = .booleanAttributeType
        isLivePhotoAttribute.isOptional = false
        isLivePhotoAttribute.defaultValue = false
        
        // 🔧 修复：添加缺失的 isSavedToPhotos 属性定义
        let isSavedToPhotosAttribute = NSAttributeDescription()
        isSavedToPhotosAttribute.name = "isSavedToPhotos"
        isSavedToPhotosAttribute.attributeType = .booleanAttributeType
        isSavedToPhotosAttribute.isOptional = false
        isSavedToPhotosAttribute.defaultValue = false
        
        screenshotEntity.properties = [
            screenshotIdAttribute, originalImagePathAttribute, enhancedImagePathAttribute,
            timestampAttribute, enhanceLevelAttribute, screenshotCreatedDateAttribute,
            isEnhancedAttribute, screenshotWidthAttribute, screenshotHeightAttribute,
            originalFileSizeAttribute, enhancedFileSizeAttribute,
            captureModeAttribute, selectionOrderAttribute, isSelectedAttribute, processingStatusAttribute,
            livePhotoVideoPathAttribute, livePhotoIdentifierAttribute, livePhotoDurationAttribute,
            keyPhotoOffsetAttribute, isLivePhotoAttribute, isSavedToPhotosAttribute
        ]
        
        // 创建关系
        let videoToScreenshotsRelationship = NSRelationshipDescription()
        videoToScreenshotsRelationship.name = "screenshots"
        videoToScreenshotsRelationship.destinationEntity = screenshotEntity
        videoToScreenshotsRelationship.minCount = 0
        videoToScreenshotsRelationship.maxCount = 0  // 0表示无限制
        videoToScreenshotsRelationship.deleteRule = .cascadeDeleteRule
        
        let screenshotToVideoRelationship = NSRelationshipDescription()
        screenshotToVideoRelationship.name = "videoSource"
        screenshotToVideoRelationship.destinationEntity = videoEntity
        screenshotToVideoRelationship.minCount = 0
        screenshotToVideoRelationship.maxCount = 1
        screenshotToVideoRelationship.deleteRule = .nullifyDeleteRule
        
        // 设置反向关系
        videoToScreenshotsRelationship.inverseRelationship = screenshotToVideoRelationship
        screenshotToVideoRelationship.inverseRelationship = videoToScreenshotsRelationship
        
        // 添加关系到实体
        videoEntity.properties.append(videoToScreenshotsRelationship)
        screenshotEntity.properties.append(screenshotToVideoRelationship)
        
        // 添加实体到模型
        model.entities = [videoEntity, screenshotEntity]
        
        return model
    }
}

// MARK: - 扩展PersistenceController以支持自定义模型
extension PersistenceController {
    
    /// 使用自定义模型初始化
    static func createWithCustomModel(inMemory: Bool = false) -> PersistenceController {
        let model = createManagedObjectModel()
        let container = NSPersistentContainer(name: "WinkkkDataModel", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.shouldInferMappingModelAutomatically = true
            storeDescription.shouldMigrateStoreAutomatically = true
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data 加载失败: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return PersistenceController(container: container)
    }
}
