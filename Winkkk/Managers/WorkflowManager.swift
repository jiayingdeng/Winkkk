//
//  WorkflowManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  工作流管理器 - 统一管理处理历史和工作流状态
//

import UIKit

// MARK: - 工作流管理器
class WorkflowManager {
    static let shared = WorkflowManager()
    
    private init() {}
    
    // MARK: - Properties
    private var currentWorkflow: WorkflowHistory?
    private var workflowHistories: [WorkflowHistory] = []
    private let maxHistoryCount = 10 // 最多保存10个历史记录
    
    // MARK: - Current Workflow Management
    
    /// 开始新的工作流
    func startNewWorkflow(with screenshots: [ScreenshotItem]) {
        var newWorkflow = WorkflowHistory()
        newWorkflow.addStep(.originalScreenshots(screenshots))
        currentWorkflow = newWorkflow
        
        print("🚀 WorkflowManager: 开始新工作流，包含 \(screenshots.count) 张截图")
    }
    
    /// 记录工作流步骤
    func recordStep(_ step: WorkflowStep) {
        guard var workflow = currentWorkflow else {
            print("⚠️ WorkflowManager: 尝试记录步骤但没有活跃的工作流")
            return
        }
        
        workflow.addStep(step)
        currentWorkflow = workflow
        
        print("📝 WorkflowManager: 记录步骤 - \(step.description)")
    }
    
    /// 完成当前工作流
    func finishCurrentWorkflow() {
        guard let workflow = currentWorkflow else { return }
        
        // 保存到历史记录
        workflowHistories.insert(workflow, at: 0)
        
        // 限制历史记录数量
        if workflowHistories.count > maxHistoryCount {
            workflowHistories.removeLast()
        }
        
        print("✅ WorkflowManager: 完成工作流，共 \(workflow.stepCount) 个步骤，耗时 \(String(format: "%.1f", workflow.duration))秒")
        
        currentWorkflow = nil
    }
    
    /// 取消当前工作流
    func cancelCurrentWorkflow() {
        if let workflow = currentWorkflow {
            print("❌ WorkflowManager: 取消工作流，共 \(workflow.stepCount) 个步骤")
        }
        currentWorkflow = nil
    }
    
    // MARK: - Workflow State Queries
    
    /// 获取当前工作流
    func getCurrentWorkflow() -> WorkflowHistory? {
        return currentWorkflow
    }
    
    /// 获取工作流历史
    func getWorkflowHistories() -> [WorkflowHistory] {
        return workflowHistories
    }
    
    /// 检查是否有活跃的工作流
    func hasActiveWorkflow() -> Bool {
        return currentWorkflow != nil
    }
    
    /// 获取当前工作流的最后步骤类型
    func getCurrentStepType() -> WorkflowStepType? {
        return currentWorkflow?.lastStepType
    }
    
    // MARK: - Capability Checks
    
    /// 检查是否可以创建拼图
    func canCreateCollage(from images: [UIImage]) -> Bool {
        return images.count >= 2
    }
    
    /// 检查是否可以修复图片
    func canEnhanceImage(_ image: UIImage) -> Bool {
        // 检查图片基本要求
        let minSize: CGFloat = 100
        return image.size.width >= minSize && image.size.height >= minSize
    }
    
    /// 检查是否可以批量修复
    func canBatchEnhance(screenshots: [ScreenshotItem]) -> Bool {
        let validImages = screenshots.compactMap { $0.image }.filter { canEnhanceImage($0) }
        return validImages.count >= 2
    }
    
    // MARK: - Smart Recommendations
    
    /// 获取基于当前状态的智能推荐
    func getSmartRecommendations(for screenshots: [ScreenshotItem]) -> [WorkflowRecommendation] {
        let engine = WorkflowRecommendationEngine()
        return engine.getAllRecommendations(for: screenshots)
    }
    
    /// 获取最佳推荐
    func getBestRecommendation(for screenshots: [ScreenshotItem]) -> WorkflowRecommendation {
        let engine = WorkflowRecommendationEngine()
        return engine.getRecommendation(for: screenshots)
    }
    
    // MARK: - Workflow Analytics
    
    /// 获取工作流统计信息
    func getWorkflowStats() -> WorkflowStats {
        let totalWorkflows = workflowHistories.count
        let avgStepsPerWorkflow = workflowHistories.isEmpty ? 0 : 
            Double(workflowHistories.map { $0.stepCount }.reduce(0, +)) / Double(totalWorkflows)
        
        let avgDuration = workflowHistories.isEmpty ? 0 :
            workflowHistories.map { $0.duration }.reduce(0, +) / Double(totalWorkflows)
        
        let mostUsedStepType = getMostUsedStepType()
        
        return WorkflowStats(
            totalWorkflows: totalWorkflows,
            averageStepsPerWorkflow: avgStepsPerWorkflow,
            averageDuration: avgDuration,
            mostUsedStepType: mostUsedStepType
        )
    }
    
    private func getMostUsedStepType() -> WorkflowStepType? {
        var stepTypeCounts: [WorkflowStepType: Int] = [:]
        
        for workflow in workflowHistories {
            for step in workflow.steps {
                stepTypeCounts[step.stepType, default: 0] += 1
            }
        }
        
        return stepTypeCounts.max { $0.value < $1.value }?.key
    }
    
    // MARK: - Debug & Logging
    
    /// 打印当前工作流状态（用于调试）
    func printCurrentWorkflowStatus() {
        guard let workflow = currentWorkflow else {
            print("🔍 WorkflowManager: 无活跃工作流")
            return
        }
        
        print("🔍 WorkflowManager 当前状态:")
        print("  - 步骤数: \(workflow.stepCount)")
        print("  - 持续时间: \(String(format: "%.1f", workflow.duration))秒")
        print("  - 最后步骤: \(workflow.lastStepType?.displayName ?? "无")")
        
        for (index, step) in workflow.steps.enumerated() {
            print("  - 步骤\(index + 1): \(step.description)")
        }
    }
}

// MARK: - 工作流统计信息
struct WorkflowStats {
    let totalWorkflows: Int
    let averageStepsPerWorkflow: Double
    let averageDuration: TimeInterval
    let mostUsedStepType: WorkflowStepType?
    
    var description: String {
        var desc = "工作流统计:\n"
        desc += "总工作流数: \(totalWorkflows)\n"
        desc += "平均步骤数: \(String(format: "%.1f", averageStepsPerWorkflow))\n"
        desc += "平均耗时: \(String(format: "%.1f", averageDuration))秒\n"
        if let mostUsed = mostUsedStepType {
            desc += "最常用步骤: \(mostUsed.displayName) \(mostUsed.emoji)"
        }
        return desc
    }
}



