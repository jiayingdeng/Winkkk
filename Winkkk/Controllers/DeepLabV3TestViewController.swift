//
//  DeepLabV3TestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/25.
//  DeepLabV3人物分割测试页面 - 专门测试运动轨迹中的人物分割效果
//

import UIKit
import Photos
import AVFoundation
import MobileCoreServices
import UniformTypeIdentifiers

class DeepLabV3TestViewController: UIViewController {
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // 功能介绍卡片
    private let infoCardView = UIView()
    private let infoIconView = UIImageView()
    private let infoTitleLabel = UILabel()
    private let infoDescLabel = UILabel()
    
    // 媒体选择区域（支持图片和视频）
    private let mediaSelectionView = UIView()
    private let selectMediaButton = CapsuleButton(title: "📷 选择图片/视频", style: .primary, size: .large)
    private let selectedImageView = UIImageView()
    private let imageInfoLabel = UILabel()
    
    // 视频相关UI
    private let videoInfoLabel = UILabel()
    private let videoThumbnailView = UIImageView()
    
    // 处理模式选择
    private let modeSelectionView = UIView()
    private let singleImageModeButton = CapsuleButton(title: "🖼️ 单图分割", style: .secondary, size: .medium)
    private let timeLapseModeButton = CapsuleButton(title: "⏱️ 时光序列", style: .primary, size: .medium)
    
    // 5帧预览区域
    private let framesPreviewView = UIView()
    private let framesHeaderLabel = UILabel()
    private let frameStackView = UIStackView()
    private var frameImageViews: [UIImageView] = []
    
    // 批量结果展示区域
    private let batchResultsView = UIView()
    private let batchResultsHeaderLabel = UILabel()
    private let batchResultsStackView = UIStackView()
    private var batchResultImageViews: [UIImageView] = []
    
    // 批量处理进度
    private let batchProgressView = UIView()
    private let batchProgressLabel = UILabel()
    private let batchProgressBar = UIProgressView(progressViewStyle: .default)
    
    // 时光序列结果区域
    private let timeLapseResultView = UIView()
    private let timeLapseHeaderLabel = UILabel()
    private let timeLapseImageView = UIImageView()
    private let timeLapseStatsLabel = UILabel()
    
    // 控制区域
    private let controlView = UIView()
    private let processButton = CapsuleButton(title: "🚀 开始人物分割", style: .secondary, size: .large)
    private let timeLapseButton = CapsuleButton(title: "✨ 生成时光序列", style: .primary, size: .large)
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    // 结果展示区域
    private let resultsView = UIView()
    private let resultsHeaderLabel = UILabel()
    
    // 图片结果
    private let originalImageView = UIImageView()
    private let subjectImageView = UIImageView()
    private let maskImageView = UIImageView()
    
    // 结果标签
    private let originalLabel = UILabel()
    private let personLabel = UILabel()
    private let maskLabel = UILabel()
    
    // 指标展示
    private let metricsView = UIView()
    private let confidenceLabel = UILabel()
    private let pixelRatioLabel = UILabel()
    private let qualityLabel = UILabel()
    
    // 操作按钮
    private let actionButtonsView = UIView()
    private let saveResultButton = CapsuleButton(title: "💾 保存结果", style: .secondary, size: .medium)
    private let shareResultButton = CapsuleButton(title: "📤 分享结果", style: .secondary, size: .medium)
    
    // MARK: - Properties
    private var selectedImage: UIImage? {
        didSet {
            updateImageSelectionUI()
        }
    }
    
    private var selectedVideoURL: URL? {
        didSet {
            updateVideoSelectionUI()
        }
    }
    
    private var extractedFrames: [UIImage] = [] {
        didSet {
            updateFramesUI()
            // 立即更新处理模式UI和按钮状态
            updateProcessingModeUI()
        }
    }
    
    private var frameSegmentationResults: [DeepLabSegmentationResult] = [] {
        didSet {
            updateBatchResultsUI()
            // 立即更新处理模式UI和按钮状态
            updateProcessingModeUI()
        }
    }
    
    private var timeLapseResult: UIImage? {
        didSet {
            updateTimeLapseUI()
        }
    }
    
    private var segmentationResult: DeepLabSegmentationResult? {
        didSet {
            displayResults()
        }
    }
    
    private var isProcessing = false {
        didSet {
            updateProcessingUI()
        }
    }
    
    private var processingMode: ProcessingMode = .singleImage {
        didSet {
            updateProcessingModeUI()
        }
    }
    
    enum ProcessingMode {
        case singleImage
        case timeLapse
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureNavigationBar()
        initializeDeepLabV3Manager()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 设置各个组件
        setupHeader()
        setupInfoCard()
        setupMediaSelectionView()
        setupModeSelectionView()
        setupFramesPreviewView()
        setupBatchResultsView()
        setupBatchProgressView()
        setupControlView()
        setupResultsView()
        setupTimeLapseResultView()
        setupActionButtons()
        
        // 添加到内容视图
        [titleLabel, subtitleLabel, infoCardView, mediaSelectionView, modeSelectionView,
         framesPreviewView, batchResultsView, batchProgressView, controlView, resultsView, 
         timeLapseResultView, actionButtonsView].forEach {
            contentView.addSubview($0)
        }
        
        // 初始状态
        updateImageSelectionUI()
        updateProcessingUI()
        updateProcessingModeUI()
        
        // 初始化帧预览组件
        setupFrameImageViews()
    }
    
    private func setupHeader() {
        titleLabel.text = "🎯 DeepLabV3 人物分割"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "专业级人物分割算法 · 运动轨迹场景优化"
        subtitleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
    }
    
    private func setupInfoCard() {
        infoCardView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        infoCardView.layer.cornerRadius = 16
        infoCardView.layer.borderWidth = 1
        infoCardView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        // 图标
        infoIconView.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
        infoIconView.tintColor = .systemBlue
        infoIconView.contentMode = .scaleAspectFit
        
        // 标题
        infoTitleLabel.text = "专注人物分割"
        infoTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        infoTitleLabel.textColor = .white
        
        // 描述
        infoDescLabel.text = "DeepLabV3模型专门针对人物主体进行优化，\n特别适合运动轨迹合成场景的人物提取"
        infoDescLabel.font = .systemFont(ofSize: 14, weight: .medium)
        infoDescLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        infoDescLabel.numberOfLines = 0
        infoDescLabel.textAlignment = .left
        
        [infoIconView, infoTitleLabel, infoDescLabel].forEach {
            infoCardView.addSubview($0)
        }
    }
    
