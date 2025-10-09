//
//  ThemedButton.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  主题化按钮组件
//

import UIKit
import SwiftUI

// MARK: - UIKit版本的胶囊按钮
class CapsuleButton: UIButton {
    
    /// 按钮样式
    enum ButtonStyle {
        case primary    // 主要按钮 - 渐变背景
        case secondary  // 次要按钮 - 透明背景带边框
        case ghost      // 幽灵按钮 - 仅文字
        case floating   // 浮动按钮 - 毛玻璃背景
    }
    
    /// 按钮大小
    enum ButtonSize {
        case small      // 36pt
        case medium     // 48pt (默认)
        case large      // 56pt
        
        var height: CGFloat {
            switch self {
            case .small: return ThemeManager.smallButtonHeight
            case .medium: return ThemeManager.buttonHeight
            case .large: return ThemeManager.largeButtonHeight
            }
        }
        
        var font: UIFont {
            switch self {
            case .small: return UIFont.systemFont(ofSize: 14, weight: .semibold)
            case .medium: return ThemeManager.buttonFont
            case .large: return UIFont.systemFont(ofSize: 20, weight: .semibold)
            }
        }
    }
    
    private var buttonStyle: ButtonStyle
    private let buttonSize: ButtonSize
    private let gradientLayer = CAGradientLayer()
    private var heightConstraint: NSLayoutConstraint?
    
    /// 初始化方法
    init(title: String, style: ButtonStyle = .primary, size: ButtonSize = .medium) {
        self.buttonStyle = style
        self.buttonSize = size
        
        super.init(frame: .zero)
        
        setTitle(title, for: .normal)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        self.buttonStyle = .primary
        self.buttonSize = .medium
        
        super.init(coder: coder)
        setupButton()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 更新渐变层frame
        gradientLayer.frame = bounds
        
        // 设置胶囊形状
        layer.cornerRadius = bounds.height / 2
        gradientLayer.cornerRadius = bounds.height / 2
    }
    
    /// 更新按钮样式
    func updateStyle(_ newStyle: ButtonStyle) {
        guard newStyle != buttonStyle else { return }
        
        buttonStyle = newStyle
        
        // 清除现有样式
        clearCurrentStyle()
        
        // 应用新样式
        configureAppearance()
    }
    
    /// 清除当前样式设置
    private func clearCurrentStyle() {
        // 移除渐变层
        gradientLayer.removeFromSuperlayer()
        
        // 清除背景和边框
        backgroundColor = UIColor.clear
        layer.borderWidth = 0
        layer.borderColor = UIColor.clear.cgColor
        
        // 清除阴影
        layer.shadowOpacity = 0
        
        // 清除模糊效果（如果有的话）
        subviews.forEach { view in
            if view is UIVisualEffectView {
                view.removeFromSuperview()
            }
        }
    }
    
    private func setupButton() {
        // 设置基础样式
        titleLabel?.font = buttonSize.font
        
        // 设置约束
        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: buttonSize.height)
        heightConstraint?.isActive = true
        
        // 根据样式配置外观
        configureAppearance()
        
