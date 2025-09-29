//
//  VideoThumbnailCell.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频缩略图单元格
//

import UIKit
import AVFoundation

class VideoThumbnailCell: UICollectionViewCell {
    
    static let identifier = "VideoThumbnailCell"
    
    // MARK: - UI Components
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = ThemeManager.cardBackground
        return imageView
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.captionFont
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()
    
    private let playIconView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.layer.cornerRadius = 20
        
        let playIcon = UIImageView(image: UIImage(systemName: "play.fill"))
        playIcon.tintColor = .white
        playIcon.contentMode = .scaleAspectFit
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playIcon)
        
        NSLayoutConstraint.activate([
            playIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 16),
            playIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        return view
    }()
    
    private let overlayGradientView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        view.layer.addSublayer(gradient)
        
        return view
    }()
    
    // 新的iOS风格选择UI组件
    private let selectionOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        view.isHidden = true
        return view
    }()
    
    private let selectionCheckmarkView: UIView = {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowRadius = 2
        containerView.layer.shadowOpacity = 0.3
        containerView.isHidden = true
        
        let checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkImageView.tintColor = UIColor.systemBlue
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(checkmarkImageView)
        
        NSLayoutConstraint.activate([
            checkmarkImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return containerView
    }()
    
    // 保留旧的选择指示器以便向后兼容（将在清理步骤中移除）
    // 移除旧的selectionIndicatorView，使用新的选择UI
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        label.textAlignment = .center
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.isHidden = true
        return label
    }()
    
    // MARK: - Properties
    private var videoItem: VideoItem?
    private var thumbnailTask: Task<Void, Never>?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }
    
    // MARK: - Lifecycle
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.image = nil
        durationLabel.text = ""
        statusLabel.text = ""
        statusLabel.isHidden = true
        videoItem = nil
        // 移除了selectionIndicatorView
        selectionOverlayView.isHidden = true
        selectionCheckmarkView.isHidden = true
        
        // 取消缩略图加载任务
        thumbnailTask?.cancel()
        thumbnailTask = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 更新渐变层frame
        if let gradientLayer = overlayGradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = overlayGradientView.bounds
        }
        
        // 更新圆角
        contentView.layer.cornerRadius = ThemeManager.standardCornerRadius
        thumbnailImageView.layer.cornerRadius = ThemeManager.standardCornerRadius
        // 移除了selectionIndicatorView的样式设置
        selectionOverlayView.layer.cornerRadius = ThemeManager.standardCornerRadius
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        contentView.backgroundColor = ThemeManager.cardBackground
        contentView.layer.cornerRadius = ThemeManager.standardCornerRadius
        contentView.layer.masksToBounds = true
        
        // 添加阴影
        layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 1.0
        layer.masksToBounds = false
        
        // 添加子视图
        // 移除了旧的selectionIndicatorView
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(overlayGradientView)
        contentView.addSubview(playIconView)
        contentView.addSubview(durationLabel)
        contentView.addSubview(statusLabel)
        
        // 添加新的选择UI组件
        contentView.addSubview(selectionOverlayView)
        contentView.addSubview(selectionCheckmarkView)
    }
    
    private func setupConstraints() {
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        playIconView.translatesAutoresizingMaskIntoConstraints = false
        overlayGradientView.translatesAutoresizingMaskIntoConstraints = false
        // 移除了selectionIndicatorView的约束设置
        selectionOverlayView.translatesAutoresizingMaskIntoConstraints = false
        selectionCheckmarkView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 移除了旧的选择指示器约束
            
            // 缩略图
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 渐变覆盖层
            overlayGradientView.leadingAnchor.constraint(equalTo: thumbnailImageView.leadingAnchor),
            overlayGradientView.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor),
            overlayGradientView.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor),
            overlayGradientView.heightAnchor.constraint(equalTo: thumbnailImageView.heightAnchor, multiplier: 0.4),
            
            // 播放图标
            playIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playIconView.widthAnchor.constraint(equalToConstant: 40),
            playIconView.heightAnchor.constraint(equalToConstant: 40),
            
            // 时长标签
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            durationLabel.heightAnchor.constraint(equalToConstant: 20),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            statusLabel.heightAnchor.constraint(equalToConstant: 24),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            
            // 新的选择UI约束
            // 半透明遮罩层 - 覆盖整个cell
            selectionOverlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionOverlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 打勾图标 - 右下角，与时长标签错开
            selectionCheckmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            selectionCheckmarkView.bottomAnchor.constraint(equalTo: durationLabel.topAnchor, constant: -8),
            selectionCheckmarkView.widthAnchor.constraint(equalToConstant: 24),
            selectionCheckmarkView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    // MARK: - Configuration
    func configure(with videoItem: VideoItem) {
        self.videoItem = videoItem
        
        // 设置时长
        durationLabel.text = videoItem.formattedDuration
        
        // 设置状态标签
        configureStatusLabel(for: videoItem)
        
        // 加载缩略图
        loadThumbnail(for: videoItem)
        
        // 配置无障碍支持
        configureAccessibility(for: videoItem)
    }
    
    private func configureAccessibility(for videoItem: VideoItem) {
        // 启用无障碍功能
        isAccessibilityElement = true
        
        // 设置基本描述
        let durationText = videoItem.formattedDuration
        let statusText = videoItem.statusLabel.isEmpty ? "" : "，状态：\(videoItem.statusLabel)"
        accessibilityLabel = "视频，时长\(durationText)\(statusText)"
        
        // 设置操作提示 - 简化实现，避免引用不存在的属性
        accessibilityHint = "双击选择或播放此视频"
        
        // 设置特征
        accessibilityTraits = .button
    }
    
    // 更新选择状态时也要更新无障碍信息
    func updateAccessibilityForSelection(isSelected: Bool) {
        if isSelected {
            accessibilityValue = "已选择"
            accessibilityHint = "双击取消选择此视频"
        } else {
            accessibilityValue = "未选择"
            accessibilityHint = "双击选择此视频"
        }
    }
    
    private func configureStatusLabel(for videoItem: VideoItem) {
        let statusText = videoItem.statusLabel
        
        if !statusText.isEmpty {
            statusLabel.text = statusText
            statusLabel.isHidden = false
            
            // 根据视频来源调整标签内边距
            let padding: CGFloat = statusText.count > 2 ? 8 : 6
            statusLabel.layer.cornerRadius = 12
            
            // 添加内边距
            statusLabel.sizeToFit()
            let size = statusLabel.intrinsicContentSize
            statusLabel.frame.size = CGSize(width: size.width + padding * 2, height: 24)
        } else {
            statusLabel.isHidden = true
        }
    }
    
    // MARK: - Selection
    func setSelected(_ selected: Bool, animated: Bool = true) {
        // 隐藏旧的选择指示器
        // 移除了selectionIndicatorView
        
        if animated {
            if selected {
                // 选中动画：显示遮罩层和打勾
                selectionOverlayView.alpha = 0
                selectionCheckmarkView.alpha = 0
                selectionCheckmarkView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                
                selectionOverlayView.isHidden = false
                selectionCheckmarkView.isHidden = false
                
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.allowUserInteraction], animations: {
                    // 遮罩层淡入
                    self.selectionOverlayView.alpha = 1.0
                    // 打勾图标缩放动画
                    self.selectionCheckmarkView.alpha = 1.0
                    self.selectionCheckmarkView.transform = CGAffineTransform.identity
                    // 轻微的整体缩放
                    self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                }) { _ in
                    // 更新无障碍信息
                    self.updateAccessibilityForSelection(isSelected: true)
                }
            } else {
                // 取消选中动画：隐藏遮罩层和打勾
                UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction], animations: {
                    self.selectionOverlayView.alpha = 0
                    self.selectionCheckmarkView.alpha = 0
                    self.selectionCheckmarkView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                    self.transform = CGAffineTransform.identity
                }, completion: { _ in
                    self.selectionOverlayView.isHidden = true
                    self.selectionCheckmarkView.isHidden = true
                    // 更新无障碍信息
                    self.updateAccessibilityForSelection(isSelected: false)
                })
            }
        } else {
            // 非动画方式直接设置状态
            selectionOverlayView.isHidden = !selected
            selectionCheckmarkView.isHidden = !selected
            selectionOverlayView.alpha = selected ? 1.0 : 0
            selectionCheckmarkView.alpha = selected ? 1.0 : 0
            selectionCheckmarkView.transform = selected ? .identity : CGAffineTransform(scaleX: 0.5, y: 0.5)
            transform = selected ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            // 更新无障碍信息
            updateAccessibilityForSelection(isSelected: selected)
        }
    }
    
    // 定义一个更简单的方法保持向后兼容
    func setSelected(_ selected: Bool) {
        setSelected(selected, animated: true)
    }
    
    private func loadThumbnail(for videoItem: VideoItem) {
        // 取消之前的任务
        thumbnailTask?.cancel()
        
        // 首先检查是否有缓存的缩略图
        if let thumbnailPath = videoItem.thumbnailPath,
           FileManager.default.fileExists(atPath: thumbnailPath.path) {
            thumbnailImageView.image = UIImage(contentsOfFile: thumbnailPath.path)
            return
        }
        
        // 检查文件是否存在，避免尝试为不存在的文件生成缩略图
        guard FileManager.default.fileExists(atPath: videoItem.filePath.path) else {
            print("❌ VideoThumbnailCell: 视频文件不存在: \(videoItem.filePath.path)")
            thumbnailImageView.image = UIImage(systemName: "video.slash")
            thumbnailImageView.tintColor = ThemeManager.secondaryText
            return
        }
        
        // 异步生成缩略图
        thumbnailTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            do {
                let thumbnail = try await self.generateThumbnail(for: videoItem.filePath)
                
                // 确保cell没有被重用
                guard self.videoItem?.id == videoItem.id else { return }
                
                self.thumbnailImageView.image = thumbnail
                
                // 保存缩略图缓存
                self.saveThumbnailCache(thumbnail, for: videoItem)
                
            } catch {
                print("❌ VideoThumbnailCell: 缩略图生成失败: \(error)")
                
                // 确保cell没有被重用
                guard self.videoItem?.id == videoItem.id else { return }
                
                self.thumbnailImageView.image = UIImage(systemName: "video.slash")
                self.thumbnailImageView.tintColor = ThemeManager.secondaryText
            }
        }
    }
    
    private func generateThumbnail(for videoURL: URL) async throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        // 在视频的1/4位置生成缩略图
        let duration = try await asset.load(.duration)
        let time = CMTime(seconds: duration.seconds * 0.25, preferredTimescale: 600)
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let cgImage = cgImage {
                    let image = UIImage(cgImage: cgImage)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ThumbnailError.generationFailed)
                }
            }
        }
    }
    
    private func saveThumbnailCache(_ image: UIImage, for videoItem: VideoItem) {
        guard let imageData = image.jpegData(compressionQuality: 0.95) else { return }
        
        let fileName = "\(videoItem.id.uuidString)_thumbnail.jpg"
        let thumbnailURL = FileManagerHelper.thumbnailsDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: thumbnailURL)
            
            // 更新数据模型
            videoItem.thumbnailPath = thumbnailURL
            PersistenceController.shared.save()
        } catch {
            print("保存缩略图缓存失败: \(error)")
        }
    }
    
    // 这个方法已经被上面的新实现替换，这里保留是为了避免重复
}


// MARK: - EmptyStateView
class EmptyStateView: UIView {
    
    // MARK: - UI Components
    private let iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "video.slash"))
        imageView.tintColor = ThemeManager.secondaryText
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "开始你的创作之旅"
        label.font = ThemeManager.headlineFont
        label.textColor = ThemeManager.primaryText
        label.textAlignment = .center
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "点击正上方 ➕ 按钮添加视频\n在应用内拍摄或从相册导入"
        label.font = ThemeManager.bodyFont
        label.textColor = ThemeManager.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(messageLabel)
    }
    
    private func setupConstraints() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 图标
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            // 消息
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: - Error Types
enum ThumbnailError: LocalizedError {
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "缩略图生成失败"
        }
    }
}
