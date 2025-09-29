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

// MARK: - Page State Enum
enum PageState {
    case selecting    // 选择阶段
    case processing   // 处理阶段  
    case completed    // 完成阶段
}

// MARK: - BatchImageEnhanceViewController
class BatchImageEnhanceViewController: UIViewController {
    
    // MARK: - Properties
    private let screenshots: [ScreenshotItem]
    private var enhanceItems: [BatchEnhanceItem] = []
    private var currentLevel: EnhanceLevel = .medium
    private var isProcessing = false
    private var pageState: PageState = .selecting
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 头部区域 - 移除重复标题，只保留提示信息
    private let headerView = UIView()
    private let countLabel = UILabel()
    private let tipsLabel = UILabel()
    
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
    
    // 第一行按钮
    private let firstRowStackView = UIStackView()
    private let saveAllButton = UIButton()
    private let shareAllButton = UIButton()
    private let createCollageButton = UIButton()
    
    // 第二行按钮
    private let secondRowStackView = UIStackView()
    private let selectModeButton = UIButton()
    private let reselectButton = UIButton() // 新增重新开始按钮
    private let returnToCenterButton = UIButton() // 新增返回截图中心按钮
    
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
        
        // 初始化状态信息显示
        updateInitialStateInfo()
        
        // 进入批量修复的触感反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        tipsLabel.translatesAutoresizingMaskIntoConstraints = false
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
        firstRowStackView.translatesAutoresizingMaskIntoConstraints = false
        secondRowStackView.translatesAutoresizingMaskIntoConstraints = false
        saveAllButton.translatesAutoresizingMaskIntoConstraints = false
        shareAllButton.translatesAutoresizingMaskIntoConstraints = false
        selectModeButton.translatesAutoresizingMaskIntoConstraints = false
        createCollageButton.translatesAutoresizingMaskIntoConstraints = false
        reselectButton.translatesAutoresizingMaskIntoConstraints = false
        returnToCenterButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // 头部区域 - 调整高度和布局
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            // 数量标签
            countLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            countLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            countLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 提示标签
            tipsLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
            tipsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            tipsLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            tipsLabel.heightAnchor.constraint(equalToConstant: 20),
            
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
            bottomActionView.heightAnchor.constraint(equalToConstant: 120),
            
            // 底部模糊背景
            bottomBlurView.topAnchor.constraint(equalTo: bottomActionView.topAnchor),
            bottomBlurView.leadingAnchor.constraint(equalTo: bottomActionView.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: bottomActionView.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: bottomActionView.bottomAnchor),
            
            // 第一行按钮容器
            firstRowStackView.topAnchor.constraint(equalTo: bottomActionView.topAnchor, constant: 12),
            firstRowStackView.leadingAnchor.constraint(equalTo: bottomActionView.leadingAnchor, constant: 16),
            firstRowStackView.trailingAnchor.constraint(equalTo: bottomActionView.trailingAnchor, constant: -16),
            firstRowStackView.heightAnchor.constraint(equalToConstant: 44),
            
            // 第二行按钮容器
            secondRowStackView.topAnchor.constraint(equalTo: firstRowStackView.bottomAnchor, constant: 8),
            secondRowStackView.leadingAnchor.constraint(equalTo: bottomActionView.leadingAnchor, constant: 16),
            secondRowStackView.trailingAnchor.constraint(equalTo: bottomActionView.trailingAnchor, constant: -16),
            secondRowStackView.heightAnchor.constraint(equalToConstant: 44)
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
        
        // 数量标签 - 调整为更大字体
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        countLabel.textColor = .white
        countLabel.textAlignment = .center
        countLabel.text = "共 \(enhanceItems.count) 张图片，请选择需要修复的图片"
        headerView.addSubview(countLabel)
        
        // 提示标签 - 添加智能提示
        tipsLabel.font = ThemeManager.captionFont
        tipsLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        tipsLabel.textAlignment = .center
        tipsLabel.text = "💡 想要不同修复强度？点击单个图片进入详细修复"
        tipsLabel.numberOfLines = 2
        headerView.addSubview(tipsLabel)
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
        // 状态容器始终显示，提供持续的状态反馈
        progressContainerView.isHidden = false
        
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
        
        // 设置初始状态信息
        updateInitialStateInfo()
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
        
        // 配置第一行StackView
        firstRowStackView.axis = .horizontal
        firstRowStackView.distribution = .fillEqually
        firstRowStackView.spacing = 12
        bottomActionView.addSubview(firstRowStackView)
        
