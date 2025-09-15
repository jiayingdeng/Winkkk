//
//  AnimationManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  动画管理器 - 录制按钮呼吸光效、心形反馈动画等
//

import UIKit

class AnimationManager {
    
    // MARK: - Singleton
    static let shared = AnimationManager()
    private init() {}
    
    // MARK: - Recording Button Animations
    
    /// 开始录制按钮呼吸光效动画
    /// - Parameter button: 录制按钮
    func startRecordingBreathingAnimation(on button: UIView) {
        // 停止现有动画
        stopRecordingBreathingAnimation(on: button)
        
        // 创建呼吸光效动画
        let breathingAnimation = createBreathingAnimation()
        let glowAnimation = createGlowAnimation()
        
        button.layer.add(breathingAnimation, forKey: "breathingAnimation")
        button.layer.add(glowAnimation, forKey: "glowAnimation")
        
        // 添加脉冲动画
        let pulseAnimation = createPulseAnimation()
        button.layer.add(pulseAnimation, forKey: "pulseAnimation")
    }
    
    /// 停止录制按钮呼吸光效动画
    /// - Parameter button: 录制按钮
    func stopRecordingBreathingAnimation(on button: UIView) {
        button.layer.removeAnimation(forKey: "breathingAnimation")
        button.layer.removeAnimation(forKey: "glowAnimation")
        button.layer.removeAnimation(forKey: "pulseAnimation")
    }
    
    /// 创建呼吸动画（大小变化）
    private func createBreathingAnimation() -> CAAnimationGroup {
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.15
        scaleAnimation.duration = 1.5
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 1.0
        opacityAnimation.duration = 1.5
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [scaleAnimation, opacityAnimation]
        groupAnimation.duration = 1.5
        groupAnimation.repeatCount = .infinity
        
        return groupAnimation
    }
    
    /// 创建发光动画
    private func createGlowAnimation() -> CABasicAnimation {
        let glowAnimation = CABasicAnimation(keyPath: "shadowRadius")
        glowAnimation.fromValue = 5
        glowAnimation.toValue = 15
        glowAnimation.duration = 1.5
        glowAnimation.autoreverses = true
        glowAnimation.repeatCount = .infinity
        glowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        return glowAnimation
    }
    
    /// 创建脉冲动画
    private func createPulseAnimation() -> CABasicAnimation {
        let pulseAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        pulseAnimation.fromValue = 0.3
        pulseAnimation.toValue = 0.8
        pulseAnimation.duration = 1.5
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        return pulseAnimation
    }
    
    // MARK: - Heart Animation
    
