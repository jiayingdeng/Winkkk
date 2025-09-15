//
//  GradientBackgroundView.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  梦幻渐变背景视图
//

import UIKit
import SwiftUI

/// UIKit版本的渐变背景视图
class GradientBackgroundView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func setupGradient() {
        // 使用ThemeManager的主渐变配置
        gradientLayer.colors = [
            ThemeManager.primaryGradientStart.cgColor,
            ThemeManager.primaryGradientEnd.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.locations = [0.0, 1.0]
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// 更新渐变色
    func updateGradient(startColor: UIColor, endColor: UIColor) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(ThemeManager.standardAnimationDuration)
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        CATransaction.commit()
    }
    
    /// 动画切换渐变方向
    func animateGradientDirection(startPoint: CGPoint, endPoint: CGPoint) {
        UIView.animate(withDuration: ThemeManager.standardAnimationDuration) {
            self.gradientLayer.startPoint = startPoint
            self.gradientLayer.endPoint = endPoint
        }
    }
}

/// SwiftUI版本的渐变背景视图
struct GradientBackground: View {
    let startColor: Color
    let endColor: Color
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    
    init(
        startColor: Color = ThemeManager.swiftUIPrimaryGradientStart,
        endColor: Color = ThemeManager.swiftUIPrimaryGradientEnd,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) {
        self.startColor = startColor
        self.endColor = endColor
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: startPoint,
            endPoint: endPoint
        )
        .ignoresSafeArea()
    }
}

/// 动画渐变背景视图（SwiftUI）
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    let colors: [Color]
    let animationDuration: Double
    
    init(
        colors: [Color] = [
            ThemeManager.swiftUIPrimaryGradientStart,
            ThemeManager.swiftUIPrimaryGradientEnd,
            Color.white.opacity(0.8)
        ],
        animationDuration: Double = 3.0
    ) {
        self.colors = colors
        self.animationDuration = animationDuration
    }
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: animationDuration)
                    .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - 预览
#if DEBUG
struct GradientBackground_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            GradientBackground()
                .frame(height: 200)
                .overlay(
                    Text("静态渐变背景")
                        .font(ThemeManager.swiftUIHeadlineFont)
                        .foregroundColor(ThemeManager.swiftUIPrimaryText)
                )
            
            AnimatedGradientBackground()
                .frame(height: 200)
                .overlay(
                    Text("动画渐变背景")
                        .font(ThemeManager.swiftUIHeadlineFont)
                        .foregroundColor(ThemeManager.swiftUIPrimaryText)
                )
        }
    }
}
#endif
