//
//  TimeSequenceViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  时间序列模式处理控制器 - 将视频关键时刻融合成艺术图片
//

import UIKit
import AVFoundation

class TimeSequenceViewController: UIViewController {
    
    // MARK: - Properties
    private let screenshots: [ScreenshotItem]
    private let sceneType: SceneType?
    private var selectedVideoURL: URL?
    private var extractedFrames: [UIImage] = []
    
    // 新的时间序列处理器
    private var timeSequenceProcessor: TimeSequenceProcessor?
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 头部区域
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // 视频选择区域
    private let videoSelectionView = UIView()
    private let selectVideoButton = UIButton()
    private let videoPreviewImageView = UIImageView()
    
    // 预览区域
    private let previewContainerView = UIView()
    private let previewTitleLabel = UILabel()
    private let framesStackView = UIStackView()
    
    // 控制区域
    private let controlPanelView = UIView()
    private let frameCountLabel = UILabel()
    private let frameCountSlider = UISlider()
    private let processButton = UIButton()
    private let progressView = UIProgressView()
    private let statusLabel = UILabel()
    
    // 结果区域
    private let resultContainerView = UIView()
    private let resultImageView = UIImageView()
    private let saveButton = UIButton()
    private let shareButton = UIButton()
    
    // MARK: - State
    private var isProcessing = false {
        didSet {
            updateProcessingState()
        }
    }
    
    // MARK: - Initialization
    init(screenshots: [ScreenshotItem]) {
        self.screenshots = screenshots
        self.sceneType = nil
        super.init(nibName: nil, bundle: nil)
    }
    
    /// 新的初始化方法 - 用于时间序列模式
    init(sceneType: SceneType) {
        self.screenshots = []
        self.sceneType = sceneType
        super.init(nibName: nil, bundle: nil)
        
        // 创建专用的时间序列处理器
        self.timeSequenceProcessor = TimeSequenceProcessor(sceneType: sceneType)
        self.timeSequenceProcessor?.delegate = self
    }
    
