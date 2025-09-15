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
    
    // 滑动控制
    private let sliderView = UIView()
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
        
        // 原始图像视图
        originalImageView.contentMode = .scaleAspectFill
        originalImageView.clipsToBounds = true
        addSubview(originalImageView)
        
        // 增强图像视图
        enhancedImageView.contentMode = .scaleAspectFill
        enhancedImageView.clipsToBounds = true
        enhancedImageView.alpha = 0 // 初始隐藏
        addSubview(enhancedImageView)
        
        // 分割线
        dividerView.backgroundColor = .white
        addSubview(dividerView)
        
        // 标签
        setupLabels()
        
        // 滑块
        setupSlider()
        
        setupConstraints()
    }
    
    private func setupLabels() {
        // 原始标签
        originalLabel.text = "修复前"
        originalLabel.textColor = .white
        originalLabel.font = ThemeManager.captionFont
        originalLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        originalLabel.textAlignment = .center
        originalLabel.layer.cornerRadius = 8
        originalLabel.layer.masksToBounds = true
        addSubview(originalLabel)
        
        // 增强标签
        enhancedLabel.text = "修复后"
        enhancedLabel.textColor = .white
        enhancedLabel.font = ThemeManager.captionFont
        enhancedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        enhancedLabel.textAlignment = .center
        enhancedLabel.layer.cornerRadius = 8
        enhancedLabel.layer.masksToBounds = true
        enhancedLabel.alpha = 0
        addSubview(enhancedLabel)
    }
    
    private func setupSlider() {
        // 滑块背景
        sliderView.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        sliderView.layer.cornerRadius = 2
        addSubview(sliderView)
        
        // 滑块手柄
        sliderHandle.backgroundColor = ThemeManager.buttonPrimary
        sliderHandle.layer.cornerRadius = 12
        
        // 添加图标
        let dragIcon = UIImageView(image: UIImage(systemName: "line.3.horizontal"))
        dragIcon.tintColor = .white
        dragIcon.contentMode = .scaleAspectFit
        sliderHandle.addSubview(dragIcon)
        
        sliderView.addSubview(sliderHandle)
        
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
        sliderView.translatesAutoresizingMaskIntoConstraints = false
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
            
            // 分割线
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
            
            // 滑块
            sliderView.centerYAnchor.constraint(equalTo: centerYAnchor),
            sliderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sliderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            sliderView.heightAnchor.constraint(equalToConstant: 4),
            
            // 滑块手柄
            sliderHandle.centerYAnchor.constraint(equalTo: sliderView.centerYAnchor),
            sliderHandle.widthAnchor.constraint(equalToConstant: 24),
            sliderHandle.heightAnchor.constraint(equalToConstant: 40)
        ])
        
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
            
            // 触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        case .changed:
            dividerPosition = newPosition
            
        case .ended, .cancelled:
            // 恢复滑块手柄大小
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.sliderHandle.transform = .identity
            }
            
        default:
            break
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard enhancedImage != nil else { return }
        
        let location = gesture.location(in: self)
        let newPosition = max(0, min(1, location.x / bounds.width))
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.dividerPosition = newPosition
        }
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Layout Updates
    override func layoutSubviews() {
        super.layoutSubviews()
        updateDividerPosition()
    }
    
    private func updateDividerPosition() {
        guard bounds.width > 0 else { return }
        
        let dividerX = bounds.width * dividerPosition
        
        // 更新分割线约束
        dividerView.constraints.forEach { constraint in
            if constraint.firstAttribute == .centerX {
                removeConstraint(constraint)
            }
        }
        
        dividerView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: dividerX).isActive = true
        
        // 更新滑块手柄位置
        sliderHandle.constraints.forEach { constraint in
            if constraint.firstAttribute == .centerX {
                sliderView.removeConstraint(constraint)
            }
        }
        
        sliderHandle.centerXAnchor.constraint(equalTo: sliderView.leadingAnchor, constant: dividerX).isActive = true
        
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
        })
        
        // 自动演示滑动效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.demonstrateSliding()
        }
    }
    
    private func demonstrateSliding() {
        UIView.animate(withDuration: 2.0, delay: 0, options: [.curveEaseInOut, .autoreverse], animations: {
            self.dividerPosition = 0.8
        }) { _ in
            UIView.animate(withDuration: 1.5, delay: 0.5, options: .curveEaseInOut) {
                self.dividerPosition = 0.5
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