    /// 显示心形成功动画
    /// - Parameters:
    ///   - in: 父视图
    ///   - at: 中心点位置
    ///   - completion: 动画完成回调
    func showHeartSuccessAnimation(in parentView: UIView, at center: CGPoint, completion: (() -> Void)? = nil) {
        let heartContainer = createHeartContainer()
        heartContainer.center = center
        parentView.addSubview(heartContainer)
        
        // 设置初始状态
        heartContainer.alpha = 0
        heartContainer.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        // 执行动画序列
        UIView.animateKeyframes(withDuration: 2.0, delay: 0, animations: {
            // 第一阶段：出现和放大
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                heartContainer.alpha = 1.0
                heartContainer.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }
            
            // 第二阶段：稳定
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4) {
                heartContainer.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }
            
            // 第三阶段：上升并消失
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                heartContainer.alpha = 0
                heartContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                heartContainer.center.y -= 60
            }
        }) { _ in
            heartContainer.removeFromSuperview()
            completion?()
        }
        
        // 添加粒子效果
        addHeartParticleEffect(to: heartContainer)
    }
    
    /// 创建心形容器
    private func createHeartContainer() -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        
        // 主心形图标
        let heartImageView = UIImageView(image: UIImage(systemName: "heart.fill"))
        heartImageView.tintColor = ThemeManager.buttonPrimary
        heartImageView.frame = CGRect(x: 15, y: 15, width: 50, height: 50)
        heartImageView.contentMode = .scaleAspectFit
        
        // 添加发光效果
        heartImageView.layer.shadowColor = ThemeManager.buttonPrimary.cgColor
        heartImageView.layer.shadowRadius = 15
        heartImageView.layer.shadowOpacity = 0.8
        heartImageView.layer.shadowOffset = .zero
        
        containerView.addSubview(heartImageView)
        
        // 添加背景圆圈
        let backgroundCircle = UIView(frame: containerView.bounds)
        backgroundCircle.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        backgroundCircle.layer.cornerRadius = 40
        containerView.insertSubview(backgroundCircle, at: 0)
        
        return containerView
    }
    
    /// 添加心形粒子效果
    private func addHeartParticleEffect(to containerView: UIView) {
        let emitterLayer = CAEmitterLayer()
        emitterLayer.emitterPosition = CGPoint(x: containerView.bounds.width / 2, y: containerView.bounds.height / 2)
        emitterLayer.emitterShape = .circle
        emitterLayer.emitterSize = CGSize(width: 10, height: 10)
        
        let emitterCell = CAEmitterCell()
        emitterCell.birthRate = 15
        emitterCell.lifetime = 1.0
        emitterCell.velocity = 50
        emitterCell.velocityRange = 20
        emitterCell.emissionRange = .pi * 2
        emitterCell.scale = 0.3
        emitterCell.scaleRange = 0.2
        emitterCell.alphaSpeed = -1.0
        
        // 使用小心形作为粒子
        if let heartImage = UIImage(systemName: "heart.fill")?.withTintColor(ThemeManager.buttonPrimary, renderingMode: .alwaysOriginal) {
            emitterCell.contents = heartImage.cgImage
        }
        
        emitterLayer.emitterCells = [emitterCell]
        containerView.layer.addSublayer(emitterLayer)
        
        // 1秒后移除粒子效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            emitterLayer.removeFromSuperlayer()
        }
    }
    
    // MARK: - Button Press Animations
    
    /// 按钮按下动画
    /// - Parameter button: 按钮视图
    func animateButtonPress(_ button: UIView) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    /// 按钮释放动画
    /// - Parameter button: 按钮视图
    func animateButtonRelease(_ button: UIView) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction]) {
            button.transform = .identity
        }
    }
    
    // MARK: - Transition Animations
    
    /// 淡入动画
    /// - Parameters:
    ///   - view: 目标视图
    ///   - duration: 动画时长
    ///   - completion: 完成回调
    func fadeIn(_ view: UIView, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        view.alpha = 0
        UIView.animate(withDuration: duration, animations: {
            view.alpha = 1.0
        }) { _ in
            completion?()
        }
    }
    
    /// 淡出动画
    /// - Parameters:
    ///   - view: 目标视图
    ///   - duration: 动画时长
    ///   - completion: 完成回调
    func fadeOut(_ view: UIView, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, animations: {
            view.alpha = 0
        }) { _ in
            completion?()
        }
    }
    
    /// 弹簧缩放动画
    /// - Parameters:
    ///   - view: 目标视图
    ///   - fromScale: 起始缩放
    ///   - toScale: 结束缩放
    ///   - completion: 完成回调
    func springScale(_ view: UIView, fromScale: CGFloat = 0.8, toScale: CGFloat = 1.0, completion: (() -> Void)? = nil) {
        view.transform = CGAffineTransform(scaleX: fromScale, y: fromScale)
        
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, animations: {
            view.transform = CGAffineTransform(scaleX: toScale, y: toScale)
        }) { _ in
            completion?()
        }
    }
    
    /// 滑入动画（从底部）
    /// - Parameters:
    ///   - view: 目标视图
    ///   - completion: 完成回调
    func slideInFromBottom(_ view: UIView, completion: (() -> Void)? = nil) {
        let originalCenter = view.center
        view.center.y += view.bounds.height
        view.alpha = 0
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, animations: {
            view.center = originalCenter
            view.alpha = 1.0
        }) { _ in
            completion?()
        }
    }
    
    /// 滑出动画（到底部）
    /// - Parameters:
    ///   - view: 目标视图
    ///   - completion: 完成回调
    func slideOutToBottom(_ view: UIView, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            view.center.y += view.bounds.height
            view.alpha = 0
        }) { _ in
            completion?()
        }
    }
    
    // MARK: - Success Feedback Animation
    
    /// 显示成功反馈动画
    /// - Parameters:
    ///   - view: 目标视图
    ///   - message: 成功消息
    ///   - completion: 完成回调
    func showSuccessFeedback(in view: UIView, message: String = "成功！", completion: (() -> Void)? = nil) {
        let feedbackView = createSuccessFeedbackView(message: message)
        feedbackView.center = view.center
        view.addSubview(feedbackView)
        
        // 初始状态
        feedbackView.alpha = 0
        feedbackView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        // 动画序列
        UIView.animateKeyframes(withDuration: 2.5, delay: 0, animations: {
            // 出现
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                feedbackView.alpha = 1.0
                feedbackView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
            
            // 稳定
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4) {
                feedbackView.transform = .identity
            }
            
            // 消失
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                feedbackView.alpha = 0
                feedbackView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }
        }) { _ in
            feedbackView.removeFromSuperview()
            completion?()
        }
    }
    
    /// 创建成功反馈视图
    private func createSuccessFeedbackView(message: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = ThemeManager.success.withAlphaComponent(0.9)
        containerView.layer.cornerRadius = 25
        
        // 成功图标
        let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkView.tintColor = .white
        checkmarkView.contentMode = .scaleAspectFit
        
        // 消息标签
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = ThemeManager.subheadlineFont
        messageLabel.textAlignment = .center
        
        containerView.addSubview(checkmarkView)
        containerView.addSubview(messageLabel)
        
        // 布局
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: 200),
            containerView.heightAnchor.constraint(equalToConstant: 80),
            
            checkmarkView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            checkmarkView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 30),
            checkmarkView.heightAnchor.constraint(equalToConstant: 30),
            
            messageLabel.leadingAnchor.constraint(equalTo: checkmarkView.trailingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            messageLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        return containerView
    }
    
    // MARK: - Loading Animation
    
    /// 开始加载动画
    /// - Parameter view: 目标视图
    func startLoadingAnimation(on view: UIView) {
        let loadingView = createLoadingView()
        loadingView.tag = 999 // 用于识别和移除
        loadingView.center = view.center
        view.addSubview(loadingView)
        
        // 旋转动画
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = Double.pi * 2
        rotationAnimation.duration = 1.0
        rotationAnimation.repeatCount = .infinity
        
        loadingView.layer.add(rotationAnimation, forKey: "loadingRotation")
        
        // 渐入动画
        fadeIn(loadingView)
    }
    
    /// 停止加载动画
    /// - Parameter view: 目标视图
    func stopLoadingAnimation(on view: UIView) {
        if let loadingView = view.viewWithTag(999) {
            fadeOut(loadingView) {
                loadingView.removeFromSuperview()
            }
        }
    }
    
    /// 创建加载视图
    private func createLoadingView() -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        containerView.layer.cornerRadius = 30
        
        let activityIndicator = UIImageView(image: UIImage(systemName: "arrow.2.circlepath"))
        activityIndicator.tintColor = .white
        activityIndicator.frame = CGRect(x: 15, y: 15, width: 30, height: 30)
        activityIndicator.contentMode = .scaleAspectFit
        
        containerView.addSubview(activityIndicator)
        return containerView
    }
}
