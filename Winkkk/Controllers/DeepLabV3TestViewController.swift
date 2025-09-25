//
//  DeepLabV3TestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/25.
//  DeepLabV3人物分割测试页面 - 专门测试运动轨迹中的人物分割效果
//

import UIKit
import Photos

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
    
    // 图片选择区域
    private let imageSelectionView = UIView()
    private let selectImageButton = CapsuleButton(title: "📷 选择测试图片", style: .primary, size: .large)
    private let selectedImageView = UIImageView()
    private let imageInfoLabel = UILabel()
    
    // 控制区域
    private let controlView = UIView()
    private let processButton = CapsuleButton(title: "🚀 开始人物分割", style: .secondary, size: .large)
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
        setupImageSelectionView()
        setupControlView()
        setupResultsView()
        setupActionButtons()
        
        // 添加到内容视图
        [titleLabel, subtitleLabel, infoCardView, imageSelectionView, 
         controlView, resultsView, actionButtonsView].forEach {
            contentView.addSubview($0)
        }
        
        // 初始状态
        updateImageSelectionUI()
        updateProcessingUI()
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
    
    private func setupImageSelectionView() {
        imageSelectionView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        imageSelectionView.layer.cornerRadius = 20
        imageSelectionView.layer.borderWidth = 2
        imageSelectionView.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        
        // 选择按钮
        selectImageButton.addTarget(self, action: #selector(selectImageTapped), for: .touchUpInside)
        
        // 图片预览
        selectedImageView.contentMode = .scaleAspectFit
        selectedImageView.clipsToBounds = true
        selectedImageView.layer.cornerRadius = 16
        selectedImageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        selectedImageView.isHidden = true
        
        // 图片信息
        imageInfoLabel.font = .systemFont(ofSize: 14, weight: .medium)
        imageInfoLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        imageInfoLabel.textAlignment = .center
        imageInfoLabel.isHidden = true
        
        [selectImageButton, selectedImageView, imageInfoLabel].forEach {
            imageSelectionView.addSubview($0)
        }
    }
    
    private func setupControlView() {
        controlView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        controlView.layer.cornerRadius = 20
        
        // 处理按钮
        processButton.addTarget(self, action: #selector(processImageTapped), for: .touchUpInside)
        processButton.isEnabled = false
        
        // 状态标签
        statusLabel.text = "请选择一张包含人物的图片"
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .systemGray
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // 进度条
        progressView.progressTintColor = .systemGreen
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progressView.layer.cornerRadius = 2
        progressView.isHidden = true
        
        [processButton, statusLabel, progressView].forEach {
            controlView.addSubview($0)
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
         imageSelectionView, selectImageButton, selectedImageView, imageInfoLabel,
         controlView, processButton, statusLabel, progressView,
         resultsView, resultsHeaderLabel, originalImageView, subjectImageView, maskImageView,
         originalLabel, personLabel, maskLabel, metricsView,
         confidenceLabel, pixelRatioLabel, qualityLabel,
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
        setupImageSelectionConstraints()
        setupControlConstraints()
        setupResultsConstraints()
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
            infoCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            infoCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            infoCardView.heightAnchor.constraint(equalToConstant: 100),
            
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
    
    private func setupImageSelectionConstraints() {
        NSLayoutConstraint.activate([
            // 图片选择区域
            imageSelectionView.topAnchor.constraint(equalTo: infoCardView.bottomAnchor, constant: 24),
            imageSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageSelectionView.heightAnchor.constraint(equalToConstant: 240),
            
            selectImageButton.centerXAnchor.constraint(equalTo: imageSelectionView.centerXAnchor),
            selectImageButton.centerYAnchor.constraint(equalTo: imageSelectionView.centerYAnchor),
            
            selectedImageView.topAnchor.constraint(equalTo: imageSelectionView.topAnchor, constant: 16),
            selectedImageView.leadingAnchor.constraint(equalTo: imageSelectionView.leadingAnchor, constant: 16),
            selectedImageView.trailingAnchor.constraint(equalTo: imageSelectionView.trailingAnchor, constant: -16),
            selectedImageView.heightAnchor.constraint(equalToConstant: 180),
            
            imageInfoLabel.topAnchor.constraint(equalTo: selectedImageView.bottomAnchor, constant: 8),
            imageInfoLabel.leadingAnchor.constraint(equalTo: imageSelectionView.leadingAnchor, constant: 16),
            imageInfoLabel.trailingAnchor.constraint(equalTo: imageSelectionView.trailingAnchor, constant: -16),
            imageInfoLabel.bottomAnchor.constraint(equalTo: imageSelectionView.bottomAnchor, constant: -16),
        ])
    }
    
    private func setupControlConstraints() {
        NSLayoutConstraint.activate([
            // 控制区域
            controlView.topAnchor.constraint(equalTo: imageSelectionView.bottomAnchor, constant: 20),
            controlView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            controlView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            controlView.heightAnchor.constraint(equalToConstant: 140),
            
            processButton.topAnchor.constraint(equalTo: controlView.topAnchor, constant: 20),
            processButton.centerXAnchor.constraint(equalTo: controlView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: processButton.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }
    
    private func setupResultsConstraints() {
        NSLayoutConstraint.activate([
            // 结果区域
            resultsView.topAnchor.constraint(equalTo: controlView.bottomAnchor, constant: 20),
            resultsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultsView.heightAnchor.constraint(equalToConstant: 400),
            
            // 结果标题
            resultsHeaderLabel.topAnchor.constraint(equalTo: resultsView.topAnchor, constant: 20),
            resultsHeaderLabel.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 20),
            resultsHeaderLabel.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -20),
            
            // 图片视图
            originalImageView.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 20),
            originalImageView.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 16),
            originalImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            originalImageView.heightAnchor.constraint(equalToConstant: 140),
            
            subjectImageView.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 20),
            subjectImageView.centerXAnchor.constraint(equalTo: resultsView.centerXAnchor),
            subjectImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            subjectImageView.heightAnchor.constraint(equalToConstant: 140),
            
            maskImageView.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 20),
            maskImageView.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -16),
            maskImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            maskImageView.heightAnchor.constraint(equalToConstant: 140),
            
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
            metricsView.heightAnchor.constraint(equalToConstant: 80),
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
    
    private func setupActionButtonsConstraints() {
        NSLayoutConstraint.activate([
            // 操作按钮
            actionButtonsView.topAnchor.constraint(equalTo: resultsView.bottomAnchor, constant: 20),
            actionButtonsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            actionButtonsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            actionButtonsView.heightAnchor.constraint(equalToConstant: 60),
            actionButtonsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
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
    @objc private func selectImageTapped() {
        let alert = UIAlertController(title: "选择测试图片", message: "建议选择包含清晰人物的图片", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "📱 从相册选择", style: .default) { [weak self] _ in
            self?.presentImagePicker()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = selectImageButton
            popover.sourceRect = selectImageButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func processImageTapped() {
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
        
        selectImageButton.isHidden = hasImage
        selectedImageView.isHidden = !hasImage
        imageInfoLabel.isHidden = !hasImage
        processButton.isEnabled = hasImage && !isProcessing
        
        if let image = selectedImage {
            selectedImageView.image = image
            let size = image.size
            imageInfoLabel.text = "图片尺寸: \(Int(size.width)) × \(Int(size.height))"
        }
    }
    
    private func updateProcessingUI() {
        processButton.isEnabled = !isProcessing && selectedImage != nil
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

// MARK: - Image Picker
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
        if let image = info[.originalImage] as? UIImage {
            selectedImage = image
            segmentationResult = nil // 重置结果
            resultsView.isHidden = true
            actionButtonsView.isHidden = true
        }
        
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
