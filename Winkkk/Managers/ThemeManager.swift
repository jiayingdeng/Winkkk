//
//  ThemeManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  梦幻少女主题管理器
//

import UIKit
import SwiftUI

/// 梦幻少女主题管理器
class ThemeManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = ThemeManager()
    
    private init() {}
    
    // MARK: - 主题色彩定义
    
    /// 主渐变色 - 粉紫色
    static let primaryGradientStart = UIColor(red: 230/255, green: 179/255, blue: 255/255, alpha: 1.0) // #E6B3FF
    
    /// 主渐变色 - 粉色
    static let primaryGradientEnd = UIColor(red: 255/255, green: 209/255, blue: 220/255, alpha: 1.0) // #FFD1DC
    
    /// 主要文本色 - 深紫色
    static let primaryText = UIColor(red: 102/255, green: 51/255, blue: 153/255, alpha: 1.0) // #663399
    
    /// 次要文本色 - 中紫色
    static let secondaryText = UIColor(red: 153/255, green: 102/255, blue: 204/255, alpha: 0.8) // #9966CC
    
    /// 占位符文本色
    static let placeholderText = UIColor(red: 200/255, green: 170/255, blue: 230/255, alpha: 0.6)
    
    /// 背景色 - 纯白
    static let background = UIColor.white
    
    /// 卡片背景色 - 浅粉色
    static let cardBackground = UIColor(red: 252/255, green: 240/255, blue: 255/255, alpha: 0.8) // #FCF0FF
    
    /// 按钮主色调
    static let buttonPrimary = UIColor(red: 255/255, green: 182/255, blue: 193/255, alpha: 1.0) // #FFB6C1
    
    /// 按钮次要色调
    static let buttonSecondary = UIColor(red: 230/255, green: 179/255, blue: 255/255, alpha: 0.6)
    
    /// 成功色 - 温柔的绿色
    static let success = UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 1.0) // #90EE90
    
    /// 警告色 - 温柔的橙色  
    static let warning = UIColor(red: 255/255, green: 218/255, blue: 185/255, alpha: 1.0) // #FFDAB9
    
    /// 错误色 - 温柔的红色
    static let error = UIColor(red: 255/255, green: 182/255, blue: 193/255, alpha: 1.0) // #FFB6C1
    
    /// 分割线色
    static let separator = UIColor(red: 230/255, green: 179/255, blue: 255/255, alpha: 0.3)
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
    static let lightShadow = NSShadow()
    
    /// 中等阴影
    static let mediumShadow = NSShadow()
    
    /// 重阴影
    static let heavyShadow = NSShadow()
    
    /// 配置阴影
    static func configureShadows() {
        // 轻微阴影
        lightShadow.shadowColor = UIColor.black.withAlphaComponent(0.1)
        lightShadow.shadowOffset = CGSize(width: 0, height: 2)
        lightShadow.shadowBlurRadius = 4
        
        // 中等阴影
        mediumShadow.shadowColor = UIColor.black.withAlphaComponent(0.15)
        mediumShadow.shadowOffset = CGSize(width: 0, height: 4)
        mediumShadow.shadowBlurRadius = 8
        
        // 重阴影
        heavyShadow.shadowColor = UIColor.black.withAlphaComponent(0.2)
        heavyShadow.shadowOffset = CGSize(width: 0, height: 6)
        heavyShadow.shadowBlurRadius = 12
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

// MARK: - 初始化方法
extension ThemeManager {
    
    /// 配置主题
    func configureTheme() {
        print("🎨 ThemeManager: configureTheme() - START")
        
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
