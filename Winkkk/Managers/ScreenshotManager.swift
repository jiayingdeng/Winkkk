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

// MARK: - 截图管理器
class ScreenshotManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ScreenshotManager()
    
    // MARK: - Published Properties
    @Published var screenshots: [ScreenshotItem] = []
    @Published var currentMode: CaptureMode = .stillImage
    @Published var selectedScreenshots: [ScreenshotItem] = []
    
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
    
    // MARK: - 截图管理
    
    /// 添加截图
    /// - Parameter screenshot: 截图项目
    /// - Throws: 如果超出最大数量限制则抛出错误
    func addScreenshot(_ screenshot: ScreenshotItem) throws {
        // 检查数量限制
        guard screenshots.count < currentMode.maxCount else {
            throw ScreenshotSessionError.maxLimitReached(mode: currentMode, count: currentMode.maxCount)
        }
        
        // 设置截图属性
        screenshot.mode = currentMode
        screenshot.selectionOrder = Int16(screenshots.count)
        screenshot.status = .original
        screenshot.isSelected = false
        
        // 添加到数组
        screenshots.append(screenshot)
        
        // 保存到数据库
        persistenceController.save()
        
        // 通知截图添加
        notifyScreenshotAdded(screenshot)
        
        print("📸 添加截图: \(currentMode.displayName)模式，当前总数: \(screenshots.count)")
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
        persistenceController.delete(screenshot)
        
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
        allScreenshots.forEach { persistenceController.delete($0) }
        
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

// MARK: - 通知名称扩展
extension Notification.Name {
    static let screenshotModeChanged = Notification.Name("screenshotModeChanged")
    static let screenshotAdded = Notification.Name("screenshotAdded")
    static let screenshotRemoved = Notification.Name("screenshotRemoved")
    static let allScreenshotsCleared = Notification.Name("allScreenshotsCleared")
    static let screenshotSelectionChanged = Notification.Name("screenshotSelectionChanged")
}
