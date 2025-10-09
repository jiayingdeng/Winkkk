//
//  ImageComparisonView.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  图像对比视图 - 左右滑动对比修复前后效果
//

import UIKit

class ImageComparisonView: UIView {
    
    // MARK: - Properties
    private var originalImage: UIImage?
    private var enhancedImage: UIImage?
    
    // MARK: - UI Components
    private let originalImageView = UIImageView()
    private let enhancedImageView = UIImageView()
    private let dividerView = UIView()
    private let originalLabel = UILabel()
    private let enhancedLabel = UILabel()
    private let instructionLabel = UILabel() // 滑动指引标签
    
    // 滑动控制
    private let sliderHandle = UIView()
    
    // 手势
    private var panGesture: UIPanGestureRecognizer!
    
    // 分割位置 (0.0 - 1.0)
    private var dividerPosition: CGFloat = 0.5 {
        didSet {
            updateDividerPosition()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .black
        layer.cornerRadius = ThemeManager.standardCornerRadius
        layer.masksToBounds = true
        
        // 原始图像视图 - 使用 scaleAspectFit 完整显示图片不裁剪
        originalImageView.contentMode = .scaleAspectFit
        originalImageView.clipsToBounds = true
        originalImageView.backgroundColor = .black  // 设置背景色避免空白区域
        addSubview(originalImageView)
        
        // 增强图像视图 - 使用 scaleAspectFit 完整显示图片不裁剪
        enhancedImageView.contentMode = .scaleAspectFit
        enhancedImageView.clipsToBounds = true
        enhancedImageView.backgroundColor = .black  // 设置背景色避免空白区域
        enhancedImageView.alpha = 0 // 初始隐藏
        addSubview(enhancedImageView)
        
        // 分割线
        dividerView.backgroundColor = .white
        addSubview(dividerView)
        
        // 标签
        setupLabels()
        
        // 滑动指引标签
        setupInstructionLabel()
        
        // 拖拽手柄
        setupSliderHandle()
        
        setupConstraints()
    }
    
    private func setupLabels() {
        // 原始标签
        originalLabel.text = "修复前"
        originalLabel.textColor = .white
        originalLabel.font = ThemeManager.captionFont
        originalLabel.backgroundColor = ThemeManager.labelOverlayBackground
        originalLabel.textAlignment = .center
        originalLabel.layer.cornerRadius = 8
        originalLabel.layer.masksToBounds = true
        addSubview(originalLabel)
        
        // 增强标签
        enhancedLabel.text = "修复后"
        enhancedLabel.textColor = .white
        enhancedLabel.font = ThemeManager.captionFont
        enhancedLabel.backgroundColor = ThemeManager.labelOverlayBackground
        enhancedLabel.textAlignment = .center
        enhancedLabel.layer.cornerRadius = 8
        enhancedLabel.layer.masksToBounds = true
        enhancedLabel.alpha = 0
        addSubview(enhancedLabel)
    }
    
    private func setupInstructionLabel() {
        instructionLabel.text = "← 拖动或点击滑块对比效果 →"
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        instructionLabel.backgroundColor = ThemeManager.labelOverlayBackground
        instructionLabel.textAlignment = .center
        instructionLabel.layer.cornerRadius = 12
        instructionLabel.layer.masksToBounds = true
        instructionLabel.alpha = 0 // 初始隐藏
        addSubview(instructionLabel)
    }
    
    private func setupSliderHandle() {
        // 拖拽手柄
        sliderHandle.backgroundColor = ThemeManager.buttonPrimary
        sliderHandle.layer.cornerRadius = 12
        
        // 阴影设置 - 确保阴影不会被裁剪
        sliderHandle.layer.masksToBounds = false
        sliderHandle.layer.shadowColor = UIColor.black.cgColor
        sliderHandle.layer.shadowOffset = CGSize(width: 0, height: 2)
        sliderHandle.layer.shadowRadius = 4
        sliderHandle.layer.shadowOpacity = 0.3
        
        addSubview(sliderHandle)
        
        // 添加图标
        let dragIcon = UIImageView(image: UIImage(systemName: "arrow.left.and.right"))
        dragIcon.tintColor = .white
        dragIcon.contentMode = .scaleAspectFit
        sliderHandle.addSubview(dragIcon)
        
        dragIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dragIcon.centerXAnchor.constraint(equalTo: sliderHandle.centerXAnchor),
            dragIcon.centerYAnchor.constraint(equalTo: sliderHandle.centerYAnchor),
            dragIcon.widthAnchor.constraint(equalToConstant: 16),
            dragIcon.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    private func setupConstraints() {
        originalImageView.translatesAutoresizingMaskIntoConstraints = false
        enhancedImageView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        originalLabel.translatesAutoresizingMaskIntoConstraints = false
        enhancedLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderHandle.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 原始图像视图
            originalImageView.topAnchor.constraint(equalTo: topAnchor),
            originalImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            originalImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            originalImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 增强图像视图
            enhancedImageView.topAnchor.constraint(equalTo: topAnchor),
            enhancedImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            enhancedImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            enhancedImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 分割线 - 垂直约束
            dividerView.topAnchor.constraint(equalTo: topAnchor),
            dividerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            dividerView.widthAnchor.constraint(equalToConstant: 2),
            
            // 原始标签
            originalLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            originalLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            originalLabel.widthAnchor.constraint(equalToConstant: 60),
            originalLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 增强标签
            enhancedLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            enhancedLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            enhancedLabel.widthAnchor.constraint(equalToConstant: 60),
            enhancedLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 滑动指引标签 - 调整位置避免被底部按钮遮挡
            instructionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            instructionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -100), // 从-16改为-100，为底部控制面板留出空间
            instructionLabel.heightAnchor.constraint(equalToConstant: 32),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            
            // 拖拽手柄 - 垂直约束
            sliderHandle.centerYAnchor.constraint(equalTo: centerYAnchor),
            sliderHandle.widthAnchor.constraint(equalToConstant: 24),
            sliderHandle.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 水平约束将在 updateDividerPosition() 中设置
        updateDividerPosition()
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        addGestureRecognizer(panGesture)
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Public Methods
    func setOriginalImage(_ image: UIImage) {
        originalImage = image
        originalImageView.image = image
    }
    
    func setEnhancedImage(_ image: UIImage?) {
        enhancedImage = image
        enhancedImageView.image = image
        
        UIView.animate(withDuration: 0.3) {
            self.enhancedImageView.alpha = image != nil ? 1.0 : 0.0
            self.enhancedLabel.alpha = image != nil ? 1.0 : 0.0
            self.instructionLabel.alpha = image != nil ? 1.0 : 0.0
        }
        
        if image != nil {
            animateSliderIntroduction()
        }
    }
    
    // MARK: - Gesture Handling
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard enhancedImage != nil else { return }
        
        let location = gesture.location(in: self)
        let newPosition = max(0, min(1, location.x / bounds.width))
        
        switch gesture.state {
        case .began:
            // 放大滑块手柄
            UIView.animate(withDuration: 0.2) {
                self.sliderHandle.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }
            
            // 用户开始交互时隐藏指引标签
            UIView.animate(withDuration: 0.2) {
                self.instructionLabel.alpha = 0
            }
            
            // 触觉反馈
            HapticFeedbackManager.shared.sliderValueChanged()
            
        case .changed:
            dividerPosition = newPosition
            // 在拖拽过程中实时更新阴影，但使用主队列确保顺序
            DispatchQueue.main.async {
                self.updateSliderHandleShadow()
            }
            
        case .ended, .cancelled:
            // 恢复滑块手柄大小
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.sliderHandle.transform = .identity
            } completion: { _ in
                // 动画结束后确保阴影位置正确，延迟执行确保动画完全结束
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateSliderHandleShadow()
                }
            }
            
        default:
            break
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard enhancedImage != nil else { return }
        
        let location = gesture.location(in: self)
        let newPosition = max(0, min(1, location.x / bounds.width))
        
        // 用户点击时隐藏指引标签
        UIView.animate(withDuration: 0.2) {
            self.instructionLabel.alpha = 0
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.dividerPosition = newPosition
        } completion: { _ in
            // 点击动画结束后更新阴影
            self.updateSliderHandleShadow()
        }
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Layout Updates
    override func layoutSubviews() {
        super.layoutSubviews()
        updateDividerPosition()
        
        // 布局变化后更新阴影
        DispatchQueue.main.async {
            self.updateSliderHandleShadow()
        }
    }
    
    // 约束引用，避免重复创建
    private var dividerCenterXConstraint: NSLayoutConstraint?
    private var sliderHandleCenterXConstraint: NSLayoutConstraint?
    
    private func updateDividerPosition() {
        guard bounds.width > 0 else { return }
        
        let dividerX = bounds.width * dividerPosition
        
        // 更新分割线约束 - 使用约束引用避免重复创建
        if let existingConstraint = dividerCenterXConstraint {
            existingConstraint.constant = dividerX
        } else {
            dividerCenterXConstraint = dividerView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: dividerX)
            dividerCenterXConstraint?.isActive = true
        }
        
        // 更新拖拽手柄位置 - 使用约束引用避免重复创建
        if let existingConstraint = sliderHandleCenterXConstraint {
            existingConstraint.constant = dividerX
        } else {
            sliderHandleCenterXConstraint = sliderHandle.centerXAnchor.constraint(equalTo: leadingAnchor, constant: dividerX)
            sliderHandleCenterXConstraint?.isActive = true
        }
        
        // 强制布局更新确保约束生效
        layoutIfNeeded()
        
        // 延迟更新阴影路径，确保手柄位置已更新
        DispatchQueue.main.async {
            self.updateSliderHandleShadow()
        }
        
        // 更新蒙版
        updateImageMasks()
    }
    
