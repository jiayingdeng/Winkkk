//
//  BatchImageEnhanceViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  批量图像画质修复控制器 - 支持多张图片同时处理
//

import UIKit
import Photos

// MARK: - BatchEnhanceItem
class BatchEnhanceItem {
    let originalImage: UIImage
    var enhancedImage: UIImage?
    var processingState: ProcessingState = .pending
    var progress: Float = 0.0
    var error: ImageEnhancementError?
    
    init(originalImage: UIImage) {
        self.originalImage = originalImage
    }
    
    enum ProcessingState {
        case pending
        case processing
        case completed
        case failed
    }
}

// MARK: - BatchImageEnhanceViewController
class BatchImageEnhanceViewController: UIViewController {
    
    // MARK: - Properties
    private let screenshots: [ScreenshotItem]
    private var enhanceItems: [BatchEnhanceItem] = []
    private var currentLevel: EnhanceLevel = .medium
    private var isProcessing = false
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 头部区域
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    
    // 控制面板
    private let controlPanelView = UIView()
    private let controlPanelBlurView = BlurEffectView(style: .regular, intensity: 0.9)
    private let levelSegmentedControl = UISegmentedControl(items: ["轻度", "中度", "重度"])
    private let startButton = UIButton()
    private let pauseButton = UIButton()
    private let resetButton = UIButton()
    
    // 进度显示
    private let progressContainerView = UIView()
    private let overallProgressView = UIProgressView()
    private let progressLabel = UILabel()
    private let statusLabel = UILabel()
    
    // 网格视图
    private let collectionView: UICollectionView
    private let collectionFlowLayout = UICollectionViewFlowLayout()
    
    // 底部操作按钮
    private let bottomActionView = UIView()
    private let bottomBlurView = BlurEffectView(style: .regular, intensity: 0.9)
    private let saveAllButton = UIButton()
    private let shareAllButton = UIButton()
    private let selectModeButton = UIButton()
    private let createCollageButton = UIButton() // 新增拼图创建按钮
    
    // MARK: - Dependencies
    private let imageEnhancer = ImageEnhancer()
    private var processingQueue = DispatchQueue(label: "batch.enhance.queue", qos: .userInitiated)
    private var processingGroup = DispatchGroup()
    
    // MARK: - State Management
    private var selectedIndices = Set<Int>()
    private var isSelectMode = true  // 默认启用选择模式
    private var completedCount = 0
    private var failedCount = 0
    
    // MARK: - Initialization
    init(screenshots: [ScreenshotItem]) {
        self.screenshots = screenshots
        
        // 配置集合视图布局
        collectionFlowLayout.scrollDirection = .vertical
        collectionFlowLayout.minimumInteritemSpacing = 8
        collectionFlowLayout.minimumLineSpacing = 12
        collectionFlowLayout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionFlowLayout)
        
        super.init(nibName: nil, bundle: nil)
        
        // 初始化处理项目
        enhanceItems = screenshots.compactMap { screenshot in
            guard let image = screenshot.image else { return nil }
            return BatchEnhanceItem(originalImage: image)
        }
        
        // 默认不选择任何图片，让用户手动选择
        selectedIndices = Set<Int>()
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
        updateUI()
        
        // 初始化选择状态UI
        updateSelectionUI()
        
