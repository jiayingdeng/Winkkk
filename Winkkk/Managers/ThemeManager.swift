//
//  ThemeManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  主题管理器 - 支持多主题切换
//

import UIKit
import SwiftUI

// MARK: - 主题枚举定义

/// 应用主题类型
enum AppTheme: String, CaseIterable {
    case dreamyGirl      // 梦幻少女
    case lightMinimal    // 简约浅色
    
    var displayName: String {
        switch self {
        case .dreamyGirl: return "梦幻少女 💕"
        case .lightMinimal: return "简约浅色 ☀️"
        }
    }
}

// MARK: - 主题管理器

/// 主题管理器 - 支持多主题切换
class ThemeManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = ThemeManager()
    
    private init() {
        // 从 UserDefaults 读取保存的主题
        if let savedThemeRaw = UserDefaults.standard.string(forKey: "AppTheme"),
           let savedTheme = AppTheme(rawValue: savedThemeRaw) {
            self.currentTheme = savedTheme
        }
    }
    
    // MARK: - 当前主题
    
    /// 当前应用主题（默认：梦幻少女）
    @Published var currentTheme: AppTheme = .dreamyGirl {
        didSet {
            // 保存到 UserDefaults
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "AppTheme")
            // 发送主题切换通知
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
            print("✅ ThemeManager: 主题已切换为 \(currentTheme.displayName)")
        }
    }
    
    /// 切换到指定主题
    func switchTheme(to theme: AppTheme, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: ThemeManager.standardAnimationDuration) {
                self.currentTheme = theme
            }
        } else {
            currentTheme = theme
        }
    }
    
    // MARK: - 主题色彩定义（计算属性 - 根据当前主题动态返回）
    
    /// 主渐变色 - 起始色
    static var primaryGradientStart: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 230/255, green: 179/255, blue: 255/255, alpha: 1.0) // #E6B3FF 粉紫色
        case .lightMinimal:
            return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0) // #FFFFFF 纯白
        }
    }
    
    /// 主渐变色 - 结束色
    static var primaryGradientEnd: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 209/255, blue: 220/255, alpha: 1.0) // #FFD1DC 粉色
        case .lightMinimal:
            return UIColor(red: 245/255, green: 245/255, blue: 247/255, alpha: 1.0) // #F5F5F7 浅灰白
        }
    }
    
    /// 主要文本色
    static var primaryText: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 102/255, green: 51/255, blue: 153/255, alpha: 1.0) // #663399 深紫色
        case .lightMinimal:
            return UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0) // #1C1C1E 几乎黑
        }
    }
    
    /// 次要文本色
    static var secondaryText: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 153/255, green: 102/255, blue: 204/255, alpha: 0.8) // #9966CC 中紫色
        case .lightMinimal:
            return UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1.0) // #8E8E93 中灰色
        }
    }
    
    /// 占位符文本色
    static var placeholderText: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 200/255, green: 170/255, blue: 230/255, alpha: 0.6) // 浅紫色
        case .lightMinimal:
            return UIColor(red: 199/255, green: 199/255, blue: 204/255, alpha: 0.6) // #C7C7CC 浅灰色
        }
    }
    
    /// 背景色
    static var background: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor.white // 纯白
        case .lightMinimal:
            return UIColor.white // 纯白
        }
    }
    
    /// 卡片背景色
    static var cardBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 252/255, green: 240/255, blue: 255/255, alpha: 0.8) // #FCF0FF 浅粉色
        case .lightMinimal:
            return UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.95) // #FFFFFF 纯白（稍微半透明）
        }
    }
    
    /// 按钮主色调
    static var buttonPrimary: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 182/255, blue: 193/255, alpha: 1.0) // #FFB6C1 粉色
        case .lightMinimal:
            return UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0) // #1C1C1E 深灰黑
        }
    }
    
    /// 按钮次要色调
    static var buttonSecondary: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 230/255, green: 179/255, blue: 255/255, alpha: 0.6) // 粉紫透明
        case .lightMinimal:
            return UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1.0) // #F2F2F7 浅灰背景
        }
    }
    
    /// 成功色（功能色 - 所有主题通用）
    static var success: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 1.0) // #90EE90 温柔绿
        case .lightMinimal:
            return UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0) // #34C759 iOS系统绿
        }
    }
    
    /// 警告色（功能色 - 所有主题通用）
    static var warning: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 218/255, blue: 185/255, alpha: 1.0) // #FFDAB9 温柔橙
        case .lightMinimal:
            return UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1.0) // #FF9500 iOS系统橙
        }
    }
    
    /// 错误色（功能色 - 所有主题通用）
    static var error: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 182/255, blue: 193/255, alpha: 1.0) // #FFB6C1 温柔红
        case .lightMinimal:
            return UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0) // #FF3B30 iOS系统红
        }
    }
    
    /// 分割线色
    static var separator: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 230/255, green: 179/255, blue: 255/255, alpha: 0.3) // 粉紫透明
        case .lightMinimal:
            return UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0) // #E5E5E5 浅灰线
        }
    }
    
    /// 次要背景色
    static var backgroundSecondary: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 248/255, green: 235/255, blue: 255/255, alpha: 0.5) // #F8EBFF 更浅的粉色
        case .lightMinimal:
            return UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1.0) // #F9F9F9 极浅灰
        }
    }
    
    /// 破坏性操作色（用于删除等危险操作）
    static var destructive: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 182/255, blue: 193/255, alpha: 1.0) // #FFB6C1 温柔红
        case .lightMinimal:
            return UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0) // #FF3B30 iOS系统红
        }
    }
    
    /// 按钮文本色（用于深色按钮上的白色文字）
    static var buttonTextOnPrimary: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return primaryText // 深紫色文字
        case .lightMinimal:
            return UIColor.white // 白色文字（黑色按钮上）
        }
    }
    
    // MARK: - 梦幻主题专属颜色（记录现有的硬编码颜色）
    
    /// FilterBar 背景色（透明，不遮挡渐变背景）
    static var filterBarBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor.clear // 透明，显示浅紫色渐变背景
        case .lightMinimal:
            return UIColor.clear // 透明，显示浅色渐变背景
        }
    }
    
    /// 按钮深紫色（主题色深色调）
    static var buttonDeepPurple: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0) // #663399 深紫色
        case .lightMinimal:
            return UIColor.systemBlue // iOS系统蓝
        }
    }
    
    /// 按钮浅紫色（主题色浅色调）
    static var buttonLightPurple: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0) // #9966CC 浅紫色
        case .lightMinimal:
            return UIColor.systemGray // iOS系统灰
        }
    }
    
    /// 按钮淡粉灰色（主题色柔和调）
    static var buttonPinkGray: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 0.7, green: 0.5, blue: 0.5, alpha: 1.0) // #B38080 淡粉灰色
        case .lightMinimal:
            return UIColor.systemGray2 // iOS系统灰2
        }
    }
    
    /// 时间轴刻度线颜色
    static var timelineTickColor: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 0.3, green: 0.2, blue: 0.5, alpha: 0.8) // #4D3380 深紫色
        case .lightMinimal:
            return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.6) // #333333 深灰色
        }
    }
    
    /// 叠加层文本色（在毛玻璃/半透明背景上的白色文字）
    static var overlayTextWhite: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor.white.withAlphaComponent(0.9) // 保持白色
        case .lightMinimal:
            return UIColor.black.withAlphaComponent(0.9) // 改为黑色
        }
    }
    
    /// 叠加层副标题文本色
    static var overlaySecondaryText: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor.white.withAlphaComponent(0.7) // 保持白色
        case .lightMinimal:
            return UIColor.black.withAlphaComponent(0.6) // 改为黑色
        }
    }
    
    /// 成功提示背景色（温暖的米白色）
    static var successToastBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 252/255, blue: 240/255, alpha: 0.95) // #FFFCF0 温暖的米白色
        case .lightMinimal:
            return UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 0.15) // 系统绿色半透明背景
        }
    }
    
    // MARK: - 录像页面专属颜色
    
    /// 录制指示器颜色（红色）
    static var recordingIndicator: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 107/255, blue: 129/255, alpha: 1.0) // #FF6B81 温柔的粉红
        case .lightMinimal:
            return UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0) // #FF3B30 iOS系统红
        }
    }
    
    /// 录制中按钮背景色（红色）
    static var recordingButtonBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 255/255, green: 107/255, blue: 129/255, alpha: 1.0) // #FF6B81 温柔的粉红
        case .lightMinimal:
            return UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0) // #FF3B30 iOS系统红
        }
    }
    
    /// 时间序列模式背景色
    static var timeSequenceModeBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 178/255, green: 156/255, blue: 250/255, alpha: 0.8) // #B29CFA 梦幻紫色
        case .lightMinimal:
            return UIColor.systemBlue.withAlphaComponent(0.8) // iOS系统蓝
        }
    }
    
    /// 普通录像模式背景色
    static var normalRecordModeBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 0.8) // #90EE90 温柔绿
        case .lightMinimal:
            return UIColor.systemGreen.withAlphaComponent(0.8) // iOS系统绿
        }
    }
    
    /// 半透明遮罩背景（用于loading等）
    static var overlayMaskBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor(red: 102/255, green: 51/255, blue: 153/255, alpha: 0.8) // #663399 深紫色半透明
        case .lightMinimal:
            return UIColor.black.withAlphaComponent(0.7) // 黑色半透明
        }
    }
    
    /// 预览容器背景（暗色背景）
    static var previewBackground: UIColor {
        switch shared.currentTheme {
        case .dreamyGirl:
            return UIColor.black.withAlphaComponent(0.3) // 浅黑色半透明
        case .lightMinimal:
            return UIColor.black.withAlphaComponent(0.3) // 浅黑色半透明
        }
    }
}

