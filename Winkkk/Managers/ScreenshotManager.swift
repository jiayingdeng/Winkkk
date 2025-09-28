//
//  ScreenshotManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图管理器 - 会话隔离设计方案
//

import Foundation
import UIKit
import Combine
import Photos
import AVFoundation
import CoreData

// MARK: - 截图管理器
class ScreenshotManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ScreenshotManager()
    
    // MARK: - Published Properties
    @Published var screenshots: [ScreenshotItem] = []
    @Published var currentMode: CaptureMode = .stillImage
    @Published var selectedScreenshots: [ScreenshotItem] = []
    
    // MARK: - Video Session Properties
    /// 当前编辑的视频URL - 用于会话隔离
    @Published var currentVideoURL: URL?
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private let notificationCenter = NotificationCenter.default
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
    }
    
    // MARK: - 模式管理
    
    /// 切换截图模式（会清空当前内容）
    /// - Parameters:
    ///   - newMode: 新的截图模式
    ///   - force: 是否强制切换（不显示确认对话框）
    /// - Throws: 如果需要用户确认则抛出错误
    func switchMode(to newMode: CaptureMode, force: Bool = false) throws {
        // 如果模式相同，无需切换
        guard newMode != currentMode else { return }
        
        // 如果当前有截图且非强制模式，需要用户确认
        if !force && !screenshots.isEmpty {
            throw ScreenshotSessionError.needConfirmation(
                currentMode: currentMode,
                newMode: newMode,
                currentCount: screenshots.count
            )
        }
        
        // 清空当前截图
        clearAllScreenshots()
        
        // 切换模式
        let previousMode = currentMode
        currentMode = newMode
        
        // 通知模式变化
        notifyModeChanged(from: previousMode, to: newMode)
        
        print("📸 截图模式切换: \(previousMode.displayName) → \(newMode.displayName)")
    }
    
    // MARK: - 视频会话管理
    
    /// 切换视频会话（实现真正的会话数据隔离）
    /// - Parameter videoURL: 新的视频URL，nil表示退出视频编辑模式
    func switchVideoSession(to videoURL: URL?) {
        let previousURL = currentVideoURL
        
        // 🎯 保存当前会话的截图数据到数据库
        if let previousURL = previousURL {
            saveCurrentSessionData(for: previousURL)
        }
        
        // 🎯 更新当前视频URL
        currentVideoURL = videoURL
        
        // 🎯 加载新会话的截图数据
        if let videoURL = videoURL {
            loadScreenshotsForVideo(videoURL)
        } else {
            // 退出视频编辑模式，清空截图数组
            screenshots.removeAll()
            selectedScreenshots.removeAll()
        }
        
        // 通知会话切换
        let userInfo: [String: Any] = [
            "previousURL": previousURL as Any,
            "newURL": videoURL as Any
        ]
        notificationCenter.post(name: .videoSessionChanged, object: self, userInfo: userInfo)
        
        if let videoURL = videoURL {
            print("📸 切换视频会话: \(videoURL.lastPathComponent)")
        } else {
            print("📸 退出视频编辑模式")
        }
    }
    
    /// 🆕 保存当前会话的截图数据到数据库
    private func saveCurrentSessionData(for videoURL: URL) {
        // 确保所有截图都与正确的视频关联
        let videoItem = findOrCreateVideoItem(for: videoURL)
        
        for screenshot in screenshots {
            // 如果截图还没有关联视频源，设置关联
            if screenshot.videoSource == nil {
                screenshot.videoSource = videoItem
            }
        }
        
        // 保存到数据库
        persistenceController.save()
        print("📸 已保存会话数据: \(videoURL.lastPathComponent) - \(screenshots.count)张截图")
    }
    
    /// 🆕 为视频URL查找或创建对应的VideoItem
    private func findOrCreateVideoItem(for videoURL: URL) -> VideoItem {
        let context = persistenceController.container.viewContext
        
        // 首先尝试查找现有的VideoItem
        let fetchRequest: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "filePath == %@", videoURL as NSURL)
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            if let existingItem = existingItems.first {
                return existingItem
            }
        } catch {
            print("❌ 查找VideoItem失败: \(error)")
        }
        
        // 如果没有找到，创建新的VideoItem
        return createVideoItem(for: videoURL)
    }
    
    /// 🆕 为视频URL创建新的VideoItem
    private func createVideoItem(for videoURL: URL) -> VideoItem {
        // 获取视频基本信息
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration.seconds
        
        // 获取视频尺寸
        var width: Int32 = 0
        var height: Int32 = 0
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            width = Int32(abs(size.width))
            height = Int32(abs(size.height))
        }
        
        // 获取文件大小
        let fileSize = (try? videoURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        
        // 创建VideoItem
        let videoItem = persistenceController.createVideoItem(
            fileName: videoURL.lastPathComponent,
            filePath: videoURL,
            duration: duration,
            isFromCamera: false, // 从相册打开的视频
            width: width,
            height: height,
            fileSize: Int64(fileSize)
        )
        
        print("📸 已创建VideoItem: \(videoURL.lastPathComponent)")
        return videoItem
    }
    
    /// 🆕 加载特定视频的截图数据
    private func loadScreenshotsForVideo(_ videoURL: URL) {
        let context = persistenceController.container.viewContext
        
        // 查找对应的VideoItem
        let videoFetchRequest: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
        videoFetchRequest.predicate = NSPredicate(format: "filePath == %@", videoURL as NSURL)
        
        do {
            let videoItems = try context.fetch(videoFetchRequest)
            
            if let videoItem = videoItems.first {
                // 找到了对应的VideoItem，加载其截图
                let screenshotFetchRequest: NSFetchRequest<ScreenshotItem> = ScreenshotItem.fetchRequest()
                screenshotFetchRequest.predicate = NSPredicate(format: "videoSource == %@", videoItem)
                screenshotFetchRequest.sortDescriptors = [
                    NSSortDescriptor(key: "selectionOrder", ascending: true),
                    NSSortDescriptor(key: "timestamp", ascending: true)
                ]
                
                let loadedScreenshots = try context.fetch(screenshotFetchRequest)
                
                // 更新截图数组
                screenshots = loadedScreenshots
                selectedScreenshots = loadedScreenshots.filter { $0.isSelected }
                
                // 🆕 关键修复：根据加载的截图类型自动设置正确的模式
                if let firstScreenshot = loadedScreenshots.first {
                    let detectedMode = firstScreenshot.mode
                    currentMode = detectedMode
                    print("📸 检测到历史模式: \(detectedMode.displayName)")
                } else {
                    // 有VideoItem但无截图数据，保持默认模式
                    currentMode = .stillImage
                    print("📸 VideoItem存在但无截图，使用默认模式")
                }
                
                print("📸 已加载会话数据: \(videoURL.lastPathComponent) - \(screenshots.count)张截图")
            } else {
                // 没有找到对应的VideoItem，说明是第一次打开这个视频
                screenshots.removeAll()
                selectedScreenshots.removeAll()
                currentMode = .stillImage  // 🆕 新视频默认使用普通截图模式
                print("📸 新视频会话: \(videoURL.lastPathComponent) - 无历史截图，默认普通模式")
            }
        } catch {
            print("❌ 加载截图数据失败: \(error)")
            screenshots.removeAll()
            selectedScreenshots.removeAll()
            currentMode = .stillImage  // 🆕 出错时也使用默认模式
        }
    }
    
    /// 🎯 手动清理未保存的截图（用于用户主动丢弃）
    /// 在用户明确选择丢弃截图时调用
    func clearUnsavedScreenshots() {
        let unsavedScreenshots = screenshots.filter { !$0.isSavedToPhotos }
        
        // 从数组中移除未保存的截图
        screenshots.removeAll { !$0.isSavedToPhotos }
        selectedScreenshots.removeAll { !$0.isSavedToPhotos }
        
        // 从数据库删除未保存的截图
        unsavedScreenshots.forEach { screenshot in
            persistenceController.deleteScreenshotItem(screenshot)
        }
        
        if !unsavedScreenshots.isEmpty {
            print("📸 手动清理未保存截图: \(unsavedScreenshots.count)张")
            notifyTemporaryScreenshotsCleared(unsavedScreenshots)
        }
    }
    
    /// 🎯 已废弃：清理临时截图方法
    /// 现在使用真正的会话隔离，不再需要手动清理临时截图
    /// 所有截图数据都通过会话切换自动管理
    @available(*, deprecated, message: "使用新的会话隔离机制，此方法已不再需要")
    private func cleanTemporaryScreenshots() {
        // 🎯 新的会话隔离机制下，这个方法已经不再需要
        // 所有截图数据的保存和加载都通过switchVideoSession自动处理
        print("⚠️ cleanTemporaryScreenshots已废弃，使用新的会话隔离机制")
    }
    
    /// 检查当前是否在视频编辑模式
    var isInVideoEditingMode: Bool {
        return currentVideoURL != nil
    }
    
    // MARK: - 截图管理
    
    /// 添加截图
    /// - Parameter screenshot: 截图项目
    /// - Throws: 如果超出最大数量限制则抛出错误
    func addScreenshot(_ screenshot: ScreenshotItem) throws {
        // 检查数量限制
        guard screenshots.count < currentMode.maxCount else {
            throw ScreenshotSessionError.maxLimitReached(mode: currentMode, count: currentMode.maxCount)
        }
        
        // 🎯 确保截图与当前视频会话关联
        if let currentVideoURL = currentVideoURL {
            let videoItem = findOrCreateVideoItem(for: currentVideoURL)
            screenshot.videoSource = videoItem
        }
        
        // 更新截图属性以匹配当前会话
        screenshot.mode = currentMode
        screenshot.selectionOrder = Int16(screenshots.count)
        // status和isSelected已在创建时初始化
        
        // 添加到数组
        screenshots.append(screenshot)
        
        // 保存到数据库
        persistenceController.save()
        
        // 通知截图添加
        notifyScreenshotAdded(screenshot)
        
        print("📸 添加截图: \(currentMode.displayName)模式，当前总数: \(screenshots.count)")
    }
    
    /// 安全添加截图（无错误抛出版本）
    /// - Parameter screenshot: 截图项目
    /// - Returns: 是否成功添加
    @discardableResult
    func safeAddScreenshot(_ screenshot: ScreenshotItem) -> Bool {
        do {
            try addScreenshot(screenshot)
            return true
        } catch {
            print("❌ 添加截图失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 移除指定位置的截图
    /// - Parameter index: 截图索引
    func removeScreenshot(at index: Int) {
        guard index < screenshots.count else { return }
        
        let screenshot = screenshots[index]
        screenshots.remove(at: index)
        
        // 更新选择顺序
        updateSelectionOrder()
        
        // 从数据库删除
        persistenceController.deleteScreenshotItem(screenshot)
        
        // 通知截图移除
        notifyScreenshotRemoved(screenshot, at: index)
        
        print("📸 移除截图: 索引\(index)，当前总数: \(screenshots.count)")
    }
    
    /// 移除指定截图
    /// - Parameter screenshot: 要移除的截图项目
    func removeScreenshot(_ screenshot: ScreenshotItem) {
        guard let index = screenshots.firstIndex(of: screenshot) else { return }
        removeScreenshot(at: index)
    }
    
    /// 清空所有截图
    func clearAllScreenshots() {
        let allScreenshots = screenshots
        screenshots.removeAll()
        selectedScreenshots.removeAll()
        
        // 批量删除
        allScreenshots.forEach { persistenceController.deleteScreenshotItem($0) }
        
        // 通知清空
        notifyAllScreenshotsCleared()
        
        print("📸 清空所有截图: \(currentMode.displayName)模式")
    }
    
    // MARK: - 选择管理
    
    /// 设置截图选择状态
    /// - Parameters:
    ///   - screenshot: 截图项目
    ///   - selected: 是否选中
    func setScreenshotSelected(_ screenshot: ScreenshotItem, selected: Bool) {
        screenshot.isSelected = selected
        
        if selected {
            if !selectedScreenshots.contains(screenshot) {
                selectedScreenshots.append(screenshot)
            }
        } else {
            selectedScreenshots.removeAll { $0 == screenshot }
        }
        
        persistenceController.save()
        notifySelectionChanged()
    }
    
    /// 全选或全不选
    /// - Parameter selected: 是否全选
    func setAllScreenshotsSelected(_ selected: Bool) {
        screenshots.forEach { screenshot in
            screenshot.isSelected = selected
        }
        
        if selected {
            selectedScreenshots = screenshots
        } else {
            selectedScreenshots.removeAll()
        }
        
        persistenceController.save()
        notifySelectionChanged()
    }
    
    /// 切换截图选择状态
    /// - Parameter screenshot: 截图项目
    func toggleScreenshotSelection(_ screenshot: ScreenshotItem) {
        setScreenshotSelected(screenshot, selected: !screenshot.isSelected)
    }
    
    // MARK: - 状态查询
    
    /// 获取当前截图数量
    var screenshotCount: Int {
        return screenshots.count
    }
    
    /// 获取选中截图数量
    var selectedCount: Int {
        return selectedScreenshots.count
    }
    
    /// 是否达到最大数量限制
    var isAtMaxLimit: Bool {
        return screenshots.count >= currentMode.maxCount
    }
    
    /// 是否为空
    var isEmpty: Bool {
        return screenshots.isEmpty
    }
    
    /// 是否有选中的截图
    var hasSelection: Bool {
        return !selectedScreenshots.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// 更新选择顺序
    private func updateSelectionOrder() {
        for (index, screenshot) in screenshots.enumerated() {
            screenshot.selectionOrder = Int16(index)
        }
        persistenceController.save()
    }
    
    /// 设置通知监听
    private func setupNotifications() {
        // 监听应用状态变化
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        // 应用即将终止时保存数据
        persistenceController.save()
    }
    
    @objc private func applicationDidEnterBackground() {
        // 应用进入后台时保存数据
        persistenceController.save()
    }
    
    // MARK: - 通知方法
    
    private func notifyModeChanged(from oldMode: CaptureMode, to newMode: CaptureMode) {
        let userInfo: [String: Any] = [
            "oldMode": oldMode,
            "newMode": newMode
        ]
        notificationCenter.post(name: .screenshotModeChanged, object: self, userInfo: userInfo)
    }
    
    private func notifyScreenshotAdded(_ screenshot: ScreenshotItem) {
        notificationCenter.post(name: .screenshotAdded, object: screenshot)
    }
    
    private func notifyScreenshotRemoved(_ screenshot: ScreenshotItem, at index: Int) {
        let userInfo: [String: Any] = [
            "screenshot": screenshot,
            "index": index
        ]
        notificationCenter.post(name: .screenshotRemoved, object: self, userInfo: userInfo)
    }
    
    private func notifyAllScreenshotsCleared() {
        notificationCenter.post(name: .allScreenshotsCleared, object: self)
    }
    
    private func notifySelectionChanged() {
        notificationCenter.post(name: .screenshotSelectionChanged, object: self)
    }
    
    private func notifyTemporaryScreenshotsCleared(_ clearedScreenshots: [ScreenshotItem]) {
        let userInfo: [String: Any] = [
            "clearedScreenshots": clearedScreenshots,
            "count": clearedScreenshots.count
        ]
        notificationCenter.post(name: .temporaryScreenshotsCleared, object: self, userInfo: userInfo)
    }
}

// MARK: - 批量操作
extension ScreenshotManager {
    
    /// 批量删除选中的截图
    func deleteSelectedScreenshots() {
        let toDelete = selectedScreenshots
        
        toDelete.forEach { screenshot in
            removeScreenshot(screenshot)
        }
        
        selectedScreenshots.removeAll()
        notifySelectionChanged()
    }
    
    /// 批量设置处理状态
    /// - Parameters:
    ///   - screenshots: 截图数组
    ///   - status: 新状态
    func setBatchProcessingStatus(_ screenshots: [ScreenshotItem], status: ProcessingStatus) {
        screenshots.forEach { screenshot in
            screenshot.status = status
        }
        
        persistenceController.save()
        notifySelectionChanged()
    }
    
    /// 获取指定状态的截图
    /// - Parameter status: 处理状态
    /// - Returns: 符合状态的截图数组
    func getScreenshots(withStatus status: ProcessingStatus) -> [ScreenshotItem] {
        return screenshots.filter { $0.status == status }
    }
}

// MARK: - Live Photo保存功能
extension ScreenshotManager {
    
    /// 保存Live Photo到系统相册
    /// - Parameters:
    ///   - screenshotItem: Live Photo截图项目
    ///   - completion: 完成回调
    func saveLivePhotoToAlbum(_ screenshotItem: ScreenshotItem, completion: @escaping (Result<Void, Error>) -> Void) {
        guard screenshotItem.mode == .livePhoto,
              let livePhotoVideoPath = screenshotItem.livePhotoVideoPath,
              let livePhotoIdentifier = screenshotItem.livePhotoIdentifier else {
            completion(.failure(ScreenshotError.invalidLivePhoto))
            return
        }
        
        let originalImagePath = screenshotItem.originalImagePath
        
        // 请求照片库权限
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.performLivePhotoSave(
                        imagePath: originalImagePath,
                        videoPath: livePhotoVideoPath,
                        identifier: livePhotoIdentifier,
                        completion: completion
                    )
                    
                case .denied, .restricted:
                    completion(.failure(ScreenshotError.permissionDenied("需要照片库访问权限来保存Live Photo")))
                    
                case .notDetermined:
                    completion(.failure(ScreenshotError.permissionDenied("照片库权限未确定")))
                    
                @unknown default:
                    completion(.failure(ScreenshotError.permissionDenied("未知的权限状态")))
                }
            }
        }
    }
    
    /// 执行Live Photo保存操作
    private func performLivePhotoSave(
        imagePath: URL,
        videoPath: URL,
        identifier: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // 设置Live Photo创建选项
            let imageOptions = PHAssetResourceCreationOptions()
            imageOptions.uniformTypeIdentifier = "public.heic"
            
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.uniformTypeIdentifier = "com.apple.quicktime-movie"
            
            // 添加图片资源
            creationRequest.addResource(
                with: .photo,
                fileURL: imagePath,
                options: imageOptions
            )
            
            // 添加视频资源
            creationRequest.addResource(
                with: .pairedVideo,
                fileURL: videoPath,
                options: videoOptions
            )
            
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? ScreenshotError.saveFailed("Live Photo保存失败")))
                }
            }
        }
    }
    
    /// 批量保存Live Photo到相册
    /// - Parameters:
    ///   - livePhotos: Live Photo截图数组
    ///   - progress: 进度回调 (已完成数量, 总数量)
    ///   - completion: 完成回调 (成功数量, 失败数量)
    func batchSaveLivePhotosToAlbum(
        _ livePhotos: [ScreenshotItem],
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping (Int, Int) -> Void
    ) {
        let validLivePhotos = livePhotos.filter { $0.mode == .livePhoto }
        guard !validLivePhotos.isEmpty else {
            completion(0, 0)
            return
        }
        
        var successCount = 0
        var failureCount = 0
        var completedCount = 0
        
        let totalCount = validLivePhotos.count
        
        for livePhoto in validLivePhotos {
            saveLivePhotoToAlbum(livePhoto) { result in
                completedCount += 1
                
                switch result {
                case .success:
                    successCount += 1
                case .failure:
                    failureCount += 1
                }
                
                // 报告进度
                progress(completedCount, totalCount)
                
                // 检查是否全部完成
                if completedCount == totalCount {
                    completion(successCount, failureCount)
                }
            }
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let screenshotModeChanged = Notification.Name("screenshotModeChanged")
    static let screenshotAdded = Notification.Name("screenshotAdded")
    static let screenshotRemoved = Notification.Name("screenshotRemoved")
    static let allScreenshotsCleared = Notification.Name("allScreenshotsCleared")
    static let screenshotSelectionChanged = Notification.Name("screenshotSelectionChanged")
    static let shouldOpenCamera = Notification.Name("shouldOpenCamera")
    static let videoSessionChanged = Notification.Name("videoSessionChanged")
    static let temporaryScreenshotsCleared = Notification.Name("temporaryScreenshotsCleared")
}