    private func updateImageMasks() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        let dividerX = bounds.width * dividerPosition
        
        // 原始图像蒙版（左侧）
        let originalMaskLayer = CALayer()
        originalMaskLayer.backgroundColor = UIColor.black.cgColor
        originalMaskLayer.frame = CGRect(x: 0, y: 0, width: dividerX, height: bounds.height)
        originalImageView.layer.mask = originalMaskLayer
        
        // 增强图像蒙版（右侧）
        let enhancedMaskLayer = CALayer()
        enhancedMaskLayer.backgroundColor = UIColor.black.cgColor
        enhancedMaskLayer.frame = CGRect(x: dividerX, y: 0, width: bounds.width - dividerX, height: bounds.height)
        enhancedImageView.layer.mask = enhancedMaskLayer
    }
    
    private func updateSliderHandleShadow() {
        // 确保手柄已完成布局
        guard sliderHandle.bounds.width > 0 && sliderHandle.bounds.height > 0 else {
            // 如果手柄尚未布局完成，延迟执行
            DispatchQueue.main.async {
                self.updateSliderHandleShadow()
            }
            return
        }
        
        // 更新阴影路径确保阴影准确跟随手柄
        let shadowPath = UIBezierPath(roundedRect: sliderHandle.bounds, cornerRadius: 12)
        sliderHandle.layer.shadowPath = shadowPath.cgPath
        
        // 确保阴影属性正确设置
        sliderHandle.layer.shadowColor = UIColor.black.cgColor
        sliderHandle.layer.shadowOffset = CGSize(width: 0, height: 2)
        sliderHandle.layer.shadowRadius = 4
        sliderHandle.layer.shadowOpacity = 0.3
        sliderHandle.layer.masksToBounds = false
    }
    
    // MARK: - Animations
    private func animateSliderIntroduction() {
        // 滑块从中心滑到适当位置
        sliderHandle.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        sliderHandle.alpha = 0
        
        UIView.animateKeyframes(withDuration: 1.0, delay: 0.2, animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                self.sliderHandle.alpha = 1
                self.sliderHandle.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                self.sliderHandle.transform = .identity
            }
        }) { _ in
            // 动画结束后更新阴影
            self.updateSliderHandleShadow()
        }
        
        // 注释掉自动演示滑动效果 - 改为静态提示引导用户手动滑动
        // DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        //     self.demonstrateSliding()
        // }
    }
    
    private func demonstrateSliding() {
        UIView.animate(withDuration: 2.0, delay: 0, options: [.curveEaseInOut, .autoreverse], animations: {
            self.dividerPosition = 0.8
        }) { _ in
            UIView.animate(withDuration: 1.5, delay: 0.5, options: .curveEaseInOut) {
                self.dividerPosition = 0.5
            } completion: { _ in
                // 演示动画结束后更新阴影
                self.updateSliderHandleShadow()
            }
        }
    }
}

