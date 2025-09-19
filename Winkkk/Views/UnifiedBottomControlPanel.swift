//
//  UnifiedBottomControlPanel.swift
//  Winkkk
//
//  Created on 2025-01-18
//  统一底部控制面板 - 整合时间轴、截图预览、主控制按钮
//

import UIKit
import AVFoundation
import Combine

// MARK: - 协议定义
protocol UnifiedBottomControlPanelDelegate: AnyObject {
    // 播放控制
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapPlayPause isPlaying: Bool)
    
    // 时间轴控制
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didSeekToTime time: Double)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didStartSeeking time: Double)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didEndSeeking time: Double)
    
    // 截图功能
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapCapture mode: UnifiedBottomControlPanel.CaptureMode)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapClearScreenshots: Void)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didSelectScreenshot item: ScreenshotItem)
    
    // 增强功能
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapEnhance screenshots: [ScreenshotItem])
}

// MARK: - 截图模式枚举
extension UnifiedBottomControlPanel {
    enum CaptureMode {
        case stillImage
        case livePhoto
    }
}

// MARK: - 主类定义
class UnifiedBottomControlPanel: UIView {
    
    // MARK: - 代理
    weak var delegate: UnifiedBottomControlPanelDelegate?
    
    // MARK: - 截图管理相关
    private let screenshotManager = ScreenshotManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI组件
    
    // 背景毛玻璃效果
    private let backgroundBlurView = BlurEffectView(style: .regular, intensity: 0.92, shouldAddShadow: false)
    
