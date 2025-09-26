//
//  CaptureModeSwitcher.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图模式切换器 - 会话隔离设计
//

import UIKit

protocol CaptureModeSwitcherDelegate: AnyObject {
    func captureModeSwitcher(_ switcher: CaptureModeSwitcher, didRequestSwitchTo mode: CaptureMode)
    func captureModeSwitcher(_ switcher: CaptureModeSwitcher, didConfirmSwitchTo mode: CaptureMode)
}

class CaptureModeSwitcher: UIView {
    
    // MARK: - Properties
    weak var delegate: CaptureModeSwitcherDelegate?
    
    private var currentMode: CaptureMode = .stillImage {
        didSet {
            updateButtonStates()
            updateLivePhotoRangeIndicator()
        }
    }
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let blurEffectView = BlurEffectView(style: .regular, intensity: 0.9)
    
    // 模式按钮
    private let stillImageButton = UIButton()
    private let livePhotoButton = UIButton()
    
    // 分隔线
    private let separatorView = UIView()
    
    // Live Photo范围指示器（在TimelineView中显示）
    weak var timelineView: TimelineView?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupGestures()
        updateButtonStates()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        setupGestures()
        updateButtonStates()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // 模糊背景
        blurEffectView.layer.cornerRadius = ThemeManager.standardCornerRadius
        blurEffectView.clipsToBounds = true
        addSubview(blurEffectView)
        
        // 容器视图
        containerView.backgroundColor = .clear
        blurEffectView.contentView.addSubview(containerView)
        
        // 设置按钮
        setupStillImageButton()
        setupLivePhotoButton()
        setupSeparator()
        
