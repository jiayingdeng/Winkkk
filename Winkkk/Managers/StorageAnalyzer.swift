//
//  StorageAnalyzer.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  存储分析器 - 安全的存储空间分析和管理
//

import Foundation
import UIKit

// MARK: - Storage Category Types
enum StorageCategoryType: CaseIterable {
    case userVideos      // 用户视频 - 不可清理
    case userScreenshots // 用户截图 - 不可清理
    case thumbnailCache  // 缩略图缓存 - 可安全清理
    case tempFiles       // 临时文件 - 可安全清理
    case systemCache     // 系统缓存 - 可安全清理
    
    var title: String {
        switch self {
        case .userVideos: return "用户视频"
        case .userScreenshots: return "截图文件"
        case .thumbnailCache: return "缩略图缓存"
        case .tempFiles: return "临时文件"
        case .systemCache: return "系统缓存"
        }
    }
    
    var icon: String {
        switch self {
        case .userVideos: return "video.fill"
        case .userScreenshots: return "photo.fill"
        case .thumbnailCache: return "square.grid.2x2.fill"
        case .tempFiles: return "doc.fill"
        case .systemCache: return "externaldrive.fill"
        }
    }
    
    var canCleanup: Bool {
        switch self {
        case .userVideos, .userScreenshots: return false
        case .thumbnailCache, .tempFiles, .systemCache: return true
        }
    }
    
    var description: String {
        switch self {
        case .userVideos: return "您录制和导入的视频文件"
        case .userScreenshots: return "从视频中截取的图片"
        case .thumbnailCache: return "视频预览缩略图，可重新生成"
        case .tempFiles: return "处理过程中的临时文件"
        case .systemCache: return "应用缓存数据"
        }
    }
}

// MARK: - Storage Category Data
struct StorageCategory {
    let type: StorageCategoryType
    let size: Int64
    let fileCount: Int
    let lastModified: Date?
    
    var formattedSize: String {
        return String.formatFileSize(size)
    }
    
    var title: String { type.title }
    var icon: String { type.icon }
    var canCleanup: Bool { type.canCleanup }
    var description: String { type.description }
}

// MARK: - Detailed Storage Info
struct DetailedStorageInfo {
    let categories: [StorageCategory]
    let totalSize: Int64
    let totalFiles: Int
    let lastUpdated: Date
    let cleanableSize: Int64  // 可清理的总大小
    
    var formattedTotalSize: String {
        return String.formatFileSize(totalSize)
    }
    
    var formattedCleanableSize: String {
        return String.formatFileSize(cleanableSize)
    }
}

// MARK: - Storage Analyzer
class StorageAnalyzer {
    
    // MARK: - Singleton
    static let shared = StorageAnalyzer()
    private init() {}
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private var cachedStorageInfo: DetailedStorageInfo?
    private var lastScanTime: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟缓存
    
    // MARK: - Protected Directories (绝对不能清理的目录)
    private let protectedDirectories: [URL] = [
        FileManagerHelper.videosDirectory,
        FileManagerHelper.screenshotsDirectory
    ]
    
    private let protectedExtensions: [String] = [
        ".mp4", ".mov", ".m4v", ".avi",  // 视频文件
        ".jpg", ".jpeg", ".png", ".heic", ".gif"  // 图片文件
    ]
    
    // MARK: - Public Methods
    
