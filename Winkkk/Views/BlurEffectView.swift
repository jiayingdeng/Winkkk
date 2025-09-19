//
//  BlurEffectView.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  毛玻璃效果视图
//

import UIKit
import SwiftUI

/// UIKit版本的毛玻璃效果视图
class BlurEffectView: UIVisualEffectView {
    
    /// 毛玻璃效果样式
    enum BlurStyle {
        case light
        case regular  
        case prominent
        case extraLight
        
        var blurEffect: UIBlurEffect {
            switch self {
            case .light:
                return UIBlurEffect(style: .light)
            case .regular:
                return UIBlurEffect(style: .regular)
            case .prominent:
                return UIBlurEffect(style: .prominent)
            case .extraLight:
                return UIBlurEffect(style: .extraLight)
            }
        }
    }
    
    private let customIntensity: CGFloat
    private let customBlurEffect: UIBlurEffect
    private let shouldAddShadow: Bool
    
    /// 初始化方法
    /// - Parameters:
    ///   - style: 毛玻璃样式
    ///   - intensity: 强度 (0.0 - 1.0)
    ///   - shouldAddShadow: 是否添加阴影 (默认为true)
    init(style: BlurStyle = .light, intensity: CGFloat = 1.0, shouldAddShadow: Bool = true) {
        self.customIntensity = max(0.0, min(1.0, intensity))
        self.customBlurEffect = style.blurEffect
        self.shouldAddShadow = shouldAddShadow
        
        super.init(effect: customBlurEffect)
        
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        self.customIntensity = 1.0
        self.customBlurEffect = BlurStyle.light.blurEffect
        self.shouldAddShadow = true
        
        super.init(coder: coder)
        
        setupAppearance()
    }
    
    private func setupAppearance() {
        // 设置背景色增强梦幻效果
        backgroundColor = ThemeManager.cardBackground.withAlphaComponent(0.1)
        
        // 添加微妙的边框
        layer.borderColor = ThemeManager.primaryGradientStart.withAlphaComponent(0.3).cgColor
        layer.borderWidth = 0  // 🎯 移除边框线，消除分割线效果
        layer.cornerRadius = ThemeManager.standardCornerRadius
        layer.masksToBounds = shouldAddShadow ? false : true
        
        // 根据参数决定是否添加阴影
        if shouldAddShadow {
            addShadow()
        }
    }
    
    private func addShadow() {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.shadowOpacity = 1.0
    }
    
    /// 动画更新模糊强度
    func animateIntensity(to newIntensity: CGFloat, duration: TimeInterval = 0.3) {
        let clampedIntensity = max(0.0, min(1.0, newIntensity))
        
        UIView.animate(withDuration: duration) {
            self.effect = clampedIntensity > 0 ? self.customBlurEffect : nil
            self.alpha = clampedIntensity
        }
    }
}

/// SwiftUI版本的毛玻璃效果视图
struct BlurEffect: UIViewRepresentable {
    let style: BlurEffectView.BlurStyle
    let intensity: CGFloat
    let shouldAddShadow: Bool
    
    init(style: BlurEffectView.BlurStyle = .light, intensity: CGFloat = 1.0, shouldAddShadow: Bool = true) {
        self.style = style
        self.intensity = intensity
        self.shouldAddShadow = shouldAddShadow
    }
    
    func makeUIView(context: Context) -> BlurEffectView {
        return BlurEffectView(style: style, intensity: intensity, shouldAddShadow: shouldAddShadow)
    }
    
    func updateUIView(_ uiView: BlurEffectView, context: Context) {
        uiView.animateIntensity(to: intensity)
    }
}

/// 梦幻卡片视图 - 结合毛玻璃效果和渐变边框
struct DreamyCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    init(
        cornerRadius: CGFloat = ThemeManager.standardCornerRadius,
        padding: CGFloat = ThemeManager.standardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                BlurEffect(style: .light, intensity: 0.8)
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ThemeManager.swiftUIPrimaryGradientStart.opacity(0.5),
                                        ThemeManager.swiftUIPrimaryGradientEnd.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

/// 浮动面板视图 - 用于底部控制面板等
struct FloatingPanel<Content: View>: View {
    let content: Content
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(
        height: CGFloat = 100,
        cornerRadius: CGFloat = ThemeManager.largeCornerRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            content
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(
                    BlurEffect(style: .regular, intensity: 0.9)
                        .cornerRadius(cornerRadius, corners: [.topLeft, .topRight])
                )
                .overlay(
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topLeading: cornerRadius,
                            topTrailing: cornerRadius
                        )
                    )
                    .stroke(
                        ThemeManager.swiftUIPrimaryGradientStart.opacity(0.3),
                        lineWidth: 0.5
                    )
                )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// 扩展View以支持指定圆角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 预览
#if DEBUG
struct BlurEffect_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 20) {
                DreamyCard {
                    VStack {
                        Text("梦幻卡片")
                            .font(ThemeManager.swiftUIHeadlineFont)
                            .foregroundColor(ThemeManager.swiftUIPrimaryText)
                        
                        Text("这是一个毛玻璃效果的卡片")
                            .font(ThemeManager.swiftUIBodyFont)
                            .foregroundColor(ThemeManager.swiftUISecondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                
                FloatingPanel(height: 80) {
                    HStack {
                        Text("浮动面板")
                            .font(ThemeManager.swiftUIButtonFont)
                            .foregroundColor(ThemeManager.swiftUIPrimaryText)
                        
                        Spacer()
                        
                        Button("按钮") {
                            // Action
                        }
                        .foregroundColor(ThemeManager.swiftUIButtonPrimary)
                    }
                    .padding(.horizontal, ThemeManager.standardPadding)
                }
            }
        }
    }
}
#endif