        // 配置第二行StackView
        secondRowStackView.axis = .horizontal
        secondRowStackView.distribution = .fillEqually
        secondRowStackView.spacing = 12
        bottomActionView.addSubview(secondRowStackView)
        
        // 保存全部按钮
        saveAllButton.setTitle("保存已完成", for: .normal)
        saveAllButton.backgroundColor = ThemeManager.buttonPrimary
        saveAllButton.setTitleColor(.white, for: .normal)
        saveAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        saveAllButton.titleLabel?.adjustsFontSizeToFitWidth = true
        saveAllButton.titleLabel?.minimumScaleFactor = 0.8
        saveAllButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        saveAllButton.addTarget(self, action: #selector(saveAllButtonTapped), for: .touchUpInside)
        saveAllButton.isEnabled = false
        saveAllButton.alpha = 0.6
        firstRowStackView.addArrangedSubview(saveAllButton)
        
        // 分享全部按钮
        shareAllButton.setTitle("分享已完成", for: .normal)
        shareAllButton.backgroundColor = ThemeManager.buttonSecondary
        shareAllButton.setTitleColor(.white, for: .normal)
        shareAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        shareAllButton.titleLabel?.adjustsFontSizeToFitWidth = true
        shareAllButton.titleLabel?.minimumScaleFactor = 0.8
        shareAllButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        shareAllButton.addTarget(self, action: #selector(shareAllButtonTapped), for: .touchUpInside)
        shareAllButton.isEnabled = false
        shareAllButton.alpha = 0.6
        firstRowStackView.addArrangedSubview(shareAllButton)
        
        // 拼图创建按钮
        createCollageButton.setTitle("拼图创建", for: .normal)
        createCollageButton.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.8)
        createCollageButton.setTitleColor(.white, for: .normal)
        createCollageButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        createCollageButton.titleLabel?.adjustsFontSizeToFitWidth = true
        createCollageButton.titleLabel?.minimumScaleFactor = 0.8
        createCollageButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        createCollageButton.addTarget(self, action: #selector(createCollageButtonTapped), for: .touchUpInside)
        createCollageButton.isEnabled = false
        createCollageButton.alpha = 0.6
        firstRowStackView.addArrangedSubview(createCollageButton)
        
        // 选择模式按钮（全选/反选）
        selectModeButton.setTitle("全选", for: .normal)
        selectModeButton.setTitle("反选", for: .selected)
        selectModeButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        selectModeButton.setTitleColor(.white, for: .normal)
        selectModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        selectModeButton.titleLabel?.adjustsFontSizeToFitWidth = true
        selectModeButton.titleLabel?.minimumScaleFactor = 0.8
        selectModeButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        selectModeButton.addTarget(self, action: #selector(selectModeButtonTapped), for: .touchUpInside)
        selectModeButton.isEnabled = true
        selectModeButton.alpha = 1.0
        secondRowStackView.addArrangedSubview(selectModeButton)
        
        // 重新开始按钮
        reselectButton.setTitle("重新开始", for: .normal)
        reselectButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        reselectButton.setTitleColor(.white, for: .normal)
        reselectButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        reselectButton.titleLabel?.adjustsFontSizeToFitWidth = true
        reselectButton.titleLabel?.minimumScaleFactor = 0.8
        reselectButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        reselectButton.addTarget(self, action: #selector(reselectButtonTapped), for: .touchUpInside)
        reselectButton.isHidden = true // 初始隐藏
        secondRowStackView.addArrangedSubview(reselectButton)
        
        // 返回截图中心按钮
        returnToCenterButton.setTitle("返回截图中心", for: .normal)
        returnToCenterButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        returnToCenterButton.setTitleColor(.white, for: .normal)
        returnToCenterButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        returnToCenterButton.titleLabel?.adjustsFontSizeToFitWidth = true
        returnToCenterButton.titleLabel?.minimumScaleFactor = 0.8
        returnToCenterButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        returnToCenterButton.addTarget(self, action: #selector(returnToCenterButtonTapped), for: .touchUpInside)
        returnToCenterButton.isHidden = true // 初始隐藏
        secondRowStackView.addArrangedSubview(returnToCenterButton)
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
    
    @objc private func reselectButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        showReselectConfirmation()
    }
    
    @objc private func returnToCenterButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        performReturn()
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
            // 检查是否有修复完成但未保存的图片
            let completedItems = enhanceItems.filter { $0.processingState == .completed }
            
            if !completedItems.isEmpty {
                // 有完成的修复但可能未保存，显示确认对话框
                let alert = UIAlertController(
                    title: "确定要退出吗？",
                    message: "已完成修复 \(completedItems.count) 张图片，退出后可在截图处理中心继续操作",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "退出", style: .default) { [weak self] _ in
                    self?.performReturn()
                })
                
                alert.addAction(UIAlertAction(title: "继续修复", style: .cancel))
                
                present(alert, animated: true)
            } else {
                // 没有完成的修复，直接返回
                performReturn()
            }
        }
    }
    
    /// 执行返回操作 - 第一层立即优化版本
    private func performReturn() {
        // 🚀 优化：智能返回路径判断
        guard let navigationController = navigationController else { return }
        
        // 🚀 优化1：并行化资源清理 - 立即开始清理，不等待导航完成
        DispatchQueue.global(qos: .utility).async {
            self.cleanupImageResources()
        }
        
        // 检查导航栈中是否有ScreenshotProcessingViewController
        let hasScreenshotProcessingVC = navigationController.viewControllers.contains { viewController in
            return viewController is ScreenshotProcessingViewController
        }
        
        if hasScreenshotProcessingVC {
            // 如果有截图处理中心，返回到那里
            let targetViewController = navigationController.viewControllers.first { viewController in
                return viewController is ScreenshotProcessingViewController
            }
            
            if let targetVC = targetViewController {
                // 🚀 优化2：立即导航，资源清理并行进行
                navigationController.popToViewController(targetVC, animated: true)
                return
            }
        }
        
        // 🚀 优化3：默认返回，简化逻辑
        navigationController.popViewController(animated: true)
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
                    self.updatePageState()
                    
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
        
        // 根据当前状态更新信息显示
        if pageState == .processing {
            updateProcessingStateInfo()
        } else if pageState == .completed {
            updateCompletedStateInfo()
        }
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
        
        // 更新状态信息显示
        updateSelectionStateInfo()
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
                let message = totalCount == 1 ? "已保存1张修复后的图片到相册" : "已保存\(totalCount)张修复后的图片到相册"
                self.showAlert(title: "保存成功", message: message)
                HapticFeedbackManager.shared.notificationSuccess()
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
    
    private func showReselectConfirmation() {
        let alert = UIAlertController(
            title: "重新开始确认",
            message: "这将清除所有修复结果，返回选择状态，确定要重新开始吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重新开始", style: .destructive) { _ in
            self.resetToSelectingState()
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
    
    private func resetToSelectingState() {
        // 停止所有处理
        // imageEnhancer.cancelAllEnhancements() // 如果需要的话可以添加取消方法
        
        // 重置所有项目状态
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
        
        // 重置页面状态为选择状态
        pageState = .selecting
        
        // 状态显示和UI更新将由状态管理系统处理
        updatePageState()
        updateSelectionUI()
        collectionView.reloadData()
    }
    
    private func updatePageState() {
        let hasCompleted = enhanceItems.contains { $0.processingState == .completed }
        let hasProcessing = enhanceItems.contains { $0.processingState == .processing }
        
        // 更新页面状态
        let newState: PageState
        if hasProcessing {
            newState = .processing
        } else if hasCompleted {
            newState = .completed
        } else {
            newState = .selecting
        }
        
        // 只在状态真正改变时更新
        if pageState != newState {
            pageState = newState
            updateStateInfoForCurrentState()
        }
        
        // 根据状态显示/隐藏按钮
        if hasCompleted && !hasProcessing {
            // 有完成的项目且没有正在处理的项目，显示重新开始和返回按钮
            reselectButton.isHidden = false
            returnToCenterButton.isHidden = false
        } else {
            // 否则隐藏这些按钮
            reselectButton.isHidden = true
            returnToCenterButton.isHidden = true
        }
    }
    
    /// 根据当前页面状态更新状态信息显示
    private func updateStateInfoForCurrentState() {
        switch pageState {
        case .selecting:
            updateInitialStateInfo()
            updateButtonsForSelectingState()
        case .processing:
            updateProcessingStateInfo()
            updateButtonsForProcessingState()
        case .completed:
            updateCompletedStateInfo()
            updateButtonsForCompletedState()
        }
    }
    
    /// 更新选择状态下的按钮显示
    private func updateButtonsForSelectingState() {
        // 显示选择相关按钮
        selectModeButton.isHidden = false
        levelSegmentedControl.isHidden = false
        startButton.isHidden = false
        
        // 重置开始按钮状态为正常可点击状态
        startButton.setTitle("开始修复", for: .normal)
        startButton.isEnabled = true
        startButton.alpha = 1.0
        
        // 恢复反选按钮的可点击状态
        selectModeButton.isEnabled = true
        selectModeButton.alpha = 1.0
        
        // 隐藏处理相关按钮
        pauseButton.isHidden = true
        resetButton.isHidden = true
    }
    
    /// 更新处理状态下的按钮显示
    private func updateButtonsForProcessingState() {
        // 隐藏选择相关按钮
        selectModeButton.isHidden = true
        levelSegmentedControl.isHidden = true
        startButton.isHidden = true
        
        // 显示处理相关按钮
        pauseButton.isHidden = false
        resetButton.isHidden = false
    }
    
    /// 更新完成状态下的按钮显示 - 保留部分控制元素
    private func updateButtonsForCompletedState() {
        // 隐藏处理相关按钮
        pauseButton.isHidden = true
        resetButton.isHidden = true
        
        // 保留选择和等级控制，允许用户重新修复
        selectModeButton.isHidden = false
        levelSegmentedControl.isHidden = false
        startButton.isHidden = false
        
        // 更新开始按钮为不可点击的成功状态
        startButton.setTitle("已成功修复", for: .normal)
        startButton.isEnabled = false
        startButton.alpha = 0.6
        
        // 禁用反选按钮，修复完成后不允许更改选择
        selectModeButton.isEnabled = false
        selectModeButton.alpha = 0.6
        
        // 保存和分享按钮的显示由updateBottomButtonsForCompletion控制
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    /// 显示单图详细查看页面
    private func showDetailView(for item: BatchEnhanceItem, at index: Int) {
        // 创建批量上下文
        let batchContext = BatchContext(
            items: enhanceItems,
            currentIndex: index,
            enhanceLevel: currentLevel,
            onItemUpdated: { [weak self] updatedIndex, newEnhancedImage in
                self?.enhanceItems[updatedIndex].enhancedImage = newEnhancedImage
                self?.enhanceItems[updatedIndex].processingState = .completed
                self?.collectionView.reloadItems(at: [IndexPath(item: updatedIndex, section: 0)])
            }
        )
        
        let imageEnhanceVC: ImageEnhanceViewController
        
        if item.processingState == .completed, let enhancedImage = item.enhancedImage {
            // 已修复的图片：使用扩展初始化，跳过自动修复
            imageEnhanceVC = ImageEnhanceViewController(
                image: item.originalImage,
                timestamp: Date().timeIntervalSince1970,
                enhanceLevel: currentLevel,  // 传递当前批量修复使用的等级
                skipAutoEnhance: true,      // 跳过自动修复
                batchContext: batchContext   // 传递批量上下文
            )
            
            // 设置来源类型为已完成的批量修复
            imageEnhanceVC.sourceType = .fromBatchCompleted
            
            // 预设已修复的图片
            imageEnhanceVC.setEnhancedImage(enhancedImage)
            
        } else {
            // 未修复的图片：使用扩展初始化，保持当前等级但允许自动修复
            imageEnhanceVC = ImageEnhanceViewController(
                image: item.originalImage,
                timestamp: Date().timeIntervalSince1970,
                enhanceLevel: currentLevel,  // 传递当前批量修复使用的等级
                skipAutoEnhance: false,     // 允许自动修复
                batchContext: batchContext   // 传递批量上下文
            )
            
            // 设置来源类型为批量修复
            imageEnhanceVC.sourceType = .fromBatch
        }
        
        // 设置完成回调（用户在详细页面重新修复后）
        imageEnhanceVC.onEnhancementComplete = { [weak self] newEnhancedImage in
            self?.enhanceItems[index].enhancedImage = newEnhancedImage
            self?.enhanceItems[index].processingState = .completed
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

// MARK: - BatchEnhanceCellDelegate
extension BatchImageEnhanceViewController: BatchEnhanceCellDelegate {
    
    func cellDidRequestSelection(_ cell: BatchEnhanceCell, at index: Int) {
        // 处理选择/取消选择逻辑
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
        updateSelectionUI()
    }
    
    func cellDidRequestSingleEnhance(_ cell: BatchEnhanceCell, at index: Int) {
        let item = enhanceItems[index]
        
        // 根据图片处理状态决定行为
        switch item.processingState {
        case .completed:
            // 已完成：查看详情页面
            showDetailView(for: item, at: index)
            
        case .pending, .failed:
            // 等待处理或失败：进入单独修复（但需要确保不在全局处理中）
            if !isProcessing {
                // 从选择列表中移除该图片（避免重复处理）
                if selectedIndices.contains(index) {
                    selectedIndices.remove(index)
                    updateSelectionUI()
                }
                
                // 进入单独修复页面
                showDetailView(for: item, at: index)
            }
            
        case .processing:
            // 处理中：不响应点击（已在Cell中通过isEnabled控制）
            break
        }
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
        
        // 设置委托和配置
        cell.delegate = self
        cell.configure(with: item, isSelected: selectedIndices.contains(indexPath.item), at: indexPath)
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension BatchImageEnhanceViewController: UICollectionViewDelegate {
    // 移除原有的didSelectItemAt方法，现在通过BatchEnhanceCellDelegate处理点击事件
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

// MARK: - BatchEnhanceCellDelegate
protocol BatchEnhanceCellDelegate: AnyObject {
    func cellDidRequestSelection(_ cell: BatchEnhanceCell, at index: Int)
    func cellDidRequestSingleEnhance(_ cell: BatchEnhanceCell, at index: Int)
}

// MARK: - BatchEnhanceCell
class BatchEnhanceCell: UICollectionViewCell {
    
    // MARK: - Delegate
    weak var delegate: BatchEnhanceCellDelegate?
    private var indexPath: IndexPath?
    
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
    
    // MARK: - Interactive Buttons
    private let selectionButton = UIButton()    // 选择框区域按钮
    private let imageContentButton = UIButton() // 图片内容区域按钮
    
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
        
        // 交互按钮设置
        setupInteractiveButtons()
    }
    
    private func setupInteractiveButtons() {
        // 选择区域按钮 - 覆盖选择框及其周围区域
        selectionButton.backgroundColor = UIColor.clear
        selectionButton.addTarget(self, action: #selector(selectionButtonTapped), for: .touchUpInside)
        contentView.addSubview(selectionButton)
        
        // 图片内容区域按钮 - 覆盖图片主体区域
        imageContentButton.backgroundColor = UIColor.clear
        imageContentButton.addTarget(self, action: #selector(imageContentButtonTapped), for: .touchUpInside)
        contentView.addSubview(imageContentButton)
    }
    
    @objc private func selectionButtonTapped() {
        // 触觉反馈
        HapticFeedbackManager.shared.lightImpact()
        
        // 视觉反馈 - 选择框轻微放大动画
        animateSelectionFeedback()
        
        if let indexPath = indexPath {
            delegate?.cellDidRequestSelection(self, at: indexPath.item)
        }
    }
    
    @objc private func imageContentButtonTapped() {
        // 只有按钮可用时才响应
        guard imageContentButton.isEnabled else { return }
        
        // 触觉反馈
        HapticFeedbackManager.shared.buttonTap()
        
        // 视觉反馈 - 图片内容轻微缩放动画
        animateImageContentFeedback()
        
        if let indexPath = indexPath {
            delegate?.cellDidRequestSingleEnhance(self, at: indexPath.item)
        }
    }
    
    private func animateSelectionFeedback() {
        UIView.animate(withDuration: 0.1, animations: {
            self.selectionIndicatorView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.selectionIndicatorView.transform = .identity
            }
        }
    }
    
    private func animateImageContentFeedback() {
        UIView.animate(withDuration: 0.1, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.containerView.transform = .identity
            }
        }
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
        selectionButton.translatesAutoresizingMaskIntoConstraints = false
        imageContentButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // 选择按钮 - 覆盖右上角选择框区域 (带扩展热区)
            selectionButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionButton.widthAnchor.constraint(equalToConstant: 44), // 扩展热区
            selectionButton.heightAnchor.constraint(equalToConstant: 44), // 扩展热区
            
            // 图片内容按钮 - 覆盖剩余区域
            imageContentButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageContentButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageContentButton.trailingAnchor.constraint(equalTo: selectionButton.leadingAnchor),
            imageContentButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    func configure(with item: BatchEnhanceItem, isSelected: Bool, at indexPath: IndexPath) {
        // 保存indexPath用于委托回调
        self.indexPath = indexPath
        
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
        
        // 根据状态设置按钮可用性
        updateButtonStates(for: item.processingState)
    }
    
    private func updateButtonStates(for processingState: BatchEnhanceItem.ProcessingState) {
        switch processingState {
        case .pending:
            // 等待状态：选择框可用，图片内容可用（进入单独修复）
            selectionButton.isEnabled = true
            imageContentButton.isEnabled = true
            imageContentButton.alpha = 1.0
            
        case .processing:
            // 处理中：选择框可用，图片内容不可用
            selectionButton.isEnabled = true
            imageContentButton.isEnabled = false
            imageContentButton.alpha = 0.5 // 视觉提示不可用
            
        case .completed:
            // 完成状态：选择框可用，图片内容可用（查看详情）
            selectionButton.isEnabled = true
            imageContentButton.isEnabled = true
            imageContentButton.alpha = 1.0
            
        case .failed:
            // 失败状态：选择框可用，图片内容可用（重新修复）
            selectionButton.isEnabled = true
            imageContentButton.isEnabled = true
            imageContentButton.alpha = 1.0
        }
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

// MARK: - State Information Management
extension BatchImageEnhanceViewController {
    
    /// 更新初始状态信息显示
    private func updateInitialStateInfo() {
        let selectedCount = selectedIndices.count
        let totalCount = enhanceItems.count
        let levelText = getLevelText(currentLevel)
        
        if selectedCount == 0 {
            statusLabel.text = "选择图片后点击开始修复"
            progressLabel.text = "当前等级：\(levelText)"
            // 显示智能提示
            tipsLabel.text = "💡 想要不同修复强度？点击单个图片进入详细修复"
            tipsLabel.isHidden = false
        } else {
            statusLabel.text = "已选择 \(selectedCount) 张图片"
            progressLabel.text = "当前等级：\(levelText) | 共 \(totalCount) 张"
            // 选择后隐藏提示，避免界面拥挤
            tipsLabel.isHidden = true
        }
        
        overallProgressView.progress = 0.0
    }
    
    /// 更新选择状态变化时的信息
    func updateSelectionStateInfo() {
        guard pageState == .selecting else { return }
        updateInitialStateInfo()
    }
    
    /// 获取等级文本描述
    private func getLevelText(_ level: EnhanceLevel) -> String {
        switch level {
        case .light:
            return "轻度"
        case .medium:
            return "中度"
        case .heavy:
            return "重度"
        }
    }
    
    /// 更新处理过程中的状态信息
    private func updateProcessingStateInfo() {
        let selectedCount = selectedIndices.count
        let completedItems = enhanceItems.enumerated().filter { index, item in
            selectedIndices.contains(index) && item.processingState == .completed
        }.count
        
        let processingItems = enhanceItems.enumerated().filter { index, item in
            selectedIndices.contains(index) && item.processingState == .processing
        }.count
        
        if processingItems > 0 {
            statusLabel.text = "正在修复第 \(completedItems + 1) 张图片..."
        } else if completedItems == selectedCount {
            statusLabel.text = "修复完成！共处理 \(completedItems) 张图片"
        } else {
            statusLabel.text = "已完成 \(completedItems)/\(selectedCount) 张图片"
        }
        
        // 处理中隐藏提示信息，避免干扰
        tipsLabel.isHidden = true
        
        progressLabel.text = "\(Int(overallProgressView.progress * 100))%"
    }
    
    /// 更新完成状态的信息
    private func updateCompletedStateInfo() {
        let completedItems = enhanceItems.filter { $0.processingState == .completed }.count
        let failedItems = enhanceItems.filter { $0.processingState == .failed }.count
        
        if failedItems == 0 {
            statusLabel.text = "🎉 全部修复完成！"
            progressLabel.text = "成功处理 \(completedItems) 张图片"
        } else {
            statusLabel.text = "修复完成，有 \(failedItems) 张失败"
            progressLabel.text = "成功 \(completedItems) 张，失败 \(failedItems) 张"
        }
        
        // 完成状态显示不同的提示信息
        tipsLabel.text = "✨ 点击已完成的图片可查看对比效果或重新修复"
        tipsLabel.isHidden = false
        
        overallProgressView.progress = 1.0
    }
}