    /// 获取详细存储信息（带缓存）
    func getDetailedStorageInfo(forceRefresh: Bool = false, completion: @escaping (Result<DetailedStorageInfo, Error>) -> Void) {
        
        // 检查缓存是否有效
        if !forceRefresh,
           let cached = cachedStorageInfo,
           let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < cacheValidityDuration {
            completion(.success(cached))
            return
        }
        
        // 后台线程扫描
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let storageInfo = try self?.scanStorageCategories() ?? DetailedStorageInfo(
                    categories: [],
                    totalSize: 0,
                    totalFiles: 0,
                    lastUpdated: Date(),
                    cleanableSize: 0
                )
                
                // 更新缓存
                self?.cachedStorageInfo = storageInfo
                self?.lastScanTime = Date()
                
                DispatchQueue.main.async {
                    completion(.success(storageInfo))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 清理指定类型的文件
    func cleanupCategory(_ categoryType: StorageCategoryType, completion: @escaping (Result<CacheCleanupResult, Error>) -> Void) {
        
        guard categoryType.canCleanup else {
            completion(.failure(StorageAnalyzerError.categoryNotCleanable))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try self?.performCategoryCleanup(categoryType) ?? CacheCleanupResult(
                    deletedVideoCount: 0,
                    deletedVideoSize: 0,
                    deletedThumbnailCount: 0,
                    deletedThumbnailSize: 0
                )
                
                // 清理后刷新缓存
                self?.cachedStorageInfo = nil
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 扫描所有存储分类
    private func scanStorageCategories() throws -> DetailedStorageInfo {
        var categories: [StorageCategory] = []
        var totalSize: Int64 = 0
        var totalFiles: Int = 0
        var cleanableSize: Int64 = 0
        
        for categoryType in StorageCategoryType.allCases {
            let category = try scanCategory(categoryType)
            categories.append(category)
            totalSize += category.size
            totalFiles += category.fileCount
            
            if category.canCleanup {
                cleanableSize += category.size
            }
        }
        
        return DetailedStorageInfo(
            categories: categories,
            totalSize: totalSize,
            totalFiles: totalFiles,
            lastUpdated: Date(),
            cleanableSize: cleanableSize
        )
    }
    
    /// 扫描单个分类
    private func scanCategory(_ type: StorageCategoryType) throws -> StorageCategory {
        switch type {
        case .userVideos:
            return try scanDirectory(FileManagerHelper.videosDirectory, categoryType: type)
            
        case .userScreenshots:
            return try scanDirectory(FileManagerHelper.screenshotsDirectory, categoryType: type)
            
        case .thumbnailCache:
            return try scanDirectory(FileManagerHelper.thumbnailsDirectory, categoryType: type)
            
        case .tempFiles:
            return try scanTempFiles()
            
        case .systemCache:
            return try scanSystemCache()
        }
    }
    
    /// 扫描指定目录
    private func scanDirectory(_ directory: URL, categoryType: StorageCategoryType) throws -> StorageCategory {
        guard fileManager.fileExists(atPath: directory.path) else {
            return StorageCategory(type: categoryType, size: 0, fileCount: 0, lastModified: nil)
        }
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return StorageCategory(type: categoryType, size: 0, fileCount: 0, lastModified: nil)
        }
        
        var totalSize: Int64 = 0
        var fileCount: Int = 0
        var lastModified: Date?
        
        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isRegularFile == true {
                let fileSize = Int64(resourceValues.fileAllocatedSize ?? 0)
                totalSize += fileSize
                fileCount += 1
                
                if let modDate = resourceValues.contentModificationDate {
                    if lastModified == nil || modDate > lastModified! {
                        lastModified = modDate
                    }
                }
            }
        }
        
        return StorageCategory(
            type: categoryType,
            size: totalSize,
            fileCount: fileCount,
            lastModified: lastModified
        )
    }
    
    /// 扫描临时文件
    private func scanTempFiles() throws -> StorageCategory {
        let tempDirectory = FileManagerHelper.documentsDirectory.appendingPathComponent("Temp")
        var category = try scanDirectory(tempDirectory, categoryType: .tempFiles)
        
        // 还要扫描系统临时目录中的相关文件
        let systemTempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let systemTempCategory = try scanDirectory(systemTempDir, categoryType: .tempFiles)
        
        return StorageCategory(
            type: .tempFiles,
            size: category.size + systemTempCategory.size,
            fileCount: category.fileCount + systemTempCategory.fileCount,
            lastModified: [category.lastModified, systemTempCategory.lastModified].compactMap { $0 }.max()
        )
    }
    
    /// 扫描系统缓存
    private func scanSystemCache() throws -> StorageCategory {
        var totalSize: Int64 = 0
        var fileCount: Int = 0
        var lastModified: Date?
        
        // 扫描 URLCache
        if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheCategory = try scanDirectory(cacheDir, categoryType: .systemCache)
            totalSize += cacheCategory.size
            fileCount += cacheCategory.fileCount
            if let modDate = cacheCategory.lastModified {
                if lastModified == nil || modDate > lastModified! {
                    lastModified = modDate
                }
            }
        }
        
        return StorageCategory(
            type: .systemCache,
            size: totalSize,
            fileCount: fileCount,
            lastModified: lastModified
        )
    }
    
    /// 执行分类清理
    private func performCategoryCleanup(_ categoryType: StorageCategoryType) throws -> CacheCleanupResult {
        guard categoryType.canCleanup else {
            throw StorageAnalyzerError.categoryNotCleanable
        }
        
        var result = CacheCleanupResult(
            deletedVideoCount: 0,
            deletedVideoSize: 0,
            deletedThumbnailCount: 0,
            deletedThumbnailSize: 0
        )
        
        switch categoryType {
        case .thumbnailCache:
            let cleanupResult = try cleanupDirectory(FileManagerHelper.thumbnailsDirectory, keepDirectory: true)
            result = CacheCleanupResult(
                deletedVideoCount: 0,
                deletedVideoSize: 0,
                deletedThumbnailCount: cleanupResult.count,
                deletedThumbnailSize: cleanupResult.size
            )
            
        case .tempFiles:
            // 清理临时文件目录
            let tempDir = FileManagerHelper.documentsDirectory.appendingPathComponent("Temp")
            let tempCleanup = try cleanupDirectory(tempDir, keepDirectory: true)
            result = CacheCleanupResult(
                deletedVideoCount: 0,
                deletedVideoSize: 0,
                deletedThumbnailCount: tempCleanup.count,
                deletedThumbnailSize: tempCleanup.size
            )
            
        case .systemCache:
            // 清理系统缓存
            var cacheCount = 0
            var cacheSize: Int64 = 0
            if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let cacheCleanup = try cleanupDirectory(cacheDir, keepDirectory: true)
                cacheCount = cacheCleanup.count
                cacheSize = cacheCleanup.size
            }
            result = CacheCleanupResult(
                deletedVideoCount: 0,
                deletedVideoSize: 0,
                deletedThumbnailCount: cacheCount,
                deletedThumbnailSize: cacheSize
            )
            
        default:
            throw StorageAnalyzerError.categoryNotCleanable
        }
        
        return result
    }
    