        // 添加到容器
        containerView.addSubview(stillImageButton)
        containerView.addSubview(separatorView)
        containerView.addSubview(livePhotoButton)
    }
    
    private func setupStillImageButton() {
        stillImageButton.setTitle("普通截图", for: .normal)
        stillImageButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)  // 🌟 使用填充版图标，更突出
        stillImageButton.titleLabel?.font = ThemeManager.buttonFont.withSize(ThemeManager.buttonFont.pointSize + 1)  // 🌟 稍大字体
        stillImageButton.contentHorizontalAlignment = .center
        stillImageButton.semanticContentAttribute = .forceLeftToRight
        stillImageButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        stillImageButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        
        // 🌟 增强视觉效果 - 主要功能按钮
        stillImageButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        stillImageButton.clipsToBounds = false  // 🌟 允许阴影显示
        
        // 🌟 预设阴影属性（选中时才激活）
        stillImageButton.layer.shadowColor = UIColor.white.cgColor  // 🌟 使用白色阴影
        stillImageButton.layer.shadowOffset = CGSize(width: 0, height: 0)  // 🌟 发光效果不需要偏移
        stillImageButton.layer.shadowOpacity = 0  // 🌟 初始状态不显示
        stillImageButton.layer.shadowRadius = 8   // 🌟 预设发光范围
        
        stillImageButton.addTarget(self, action: #selector(stillImageButtonTapped), for: .touchUpInside)
    }
    
    private func setupLivePhotoButton() {
        livePhotoButton.setTitle("Live Photo", for: .normal)
        livePhotoButton.setImage(UIImage(systemName: "livephoto"), for: .normal)
        livePhotoButton.titleLabel?.font = ThemeManager.buttonFont
        livePhotoButton.contentHorizontalAlignment = .center
        livePhotoButton.semanticContentAttribute = .forceLeftToRight
        livePhotoButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        livePhotoButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        
        // 设置样式
        livePhotoButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        livePhotoButton.clipsToBounds = false  // 🌟 允许阴影显示
        
        // 🌟 预设阴影属性（选中时才激活）
        livePhotoButton.layer.shadowColor = UIColor.white.cgColor  // 🌟 使用白色阴影
        livePhotoButton.layer.shadowOffset = CGSize(width: 0, height: 0)  // 🌟 发光效果不需要偏移
        livePhotoButton.layer.shadowOpacity = 0  // 🌟 初始状态不显示
        livePhotoButton.layer.shadowRadius = 8   // 🌟 预设发光范围
        livePhotoButton.layer.borderWidth = 0
        livePhotoButton.layer.borderColor = UIColor.clear.cgColor
        
        livePhotoButton.addTarget(self, action: #selector(livePhotoButtonTapped), for: .touchUpInside)
    }
    
    private func setupSeparator() {
        separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
    }
    
    private func setupConstraints() {
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        stillImageButton.translatesAutoresizingMaskIntoConstraints = false
        livePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 模糊背景视图
            blurEffectView.topAnchor.constraint(equalTo: topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 容器视图
            containerView.topAnchor.constraint(equalTo: blurEffectView.contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: blurEffectView.contentView.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: blurEffectView.contentView.trailingAnchor, constant: -12),
            containerView.bottomAnchor.constraint(equalTo: blurEffectView.contentView.bottomAnchor, constant: -8),
            
            // 普通截图按钮
            stillImageButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            stillImageButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stillImageButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stillImageButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.48),
            
            // 分隔线
            separatorView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            separatorView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 1),
            separatorView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.6),
            
            // Live Photo按钮
            livePhotoButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            livePhotoButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            livePhotoButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            livePhotoButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.48)
        ])
    }
    
    private func setupGestures() {
        // 为按钮添加触觉反馈和动画
        addButtonTouchEffects(to: stillImageButton)
        addButtonTouchEffects(to: livePhotoButton)
    }
    
    private func addButtonTouchEffects(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    // MARK: - Public Methods
    
    /// 设置当前模式
    /// - Parameter mode: 截图模式
    func setCurrentMode(_ mode: CaptureMode) {
        currentMode = mode
    }
    
    /// 设置关联的时间轴视图
    /// - Parameter timelineView: 时间轴视图
    func setTimelineView(_ timelineView: TimelineView) {
        self.timelineView = timelineView
    }
    
    // MARK: - Private Methods
    
    private func updateButtonStates() {
        // 更新选中状态
        updateButtonAppearance(stillImageButton, isSelected: currentMode == .stillImage)
        updateButtonAppearance(livePhotoButton, isSelected: currentMode == .livePhoto)
        
        // 🌟 为选中的按钮添加微妙的呼吸动画
        if currentMode == .stillImage {
            addBreathingAnimation(to: stillImageButton)
            removeBreathingAnimation(from: livePhotoButton)  // 🌟 移除另一个按钮的动画
        } else if currentMode == .livePhoto {
            addBreathingAnimation(to: livePhotoButton)
            removeBreathingAnimation(from: stillImageButton)  // 🌟 移除另一个按钮的动画
        }
    }
    
    private func updateButtonAppearance(_ button: UIButton, isSelected: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            if isSelected {
                // 🌟 两个按钮都应用相同的发光效果
                button.backgroundColor = UIColor.captureModeSelected.withAlphaComponent(0.8)
                
                // 🌟 发光效果：强烈的白色阴影发光
                button.layer.shadowOpacity = 0.8  // 🌟 增强发光阴影
                button.layer.shadowRadius = 8     // 🌟 增大发光范围
                button.layer.shadowColor = UIColor.white.cgColor  // 🌟 白色发光更明显
                
                // 🌟 边框高亮：2px白色边框，60%透明度
                button.layer.borderWidth = 2.0
                button.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
                
                button.setTitleColor(.white, for: .normal)
                button.tintColor = .white
                button.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                
            } else {
                // 🌟 未选中状态：完全恢复原有样式
                button.backgroundColor = UIColor.captureModeUnselected.withAlphaComponent(0.3)
                button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
                button.tintColor = UIColor.white.withAlphaComponent(0.7)
                button.transform = .identity
                
                // 🌟 完全移除所有特殊效果
                button.layer.shadowOpacity = 0
                button.layer.borderWidth = 0
                button.layer.borderColor = UIColor.clear.cgColor
                
                // 🌟 确保移除所有动画效果
                self.removeBreathingAnimation(from: button)
            }
        }
    }
    
    private func updateLivePhotoRangeIndicator() {
        // 如果是Live Photo模式，在时间轴上显示3秒范围指示器
        // 这里暂时打印，后续与TimelineView集成时实现
        if currentMode == .livePhoto {
            print("🔴 Live Photo模式：显示3秒范围指示器")
        } else {
            print("📷 普通截图模式：隐藏范围指示器")
        }
    }
    
    // 🌟 呼吸动画效果 - 让主要功能更突出
    private func addBreathingAnimation(to button: UIButton) {
        // 移除现有动画
        button.layer.removeAnimation(forKey: "breathing")
        button.layer.removeAnimation(forKey: "glowPulse")
        
        // 创建更明显的发光脉冲动画
        let glowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        glowAnimation.fromValue = 0.3
        glowAnimation.toValue = 1.0  // 🌟 更强的发光效果
        glowAnimation.duration = 1.5  // 🌟 稍快的节奏
        glowAnimation.autoreverses = true
        glowAnimation.repeatCount = .infinity
        glowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // 创建边框闪烁动画
        let borderAnimation = CABasicAnimation(keyPath: "borderColor")
        borderAnimation.fromValue = UIColor.white.withAlphaComponent(0.3).cgColor
        borderAnimation.toValue = UIColor.white.withAlphaComponent(0.9).cgColor  // 🌟 更明显的边框变化
        borderAnimation.duration = 1.5
        borderAnimation.autoreverses = true
        borderAnimation.repeatCount = .infinity
        borderAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // 同时添加两个动画
        button.layer.add(glowAnimation, forKey: "glowPulse")
        button.layer.add(borderAnimation, forKey: "borderPulse")
    }
    
    private func removeBreathingAnimation(from button: UIButton) {
        button.layer.removeAnimation(forKey: "breathing")
        button.layer.removeAnimation(forKey: "glowPulse")
        button.layer.removeAnimation(forKey: "borderPulse")
    }
    
    private func requestModeSwitch(to newMode: CaptureMode) {
        // 检查是否需要确认
        let screenshotManager = ScreenshotManager.shared
        
        do {
            try screenshotManager.switchMode(to: newMode, force: false)
            // 如果成功，直接切换
            currentMode = newMode
            delegate?.captureModeSwitcher(self, didConfirmSwitchTo: newMode)
            
            // 触觉反馈
            HapticFeedbackManager.shared.selectionChanged()
            
        } catch ScreenshotSessionError.needConfirmation(let currentMode, let newMode, let currentCount) {
            // 需要用户确认
            showConfirmationAlert(currentMode: currentMode, newMode: newMode, currentCount: currentCount)
            
        } catch {
            // 其他错误
            print("⚠️ 模式切换失败: \(error.localizedDescription)")
            showErrorAlert(error: error)
        }
    }
    
    private func showConfirmationAlert(currentMode: CaptureMode, newMode: CaptureMode, currentCount: Int) {
        guard let parentViewController = findParentViewController() else { return }
        
        let alert = UIAlertController(
            title: "切换模式",
            message: "切换到\(newMode.displayName)模式将清空当前的\(currentCount)张\(currentMode.displayName)，是否继续？",
            preferredStyle: .alert
        )
        
        // 确定切换
        alert.addAction(UIAlertAction(title: "确定切换", style: .destructive) { [weak self] _ in
            self?.confirmModeSwitch(to: newMode)
        })
        
        // 取消
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.cancelModeSwitch()
        })
        
        parentViewController.present(alert, animated: true)
    }
    
    private func confirmModeSwitch(to newMode: CaptureMode) {
        do {
            try ScreenshotManager.shared.switchMode(to: newMode, force: true)
            currentMode = newMode
            delegate?.captureModeSwitcher(self, didConfirmSwitchTo: newMode)
            
            // 成功触觉反馈
            HapticFeedbackManager.shared.notificationSuccess()
            
        } catch {
            print("⚠️ 强制模式切换失败: \(error.localizedDescription)")
            showErrorAlert(error: error)
        }
    }
    
    private func cancelModeSwitch() {
        // 恢复按钮状态
        updateButtonStates()
        
        // 轻微触觉反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func showErrorAlert(error: Error) {
        guard let parentViewController = findParentViewController() else { return }
        
        let alert = UIAlertController(
            title: "切换失败",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        parentViewController.present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func stillImageButtonTapped() {
        guard currentMode != .stillImage else { return }
        requestModeSwitch(to: .stillImage)
    }
    
    @objc private func livePhotoButtonTapped() {
        guard currentMode != .livePhoto else { return }
        requestModeSwitch(to: .livePhoto)
    }
    
    @objc private func buttonPressed(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            // 恢复到选中状态的缩放
            if (button == self.stillImageButton && self.currentMode == .stillImage) ||
               (button == self.livePhotoButton && self.currentMode == .livePhoto) {
                button.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } else {
                button.transform = .identity
            }
        }
    }
}

// MARK: - 辅助扩展
extension UIView {
    func findParentViewController() -> UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}
