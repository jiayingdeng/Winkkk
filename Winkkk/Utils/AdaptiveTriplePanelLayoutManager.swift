//
//  AdaptiveTriplePanelLayoutManager.swift
//  Winkkk
//
//  Created by AI Assistant on 2025/09/30.
//  三分屏自适应布局管理器 - 为VideoPlayerViewController提供智能布局计算
//

import UIKit

/// 屏幕尺寸分类
enum ScreenCategory {
    case compact    // 紧凑型（iPhone SE, mini系列）
    case regular    // 标准型（主流iPhone）
    case expanded   // 扩展型（Plus, Pro Max系列）
    
    /// 根据可用高度分类屏幕
    static func categorize(availableHeight: CGFloat) -> ScreenCategory {
        switch availableHeight {
        case ..<600:
            return .compact
        case 600..<750:
            return .regular
        default:
            return .expanded
        }
    }
}

/// 三分屏布局配置
struct TriplePanelConfiguration {
    let availableHeight: CGFloat
    
    // 🎯 三个主要区域高度
    let videoPanelHeight: CGFloat           // 视频播放区域
    let controlPanelHeight: CGFloat         // 控制面板区域（时间轴+按钮）
    let previewPanelHeight: CGFloat         // 截图预览区域
    
    // 🎯 各区域占比（用于验证）
    var videoRatio: CGFloat {
        return videoPanelHeight / availableHeight
    }
    
    var controlRatio: CGFloat {
        return controlPanelHeight / availableHeight
    }
    
    var previewRatio: CGFloat {
        return previewPanelHeight / availableHeight
    }
    
    /// 验证配置是否合理
    var isValid: Bool {
        // 视频区域至少200pt
        guard videoPanelHeight >= 200 else { return false }
        
        // 控制区域至少250pt（包含模式切换器44 + 时间轴110 + 按钮等）
        guard controlPanelHeight >= 250 else { return false }
        
        // 预览区域至少60pt（显示缩略图）
        guard previewPanelHeight >= 60 else { return false }
        
        // 总和不超过可用高度
        let totalHeight = videoPanelHeight + controlPanelHeight + previewPanelHeight
        guard totalHeight <= availableHeight + 20 else { return false } // 允许20pt误差
        
        return true
    }
    
    /// 打印调试信息
    func debugPrint() {
        print("📐 三分屏布局配置:")
        print("   可用高度: \(availableHeight)pt")
        print("   视频区域: \(videoPanelHeight)pt (\(String(format: "%.1f", videoRatio * 100))%)")
        print("   控制区域: \(controlPanelHeight)pt (\(String(format: "%.1f", controlRatio * 100))%)")
        print("   预览区域: \(previewPanelHeight)pt (\(String(format: "%.1f", previewRatio * 100))%)")
        print("   配置有效: \(isValid ? "✅" : "❌")")
    }
}

/// 三分屏自适应布局管理器
class AdaptiveTriplePanelLayoutManager {
    
    // MARK: - 主要方法
    
    /// 计算最优布局配置
    /// - Parameter containerView: 容器视图（通常是ViewController.view）
    /// - Returns: 三分屏布局配置
    static func calculateOptimalLayout(for containerView: UIView) -> TriplePanelConfiguration {
        // 计算可用高度
        let safeInsets = containerView.safeAreaInsets
        let totalHeight = containerView.bounds.height
        
        // 扣除安全区域和间距
        let topMargin: CGFloat = 20        // 视频顶部边距
        let videoBottomMargin: CGFloat = 8 // 视频底部到控制面板的间距
        let bottomMargin: CGFloat = 0      // 控制面板贴底，不需要底部边距
        
        let availableHeight = totalHeight - safeInsets.top - safeInsets.bottom - 
                             topMargin - videoBottomMargin - bottomMargin
        
        // 根据屏幕分类获取比例
        let category = ScreenCategory.categorize(availableHeight: availableHeight)
        let ratios = getRatios(for: category)
        
        // 计算各区域高度
        let videoPanelHeight = availableHeight * ratios.video
        let controlPanelHeight = availableHeight * ratios.control
        let previewPanelHeight = availableHeight * ratios.preview
        
        let config = TriplePanelConfiguration(
            availableHeight: availableHeight,
            videoPanelHeight: videoPanelHeight,
            controlPanelHeight: controlPanelHeight,
            previewPanelHeight: previewPanelHeight
        )
        
        // 调试输出
        config.debugPrint()
        
        return config
    }
    
    // MARK: - 私有方法
    
    /// 根据屏幕分类获取各区域比例
    private static func getRatios(for category: ScreenCategory) -> (video: CGFloat, control: CGFloat, preview: CGFloat) {
        switch category {
        case .compact:
            // 小屏设备（iPhone SE 520pt）
            // 统一42%视频区域，确保截图预览栏展开时不遮挡时间标签
            return (
                video: 0.42,    // ~218pt - 为控制区域留出更多空间
                control: 0.46,  // ~239pt - 充足空间容纳截图预览栏
                preview: 0.12   // ~62pt  - 基本预览功能
            )
            
        case .regular:
            // 标准设备（iPhone 15 690pt）
            // 统一42%视频区域，平衡布局
            return (
                video: 0.42,    // ~290pt - 舒适的视频观看
                control: 0.46,  // ~317pt - 充足的操作空间
                preview: 0.12   // ~83pt  - 适中的预览体验
            )
            
        case .expanded:
            // 大屏设备（iPhone 15 Pro Max 852pt）
            // 统一42%视频区域，充分利用大屏空间
            return (
                video: 0.42,    // ~358pt - 宽敞的视频观看
                control: 0.46,  // ~392pt - 舒适的操作体验
                preview: 0.12   // ~102pt - 丰富的预览体验
            )
        }
    }
}