    /// 清理目录内容
    private func cleanupDirectory(_ directory: URL, keepDirectory: Bool) throws -> (size: Int64, count: Int) {
        guard fileManager.fileExists(atPath: directory.path) else {
            return (0, 0)
        }
        
        // 安全检查：确保不是受保护的目录
        for protectedDir in protectedDirectories {
            if directory.path.hasPrefix(protectedDir.path) {
                throw StorageAnalyzerError.attemptToDeleteProtectedDirectory
            }
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileAllocatedSizeKey],
            options: []
        )
        
        var totalSize: Int64 = 0
        var totalCount = 0
        
        for fileURL in contents {
            // 双重安全检查：不删除受保护的文件扩展名
            let fileExtension = fileURL.pathExtension.lowercased()
            if protectedExtensions.contains(".\(fileExtension)") {
                continue
            }
            
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey])
            let fileSize = Int64(resourceValues.fileAllocatedSize ?? 0)
            
            try fileManager.removeItem(at: fileURL)
            totalSize += fileSize
            totalCount += 1
        }
        
        if keepDirectory && !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return (totalSize, totalCount)
    }
}

// MARK: - Storage Analyzer Errors
enum StorageAnalyzerError: LocalizedError {
    case categoryNotCleanable
    case attemptToDeleteProtectedDirectory
    case scanFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .categoryNotCleanable:
            return "该分类不支持清理操作"
        case .attemptToDeleteProtectedDirectory:
            return "尝试删除受保护的目录"
        case .scanFailed(let reason):
            return "存储扫描失败: \(reason)"
        }
    }
}