// MARK: - Accessibility
extension ImageComparisonView {
    
    override var accessibilityLabel: String? {
        get {
            return "图像对比视图"
        }
        set { }
    }
    
    override var accessibilityHint: String? {
        get {
            return "左右拖动或点击来对比修复前后的效果"
        }
        set { }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            return .adjustable
        }
        set { }
    }
    
    override func accessibilityIncrement() {
        dividerPosition = min(1.0, dividerPosition + 0.1)
    }
    
    override func accessibilityDecrement() {
        dividerPosition = max(0.0, dividerPosition - 0.1)
    }
}

// MARK: - Convenience Methods
extension ImageComparisonView {
    
    /// 重置到中间位置
    func resetToCenter() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.dividerPosition = 0.5
        }
    }
    
    /// 重置到显示完整原图（用于清除修复后图片时）
    func resetToOriginalImage() {
        enhancedImage = nil
        enhancedImageView.image = nil
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, animations: {
            self.enhancedImageView.alpha = 0.0
            self.enhancedLabel.alpha = 0.0
            self.instructionLabel.alpha = 0.0
            self.dividerPosition = 1.0  // 显示完整原图
        }) { _ in
            // 动画完成后更新阴影
            self.updateSliderHandleShadow()
        }
    }
    
    /// 显示完整的原始图像
    func showOriginalImage() {
        UIView.animate(withDuration: 0.3) {
            self.dividerPosition = 1.0
        }
    }
    
    /// 显示完整的增强图像
    func showEnhancedImage() {
        UIView.animate(withDuration: 0.3) {
            self.dividerPosition = 0.0
        }
    }
    
    /// 获取当前选择的图像
    var selectedImage: UIImage? {
        if dividerPosition < 0.5 {
            return enhancedImage
        } else {
            return originalImage
        }
    }
    
    /// 是否显示增强图像为主
    var isShowingEnhancedAsPrimary: Bool {
        return dividerPosition < 0.5
    }
}
