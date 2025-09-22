//
//  TimeSequenceModeManager.swift
//  Winkkk
//
//  Created by AI Assistant on 2024/09/20.
//

import Foundation
import UIKit

/// 录像模式枚举
enum CameraMode {
    case normal         // 普通录像模式
    case timeSequence   // 时间序列录像模式
}

/// 时间序列模式管理器
class TimeSequenceModeManager {
    
    // MARK: - 单例
    static let shared = TimeSequenceModeManager()
    private init() {}
    
    // MARK: - 功能开关
    /// 时间序列模式功能开关
    static var isTimeSequenceModeEnabled: Bool = true
    
    // MARK: - 状态管理
    /// 当前录像模式
    private(set) var currentMode: CameraMode = .normal
    
    /// 选择的场景类型
    private(set) var selectedSceneType: SceneType?
    
    /// 时间序列处理参数
    private(set) var processingParameters: TimeSequenceParameters?
    
    /// 模式状态变化通知
    static let modeDidChangeNotification = Notification.Name("TimeSequenceModeDidChange")
    
    // MARK: - 模式切换
    
    /// 切换到时间序列模式
    /// - Parameter sceneType: 选择的场景类型
    func switchToTimeSequenceMode(with sceneType: SceneType) {
        guard Self.isTimeSequenceModeEnabled else {
            print("⚠️ 时间序列模式已禁用")
            return
        }
        
        currentMode = .timeSequence
        selectedSceneType = sceneType
        processingParameters = TimeSequenceParameters.defaultParameters(for: sceneType)
        
        print("✅ 已切换到时间序列模式：\(sceneType.displayName)")
        postModeChangeNotification()
    }
    
    /// 切换到普通模式
    func switchToNormalMode() {
        currentMode = .normal
        selectedSceneType = nil
        processingParameters = nil
        
        print("✅ 已切换到普通录像模式")
        postModeChangeNotification()
    }
    
    /// 重置到默认状态
    func reset() {
        switchToNormalMode()
    }
    
    // MARK: - 状态查询
    
    /// 是否为时间序列模式
    var isTimeSequenceMode: Bool {
        return currentMode == .timeSequence
    }
    
    /// 是否为普通模式
    var isNormalMode: Bool {
        return currentMode == .normal
    }
    
    /// 获取当前模式显示名称
    var currentModeDisplayName: String {
        switch currentMode {
        case .normal:
            return "普通录像"
        case .timeSequence:
            if let sceneType = selectedSceneType {
                return "时间序列 - \(sceneType.displayName)"
            } else {
                return "时间序列录像"
            }
        }
    }
    
    /// 获取模式图标
    var currentModeIcon: String {
        switch currentMode {
        case .normal:
            return "📹"
        case .timeSequence:
            return "⏰"
        }
    }
    
    // MARK: - 参数管理
    
    /// 更新处理参数
    /// - Parameter parameters: 新的处理参数
    func updateProcessingParameters(_ parameters: TimeSequenceParameters) {
        guard isTimeSequenceMode else {
            print("⚠️ 当前不是时间序列模式，无法更新参数")
            return
        }
        
        processingParameters = parameters
        print("✅ 已更新时间序列处理参数")
    }
    
    /// 获取当前场景的拍摄指导
    func getCurrentShootingGuide() -> ShootingGuide? {
        guard let sceneType = selectedSceneType else { return nil }
        return ShootingGuide.guide(for: sceneType)
    }
    
    // MARK: - 视频处理
    
    /// 统一处理视频选择逻辑
    /// - Parameters:
    ///   - videoURL: 选中的视频URL
    ///   - viewController: 当前视图控制器
    func handleVideoSelection(_ videoURL: URL, from viewController: UIViewController) {
        if isTimeSequenceMode, let sceneType = selectedSceneType {
            // 时间序列模式：跳转到时间序列处理界面
            print("🎬 时间序列模式：跳转到时间序列处理界面")
            let timeSequenceVC = TimeSequenceViewController(videoURL: videoURL, sceneType: sceneType)
            let navController = UINavigationController(rootViewController: timeSequenceVC)
            navController.modalPresentationStyle = .fullScreen
            viewController.present(navController, animated: true)
            
            // 重置时间序列模式状态
            reset()
        } else {
            // 普通模式：跳转到视频播放器
            print("📹 普通模式：跳转到视频播放器")
            let playerVC = VideoPlayerViewController(videoURL: videoURL)
            let navController = UINavigationController(rootViewController: playerVC)
            navController.modalPresentationStyle = .fullScreen
            viewController.present(navController, animated: true)
        }
    }
    
    // MARK: - 私有方法
    
    /// 发送模式变化通知
    private func postModeChangeNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.modeDidChangeNotification,
                object: self,
                userInfo: [
                    "mode": self.currentMode,
                    "sceneType": self.selectedSceneType as Any,
                    "parameters": self.processingParameters as Any
                ]
            )
        }
    }
}

// MARK: - 扩展：调试和日志

extension TimeSequenceModeManager {
    
    /// 打印当前状态（调试用）
    func printCurrentStatus() {
        print("📊 时间序列模式管理器状态：")
        print("   功能开关：\(Self.isTimeSequenceModeEnabled ? "✅开启" : "❌关闭")")
        print("   当前模式：\(currentModeDisplayName)")
        
        if let sceneType = selectedSceneType {
            print("   场景类型：\(sceneType.displayName)")
        }
        
        if let params = processingParameters {
            print("   处理参数：")
            print("     帧间隔：\(params.frameInterval)秒")
            print("     总帧数：\(params.totalFrames)")
            print("     处理模式：\(params.processingMode)")
        }
    }
    
    /// 获取状态信息字典（用于调试或数据传递）
    var statusInfo: [String: Any] {
        var info: [String: Any] = [
            "isEnabled": Self.isTimeSequenceModeEnabled,
            "currentMode": currentMode,
            "modeDisplayName": currentModeDisplayName,
            "modeIcon": currentModeIcon
        ]
        
        if let sceneType = selectedSceneType {
            info["sceneType"] = sceneType.rawValue
            info["sceneDisplayName"] = sceneType.displayName
        }
        
        if let params = processingParameters {
            info["frameInterval"] = params.frameInterval
            info["totalFrames"] = params.totalFrames
            info["processingMode"] = params.processingMode
        }
        
        return info
    }
}

// MARK: - 扩展：便利方法

extension TimeSequenceModeManager {
    
    /// 快速设置物体变化模式
    func setObjectChangeMode() {
        switchToTimeSequenceMode(with: .objectChange)
    }
    
    /// 快速设置人物动作模式
    func setPersonActionMode() {
        switchToTimeSequenceMode(with: .personAction)
    }
    
    /// 快速设置运动轨迹模式
    func setSportMotionMode() {
        switchToTimeSequenceMode(with: .sportMotion)
    }
}