        // 进入批量修复的触感反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        controlPanelView.translatesAutoresizingMaskIntoConstraints = false
        controlPanelBlurView.translatesAutoresizingMaskIntoConstraints = false
        levelSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        progressContainerView.translatesAutoresizingMaskIntoConstraints = false
        overallProgressView.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        bottomActionView.translatesAutoresizingMaskIntoConstraints = false
        bottomBlurView.translatesAutoresizingMaskIntoConstraints = false
        saveAllButton.translatesAutoresizingMaskIntoConstraints = false
        shareAllButton.translatesAutoresizingMaskIntoConstraints = false
        selectModeButton.translatesAutoresizingMaskIntoConstraints = false
        createCollageButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            scrollView.bottomAnchor.constraint(equalTo: bottomActionView.topAnchor),
            
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
            headerView.heightAnchor.constraint(equalToConstant: 80),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 40),
            
            // 数量标签
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            countLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 控制面板
            controlPanelView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            controlPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            controlPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            controlPanelView.heightAnchor.constraint(equalToConstant: 120),
            
            // 控制面板模糊背景
            controlPanelBlurView.topAnchor.constraint(equalTo: controlPanelView.topAnchor),
            controlPanelBlurView.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor),
            controlPanelBlurView.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor),
            controlPanelBlurView.bottomAnchor.constraint(equalTo: controlPanelView.bottomAnchor),
            
            // 修复等级选择
            levelSegmentedControl.topAnchor.constraint(equalTo: controlPanelView.topAnchor, constant: 16),
            levelSegmentedControl.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            levelSegmentedControl.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            levelSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // 开始按钮
            startButton.topAnchor.constraint(equalTo: levelSegmentedControl.bottomAnchor, constant: 16),
            startButton.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            startButton.widthAnchor.constraint(equalToConstant: 180),
            startButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 暂停按钮
            pauseButton.topAnchor.constraint(equalTo: levelSegmentedControl.bottomAnchor, constant: 16),
            pauseButton.leadingAnchor.constraint(equalTo: startButton.trailingAnchor, constant: 12),
            pauseButton.widthAnchor.constraint(equalToConstant: 80),
            pauseButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 重置按钮
            resetButton.topAnchor.constraint(equalTo: levelSegmentedControl.bottomAnchor, constant: 16),
            resetButton.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            resetButton.widthAnchor.constraint(equalToConstant: 80),
            resetButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 进度容器 - 动态高度
            progressContainerView.topAnchor.constraint(equalTo: controlPanelView.bottomAnchor, constant: 16),
            progressContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            progressContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            progressContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // 总体进度条 - 优化间距
            overallProgressView.topAnchor.constraint(equalTo: progressContainerView.topAnchor, constant: 12),
            overallProgressView.leadingAnchor.constraint(equalTo: progressContainerView.leadingAnchor, constant: 16),
            overallProgressView.trailingAnchor.constraint(equalTo: progressContainerView.trailingAnchor, constant: -16),
            overallProgressView.heightAnchor.constraint(equalToConstant: 4),
            
            // 进度标签 - 减小间距
            progressLabel.topAnchor.constraint(equalTo: overallProgressView.bottomAnchor, constant: 6),
            progressLabel.leadingAnchor.constraint(equalTo: progressContainerView.leadingAnchor, constant: 16),
            progressLabel.trailingAnchor.constraint(equalTo: progressContainerView.trailingAnchor, constant: -16),
            progressLabel.heightAnchor.constraint(equalToConstant: 18),
            
            // 状态标签 - 减小间距，并固定底部约束
            statusLabel.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: progressContainerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: progressContainerView.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: progressContainerView.bottomAnchor, constant: -12),
            statusLabel.heightAnchor.constraint(equalToConstant: 18),
            
            // 集合视图
            collectionView.topAnchor.constraint(equalTo: progressContainerView.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            collectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),
            
            // 底部操作区域
            bottomActionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomActionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomActionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomActionView.heightAnchor.constraint(equalToConstant: 80),
            
            // 底部模糊背景
            bottomBlurView.topAnchor.constraint(equalTo: bottomActionView.topAnchor),
            bottomBlurView.leadingAnchor.constraint(equalTo: bottomActionView.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: bottomActionView.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: bottomActionView.bottomAnchor),
            
            // 保存全部按钮
            saveAllButton.leadingAnchor.constraint(equalTo: bottomActionView.leadingAnchor, constant: 16),
            saveAllButton.centerYAnchor.constraint(equalTo: bottomActionView.centerYAnchor),
            saveAllButton.widthAnchor.constraint(equalToConstant: 80),
            saveAllButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 拼图创建按钮
            createCollageButton.leadingAnchor.constraint(equalTo: saveAllButton.trailingAnchor, constant: 8),
            createCollageButton.centerYAnchor.constraint(equalTo: bottomActionView.centerYAnchor),
            createCollageButton.widthAnchor.constraint(equalToConstant: 80),
            createCollageButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 分享全部按钮
            shareAllButton.leadingAnchor.constraint(equalTo: createCollageButton.trailingAnchor, constant: 8),
            shareAllButton.centerYAnchor.constraint(equalTo: bottomActionView.centerYAnchor),
            shareAllButton.widthAnchor.constraint(equalToConstant: 80),
            shareAllButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 选择模式按钮
            selectModeButton.leadingAnchor.constraint(equalTo: shareAllButton.trailingAnchor, constant: 8),
            selectModeButton.trailingAnchor.constraint(equalTo: bottomActionView.trailingAnchor, constant: -16),
            selectModeButton.centerYAnchor.constraint(equalTo: bottomActionView.centerYAnchor),
            selectModeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
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
        
        setupHeaderView()
        setupControlPanel()
        setupProgressView()
        setupCollectionView()
        setupBottomActionView()
        
        // 添加到内容视图
        contentView.addSubview(headerView)
        contentView.addSubview(controlPanelView)
        contentView.addSubview(progressContainerView)
        contentView.addSubview(collectionView)
        view.addSubview(bottomActionView)
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // 标题
        titleLabel.font = ThemeManager.titleFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.text = "批量画质修复"
        headerView.addSubview(titleLabel)
        
        // 数量标签
        countLabel.font = ThemeManager.captionFont
        countLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        countLabel.textAlignment = .center
        countLabel.text = "共 \(enhanceItems.count) 张图片，请选择需要修复的图片"
        headerView.addSubview(countLabel)
    }
    
    private func setupControlPanel() {
        controlPanelView.backgroundColor = .clear
        controlPanelView.layer.cornerRadius = ThemeManager.standardCornerRadius
        controlPanelView.clipsToBounds = true
        
        // 模糊背景
        controlPanelView.addSubview(controlPanelBlurView)
        
        // 修复等级选择
        levelSegmentedControl.selectedSegmentIndex = 1 // 默认中度
        levelSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        levelSegmentedControl.selectedSegmentTintColor = ThemeManager.buttonPrimary
        levelSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        levelSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        levelSegmentedControl.addTarget(self, action: #selector(levelChanged(_:)), for: .valueChanged)
        controlPanelView.addSubview(levelSegmentedControl)
        
        // 开始按钮
        startButton.setTitle("开始修复", for: .normal)
        // 注意：禁用状态的文案在updateStartButtonText()中动态设置
        startButton.backgroundColor = ThemeManager.buttonPrimary
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = ThemeManager.buttonFont
        startButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        controlPanelView.addSubview(startButton)
        
        // 暂停按钮
        pauseButton.setTitle("暂停", for: .normal)
        pauseButton.setTitle("继续", for: .selected)
        pauseButton.backgroundColor = ThemeManager.buttonSecondary
        pauseButton.setTitleColor(.white, for: .normal)
        pauseButton.titleLabel?.font = ThemeManager.buttonFont
        pauseButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        pauseButton.isHidden = true
        controlPanelView.addSubview(pauseButton)
        
        // 重置按钮
        resetButton.setTitle("重置", for: .normal)
        resetButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.titleLabel?.font = ThemeManager.buttonFont
        resetButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        resetButton.isHidden = true
        controlPanelView.addSubview(resetButton)
    }
    
    private func setupProgressView() {
        progressContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        progressContainerView.layer.cornerRadius = ThemeManager.standardCornerRadius
        progressContainerView.isHidden = true
        
        // 总体进度条
        overallProgressView.progressTintColor = ThemeManager.buttonPrimary
        overallProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        overallProgressView.layer.cornerRadius = 2
        overallProgressView.clipsToBounds = true
        progressContainerView.addSubview(overallProgressView)
        
        // 进度标签
        progressLabel.font = ThemeManager.captionFont
        progressLabel.textColor = .white
        progressLabel.textAlignment = .center
        progressLabel.text = "0%"
        progressContainerView.addSubview(progressLabel)
        
        // 状态标签
        statusLabel.font = ThemeManager.captionFont
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        statusLabel.textAlignment = .center
        statusLabel.text = "准备就绪"
        progressContainerView.addSubview(statusLabel)
    }
    
    private func setupCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
        
        // 注册单元格
        collectionView.register(BatchEnhanceCell.self, forCellWithReuseIdentifier: "BatchEnhanceCell")
    }
    
    private func setupBottomActionView() {
        bottomActionView.backgroundColor = .clear
        
        // 模糊背景
        bottomActionView.addSubview(bottomBlurView)
        
        // 保存全部按钮
        saveAllButton.setTitle("保存全部", for: .normal)
        saveAllButton.backgroundColor = ThemeManager.buttonPrimary
        saveAllButton.setTitleColor(.white, for: .normal)
        saveAllButton.titleLabel?.font = ThemeManager.buttonFont
        saveAllButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        saveAllButton.addTarget(self, action: #selector(saveAllButtonTapped), for: .touchUpInside)
        saveAllButton.isEnabled = false
        saveAllButton.alpha = 0.6
        bottomActionView.addSubview(saveAllButton)
        
        // 分享全部按钮
        shareAllButton.setTitle("分享全部", for: .normal)
        shareAllButton.backgroundColor = ThemeManager.buttonSecondary
        shareAllButton.setTitleColor(.white, for: .normal)
        shareAllButton.titleLabel?.font = ThemeManager.buttonFont
        shareAllButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        shareAllButton.addTarget(self, action: #selector(shareAllButtonTapped), for: .touchUpInside)
        shareAllButton.isEnabled = false
        shareAllButton.alpha = 0.6
        bottomActionView.addSubview(shareAllButton)
        
        // 拼图创建按钮
        createCollageButton.setTitle("🧩 拼图", for: .normal)
        createCollageButton.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.8)
        createCollageButton.setTitleColor(.white, for: .normal)
        createCollageButton.titleLabel?.font = ThemeManager.buttonFont
        createCollageButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        createCollageButton.addTarget(self, action: #selector(createCollageButtonTapped), for: .touchUpInside)
        createCollageButton.isEnabled = false
        createCollageButton.alpha = 0.6
        bottomActionView.addSubview(createCollageButton)
        
        // 选择模式按钮（改为全选/反选按钮）
        selectModeButton.setTitle("全选", for: .normal)
        selectModeButton.setTitle("反选", for: .selected)
        selectModeButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        selectModeButton.setTitleColor(.white, for: .normal)
        selectModeButton.titleLabel?.font = ThemeManager.buttonFont
        selectModeButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        selectModeButton.addTarget(self, action: #selector(selectModeButtonTapped), for: .touchUpInside)
        selectModeButton.isEnabled = true  // 默认启用
        selectModeButton.alpha = 1.0
        bottomActionView.addSubview(selectModeButton)
    }
    
    private func configureNavigationBar() {
        title = "批量画质修复"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
}

// MARK: - Actions
extension BatchImageEnhanceViewController {
    
    @objc private func levelChanged(_ sender: UISegmentedControl) {
        currentLevel = EnhanceLevel.allCases[sender.selectedSegmentIndex]
        HapticFeedbackManager.shared.selectionChanged()
    }
    
    @objc private func startButtonTapped() {
        guard !isProcessing else { return }
        
        // 验证是否至少选择了一张图片
        guard selectedIndices.count > 0 else {
            showAlert(title: "无法开始", message: "请至少选择一张图片进行修复")
            HapticFeedbackManager.shared.notificationWarning()
            return
        }
        
        HapticFeedbackManager.shared.buttonTap()
        startBatchProcessing()
    }
    
    @objc private func pauseButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        pauseButton.isSelected.toggle()
        // TODO: 实现暂停/继续逻辑
    }
    
    @objc private func resetButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        showResetConfirmation()
    }
    
    @objc private func saveAllButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        saveCompletedImages()
    }
    
    @objc private func shareAllButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        shareCompletedImages()
    }
    
    @objc private func createCollageButtonTapped() {
        // 获取所有修复完成的图片
        let completedImages = enhanceItems.compactMap { item in
            return item.processingState == .completed ? item.enhancedImage : nil
        }
        
        guard completedImages.count > 1 else {
            showAlert(title: "无法创建拼图", message: "至少需要2张修复完成的图片才能创建拼图")
            HapticFeedbackManager.shared.notificationWarning()
            return
        }
        
        HapticFeedbackManager.shared.buttonTap()
        
        // 跳转到拼图创建页面
        let collageVC = CollageViewController(images: completedImages)
        navigationController?.pushViewController(collageVC, animated: true)
    }
    
    @objc private func selectModeButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        toggleSelectAll()
    }
    
    private func toggleSelectAll() {
        let allSelected = selectedIndices.count == enhanceItems.count
        
        if allSelected {
            // 当前全选，执行反选（清空选择）
            selectedIndices.removeAll()
        } else {
            // 当前非全选，执行全选
            selectedIndices = Set(0..<enhanceItems.count)
        }
        
        updateSelectionUI()
        HapticFeedbackManager.shared.selectionChanged()
    }
    
    @objc private func cancelButtonTapped() {
        // 🚀 优化：立即触感反馈提升响应感
        HapticFeedbackManager.shared.buttonTap()
        
        if isProcessing {
            showCancelConfirmation()
        } else {
            // 🚀 优化：立即开始返回动画，提升响应感
            navigationController?.popViewController(animated: true)
            
            // 🚀 优化：异步清理资源，避免阻塞UI
            DispatchQueue.global(qos: .utility).async {
                // 清理大图片资源，释放内存
                self.cleanupImageResources()
            }
        }
    }
    
    /// 🚀 新增：清理图片资源，优化内存使用
    private func cleanupImageResources() {
        // 清理增强后的大图片，避免内存泄漏
        for item in enhanceItems {
            item.enhancedImage = nil
        }
        print("✅ 批量修复页面：图片资源已清理")
    }
}

