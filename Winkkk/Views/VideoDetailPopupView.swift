//
//  VideoDetailPopupView.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频详情弹窗视图
//

import UIKit

class VideoDetailPopupView: UIView {
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeManager.cardBackground
        view.layer.cornerRadius = ThemeManager.standardCornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.3
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.headlineFont
        label.textColor = ThemeManager.primaryText
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = ThemeManager.backgroundSecondary
        return imageView
    }()
    
    private let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = ThemeManager.secondaryText
        return button
    }()
    
    // MARK: - Properties
    private var videoItem: VideoItem?
    var onClose: (() -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = ThemeManager.popupDimmingBackground
        
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(thumbnailImageView)
        containerView.addSubview(infoStackView)
        containerView.addSubview(closeButton)
        
        // 添加手势关闭
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        addGestureRecognizer(tapGesture)
    }
    
    private func setupConstraints() {
        [containerView, titleLabel, thumbnailImageView, infoStackView, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // 容器视图 - 调整高度，移除按钮后更紧凑
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            containerView.heightAnchor.constraint(equalToConstant: 380),
            
            // 关闭按钮
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            
            // 缩略图
            thumbnailImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            thumbnailImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 120),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // 信息堆栈 - 移除按钮后，底部约束改为相对于容器
            infoStackView.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 20),
            infoStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            infoStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            infoStackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        hideWithAnimation()
    }
    
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        if !containerView.frame.contains(location) {
            hideWithAnimation()
        }
    }
    
    // MARK: - Configuration
    func configure(with videoItem: VideoItem) {
        self.videoItem = videoItem
        
        titleLabel.text = videoItem.fileName
        
        // 设置缩略图
        if let thumbnailPath = videoItem.thumbnailPath,
           FileManager.default.fileExists(atPath: thumbnailPath.path) {
            thumbnailImageView.image = UIImage(contentsOfFile: thumbnailPath.path)
        } else {
            thumbnailImageView.image = UIImage(systemName: "video")
            thumbnailImageView.tintColor = ThemeManager.secondaryText
        }
        
        // 清空现有信息
        infoStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 添加视频信息
        let infoItems = [
            ("来源", videoItem.detailedStatus),
            ("创建时间", formatDate(videoItem.createdDate)),
            ("时长", videoItem.formattedDuration),
            ("分辨率", videoItem.resolutionString),
            ("文件大小", videoItem.formattedFileSize)
        ]
        
        for (label, value) in infoItems {
            let infoView = createInfoRow(label: label, value: value)
            infoStackView.addArrangedSubview(infoView)
        }
    }
    
    private func createInfoRow(label: String, value: String) -> UIView {
        let containerView = UIView()
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = ThemeManager.bodyFont
        labelView.textColor = ThemeManager.secondaryText
        labelView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let valueView = UILabel()
        valueView.text = value
        valueView.font = ThemeManager.bodyFont
        valueView.textColor = ThemeManager.primaryText
        valueView.textAlignment = .right
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        containerView.addSubview(labelView)
        containerView.addSubview(valueView)
        
        labelView.translatesAutoresizingMaskIntoConstraints = false
        valueView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            valueView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            valueView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            valueView.leadingAnchor.constraint(greaterThanOrEqualTo: labelView.trailingAnchor, constant: 16),
            
            containerView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return containerView
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // MARK: - Animation
    func showWithAnimation() {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    func hideWithAnimation() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            self.onClose?()
            self.removeFromSuperview()
        }
    }
}