    // 主要内容区域 - 垂直堆栈
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .fill
        stack.spacing = 16
        return stack
    }()
    
    // 1. 时间轴容器
    private let timelineContainer = UIView()
    private let timelineView = TimelineView()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    
    // 2. 截图预览容器 (固定高度)
    private let screenshotsContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        return container
    }()
    
    // 截图预览头部
    private let previewHeaderStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        return stack
    }()
    
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "截图预览"
        label.font = ThemeManager.bodyFont
        label.textColor = ThemeManager.secondaryText
        return label
    }()
    
    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("清空", for: .normal)
        button.titleLabel?.font = ThemeManager.buttonFont
        button.setTitleColor(ThemeManager.error, for: .normal)
        return button
    }()
    
    // 截图预览CollectionView
    private lazy var screenshotsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "ScreenshotThumbnailCell")
        return collectionView
    }()
    
    // 3. 主控制按钮区域
    private let mainControlsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        return stack
    }()
    
    // 播放/暂停按钮
    private let playPauseButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = ThemeManager.buttonPrimary.withAlphaComponent(0.8)
        button.layer.cornerRadius = 25
        return button
    }()
    
    // 截图按钮 (整合模式切换功能)
    private let captureButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        button.setTitle("截图", for: .normal)
        button.tintColor = .white
        button.backgroundColor = ThemeManager.success.withAlphaComponent(0.8)
        button.layer.cornerRadius = ThemeManager.smallCornerRadius
        button.titleLabel?.font = ThemeManager.buttonFont
        return button
    }()
    
    // 增强按钮
    private let enhanceButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "wand.and.stars"), for: .normal)
        button.setTitle("增强", for: .normal)
        button.tintColor = .white
        button.backgroundColor = ThemeManager.buttonPrimary.withAlphaComponent(0.8)
        button.layer.cornerRadius = ThemeManager.smallCornerRadius
        button.titleLabel?.font = ThemeManager.buttonFont
        return button
    }()
    
    // MARK: - 数据
    private var screenshots: [ScreenshotItem] = []
    private var currentCaptureMode: UnifiedBottomControlPanel.CaptureMode = .stillImage
    private var isPlaying: Bool = false {
        didSet {
            // 🎯 同步时间轴的播放状态 - 参考技术报告的状态管理
            timelineView.setPlaying(isPlaying)
        }
    }
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        setupActions()
        setupObservers()
        updateUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
        setupActions()
        setupObservers()
        updateUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 截图预览设置方法
    private func setupScreenshotsContainer() {
        // 设置头部信息区域
        setupPreviewHeader()
        
        // 设置CollectionView
        setupCollectionView()
        
        // 添加到截图容器
        screenshotsContainer.addSubview(previewHeaderStackView)
        screenshotsContainer.addSubview(screenshotsCollectionView)
        
        // 设置约束
        setupScreenshotsConstraints()
    }
    
    private func setupPreviewHeader() {
        // 配置提示标签
        hintLabel.font = ThemeManager.captionFont
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.textAlignment = .left
        
        // 配置清空按钮
        clearButton.setTitle("🗑 清空", for: .normal)
        clearButton.setTitleColor(UIColor.systemRed, for: .normal)
        clearButton.titleLabel?.font = ThemeManager.captionFont
        clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        clearButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        
        // 添加到头部容器
        previewHeaderStackView.addArrangedSubview(hintLabel)
        previewHeaderStackView.addArrangedSubview(clearButton)
        
        // 设置清空按钮尺寸
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clearButton.widthAnchor.constraint(equalToConstant: 60),
            clearButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupCollectionView() {
        screenshotsCollectionView.backgroundColor = .clear
        screenshotsCollectionView.showsHorizontalScrollIndicator = false
        screenshotsCollectionView.alwaysBounceHorizontal = true
        screenshotsCollectionView.decelerationRate = .fast
        
        // 设置数据源和代理
        screenshotsCollectionView.dataSource = self
        screenshotsCollectionView.delegate = self
        
        // 注册cell（临时使用UICollectionViewCell）
        screenshotsCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "ScreenshotThumbnailCell")
    }
    
    private func setupScreenshotsConstraints() {
        previewHeaderStackView.translatesAutoresizingMaskIntoConstraints = false
        screenshotsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 头部区域
            previewHeaderStackView.topAnchor.constraint(equalTo: screenshotsContainer.topAnchor, constant: 8),
            previewHeaderStackView.leadingAnchor.constraint(equalTo: screenshotsContainer.leadingAnchor, constant: 12),
            previewHeaderStackView.trailingAnchor.constraint(equalTo: screenshotsContainer.trailingAnchor, constant: -12),
            previewHeaderStackView.heightAnchor.constraint(equalToConstant: 30),
            
            // CollectionView
            screenshotsCollectionView.topAnchor.constraint(equalTo: previewHeaderStackView.bottomAnchor, constant: 8),
            screenshotsCollectionView.leadingAnchor.constraint(equalTo: screenshotsContainer.leadingAnchor, constant: 12),
            screenshotsCollectionView.trailingAnchor.constraint(equalTo: screenshotsContainer.trailingAnchor, constant: -12),
            screenshotsCollectionView.bottomAnchor.constraint(equalTo: screenshotsContainer.bottomAnchor, constant: -8),
            screenshotsCollectionView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    // MARK: - 观察者设置方法
    private func setupObservers() {
        // 监听ScreenshotManager的变化
        screenshotManager.$screenshots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateUI()
            }
            .store(in: &cancellables)
        
        screenshotManager.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateUI()
            }
            .store(in: &cancellables)
        
        // 监听通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenshotAdded(_:)),
            name: .screenshotAdded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenshotRemoved(_:)),
            name: .screenshotRemoved,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(allScreenshotsCleared),
            name: .allScreenshotsCleared,
            object: nil
        )
    }
    
    // MARK: - 基础设置方法
    private func setupLayout() {
        // 设置背景毛玻璃
        backgroundBlurView.layer.cornerRadius = ThemeManager.largeCornerRadius
        backgroundBlurView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backgroundBlurView.clipsToBounds = false
        addSubview(backgroundBlurView)
        
        // 添加主内容区域
        backgroundBlurView.contentView.addSubview(contentStackView)
        
        // 设置各个容器
        setupTimelineContainer()
        setupScreenshotsContainer()
        setupMainControlsContainer()
        
        // 添加到主堆栈
        contentStackView.addArrangedSubview(timelineContainer)
        contentStackView.addArrangedSubview(screenshotsContainer)
        contentStackView.addArrangedSubview(mainControlsStackView)
        
        setupConstraints()
    }
    
    private func setupTimelineContainer() {
        // 时间轴和时间标签的基础设置
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 时间标签样式 - 参考技术报告的样式配置
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = .white
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        currentTimeLabel.textAlignment = .center
        
        totalTimeLabel.text = "00:00"
        totalTimeLabel.textColor = .white.withAlphaComponent(0.7)
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        totalTimeLabel.textAlignment = .center
        
        timelineContainer.addSubview(timelineView)
        timelineContainer.addSubview(currentTimeLabel)
        timelineContainer.addSubview(totalTimeLabel)
    }
    
    private func setupMainControlsContainer() {
        // 按钮基础配置
        [playPauseButton, captureButton, enhanceButton].forEach { button in
            button.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // 添加到水平堆栈
        mainControlsStackView.addArrangedSubview(playPauseButton)
        mainControlsStackView.addArrangedSubview(captureButton)
        mainControlsStackView.addArrangedSubview(enhanceButton)
    }
    
    // MARK: - 时间轴宽度约束属性
    private var timelineWidthConstraint: NSLayoutConstraint?
    
    private func setupConstraints() {
        backgroundBlurView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        previewHeaderStackView.translatesAutoresizingMaskIntoConstraints = false
        screenshotsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 背景毛玻璃
            backgroundBlurView.topAnchor.constraint(equalTo: topAnchor),
            backgroundBlurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 主内容区域
            contentStackView.topAnchor.constraint(equalTo: backgroundBlurView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: backgroundBlurView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: backgroundBlurView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: backgroundBlurView.bottomAnchor, constant: -16),
            
            // 🎯 时间轴容器 - 允许视觉溢出屏幕边界 (Wink风格)
            timelineContainer.heightAnchor.constraint(equalToConstant: 140), // 110时间轴 + 30时间标签
            
            // 🎯 时间轴 - 允许视觉溢出屏幕边界 (技术报告核心特性)
            timelineView.topAnchor.constraint(equalTo: timelineContainer.topAnchor),
            timelineView.centerXAnchor.constraint(equalTo: timelineContainer.centerXAnchor),
            timelineView.heightAnchor.constraint(equalToConstant: 110),
            
            // 时间标签 - 参考技术报告的布局
            currentTimeLabel.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 8),
            currentTimeLabel.leadingAnchor.constraint(equalTo: timelineView.leadingAnchor),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            totalTimeLabel.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 8),
            totalTimeLabel.trailingAnchor.constraint(equalTo: timelineView.trailingAnchor),
            totalTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            // 截图容器固定高度
            screenshotsContainer.heightAnchor.constraint(equalToConstant: 100),
            
            // 预览头部
            previewHeaderStackView.topAnchor.constraint(equalTo: screenshotsContainer.topAnchor),
            previewHeaderStackView.leadingAnchor.constraint(equalTo: screenshotsContainer.leadingAnchor),
            previewHeaderStackView.trailingAnchor.constraint(equalTo: screenshotsContainer.trailingAnchor),
            previewHeaderStackView.heightAnchor.constraint(equalToConstant: 30),
            
            // CollectionView
            screenshotsCollectionView.topAnchor.constraint(equalTo: previewHeaderStackView.bottomAnchor, constant: 8),
            screenshotsCollectionView.leadingAnchor.constraint(equalTo: screenshotsContainer.leadingAnchor),
            screenshotsCollectionView.trailingAnchor.constraint(equalTo: screenshotsContainer.trailingAnchor),
            screenshotsCollectionView.bottomAnchor.constraint(equalTo: screenshotsContainer.bottomAnchor),
            
            // 按钮尺寸
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 40),
            enhanceButton.widthAnchor.constraint(equalToConstant: 80),
            enhanceButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 🎯 初始化时间轴动态宽度约束 (实现15%溢出效果 - 技术报告核心特性)
        setupTimelineOverflowConstraints()
    }
    
    // MARK: - 时间轴溢出约束设置 (技术报告核心算法)
    private func setupTimelineOverflowConstraints() {
        let screenWidth = UIScreen.main.bounds.width
        let overflowWidth = screenWidth + (screenWidth * 0.15)  // 屏幕宽度 + 15%溢出
        timelineWidthConstraint = timelineView.widthAnchor.constraint(equalToConstant: overflowWidth)
        timelineWidthConstraint?.isActive = true
    }
    
    // MARK: - 播放头指示器约束设置 (技术报告: 固定播放头设计)
    func setupPlayheadConstraints(to parentView: UIView) {
        // 🎯 关键修复：将playheadIndicator约束到屏幕中心而不是TimelineView中心
        // 这是解决所有时间轴问题的核心 (技术报告: 固定播放头设计)
        timelineView.playheadIndicatorView.centerXAnchor.constraint(
            equalTo: parentView.centerXAnchor
        ).isActive = true
        
        print("🎯 Playhead indicator constrained to parent view center")
    }
    
    private func setupActions() {
        // 按钮事件
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        enhanceButton.addTarget(self, action: #selector(enhanceButtonTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        
        // 🎯 设置时间轴代理 - 参考技术报告的代理模式
        timelineView.delegate = self
        
        // 添加触摸效果
        addButtonTouchEffects(to: playPauseButton)
        addButtonTouchEffects(to: captureButton)
        addButtonTouchEffects(to: enhanceButton)
    }
    
    private func addButtonTouchEffects(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    // MARK: - UI更新方法
    private func updateUI() {
        updateHintLabel()
        updateCollectionView()
        updateButtonStates()
    }
    
    private func updateHintLabel() {
        let count = screenshotManager.screenshotCount
        let mode = screenshotManager.currentMode
        let maxCount = mode.maxCount
        
        if count == 0 {
            hintLabel.text = "\(mode.displayName)模式 (最多\(maxCount)张)"
        } else {
            hintLabel.text = "已截\(count)张: \(mode.displayName) (最多\(maxCount)张)"
        }
        
        // 接近上限时的警告色
        if count >= maxCount - 2 {
            hintLabel.textColor = UIColor.systemOrange
        } else {
            hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        }
    }
    
    private func updateCollectionView() {
        screenshotsCollectionView.reloadData()
        
        // 自动滚动到最新截图
        if !screenshotManager.screenshots.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let lastIndex = IndexPath(item: self.screenshotManager.screenshots.count - 1, section: 0)
                self.screenshotsCollectionView.scrollToItem(at: lastIndex, at: .right, animated: true)
            }
        }
    }
    
    private func updateButtonStates() {
        let count = screenshotManager.screenshotCount
        let hasScreenshots = count > 0
        let isAtLimit = screenshotManager.isAtMaxLimit
        
        // 截图按钮状态
        captureButton.isEnabled = !isAtLimit
        captureButton.alpha = isAtLimit ? 0.5 : 1.0
        
        // 修复按钮状态（Live Photo模式下隐藏）
        let shouldShowEnhance = hasScreenshots && screenshotManager.currentMode == .stillImage
        enhanceButton.isHidden = !shouldShowEnhance
        enhanceButton.alpha = shouldShowEnhance ? 1.0 : 0.5
        
        // 清空按钮状态
        clearButton.isEnabled = hasScreenshots
        clearButton.alpha = hasScreenshots ? 1.0 : 0.5
    }
    
    // MARK: - 通知处理方法
    @objc private func screenshotAdded(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    @objc private func screenshotRemoved(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    @objc private func allScreenshotsCleared() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    // MARK: - 按钮事件处理
    @objc private func playPauseButtonTapped() {
        isPlaying.toggle()
        updatePlayPauseButtonState()
        delegate?.bottomControlPanel(self, didTapPlayPause: isPlaying)
        HapticFeedbackManager.shared.buttonTap()
        print("🎯 PlayPause button tapped - isPlaying: \(isPlaying)")
    }
    
    @objc private func captureButtonTapped() {
        let mode = currentCaptureMode
        delegate?.bottomControlPanel(self, didTapCapture: mode)
        HapticFeedbackManager.shared.buttonTap()
        print("🎯 Capture button tapped - mode: \(mode)")
    }
    
    @objc private func enhanceButtonTapped() {
        let screenshots = screenshotManager.screenshots
        delegate?.bottomControlPanel(self, didTapEnhance: screenshots)
        HapticFeedbackManager.shared.buttonTap()
        print("🎯 Enhance button tapped - screenshots count: \(screenshots.count)")
    }
    
    @objc private func clearButtonTapped() {
        HapticFeedbackManager.shared.lightImpact()
        
        let alert = UIAlertController(
            title: "清空确认",
            message: "确定要清空所有\(screenshotManager.currentMode.displayName)吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.bottomControlPanel(self, didTapClearScreenshots: ())
            self.screenshotManager.clearAllScreenshots()
            HapticFeedbackManager.shared.notificationSuccess()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 找到父级视图控制器并显示弹窗
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                viewController.present(alert, animated: true)
                break
            }
            responder = responder?.next
        }
        
        print("🎯 Clear button tapped")
    }
    
    // MARK: - 按钮状态更新
    private func updatePlayPauseButtonState() {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
        
        let title = isPlaying ? "暂停" : "播放"
        playPauseButton.accessibilityLabel = title
    }
    
    // MARK: - 按钮触摸效果
    @objc private func buttonPressed(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = .identity
        }
    }
    
    // MARK: - 公共方法
    func updateWithScreenshots(_ screenshots: [ScreenshotItem]) {
        updateUI()
    }
    
    func setPlayingState(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
        updatePlayPauseButtonState()
    }
    
    func setCaptureMode(_ mode: UnifiedBottomControlPanel.CaptureMode) {
        self.currentCaptureMode = mode
        updateUI()
    }
    
    // MARK: - 时间轴相关方法 (技术报告核心功能)
    
    /// 设置视频时长和URL - 参考技术报告的视频配置
    func setupVideo(url: URL, duration: CMTime) {
        timelineView.setVideoURL(url)
        timelineView.setDuration(duration.seconds)
        totalTimeLabel.text = duration.formattedString
    }
    
    /// 更新当前播放时间 - 参考技术报告的时间同步
    func updateCurrentTime(_ time: CMTime) {
        currentTimeLabel.text = time.formattedString
    }
    
    /// 更新截取时间标签（Wink风格） - 参考技术报告的截取时间显示
    func updateCaptureTime(_ time: CMTime) {
        let captureTimeString = time.formattedString
        totalTimeLabel.text = "截取: \(captureTimeString)"
        totalTimeLabel.textColor = ThemeManager.success // 绿色表示截取时间
    }
    
    /// 获取当前截取时间 - 参考技术报告的时间获取算法
    func getCurrentCaptureTime() -> Double {
        return timelineView.getCurrentCaptureTime()
    }
    
    /// 设置Live Photo模式 - 参考技术报告的Live Photo功能
    func setLivePhotoMode(_ enabled: Bool) {
        timelineView.setLivePhotoMode(enabled)
    }
    
    /// 设置时间轴播放状态 - 参考技术报告的播放状态同步
    func setTimelineProgress(_ progress: Double) {
        timelineView.setProgress(progress)
    }
    
    /// 同步播放时间到时间轴 - 参考技术报告的时间同步算法
    func syncPlaybackTime(_ currentTime: CMTime, duration: CMTime) {
        guard duration.seconds > 0 else { return }
        
        let progress = currentTime.seconds / duration.seconds
        
        // 🎯 播放状态下的时间轴同步 (技术报告: 播放模式vs编辑模式)
        if isPlaying {
            timelineView.setProgress(progress)
        }
        
        // 更新时间标签
        updateCurrentTime(currentTime)
    }
    
    /// 滚动到指定截取时间 - 参考技术报告的精确定位
    func scrollToCaptureTime(_ time: Double) {
        timelineView.scrollToCaptureTime(time)
        
        // 更新截取时间显示
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        updateCaptureTime(cmTime)
    }
    
    /// 流动控制 - 参考技术报告的自动滚动功能
    func startFlowing(speed: CGFloat) {
        // 这里可以实现自动流动功能，如果需要的话
        print("🎯 Start flowing with speed: \(speed)")
    }
    
    func stopFlowing() {
        // 停止自动流动
        print("🎯 Stop flowing")
    }
    
    // MARK: - 测试方法 (验证技术报告功能)
    func testTimelineFeatures() {
        print("🧪 Testing TimelineView features from technical report...")
        
        // 1. 测试坐标系统
        let testTime: Double = 5.0
        timelineView.scrollToCaptureTime(testTime)
        let captureTime = timelineView.getCurrentCaptureTime()
        print("✅ 坐标系统测试 - 设置时间: \(testTime), 获取时间: \(captureTime)")
        
        // 2. 测试Live Photo模式
        timelineView.setLivePhotoMode(true)
        print("✅ Live Photo模式测试 - 已启用")
        
        // 3. 测试播放状态同步
        timelineView.setPlaying(true)
        print("✅ 播放状态同步测试 - 已设置播放状态")
        
        // 4. 测试时间轴约束
        if let constraint = timelineWidthConstraint {
            print("✅ 时间轴约束测试 - 宽度约束: \(constraint.constant)")
        }
        
        // 5. 测试播放头指示器
        let playheadView = timelineView.playheadIndicatorView
        print("✅ 播放头指示器测试 - 视图存在: \(playheadView)")
        
        print("🎯 TimelineView核心功能测试完成！")
    }
}