// MARK: - Batch Processing Logic
extension BatchImageEnhanceViewController {
    
    private func startBatchProcessing() {
        isProcessing = true
        completedCount = 0
        failedCount = 0
        
        updateProcessingState()
        
        // 显示进度视图
        progressContainerView.isHidden = false
        
        // 只重置选中项目的状态
        for (index, item) in enhanceItems.enumerated() {
            if selectedIndices.contains(index) {
                item.processingState = .pending
                item.progress = 0.0
                item.error = nil
                item.enhancedImage = nil
            }
        }
        
        collectionView.reloadData()
        
        // 开始处理
        processBatchItems()
    }
    
    private func processBatchItems() {
        // 只处理选中的图片
        let itemsToProcess = enhanceItems.enumerated().filter { index, item in
            selectedIndices.contains(index) && item.processingState == .pending
        }
        
        guard !itemsToProcess.isEmpty else {
            finishBatchProcessing()
            return
        }
        
        let selectedCount = selectedIndices.count
        statusLabel.text = "正在处理\(selectedCount)张选中图片..."
        
        // 逐个处理图片（避免内存过载）
        for (index, item) in itemsToProcess {
            processingGroup.enter()
            
            item.processingState = .processing
            
            DispatchQueue.main.async {
                self.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
            
            imageEnhancer.enhanceImage(item.originalImage, level: currentLevel) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let enhancedImage):
                        item.enhancedImage = enhancedImage
                        item.processingState = .completed
                        item.progress = 1.0
                        self.completedCount += 1
                        
                    case .failure(let error):
                        item.error = error
                        item.processingState = .failed
                        item.progress = 0.0
                        self.failedCount += 1
                    }
                    
                    self.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
                    self.updateOverallProgress()
                    
                    self.processingGroup.leave()
                }
            }
        }
        
        // 等待所有处理完成
        processingGroup.notify(queue: .main) {
            self.finishBatchProcessing()
        }
    }
    
    private func finishBatchProcessing() {
        isProcessing = false
        updateProcessingState()
        
        // 更新UI状态
        let successCount = completedCount
        let totalCount = enhanceItems.count
        
        if successCount == totalCount {
            statusLabel.text = "全部处理完成！"
            HapticFeedbackManager.shared.notificationSuccess()
        } else if successCount > 0 {
            statusLabel.text = "处理完成：成功 \(successCount)，失败 \(failedCount)"
            HapticFeedbackManager.shared.notificationWarning()
        } else {
            statusLabel.text = "处理失败，请检查图片格式"
            HapticFeedbackManager.shared.notificationError()
        }
        
        // 启用底部按钮
        if successCount > 0 {
            saveAllButton.isEnabled = true
            saveAllButton.alpha = 1.0
            shareAllButton.isEnabled = true
            shareAllButton.alpha = 1.0
        }
        
        // 检查是否可以创建拼图（至少需要2张修复完成的图片）
        if successCount > 1 {
            createCollageButton.isEnabled = true
            createCollageButton.alpha = 1.0
        }
        
        // 更新保存分享按钮文案
        updateBottomButtonsForCompletion()
    }
    
    private func updateOverallProgress() {
        let totalSelectedItems = selectedIndices.count
        let processedItems = completedCount + failedCount
        let progress = totalSelectedItems > 0 ? Float(processedItems) / Float(totalSelectedItems) : 0
        
        overallProgressView.progress = progress
        progressLabel.text = "\(Int(progress * 100))%"
    }
    
    private func updateProcessingState() {
        // 更新按钮状态和文案
        if isProcessing {
            startButton.isEnabled = false
            startButton.alpha = 0.6
            startButton.setTitle("处理中...", for: .normal)
        } else {
            // 根据选择状态更新按钮
            updateStartButtonText()
        }
        
        pauseButton.isHidden = !isProcessing
        resetButton.isHidden = !isProcessing
        
        levelSegmentedControl.isEnabled = !isProcessing
        levelSegmentedControl.alpha = isProcessing ? 0.6 : 1.0
    }
}

