//
//  TimeSequenceViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  时间序列模式处理控制器 - 将视频关键时刻融合成艺术图片
//

import UIKit
import AVFoundation
import Photos

/// 时间序列布局类型
enum TimeSequenceLayout {
    case horizontal(spacing: CGFloat)
    case vertical(spacing: CGFloat)
    case grid(columns: Int, horizontalSpacing: CGFloat, verticalSpacing: CGFloat)
    case multiSubjectSharedBackground    // 🌟 新增：多主体共享背景布局
}

/// 📐 多主体布局数据结构
struct MultiSubjectLayout {
    let canvasSize: CGSize          // 画布总尺寸
    let positions: [CGPoint]        // 每个主体的位置
    let subjectSize: CGSize         // 统一的主体尺寸
    let spacing: CGFloat            // 主体间距
    let layoutType: LayoutType      // 布局类型
}

enum LayoutType {
    case horizontal                 // 水平一排
    case vertical                   // 垂直一列
    case grid(rows: Int, cols: Int) // 网格布局
    case circular(center: CGPoint, radius: CGFloat) // 圆形布局
    case custom([CGPoint])          // 自定义位置
}

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
    
    // 用户选择的帧数量
    private var selectedFrameCount: Int = 5
    
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
        framesStackView.distribution = .equalSpacing  // 改为等间距，避免固定宽度冲突
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
        selectedFrameCount = count  // 保存用户选择的帧数
        frameCountLabel.text = "关键帧数量: \(count)"
        
        // 触感反馈
        HapticFeedbackManager.shared.lightImpact()
        
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
        
        guard let sceneType = sceneType else {
            let alert = UIAlertController(
                title: "场景类型错误",
                message: "未设置场景类型",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        // 🆕 使用用户选择的帧数创建自定义参数
        let customParameters = createCustomParameters(for: sceneType, frameCount: selectedFrameCount)
        
        // 重新创建处理器以使用新参数
        timeSequenceProcessor = TimeSequenceProcessor(sceneType: sceneType, parameters: customParameters)
        timeSequenceProcessor?.delegate = self
        
        guard let processor = timeSequenceProcessor else {
            let alert = UIAlertController(
                title: "处理器错误",
                message: "时间序列处理器初始化失败",
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
        
        guard let image = resultImageView.image else {
            showAlert(title: "保存失败", message: "没有可保存的图片")
            return
        }
        
        // 检查相册访问权限
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            saveImageToPhotoLibrary(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.saveImageToPhotoLibrary(image)
                    } else {
                        self?.showAlert(title: "权限被拒绝", message: "请在设置中允许访问相册以保存图片")
                    }
                }
            }
        case .denied, .restricted:
            showAlert(title: "需要相册权限", message: "请在设置 > 隐私与安全性 > 照片中允许访问相册")
        case .limited:
            saveImageToPhotoLibrary(image)
        @unknown default:
            showAlert(title: "权限错误", message: "无法确定相册访问权限")
        }
    }
    
    @objc private func shareButtonTapped() {
        print("📤 分享结果")
        HapticFeedbackManager.shared.buttonTap()
        
        guard let image = resultImageView.image else {
            showAlert(title: "分享失败", message: "没有可分享的图片")
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // 为iPad设置popover
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true)
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
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
    
    /// 保存图片到相册
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    HapticFeedbackManager.shared.notificationSuccess()
                    self?.showAlert(title: "保存成功", message: "时间序列图片已保存到相册")
                } else {
                    HapticFeedbackManager.shared.notificationError()
                    let errorMessage = error?.localizedDescription ?? "未知错误"
                    self?.showAlert(title: "保存失败", message: "保存图片时出错：\(errorMessage)")
                }
            }
        }
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
    
    /// 选择视频后显示控制界面
    private func showControlInterfaceAfterVideoSelection() {
        print("🎛️ 显示控制界面 - 手动选择模式")
        
        // 1. 显示预览区域和控制面板
        previewContainerView.isHidden = false
        controlPanelView.isHidden = false
        
        // 2. 更新标题状态
        if let sceneType = sceneType {
            titleLabel.text = "\(sceneType.icon) \(sceneType.displayName)"
            subtitleLabel.text = "调整参数并点击生成时间序列图片"
        } else {
            titleLabel.text = "⏰ 时间序列模式"
            subtitleLabel.text = "调整参数并点击生成时间序列图片"
        }
        
        // 3. 重置控制状态
        isProcessing = false
        updateProcessingState()
        
        // 4. 滚动到控制面板区域
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.scrollToControlPanel()
        }
    }
    
    /// 滚动到控制面板区域
    private func scrollToControlPanel() {
        let controlPanelFrame = controlPanelView.frame
        let targetRect = CGRect(
            x: 0,
            y: controlPanelFrame.origin.y - 20,
            width: controlPanelFrame.width,
            height: controlPanelFrame.height + 40
        )
        scrollView.scrollRectToVisible(targetRect, animated: true)
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
        
        // 🔧 修复：显示所有提取的帧，而不是固定限制为5帧
        let framesToShow = extractedFrames
        let maxDisplayFrames = min(8, framesToShow.count) // 最多显示8帧，避免界面过挤
        
        // 显示提取的帧
        for (index, frame) in framesToShow.prefix(maxDisplayFrames).enumerated() {
            let imageView = UIImageView(image: frame)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.backgroundColor = .systemGray6
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            // 动态计算宽度，避免约束冲突
            let frameCount = CGFloat(min(maxDisplayFrames, extractedFrames.count))
            let totalSpacing = CGFloat(8 * (Int(frameCount) - 1)) // 间距总和
            let availableWidth = view.frame.width - 64 // 减去左右边距
            let dynamicWidth = max(40, min(80, (availableWidth - totalSpacing) / frameCount)) // 动态宽度，范围40-80
            
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: dynamicWidth),
                imageView.heightAnchor.constraint(equalToConstant: dynamicWidth * 1.33) // 保持4:3比例
            ])
            
            framesStackView.addArrangedSubview(imageView)
        }
        
        // 如果有更多帧未显示，添加提示
        if extractedFrames.count > maxDisplayFrames {
            let moreLabel = UILabel()
            moreLabel.text = "+\(extractedFrames.count - maxDisplayFrames)"
            moreLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            moreLabel.textColor = ThemeManager.secondaryText
            moreLabel.textAlignment = .center
            moreLabel.backgroundColor = UIColor.systemGray5
            moreLabel.layer.cornerRadius = 8
            moreLabel.clipsToBounds = true
            
            moreLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                moreLabel.widthAnchor.constraint(equalToConstant: 40),
                moreLabel.heightAnchor.constraint(equalToConstant: 40 * 1.33)
            ])
            
            framesStackView.addArrangedSubview(moreLabel)
        }
        
        // 显示预览区域
        previewContainerView.isHidden = extractedFrames.isEmpty
        controlPanelView.isHidden = extractedFrames.isEmpty
        
        // 🆕 更新预览标题显示实际帧数
        previewTitleLabel.text = "📸 提取的关键帧 (\(extractedFrames.count)帧)"
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
                
                // 🆕 选择视频后显示控制界面
                self?.showControlInterfaceAfterVideoSelection()
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
            
            // 🆕 处理完成后恢复正常标题状态
            self.updateTitleForManualMode()
            
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
            
            // 🆕 处理失败后也恢复正常标题状态
            self.updateTitleForManualMode()
            
            // 🆕 使用增强的错误处理机制
            self.offerRetryOrBackOptions()
            
            HapticFeedbackManager.shared.notificationError()
            self.statusLabel.text = "处理失败：\(error.localizedDescription)"
        }
    }
    
    private func generateCompositeImage(from frames: [UIImage]) {
        // 🌟 智能场景合成逻辑 - 根据场景类型选择最佳合成策略
        guard !frames.isEmpty else { return }
        
        // 🔍 获取当前场景类型
        guard let currentSceneType = sceneType else {
            print("❌ 场景类型未设置，使用默认叠加合成")
            generateDefaultOverlayComposite(from: frames)
            return
        }
        
        // 🎯 根据场景类型选择合成策略
        switch currentSceneType {
        case .objectChange, .personAction:
            // 📋 策略1：多主体共享背景合成 - 🌟 新功能！
            if frames.count >= 3 {
                generateSharedBackgroundMultiSubjectComposite(from: frames, sceneType: currentSceneType)
            } else {
                // 帧数太少时降级到水平时间轴
                generateHorizontalTimelineComposite(from: frames, sceneType: currentSceneType)
            }
            
        case .sportMotion:
            // 📋 策略2：轨迹叠加合成 - 适合运动轨迹
            generateTrajectoryOverlayComposite(from: frames, sceneType: currentSceneType)
        }
        
        print("✅ 智能场景合成完成！场景类型: \(currentSceneType.displayName)")
    }
    
    /// 📋 策略1：水平时间轴合成 (物体变化 + 人物动作类)
    private func generateHorizontalTimelineComposite(from frames: [UIImage], sceneType: SceneType) {
        guard let firstFrame = frames.first else { return }
        
        // 🎨 画布尺寸：宽度 = 帧宽 × 帧数，高度 = 帧高
        let frameSize = firstFrame.size
        let canvasSize = CGSize(
            width: frameSize.width * CGFloat(frames.count),
            height: frameSize.height
        )
        
        print("📏 水平时间轴画布尺寸: \(canvasSize.width) × \(canvasSize.height)")
        
        // 🖼️ 创建画布
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0.0)
        
        // 🎯 绘制每一帧到不同的水平位置
        for (index, frame) in frames.enumerated() {
            let alpha = calculateAlphaForScene(
                index: index,
                totalFrames: frames.count,
                sceneType: sceneType
            )
            
            // ✨ 关键：每帧绘制在不同的水平位置
            let xOffset = frameSize.width * CGFloat(index)
            let drawRect = CGRect(
                x: xOffset,
                y: 0,
                width: frameSize.width,
                height: frameSize.height
            )
            
            frame.draw(in: drawRect, blendMode: .normal, alpha: alpha)
            
            print("🎨 \(sceneType.icon) 绘制帧 \(index + 1)/\(frames.count)，位置: x=\(Int(xOffset))，透明度: \(String(format: "%.1f", alpha * 100))%")
        }
        
        // 🎉 完成合成
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        resultImageView.image = compositeImage
        resultContainerView.isHidden = false
    }
    
    /// 📋 策略2：轨迹叠加合成 (运动轨迹类)
    private func generateTrajectoryOverlayComposite(from frames: [UIImage], sceneType: SceneType) {
        guard let firstFrame = frames.first else { return }
        
        // 🎨 画布尺寸：保持原始帧尺寸，用于轨迹叠加
        let canvasSize = firstFrame.size
        
        print("📏 轨迹叠加画布尺寸: \(canvasSize.width) × \(canvasSize.height)")
        
        // 🖼️ 创建画布
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0.0)
        
        // 🎯 所有帧叠加在同一位置，创建运动轨迹效果
        for (index, frame) in frames.enumerated() {
            let alpha = calculateAlphaForScene(
                index: index,
                totalFrames: frames.count,
                sceneType: sceneType
            )
            
            // ✨ 关键：所有帧叠加在同一位置，形成轨迹残影
            frame.draw(
                in: CGRect(origin: .zero, size: canvasSize),
                blendMode: .normal,
                alpha: alpha
            )
            
            print("🎨 \(sceneType.icon) 绘制轨迹帧 \(index + 1)/\(frames.count)，透明度: \(String(format: "%.1f", alpha * 100))%")
        }
        
        // 🎉 完成合成
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        resultImageView.image = compositeImage
        resultContainerView.isHidden = false
    }
    
    /// 默认叠加合成 (无场景类型时的备用方案)
    private func generateDefaultOverlayComposite(from frames: [UIImage]) {
        guard let firstFrame = frames.first else { return }
        
        let canvasSize = firstFrame.size
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0.0)
        
        for (index, frame) in frames.enumerated() {
            let alpha = (CGFloat(index + 1) / CGFloat(frames.count)) * 0.6 + 0.1
            frame.draw(
                in: CGRect(origin: .zero, size: canvasSize),
                blendMode: .normal,
                alpha: alpha
            )
        }
        
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        resultImageView.image = compositeImage
        resultContainerView.isHidden = false
    }
    
    // 🗑️ 旧的布局计算函数已移除 - 透明度叠加不需要布局计算
    // 所有帧都绘制在同一位置 (origin: .zero)，只需要计算透明度
    
    // MARK: - 🌟 多主体共享背景合成算法
    
    /// 🌟 新功能：智能背景共享多主体合成
    private func generateSharedBackgroundMultiSubjectComposite(from frames: [UIImage], sceneType: SceneType) {
        guard let firstFrame = frames.first else { return }
        
        print("🎯 开始多主体共享背景合成，帧数: \(frames.count)")
        
        // 📐 1. 分析最佳布局
        let layout = calculateOptimalMultiSubjectLayout(
            frameCount: frames.count,
            frameSize: firstFrame.size
        )
        
        print("📏 布局计算完成: 画布尺寸 \(layout.canvasSize.width)×\(layout.canvasSize.height), 主体尺寸: \(layout.subjectSize.width)×\(layout.subjectSize.height)")
        
        // 🖼️ 2. 创建共享背景画布
        UIGraphicsBeginImageContextWithOptions(layout.canvasSize, false, 0.0)
        
        // 🌄 3. 绘制一次背景（使用第一帧的背景）
        let backgroundFrame = selectBestBackgroundFrame(from: frames)
        backgroundFrame.draw(in: CGRect(origin: .zero, size: layout.canvasSize))
        
        print("🌄 背景绘制完成")
        
        // 🎯 4. 提取并放置每个主体
        for (index, frame) in frames.enumerated() {
            // 🔍 智能提取主体部分
            if let extractedSubject = extractSubjectFromFrame(frame, index: index, totalFrames: frames.count) {
                // 📍 计算放置位置
                let position = layout.positions[index]
                let targetRect = CGRect(
                    origin: position,
                    size: layout.subjectSize
                )
                
                // 🎨 绘制主体到指定位置
                extractedSubject.draw(in: targetRect)
                
                print("✅ 绘制主体 \(index + 1)/\(frames.count) 到位置: (\(Int(position.x)), \(Int(position.y)))")
            } else {
                print("⚠️ 主体 \(index + 1) 提取失败，跳过")
            }
        }
        
        // 🎉 完成合成
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        resultImageView.image = compositeImage
        resultContainerView.isHidden = false
        
        print("🎉 多主体共享背景合成完成！")
    }
    
    /// 📐 计算多主体最佳布局
    private func calculateOptimalMultiSubjectLayout(frameCount: Int, frameSize: CGSize) -> MultiSubjectLayout {
        
        print("🧮 计算布局策略，帧数: \(frameCount)")
        
        // 🧮 智能计算：根据主体数量决定布局
        switch frameCount {
        case 1...3:
            // 水平一排
            return calculateHorizontalLayout(count: frameCount, frameSize: frameSize)
        case 4...6:
            // 2行布局
            return calculateGridLayout(count: frameCount, rows: 2, frameSize: frameSize)
        case 7...9:
            // 3行布局
            return calculateGridLayout(count: frameCount, rows: 3, frameSize: frameSize)
        default:
            // 自动密集布局
            return calculateCompactLayout(count: frameCount, frameSize: frameSize)
        }
    }
    
    /// 🔄 水平布局计算
    private func calculateHorizontalLayout(count: Int, frameSize: CGSize) -> MultiSubjectLayout {
        
        // 📏 计算主体尺寸 (稍微小一点，留出间距)
        let maxSubjectWidth = frameSize.width * 0.5  // 主体占原图50%
        let subjectSize = CGSize(
            width: maxSubjectWidth,
            height: maxSubjectWidth * 1.2  // 稍微高一点
        )
        
        // 📐 计算画布和间距
        let spacing: CGFloat = 30
        let totalWidth = CGFloat(count) * subjectSize.width + CGFloat(count - 1) * spacing
        let canvasSize = CGSize(
            width: max(totalWidth + 60, frameSize.width),  // 至少比总宽度大60点
            height: frameSize.height
        )
        
        // 📍 计算每个主体位置
        var positions: [CGPoint] = []
        let startX = (canvasSize.width - totalWidth) / 2
        let startY = (canvasSize.height - subjectSize.height) / 2
        
        for i in 0..<count {
            let x = startX + CGFloat(i) * (subjectSize.width + spacing)
            positions.append(CGPoint(x: x, y: startY))
        }
        
        return MultiSubjectLayout(
            canvasSize: canvasSize,
            positions: positions,
            subjectSize: subjectSize,
            spacing: spacing,
            layoutType: .horizontal
        )
    }
    
    /// 🔲 网格布局计算
    private func calculateGridLayout(count: Int, rows: Int, frameSize: CGSize) -> MultiSubjectLayout {
        
        let cols = (count + rows - 1) / rows  // 向上取整
        
        // 📏 计算主体尺寸
        let availableWidth = frameSize.width * 0.85
        let availableHeight = frameSize.height * 0.85
        let spacing: CGFloat = 20
        
        let subjectWidth = (availableWidth - CGFloat(cols - 1) * spacing) / CGFloat(cols)
        let subjectHeight = (availableHeight - CGFloat(rows - 1) * spacing) / CGFloat(rows)
        
        let subjectSize = CGSize(
            width: min(subjectWidth, subjectHeight),  // 保持正方形
            height: min(subjectWidth, subjectHeight)
        )
        
        // 📍 计算位置
        var positions: [CGPoint] = []
        let startX = (frameSize.width - (CGFloat(cols) * subjectSize.width + CGFloat(cols - 1) * spacing)) / 2
        let startY = (frameSize.height - (CGFloat(rows) * subjectSize.height + CGFloat(rows - 1) * spacing)) / 2
        
        for i in 0..<count {
            let row = i / cols
            let col = i % cols
            
            let x = startX + CGFloat(col) * (subjectSize.width + spacing)
            let y = startY + CGFloat(row) * (subjectSize.height + spacing)
            
            positions.append(CGPoint(x: x, y: y))
        }
        
        return MultiSubjectLayout(
            canvasSize: frameSize,
            positions: positions,
            subjectSize: subjectSize,
            spacing: spacing,
            layoutType: .grid(rows: rows, cols: cols)
        )
    }
    
    /// 📦 紧凑布局计算 (超过9个主体时使用)
    private func calculateCompactLayout(count: Int, frameSize: CGSize) -> MultiSubjectLayout {
        // 自动计算最佳行列数
        let rows = Int(ceil(sqrt(Double(count))))
        let cols = (count + rows - 1) / rows
        
        return calculateGridLayout(count: count, rows: rows, frameSize: frameSize)
    }
    
    /// 🌄 选择最佳背景帧
    private func selectBestBackgroundFrame(from frames: [UIImage]) -> UIImage {
        
        // 🏆 策略1：选择第一帧（最原始状态的背景）
        if let firstFrame = frames.first {
            return firstFrame
        }
        
        // 🏆 策略2：选择中间帧（平衡状态的背景）
        // let middleIndex = frames.count / 2
        // return frames[middleIndex]
        
        // 这里应该不会到达，但为了安全起见
        return frames[0]
    }
    
    /// 🔍 智能主体提取
    private func extractSubjectFromFrame(_ frame: UIImage, index: Int, totalFrames: Int) -> UIImage? {
        
        // 🎯 策略1：中心区域提取（最可靠的方法）
        let percentage: CGFloat = 0.4  // 提取中心40%区域
        if let centerSubject = extractCenterRegion(from: frame, percentage: percentage) {
            return centerSubject
        }
        
        // 🎯 策略2：如果中心提取失败，直接返回缩放后的原图
        return frame
    }
    
    /// 🎯 中心区域提取
    private func extractCenterRegion(from image: UIImage, percentage: CGFloat) -> UIImage? {
        
        guard let cgImage = image.cgImage else { return nil }
        
        let imageSize = image.size
        let cropSize = CGSize(
            width: imageSize.width * percentage,
            height: imageSize.height * percentage
        )
        
        let cropRect = CGRect(
            x: (imageSize.width - cropSize.width) / 2,
            y: (imageSize.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )
        
        // 🔍 转换坐标系（Core Graphics坐标系是左下角原点）
        let scaleFactor = image.scale
        let pixelCropRect = CGRect(
            x: cropRect.origin.x * scaleFactor,
            y: cropRect.origin.y * scaleFactor,
            width: cropRect.size.width * scaleFactor,
            height: cropRect.size.height * scaleFactor
        )
        
        guard let croppedCGImage = cgImage.cropping(to: pixelCropRect) else { return nil }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - 透明度叠加合成算法
    
    /// 🍞 物体变化场景透明度优化
    private func optimizeForObjectChange(alpha: CGFloat) -> CGFloat {
        // 物体变化：线性递增，突出渐变过程
        // 结合参数：每0.3秒一帧，最多12帧，对比度+20%，饱和度+10%
        return alpha
    }
    
    /// 🧘‍♀️ 人物动作场景透明度优化
    private func optimizeForHumanAction(alpha: CGFloat) -> CGFloat {
        // 人物动作：保持肌肤自然，避免过度透明
        // 结合参数：每0.2秒一帧，最多15帧，加权分布(开始20%，中间60%，结束20%)
        // 色彩处理：对比度+5%，亮度+5%，保持自然肤色
        return max(alpha, 0.3) // 最低30%透明度，确保人物可见性
    }
    
    /// 🏀 运动轨迹场景透明度优化
    private func optimizeForSportsMotion(alpha: CGFloat) -> CGFloat {
        // 运动轨迹：增强对比，突出动作连贯性
        // 结合参数：每0.1秒一帧，最多20帧，密集时间分布提取，锐度增强
        return pow(alpha, 0.6) // 🔥 优化：从0.8改为0.6，显著增强中间帧可见度，突出运动轨迹连贯性
    }
    
    /// 计算场景特定的透明度
    private func calculateAlphaForScene(index: Int, totalFrames: Int, sceneType: SceneType) -> CGFloat {
        // 🔥 修复：调整透明度范围，确保所有帧都能看见
        // 从10%到70%的范围，避免最后一帧100%完全覆盖前面的帧
        let baseAlpha = (CGFloat(index + 1) / CGFloat(totalFrames)) * 0.6 + 0.1
        
        // 根据场景类型应用优化策略
        switch sceneType {
        case .objectChange:
            return optimizeForObjectChange(alpha: baseAlpha)
        case .personAction:
            return optimizeForHumanAction(alpha: baseAlpha)
        case .sportMotion:
            return optimizeForSportsMotion(alpha: baseAlpha)
        }
    }
    
    // MARK: - 参数创建
    
    /// 根据场景类型和用户选择创建自定义参数
    private func createCustomParameters(for sceneType: SceneType, frameCount: Int) -> TimeSequenceParameters {
        let defaultParams = TimeSequenceParameters.defaultParameters(for: sceneType)
        
        // 使用用户选择的帧数覆盖默认值
        return TimeSequenceParameters(
            sceneType: sceneType,
            frameInterval: defaultParams.frameInterval,  // 保持默认间隔
            totalFrames: frameCount,                      // 🆕 使用用户选择的帧数
            processingMode: defaultParams.processingMode  // 保持默认处理模式
        )
    }
}