    /// 从录像界面跳转的初始化方法 - 直接传入视频URL和场景类型
    init(videoURL: URL, sceneType: SceneType) {
        self.screenshots = []
        self.sceneType = sceneType
        self.selectedVideoURL = videoURL
        super.init(nibName: nil, bundle: nil)
        
        // 创建专用的时间序列处理器
        self.timeSequenceProcessor = TimeSequenceProcessor(sceneType: sceneType)
        self.timeSequenceProcessor?.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureNavigationBar()
        
        // 进入时间序列模式的触感反馈
        HapticFeedbackManager.shared.lightImpact()
        
        // 🆕 检测是否从录像界面跳转而来
        if let videoURL = selectedVideoURL {
            // 自动模式：隐藏视频选择UI，直接开始处理
            enterAutoProcessingMode(with: videoURL)
        } else {
            // 手动模式：显示正常的选择界面
            enterManualSelectionMode()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 设置各个区域
        setupHeaderView()
        setupVideoSelectionView()
        setupPreviewArea()
        setupControlPanel()
        setupResultArea()
        
        // 添加到内容视图
        contentView.addSubview(headerView)
        contentView.addSubview(videoSelectionView)
        contentView.addSubview(previewContainerView)
        contentView.addSubview(controlPanelView)
        contentView.addSubview(resultContainerView)
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // 初始设置标题（稍后会根据模式更新）
        updateTitleForCurrentMode()
        
        titleLabel.font = ThemeManager.titleFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.font = ThemeManager.bodyFont
        subtitleLabel.textColor = ThemeManager.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
    }
    
    private func setupVideoSelectionView() {
        videoSelectionView.backgroundColor = ThemeManager.cardBackground
        videoSelectionView.layer.cornerRadius = ThemeManager.largeCornerRadius
        
        // 选择视频按钮
        selectVideoButton.setTitle("📱 选择要处理的视频", for: .normal)
        selectVideoButton.setTitleColor(.white, for: .normal)
        selectVideoButton.backgroundColor = ThemeManager.buttonPrimary
        selectVideoButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        selectVideoButton.titleLabel?.font = ThemeManager.buttonFont
        selectVideoButton.addTarget(self, action: #selector(selectVideoButtonTapped), for: .touchUpInside)
        
        // 视频预览
        videoPreviewImageView.contentMode = .scaleAspectFill
        videoPreviewImageView.layer.cornerRadius = ThemeManager.standardCornerRadius
        videoPreviewImageView.clipsToBounds = true
        videoPreviewImageView.backgroundColor = ThemeManager.cardBackground
        videoPreviewImageView.isHidden = true
        
        videoSelectionView.addSubview(selectVideoButton)
        videoSelectionView.addSubview(videoPreviewImageView)
    }
    
    private func setupPreviewArea() {
        previewContainerView.backgroundColor = ThemeManager.cardBackground
        previewContainerView.layer.cornerRadius = ThemeManager.largeCornerRadius
        previewContainerView.isHidden = true
        
        // 预览标题
        previewTitleLabel.text = "📸 提取的关键帧"
        previewTitleLabel.font = ThemeManager.headlineFont
        previewTitleLabel.textColor = .white
        
        // 帧堆栈视图
        framesStackView.axis = .horizontal
        framesStackView.distribution = .fillEqually
        framesStackView.spacing = 8
        framesStackView.alignment = .center
        
        previewContainerView.addSubview(previewTitleLabel)
        previewContainerView.addSubview(framesStackView)
    }
    
    private func setupControlPanel() {
        controlPanelView.backgroundColor = ThemeManager.cardBackground
        controlPanelView.layer.cornerRadius = ThemeManager.largeCornerRadius
        controlPanelView.isHidden = true
        
        // 帧数量标签
        frameCountLabel.text = "关键帧数量: 5"
        frameCountLabel.font = ThemeManager.bodyFont
        frameCountLabel.textColor = .white
        
        // 帧数量滑块
        frameCountSlider.minimumValue = 3
        frameCountSlider.maximumValue = 8
        frameCountSlider.value = 5
        frameCountSlider.tintColor = ThemeManager.buttonPrimary
        frameCountSlider.addTarget(self, action: #selector(frameCountChanged(_:)), for: .valueChanged)
        
        // 处理按钮
        processButton.setTitle("🎨 生成时间序列图片", for: .normal)
        processButton.setTitleColor(.white, for: .normal)
        processButton.backgroundColor = ThemeManager.success
        processButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        processButton.titleLabel?.font = ThemeManager.buttonFont
        processButton.addTarget(self, action: #selector(processButtonTapped), for: .touchUpInside)
        
        // 进度视图
        progressView.progressTintColor = ThemeManager.buttonPrimary
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.isHidden = true
        
        // 状态标签
        statusLabel.text = "选择视频并调整参数"
        statusLabel.font = ThemeManager.captionFont
        statusLabel.textColor = ThemeManager.secondaryText
        statusLabel.textAlignment = .center
        
        controlPanelView.addSubview(frameCountLabel)
        controlPanelView.addSubview(frameCountSlider)
        controlPanelView.addSubview(processButton)
        controlPanelView.addSubview(progressView)
        controlPanelView.addSubview(statusLabel)
    }
    
    private func setupResultArea() {
        resultContainerView.backgroundColor = ThemeManager.cardBackground
        resultContainerView.layer.cornerRadius = ThemeManager.largeCornerRadius
        resultContainerView.isHidden = true
        
        // 结果图片
        resultImageView.contentMode = .scaleAspectFit
        resultImageView.layer.cornerRadius = ThemeManager.standardCornerRadius
        resultImageView.clipsToBounds = true
        resultImageView.backgroundColor = .black
        
        // 保存按钮
        saveButton.setTitle("💾 保存到相册", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonPrimary
        saveButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        // 分享按钮
        shareButton.setTitle("📤 分享", for: .normal)
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.backgroundColor = ThemeManager.success
        shareButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        
        resultContainerView.addSubview(resultImageView)
        resultContainerView.addSubview(saveButton)
        resultContainerView.addSubview(shareButton)
    }
    
    private func setupConstraints() {
        // 设置所有视图的translatesAutoresizingMaskIntoConstraints
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        videoSelectionView.translatesAutoresizingMaskIntoConstraints = false
        selectVideoButton.translatesAutoresizingMaskIntoConstraints = false
        videoPreviewImageView.translatesAutoresizingMaskIntoConstraints = false
        
        previewContainerView.translatesAutoresizingMaskIntoConstraints = false
        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        framesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        controlPanelView.translatesAutoresizingMaskIntoConstraints = false
        frameCountLabel.translatesAutoresizingMaskIntoConstraints = false
        frameCountSlider.translatesAutoresizingMaskIntoConstraints = false
        processButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        resultContainerView.translatesAutoresizingMaskIntoConstraints = false
        resultImageView.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
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
            
            // 头部区域
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            // 视频选择区域
            videoSelectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            videoSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            videoSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            videoSelectionView.heightAnchor.constraint(equalToConstant: 120),
            
            selectVideoButton.centerXAnchor.constraint(equalTo: videoSelectionView.centerXAnchor),
            selectVideoButton.centerYAnchor.constraint(equalTo: videoSelectionView.centerYAnchor),
            selectVideoButton.widthAnchor.constraint(equalToConstant: 200),
            selectVideoButton.heightAnchor.constraint(equalToConstant: 44),
            
            videoPreviewImageView.topAnchor.constraint(equalTo: videoSelectionView.topAnchor, constant: 16),
            videoPreviewImageView.leadingAnchor.constraint(equalTo: videoSelectionView.leadingAnchor, constant: 16),
            videoPreviewImageView.trailingAnchor.constraint(equalTo: videoSelectionView.trailingAnchor, constant: -16),
            videoPreviewImageView.bottomAnchor.constraint(equalTo: videoSelectionView.bottomAnchor, constant: -16),
            
            // 预览区域
            previewContainerView.topAnchor.constraint(equalTo: videoSelectionView.bottomAnchor, constant: 20),
            previewContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewContainerView.heightAnchor.constraint(equalToConstant: 140),
            
            previewTitleLabel.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 16),
            previewTitleLabel.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 16),
            previewTitleLabel.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -16),
            
            framesStackView.topAnchor.constraint(equalTo: previewTitleLabel.bottomAnchor, constant: 12),
            framesStackView.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 16),
            framesStackView.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -16),
            framesStackView.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -16),
            
