//
//  ImageEnhanceViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  图像画质修复视图控制器 - 修复前后对比和参数调节
//

import UIKit
import Photos

// MARK: - Error Types
enum PhotoLibraryError: Error {
    case permissionDenied
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "需要相册访问权限才能保存图片"
        }
    }
}

// MARK: - 修复来源类型
enum EnhanceSourceType {
    case fromScreenshots    // 来自截图
    case fromCollage       // 来自拼图
    case fromBatch         // 来自批量修复（未修复状态）
    case fromBatchCompleted // 来自批量修复（已修复状态）
    
    var displayName: String {
        switch self {
        case .fromScreenshots:
            return "截图修复"
        case .fromCollage:
            return "拼图修复"
        case .fromBatch:
            return "批量修复"
        case .fromBatchCompleted:
            return "批量修复结果"
        }
    }
}

// MARK: - 批量上下文信息
struct BatchContext {
    let items: [BatchEnhanceItem]
    let currentIndex: Int
    let enhanceLevel: EnhanceLevel
    let onItemUpdated: ((Int, UIImage) -> Void)?
}

class ImageEnhanceViewController: UIViewController {
    
    // MARK: - Properties
    private let originalImage: UIImage
    private let timestamp: Double
    private var enhancedImage: UIImage?
    private var currentLevel: EnhanceLevel = .medium
    var sourceType: EnhanceSourceType = .fromScreenshots // 修复来源类型
    var onEnhancementComplete: ((UIImage) -> Void)? // 完成回调
    
    // 批量模式相关属性
    private var batchContext: BatchContext?
    private var skipAutoEnhance: Bool = false
    private var currentBatchIndex: Int = 0
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 图像对比视图
    private let comparisonView = ImageComparisonView()
    
    // 控制面板
    private let controlPanelBlurView = BlurEffectView(style: .regular, intensity: 0.9)
    private let levelSegmentedControl = UISegmentedControl(items: ["轻度", "中度", "重度"])
    private let enhanceButton = UIButton()
    private let progressView = UIProgressView()
    private let statusLabel = UILabel()
    
    // 底部按钮
    private let resetButton = UIButton()
    private let saveButton = UIButton()
    private let shareButton = UIButton()
    private let returnToCenterButton = UIButton() // 🆕 返回截图中心按钮
    
    // MARK: - Dependencies
    private let imageEnhancer = ImageEnhancer()
    
    // MARK: - Layout Constraints
    private var controlPanelHeightConstraint: NSLayoutConstraint?
    
    // MARK: - State
    private var isProcessing = false {
        didSet {
            updateProcessingState()
        }
    }
    
    // MARK: - Initialization
    init(image: UIImage, timestamp: Double) {
        self.originalImage = image
        self.timestamp = timestamp
        super.init(nibName: nil, bundle: nil)
    }
    