// MARK: - SwiftUI Color扩展
extension ThemeManager {
    
    /// SwiftUI版本的主渐变起始色
    static var swiftUIPrimaryGradientStart: Color {
        Color(primaryGradientStart)
    }
    
    /// SwiftUI版本的主渐变结束色
    static var swiftUIPrimaryGradientEnd: Color {
        Color(primaryGradientEnd)
    }
    
    /// SwiftUI版本的主要文本色
    static var swiftUIPrimaryText: Color {
        Color(primaryText)
    }
    
    /// SwiftUI版本的次要文本色
    static var swiftUISecondaryText: Color {
        Color(secondaryText)
    }
    
    /// SwiftUI版本的背景色
    static var swiftUIBackground: Color {
        Color(background)
    }
    
    /// SwiftUI版本的卡片背景色
    static var swiftUICardBackground: Color {
        Color(cardBackground)
    }
    
    /// SwiftUI版本的主要按钮色
    static var swiftUIButtonPrimary: Color {
        Color(buttonPrimary)
    }
}

// MARK: - 渐变定义
extension ThemeManager {
    
    /// 主背景渐变
    static var primaryGradient: CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = [primaryGradientStart.cgColor, primaryGradientEnd.cgColor]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradient.locations = [0.0, 1.0]
        return gradient
    }
    
    /// SwiftUI版本的主背景渐变
    static var swiftUIPrimaryGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [swiftUIPrimaryGradientStart, swiftUIPrimaryGradientEnd]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 按钮渐变
    static var buttonGradient: CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = [buttonPrimary.cgColor, buttonSecondary.cgColor]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.0)
        gradient.locations = [0.0, 1.0]
        return gradient
    }
    
    /// SwiftUI版本的按钮渐变
    static var swiftUIButtonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [swiftUIButtonPrimary, Color(buttonSecondary)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - 字体定义
extension ThemeManager {
    
    /// 大标题字体
    static let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
    
    /// 标题字体
    static let headlineFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
    
    /// 副标题字体
    static let subheadlineFont = UIFont.systemFont(ofSize: 18, weight: .medium)
    
    /// 正文字体
    static let bodyFont = UIFont.systemFont(ofSize: 16, weight: .regular)
    
    /// 小字体
    static let captionFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    
    /// 按钮字体
    static let buttonFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    
    // SwiftUI字体
    static let swiftUITitleFont = Font.system(size: 28, weight: .bold)
    static let swiftUIHeadlineFont = Font.system(size: 22, weight: .semibold)
    static let swiftUISubheadlineFont = Font.system(size: 18, weight: .medium)
    static let swiftUIBodyFont = Font.system(size: 16, weight: .regular)
    static let swiftUICaptionFont = Font.system(size: 14, weight: .regular)
    static let swiftUIButtonFont = Font.system(size: 18, weight: .semibold)
}

// MARK: - 阴影定义
extension ThemeManager {
    
    /// 轻微阴影
    static var lightShadow: NSShadow {
        let shadow = NSShadow()
        switch shared.currentTheme {
        case .dreamyGirl:
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.1)
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            shadow.shadowBlurRadius = 4
        case .lightMinimal:
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.05)
            shadow.shadowOffset = CGSize(width: 0, height: 1)
            shadow.shadowBlurRadius = 2
        }
        return shadow
    }
    
    /// 中等阴影
    static var mediumShadow: NSShadow {
        let shadow = NSShadow()
        switch shared.currentTheme {
        case .dreamyGirl:
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.15)
            shadow.shadowOffset = CGSize(width: 0, height: 4)
            shadow.shadowBlurRadius = 8
        case .lightMinimal:
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.08)
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            shadow.shadowBlurRadius = 4
        }
        return shadow
    }
    
    /// 重阴影
    static var heavyShadow: NSShadow {
        let shadow = NSShadow()
        switch shared.currentTheme {
        case .dreamyGirl:
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.2)
            shadow.shadowOffset = CGSize(width: 0, height: 6)
            shadow.shadowBlurRadius = 12
        case .lightMinimal:
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.12)
            shadow.shadowOffset = CGSize(width: 0, height: 4)
            shadow.shadowBlurRadius = 8
        }
        return shadow
    }
    
    /// 配置阴影（保留以兼容旧代码，但已改为计算属性，此方法可以为空）
    static func configureShadows() {
        // 阴影已改为计算属性，此方法保留用于向后兼容
        print("✅ ThemeManager: Shadows configured (now using computed properties)")
    }
}