        // 添加交互动画
        setupAnimations()
    }
    
    private func configureAppearance() {
        switch buttonStyle {
        case .primary:
            setupPrimaryStyle()
        case .secondary:
            setupSecondaryStyle()
        case .ghost:
            setupGhostStyle()
        case .floating:
            setupFloatingStyle()
        }
    }
    
    private func setupPrimaryStyle() {
        // 渐变背景
        gradientLayer.colors = [
            ThemeManager.buttonPrimary.cgColor,
            ThemeManager.buttonSecondary.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        layer.insertSublayer(gradientLayer, at: 0)
        
        // 🎨 文字颜色 - 使用专门的按钮文字颜色
        let textColor = ThemeManager.buttonPrimaryText
        
        setTitleColor(textColor, for: .normal)
        setTitleColor(textColor.withAlphaComponent(0.6), for: .highlighted)
        
        // 阴影
        addButtonShadow()
    }
    
    private func setupSecondaryStyle() {
        backgroundColor = UIColor.clear
        layer.borderWidth = 1.5
        layer.borderColor = ThemeManager.buttonPrimary.cgColor
        
        setTitleColor(ThemeManager.buttonPrimary, for: .normal)
        setTitleColor(ThemeManager.buttonPrimary.withAlphaComponent(0.6), for: .highlighted)
    }
    
    private func setupGhostStyle() {
        backgroundColor = UIColor.clear
        
        setTitleColor(ThemeManager.primaryText, for: .normal)
        setTitleColor(ThemeManager.primaryText.withAlphaComponent(0.6), for: .highlighted)
    }
    
    private func setupFloatingStyle() {
        // 毛玻璃效果背景 - 根据主题选择合适的模糊效果
        let blurStyle: UIBlurEffect.Style = ThemeManager.shared.currentTheme == .lightMinimal ? .systemMaterial : .light
        let blurEffect = UIBlurEffect(style: blurStyle)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = buttonSize.height / 2
        blurView.layer.masksToBounds = true
        
        insertSubview(blurView, at: 0)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 文字颜色使用主题的primaryText即可，因为毛玻璃背景会适配
        setTitleColor(ThemeManager.primaryText, for: .normal)
        setTitleColor(ThemeManager.primaryText.withAlphaComponent(0.6), for: .highlighted)
        
        addButtonShadow()
    }
    
    private func addButtonShadow() {
        let shadow = ThemeManager.mediumShadow
        layer.shadowColor = (shadow.shadowColor as? UIColor)?.cgColor ?? UIColor.black.withAlphaComponent(0.15).cgColor
        layer.shadowOffset = shadow.shadowOffset
        layer.shadowRadius = shadow.shadowBlurRadius
        layer.shadowOpacity = 1.0
        layer.masksToBounds = false
    }
    
    private func setupAnimations() {
        addTarget(self, action: #selector(buttonPressed), for: .touchDown)
        addTarget(self, action: #selector(buttonReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    @objc private func buttonPressed() {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased() {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.transform = .identity
        }
    }
}

// MARK: - SwiftUI版本的主题化按钮
struct ThemedButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    let size: ButtonSize
    let isEnabled: Bool
    
    enum ButtonStyle {
        case primary
        case secondary
        case ghost
        case floating
    }
    
    enum ButtonSize {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return ThemeManager.smallButtonHeight
            case .medium: return ThemeManager.buttonHeight
            case .large: return ThemeManager.largeButtonHeight
            }
        }
        
        var font: Font {
            switch self {
            case .small: return Font.system(size: 14, weight: .semibold)
            case .medium: return ThemeManager.swiftUIButtonFont
            case .large: return Font.system(size: 20, weight: .semibold)
            }
        }
    }
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(size.font)
                .foregroundColor(textColor)
                .frame(height: size.height)
                .frame(maxWidth: .infinity)
                .background(backgroundView)
                .overlay(overlayView)
                .cornerRadius(size.height / 2)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isEnabled ? 1.0 : 0.6)
                .shadow(
                    color: shadowColor,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .floating:
            return ThemeManager.swiftUIButtonPrimaryText  // 🎨 使用专门的按钮文字颜色
        case .secondary:
            return ThemeManager.swiftUIButtonPrimary
        case .ghost:
            return ThemeManager.swiftUIPrimaryText
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            ThemeManager.swiftUIButtonGradient
        case .secondary:
            Color.clear
        case .ghost:
            Color.clear
        case .floating:
            BlurEffect(style: .light, intensity: 0.8)
        }
    }
    
    @ViewBuilder
    private var overlayView: some View {
        switch style {
        case .secondary:
            Capsule()
                .stroke(ThemeManager.swiftUIButtonPrimary, lineWidth: 1.5)
        default:
            EmptyView()
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary, .floating:
            return Color.black.opacity(0.15)
        default:
            return Color.clear
        }
    }
}

/// 特殊功能按钮 - 录制按钮
struct RecordButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void
    
    @State private var breathingScale: CGFloat = 1.0
    @State private var breathingOpacity: Double = 1.0
    
    private let buttonSize: CGFloat = 80
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 呼吸光效
                if isRecording {
                    Circle()
                        .fill(ThemeManager.swiftUIButtonPrimary.opacity(0.3))
                        .frame(width: buttonSize + 20, height: buttonSize + 20)
                        .scaleEffect(breathingScale)
                        .opacity(breathingOpacity)
                        .animation(
                            Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: breathingScale
                        )
                }
                
                // 主按钮
                ZStack {
                    Circle()
                        .fill(ThemeManager.swiftUIButtonGradient)
                        .frame(width: buttonSize, height: buttonSize)
                    
                    // 录制状态图标
                    if isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ThemeManager.swiftUIPrimaryText)
                            .frame(width: 24, height: 24)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                    }
                }
            }
        }
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        .onAppear {
            if isRecording {
                startBreathingAnimation()
            }
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                startBreathingAnimation()
            } else {
                stopBreathingAnimation()
            }
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            breathingScale = 1.2
            breathingOpacity = 0.5
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            breathingScale = 1.0
            breathingOpacity = 1.0
        }
    }
}

// MARK: - 预览
#if DEBUG
struct ThemedButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 20) {
                ThemedButton("主要按钮", style: .primary) {
                    print("Primary button tapped")
                }
                .padding(.horizontal)
                
                ThemedButton("次要按钮", style: .secondary) {
                    print("Secondary button tapped")
                }
                .padding(.horizontal)
                
                ThemedButton("幽灵按钮", style: .ghost) {
                    print("Ghost button tapped")
                }
                .padding(.horizontal)
                
                ThemedButton("浮动按钮", style: .floating) {
                    print("Floating button tapped")
                }
                .padding(.horizontal)
                
                RecordButton(isRecording: .constant(false)) {
                    print("Record button tapped")
                }
                
                RecordButton(isRecording: .constant(true)) {
                    print("Recording button tapped")
                }
            }
        }
        .padding()
    }
}
#endif