    // 扩展初始化方法 - 支持批量修复模式
    init(image: UIImage, 
         timestamp: Double, 
         enhanceLevel: EnhanceLevel = .medium,
         skipAutoEnhance: Bool = false,
         batchContext: BatchContext? = nil) {
        self.originalImage = image
        self.timestamp = timestamp
        self.currentLevel = enhanceLevel
        self.skipAutoEnhance = skipAutoEnhance
        self.batchContext = batchContext
        if let context = batchContext {
            self.currentBatchIndex = context.currentIndex
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    /// 设置已修复的图片（用于从批量修复界面进入时预设图片）
    func setEnhancedImage(_ image: UIImage) {
        self.enhancedImage = image
        
        // 如果视图已加载，立即更新显示
        if isViewLoaded {
            comparisonView.setEnhancedImage(image)
            
            // 启用保存和分享按钮
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
            shareButton.isEnabled = true
            shareButton.alpha = 1.0
            
            statusLabel.text = "修复完成！可以保存或分享"
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureInitialState()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 根据skipAutoEnhance参数决定是否自动修复
        if !skipAutoEnhance {
            // 首次显示时自动应用修复
            enhanceImageWithCurrentLevel()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 动态调整控制面板高度，确保适配不同设备
        let safeAreaBottom = view.safeAreaInsets.bottom
        // 🔧 调整基础高度以适应双行按钮布局：
        // segmentedControl(32) + enhanceButton(40) + progressView(6) + statusLabel(20) + 第一行按钮(36) + 第二行按钮(40) + 间距(20+16+12+8+16+12) = 约218px
        // 加上上下内边距20px共约238px，保留额外空间使用300px
        let hasReturnButton = sourceType == .fromBatch || sourceType == .fromBatchCompleted
        let panelHeight = (hasReturnButton ? 300 : 260) + safeAreaBottom
        
        // 调整最大高度比例从40%到45%，给小屏幕设备更多空间
        let maxHeight = view.bounds.height * 0.45
        let finalHeight = min(panelHeight, maxHeight)
        
        controlPanelHeightConstraint?.constant = finalHeight
        
        print("📱 ImageEnhanceViewController 布局更新:")
        print("   安全区域底部: \(safeAreaBottom)")
        print("   控制面板高度: \(finalHeight)")
        print("   屏幕高度: \(view.bounds.height)")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
        
        scrollView.addSubview(contentView)
        
        // 图像对比视图
        comparisonView.setOriginalImage(originalImage)
        contentView.addSubview(comparisonView)
        
        // 控制面板
        setupControlPanel()
        
        // 导航栏
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        // 根据来源类型设置标题
        if let batchContext = batchContext {
            let currentPosition = batchContext.currentIndex + 1
            let totalCount = batchContext.items.count
            title = "第\(currentPosition)张/共\(totalCount)张"
        } else {
            title = sourceType.displayName
        }
        
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // 🔧 移除导航栏右侧按钮，改为底部按钮
        // 返回截图中心按钮现在位于控制面板底部
        
        // 如果是批量模式，可以考虑添加左右切换按钮（Phase 2实现）
        if batchContext != nil {
            setupBatchNavigationButtons()
        }
    }
    
    private func setupControlPanel() {
        controlPanelBlurView.layer.cornerRadius = ThemeManager.largeCornerRadius
        controlPanelBlurView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(controlPanelBlurView)
        
        // 强度选择控件
        setupLevelControl()
        
        // 修复按钮
        setupEnhanceButton()
        
        // 进度视图
        setupProgressView()
        
        // 底部按钮
        setupBottomButtons()
        
        // 🆕 返回截图中心按钮（条件显示）
        if sourceType == .fromBatch || sourceType == .fromBatchCompleted {
            setupReturnToCenterButton()
        }
        
        // 添加到控制面板
        controlPanelBlurView.contentView.addSubview(levelSegmentedControl)
        controlPanelBlurView.contentView.addSubview(enhanceButton)
        controlPanelBlurView.contentView.addSubview(progressView)
        controlPanelBlurView.contentView.addSubview(statusLabel)
        controlPanelBlurView.contentView.addSubview(resetButton)
        controlPanelBlurView.contentView.addSubview(saveButton)
        controlPanelBlurView.contentView.addSubview(shareButton)
        
        // 🆕 条件添加返回截图中心按钮
        if sourceType == .fromBatch || sourceType == .fromBatchCompleted {
            controlPanelBlurView.contentView.addSubview(returnToCenterButton)
        }
    }
    
    private func setupLevelControl() {
        levelSegmentedControl.selectedSegmentIndex = 1 // 默认中度
        levelSegmentedControl.backgroundColor = ThemeManager.cardBackground
        levelSegmentedControl.selectedSegmentTintColor = ThemeManager.buttonPrimary
        levelSegmentedControl.setTitleTextAttributes([.foregroundColor: ThemeManager.primaryText], for: .normal)
        levelSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        
        levelSegmentedControl.addTarget(self, action: #selector(levelChanged(_:)), for: .valueChanged)
    }
    
    private func setupEnhanceButton() {
        enhanceButton.setTitle("应用修复", for: .normal)
        enhanceButton.setTitleColor(.white, for: .normal)
        enhanceButton.backgroundColor = ThemeManager.success
        enhanceButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        enhanceButton.titleLabel?.font = ThemeManager.buttonFont
        
        enhanceButton.addTarget(self, action: #selector(enhanceButtonTapped), for: .touchUpInside)
    }
    
    private func setupProgressView() {
        progressView.progressTintColor = ThemeManager.buttonPrimary
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.isHidden = true
        
        statusLabel.textColor = .white
        statusLabel.font = ThemeManager.captionFont
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2  // 允许多行显示
        
        // 根据来源类型设置初始状态文字
        if sourceType == .fromBatchCompleted {
            statusLabel.text = "批量修复已完成\n如需调整效果，可重新选择修复强度"
        } else {
            statusLabel.text = "选择修复强度并点击应用修复"
        }
    }
    
    private func setupBottomButtons() {
        // 重置按钮
        resetButton.setTitle("重置", for: .normal)
        resetButton.setTitleColor(ThemeManager.secondaryText, for: .normal)
        resetButton.backgroundColor = UIColor.clear
        resetButton.layer.borderWidth = 1
        resetButton.layer.borderColor = ThemeManager.secondaryText.cgColor
        resetButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        
        // 保存按钮
        saveButton.setTitle("保存", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonPrimary
        saveButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        // 分享按钮
        shareButton.setTitle("分享", for: .normal)
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.backgroundColor = ThemeManager.success
        shareButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        
        // 初始状态设置
        saveButton.isEnabled = false
        saveButton.alpha = 0.6
        shareButton.isEnabled = false
        shareButton.alpha = 0.6
    }
    
    // 🆕 设置返回截图中心按钮
    private func setupReturnToCenterButton() {
        returnToCenterButton.setTitle("返回截图中心", for: .normal)
        returnToCenterButton.setTitleColor(.white, for: .normal)
        returnToCenterButton.backgroundColor = ThemeManager.buttonPrimary
        returnToCenterButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        returnToCenterButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        returnToCenterButton.addTarget(self, action: #selector(returnToScreenshotCenterTapped), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        comparisonView.translatesAutoresizingMaskIntoConstraints = false
        controlPanelBlurView.translatesAutoresizingMaskIntoConstraints = false
        
        // 控制面板内的控件
        levelSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        enhanceButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        // 🆕 条件设置返回截图中心按钮的约束
        if sourceType == .fromBatch || sourceType == .fromBatchCompleted {
            returnToCenterButton.translatesAutoresizingMaskIntoConstraints = false
        }
        
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
            scrollView.bottomAnchor.constraint(equalTo: controlPanelBlurView.topAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 对比视图
            comparisonView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            comparisonView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            comparisonView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            comparisonView.heightAnchor.constraint(equalTo: comparisonView.widthAnchor, multiplier: 1.2),
            comparisonView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // 控制面板
            controlPanelBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlPanelBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlPanelBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 强度选择
            levelSegmentedControl.topAnchor.constraint(equalTo: controlPanelBlurView.topAnchor, constant: 20),
            levelSegmentedControl.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 20),
            levelSegmentedControl.trailingAnchor.constraint(equalTo: controlPanelBlurView.trailingAnchor, constant: -20),
            levelSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // 修复按钮
            enhanceButton.topAnchor.constraint(equalTo: levelSegmentedControl.bottomAnchor, constant: 16),
            enhanceButton.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            enhanceButton.widthAnchor.constraint(equalToConstant: 120),
            enhanceButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 进度视图
            progressView.topAnchor.constraint(equalTo: enhanceButton.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: controlPanelBlurView.trailingAnchor, constant: -40),
            
            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: controlPanelBlurView.trailingAnchor, constant: -20),
            
            // 🎨 双行布局 - 第一行：三个功能按钮
            resetButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            resetButton.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 20),
            resetButton.widthAnchor.constraint(equalTo: controlPanelBlurView.widthAnchor, multiplier: 0.25),
            resetButton.heightAnchor.constraint(equalToConstant: 36),
            
            saveButton.centerYAnchor.constraint(equalTo: resetButton.centerYAnchor),
            saveButton.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalTo: resetButton.widthAnchor),
            saveButton.heightAnchor.constraint(equalTo: resetButton.heightAnchor),
            
            shareButton.centerYAnchor.constraint(equalTo: resetButton.centerYAnchor),
            shareButton.trailingAnchor.constraint(equalTo: controlPanelBlurView.trailingAnchor, constant: -20),
            shareButton.widthAnchor.constraint(equalTo: resetButton.widthAnchor),
            shareButton.heightAnchor.constraint(equalTo: resetButton.heightAnchor)
        ])
        
        // 🆕 条件添加返回截图中心按钮约束（第二行）
        if sourceType == .fromBatch || sourceType == .fromBatchCompleted {
            NSLayoutConstraint.activate([
                // 🎨 第二行：返回截图中心按钮 - 居中显示，底部安全区域考虑
                returnToCenterButton.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: 12),
                returnToCenterButton.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
                returnToCenterButton.widthAnchor.constraint(equalToConstant: 160),
                returnToCenterButton.heightAnchor.constraint(equalToConstant: 40),
                returnToCenterButton.bottomAnchor.constraint(lessThanOrEqualTo: controlPanelBlurView.safeAreaLayoutGuide.bottomAnchor, constant: -12)
            ])
        } else {
            // 如果没有返回截图中心按钮，第一行按钮需要设置底部约束
            resetButton.bottomAnchor.constraint(lessThanOrEqualTo: controlPanelBlurView.safeAreaLayoutGuide.bottomAnchor, constant: -12).isActive = true
        }
        
        // 创建控制面板高度约束（稍后在viewDidLayoutSubviews中动态设置）
        controlPanelHeightConstraint = controlPanelBlurView.heightAnchor.constraint(equalToConstant: 280)
        controlPanelHeightConstraint?.isActive = true
    }
    
    private func configureInitialState() {
        // 如果没有通过初始化设置等级，则使用默认中度
        if currentLevel == .medium && batchContext == nil {
            currentLevel = .medium
        }
        
        // 设置分段控制器的选中状态
        levelSegmentedControl.selectedSegmentIndex = currentLevel.rawValue - 1
        updateStatusLabel()
        
        // 如果是批量修复完成状态，更新状态提示
        if sourceType == .fromBatchCompleted {
            updateBatchCompletedStatus()
        }
    }
    
    // MARK: - Image Enhancement
    @objc private func enhanceButtonTapped() {
        enhanceImageWithCurrentLevel()
    }
    
    @objc private func levelChanged(_ sender: UISegmentedControl) {
        currentLevel = EnhanceLevel(rawValue: sender.selectedSegmentIndex + 1) ?? .medium
        updateStatusLabel()
        
        // 如果已有增强图像，自动重新处理
        if enhancedImage != nil {
            enhanceImageWithCurrentLevel()
        }
    }
    
    private func enhanceImageWithCurrentLevel() {
        guard !isProcessing else { return }
        
        isProcessing = true
        progressView.progress = 0
        
        statusLabel.text = "正在处理图像..."
        
        // 触觉反馈
        HapticFeedbackManager.shared.buttonTap()
        
        imageEnhancer.enhanceImage(originalImage, level: currentLevel) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let enhanced):
                    self?.handleEnhancementSuccess(enhanced)
                    
                case .failure(let error):
                    self?.handleEnhancementError(error)
                }
            }
        }
        
        // 模拟进度更新
        animateProgress()
    }
    
    private func animateProgress() {
        UIView.animate(withDuration: 2.0, delay: 0, options: .curveEaseInOut) {
            self.progressView.progress = 1.0
        }
    }
    
    private func handleEnhancementSuccess(_ enhanced: UIImage) {
        enhancedImage = enhanced
        comparisonView.setEnhancedImage(enhanced)
        
        // 🎯 关键新增：重置竖线到中线位置，展示标准修复前后对比
        comparisonView.resetToCenter()
        
        statusLabel.text = "修复完成！可以保存或分享"
        
        // 启用保存和分享按钮
        saveButton.isEnabled = true
        saveButton.alpha = 1.0
        shareButton.isEnabled = true
        shareButton.alpha = 1.0
        
        // 成功触觉反馈
        HapticFeedbackManager.shared.notificationSuccess()
        
        // 显示完成动画
        showCompletionAnimation()
    }
    
    private func handleEnhancementError(_ error: ImageEnhancementError) {
        statusLabel.text = "修复失败：\(error.localizedDescription)"
        
        // 错误触觉反馈
        HapticFeedbackManager.shared.notificationError()
        
        // 显示错误提示
        showErrorAlert(error)
    }
    
    private func showCompletionAnimation() {
        let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkView.tintColor = ThemeManager.success
        checkmarkView.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        checkmarkView.center = comparisonView.center
        view.addSubview(checkmarkView)
        
        checkmarkView.alpha = 0
        checkmarkView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            checkmarkView.alpha = 1
            checkmarkView.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, options: .curveEaseInOut) {
                checkmarkView.alpha = 0
            } completion: { _ in
                checkmarkView.removeFromSuperview()
            }
        }
    }
    
    private func updateProcessingState() {
        enhanceButton.isEnabled = !isProcessing
        enhanceButton.alpha = isProcessing ? 0.6 : 1.0
        levelSegmentedControl.isEnabled = !isProcessing
        
        progressView.isHidden = !isProcessing
        
        if isProcessing {
            enhanceButton.setTitle("处理中...", for: .normal)
        } else {
            enhanceButton.setTitle("应用修复", for: .normal)
        }
    }
    
    private func updateStatusLabel() {
        if !isProcessing {
            if sourceType == .fromBatchCompleted {
                statusLabel.text = "批量修复已完成 - \(currentLevel.displayName)效果"
            } else {
                statusLabel.text = "\(currentLevel.displayName) - \(currentLevel.description)"
            }
        }
    }
    
    private func updateBatchCompletedStatus() {
        statusLabel.text = "批量修复已完成 - \(currentLevel.displayName)效果\n如需调整效果，可重新选择修复强度"
        
        // 更新导航栏副标题（如果需要）
        if let batchContext = batchContext {
            let currentPosition = batchContext.currentIndex + 1
            let totalCount = batchContext.items.count
            title = "第\(currentPosition)张/共\(totalCount)张 - 已修复"
        }
    }
    
    // MARK: - Batch Navigation Support
    private func setupBatchNavigationButtons() {
        guard let context = batchContext else { return }
        
        // 创建左右切换按钮
        let prevButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(previousImageTapped)
        )
        
        let nextButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: self,
            action: #selector(nextImageTapped)
        )
        
        // 根据当前位置启用/禁用按钮
        prevButton.isEnabled = context.currentIndex > 0
        nextButton.isEnabled = context.currentIndex < context.items.count - 1
        
        // 🎯 实现对称布局：左箭头在左侧，右箭头在右侧，标题居中
        // 保留原有的返回按钮，添加左箭头在其右侧
        if let originalLeftButton = navigationItem.leftBarButtonItem {
            navigationItem.leftBarButtonItems = [originalLeftButton, prevButton]
        } else {
            navigationItem.leftBarButtonItem = prevButton
        }
        
        // 右箭头放在右侧
        navigationItem.rightBarButtonItem = nextButton
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func returnToScreenshotCenterTapped() {
        HapticFeedbackManager.shared.buttonTap()
        
        // 查找导航栈中的ScreenshotProcessingViewController
        guard let navigationController = navigationController else { return }
        
        let screenshotProcessingVC = navigationController.viewControllers.first { viewController in
            return viewController is ScreenshotProcessingViewController
        }
        
        if let targetVC = screenshotProcessingVC {
            // 如果找到截图中心，直接返回到那里
            navigationController.popToViewController(targetVC, animated: true)
        } else {
            // 如果没有找到，返回到上一级（批量修复页面）
            navigationController.popViewController(animated: true)
        }
    }
    
    @objc private func previousImageTapped() {
        guard let context = batchContext, context.currentIndex > 0 else { return }
        switchToImageAtIndex(context.currentIndex - 1)
    }
    
    @objc private func nextImageTapped() {
        guard let context = batchContext, context.currentIndex < context.items.count - 1 else { return }
        switchToImageAtIndex(context.currentIndex + 1)
    }
    
    // MARK: - Batch Navigation Implementation
    private func switchToImageAtIndex(_ newIndex: Int) {
        guard let context = batchContext,
              newIndex >= 0,
              newIndex < context.items.count else { return }
        
        HapticFeedbackManager.shared.selectionChanged()
        
        let newItem = context.items[newIndex]
        
        // 保存当前图片的修复结果（如果有的话）
        if let currentEnhanced = enhancedImage {
            context.onItemUpdated?(currentBatchIndex, currentEnhanced)
        }
        
        // 更新当前索引
        currentBatchIndex = newIndex
        
        // 更新批量上下文（创建新的上下文对象）
        batchContext = BatchContext(
            items: context.items,
            currentIndex: newIndex,
            enhanceLevel: context.enhanceLevel,
            onItemUpdated: context.onItemUpdated
        )
        
        // 更新UI内容
        updateContentForCurrentImage(newItem)
        
        // 更新导航栏
        updateNavigationForCurrentIndex()
        
        // 更新导航按钮状态
        updateNavigationButtonStates()
    }
    
    private func updateContentForCurrentImage(_ item: BatchEnhanceItem) {
        // 更新对比视图的原图
        comparisonView.setOriginalImage(item.originalImage)
        
        // 根据图片状态设置修复结果和来源类型
        if item.processingState == .completed, let enhancedImage = item.enhancedImage {
            // 已修复的图片
            sourceType = .fromBatchCompleted
            self.enhancedImage = enhancedImage
            comparisonView.setEnhancedImage(enhancedImage)
            
            // 启用保存和分享按钮
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
            shareButton.isEnabled = true
            shareButton.alpha = 1.0
            
        } else {
            // 未修复的图片
            sourceType = .fromBatch
            enhancedImage = nil
            comparisonView.resetToOriginalImage()
            
            // 禁用保存和分享按钮
            saveButton.isEnabled = false
            saveButton.alpha = 0.6
            shareButton.isEnabled = false
            shareButton.alpha = 0.6
        }
        
        // 更新状态标签
        updateStatusLabel()
        if sourceType == .fromBatchCompleted {
            updateBatchCompletedStatus()
        }
    }
    
    private func updateNavigationForCurrentIndex() {
        guard let context = batchContext else { return }
        
        let currentPosition = context.currentIndex + 1
        let totalCount = context.items.count
        
        if sourceType == .fromBatchCompleted {
            title = "第\(currentPosition)张/共\(totalCount)张 - 已修复"
        } else {
            title = "第\(currentPosition)张/共\(totalCount)张"
        }
    }
    
    private func updateNavigationButtonStates() {
        guard let context = batchContext else { return }
        
        // 🎯 更新对称布局的导航按钮状态
        // 左箭头按钮在左侧按钮组中
        if let leftBarButtonItems = navigationItem.leftBarButtonItems {
            for item in leftBarButtonItems {
                if item.image == UIImage(systemName: "chevron.left") {
                    item.isEnabled = context.currentIndex > 0
                }
            }
        }
        
        // 右箭头按钮在右侧
        if let rightBarButtonItem = navigationItem.rightBarButtonItem,
           rightBarButtonItem.image == UIImage(systemName: "chevron.right") {
            rightBarButtonItem.isEnabled = context.currentIndex < context.items.count - 1
        }
    }
    
    @objc private func resetButtonTapped() {
        enhancedImage = nil
        comparisonView.resetToOriginalImage()  // 重置为显示完整原图，避免黑屏问题
        
        saveButton.isEnabled = false
        saveButton.alpha = 0.6
        shareButton.isEnabled = false
        shareButton.alpha = 0.6
        
        statusLabel.text = "选择修复强度并点击应用修复"
        
        // 触觉反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func saveButtonTapped() {
        guard let enhanced = enhancedImage else { return }
        
        // 保存到相册并创建截图记录
        saveEnhancedImage(enhanced)
    }
    
    @objc private func shareButtonTapped() {
        guard let enhanced = enhancedImage else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        
        // 直接使用系统分享 Sheet
        let activityVC = UIActivityViewController(
            activityItems: [enhanced],
            applicationActivities: nil
        )
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    // MARK: - Save & Share
    private func saveEnhancedImage(_ image: UIImage) {
        // 请求相册权限
        requestPhotoLibraryPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.performSaveToPhotoLibrary(image)
                } else {
                    self?.showSaveErrorAlert(PhotoLibraryError.permissionDenied)
                }
            }
        }
    }
    
    private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                completion(newStatus == .authorized || newStatus == .limited)
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func performSaveToPhotoLibrary(_ image: UIImage) {
        // 显示保存进度
        let alertController = UIAlertController(title: "保存中", message: "正在保存图片到相册...", preferredStyle: .alert)
        present(alertController, animated: true)
        
        // 保存到系统相册
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
        // 异步保存到应用文件系统作为备份
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.saveToFileSystem(image)
        }
        
        // 延迟关闭进度提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            alertController.dismiss(animated: true)
        }
    }
    
    private func saveToFileSystem(_ image: UIImage) {
        do {
            let fileName = "enhanced_\(Date().timeIntervalSince1970).jpg"
            let imageURL = FileManagerHelper.screenshotsDirectory.appendingPathComponent(fileName)
            
            guard let imageData = image.jpegData(compressionQuality: 0.95) else {
                return
            }
            
            try imageData.write(to: imageURL)
            
            // 创建截图记录
            // TODO: 关联到对应的VideoItem
            
        } catch {
            print("❌ 保存到文件系统失败: \(error.localizedDescription)")
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showSaveErrorAlert(error)
        } else {
            showSaveSuccessAlert()
            // 成功触觉反馈
            HapticFeedbackManager.shared.notificationSuccess()
        }
    }
    
    private func showSaveSuccessAlert() {
        let alert = UIAlertController(title: "保存成功", message: "图片已保存到相册", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showSaveErrorAlert(_ error: Error) {
        let message: String
        if error is PhotoLibraryError {
            message = "需要相册访问权限才能保存图片，请在设置中允许访问相册"
        } else {
            message = error.localizedDescription
        }
        
        let alert = UIAlertController(title: "保存失败", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
        
        // 错误触觉反馈
        HapticFeedbackManager.shared.notificationError()
    }
    
    private func showErrorAlert(_ error: ImageEnhancementError) {
        let alert = UIAlertController(title: "处理失败", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
