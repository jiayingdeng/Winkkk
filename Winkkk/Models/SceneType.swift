//
//  SceneType.swift
//  Winkkk
//
//  Created by AI Assistant on 2024/09/20.
//

import Foundation
import UIKit

/// 时间序列录像场景类型
enum SceneType: String, CaseIterable {
    case objectChange = "object_change"    // 物体变化
    case personAction = "person_action"    // 人物动作  
    case sportMotion = "sport_motion"      // 运动轨迹
    
    /// 场景显示名称
    var displayName: String {
        switch self {
        case .objectChange:
            return "物体变化"
        case .personAction:
            return "人物动作"
        case .sportMotion:
            return "运动轨迹"
        }
    }
    
    /// 场景图标
    var icon: String {
        switch self {
        case .objectChange:
            return "🍞"
        case .personAction:
            return "🧘‍♀️"
        case .sportMotion:
            return "🏀"
        }
    }
    
    /// 场景描述
    var description: String {
        switch self {
        case .objectChange:
            return "面包发酵、植物生长等"
        case .personAction:
            return "瑜伽、健身、化妆等"
        case .sportMotion:
            return "投篮、滑板、跳跃等"
        }
    }
    
    /// 难度等级 (1-5星)
    var difficultyLevel: Int {
        switch self {
        case .objectChange:
            return 5  // ⭐⭐⭐⭐⭐ 成功率很高
        case .personAction:
            return 4  // ⭐⭐⭐⭐ 需要一些技巧
        case .sportMotion:
            return 3  // ⭐⭐⭐ 需要较多练习
        }
    }
    
    /// 难度等级显示文本
    var difficultyText: String {
        switch self {
        case .objectChange:
            return "⭐⭐⭐⭐⭐ 成功率很高"
        case .personAction:
            return "⭐⭐⭐⭐ 需要一些技巧"
        case .sportMotion:
            return "⭐⭐⭐ 需要较多练习"
        }
    }
    
    /// 是否推荐新手
    var isRecommendedForBeginners: Bool {
        return self == .objectChange
    }
}

/// 拍摄指导内容
struct ShootingGuide {
    let sceneType: SceneType
    let tips: [String]
    let duration: String
    let setupInstructions: [String]
    
    static func guide(for sceneType: SceneType) -> ShootingGuide {
        switch sceneType {
        case .objectChange:
            return ShootingGuide(
                sceneType: sceneType,
                tips: [
                    "手机固定在三脚架上",
                    "保持背景完全不变",
                    "室内光线稳定",
                    "确保主体在画面中央"
                ],
                duration: "建议录制8-15秒",
                setupInstructions: [
                    "将手机放在三脚架上",
                    "调整好拍摄角度",
                    "确认背景干净整洁",
                    "测试光线是否充足"
                ]
            )
            
        case .personAction:
            return ShootingGuide(
                sceneType: sceneType,
                tips: [
                    "确保人物完全在画面内",
                    "背景尽量简洁",
                    "动作要相对缓慢",
                    "保持手机稳定"
                ],
                duration: "建议录制10-20秒",
                setupInstructions: [
                    "选择合适的拍摄距离",
                    "确保人物动作空间足够",
                    "调整手机高度",
                    "准备稳定的拍摄姿势"
                ]
            )
            
        case .sportMotion:
            return ShootingGuide(
                sceneType: sceneType,
                tips: [
                    "手机必须完全固定不动",
                    "使用三脚架或稳定支架",
                    "保持拍摄角度不变",
                    "确保运动在画面范围内"
                ],
                duration: "建议录制5-12秒",
                setupInstructions: [
                    "将手机固定在三脚架上",
                    "调整好拍摄角度和距离",
                    "确保运动轨迹完全在画面内",
                    "检查背景是否简洁稳定"
                ]
            )
        }
    }
}

/// 时间序列处理参数
struct TimeSequenceParameters {
    let sceneType: SceneType
    let frameInterval: TimeInterval  // 帧间隔
    let totalFrames: Int            // 总帧数
    let processingMode: ProcessingMode
    
    enum ProcessingMode {
        case sequential     // 顺序处理
        case optimized     // 优化处理
        case highQuality   // 高质量处理
    }
    
    /// 根据场景类型获取默认参数
    static func defaultParameters(for sceneType: SceneType) -> TimeSequenceParameters {
        switch sceneType {
        case .objectChange:
            return TimeSequenceParameters(
                sceneType: sceneType,
                frameInterval: 0.3,           // 每0.3秒一帧
                totalFrames: 12,              // 最多12帧
                processingMode: .optimized
            )
            
        case .personAction:
            return TimeSequenceParameters(
                sceneType: sceneType,
                frameInterval: 0.2,           // 每0.2秒一帧
                totalFrames: 15,              // 最多15帧
                processingMode: .sequential
            )
            
        case .sportMotion:
            return TimeSequenceParameters(
                sceneType: sceneType,
                frameInterval: 0.1,           // 每0.1秒一帧
                totalFrames: 20,              // 最多20帧
                processingMode: .highQuality
            )
        }
    }
}