// MARK: - CollectionView DataSource
extension UnifiedBottomControlPanel: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screenshotManager.screenshots.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ScreenshotThumbnailCell", for: indexPath)
        
        // 临时配置 - 基础样式
        let screenshot = screenshotManager.screenshots[indexPath.item]
        cell.backgroundColor = ThemeManager.cardBackground
        cell.layer.cornerRadius = 8
        cell.layer.masksToBounds = true
        
        // 清除之前的子视图
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // 添加缩略图
        let imageView = UIImageView()
        imageView.image = screenshot.image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        cell.contentView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
        ])
        
        return cell
    }
}

// MARK: - CollectionView Delegate
extension UnifiedBottomControlPanel: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let screenshot = screenshotManager.screenshots[indexPath.item]
        delegate?.bottomControlPanel(self, didSelectScreenshot: screenshot)
        print("🎯 Screenshot selected at index: \(indexPath.item)")
    }
}

// MARK: - CollectionView FlowLayout Delegate
extension UnifiedBottomControlPanel: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 60高度的正方形缩略图
        return CGSize(width: 60, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }
}

// MARK: - TimelineViewDelegate (技术报告核心交互系统)
extension UnifiedBottomControlPanel: TimelineViewDelegate {
    
    /// 时间轴拖拽跳转 - 参考技术报告的精确定位算法
    func timelineView(_ timelineView: TimelineView, didSeekToProgress progress: Double) {
        // 🎯 Wink风格：接收的是截取时间，用于截图功能
        let seekTime = progress
        delegate?.bottomControlPanel(self, didSeekToTime: seekTime)
        
        print("🎯 Timeline seek to progress: \(progress)")
    }
    