            // 控制区域
            controlPanelView.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: 20),
            controlPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            controlPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            controlPanelView.heightAnchor.constraint(equalToConstant: 160),
            
            frameCountLabel.topAnchor.constraint(equalTo: controlPanelView.topAnchor, constant: 16),
            frameCountLabel.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            frameCountLabel.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            
            frameCountSlider.topAnchor.constraint(equalTo: frameCountLabel.bottomAnchor, constant: 8),
            frameCountSlider.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            frameCountSlider.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            
            processButton.topAnchor.constraint(equalTo: frameCountSlider.bottomAnchor, constant: 16),
            processButton.centerXAnchor.constraint(equalTo: controlPanelView.centerXAnchor),
            processButton.widthAnchor.constraint(equalToConstant: 200),
            processButton.heightAnchor.constraint(equalToConstant: 44),
            
            progressView.topAnchor.constraint(equalTo: processButton.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 32),
            progressView.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -32),
            
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: controlPanelView.bottomAnchor, constant: -16),
            
            // 结果区域
            resultContainerView.topAnchor.constraint(equalTo: controlPanelView.bottomAnchor, constant: 20),
            resultContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            resultContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            resultContainerView.heightAnchor.constraint(equalToConstant: 320),
            resultContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            resultImageView.topAnchor.constraint(equalTo: resultContainerView.topAnchor, constant: 16),
            resultImageView.leadingAnchor.constraint(equalTo: resultContainerView.leadingAnchor, constant: 16),
            resultImageView.trailingAnchor.constraint(equalTo: resultContainerView.trailingAnchor, constant: -16),
            resultImageView.heightAnchor.constraint(equalToConstant: 220),
            
            saveButton.topAnchor.constraint(equalTo: resultImageView.bottomAnchor, constant: 16),
            saveButton.leadingAnchor.constraint(equalTo: resultContainerView.leadingAnchor, constant: 16),
            saveButton.widthAnchor.constraint(equalTo: resultContainerView.widthAnchor, multiplier: 0.45),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            
            shareButton.topAnchor.constraint(equalTo: resultImageView.bottomAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: resultContainerView.trailingAnchor, constant: -16),
            shareButton.widthAnchor.constraint(equalTo: resultContainerView.widthAnchor, multiplier: 0.45),
            shareButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func configureNavigationBar() {
        title = "时间序列模式"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回",
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func selectVideoButtonTapped() {
        print("🎬 选择视频")
        HapticFeedbackManager.shared.buttonTap()
        
        let galleryVC = VideoGalleryViewController()
        galleryVC.delegate = self
        let navController = UINavigationController(rootViewController: galleryVC)
        present(navController, animated: true)
    }
    
    @objc private func frameCountChanged(_ sender: UISlider) {
        let count = Int(sender.value)
        frameCountLabel.text = "关键帧数量: \(count)"
        
        // TODO: 更新预览帧
    }
    
    @objc private func processButtonTapped() {
        print("🎨 处理时间序列")
        HapticFeedbackManager.shared.buttonTap()
        
        guard let videoURL = selectedVideoURL else {
            let alert = UIAlertController(
                title: "请选择视频",
                message: "请先选择要处理的视频文件",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        guard let processor = timeSequenceProcessor else {
            let alert = UIAlertController(
                title: "处理器错误",
                message: "时间序列处理器未初始化",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        isProcessing = true
        processor.processVideo(at: videoURL)
    }
    
    @objc private func saveButtonTapped() {
        print("💾 保存结果")
        HapticFeedbackManager.shared.buttonTap()
        
        // TODO: 实现保存功能
        showComingSoonAlert(title: "保存", message: "保存功能开发中")
    }
    
    @objc private func shareButtonTapped() {
        print("📤 分享结果")
        HapticFeedbackManager.shared.buttonTap()
        
        // TODO: 实现分享功能
        showComingSoonAlert(title: "分享", message: "分享功能开发中")
    }
    
    // MARK: - Helper Methods
    private func updateProcessingState() {
        processButton.isEnabled = !isProcessing
        processButton.alpha = isProcessing ? 0.6 : 1.0
        frameCountSlider.isEnabled = !isProcessing
        
        progressView.isHidden = !isProcessing
        
        if isProcessing {
            processButton.setTitle("处理中...", for: .normal)
            statusLabel.text = "正在生成时间序列图片..."
        } else {
            processButton.setTitle("🎨 生成时间序列图片", for: .normal)
            statusLabel.text = "调整参数并点击生成"
        }
    }
    
    private func showComingSoonAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - 🆕 Auto Processing Mode
    
    /// 进入自动处理模式 - 从录像界面跳转而来
    private func enterAutoProcessingMode(with videoURL: URL) {
        print("🎬 进入自动处理模式，视频URL: \(videoURL)")
        
        // 1. 隐藏视频选择区域
        videoSelectionView.isHidden = true
        
        // 2. 显示处理区域
        previewContainerView.isHidden = false
        controlPanelView.isHidden = false
        
        // 3. 更新标题为自动处理模式
        updateTitleForAutoMode()
        
        // 4. 自动开始处理
        automaticallyStartProcessing(videoURL: videoURL)
    }
    
    /// 进入手动选择模式 - 正常进入界面
    private func enterManualSelectionMode() {
        print("📱 进入手动选择模式")
        
        // 1. 显示视频选择界面
        videoSelectionView.isHidden = false
        
        // 2. 隐藏处理区域（等待用户选择）
        previewContainerView.isHidden = true
        controlPanelView.isHidden = true
        
        // 3. 显示选择提示
        updateTitleForManualMode()
    }
    
    /// 自动开始处理视频
    private func automaticallyStartProcessing(videoURL: URL) {
        print("⚡ 自动开始处理视频：\(videoURL)")
        
        guard let processor = timeSequenceProcessor else {
            print("❌ 时间序列处理器未初始化")
            offerRetryOrBackOptions()
            return
        }
        
        // 1. 更新UI状态
        statusLabel.text = "正在分析视频..."
        progressView.isHidden = false
        processButton.isEnabled = false
        processButton.setTitle("自动处理中...", for: .normal)
        
        // 2. 开始处理
        isProcessing = true
        processor.processVideo(at: videoURL)
    }
    
    /// 更新标题为当前模式
    private func updateTitleForCurrentMode() {
        if selectedVideoURL != nil {
            updateTitleForAutoMode()
        } else {
            updateTitleForManualMode()
        }
    }
    
    /// 自动模式标题
    private func updateTitleForAutoMode() {
        if let sceneType = sceneType {
            titleLabel.text = "🎬 正在处理\(sceneType.displayName)"
            subtitleLabel.text = "请稍候，正在提取关键帧并生成时间序列图片..."
        } else {
            titleLabel.text = "🎬 正在处理时间序列"
            subtitleLabel.text = "请稍候，正在提取关键帧并生成时间序列图片..."
        }
    }
    
    /// 手动模式标题
    private func updateTitleForManualMode() {
        if let sceneType = sceneType {
            titleLabel.text = "\(sceneType.icon) \(sceneType.displayName)"
            subtitleLabel.text = sceneType.description
        } else {
            titleLabel.text = "⏰ 时间序列模式"
            subtitleLabel.text = "选择要处理的视频，生成时间序列艺术图片"
        }
    }
    
    /// 处理失败后的重试或返回选项
    private func offerRetryOrBackOptions() {
        let alert = UIAlertController(
            title: "处理失败",
            message: "视频处理遇到问题，您可以选择重试或返回录像界面",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            if let videoURL = self?.selectedVideoURL {
                self?.automaticallyStartProcessing(videoURL: videoURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "返回", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    /// 自动滚动到结果区域
    private func scrollToResultArea() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let resultOrigin = self.resultContainerView.frame.origin
            let offset = CGPoint(x: 0, y: max(0, resultOrigin.y - 100))
            self.scrollView.setContentOffset(offset, animated: true)
        }
    }
    
    /// 显示处理完成提示
    private func showProcessingCompletedAlert(frameCount: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let alert = UIAlertController(
                title: "✅ 时间序列处理完成",
                message: "🎬 成功提取了 \(frameCount) 个关键帧\n🎨 已生成时间序列合成图片\n💾 您可以保存或分享结果",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "查看结果", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    private func updateFramesPreview() {
        // 清除现有帧
        framesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 显示提取的帧
        for (index, frame) in extractedFrames.prefix(5).enumerated() {
            let imageView = UIImageView(image: frame)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.backgroundColor = .systemGray6
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 60),
                imageView.heightAnchor.constraint(equalToConstant: 80)
            ])
            
            framesStackView.addArrangedSubview(imageView)
        }
        
        // 显示预览区域
        previewContainerView.isHidden = extractedFrames.isEmpty
        controlPanelView.isHidden = extractedFrames.isEmpty
    }
}

// MARK: - VideoGalleryViewControllerDelegate
extension TimeSequenceViewController: VideoGalleryViewControllerDelegate {
    
    func videoGalleryViewController(_ controller: VideoGalleryViewController, didSelectVideo videoItem: VideoItem) {
        selectedVideoURL = videoItem.filePath
        
        // 生成视频缩略图
        generateVideoThumbnail(from: videoItem.filePath) { [weak self] thumbnail in
            DispatchQueue.main.async {
                self?.videoPreviewImageView.image = thumbnail
                self?.videoPreviewImageView.isHidden = false
                self?.selectVideoButton.isHidden = true
            }
        }
        
        controller.dismiss(animated: true)
    }
    
    func videoGalleryViewControllerDidCancel(_ controller: VideoGalleryViewController) {
        controller.dismiss(animated: true)
    }
    
    private func generateVideoThumbnail(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            if let cgImage = cgImage {
                let thumbnail = UIImage(cgImage: cgImage)
                completion(thumbnail)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - TimeSequenceProcessorDelegate
extension TimeSequenceViewController: TimeSequenceProcessorDelegate {
    
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didStartProcessing videoURL: URL) {
        DispatchQueue.main.async {
            self.statusLabel.text = "开始处理视频..."
            self.progressView.progress = 0.0
        }
    }
    
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didUpdateProgress progress: Float, currentFrame: Int, totalFrames: Int) {
        DispatchQueue.main.async {
            self.progressView.progress = progress
            self.statusLabel.text = "处理中... (\(currentFrame)/\(totalFrames))"
        }
    }
    
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didCompleteWithFrames frames: [UIImage]) {
        DispatchQueue.main.async {
            self.isProcessing = false
            self.extractedFrames = frames
            self.updateFramesPreview()
            
            // 生成合成图片
            self.generateCompositeImage(from: frames)
            
            // 🆕 自动滚动到结果区域
            self.scrollToResultArea()
            
            // 🆕 显示处理完成提示
            self.showProcessingCompletedAlert(frameCount: frames.count)
            
            HapticFeedbackManager.shared.notificationSuccess()
            self.statusLabel.text = "处理完成！"
        }
    }
    
    func timeSequenceProcessor(_ processor: TimeSequenceProcessor, didFailWithError error: TimeSequenceError) {
        DispatchQueue.main.async {
            self.isProcessing = false
            
            // 🆕 使用增强的错误处理机制
            self.offerRetryOrBackOptions()
            
            HapticFeedbackManager.shared.notificationError()
            self.statusLabel.text = "处理失败：\(error.localizedDescription)"
        }
    }
    
    private func generateCompositeImage(from frames: [UIImage]) {
        // 简单的时间序列合成逻辑 - 将多个帧叠加
        guard !frames.isEmpty else { return }
        
        let firstFrame = frames[0]
        let size = firstFrame.size
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        // 绘制所有帧，使用不同的透明度
        for (index, frame) in frames.enumerated() {
            let alpha = 1.0 / CGFloat(frames.count) * 0.8 + 0.2
            frame.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: alpha)
        }
        
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 显示结果
        resultImageView.image = compositeImage
        resultContainerView.isHidden = false
    }
}