// MARK: - UI Updates
extension BatchImageEnhanceViewController {
    
    private func updateUI() {
        updateCountLabel()
        updateStartButtonText()
    }
    
    private func updateCountLabel() {
        let totalCount = enhanceItems.count
        let selectedCount = selectedIndices.count
        if selectedCount > 0 {
            countLabel.text = "共\(totalCount)张图片，已选择\(selectedCount)张"
        } else {
            countLabel.text = "共\(totalCount)张图片，请选择需要修复的图片"
        }
    }
    
    private func updateStartButtonText() {
        let selectedCount = selectedIndices.count
        if selectedCount > 0 {
            startButton.setTitle("开始修复(\(selectedCount)张)", for: .normal)
            startButton.isEnabled = true
            startButton.alpha = 1.0
        } else {
            startButton.setTitle("请先选择图片", for: .normal)
            startButton.isEnabled = false
            startButton.alpha = 0.6
        }
    }
    
    private func updateSelectionUI() {
        // 更新全选/反选按钮状态
        let allSelected = selectedIndices.count == enhanceItems.count
        selectModeButton.isSelected = allSelected
        selectModeButton.setTitle(allSelected ? "反选" : "全选", for: .normal)
        
        // 刷新集合视图显示选择状态
        collectionView.reloadData()
        
        // 更新计数和按钮
        updateCountLabel()
        updateStartButtonText()
    }
    
