//
//  WorkflowModels.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  工作流数据模型 - 支持拼图和画质修复功能的互相集成
//

import UIKit

// MARK: - 工作流步骤枚举
enum WorkflowStep {
    case originalScreenshots([ScreenshotItem])
    case collageCreated(UIImage)
    case imageEnhanced([UIImage])
    case collageFromEnhanced(UIImage)
    
    var description: String {
        switch self {
        case .originalScreenshots(let screenshots):
            return "原始截图 (\(screenshots.count)张)"
        case .collageCreated:
            return "拼图已创建"
        case .imageEnhanced(let images):
            return "图片已修复 (\(images.count)张)"
        case .collageFromEnhanced:
            return "修复图片拼图已创建"
        }
    }
    
    var stepType: WorkflowStepType {
        switch self {
        case .originalScreenshots:
            return .screenshots
        case .collageCreated:
            return .collage
        case .imageEnhanced:
            return .enhance
        case .collageFromEnhanced:
            return .collageFromEnhanced
        }
    }
}

// MARK: - 工作流步骤类型
enum WorkflowStepType {
    case screenshots
    case collage
    case enhance
    case collageFromEnhanced
    
    var displayName: String {
        switch self {
        case .screenshots:
            return "截图"
        case .collage:
            return "拼图"
        case .enhance:
            return "修复"
        case .collageFromEnhanced:
            return "修复拼图"
        }
    }
    
    var emoji: String {
        switch self {
        case .screenshots:
            return "📷"
        case .collage:
            return "🧩"
        case .enhance:
            return "✨"
        case .collageFromEnhanced:
            return "🎨"
        }
    }
}

// MARK: - 工作流推荐结果
struct WorkflowRecommendation {
    let title: String
    let description: String
    let actionTitle: String
    let priority: RecommendationPriority
    let execute: (UIViewController, [ScreenshotItem]) -> Void
    
    enum RecommendationPriority: Int, CaseIterable {
        case high = 3
        case medium = 2
        case low = 1
        
        var displayName: String {
            switch self {
            case .high:
                return "推荐"
            case .medium:
                return "建议"
            case .low:
                return "可选"
            }
        }
        
        var color: UIColor {
            switch self {
            case .high:
                return UIColor.systemBlue
            case .medium:
                return UIColor.systemOrange
            case .low:
                return UIColor.systemGray
            }
        }
    }
}

// MARK: - 工作流推荐引擎
class WorkflowRecommendationEngine {
    
    func getRecommendation(for screenshots: [ScreenshotItem]) -> WorkflowRecommendation {
        let imageCount = screenshots.count
        
        // 根据图片数量和质量智能推荐
        if imageCount == 1 {
            return createSingleImageRecommendation()
        } else if imageCount <= 4 {
            return createSmallBatchRecommendation(count: imageCount)
        } else {
            return createLargeBatchRecommendation(count: imageCount)
        }
    }
    
    private func createSingleImageRecommendation() -> WorkflowRecommendation {
        return WorkflowRecommendation(
            title: "🎨 单图画质修复",
            description: "建议先修复图片质量，获得更清晰的效果",
            actionTitle: "开始修复",
            priority: .high
        ) { viewController, screenshots in
            guard let firstScreenshot = screenshots.first,
                  let image = firstScreenshot.image else { return }
            
            let imageEnhanceVC = ImageEnhanceViewController(
                image: image,
                timestamp: firstScreenshot.timestamp
            )
            viewController.navigationController?.pushViewController(imageEnhanceVC, animated: true)
        }
    }
    
    private func createSmallBatchRecommendation(count: Int) -> WorkflowRecommendation {
        return WorkflowRecommendation(
            title: "🧩 创建拼图",
            description: "\(count)张图片适合先创建拼图，再进行整体画质优化",
            actionTitle: "创建拼图",
            priority: .high
        ) { viewController, screenshots in
            let images = screenshots.compactMap { $0.image }
            let collageVC = CollageViewController(images: images)
            viewController.navigationController?.pushViewController(collageVC, animated: true)
        }
    }
    
    private func createLargeBatchRecommendation(count: Int) -> WorkflowRecommendation {
        return WorkflowRecommendation(
            title: "✨ 批量画质修复",
            description: "\(count)张图片建议先批量修复画质，再选择优质图片创建拼图",
            actionTitle: "批量修复",
            priority: .high
        ) { viewController, screenshots in
            let batchEnhanceVC = BatchImageEnhanceViewController(screenshots: screenshots)
            viewController.navigationController?.pushViewController(batchEnhanceVC, animated: true)
        }
    }
    
    /// 获取所有可用的推荐选项
    func getAllRecommendations(for screenshots: [ScreenshotItem]) -> [WorkflowRecommendation] {
        var recommendations: [WorkflowRecommendation] = []
        let imageCount = screenshots.count
        
        // 单图修复推荐
        if imageCount == 1 {
            recommendations.append(createSingleImageRecommendation())
        }
        
        // 拼图创建推荐
        if imageCount >= 2 {
            recommendations.append(createSmallBatchRecommendation(count: imageCount))
        }
        
        // 批量修复推荐
        if imageCount >= 3 {
            recommendations.append(createLargeBatchRecommendation(count: imageCount))
        }
        
        // 按优先级排序
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
}

// MARK: - 工作流历史记录
struct WorkflowHistory {
    let id = UUID()
    let timestamp = Date()
    var steps: [WorkflowStep] = []
    
    mutating func addStep(_ step: WorkflowStep) {
        steps.append(step)
    }
    
    var duration: TimeInterval {
        guard let firstStep = steps.first else { return 0 }
        // 这里简化处理，实际应该记录每个步骤的时间戳
        return Date().timeIntervalSince(timestamp)
    }
    
    var stepCount: Int {
        return steps.count
    }
    
    var lastStepType: WorkflowStepType? {
        return steps.last?.stepType
    }
}


