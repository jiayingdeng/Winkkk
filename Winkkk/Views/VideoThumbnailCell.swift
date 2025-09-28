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
    
    private let selectionIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeManager.buttonPrimary.withAlphaComponent(0.2)
        view.layer.borderColor = ThemeManager.buttonPrimary.cgColor
        view.layer.borderWidth = 2
        view.isHidden = true
        return view
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
        videoItem = nil
        selectionIndicatorView.isHidden = true
        
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
        selectionIndicatorView.layer.cornerRadius = ThemeManager.standardCornerRadius
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
        contentView.addSubview(selectionIndicatorView)
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(overlayGradientView)
        contentView.addSubview(playIconView)
        contentView.addSubview(durationLabel)
    }
    
    private func setupConstraints() {
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        playIconView.translatesAutoresizingMaskIntoConstraints = false
        overlayGradientView.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 选择指示器
            selectionIndicatorView.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionIndicatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionIndicatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionIndicatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
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
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }
    
    // MARK: - Configuration
    func configure(with videoItem: VideoItem) {
        self.videoItem = videoItem
        
        // 设置时长
        durationLabel.text = videoItem.formattedDuration
        
        // 加载缩略图
        loadThumbnail(for: videoItem)
    }
    
    // MARK: - Selection
    func setSelected(_ selected: Bool) {
        selectionIndicatorView.isHidden = !selected
        
        UIView.animate(withDuration: 0.2) {
            self.contentView.transform = selected ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
        }
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
    
    // MARK: - Selection
    func setSelected(_ selected: Bool, animated: Bool = true) {
        let animations = {
            self.selectionIndicatorView.isHidden = !selected
            self.transform = selected ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: animations)
        } else {
            animations()
        }
    }
}

// MARK: - AddVideoCell
class AddVideoCell: UICollectionViewCell {
    
    static let identifier = "AddVideoCell"
    
    // MARK: - UI Components
    private let iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
        imageView.tintColor = ThemeManager.buttonPrimary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "添加视频"
        label.font = ThemeManager.subheadlineFont
        label.textColor = ThemeManager.primaryText
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private let dashedBorderView = UIView()
    
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.layer.cornerRadius = ThemeManager.standardCornerRadius
        setupDashedBorder()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        contentView.backgroundColor = ThemeManager.cardBackground.withAlphaComponent(0.5)
        
        contentView.addSubview(dashedBorderView)
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
    }
    
    private func setupConstraints() {
        dashedBorderView.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 虚线边框
            dashedBorderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dashedBorderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dashedBorderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dashedBorderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 图标
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -15),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
        ])
    }
    
    private func setupDashedBorder() {
        // 移除旧的虚线边框
        dashedBorderView.layer.sublayers?.removeAll()
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = ThemeManager.buttonPrimary.withAlphaComponent(0.7).cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.lineDashPattern = [8, 4]
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        let path = UIBezierPath(roundedRect: dashedBorderView.bounds, 
                               cornerRadius: ThemeManager.standardCornerRadius)
        shapeLayer.path = path.cgPath
        
        dashedBorderView.layer.addSublayer(shapeLayer)
    }
    
    func configure() {
        // 配置添加按钮外观
        iconView.tintColor = ThemeManager.buttonPrimary
        titleLabel.textColor = ThemeManager.primaryText
    }
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
        label.text = "在应用内拍摄或导入视频\n完成后可导出到系统相册分享"
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