// MARK: - 动画配置
extension ThemeManager {
    
    /// 标准动画时长
    static let standardAnimationDuration: TimeInterval = 0.3
    
    /// 快速动画时长
    static let quickAnimationDuration: TimeInterval = 0.15
    
    /// 慢动画时长
    static let slowAnimationDuration: TimeInterval = 0.5
    
    /// 弹簧动画配置
    static let springAnimationDamping: CGFloat = 0.8
    static let springAnimationVelocity: CGFloat = 0.5
    
    /// SwiftUI动画
    static let swiftUIStandardAnimation = Animation.easeInOut(duration: standardAnimationDuration)
    static let swiftUIQuickAnimation = Animation.easeInOut(duration: quickAnimationDuration)
    static let swiftUISlowAnimation = Animation.easeInOut(duration: slowAnimationDuration)
    static let swiftUISpringAnimation = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
}

// MARK: - 几何常量
extension ThemeManager {
    
    /// 标准圆角半径
    static let standardCornerRadius: CGFloat = 12
    
    /// 小圆角半径
    static let smallCornerRadius: CGFloat = 8
    
    /// 大圆角半径
    static let largeCornerRadius: CGFloat = 20
    
    /// 胶囊按钮圆角半径（高度的一半）
    static func capsuleCornerRadius(for height: CGFloat) -> CGFloat {
        return height / 2
    }
    