    private func setupMediaSelectionView() {
        mediaSelectionView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        mediaSelectionView.layer.cornerRadius = 20
        mediaSelectionView.layer.borderWidth = 2
        mediaSelectionView.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        
        // 选择按钮
        selectMediaButton.addTarget(self, action: #selector(selectMediaTapped), for: .touchUpInside)
        
        // 图片预览
        selectedImageView.contentMode = .scaleAspectFit
        selectedImageView.clipsToBounds = true
        selectedImageView.layer.cornerRadius = 16
        selectedImageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        selectedImageView.isHidden = true
        
        // 视频缩略图
        videoThumbnailView.contentMode = .scaleAspectFit
        videoThumbnailView.clipsToBounds = true
        videoThumbnailView.layer.cornerRadius = 16
        videoThumbnailView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        videoThumbnailView.isHidden = true
        
        // 媒体信息
        imageInfoLabel.font = .systemFont(ofSize: 14, weight: .medium)
        imageInfoLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        imageInfoLabel.textAlignment = .center
        imageInfoLabel.isHidden = true
        
        videoInfoLabel.font = .systemFont(ofSize: 14, weight: .medium)
        videoInfoLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        videoInfoLabel.textAlignment = .center
        videoInfoLabel.isHidden = true
        
        [selectMediaButton, selectedImageView, videoThumbnailView, 
         imageInfoLabel, videoInfoLabel].forEach {
            mediaSelectionView.addSubview($0)
        }
    }
    
    private func setupControlView() {
        controlView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        controlView.layer.cornerRadius = 20
        
        // 处理按钮
        processButton.addTarget(self, action: #selector(processImageTapped), for: .touchUpInside)
        processButton.isEnabled = false
        
        // 时光序列按钮
        timeLapseButton.addTarget(self, action: #selector(generateTimeLapseTapped), for: .touchUpInside)
        timeLapseButton.isEnabled = false
        timeLapseButton.isHidden = true
        
        // 状态标签
        statusLabel.text = "请选择图片或视频进行测试"
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .systemGray
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // 进度条
        progressView.progressTintColor = .systemGreen
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progressView.layer.cornerRadius = 2
        progressView.isHidden = true
        
        [processButton, timeLapseButton, statusLabel, progressView].forEach {
            controlView.addSubview($0)
        }
    }
    
    private func setupModeSelectionView() {
        modeSelectionView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        modeSelectionView.layer.cornerRadius = 16
        modeSelectionView.isHidden = true // 只有选择视频时才显示
        
        // 模式按钮
        singleImageModeButton.addTarget(self, action: #selector(singleImageModeTapped), for: .touchUpInside)
        timeLapseModeButton.addTarget(self, action: #selector(timeLapseModeTapped), for: .touchUpInside)
        
        [singleImageModeButton, timeLapseModeButton].forEach {
            modeSelectionView.addSubview($0)
        }
    }
    
    private func setupFramesPreviewView() {
        framesPreviewView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        framesPreviewView.layer.cornerRadius = 20
        framesPreviewView.isHidden = true
        
        // 标题
        framesHeaderLabel.text = "📹 提取的5帧关键帧"
        framesHeaderLabel.font = .systemFont(ofSize: 18, weight: .bold)
        framesHeaderLabel.textColor = .white
        framesHeaderLabel.textAlignment = .center
        
        // 帧容器
        frameStackView.axis = .horizontal
        frameStackView.distribution = .fillEqually
        frameStackView.spacing = 8
        frameStackView.alignment = .center
        
        [framesHeaderLabel, frameStackView].forEach {
            framesPreviewView.addSubview($0)
        }
    }
    
    private func setupBatchResultsView() {
        batchResultsView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        batchResultsView.layer.cornerRadius = 20
        batchResultsView.isHidden = true
        
        // 标题
        batchResultsHeaderLabel.text = "🎯 分割结果预览"
        batchResultsHeaderLabel.font = .systemFont(ofSize: 20, weight: .bold)
        batchResultsHeaderLabel.textColor = .white
        batchResultsHeaderLabel.textAlignment = .center
        
        // 结果堆栈视图
        batchResultsStackView.axis = .horizontal
        batchResultsStackView.spacing = 12
        batchResultsStackView.distribution = .fillEqually
        
        // 创建5个结果预览视图
        for i in 0..<5 {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
            imageView.layer.borderWidth = 1
            imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            
            // 添加标签
            let label = UILabel()
            label.text = "帧\(i+1)"
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.8)
            label.textAlignment = .center
            
            let containerView = UIView()
            containerView.addSubview(imageView)
            containerView.addSubview(label)
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                imageView.heightAnchor.constraint(equalToConstant: 80),
                
                label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            batchResultImageViews.append(imageView)
            batchResultsStackView.addArrangedSubview(containerView)
        }
        
        [batchResultsHeaderLabel, batchResultsStackView].forEach {
            batchResultsView.addSubview($0)
        }
    }
    
    private func setupBatchProgressView() {
        batchProgressView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        batchProgressView.layer.cornerRadius = 16
        batchProgressView.isHidden = true
        
        // 进度标签
        batchProgressLabel.text = "正在处理帧 1/5..."
        batchProgressLabel.font = .systemFont(ofSize: 16, weight: .medium)
        batchProgressLabel.textColor = .white
        batchProgressLabel.textAlignment = .center
        
        // 进度条
        batchProgressBar.progressTintColor = .systemBlue
        batchProgressBar.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        batchProgressBar.layer.cornerRadius = 3
        
        [batchProgressLabel, batchProgressBar].forEach {
            batchProgressView.addSubview($0)
        }
    }
    
    private func setupTimeLapseResultView() {
        timeLapseResultView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        timeLapseResultView.layer.cornerRadius = 20
        timeLapseResultView.isHidden = true
        
        // 标题
        timeLapseHeaderLabel.text = "✨ 时光序列合成结果"
        timeLapseHeaderLabel.font = .systemFont(ofSize: 22, weight: .bold)
        timeLapseHeaderLabel.textColor = .white
        timeLapseHeaderLabel.textAlignment = .center
        
        // 结果图片
        timeLapseImageView.contentMode = .scaleAspectFit
        timeLapseImageView.clipsToBounds = true
        timeLapseImageView.layer.cornerRadius = 16
        timeLapseImageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        timeLapseImageView.layer.borderWidth = 1
        timeLapseImageView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        // 统计信息
        timeLapseStatsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        timeLapseStatsLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        timeLapseStatsLabel.textAlignment = .center
        timeLapseStatsLabel.numberOfLines = 0
        
        [timeLapseHeaderLabel, timeLapseImageView, timeLapseStatsLabel].forEach {
            timeLapseResultView.addSubview($0)
        }
    }
    
    private func setupFrameImageViews() {
        // 创建5个帧预览视图
        frameImageViews.removeAll()
        frameStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for i in 0..<5 {
            let containerView = UIView()
            containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            containerView.layer.cornerRadius = 8
            
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 6
            imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
            
            let label = UILabel()
            label.text = "帧\(i+1)"
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.7)
            label.textAlignment = .center
            
            containerView.addSubview(imageView)
            containerView.addSubview(label)
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
                imageView.heightAnchor.constraint(equalToConstant: 60),
                
                label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4)
            ])
            
            frameImageViews.append(imageView)
            frameStackView.addArrangedSubview(containerView)
        }
    }
    
    private func setupResultsView() {
        resultsView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        resultsView.layer.cornerRadius = 20
        resultsView.isHidden = true
        
        // 结果标题
        resultsHeaderLabel.text = "🎉 分割结果"
        resultsHeaderLabel.font = .systemFont(ofSize: 22, weight: .bold)
        resultsHeaderLabel.textColor = .white
        resultsHeaderLabel.textAlignment = .center
        
        // 配置图片视图
        [originalImageView, subjectImageView, maskImageView].forEach { imageView in
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12
            imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
            imageView.layer.borderWidth = 1
            imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        }
        
        // 配置标签
        originalLabel.text = "原图"
        personLabel.text = "人物主体"
        maskLabel.text = "分割遮罩"
        
        [originalLabel, personLabel, maskLabel].forEach { label in
            label.font = .systemFont(ofSize: 16, weight: .semibold)
            label.textColor = .white
            label.textAlignment = .center
        }
        
        // 指标展示
        setupMetricsView()
        
        [resultsHeaderLabel, originalImageView, subjectImageView, maskImageView,
         originalLabel, personLabel, maskLabel, metricsView].forEach {
            resultsView.addSubview($0)
        }
    }
    