    // 移除原来的toggleSelectMode方法，已被toggleSelectAll替代
    
    private func updateBottomButtonsForCompletion() {
        // 处理完成后，按钮文案基于实际完成的图片数量
        let completedItems = enhanceItems.filter { $0.processingState == .completed }
        let completedCount = completedItems.count
        
        saveAllButton.setTitle("保存已完成(\(completedCount))", for: .normal)
        shareAllButton.setTitle("分享已完成(\(completedCount))", for: .normal)
        
        if completedCount > 1 {
            createCollageButton.setTitle("🧩 拼图(\(completedCount))", for: .normal)
        } else {
            createCollageButton.setTitle("🧩 拼图", for: .normal)
        }
    }
}

// MARK: - Save & Share
extension BatchImageEnhanceViewController {
    
    private func saveCompletedImages() {
        // 保存所有已完成的图片，不区分选择状态
        let imagesToSave = enhanceItems.compactMap { item in
            return item.processingState == .completed ? item.enhancedImage : nil
        }
        
        guard !imagesToSave.isEmpty else {
            showAlert(title: "无法保存", message: "没有已完成的图片可以保存")
            return
        }
        
        // 批量保存到相册
        batchSaveToPhotos(imagesToSave)
    }
    
    private func shareCompletedImages() {
        // 分享所有已完成的图片，不区分选择状态
        let imagesToShare = enhanceItems.compactMap { item in
            return item.processingState == .completed ? item.enhancedImage : nil
        }
        
        guard !imagesToShare.isEmpty else {
            showAlert(title: "无法分享", message: "没有已完成的图片可以分享")
            return
        }
        
        // 创建分享界面
        let activityVC = UIActivityViewController(activityItems: imagesToShare, applicationActivities: nil)
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareAllButton
            popover.sourceRect = shareAllButton.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    private func batchSaveToPhotos(_ images: [UIImage]) {
        // 检查相册权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch status {
                case .authorized:
                    self.performBatchSave(images)
                case .denied, .restricted:
                    self.showAlert(title: "权限不足", message: "需要相册访问权限才能保存图片")
                case .notDetermined:
                    // 重新请求权限
                    self.batchSaveToPhotos(images)
                @unknown default:
                    self.showAlert(title: "权限错误", message: "无法获取相册权限")
                }
            }
        }
    }
    
    private func performBatchSave(_ images: [UIImage]) {
        let progressAlert = UIAlertController(title: "保存中", message: "正在保存图片到相册...", preferredStyle: .alert)
        present(progressAlert, animated: true)
        
        var savedCount = 0
        var failedCount = 0
        let totalCount = images.count
        
        for (index, image) in images.enumerated() {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
        
        // 简化处理，实际应该用批量保存API
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            progressAlert.dismiss(animated: true) {
                self.showAlert(title: "保存完成", message: "已保存\(totalCount)张图片到相册")
            }
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        // 保存完成回调
    }
}

