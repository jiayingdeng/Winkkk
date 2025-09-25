//
//  FrameSegmentationCollectionViewCell.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/25.
//  视频分割结果展示Cell
//

import UIKit

class FrameSegmentationCollectionViewCell: UICollectionViewCell {
    
    // MARK: - UI Components
    private let containerStackView = UIStackView()
    private let headerView = UIView()
    private let frameIndexLabel = UILabel()
    private let timePositionLabel = UILabel()
    private let statusIndicatorView = UIView()
    
    private let imageStackView = UIStackView()
    private let originalImageView = UIImageView()
    private let maskImageView = UIImageView()
    private let subjectImageView = UIImageView()
    
    private let originalLabel = UILabel()
    private let maskLabel = UILabel()
    private let subjectLabel = UILabel()
    
    private let metricsView = UIView()
    private let confidenceLabel = UILabel()
    private let ratioLabel = UILabel()
    private let timeLabel = UILabel()
    private let qualityBadge = UIView()
    private let qualityLabel = UILabel()
    
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Properties
    static let identifier = "FrameSegmentationCollectionViewCell"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        setupContainerView()
        setupHeaderView()
        setupImageViews()
        setupLabels()
        setupMetricsView()
        setupLoadingIndicator()
        setupConstraints()
        setupStyling()
    }
    
    private func setupContainerView() {
        containerStackView.axis = .vertical
        containerStackView.spacing = 8
        containerStackView.alignment = .fill
        containerStackView.distribution = .fill
        
        contentView.addSubview(containerStackView)
        
        // 添加阴影和圆角
        contentView.layer.cornerRadius = 12
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.layer.shadowOpacity = 0.1
        contentView.backgroundColor = .systemBackground
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = UIColor.systemGray6
        headerView.layer.cornerRadius = 8
        
        frameIndexLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        frameIndexLabel.textAlignment = .left
        
        timePositionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timePositionLabel.textColor = .systemGray
        timePositionLabel.textAlignment = .left
        
        statusIndicatorView.layer.cornerRadius = 4
        
        headerView.addSubview(frameIndexLabel)
        headerView.addSubview(timePositionLabel)
        headerView.addSubview(statusIndicatorView)
        
        containerStackView.addArrangedSubview(headerView)
    }
    
    private func setupImageViews() {
        imageStackView.axis = .horizontal
        imageStackView.spacing = 4
        imageStackView.alignment = .fill
        imageStackView.distribution = .fillEqually
        
        // 配置图像视图
        [originalImageView, maskImageView, subjectImageView].forEach { imageView in
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 6
            imageView.backgroundColor = .systemGray5
        }
        
        imageStackView.addArrangedSubview(originalImageView)
        imageStackView.addArrangedSubview(maskImageView)
        imageStackView.addArrangedSubview(subjectImageView)
        
        containerStackView.addArrangedSubview(imageStackView)
    }
    
    private func setupLabels() {
        let labelStackView = UIStackView()
        labelStackView.axis = .horizontal
        labelStackView.spacing = 4
        labelStackView.alignment = .center
        labelStackView.distribution = .fillEqually
        
        [originalLabel, maskLabel, subjectLabel].forEach { label in
            label.font = .systemFont(ofSize: 10, weight: .medium)
            label.textAlignment = .center
            label.textColor = .systemGray
        }
        
        originalLabel.text = "原图"
        maskLabel.text = "遮罩"
        subjectLabel.text = "主体"
        
        labelStackView.addArrangedSubview(originalLabel)
        labelStackView.addArrangedSubview(maskLabel)
        labelStackView.addArrangedSubview(subjectLabel)
        
        containerStackView.addArrangedSubview(labelStackView)
    }
    
    private func setupMetricsView() {
        metricsView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.5)
        metricsView.layer.cornerRadius = 6
        
        confidenceLabel.font = .systemFont(ofSize: 10, weight: .medium)
        ratioLabel.font = .systemFont(ofSize: 10, weight: .medium)
        timeLabel.font = .systemFont(ofSize: 10, weight: .regular)
        
        confidenceLabel.textColor = .label
        ratioLabel.textColor = .label
        timeLabel.textColor = .systemGray
        
        // 质量徽章
        qualityBadge.layer.cornerRadius = 8
        qualityLabel.font = .systemFont(ofSize: 8, weight: .bold)
        qualityLabel.textAlignment = .center
        qualityLabel.textColor = .white
        
        qualityBadge.addSubview(qualityLabel)
        
        [confidenceLabel, ratioLabel, timeLabel, qualityBadge].forEach {
            metricsView.addSubview($0)
        }
        
        containerStackView.addArrangedSubview(metricsView)
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator.hidesWhenStopped = true
        contentView.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        frameIndexLabel.translatesAutoresizingMaskIntoConstraints = false
        timePositionLabel.translatesAutoresizingMaskIntoConstraints = false
        statusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        imageStackView.translatesAutoresizingMaskIntoConstraints = false
        metricsView.translatesAutoresizingMaskIntoConstraints = false
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        ratioLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        qualityBadge.translatesAutoresizingMaskIntoConstraints = false
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 容器视图
            containerStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            containerStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // 头部视图
            headerView.heightAnchor.constraint(equalToConstant: 40),
            
            frameIndexLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            frameIndexLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: -6),
            
            timePositionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            timePositionLabel.topAnchor.constraint(equalTo: frameIndexLabel.bottomAnchor, constant: 2),
            
            statusIndicatorView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            statusIndicatorView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            statusIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            statusIndicatorView.heightAnchor.constraint(equalToConstant: 8),
            
            // 图像视图
            imageStackView.heightAnchor.constraint(equalToConstant: 80),
            
            // 指标视图
            metricsView.heightAnchor.constraint(equalToConstant: 50),
            
            confidenceLabel.leadingAnchor.constraint(equalTo: metricsView.leadingAnchor, constant: 6),
            confidenceLabel.topAnchor.constraint(equalTo: metricsView.topAnchor, constant: 4),
            
            ratioLabel.leadingAnchor.constraint(equalTo: metricsView.leadingAnchor, constant: 6),
            ratioLabel.topAnchor.constraint(equalTo: confidenceLabel.bottomAnchor, constant: 2),
            
            timeLabel.leadingAnchor.constraint(equalTo: metricsView.leadingAnchor, constant: 6),
            timeLabel.topAnchor.constraint(equalTo: ratioLabel.bottomAnchor, constant: 2),
            
            qualityBadge.trailingAnchor.constraint(equalTo: metricsView.trailingAnchor, constant: -6),
            qualityBadge.centerYAnchor.constraint(equalTo: metricsView.centerYAnchor),
            qualityBadge.widthAnchor.constraint(equalToConstant: 32),
            qualityBadge.heightAnchor.constraint(equalToConstant: 16),
            
            qualityLabel.centerXAnchor.constraint(equalTo: qualityBadge.centerXAnchor),
            qualityLabel.centerYAnchor.constraint(equalTo: qualityBadge.centerYAnchor),
            
            // 加载指示器
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    private func setupStyling() {
        // 设置基础样式
        layer.masksToBounds = false
    }
    
    // MARK: - Public Methods
    
    /// 配置Cell数据
    /// - Parameter result: 帧分割结果
    func configure(with result: FrameSegmentationResult) {
        // 设置头部信息
        frameIndexLabel.text = "帧 \(result.frameIndex + 1)"
        timePositionLabel.text = result.formattedTimePosition
        
        // 设置状态指示器
        statusIndicatorView.backgroundColor = result.status.color
        
        switch result.status {
        case .pending:
            showLoadingState()
        case .processing:
            showProcessingState()
        case .completed:
            showCompletedState(result)
        case .failed(let error):
            showFailedState(error)
        }
    }
    
    private func showLoadingState() {
        loadingIndicator.startAnimating()
        hideImageContent()
        hideMetrics()
    }
    
    private func showProcessingState() {
        loadingIndicator.startAnimating()
        hideImageContent()
        hideMetrics()
    }
    
    private func showCompletedState(_ result: FrameSegmentationResult) {
        loadingIndicator.stopAnimating()
        
        // 设置图像
        originalImageView.image = result.originalImage
        maskImageView.image = result.maskImage
        subjectImageView.image = result.subjectImage
        
        // 显示图像内容
        showImageContent()
        
        // 设置指标
        confidenceLabel.text = "置信度: \(Int(result.confidence * 100))%"
        ratioLabel.text = "占比: \(String(format: "%.1f%%", result.subjectPixelRatio * 100))"
        timeLabel.text = "耗时: \(String(format: "%.2fs", result.processingTime))"
        
        // 设置质量徽章
        let quality = result.quality
        qualityLabel.text = quality.displayText
        qualityBadge.backgroundColor = quality.color
        
        showMetrics()
    }
    
    private func showFailedState(_ error: Error) {
        loadingIndicator.stopAnimating()
        hideImageContent()
        hideMetrics()
        
        // 可以显示错误信息
        confidenceLabel.text = "处理失败"
        confidenceLabel.textColor = .systemRed
        metricsView.isHidden = false
    }
    
    private func hideImageContent() {
        [originalImageView, maskImageView, subjectImageView].forEach { imageView in
            imageView.image = nil
            imageView.backgroundColor = .systemGray5
        }
    }
    
    private func showImageContent() {
        [originalImageView, maskImageView, subjectImageView].forEach { imageView in
            imageView.backgroundColor = .clear
        }
    }
    
    private func hideMetrics() {
        metricsView.isHidden = true
    }
    
    private func showMetrics() {
        metricsView.isHidden = false
    }
    
    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // 重置所有内容
        frameIndexLabel.text = nil
        timePositionLabel.text = nil
        statusIndicatorView.backgroundColor = .systemGray
        
        [originalImageView, maskImageView, subjectImageView].forEach { imageView in
            imageView.image = nil
            imageView.backgroundColor = .systemGray5
        }
        
        confidenceLabel.text = nil
        ratioLabel.text = nil
        timeLabel.text = nil
        qualityLabel.text = nil
        
        confidenceLabel.textColor = .label
        loadingIndicator.stopAnimating()
        
        hideMetrics()
    }
}

// MARK: - Animation Extension
extension FrameSegmentationCollectionViewCell {
    
    /// 播放完成动画
    func playCompletionAnimation() {
        // 轻微的缩放动画
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
        
        // 质量徽章动画
        qualityBadge.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.qualityBadge.transform = .identity
        })
    }
}
