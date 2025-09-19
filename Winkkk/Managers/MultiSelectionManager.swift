//
//  MultiSelectionManager.swift
//  Winkkk
//
//  Created on 2025-01-19.
//

import Foundation
import Combine

/// 多选管理器 - 处理截图的批量选择逻辑
class MultiSelectionManager {
    
    // MARK: - Properties
    static let shared = MultiSelectionManager()
    
    @Published private(set) var selectedItems: [ScreenshotItem] = []
    @Published private(set) var isInSelectionMode: Bool = false
    
    // MARK: - Callbacks
    var onSelectionModeChanged: ((Bool) -> Void)?
    var onSelectedItemsChanged: (([ScreenshotItem], Int) -> Void)?
    
    private init() {}
    
    // MARK: - Selection Mode
    /// 进入选择模式
    func enterSelectionMode() {
        guard !isInSelectionMode else { return }
        
        isInSelectionMode = true
        selectedItems.removeAll()
        
        HapticFeedbackManager.shared.mediumImpact()
        onSelectionModeChanged?(true)
        onSelectedItemsChanged?(selectedItems, selectedItems.count)
    }
    
    /// 退出选择模式
    func exitSelectionMode() {
        guard isInSelectionMode else { return }
        
        isInSelectionMode = false
        selectedItems.removeAll()
        
        HapticFeedbackManager.shared.lightImpact()
        onSelectionModeChanged?(false)
        onSelectedItemsChanged?(selectedItems, selectedItems.count)
    }
    
    /// 切换选择模式
    func toggleSelectionMode() {
        if isInSelectionMode {
            exitSelectionMode()
        } else {
            enterSelectionMode()
        }
    }
    
    // MARK: - Item Selection
    /// 选择项目
    func selectItem(_ item: ScreenshotItem) {
        guard isInSelectionMode else { return }
        
        if let index = selectedItems.firstIndex(where: { $0.id == item.id }) {
            selectedItems.remove(at: index)
        } else {
            selectedItems.append(item)
        }
        
        HapticFeedbackManager.shared.selectionChanged()
        onSelectedItemsChanged?(selectedItems, selectedItems.count)
    }
    
    /// 取消选择项目
    func deselectItem(_ item: ScreenshotItem) {
        guard isInSelectionMode else { return }
        
        if let index = selectedItems.firstIndex(where: { $0.id == item.id }) {
            selectedItems.remove(at: index)
            HapticFeedbackManager.shared.selectionChanged()
            onSelectedItemsChanged?(selectedItems, selectedItems.count)
        }
    }
    
    /// 全选
    func selectAll(_ items: [ScreenshotItem] = []) {
        guard isInSelectionMode else { return }
        
        if items.isEmpty {
            // 如果没有提供items，使用ScreenshotManager的当前截图
            selectedItems = ScreenshotManager.shared.screenshots
        } else {
            selectedItems = items
        }
        
        HapticFeedbackManager.shared.lightImpact()
        onSelectedItemsChanged?(selectedItems, selectedItems.count)
    }
    
    /// 全不选
    func deselectAll() {
        guard isInSelectionMode else { return }
        
        selectedItems.removeAll()
        
        HapticFeedbackManager.shared.lightImpact()
        onSelectedItemsChanged?(selectedItems, selectedItems.count)
    }
    
    /// 检查项目是否被选中
    func isItemSelected(_ item: ScreenshotItem) -> Bool {
        return selectedItems.contains(where: { $0.id == item.id })
    }
    
    // MARK: - State Getters
    var selectedCount: Int {
        return selectedItems.count
    }
    
    // MARK: - Batch Operations
    /// 删除选中的项目
    func deleteSelectedItems() -> [ScreenshotItem] {
        let itemsToDelete = selectedItems
        selectedItems.removeAll()
        
        onSelectedItemsChanged?(selectedItems, selectedItems.count)
        
        return itemsToDelete
    }
    
    /// 获取选中的项目用于分享
    func getSelectedItemsForSharing() -> [ScreenshotItem] {
        return selectedItems
    }
}

// MARK: - Extensions
extension MultiSelectionManager {
    
    /// 重置管理器状态
    func reset() {
        isInSelectionMode = false
        selectedItems.removeAll()
    }
    
    /// 验证选中项目是否仍然有效
    func validateSelection(validItems: [ScreenshotItem]) {
        let validIds = Set(validItems.map { $0.id })
        selectedItems = selectedItems.filter { validIds.contains($0.id) }
        
        if selectedItems.isEmpty && isInSelectionMode {
            exitSelectionMode()
        } else {
            onSelectedItemsChanged?(selectedItems, selectedItems.count)
        }
    }
}