    /// 标准边距
    static let standardPadding: CGFloat = 16
    
    /// 小边距
    static let smallPadding: CGFloat = 8
    
    /// 大边距
    static let largePadding: CGFloat = 24
    
    /// 按钮高度
    static let buttonHeight: CGFloat = 48
    
    /// 小按钮高度
    static let smallButtonHeight: CGFloat = 36
    
    /// 大按钮高度
    static let largeButtonHeight: CGFloat = 56
}

// MARK: - 通知名称定义
extension Notification.Name {
    /// 主题切换通知
    static let themeDidChange = Notification.Name("ThemeDidChangeNotification")
}

// MARK: - 初始化方法
extension ThemeManager {
    
    /// 配置主题
    func configureTheme() {
        print("🎨 ThemeManager: configureTheme() - START")
        print("🎨 ThemeManager: Current theme is \(currentTheme.displayName)")
        
        do {
            Self.configureShadows()
            print("✅ ThemeManager: Shadows configured")
            
            // 配置全局外观
            configureGlobalAppearance()
            print("✅ ThemeManager: Global appearance configured")
            
        } catch {
            print("❌ ThemeManager: Configuration failed: \(error)")
            // 即使配置失败，也不要抛出错误，让应用继续运行
        }
        
        print("✅ ThemeManager: configureTheme() - COMPLETED")
    }
    
    /// 配置全局外观
    private func configureGlobalAppearance() {
        print("🎨 ThemeManager: Configuring global appearance...")
        
        // 配置导航栏外观
        do {
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.configureWithTransparentBackground()
            navigationBarAppearance.titleTextAttributes = [
                .foregroundColor: Self.primaryText,
                .font: Self.headlineFont
            ]
            navigationBarAppearance.largeTitleTextAttributes = [
                .foregroundColor: Self.primaryText,
                .font: Self.titleFont
            ]
            
            UINavigationBar.appearance().standardAppearance = navigationBarAppearance
            UINavigationBar.appearance().compactAppearance = navigationBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
            print("✅ ThemeManager: Navigation bar configured")
        } catch {
            print("❌ ThemeManager: Navigation bar configuration failed: \(error)")
        }
        
        // 配置标签栏外观
        do {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = Self.cardBackground.withAlphaComponent(0.9)
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            print("✅ ThemeManager: Tab bar configured")
        } catch {
            print("❌ ThemeManager: Tab bar configuration failed: \(error)")
        }
        
        // 配置工具栏外观
        do {
            let toolbarAppearance = UIToolbarAppearance()
            toolbarAppearance.configureWithTransparentBackground()
            
            UIToolbar.appearance().standardAppearance = toolbarAppearance
            UIToolbar.appearance().compactAppearance = toolbarAppearance
            print("✅ ThemeManager: Toolbar configured")
        } catch {
            print("❌ ThemeManager: Toolbar configuration failed: \(error)")
        }
        
        print("✅ ThemeManager: Global appearance configuration completed")
    }
}
