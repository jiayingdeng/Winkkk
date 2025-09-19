//
//  ScreenshotThumbnailCollectionViewCell.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  自定义截图缩略图CollectionView Cell - 带删除按钮
//

import UIKit

class ScreenshotThumbnailCollectionViewCell: UICollectionViewCell {
    
    // MARK: - Properties
    var onDeleteTap: (() -> Void)?
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    
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
        layer.cornerRadius = ThemeManager.smallCornerRadius
        clipsToBounds = false
        
        // 主图片视图
        setupImageView()
        
        // 🔧 修复任务4: 删除按钮UI
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
        contentView.addSubview(imageView)
        contentView.addSubview(deleteButton)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(selectionIndicator)
        contentView.addSubview(processingIndicator)
        contentView.addSubview(statusBadge)
        contentView.addSubview(livePhotoIndicator)
    }
    
    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = ThemeManager.smallCornerRadius
        imageView.backgroundColor = ThemeManager.cardBackground
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
        
        // 🔧 确保删除按钮可见且可交互
        deleteButton.isHidden = false
        deleteButton.alpha = 1.0
        deleteButton.isUserInteractionEnabled = true
    }
    
    private func setupTimestampLabel() {
        timestampLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        timestampLabel.textColor = .white
        timestampLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        timestampLabel.textAlignment = .center
        timestampLabel.layer.cornerRadius = 4
        timestampLabel.clipsToBounds = true
    }
    
    private func setupSelectionIndicator() {
        selectionIndicator.backgroundColor = ThemeManager.buttonPrimary
        selectionIndicator.layer.cornerRadius = 2
        selectionIndicator.isHidden = true
    }
    
    private func setupProcessingIndicator() {
        processingIndicator.color = .white
        processingIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        processingIndicator.layer.cornerRadius = 15
        processingIndicator.isHidden = true
    }
    
    private func setupStatusBadge() {
        statusBadge.backgroundColor = ThemeManager.success
        statusBadge.layer.cornerRadius = 8
        statusBadge.isHidden = true
        
        statusLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusBadge.addSubview(statusLabel)
    }
    
    private func setupLivePhotoIndicator() {
        livePhotoIndicator.image = UIImage(systemName: "livephoto")
        livePhotoIndicator.tintColor = .white
        livePhotoIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        livePhotoIndicator.layer.cornerRadius = 8
        livePhotoIndicator.clipsToBounds = true
        livePhotoIndicator.isHidden = true
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
            // 主图片视图 - 填充整个cell
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 🔧 修复任务4: 删除按钮 - 右上角
            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -8),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 8),
            deleteButton.widthAnchor.constraint(equalToConstant: 20),
            deleteButton.heightAnchor.constraint(equalToConstant: 20),
            
            // 时间戳标签 - 底部中央
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            timestampLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            timestampLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 50),
            timestampLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // 选择指示器 - 左侧边缘
            selectionIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionIndicator.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 4),
            
            // 处理指示器 - 中央
            processingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            processingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            processingIndicator.widthAnchor.constraint(equalToConstant: 30),
            processingIndicator.heightAnchor.constraint(equalToConstant: 30),
            
            // 状态徽章 - 左上角
            statusBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            statusBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            statusBadge.widthAnchor.constraint(equalToConstant: 16),
            statusBadge.heightAnchor.constraint(equalToConstant: 16),
            
            // Live Photo指示器 - 左下角
            livePhotoIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            livePhotoIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            livePhotoIndicator.widthAnchor.constraint(equalToConstant: 16),
            livePhotoIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        // 状态标签约束
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: statusBadge.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor)
        ])
    }
    
    private func setupGestures() {
        // 点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGesture)
        
        // 长按手势
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(cellLongPressed))
        longPressGesture.minimumPressDuration = 0.5
        contentView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Configuration
    func configure(with screenshot: ScreenshotItem) {
        self.screenshot = screenshot
        
        // 设置图片
        imageView.image = screenshot.image
        
        // 设置时间戳
        timestampLabel.text = formatTimestamp(screenshot.timestamp)
        
        // Live Photo指示器
        livePhotoIndicator.isHidden = !(screenshot.mode == .livePhoto)
        
        // 根据状态更新UI
        updateAppearance(for: screenshot.status)
        
        print("🔧 截图Cell配置完成: \(screenshot.id), Live Photo: \(screenshot.mode == .livePhoto)")
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func updateAppearance(for status: ProcessingStatus) {
        switch status {
        case .original:
            processingIndicator.isHidden = true
            processingIndicator.stopAnimating()
            statusBadge.isHidden = true
            
        case .enhancing:
            processingIndicator.isHidden = false
            processingIndicator.startAnimating()
            statusBadge.isHidden = true
            
        case .enhanced:
            processingIndicator.isHidden = true
            processingIndicator.stopAnimating()
            statusBadge.isHidden = false
            statusBadge.backgroundColor = ThemeManager.success
            statusLabel.text = "✨"
            
        case .failed:
            processingIndicator.isHidden = true
            processingIndicator.stopAnimating()
            statusBadge.isHidden = false
            statusBadge.backgroundColor = ThemeManager.error
            statusLabel.text = "⚠️"
        }
    }
    
    // MARK: - Selection
    func setSelected(_ selected: Bool) {
        selectionIndicator.isHidden = !selected
        
        UIView.animate(withDuration: 0.2) {
            self.transform = selected ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            self.alpha = selected ? 0.8 : 1.0
        }
    }
    
    // MARK: - Actions
    @objc private func deleteButtonTapped() {
        print("🗑️ 删除按钮点击: \(screenshot?.id.uuidString ?? "unknown")")
        
        // 🔧 使用AnimationManager的删除动画和触觉反馈
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.alpha = 0
        }) { _ in
            self.onDeleteTap?()
        }
        
        // 删除按钮按压动画
        AnimationManager.shared.animateButtonPress(deleteButton)
        
        // 触觉反馈
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func cellTapped() {
        print("📱 截图Cell点击: \(screenshot?.id.uuidString ?? "unknown")")
        onTap?()
    }
    
    @objc private func cellLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            print("📱 截图Cell长按: \(screenshot?.id.uuidString ?? "unknown")")
            onLongPress?()
            
            // 触觉反馈
            HapticFeedbackManager.shared.mediumImpact()
        }
    }
    
    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageView.image = nil
        timestampLabel.text = nil
        livePhotoIndicator.isHidden = true
        selectionIndicator.isHidden = true
        processingIndicator.stopAnimating()
        processingIndicator.isHidden = true
        statusBadge.isHidden = true
        
        transform = .identity
        alpha = 1.0
        
        onDeleteTap = nil
        onTap = nil
        onLongPress = nil
        screenshot = nil
    }
}