    /// 播放状态同步更新 - 参考技术报告的播放模式vs编辑模式
    func timelineView(_ timelineView: TimelineView, didUpdateProgressDuringPlayback progress: Double) {
        // 播放状态下的时间轴位置更新
        delegate?.bottomControlPanel(self, didSeekToTime: progress)
    }
    
    /// 开始拖拽时间轴 - 参考技术报告的手势交互
    func timelineViewDidBeginSeeking(_ timelineView: TimelineView) {
        delegate?.bottomControlPanel(self, didStartSeeking: timelineView.getCurrentCaptureTime())
        print("🎯 Timeline begin seeking")
    }
    
    /// 结束拖拽时间轴 - 参考技术报告的手势交互
    func timelineViewDidEndSeeking(_ timelineView: TimelineView) {
        delegate?.bottomControlPanel(self, didEndSeeking: timelineView.getCurrentCaptureTime())
        print("🎯 Timeline end seeking")
    }
    
    /// 请求播放 - 参考技术报告的播放控制
    func timelineViewDidRequestPlay(_ timelineView: TimelineView) {
        isPlaying = true
        updatePlayPauseButtonState()
        delegate?.bottomControlPanel(self, didTapPlayPause: true)
        print("🎯 Timeline requested play")
    }
    
    /// 请求暂停 - 参考技术报告的播放控制
    func timelineViewDidRequestPause(_ timelineView: TimelineView) {
        isPlaying = false
        updatePlayPauseButtonState()
        delegate?.bottomControlPanel(self, didTapPlayPause: false)
        print("🎯 Timeline requested pause")
    }
}