// MARK: - Helper Methods
extension BatchImageEnhanceViewController {
    
    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "重置确认",
            message: "这将清除所有处理结果，确定要重置吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { _ in
            self.resetAllItems()
        })
        
        present(alert, animated: true)
    }
    
    private func showCancelConfirmation() {
        let alert = UIAlertController(
            title: "取消处理",
            message: "正在处理中，确定要取消吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "继续处理", style: .cancel))
        alert.addAction(UIAlertAction(title: "取消", style: .destructive) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func resetAllItems() {
        for item in enhanceItems {
            item.processingState = .pending
            item.progress = 0.0
            item.error = nil
            item.enhancedImage = nil
        }
        
        completedCount = 0
        failedCount = 0
        
        // 重置为默认未选择状态
        selectedIndices = Set<Int>()
        
        progressContainerView.isHidden = true
        overallProgressView.progress = 0.0
        progressLabel.text = "0%"
        statusLabel.text = "准备就绪"
        
        saveAllButton.isEnabled = false
        saveAllButton.alpha = 0.6
        shareAllButton.isEnabled = false
        shareAllButton.alpha = 0.6
        createCollageButton.isEnabled = false
        createCollageButton.alpha = 0.6
        
        // 更新选择UI
        updateSelectionUI()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    /// 显示单图详细查看页面
    private func showDetailView(for item: BatchEnhanceItem, at index: Int) {
        guard let enhancedImage = item.enhancedImage else { return }
        
        let imageEnhanceVC = ImageEnhanceViewController(
            image: item.originalImage,
            timestamp: Date().timeIntervalSince1970
        )
        
        // 设置来源类型
        imageEnhanceVC.sourceType = .fromBatch
        
        // 预设已修复的图片
        imageEnhanceVC.setEnhancedImage(enhancedImage)
        
        // 设置完成回调（用户在详细页面重新修复后）
        imageEnhanceVC.onEnhancementComplete = { [weak self] newEnhancedImage in
            self?.enhanceItems[index].enhancedImage = newEnhancedImage
            self?.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        }
        
        navigationController?.pushViewController(imageEnhanceVC, animated: true)
    }
    
    /// 切换图片选择状态
    private func toggleSelection(at index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
        
        // 更新UI
        updateSelectionUI()
    }
}

// MARK: - UICollectionViewDataSource
extension BatchImageEnhanceViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return enhanceItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BatchEnhanceCell", for: indexPath) as! BatchEnhanceCell
        let item = enhanceItems[indexPath.item]
        cell.configure(with: item, isSelected: selectedIndices.contains(indexPath.item))
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension BatchImageEnhanceViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = enhanceItems[indexPath.item]
        
        // 优先检查是否可以查看详细（已完成的图片随时可以查看详细）
        if item.processingState == .completed {
            showDetailView(for: item, at: indexPath.item)
        } else if !isProcessing {
            // 未完成且非处理状态时，切换选择状态
            toggleSelection(at: indexPath.item)
        }
        // 处理中的图片不响应点击
        
        HapticFeedbackManager.shared.lightImpact()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension BatchImageEnhanceViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 16
        let spacing: CGFloat = 8
        let availableWidth = collectionView.bounds.width - (padding * 2) - spacing
        let itemWidth = availableWidth / 2
        
        return CGSize(width: itemWidth, height: itemWidth + 60) // 额外高度用于显示状态信息
    }
}

// MARK: - BatchEnhanceCell
class BatchEnhanceCell: UICollectionViewCell {
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let originalImageView = UIImageView()
    private let enhancedImageView = UIImageView()
    private let dividerView = UIView()
    private let originalLabel = UILabel()
    private let enhancedLabel = UILabel()
    
    // 状态指示器
    private let statusContainerView = UIView()
    private let statusIconView = UIImageView()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView()
    
    // 选择指示器
    private let selectionIndicatorView = UIView()
    private let checkmarkImageView = UIImageView()
    
    // 覆盖层
    private let overlayView = UIView()
    
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
    
    private func setupUI() {
        backgroundColor = .clear
        
        // 容器视图
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        contentView.addSubview(containerView)
        
        // 原图视图
        originalImageView.contentMode = .scaleAspectFill
        originalImageView.clipsToBounds = true
        containerView.addSubview(originalImageView)
        
        // 修复后图片视图
        enhancedImageView.contentMode = .scaleAspectFill
        enhancedImageView.clipsToBounds = true
        enhancedImageView.alpha = 0
        containerView.addSubview(enhancedImageView)
        
        // 分割线（仅在修复完成时显示）
        dividerView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        dividerView.isHidden = true // 初始隐藏，仅在有修复后图片时显示
        containerView.addSubview(dividerView)
        
        // 标签
        originalLabel.text = "原图"
        originalLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        originalLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        originalLabel.textAlignment = .center
        originalLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        originalLabel.layer.cornerRadius = 8
        originalLabel.clipsToBounds = true
        containerView.addSubview(originalLabel)
        
        enhancedLabel.text = "修复后"
        enhancedLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        enhancedLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        enhancedLabel.textAlignment = .center
        enhancedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        enhancedLabel.layer.cornerRadius = 8
        enhancedLabel.clipsToBounds = true
        enhancedLabel.alpha = 0
        containerView.addSubview(enhancedLabel)
        
        // 状态容器
        statusContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        statusContainerView.layer.cornerRadius = 8
        contentView.addSubview(statusContainerView)
        
        // 状态图标
        statusIconView.contentMode = .scaleAspectFit
        statusIconView.tintColor = .white
        statusContainerView.addSubview(statusIconView)
        
        // 状态标签
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusContainerView.addSubview(statusLabel)
        
        // 进度条
        progressView.progressTintColor = ThemeManager.buttonPrimary
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progressView.layer.cornerRadius = 1
        progressView.clipsToBounds = true
        progressView.isHidden = true
        statusContainerView.addSubview(progressView)
        
        // 选择指示器
        selectionIndicatorView.backgroundColor = ThemeManager.buttonPrimary
        selectionIndicatorView.layer.cornerRadius = 12
        selectionIndicatorView.isHidden = true
        contentView.addSubview(selectionIndicatorView)
        
        checkmarkImageView.image = UIImage(systemName: "checkmark")
        checkmarkImageView.tintColor = .white
        checkmarkImageView.contentMode = .scaleAspectFit
        selectionIndicatorView.addSubview(checkmarkImageView)
        
        // 覆盖层
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.layer.cornerRadius = 12
        overlayView.isHidden = true
        contentView.addSubview(overlayView)
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        originalImageView.translatesAutoresizingMaskIntoConstraints = false
        enhancedImageView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        originalLabel.translatesAutoresizingMaskIntoConstraints = false
        enhancedLabel.translatesAutoresizingMaskIntoConstraints = false
        statusContainerView.translatesAutoresizingMaskIntoConstraints = false
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageHeight = frame.width // 正方形图片区域
        
        NSLayoutConstraint.activate([
            // 容器视图
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor), // 正方形
            
            // 原图 (左半部分)
            originalImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            originalImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            originalImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            originalImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.5),
            
            // 修复后图片 (右半部分)
            enhancedImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            enhancedImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            enhancedImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            enhancedImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.5),
            
            // 分割线（仅在显示对比时显示）
            dividerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dividerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            dividerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            dividerView.widthAnchor.constraint(equalToConstant: 1),
            
            // 原图标签
            originalLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            originalLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            originalLabel.widthAnchor.constraint(equalToConstant: 40),
            originalLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // 修复后标签
            enhancedLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            enhancedLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            enhancedLabel.widthAnchor.constraint(equalToConstant: 50),
            enhancedLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // 状态容器
            statusContainerView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 8),
            statusContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            // 状态图标
            statusIconView.leadingAnchor.constraint(equalTo: statusContainerView.leadingAnchor, constant: 12),
            statusIconView.centerYAnchor.constraint(equalTo: statusContainerView.centerYAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 20),
            statusIconView.heightAnchor.constraint(equalToConstant: 20),
            
            // 状态标签
            statusLabel.leadingAnchor.constraint(equalTo: statusIconView.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainerView.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: statusContainerView.centerYAnchor),
            
            // 进度条
            progressView.leadingAnchor.constraint(equalTo: statusContainerView.leadingAnchor, constant: 12),
            progressView.trailingAnchor.constraint(equalTo: statusContainerView.trailingAnchor, constant: -12),
            progressView.bottomAnchor.constraint(equalTo: statusContainerView.bottomAnchor, constant: -8),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            // 选择指示器
            selectionIndicatorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            selectionIndicatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            selectionIndicatorView.widthAnchor.constraint(equalToConstant: 24),
            selectionIndicatorView.heightAnchor.constraint(equalToConstant: 24),
            
            // 对勾图标
            checkmarkImageView.centerXAnchor.constraint(equalTo: selectionIndicatorView.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: selectionIndicatorView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 14),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 14),
            
            // 覆盖层
            overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    func configure(with item: BatchEnhanceItem, isSelected: Bool) {
        // 设置原图
        originalImageView.image = item.originalImage
        
        // 根据状态配置UI
        switch item.processingState {
        case .pending:
            configureForPendingState()
            
        case .processing:
            configureForProcessingState(progress: item.progress)
            
        case .completed:
            configureForCompletedState(enhancedImage: item.enhancedImage)
            
        case .failed:
            configureForFailedState(error: item.error)
        }
        
        // 总是显示选择状态（不需要等处理完成）
        selectionIndicatorView.isHidden = false
        selectionIndicatorView.backgroundColor = isSelected ? ThemeManager.buttonPrimary : UIColor.white.withAlphaComponent(0.3)
        checkmarkImageView.isHidden = !isSelected
        overlayView.isHidden = !isSelected
    }
    
    private func configureForPendingState() {
        statusIconView.image = UIImage(systemName: "clock")
        statusIconView.tintColor = UIColor.white.withAlphaComponent(0.6)
        statusLabel.text = "等待处理"
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        progressView.isHidden = true
        
        enhancedImageView.alpha = 0
        enhancedLabel.alpha = 0
    }
    
    private func configureForProcessingState(progress: Float) {
        statusIconView.image = UIImage(systemName: "gear.circle")
        statusIconView.tintColor = ThemeManager.buttonPrimary
        statusLabel.text = "处理中..."
        statusLabel.textColor = .white
        progressView.isHidden = false
        progressView.progress = progress
        
        // 添加旋转动画
        if statusIconView.layer.animation(forKey: "rotation") == nil {
            let rotation = CABasicAnimation(keyPath: "transform.rotation")
            rotation.fromValue = 0
            rotation.toValue = Double.pi * 2
            rotation.duration = 1.0
            rotation.repeatCount = .infinity
            statusIconView.layer.add(rotation, forKey: "rotation")
        }
    }
    
    private func configureForCompletedState(enhancedImage: UIImage?) {
        statusIconView.image = UIImage(systemName: "checkmark.circle.fill")
        statusIconView.tintColor = ThemeManager.success
        statusLabel.text = "修复完成"
        statusLabel.textColor = ThemeManager.success
        progressView.isHidden = true
        
        // 移除旋转动画
        statusIconView.layer.removeAnimation(forKey: "rotation")
        
        // 显示修复后的图片
        if let enhanced = enhancedImage {
            enhancedImageView.image = enhanced
            
            UIView.animate(withDuration: 0.5) {
                self.enhancedImageView.alpha = 1
                self.enhancedLabel.alpha = 1
                // 修复完成时显示分割线，用于对比显示
                self.dividerView.isHidden = false
            }
        }
    }
    
    private func configureForFailedState(error: ImageEnhancementError?) {
        statusIconView.image = UIImage(systemName: "exclamationmark.circle.fill")
        statusIconView.tintColor = UIColor.systemRed
        statusLabel.text = "处理失败"
        statusLabel.textColor = UIColor.systemRed
        progressView.isHidden = true
        
        // 移除旋转动画
        statusIconView.layer.removeAnimation(forKey: "rotation")
        
        enhancedImageView.alpha = 0
        enhancedLabel.alpha = 0
        // 失败时隐藏分割线
        dividerView.isHidden = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        statusIconView.layer.removeAnimation(forKey: "rotation")
        enhancedImageView.alpha = 0
        enhancedLabel.alpha = 0
        selectionIndicatorView.isHidden = true
        overlayView.isHidden = true
        progressView.isHidden = true
        progressView.progress = 0
        // 重用时隐藏分割线
        dividerView.isHidden = true
    }
}
