//
//  CaptureMode.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图模式枚举 - 会话隔离设计
//

import Foundation

// MARK: - 截图模式枚举
enum CaptureMode: String, CaseIterable {
    case stillImage = "stillImage"     // 普通截图模式
    case livePhoto = "livePhoto"       // Live Photo模式（3秒）
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .stillImage:
            return "普通截图"
        case .livePhoto:
            return "实况照片"
        }
    }
    
    /// 描述文字
    var description: String {
        switch self {
        case .stillImage:
            return "截取当前帧"
        case .livePhoto:
            return "3秒动态图片"
        }
    }
    
    /// 每种模式的最大截图数量
    var maxCount: Int {
        return 16  // 两种模式都支持最多16个
    }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .stillImage:
            return "camera"
        case .livePhoto:
            return "livephoto"
        }
    }
    
    /// 预览栏颜色主题
    var themeColor: UIColor {
        switch self {
        case .stillImage:
            return ThemeManager.buttonPrimary
        case .livePhoto:
            return UIColor.systemRed
        }
    }
}

// MARK: - 截图错误类型
enum ScreenshotSessionError: LocalizedError {
    case maxLimitReached(mode: CaptureMode, count: Int)
    case needConfirmation(currentMode: CaptureMode, newMode: CaptureMode, currentCount: Int)
    case modeConflict(expected: CaptureMode, actual: CaptureMode)
    case captureFailed(reason: String)
    case saveFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .maxLimitReached(let mode, let count):
            return "\(mode.displayName)模式最多支持\(count)张截图"
        case .needConfirmation(let currentMode, let newMode, let currentCount):
            return "切换到\(newMode.displayName)模式将清空当前的\(currentCount)张\(currentMode.displayName)，是否继续？"
        case .modeConflict(let expected, let actual):
            return "模式冲突：期望\(expected.displayName)，实际\(actual.displayName)"
        case .captureFailed(let reason):
            return "截图失败：\(reason)"
        case .saveFailed(let reason):
            return "保存失败：\(reason)"
        }
    }
}

// MARK: - Live Photo配置
struct LivePhotoConfig {
    /// Live Photo持续时间（秒）
    static let duration: Double = 3.0
    
    /// 封面帧位置（相对于开始时间的偏移，秒）
    static let keyPhotoOffset: Double = 1.5
    
    /// 最小视频时长要求（秒）
    static let minimumVideoDuration: Double = 5.0
    
    /// Live Photo文件扩展名
    static let imageExtension = "heic"
    static let videoExtension = "mov"
    
    /// 生成Live Photo文件名
    static func generateFileName() -> String {
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        return "livephoto_\(timestamp)_\(uuid)"
    }
}

import UIKit

// MARK: - 扩展UIColor支持主题
extension UIColor {
    static var captureModeSwitcher: UIColor {
        return UIColor.systemBackground.withAlphaComponent(0.9)
    }
    
    static var captureModeSelected: UIColor {
        return ThemeManager.buttonPrimary
    }
    
    static var captureModeUnselected: UIColor {
        return UIColor.systemGray3
    }
}
