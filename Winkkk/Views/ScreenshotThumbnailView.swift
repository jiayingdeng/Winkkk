//
//  ScreenshotThumbnailView.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图缩略图视图 - 会话隔离设计
//

import UIKit

class ScreenshotThumbnailView: UIView {
    
    // MARK: - Properties
    var onDeleteTap: (() -> Void)?
    var onTap: (() -> Void)?
    
    private var screenshot: ScreenshotItem?
    
    // MARK: - UI Components
    private let imageView = UIImageView()
    private let deleteButton = UIButton()
    private let timestampLabel = UILabel()
    private let selectionIndicator = UIView()
    private let processingIndicator = UIActivityIndicatorView(style: .medium)
    private let statusBadge = UIView()
    private let statusLabel = UILabel()
    
    // Live Photo专用组件
    private let livePhotoIndicator = UIImageView()
    
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        setupGestures()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // 设置固定尺寸 - 使用高优先级约束以避免冲突
        translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = widthAnchor.constraint(equalToConstant: 60)
        let heightConstraint = heightAnchor.constraint(equalToConstant: 60)
        widthConstraint.priority = UILayoutPriority(999)
        heightConstraint.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            widthConstraint,
            heightConstraint
        ])
        
        // 图片视图
        setupImageView()
        
        // 删除按钮
        setupDeleteButton()
        
        // 时间戳标签
        setupTimestampLabel()
        
        // 选择指示器
        setupSelectionIndicator()
        
        // 处理指示器
        setupProcessingIndicator()
        
        // 状态徽章
        setupStatusBadge()
        
        // Live Photo指示器
        setupLivePhotoIndicator()
        
        
        // 添加到视图
        addSubview(imageView)
        addSubview(deleteButton)
        addSubview(timestampLabel)
        addSubview(selectionIndicator)
        addSubview(processingIndicator)
        addSubview(statusBadge)
        addSubview(livePhotoIndicator)
    }
    
    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        imageView.layer.cornerRadius = 8
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.white.cgColor
        
        // 确保高质量图像渲染
        imageView.layer.contentsGravity = .resizeAspectFill
        imageView.layer.magnificationFilter = .linear
        imageView.layer.minificationFilter = .trilinear
    }
    
    private func setupDeleteButton() {
        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = .white
        deleteButton.layer.cornerRadius = 10
        deleteButton.layer.shadowColor = UIColor.black.cgColor
        deleteButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        deleteButton.layer.shadowRadius = 2
        deleteButton.layer.shadowOpacity = 0.3
        
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    private func setupTimestampLabel() {
        timestampLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        timestampLabel.textColor = .white
        timestampLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        timestampLabel.textAlignment = .center
        timestampLabel.layer.cornerRadius = 6
        timestampLabel.clipsToBounds = true
    }
    
    private func setupSelectionIndicator() {
        selectionIndicator.backgroundColor = ThemeManager.buttonPrimary
        selectionIndicator.layer.cornerRadius = 4
        selectionIndicator.isHidden = true
        
        // 添加发光效果
        selectionIndicator.layer.shadowColor = ThemeManager.buttonPrimary.cgColor
        selectionIndicator.layer.shadowOffset = CGSize(width: 0, height: 0)
        selectionIndicator.layer.shadowRadius = 4
        selectionIndicator.layer.shadowOpacity = 0.8
    }
    
    private func setupProcessingIndicator() {
        processingIndicator.color = UIColor.white
        processingIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        processingIndicator.layer.cornerRadius = 8
        processingIndicator.isHidden = true
    }
    
    private func setupStatusBadge() {
        statusBadge.layer.cornerRadius = 8
        statusBadge.isHidden = true
        
        statusLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusBadge.addSubview(statusLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: statusBadge.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor)
        ])
    }
    
    private func setupLivePhotoIndicator() {
        livePhotoIndicator.image = UIImage(systemName: "livephoto")
        livePhotoIndicator.tintColor = .white
        livePhotoIndicator.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        livePhotoIndicator.layer.cornerRadius = 8
        livePhotoIndicator.clipsToBounds = true
        livePhotoIndicator.contentMode = .center
        livePhotoIndicator.isHidden = true
        
        // 添加动画效果
        addLivePhotoAnimation()
    }
    
    private func addLivePhotoAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.1
        pulseAnimation.duration = 1.0
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        livePhotoIndicator.layer.add(pulseAnimation, forKey: "livePhotoPulse")
    }
    
    
    private func setupConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        processingIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        livePhotoIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 图片视图 - 填满整个视图
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 删除按钮 - 右上角
            deleteButton.topAnchor.constraint(equalTo: topAnchor, constant: -8),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
            deleteButton.widthAnchor.constraint(equalToConstant: 20),
            deleteButton.heightAnchor.constraint(equalToConstant: 20),
            
            // 时间戳标签 - 底部中央
            timestampLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            timestampLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            timestampLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 50),
            timestampLabel.heightAnchor.constraint(equalToConstant: 12),
            
            // 选择指示器 - 左上角
            selectionIndicator.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            selectionIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 8),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            // 处理指示器 - 中央
            processingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            processingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            processingIndicator.widthAnchor.constraint(equalToConstant: 16),
            processingIndicator.heightAnchor.constraint(equalToConstant: 16),
            
            // 状态徽章 - 右下角
            statusBadge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            statusBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            statusBadge.widthAnchor.constraint(equalToConstant: 16),
            statusBadge.heightAnchor.constraint(equalToConstant: 16),
            
            // Live Photo指示器 - 左下角
            livePhotoIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            livePhotoIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            livePhotoIndicator.widthAnchor.constraint(equalToConstant: 16),
            livePhotoIndicator.heightAnchor.constraint(equalToConstant: 16),
            
        ])
    }
    
    private func setupGestures() {
        // 点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(thumbnailTapped))
        addGestureRecognizer(tapGesture)
        
        isUserInteractionEnabled = true
    }
    
    // MARK: - Public Methods
    func configure(with screenshot: ScreenshotItem) {
        self.screenshot = screenshot
        
        // 设置图片
        imageView.image = screenshot.image
        
        // 设置时间戳
        timestampLabel.text = String.formatTime(screenshot.timestamp)
        
        // 设置选择状态
        selectionIndicator.isHidden = !screenshot.isSelected
        
        // 设置处理状态
        updateProcessingStatus(screenshot.status)
        
        // 设置模式特定的显示
        updateModeSpecificDisplay(for: screenshot.mode)
        
        // 更新边框颜色
        updateBorderColor(for: screenshot.mode, status: screenshot.status)
    }
    
    private func updateProcessingStatus(_ status: ProcessingStatus) {
        switch status {
        case .original:
            processingIndicator.isHidden = true
            processingIndicator.stopAnimating()
            statusBadge.isHidden = true
            imageView.alpha = 1.0
            
        case .enhancing:
            processingIndicator.isHidden = false
            processingIndicator.startAnimating()
            statusBadge.isHidden = true
            imageView.alpha = 0.7
            
        case .enhanced:
            processingIndicator.isHidden = true
            processingIndicator.stopAnimating()
            statusBadge.isHidden = false
            statusBadge.backgroundColor = UIColor.systemGreen
            statusLabel.text = "✓"
            imageView.alpha = 1.0
            
        case .failed:
            processingIndicator.isHidden = true
            processingIndicator.stopAnimating()
            statusBadge.isHidden = false
            statusBadge.backgroundColor = UIColor.systemRed
            statusLabel.text = "!"
            imageView.alpha = 0.8
        }
    }
    
    private func updateModeSpecificDisplay(for mode: CaptureMode) {
        switch mode {
        case .stillImage:
            livePhotoIndicator.isHidden = true
            
        case .livePhoto:
            livePhotoIndicator.isHidden = false
        }
    }
    
    private func updateBorderColor(for mode: CaptureMode, status: ProcessingStatus) {
        let borderColor: UIColor
        
        switch (mode, status) {
        case (.stillImage, .original):
            borderColor = .white
        case (.stillImage, .enhanced):
            borderColor = .systemGreen
        case (.stillImage, .failed):
            borderColor = .systemRed
        case (.livePhoto, _):
            borderColor = .systemRed
        default:
            borderColor = .systemBlue
        }
        
        imageView.layer.borderColor = borderColor.cgColor
    }
    
    
    // MARK: - Actions
    @objc private func deleteButtonTapped() {
        // 添加删除动画
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.alpha = 0
        }) { _ in
            self.onDeleteTap?()
        }
        
        // 触觉反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func thumbnailTapped() {
        // 添加点击反馈动画
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
        
        // 普通点击回调
        onTap?()
        
        // 触觉反馈
        HapticFeedbackManager.shared.lightImpact()
    }
}

// MARK: - 动画扩展
extension ScreenshotThumbnailView {
    
    /// 显示截图成功动画
    func showCaptureSuccessAnimation() {
        // 初始状态
        transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        alpha = 0
        
        // 弹跳出现动画
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.transform = .identity
            self.alpha = 1
        }
        
        // 边框闪烁效果
        let flashAnimation = CABasicAnimation(keyPath: "borderColor")
        flashAnimation.fromValue = UIColor.systemGreen.cgColor
        flashAnimation.toValue = UIColor.white.cgColor
        flashAnimation.duration = 0.5
        flashAnimation.repeatCount = 2
        flashAnimation.autoreverses = true
        
        imageView.layer.add(flashAnimation, forKey: "borderFlash")
    }
    
    /// 显示删除动画
    func showDeleteAnimation(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.alpha = 0
        }, completion: { _ in
            completion()
        })
    }
}