    private func setupMetricsView() {
        metricsView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        metricsView.layer.cornerRadius = 12
        
        // 指标标签
        [confidenceLabel, pixelRatioLabel, qualityLabel].forEach { label in
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 2
            metricsView.addSubview(label)
        }
    }
    
    private func setupActionButtons() {
        actionButtonsView.isHidden = true
        
        // 按钮配置
        saveResultButton.addTarget(self, action: #selector(saveResultTapped), for: UIControl.Event.touchUpInside)
        shareResultButton.addTarget(self, action: #selector(shareResultTapped), for: UIControl.Event.touchUpInside)
        
        [saveResultButton, shareResultButton].forEach {
            actionButtonsView.addSubview($0)
        }
    }
    
    private func setupConstraints() {
        // 禁用自动布局
        [gradientBackgroundView, scrollView, contentView, titleLabel, subtitleLabel,
         infoCardView, infoIconView, infoTitleLabel, infoDescLabel,
         mediaSelectionView, selectMediaButton, selectedImageView, videoThumbnailView, 
         imageInfoLabel, videoInfoLabel, modeSelectionView, singleImageModeButton, timeLapseModeButton,
         framesPreviewView, framesHeaderLabel, frameStackView,
         batchResultsView, batchResultsHeaderLabel, batchResultsStackView,
         batchProgressView, batchProgressLabel, batchProgressBar,
         controlView, processButton, timeLapseButton, statusLabel, progressView,
         resultsView, resultsHeaderLabel, originalImageView, subjectImageView, maskImageView,
         originalLabel, personLabel, maskLabel, metricsView,
         confidenceLabel, pixelRatioLabel, qualityLabel,
         timeLapseResultView, timeLapseHeaderLabel, timeLapseImageView, timeLapseStatsLabel,
         actionButtonsView, saveResultButton, shareResultButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // 背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        
        setupHeaderConstraints()
        setupInfoCardConstraints()
        setupMediaSelectionConstraints()
        setupModeSelectionConstraints()
        setupFramesPreviewConstraints()
        setupBatchResultsConstraints()
        setupBatchProgressConstraints()
        setupControlConstraints()
        setupResultsConstraints()
        setupTimeLapseResultConstraints()
        setupActionButtonsConstraints()
    }
    
    private func setupHeaderConstraints() {
        NSLayoutConstraint.activate([
            // Header
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }
    
    private func setupInfoCardConstraints() {
        NSLayoutConstraint.activate([
            // 信息卡片
            infoCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            infoCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            infoCardView.heightAnchor.constraint(equalToConstant: 80),
            
            // 信息卡片内容
            infoIconView.leadingAnchor.constraint(equalTo: infoCardView.leadingAnchor, constant: 20),
            infoIconView.centerYAnchor.constraint(equalTo: infoCardView.centerYAnchor),
            infoIconView.widthAnchor.constraint(equalToConstant: 40),
            infoIconView.heightAnchor.constraint(equalToConstant: 40),
            
            infoTitleLabel.topAnchor.constraint(equalTo: infoCardView.topAnchor, constant: 20),
            infoTitleLabel.leadingAnchor.constraint(equalTo: infoIconView.trailingAnchor, constant: 16),
            infoTitleLabel.trailingAnchor.constraint(equalTo: infoCardView.trailingAnchor, constant: -20),
            
            infoDescLabel.topAnchor.constraint(equalTo: infoTitleLabel.bottomAnchor, constant: 4),
            infoDescLabel.leadingAnchor.constraint(equalTo: infoTitleLabel.leadingAnchor),
            infoDescLabel.trailingAnchor.constraint(equalTo: infoTitleLabel.trailingAnchor),
        ])
    }
    
    private func setupMediaSelectionConstraints() {
        NSLayoutConstraint.activate([
            // 媒体选择区域
            mediaSelectionView.topAnchor.constraint(equalTo: infoCardView.bottomAnchor, constant: 16),
            mediaSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mediaSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mediaSelectionView.heightAnchor.constraint(equalToConstant: 200),
            
            selectMediaButton.centerXAnchor.constraint(equalTo: mediaSelectionView.centerXAnchor),
            selectMediaButton.centerYAnchor.constraint(equalTo: mediaSelectionView.centerYAnchor),
            
            selectedImageView.topAnchor.constraint(equalTo: mediaSelectionView.topAnchor, constant: 16),
            selectedImageView.leadingAnchor.constraint(equalTo: mediaSelectionView.leadingAnchor, constant: 16),
            selectedImageView.trailingAnchor.constraint(equalTo: mediaSelectionView.trailingAnchor, constant: -16),
            selectedImageView.heightAnchor.constraint(equalToConstant: 140),
            
            videoThumbnailView.topAnchor.constraint(equalTo: mediaSelectionView.topAnchor, constant: 16),
            videoThumbnailView.leadingAnchor.constraint(equalTo: mediaSelectionView.leadingAnchor, constant: 16),
            videoThumbnailView.trailingAnchor.constraint(equalTo: mediaSelectionView.trailingAnchor, constant: -16),
            videoThumbnailView.heightAnchor.constraint(equalToConstant: 140),
            
            imageInfoLabel.topAnchor.constraint(equalTo: selectedImageView.bottomAnchor, constant: 8),
            imageInfoLabel.leadingAnchor.constraint(equalTo: mediaSelectionView.leadingAnchor, constant: 16),
            imageInfoLabel.trailingAnchor.constraint(equalTo: mediaSelectionView.trailingAnchor, constant: -16),
            imageInfoLabel.bottomAnchor.constraint(equalTo: mediaSelectionView.bottomAnchor, constant: -16),
            
            videoInfoLabel.topAnchor.constraint(equalTo: videoThumbnailView.bottomAnchor, constant: 8),
            videoInfoLabel.leadingAnchor.constraint(equalTo: mediaSelectionView.leadingAnchor, constant: 16),
            videoInfoLabel.trailingAnchor.constraint(equalTo: mediaSelectionView.trailingAnchor, constant: -16),
            videoInfoLabel.bottomAnchor.constraint(equalTo: mediaSelectionView.bottomAnchor, constant: -16),
        ])
    }
    
    private func setupControlConstraints() {
        NSLayoutConstraint.activate([
            // 控制区域
            controlView.topAnchor.constraint(equalTo: batchProgressView.bottomAnchor, constant: 12),
            controlView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            controlView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            controlView.heightAnchor.constraint(equalToConstant: 140),
            
            processButton.topAnchor.constraint(equalTo: controlView.topAnchor, constant: 20),
            processButton.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            processButton.trailingAnchor.constraint(equalTo: controlView.centerXAnchor, constant: -10),
            
            timeLapseButton.topAnchor.constraint(equalTo: controlView.topAnchor, constant: 20),
            timeLapseButton.leadingAnchor.constraint(equalTo: controlView.centerXAnchor, constant: 10),
            timeLapseButton.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: processButton.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }
    
    private func setupModeSelectionConstraints() {
        NSLayoutConstraint.activate([
            // 模式选择区域
            modeSelectionView.topAnchor.constraint(equalTo: mediaSelectionView.bottomAnchor, constant: 16),
            modeSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            modeSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            modeSelectionView.heightAnchor.constraint(equalToConstant: 60),
            
            singleImageModeButton.leadingAnchor.constraint(equalTo: modeSelectionView.leadingAnchor, constant: 20),
            singleImageModeButton.centerYAnchor.constraint(equalTo: modeSelectionView.centerYAnchor),
            singleImageModeButton.widthAnchor.constraint(equalTo: modeSelectionView.widthAnchor, multiplier: 0.4),
            
            timeLapseModeButton.trailingAnchor.constraint(equalTo: modeSelectionView.trailingAnchor, constant: -20),
            timeLapseModeButton.centerYAnchor.constraint(equalTo: modeSelectionView.centerYAnchor),
            timeLapseModeButton.widthAnchor.constraint(equalTo: modeSelectionView.widthAnchor, multiplier: 0.4),
        ])
    }
    
    private func setupFramesPreviewConstraints() {
        NSLayoutConstraint.activate([
            // 帧预览区域
            framesPreviewView.topAnchor.constraint(equalTo: modeSelectionView.bottomAnchor, constant: 12),
            framesPreviewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            framesPreviewView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            framesPreviewView.heightAnchor.constraint(equalToConstant: 100),
            
            framesHeaderLabel.topAnchor.constraint(equalTo: framesPreviewView.topAnchor, constant: 16),
            framesHeaderLabel.leadingAnchor.constraint(equalTo: framesPreviewView.leadingAnchor, constant: 16),
            framesHeaderLabel.trailingAnchor.constraint(equalTo: framesPreviewView.trailingAnchor, constant: -16),
            
            frameStackView.topAnchor.constraint(equalTo: framesHeaderLabel.bottomAnchor, constant: 12),
            frameStackView.leadingAnchor.constraint(equalTo: framesPreviewView.leadingAnchor, constant: 16),
            frameStackView.trailingAnchor.constraint(equalTo: framesPreviewView.trailingAnchor, constant: -16),
            frameStackView.bottomAnchor.constraint(equalTo: framesPreviewView.bottomAnchor, constant: -16),
        ])
    }
    
    private func setupBatchResultsConstraints() {
        NSLayoutConstraint.activate([
            // 批量结果展示区域
            batchResultsView.topAnchor.constraint(equalTo: framesPreviewView.bottomAnchor, constant: 12),
            batchResultsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            batchResultsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            batchResultsView.heightAnchor.constraint(equalToConstant: 120),
            
            batchResultsHeaderLabel.topAnchor.constraint(equalTo: batchResultsView.topAnchor, constant: 16),
            batchResultsHeaderLabel.leadingAnchor.constraint(equalTo: batchResultsView.leadingAnchor, constant: 16),
            batchResultsHeaderLabel.trailingAnchor.constraint(equalTo: batchResultsView.trailingAnchor, constant: -16),
            
            batchResultsStackView.topAnchor.constraint(equalTo: batchResultsHeaderLabel.bottomAnchor, constant: 12),
            batchResultsStackView.leadingAnchor.constraint(equalTo: batchResultsView.leadingAnchor, constant: 16),
            batchResultsStackView.trailingAnchor.constraint(equalTo: batchResultsView.trailingAnchor, constant: -16),
            batchResultsStackView.bottomAnchor.constraint(lessThanOrEqualTo: batchResultsView.bottomAnchor, constant: -16),
        ])
    }
    
    private func setupBatchProgressConstraints() {
        NSLayoutConstraint.activate([
            // 批量处理进度区域
            batchProgressView.topAnchor.constraint(equalTo: batchResultsView.bottomAnchor, constant: 12),
            batchProgressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            batchProgressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            batchProgressView.heightAnchor.constraint(equalToConstant: 70),
            
            batchProgressLabel.topAnchor.constraint(equalTo: batchProgressView.topAnchor, constant: 16),
            batchProgressLabel.leadingAnchor.constraint(equalTo: batchProgressView.leadingAnchor, constant: 16),
            batchProgressLabel.trailingAnchor.constraint(equalTo: batchProgressView.trailingAnchor, constant: -16),
            
            batchProgressBar.topAnchor.constraint(equalTo: batchProgressLabel.bottomAnchor, constant: 12),
            batchProgressBar.leadingAnchor.constraint(equalTo: batchProgressView.leadingAnchor, constant: 16),
            batchProgressBar.trailingAnchor.constraint(equalTo: batchProgressView.trailingAnchor, constant: -16),
            batchProgressBar.heightAnchor.constraint(equalToConstant: 6),
        ])
    }
    
    private func setupResultsConstraints() {
        NSLayoutConstraint.activate([
            // 结果区域
            resultsView.topAnchor.constraint(equalTo: controlView.bottomAnchor, constant: 12),
            resultsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultsView.heightAnchor.constraint(equalToConstant: 320),
            
            // 结果标题
            resultsHeaderLabel.topAnchor.constraint(equalTo: resultsView.topAnchor, constant: 20),
            resultsHeaderLabel.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 20),
            resultsHeaderLabel.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -20),
            
            // 图片视图
            originalImageView.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 20),
            originalImageView.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 16),
            originalImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            originalImageView.heightAnchor.constraint(equalToConstant: 120),
            
            subjectImageView.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 20),
            subjectImageView.centerXAnchor.constraint(equalTo: resultsView.centerXAnchor),
            subjectImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            subjectImageView.heightAnchor.constraint(equalToConstant: 120),
            
            maskImageView.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 20),
            maskImageView.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -16),
            maskImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            maskImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // 标签
            originalLabel.topAnchor.constraint(equalTo: originalImageView.bottomAnchor, constant: 8),
            originalLabel.centerXAnchor.constraint(equalTo: originalImageView.centerXAnchor),
            
            personLabel.topAnchor.constraint(equalTo: subjectImageView.bottomAnchor, constant: 8),
            personLabel.centerXAnchor.constraint(equalTo: subjectImageView.centerXAnchor),
            
            maskLabel.topAnchor.constraint(equalTo: maskImageView.bottomAnchor, constant: 8),
            maskLabel.centerXAnchor.constraint(equalTo: maskImageView.centerXAnchor),
            
            // 指标展示
            metricsView.topAnchor.constraint(equalTo: originalLabel.bottomAnchor, constant: 16),
            metricsView.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 16),
            metricsView.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -16),
            metricsView.heightAnchor.constraint(equalToConstant: 70),
        ])
        
        // 指标标签约束
        NSLayoutConstraint.activate([
            confidenceLabel.topAnchor.constraint(equalTo: metricsView.topAnchor, constant: 12),
            confidenceLabel.leadingAnchor.constraint(equalTo: metricsView.leadingAnchor, constant: 16),
            confidenceLabel.widthAnchor.constraint(equalTo: metricsView.widthAnchor, multiplier: 0.28),
            
            pixelRatioLabel.topAnchor.constraint(equalTo: metricsView.topAnchor, constant: 12),
            pixelRatioLabel.centerXAnchor.constraint(equalTo: metricsView.centerXAnchor),
            pixelRatioLabel.widthAnchor.constraint(equalTo: metricsView.widthAnchor, multiplier: 0.28),
            
            qualityLabel.topAnchor.constraint(equalTo: metricsView.topAnchor, constant: 12),
            qualityLabel.trailingAnchor.constraint(equalTo: metricsView.trailingAnchor, constant: -16),
            qualityLabel.widthAnchor.constraint(equalTo: metricsView.widthAnchor, multiplier: 0.28),
        ])
    }
    
    private func setupTimeLapseResultConstraints() {
        NSLayoutConstraint.activate([
            // 时光序列结果区域
            timeLapseResultView.topAnchor.constraint(equalTo: resultsView.bottomAnchor, constant: 12),
            timeLapseResultView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            timeLapseResultView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            timeLapseResultView.heightAnchor.constraint(equalToConstant: 260),
            
            timeLapseHeaderLabel.topAnchor.constraint(equalTo: timeLapseResultView.topAnchor, constant: 20),
            timeLapseHeaderLabel.leadingAnchor.constraint(equalTo: timeLapseResultView.leadingAnchor, constant: 20),
            timeLapseHeaderLabel.trailingAnchor.constraint(equalTo: timeLapseResultView.trailingAnchor, constant: -20),
            
            timeLapseImageView.topAnchor.constraint(equalTo: timeLapseHeaderLabel.bottomAnchor, constant: 16),
            timeLapseImageView.leadingAnchor.constraint(equalTo: timeLapseResultView.leadingAnchor, constant: 20),
            timeLapseImageView.trailingAnchor.constraint(equalTo: timeLapseResultView.trailingAnchor, constant: -20),
            timeLapseImageView.heightAnchor.constraint(equalToConstant: 150),
            
            timeLapseStatsLabel.topAnchor.constraint(equalTo: timeLapseImageView.bottomAnchor, constant: 12),
            timeLapseStatsLabel.leadingAnchor.constraint(equalTo: timeLapseResultView.leadingAnchor, constant: 20),
            timeLapseStatsLabel.trailingAnchor.constraint(equalTo: timeLapseResultView.trailingAnchor, constant: -20),
            timeLapseStatsLabel.bottomAnchor.constraint(lessThanOrEqualTo: timeLapseResultView.bottomAnchor, constant: -20),
        ])
    }
    
    private func setupActionButtonsConstraints() {
        NSLayoutConstraint.activate([
            // 操作按钮
            actionButtonsView.topAnchor.constraint(equalTo: timeLapseResultView.bottomAnchor, constant: 12),
            actionButtonsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            actionButtonsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            actionButtonsView.heightAnchor.constraint(equalToConstant: 50),
            actionButtonsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            saveResultButton.leadingAnchor.constraint(equalTo: actionButtonsView.leadingAnchor, constant: 20),
            saveResultButton.centerYAnchor.constraint(equalTo: actionButtonsView.centerYAnchor),
            saveResultButton.widthAnchor.constraint(equalTo: actionButtonsView.widthAnchor, multiplier: 0.4),
            
            shareResultButton.trailingAnchor.constraint(equalTo: actionButtonsView.trailingAnchor, constant: -20),
            shareResultButton.centerYAnchor.constraint(equalTo: actionButtonsView.centerYAnchor),
            shareResultButton.widthAnchor.constraint(equalTo: actionButtonsView.widthAnchor, multiplier: 0.4),
        ])
    }
    
    private func configureNavigationBar() {
        title = "DeepLabV3 测试"
        
        // 返回按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回设置",
            style: .plain,
            target: self,
            action: #selector(backToSettings)
        )
        
        // 设置导航栏样式
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .systemBlue
    }
    
    // MARK: - DeepLabV3 Manager
    private func initializeDeepLabV3Manager() {
        statusLabel.text = "正在初始化DeepLabV3模型..."
        statusLabel.textColor = .systemOrange
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try DeepLabV3Manager.shared.initialize()
                DispatchQueue.main.async {
                    self.statusLabel.text = "✅ DeepLabV3模型已就绪，请选择图片"
                    self.statusLabel.textColor = .systemGreen
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.text = "❌ DeepLabV3模型初始化失败: \(error.localizedDescription)"
                    self.statusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func selectMediaTapped() {
        let alert = UIAlertController(title: "选择媒体文件", message: "可以选择图片进行单个分割，或视频进行时光序列合成", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "📷 从相册选择图片", style: .default) { [weak self] _ in
            self?.presentImagePicker()
        })
        
        alert.addAction(UIAlertAction(title: "🎥 从相册选择视频", style: .default) { [weak self] _ in
            self?.presentVideoPicker()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = selectMediaButton
            popover.sourceRect = selectMediaButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func singleImageModeTapped() {
        processingMode = .singleImage
        updateProcessingModeUI()
    }
    
    @objc private func timeLapseModeTapped() {
        processingMode = .timeLapse
        updateProcessingModeUI()
        
        // 如果有视频，自动提取帧
        if let videoURL = selectedVideoURL {
            extractFramesFromVideo(videoURL)
        }
        
        // 强制更新按钮状态
        DispatchQueue.main.async {
            self.updateButtonStates()
        }
    }
    
    @objc private func generateTimeLapseTapped() {
        guard !frameSegmentationResults.isEmpty else {
            statusLabel.text = "请先对帧进行分割处理"
            statusLabel.textColor = .systemRed
            return
        }
        
        statusLabel.text = "🎆 正在生成时光序列..."
        statusLabel.textColor = .systemBlue
        
        generateTimeLapseComposite()
    }
    
    @objc private func processImageTapped() {
        switch processingMode {
        case .singleImage:
            processSingleImage()
        case .timeLapse:
            processFramesBatch()
        }
    }
    
    private func processSingleImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        segmentationResult = nil
        resultsView.isHidden = true
        actionButtonsView.isHidden = true
        
        statusLabel.text = "🔄 正在进行人物分割..."
        statusLabel.textColor = .systemBlue
        
        // 模拟进度动画
        animateProgress()
        
        DeepLabV3Manager.shared.segmentSubjects(from: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let segmentationResult):
                    self?.segmentationResult = segmentationResult
                    self?.statusLabel.text = "🎉 人物分割完成！"
                    self?.statusLabel.textColor = .systemGreen
                    
                case .failure(let error):
                    self?.statusLabel.text = "❌ 分割失败: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    @objc private func saveResultTapped() {
        guard let result = segmentationResult else { return }
        
        // 保存人物提取结果到相册
        UIImageWriteToSavedPhotosAlbum(result.subjectImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func shareResultTapped() {
        guard let result = segmentationResult else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [result.subjectImage, "DeepLabV3多类别分割结果"],
            applicationActivities: nil
        )
        
        // iPad支持
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareResultButton
            popover.sourceRect = shareResultButton.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func backToSettings() {
        dismiss(animated: true)
    }
    
    // MARK: - UI Updates
    private func updateImageSelectionUI() {
        let hasImage = selectedImage != nil
        let hasVideo = selectedVideoURL != nil
        
        selectMediaButton.isHidden = hasImage || hasVideo
        selectedImageView.isHidden = !hasImage
        videoThumbnailView.isHidden = !hasVideo
        imageInfoLabel.isHidden = !hasImage
        videoInfoLabel.isHidden = !hasVideo
        
        // 更新模式选择区域可见性
        modeSelectionView.isHidden = !hasVideo
        
        // 更新按钮状态
        updateButtonStates()
        
        if let image = selectedImage {
            selectedImageView.image = image
            let size = image.size
            imageInfoLabel.text = "图片尺寸: \(Int(size.width)) × \(Int(size.height))"
        }
    }
    
    private func updateVideoSelectionUI() {
        guard let videoURL = selectedVideoURL else { return }
        
        // 生成视频缩略图
        generateVideoThumbnail(from: videoURL) { [weak self] thumbnail in
            DispatchQueue.main.async {
                self?.videoThumbnailView.image = thumbnail
            }
        }
        
        // 更新视频信息
        getVideoDuration(from: videoURL) { [weak self] duration in
            DispatchQueue.main.async {
                self?.videoInfoLabel.text = "视频时长: \(String(format: "%.1f", duration))秒"
            }
        }
        
        updateImageSelectionUI()
    }
    
    private func updateProcessingModeUI() {
        switch processingMode {
        case .singleImage:
            singleImageModeButton.updateStyle(.primary)
            timeLapseModeButton.updateStyle(.secondary)
            
            framesPreviewView.isHidden = true
            batchProgressView.isHidden = true
            timeLapseButton.isHidden = true
            processButton.isHidden = false
            
        case .timeLapse:
            singleImageModeButton.updateStyle(.secondary)
            timeLapseModeButton.updateStyle(.primary)
            
            framesPreviewView.isHidden = extractedFrames.isEmpty
            batchProgressView.isHidden = true
            timeLapseButton.isHidden = frameSegmentationResults.isEmpty
            processButton.isHidden = extractedFrames.isEmpty
        }
        
        updateButtonStates()
    }
    
    private func updateFramesUI() {
        framesPreviewView.isHidden = extractedFrames.isEmpty || processingMode != .timeLapse
        
        for (index, frame) in extractedFrames.enumerated() {
            if index < frameImageViews.count {
                frameImageViews[index].image = frame
            }
        }
        
        updateButtonStates()
    }
    
    private func updateBatchResultsUI() {
        timeLapseButton.isHidden = frameSegmentationResults.isEmpty
        
        // 显示批量处理结果的预览
        if !frameSegmentationResults.isEmpty {
            // 显示批量结果视图
            batchResultsView.isHidden = false
            
            // 更新批量结果图片显示
            for (index, result) in frameSegmentationResults.enumerated() {
                if index < batchResultImageViews.count {
                    batchResultImageViews[index].image = result.subjectImage
                    batchResultImageViews[index].layer.borderColor = UIColor.systemGreen.cgColor
                    batchResultImageViews[index].layer.borderWidth = 2
                }
                
                // 同时更新帧预览显示分割结果
                if index < frameImageViews.count {
                    frameImageViews[index].image = result.subjectImage
                    frameImageViews[index].layer.borderColor = UIColor.systemGreen.cgColor
                    frameImageViews[index].layer.borderWidth = 2
                }
            }
            
            // 添加处理完成的视觉反馈
            statusLabel.text = "🎉 批量分割完成！成功处理 \(frameSegmentationResults.count) 帧"
            statusLabel.textColor = .systemGreen
        } else {
            batchResultsView.isHidden = true
        }
        
        updateButtonStates()
    }
    
    private func updateTimeLapseUI() {
        timeLapseResultView.isHidden = timeLapseResult == nil
        
        if let result = timeLapseResult {
            timeLapseImageView.image = result
            
            // 计算统计信息
            let avgConfidence = frameSegmentationResults.isEmpty ? 0.0 : 
                frameSegmentationResults.reduce(0.0) { $0 + Double($1.confidence) } / Double(frameSegmentationResults.count)
            let avgSubjectRatio = frameSegmentationResults.isEmpty ? 0.0 : 
                frameSegmentationResults.reduce(0.0) { $0 + Double($1.subjectPixelRatio) } / Double(frameSegmentationResults.count)
            
            let stats = """
            ✨ 时光序列合成完成！
            • 合成帧数: \(frameSegmentationResults.count)
            • 平均置信度: \(String(format: "%.1f%%", avgConfidence * 100))
            • 平均主体占比: \(String(format: "%.1f%%", avgSubjectRatio * 100))
            • 合成效果: 运动轨迹叠加
            """
            
            timeLapseStatsLabel.text = stats
            
            // 显示时光序列结果视图
            DispatchQueue.main.async {
                self.timeLapseResultView.isHidden = false
                
                // 添加完成动画效果
                self.timeLapseResultView.alpha = 0
                UIView.animate(withDuration: 0.8, delay: 0.2, options: [.curveEaseOut]) {
                    self.timeLapseResultView.alpha = 1
                } completion: { _ in
                    // 滚动到结果区域
                    self.scrollToTimeLapseResult()
                }
            }
        }
    }
    
    private func updateButtonStates() {
        let hasMedia = selectedImage != nil || selectedVideoURL != nil
        
        switch processingMode {
        case .singleImage:
            processButton.isEnabled = selectedImage != nil && !isProcessing
            
        case .timeLapse:
            processButton.isEnabled = !extractedFrames.isEmpty && !isProcessing
            timeLapseButton.isEnabled = !frameSegmentationResults.isEmpty && !isProcessing
        }
    }
    
    private func updateProcessingUI() {
        updateButtonStates()
        progressView.isHidden = !isProcessing
        
        if !isProcessing {
            progressView.progress = 0
        }
    }
    
    private func displayResults() {
        guard let result = segmentationResult else {
            resultsView.isHidden = true
            actionButtonsView.isHidden = true
            return
        }
        
        resultsView.isHidden = false
        actionButtonsView.isHidden = false
        
        // 显示图片结果
        originalImageView.image = result.originalImage
        subjectImageView.image = result.subjectImage
        maskImageView.image = result.maskImage
        
        // 显示指标
        let confidencePercent = Int(result.confidence * 100)
        confidenceLabel.text = "置信度\n\(confidencePercent)%"
        confidenceLabel.textColor = result.confidence > 0.6 ? .systemGreen : (result.confidence > 0.3 ? .systemOrange : .systemRed)
        
        let pixelPercent = Int(result.subjectPixelRatio * 100)
        pixelRatioLabel.text = "主体占比\n\(pixelPercent)%"
        pixelRatioLabel.textColor = .systemBlue
        
        let qualityPercent = Int(result.maskQuality * 100)
        qualityLabel.text = "遮罩质量\n\(qualityPercent)%"
        qualityLabel.textColor = result.maskQuality > 0.7 ? .systemGreen : .systemOrange
    }
    
    private func animateProgress() {
        progressView.progress = 0
        UIView.animate(withDuration: 2.5, delay: 0, options: [.curveEaseInOut], animations: {
            self.progressView.progress = 0.95
        })
    }
    
    // MARK: - Image Save Callback
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            let alert = UIAlertController(title: "保存失败", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "保存成功", message: "人物分割结果已保存到相册", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - Media Picker
extension DeepLabV3TestViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private func presentImagePicker() {
        // 检查权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.showImagePicker()
                case .denied, .restricted:
                    self?.showPermissionAlert()
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func showImagePicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "需要相册权限",
            message: "请在设置中允许访问相册以选择测试图片",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // 处理图片选择
        if let image = info[.originalImage] as? UIImage {
            selectedImage = image
            selectedVideoURL = nil // 清除视频
            segmentationResult = nil
            extractedFrames = []
            frameSegmentationResults = []
            timeLapseResult = nil
            
            // 设置为单图模式
            processingMode = .singleImage
            
            // 隐藏相关视图
            resultsView.isHidden = true
            actionButtonsView.isHidden = true
        }
        
        // 处理视频选择
        if let videoURL = info[.mediaURL] as? URL {
            selectedVideoURL = videoURL
            selectedImage = nil // 清除图片
            segmentationResult = nil
            extractedFrames = []
            frameSegmentationResults = []
            timeLapseResult = nil
            
            // 设置为时光序列模式
            processingMode = .timeLapse
            
            // 隐藏相关视图
            resultsView.isHidden = true
            actionButtonsView.isHidden = true
            timeLapseResultView.isHidden = true
            
            // 更新视频UI
            updateVideoSelectionUI()
        }
        
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    // MARK: - Video Picker Methods
    private func presentVideoPicker() {
        // 检查权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.showVideoPicker()
                case .denied, .restricted:
                    self?.showPermissionAlert()
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func showVideoPicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.movie.identifier]
        picker.allowsEditing = false
        present(picker, animated: true)
    }
}

// MARK: - Video Processing
extension DeepLabV3TestViewController {
    
    /// 从视频提取5帧关键帧
    private func extractFramesFromVideo(_ videoURL: URL) {
        statusLabel.text = "📹 正在提取视频关键帧..."
        statusLabel.textColor = .systemBlue
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let frames = try self?.extractVideoFrames(from: videoURL, frameCount: 5) ?? []
                
                DispatchQueue.main.async {
                    self?.extractedFrames = frames
                    self?.statusLabel.text = "✅ 已提取 \(frames.count) 个关键帧"
                    self?.statusLabel.textColor = .systemGreen
                    
                    // 重置相关状态
                    self?.frameSegmentationResults = []
                    self?.timeLapseResult = nil
                    
                    // 强制更新UI状态
                    self?.updateProcessingModeUI()
                    self?.updateButtonStates()
                }
                
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.text = "❌ 视频帧提取失败: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    /// 提取视频帧的核心方法
    private func extractVideoFrames(from videoURL: URL, frameCount: Int) throws -> [UIImage] {
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        guard durationInSeconds > 0 else {
            throw VideoProcessingError.invalidDuration
        }
        
        // 获取视频轨道信息以确定原始分辨率
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }
        
        let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let videoSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        
        // 🎯 关键优化1：保持高分辨率，最大支持到2K以避免内存问题
        let maxDimension: CGFloat = 2048
        if max(videoSize.width, videoSize.height) > maxDimension {
            let scale = maxDimension / max(videoSize.width, videoSize.height)
            generator.maximumSize = CGSize(
                width: videoSize.width * scale,
                height: videoSize.height * scale
            )
        } else {
            // 保持原始分辨率
            generator.maximumSize = videoSize
        }
        
        // 🎯 关键优化2：设置高质量参数
        generator.apertureMode = .cleanAperture
        if #available(iOS 16.0, *) {
            generator.requestedTimeToleranceAfter = .zero
            generator.requestedTimeToleranceBefore = .zero
        }
        
        var frames: [UIImage] = []
        let interval = durationInSeconds / Double(frameCount)
        
        for i in 0..<frameCount {
            let timeInSeconds = Double(i) * interval
            let time = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
            
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                frames.append(uiImage)
            } catch {
                print("提取第\(i+1)帧失败: \(error)")
                // 继续提取其他帧
            }
        }
        
        guard !frames.isEmpty else {
            throw VideoProcessingError.noFramesExtracted
        }
        
        // 🎯 关键优化3：智能帧选择 - 选择清晰度最高的帧
        let selectedFrames = selectHighQualityFrames(from: frames, targetCount: frameCount)
        
        // 🎯 关键优化4：图像预处理增强
        let enhancedFrames = selectedFrames.compactMap { frame in
            return enhanceImageQuality(frame)
        }
        
        return enhancedFrames.isEmpty ? selectedFrames : enhancedFrames
    }
    
    /// 批量处理帧分割
    @objc private func processFramesBatch() {
        guard !extractedFrames.isEmpty else { return }
        
        isProcessing = true
        frameSegmentationResults = []
        
        batchProgressView.isHidden = false
        batchProgressBar.progress = 0
        
        statusLabel.text = "🔄 开始批量分割处理..."
        statusLabel.textColor = .systemBlue
        
        // 使用DeepLabV3Manager的批量处理功能
        DeepLabV3Manager.shared.segmentMultipleFrames(
            extractedFrames,
            progressCallback: { [weak self] current, total in
                let progress = Float(current) / Float(total)
                self?.batchProgressBar.progress = progress
                self?.batchProgressLabel.text = "正在处理帧 \(current+1)/\(total)..."
            },
            frameCompletion: { [weak self] index, result in
                // 单帧完成回调
                print("帧 \(index+1) 处理完成")
            },
            finalCompletion: { [weak self] results in
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.batchProgressView.isHidden = true
                    
                    // 提取成功的结果
                    let successResults = results.compactMap { result -> DeepLabSegmentationResult? in
                        if case .success(let segmentationResult) = result {
                            return segmentationResult
                        }
                        return nil
                    }
                    
                    self?.frameSegmentationResults = successResults
                    
                    if !successResults.isEmpty {
                        // 显示批量统计
                        let stats = DeepLabV3Manager.shared.calculateBatchStatistics(results)
                        print(stats.formattedSummary)
                        
                        // 滚动到帧预览区域显示结果
                        self?.scrollToFramesPreview()
                        
                        // 添加成功的触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                    } else {
                        self?.statusLabel.text = "❌ 批量分割失败"
                        self?.statusLabel.textColor = .systemRed
                        
                        // 添加失败的触觉反馈
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.error)
                    }
                }
            }
        )
    }
    
    /// 生成时光序列合成图
    private func generateTimeLapseComposite() {
        guard !frameSegmentationResults.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let composite = try self?.createTimeLapseComposite(from: self?.frameSegmentationResults ?? [])
                
                DispatchQueue.main.async {
                    self?.timeLapseResult = composite
                    self?.statusLabel.text = "✨ 时光序列合成完成！"
                    self?.statusLabel.textColor = .systemGreen
                    
                    // 添加成功的触觉反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
                
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.text = "❌ 时光序列合成失败: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    /// 创建时光序列合成图的核心算法
    private func createTimeLapseComposite(from results: [DeepLabSegmentationResult]) throws -> UIImage {
        guard !results.isEmpty else {
            throw TimeLapseError.noResults
        }
        
        // 使用第一帧的尺寸作为画布尺寸
        let baseImage = results.first!.originalImage
        let canvasSize = baseImage.size
        let scale = baseImage.scale
        
        // 使用UIGraphicsImageRenderer来避免坐标系翻转问题
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        let compositeImage = renderer.image { context in
            let cgContext = context.cgContext
            
            // 首先绘制背景 - 使用最后一帧的原始图像作为背景
            if let lastFrame = results.last {
                lastFrame.originalImage.draw(in: CGRect(origin: .zero, size: canvasSize))
            }
            
            // 透明度递增：0.15, 0.25, 0.4, 0.6, 0.85
            let alphaValues: [CGFloat] = [0.15, 0.25, 0.4, 0.6, 0.85]
            
            // 按透明度从低到高叠加人物主体（反向绘制：最早帧最透明）
            for (index, result) in results.enumerated().reversed() {
                let alpha = alphaValues[min(index, alphaValues.count - 1)]
                
                // 绘制人物主体图像
                cgContext.saveGState()
                cgContext.setAlpha(alpha)
                
                // 使用UIImage的draw方法，避免坐标系问题
                result.subjectImage.draw(in: CGRect(origin: .zero, size: canvasSize), blendMode: .normal, alpha: alpha)
                
                cgContext.restoreGState()
            }
        }
        
        return compositeImage
    }
    
    // MARK: - UI Scroll Helper Methods
    private func scrollToFramesPreview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let framePreviewY = self.framesPreviewView.frame.origin.y
            let targetY = max(0, framePreviewY - 50) // 留出一些顶部空间
            self.scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
        }
    }
    
    private func scrollToTimeLapseResult() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let timeLapseY = self.timeLapseResultView.frame.origin.y
            let targetY = max(0, timeLapseY - 50) // 留出一些顶部空间
            self.scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
        }
    }

    // MARK: - Video Helper Methods
    private func generateVideoThumbnail(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            if let cgImage = cgImage {
                completion(UIImage(cgImage: cgImage))
            } else {
                completion(nil)
            }
        }
    }
    
    private func getVideoDuration(from url: URL, completion: @escaping (Double) -> Void) {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)
        completion(durationInSeconds)
    }
    
    // MARK: - 🎯 智能帧选择和图像增强
    
    /// 智能选择高质量帧
    private func selectHighQualityFrames(from frames: [UIImage], targetCount: Int) -> [UIImage] {
        guard frames.count > targetCount else { return frames }
        
        // 计算每帧的清晰度分数
        var frameScores: [(frame: UIImage, score: Double)] = []
        
        for frame in frames {
            let sharpnessScore = calculateImageSharpness(frame)
            let contrastScore = calculateImageContrast(frame)
            let brightnessScore = calculateImageBrightness(frame)
            
            // 综合评分：清晰度权重最高
            let totalScore = sharpnessScore * 0.6 + contrastScore * 0.3 + brightnessScore * 0.1
            frameScores.append((frame: frame, score: totalScore))
        }
        
        // 按分数排序，选择最高质量的帧
        frameScores.sort { $0.score > $1.score }
        let selectedFrames = Array(frameScores.prefix(targetCount)).map { $0.frame }
        
        print("📊 帧选择统计: 原始\(frames.count)帧 → 选择\(selectedFrames.count)帧")
        
        return selectedFrames
    }
    
    /// 计算图像清晰度（基于拉普拉斯算子）
    private func calculateImageSharpness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return 0.0 }
        
        var sharpnessSum: Double = 0.0
        let sampleStep = max(1, min(width, height) / 100) // 采样优化
        
        for y in stride(from: sampleStep, to: height - sampleStep, by: sampleStep) {
            for x in stride(from: sampleStep, to: width - sampleStep, by: sampleStep) {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                
                let r = Double(data[pixelIndex])
                let g = Double(data[pixelIndex + 1])
                let b = Double(data[pixelIndex + 2])
                let gray = (r + g + b) / 3.0
                
                // 简化的拉普拉斯算子
                let rightIndex = pixelIndex + bytesPerPixel
                let bottomIndex = ((y + sampleStep) * bytesPerRow) + (x * bytesPerPixel)
                
                if rightIndex < CFDataGetLength(pixelData) && bottomIndex < CFDataGetLength(pixelData) {
                    let rightGray = (Double(data[rightIndex]) + Double(data[rightIndex + 1]) + Double(data[rightIndex + 2])) / 3.0
                    let bottomGray = (Double(data[bottomIndex]) + Double(data[bottomIndex + 1]) + Double(data[bottomIndex + 2])) / 3.0
                    
                    let gradient = abs(rightGray - gray) + abs(bottomGray - gray)
                    sharpnessSum += gradient
                }
            }
        }
        
        return sharpnessSum / Double((width / sampleStep) * (height / sampleStep))
    }
    
    /// 计算图像对比度
    private func calculateImageContrast(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return 0.0 }
        
        var values: [Double] = []
        let sampleStep = max(1, min(width, height) / 50)
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let pixelIndex = (y * width * 4) + (x * 4)
                if pixelIndex + 2 < CFDataGetLength(pixelData) {
                    let r = Double(data[pixelIndex])
                    let g = Double(data[pixelIndex + 1])
                    let b = Double(data[pixelIndex + 2])
                    let gray = (r + g + b) / 3.0
                    values.append(gray)
                }
            }
        }
        
        guard !values.isEmpty else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        
        return sqrt(variance) // 标准差作为对比度指标
    }
    
    /// 计算图像亮度
    private func calculateImageBrightness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return 0.0 }
        
        var brightnessSum: Double = 0.0
        let sampleStep = max(1, min(width, height) / 50)
        var sampleCount = 0
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let pixelIndex = (y * width * 4) + (x * 4)
                if pixelIndex + 2 < CFDataGetLength(pixelData) {
                    let r = Double(data[pixelIndex])
                    let g = Double(data[pixelIndex + 1])
                    let b = Double(data[pixelIndex + 2])
                    let brightness = (r + g + b) / 3.0
                    brightnessSum += brightness
                    sampleCount += 1
                }
            }
        }
        
        let averageBrightness = sampleCount > 0 ? brightnessSum / Double(sampleCount) : 0.0
        
        // 返回接近理想亮度(128)的评分
        return 1.0 - abs(averageBrightness - 128.0) / 128.0
    }
    
    /// 图像质量增强
    private func enhanceImageQuality(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: width * 4,
                                     space: colorSpace,
                                     bitmapInfo: bitmapInfo.rawValue) else { return nil }
        
        // 🎯 关键优化5：设置高质量渲染
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        
        // 绘制原始图像
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let enhancedCGImage = context.makeImage() else { return nil }
        
        // 🎯 关键优化6：应用锐化滤镜
        return applySharpnessFilter(to: UIImage(cgImage: enhancedCGImage))
    }
    
    /// 应用锐化滤镜
    private func applySharpnessFilter(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // 创建锐化滤镜
        guard let sharpnessFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        sharpnessFilter.setValue(ciImage, forKey: kCIInputImageKey)
        sharpnessFilter.setValue(0.4, forKey: kCIInputSharpnessKey) // 适度锐化
        
        // 创建对比度增强滤镜
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return image }
        contrastFilter.setValue(sharpnessFilter.outputImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.1, forKey: kCIInputContrastKey) // 轻微增强对比度
        contrastFilter.setValue(1.0, forKey: kCIInputBrightnessKey)
        contrastFilter.setValue(1.05, forKey: kCIInputSaturationKey) // 轻微增强饱和度
        
        guard let outputImage = contrastFilter.outputImage else { return image }
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let finalCGImage = context.createCGImage(outputImage, from: outputImage.extent) else { return image }
        
        return UIImage(cgImage: finalCGImage)
    }
}

// MARK: - Error Types
enum VideoProcessingError: LocalizedError {
    case invalidDuration
    case noFramesExtracted
    case extractionFailed(Error)
    case noVideoTrack
    
    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "视频时长无效"
        case .noFramesExtracted:
            return "无法提取视频帧"
        case .extractionFailed(let error):
            return "帧提取失败: \(error.localizedDescription)"
        case .noVideoTrack:
            return "视频文件中未找到视频轨道"
        }
    }
}

enum TimeLapseError: LocalizedError {
    case noResults
    case contextCreationFailed
    case compositeCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "没有分割结果可供合成"
        case .contextCreationFailed:
            return "图形上下文创建失败"
        case .compositeCreationFailed:
            return "合成图像创建失败"
        }
    }
}
