//
//  VideoPlayerViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频播放编辑视图控制器 - AVPlayer集成和自定义控件
//

import UIKit
import AVFoundation
import Combine

// 🎯 流动速度控制枚举
enum FlowSpeed {
    case precise    // 0.5x - 精确模式
    case standard   // 1.0x - 标准模式  
    case browse     // 1.5x - 浏览模式
    
    var multiplier: Double {
        switch self {
        case .precise: return 0.5
        case .standard: return 1.0
        case .browse: return 1.5
        }
    }
    
    var displayName: String {
        switch self {
        case .precise: return "精确模式"
        case .standard: return "标准模式"
        case .browse: return "浏览模式"
        }
    }
}

class VideoPlayerViewController: UIViewController {
    
    // MARK: - Properties
    private let videoURL: URL
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeObserverToken: Any?
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let playerContainerView = UIView()
    
    // 🆕 统一毛玻璃容器 - 包含控制面板+截图预览栏
    private let unifiedControlPanelView = BlurEffectView(style: .regular, intensity: 0.92, shouldAddShadow: false)
    private let controlPanelBlurView = BlurEffectView(style: .regular, intensity: 0.9)  // 保留作为内容容器
    
    // 播放控制
    private let playPauseButton = UIButton()
    private let timelineView = TimelineView()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    
    // 截图按钮
    private let screenshotButton = UIButton()
    
    // 🆕 多图截取系统组件
    private let captureModeSwitcher = CaptureModeSwitcher()
    private let screenshotPreviewBar = ScreenshotPreviewBar()
    
    // 🆕 批量操作面板 - 已移除，功能集成到ScreenshotPreviewBar中
    
    // 🆕 多选状态管理
    private var isInSelectionMode = false {
        didSet {
            updateSelectionModeUI()
        }
    }
    private var selectedScreenshots: Set<ScreenshotItem> = [] {
        didSet {
            updateSelectionCountLabel()
        }
    }
    
    // 状态变量 - 🎯 编辑器模式重构
    private var isFlowing = false {  // 从isPlaying改为isFlowing
        didSet {
            updatePlayPauseButton()
        }
    }

    private var videoDuration: CMTime = .zero
    private var currentTime: CMTime = .zero
    
    // 🎯 流动控制参数
    private var flowTimer: Timer?
    private var currentFlowSpeed: FlowSpeed = .standard
    
    // 🎯 实时预览控制参数
    private var previewUpdateTimer: Timer?
    private let previewUpdateInterval: TimeInterval = 1.0/30.0  // 30fps限制
    private var lastPreviewUpdateTime: TimeInterval = 0
    
    // 🎯 响应式布局约束
    // private var controlPanelHeightConstraint: NSLayoutConstraint? // 三分屏布局使用比例约束，不需要动态高度
    private var timelineWidthConstraint: NSLayoutConstraint?  // 动态宽度约束
    
    // MARK: - Dependencies
    private let screenshotEngine = ScreenshotEngine()
    private let screenshotManager = ScreenshotManager.shared
    
    // 🆕 Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupPlayer()
        setupTimelineView()
        setupMultiScreenshotSystem()  // 🆕 新增
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pausePlayer()
    }
    
    deinit {
        cleanupPlayer()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 播放器容器
        playerContainerView.backgroundColor = .black
        playerContainerView.layer.cornerRadius = ThemeManager.standardCornerRadius
        playerContainerView.layer.masksToBounds = true
        view.addSubview(playerContainerView)
        
        // 控制面板
        setupControlPanel()
        
        // 🆕 多图截取系统组件
        setupCaptureModeSwitcher()
        setupScreenshotPreviewBar()
        
        // 🆕 批量操作功能已集成到ScreenshotPreviewBar中
        
        // 导航栏
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        title = "视频编辑"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
    }
    
    private func setupControlPanel() {
        // 🆕 设置统一毛玻璃容器
        unifiedControlPanelView.layer.cornerRadius = ThemeManager.largeCornerRadius
        unifiedControlPanelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        unifiedControlPanelView.clipsToBounds = false
        view.addSubview(unifiedControlPanelView)
        
        // 控制面板内容容器 - 透明背景
        controlPanelBlurView.backgroundColor = .clear
        controlPanelBlurView.layer.cornerRadius = 0
        controlPanelBlurView.clipsToBounds = false
        unifiedControlPanelView.contentView.addSubview(controlPanelBlurView)
        
        // 播放/暂停按钮
        setupPlayPauseButton()
        
        // 截图按钮
        setupScreenshotButton()
        
        // 时间标签
        setupTimeLabels()
        
        // 添加到控制面板 - 🔧 时间轴放在最下层，避免遮挡按钮
        controlPanelBlurView.contentView.addSubview(timelineView)
        controlPanelBlurView.contentView.addSubview(currentTimeLabel)
        controlPanelBlurView.contentView.addSubview(totalTimeLabel)
        controlPanelBlurView.contentView.addSubview(playPauseButton)
        controlPanelBlurView.contentView.addSubview(screenshotButton)
    }
    
    private func setupPlayPauseButton() {
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = ThemeManager.buttonPrimary.withAlphaComponent(0.8)
        playPauseButton.layer.cornerRadius = 25
        
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        playPauseButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    private func setupScreenshotButton() {
        screenshotButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        screenshotButton.setTitle("截图", for: .normal)
        screenshotButton.tintColor = .white
        screenshotButton.backgroundColor = ThemeManager.success.withAlphaComponent(0.8)
        screenshotButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        screenshotButton.titleLabel?.font = ThemeManager.buttonFont
        
        // 🔧 确保按钮可交互
        screenshotButton.isUserInteractionEnabled = true
        screenshotButton.isHidden = false
        screenshotButton.alpha = 1.0
        
        // 设置图文布局
        screenshotButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        screenshotButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        
        screenshotButton.addTarget(self, action: #selector(screenshotButtonTapped), for: .touchUpInside)
        screenshotButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        screenshotButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
        
        // 🎯 关键修复：优化按钮触摸响应
        screenshotButton.isUserInteractionEnabled = true
        screenshotButton.isExclusiveTouch = true  // 独占触摸，防止手势干扰
        screenshotButton.layer.zPosition = 1000  // 确保在最顶层
        
        print("🔧 截图按钮设置完成 - 可交互: \(screenshotButton.isUserInteractionEnabled), 可见: \(!screenshotButton.isHidden), 独占触摸: \(screenshotButton.isExclusiveTouch)")
    }
    
    private func setupTimeLabels() {
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = .white
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        currentTimeLabel.textAlignment = .center
        
        totalTimeLabel.text = "00:00"
        totalTimeLabel.textColor = .white.withAlphaComponent(0.7)
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        totalTimeLabel.textAlignment = .center
    }
    
    private func setupConstraints() {
        // 🔧 关键修复：确保所有视图都禁用自动布局掩码
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        unifiedControlPanelView.translatesAutoresizingMaskIntoConstraints = false  // 🚨 关键修复
        controlPanelBlurView.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        screenshotButton.translatesAutoresizingMaskIntoConstraints = false
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 🎯 三分屏布局：视频区域 (53.3%)
            playerContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            playerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            playerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            playerContainerView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.533),
            
            // 🎯 统一毛玻璃容器 - 包含控制面板+模式切换器+截图预览栏
            unifiedControlPanelView.topAnchor.constraint(equalTo: playerContainerView.bottomAnchor, constant: 8),
            unifiedControlPanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            unifiedControlPanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            unifiedControlPanelView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            
            // 🎯 控制面板内容区域 - 在统一容器内部，使用弹性高度
            controlPanelBlurView.topAnchor.constraint(equalTo: unifiedControlPanelView.topAnchor),
            controlPanelBlurView.leadingAnchor.constraint(equalTo: unifiedControlPanelView.leadingAnchor),
            controlPanelBlurView.trailingAnchor.constraint(equalTo: unifiedControlPanelView.trailingAnchor),
            controlPanelBlurView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            
            // 🎯 时间轴 - 允许视觉溢出屏幕边界 (Wink风格)
            timelineView.topAnchor.constraint(equalTo: controlPanelBlurView.topAnchor, constant: 20),
            timelineView.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            timelineView.heightAnchor.constraint(equalToConstant: 110),
            
            // 时间标签
            currentTimeLabel.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 8),
            currentTimeLabel.leadingAnchor.constraint(equalTo: timelineView.leadingAnchor),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            totalTimeLabel.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 8),
            totalTimeLabel.trailingAnchor.constraint(equalTo: timelineView.trailingAnchor),
            totalTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            // 🎯 修复：播放和截图按钮与时间轴在同一水平区域，但固定在屏幕边界内
            // 播放按钮 - 位于屏幕左侧，与时间轴同一水平线
            playPauseButton.centerYAnchor.constraint(equalTo: timelineView.centerYAnchor),
            playPauseButton.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 20),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 截图按钮 - 位于屏幕右侧，与时间轴同一水平线
            screenshotButton.centerYAnchor.constraint(equalTo: timelineView.centerYAnchor),
            screenshotButton.trailingAnchor.constraint(equalTo: controlPanelBlurView.trailingAnchor, constant: -20),
            screenshotButton.widthAnchor.constraint(equalToConstant: 80),
            screenshotButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 🎯 初始化动态约束 - 三分屏布局不需要动态高度约束，使用比例约束
        // controlPanelHeightConstraint 现在由比例约束替代
        
        // 🎯 初始化时间轴动态宽度约束 (实现15%溢出效果)
        let screenWidth = UIScreen.main.bounds.width
        let overflowWidth = screenWidth + (screenWidth * 0.15)  // 屏幕宽度 + 15%溢出
        timelineWidthConstraint = timelineView.widthAnchor.constraint(equalToConstant: overflowWidth)
        timelineWidthConstraint?.isActive = true
        
        // 🎯 关键修复：将playheadIndicator约束到屏幕中心而不是TimelineView中心
        // 这是解决所有时间轴问题的核心
        timelineView.playheadIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        // 🆕 新组件约束
        setupNewComponentsConstraints()
    }
    
    private func setupNewComponentsConstraints() {
        captureModeSwitcher.translatesAutoresizingMaskIntoConstraints = false
        screenshotPreviewBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 🎯 统一容器内：模式切换器 - 无缝连接控制面板
            captureModeSwitcher.topAnchor.constraint(equalTo: controlPanelBlurView.bottomAnchor, constant: 0),
            captureModeSwitcher.centerXAnchor.constraint(equalTo: unifiedControlPanelView.centerXAnchor),
            captureModeSwitcher.heightAnchor.constraint(equalToConstant: 44),
            captureModeSwitcher.widthAnchor.constraint(equalToConstant: 280),
            
            // 🎯 统一容器内：截图预览栏 - 添加适当内边距，避免双重边界
            screenshotPreviewBar.topAnchor.constraint(equalTo: captureModeSwitcher.bottomAnchor, constant: 8),
            screenshotPreviewBar.leadingAnchor.constraint(equalTo: unifiedControlPanelView.leadingAnchor, constant: 16),
            screenshotPreviewBar.trailingAnchor.constraint(equalTo: unifiedControlPanelView.trailingAnchor, constant: -16)
        ])
        
        // 🔧 关键修复：使用优先级约束避免冲突，添加底部边距
        let bottomConstraint = screenshotPreviewBar.bottomAnchor.constraint(equalTo: unifiedControlPanelView.bottomAnchor, constant: -16)
        bottomConstraint.priority = UILayoutPriority(999)  // 高优先级但非必需
        bottomConstraint.isActive = true
        
        // 最小高度约束保证可用性
        let minHeightConstraint = screenshotPreviewBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        minHeightConstraint.priority = UILayoutPriority(1000)  // 必需约束
        minHeightConstraint.isActive = true
    }
    
    // MARK: - Player Setup
    private func setupPlayer() {
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // 创建播放器层
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = playerContainerView.bounds
        playerLayer?.videoGravity = .resizeAspect
        playerContainerView.layer.addSublayer(playerLayer!)
        
        // 监听播放状态
        setupPlayerObservers()
        
        // 获取视频信息
        loadVideoInfo()
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        // 播放时间观察者
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.1, preferredTimescale: timeScale)
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            self?.updatePlaybackTime(time)
        }
        
        // 播放结束通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        // 播放状态观察
        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
    }
    
    private func loadVideoInfo() {
        guard let player = player else { return }
        
        player.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let duration = player.currentItem?.asset.duration {
                    self.videoDuration = duration
                    self.totalTimeLabel.text = duration.formattedString
                    
                    // 设置时间轴
                    self.timelineView.setDuration(duration.seconds)
                }
            }
        }
    }
    
    private func setupTimelineView() {
        timelineView.delegate = self
        timelineView.setVideoURL(videoURL)
    }
    
    // MARK: - 🆕 多图截取系统设置
    private func setupCaptureModeSwitcher() {
        captureModeSwitcher.delegate = self
        captureModeSwitcher.backgroundColor = .clear  // 🆕 透明背景
        unifiedControlPanelView.contentView.addSubview(captureModeSwitcher)
    }
    
    private func setupScreenshotPreviewBar() {
        screenshotPreviewBar.delegate = self
        screenshotPreviewBar.isHidden = false  // 🎯 固定三分屏：底部区域始终显示
        screenshotPreviewBar.alpha = 1.0
        // 🆕 添加到统一容器中，而不是直接添加到view
        unifiedControlPanelView.contentView.addSubview(screenshotPreviewBar)
    }
    
    // setupBatchOperationPanel 已移除 - 功能集成到ScreenshotPreviewBar中
    
    // 批量操作UI设置方法已移除 - 功能集成到ScreenshotPreviewBar中
    
    private func addButtonTouchEffects(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    private func setupMultiScreenshotSystem() {
        // 设置初始模式
        captureModeSwitcher.setCurrentMode(CaptureMode.stillImage)
        
        // 订阅截图状态变化
        screenshotManager.$screenshots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] screenshots in
                self?.updatePreviewBarVisibility(screenshots: screenshots)
            }
            .store(in: &cancellables)
        
        // 订阅模式变化
        screenshotManager.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.updateTimelineForMode(mode)
            }
            .store(in: &cancellables)
    }
    
    private func updatePreviewBarVisibility(screenshots: [ScreenshotItem]) {
        // 🎯 固定三分屏设计：底部区域始终显示，不管是否有截图
        // 更新预览栏数据
        screenshotPreviewBar.updateWithScreenshots(screenshots)
        
        // 确保预览栏始终可见
        screenshotPreviewBar.isHidden = false
        screenshotPreviewBar.alpha = 1.0
        screenshotPreviewBar.transform = .identity
        
        if !screenshots.isEmpty {
            print("📸 截图已添加到预览栏 (固定三分屏底部区域)")
        } else {
            print("📸 预览栏已清空，但底部区域保持显示 (固定三分屏)")
        }
    }
    
    private func updateTimelineForMode(_ mode: CaptureMode) {
        switch mode {
        case .stillImage:
            // 普通截图模式：正常显示
            timelineView.setLivePhotoMode(false)
        case .livePhoto:
            // Live Photo模式：显示3秒范围指示
            timelineView.setLivePhotoMode(true)
        }
    }
    
    // MARK: - Flow Control (编辑器模式)
    @objc private func playPauseButtonTapped() {
        if isFlowing {
            stopFlowing()
        } else {
            startFlowing()
        }
    }
    
    // 🎯 开始内容流动 (Wink编辑器模式)
    private func startFlowing() {
        guard videoDuration.seconds > 0 else { return }
        
        // 计算流动速度 (像素/秒)
        let totalTimelineWidth = timelineView.timelineScrollView.contentSize.width
        let basePixelsPerSecond = totalTimelineWidth / CGFloat(videoDuration.seconds)
        let adjustedSpeed = basePixelsPerSecond * CGFloat(currentFlowSpeed.multiplier)
        
        // 启动定时器，让内容流动
        flowTimer?.invalidate()
        flowTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updateFlowPosition(speed: adjustedSpeed)
        }
        
        isFlowing = true
        print("🎯 开始内容流动 - 速度: \(currentFlowSpeed.displayName)")
    }
    
    // 🎯 停止内容流动
    private func stopFlowing() {
        flowTimer?.invalidate()
        flowTimer = nil
        isFlowing = false
        print("⏸️ 停止内容流动")
    }
    
    // 🎯 编辑器模式：暂停播放 = 停止流动
    private func pausePlayer() {
        stopFlowing()
        // 同时暂停视频播放
        player?.pause()
    }
    
    // 🎯 更新流动位置
    private func updateFlowPosition(speed: CGFloat) {
        let currentOffset = timelineView.timelineScrollView.contentOffset.x
        let newOffset = currentOffset + (speed / 30.0)  // 30fps
        let maxOffset = timelineView.timelineScrollView.contentSize.width - timelineView.timelineScrollView.bounds.width
        
        if newOffset >= maxOffset {
            // 流动到末尾，停止
            timelineView.timelineScrollView.setContentOffset(CGPoint(x: maxOffset, y: 0), animated: false)
            stopFlowing()
        } else {
            timelineView.timelineScrollView.setContentOffset(CGPoint(x: newOffset, y: 0), animated: false)
        }
    }
    
    private func seekToTime(_ time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateTimeLabels()
    }
    
    private func updatePlayPauseButton() {
        // 🎯 编辑器模式：流动控制而非播放控制
        let imageName = isFlowing ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
        
        // 更新按钮标题以体现流动功能
        let title = isFlowing ? "停止流动" : "开始流动"
        playPauseButton.accessibilityLabel = title
    }
    
    private func updatePlaybackTime(_ time: CMTime) {
        currentTime = time
        updateTimeLabels()
        
        // 🎯 编辑器模式：不再同步播放进度到时间轴
        // 时间轴现在只负责截取位置控制，不跟随播放进度
    }
    
    private func updateTimeLabels() {
        currentTimeLabel.text = currentTime.formattedString
    }
    
    // 🎯 更新截取时间标签（Wink风格）
    private func updateCaptureTimeLabel(_ captureTime: CMTime) {
        // 显示截取时间，区别于播放时间
        let captureTimeString = captureTime.formattedString
        // 可以考虑添加视觉提示，比如颜色区分
        totalTimeLabel.text = "截取: \(captureTimeString)"
        totalTimeLabel.textColor = ThemeManager.success // 绿色表示截取时间
    }
    
    // 🎯 实时视频预览更新（防抖优化）
    private func updateVideoPreview(to time: CMTime) {
        let currentTime = CACurrentMediaTime()
        
        // 防抖：避免过于频繁的更新
        guard currentTime - lastPreviewUpdateTime >= previewUpdateInterval else {
            return
        }
        
        lastPreviewUpdateTime = currentTime
        
        // 取消之前的定时器
        previewUpdateTimer?.invalidate()
        
        // 延迟更新，进一步防抖
        previewUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.performVideoSeek(to: time)
        }
    }
    
    // 🎯 执行视频帧跳转
    private func performVideoSeek(to time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            if completed {
                DispatchQueue.main.async {
                    self?.currentTime = time
                    // 只更新当前播放时间，不更新截取时间标签
                    self?.currentTimeLabel.text = time.formattedString
                }
            }
        }
    }
    
    // MARK: - Screenshot
    @objc private func screenshotButtonTapped() {
        print("📸 截图按钮被点击！")
        
        // 🎯 编辑器模式：停止流动以便精确截图
        stopFlowing()
        
        // 🎯 Wink风格：使用竖线位置的截取时间，而非当前播放时间
        let captureTime = timelineView.getCurrentCaptureTime()
        let cmCaptureTime = CMTime(seconds: captureTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        print("📸 准备截图 - 时间: \(captureTime)秒, CMTime: \(cmCaptureTime)")
        
        screenshotEngine.captureFrame(from: videoURL, at: cmCaptureTime) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self?.handleScreenshotSuccess(image)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    private func handleScreenshotSuccess(_ image: UIImage) {
        // 🎯 使用截取时间作为时间戳，而非播放时间
        let captureTime = timelineView.getCurrentCaptureTime()
        
        // 🆕 创建截图项目 - 使用正确的Core Data方式
        // 先临时创建一个VideoItem（后续优化为复用现有的）
        let tempVideoItem = PersistenceController.shared.createVideoItem(
            fileName: videoURL.lastPathComponent,
            filePath: videoURL,
            duration: 120.0, // TODO: 获取真实时长
            isFromCamera: false,
            width: Int32(image.size.width),
            height: Int32(image.size.height),
            fileSize: 0 // TODO: 获取真实文件大小
        )
        
        // 保存图片到临时路径（实际应用中应该保存到Documents目录）
        let tempImagePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("screenshot_\(UUID().uuidString).jpg")
        
        // 保存图片到文件系统
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            try? imageData.write(to: tempImagePath)
        }
        
        let screenshot = PersistenceController.shared.createScreenshotItem(
            originalImagePath: tempImagePath,
            timestamp: captureTime,
            width: Int32(image.size.width),
            height: Int32(image.size.height),
            originalFileSize: Int64(image.jpegData(compressionQuality: 0.9)?.count ?? 0),
            videoSource: tempVideoItem
        )
        
        do {
            // 添加到管理器
            try screenshotManager.addScreenshot(screenshot)
            
            // 触感反馈
            HapticFeedbackManager.shared.lightImpact()
            
            // 显示成功动画
            showScreenshotSuccessAnimation()
            
        } catch {
            // 处理错误（如数量超限、模式冲突等）
            handleScreenshotError(error)
        }
    }
    
    private func showScreenshotSuccessAnimation() {
        // 简单的成功动画
        UIView.animate(withDuration: 0.2, animations: {
            self.screenshotButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.screenshotButton.transform = .identity
            }
        }
    }
    
    private func handleScreenshotError(_ error: Error) {
        if let screenshotError = error as? ScreenshotSessionError {
            switch screenshotError {
            case .maxLimitReached(let mode, let count):
                showMaxLimitAlert()
            case .needConfirmation(let currentMode, let newMode, let currentCount):
                // 这种情况不应该在截图时发生
                break
            case .modeConflict(let expected, let actual):
                showModeConflictAlert()
            case .captureFailed(let reason):
                showAlert(title: "截图失败", message: reason)
            case .saveFailed(let reason):
                showAlert(title: "保存失败", message: reason)
            }
        } else {
            showError(error)
        }
    }
    
    private func showMaxLimitAlert() {
        let alert = UIAlertController(
            title: "截图数量已达上限",
            message: "最多只能截取20张图片。请先删除一些截图或切换到预览界面。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "查看截图", style: .default) { _ in
            // 进入多选模式查看所有截图
            self.enterSelectionMode()
            self.selectedScreenshots = Set(self.screenshotManager.screenshots)
            
            // 跳转到处理中心
            let screenshots = self.screenshotManager.screenshots
            let processingVC = ScreenshotProcessingViewController(
                screenshots: screenshots,
                mode: self.screenshotManager.currentMode
            )
            let navController = UINavigationController(rootViewController: processingVC)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showModeConflictAlert() {
        let alert = UIAlertController(
            title: "模式冲突",
            message: "截图失败，请检查当前模式设置。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        present(alert, animated: true)
    }
    
    private func showOperationHint() {
        // 🎯 固定三分屏模式：显示操作提示，不弹出界面
        print("💡 提示：长按截图进入多选模式，或点击右上角更多选项")
        
        // 可选：在底部区域显示简短的操作提示文字
        // 这里可以添加一个临时的提示标签，几秒后自动消失
        let hintLabel = UILabel()
        hintLabel.text = "长按截图进入多选模式"
        hintLabel.font = UIFont.systemFont(ofSize: 14)
        hintLabel.textColor = UIColor.secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.alpha = 0.0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            hintLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // 显示动画
        UIView.animate(withDuration: 0.3) {
            hintLabel.alpha = 1.0
        } completion: { _ in
            // 2秒后自动消失
            UIView.animate(withDuration: 0.3, delay: 2.0) {
                hintLabel.alpha = 0.0
            } completion: { _ in
                hintLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneButtonTapped() {
        // 保存当前编辑状态或其他操作
        dismiss(animated: true)
    }
    
    // MARK: - 批量操作按钮动作已移除 - 功能集成到ScreenshotPreviewBar中
    
    // MARK: - 🆕 多选状态管理方法
    private func updateSelectionModeUI() {
        // 更新缩略图栏的选择模式 - 批量操作UI已集成到ScreenshotPreviewBar中
        screenshotPreviewBar.setSelectionMode(isInSelectionMode)
    }
    
    private func updateSelectionCountLabel() {
        // 选择数量更新逻辑已集成到ScreenshotPreviewBar中
        let count = selectedScreenshots.count
        print("🔄 已选择 \(count) 张截图")
    }
    
    private func enterSelectionMode() {
        isInSelectionMode = true
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func exitSelectionMode() {
        isInSelectionMode = false
        selectedScreenshots.removeAll()
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func selectAll() {
        selectedScreenshots = Set(screenshotManager.screenshots)
        HapticFeedbackManager.shared.lightImpact()
        
        // 更新缩略图栏的选择状态
        screenshotPreviewBar.selectAllItems()
    }
    
    private func deselectAll() {
        selectedScreenshots.removeAll()
        HapticFeedbackManager.shared.lightImpact()
        
        // 更新缩略图栏的选择状态
        screenshotPreviewBar.deselectAllItems()
    }
    
    private func performBatchDelete() {
        let screenshotsToDelete = Array(selectedScreenshots)
        
        for screenshot in screenshotsToDelete {
            screenshotManager.removeScreenshot(screenshot)
        }
        
        exitSelectionMode()
        HapticFeedbackManager.shared.notificationSuccess()
    }
    
    private func toggleScreenshotSelection(_ screenshot: ScreenshotItem) {
        if selectedScreenshots.contains(screenshot) {
            selectedScreenshots.remove(screenshot)
        } else {
            selectedScreenshots.insert(screenshot)
        }
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func presentScreenshotViewSheet(_ screenshot: ScreenshotItem) {
        let viewSheet = ScreenshotViewSheet(screenshot: screenshot)
        viewSheet.modalPresentationStyle = .pageSheet
        
        // iOS 15+ 支持可调整高度
        if #available(iOS 15.0, *) {
            viewSheet.sheetPresentationController?.detents = [.medium(), .large()]
            viewSheet.sheetPresentationController?.prefersGrabberVisible = true
        }
        
        present(viewSheet, animated: true)
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func buttonPressed(_ button: UIButton) {
        if button == screenshotButton {
            print("🔧 截图按钮被按下")
        }
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = .identity
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        // 🎯 流动结束，重置到开始位置
        timelineView.timelineScrollView.setContentOffset(.zero, animated: true)
        isFlowing = false
    }
    
    // MARK: - Cleanup
    private func cleanupPlayer() {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        
        // 🎯 清理流动控制资源
        flowTimer?.invalidate()
        flowTimer = nil
        previewUpdateTimer?.invalidate()
        previewUpdateTimer = nil
        
        player?.removeObserver(self, forKeyPath: "timeControlStatus")
        NotificationCenter.default.removeObserver(self)
        
        player?.pause()
        playerLayer?.removeFromSuperlayer()
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "操作失败",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Layout Updates
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerContainerView.bounds
        
        // 🎯 动态调整控制面板高度，确保适配不同设备
        updateControlPanelHeight()
    }
    
    // 🎯 三分屏布局响应式适配
    private func updateControlPanelHeight() {
        // 🎯 更新时间轴动态宽度 (响应屏幕变化)
        updateTimelineWidth()
        
        // 三分屏布局使用比例约束，自动适应不同设备尺寸
        let safeAreaHeight = view.safeAreaLayoutGuide.layoutFrame.height
        let videoAreaHeight = safeAreaHeight * 0.533  // 53.3%
        let controlAreaHeight = safeAreaHeight * 0.213  // 21.3%
        let bottomAreaHeight = safeAreaHeight * 0.254  // 25.4%
        
        print("📱 VideoPlayerViewController 三分屏响应式布局:")
        print("   安全区域高度: \(safeAreaHeight)")
        print("   视频区域高度: \(videoAreaHeight) (53.3%)")
        print("   控制区域高度: \(controlAreaHeight) (21.3%)")
        print("   底部区域高度: \(bottomAreaHeight) (25.4%)")
    }
    
    // 🎯 动态更新时间轴宽度 (实现15%溢出)
    private func updateTimelineWidth() {
        let screenWidth = view.bounds.width
        let overflowWidth = screenWidth + (screenWidth * 0.15)  // 15%溢出
        timelineWidthConstraint?.constant = overflowWidth
        
        print("🎯 时间轴溢出更新:")
        print("   屏幕宽度: \(screenWidth)")
        print("   溢出宽度: \(overflowWidth) (+\(screenWidth * 0.15)px)")
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus" {
            DispatchQueue.main.async { [weak self] in
                // 🎯 编辑器模式：不再同步AVPlayer的播放状态
                // 流动状态由用户手动控制，不跟随AVPlayer状态
                print("📱 AVPlayer状态变化，但编辑器模式独立控制流动状态")
            }
        }
    }
}

// MARK: - TimelineViewDelegate
extension VideoPlayerViewController: TimelineViewDelegate {
    
    func timelineView(_ timelineView: TimelineView, didSeekToProgress progress: Double) {
        // 🎯 Wink风格：接收的是截取时间，用于截图功能
        let captureTime = CMTime(seconds: progress * videoDuration.seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // 更新截取时间标签显示
        updateCaptureTimeLabel(captureTime)
        
        // 🎯 实时预览：立即更新视频帧到对应时间
        updateVideoPreview(to: captureTime)
    }
    
    func timelineViewDidBeginSeeking(_ timelineView: TimelineView) {
        // 🎯 用户开始滚动时间轴，停止自动流动
        stopFlowing()
    }
    
    func timelineViewDidEndSeeking(_ timelineView: TimelineView) {
        // 🎯 用户结束滚动，可以选择恢复流动或保持停止状态
        // 用户体验：让用户手动控制是否继续流动
    }
}

// MARK: - 🆕 CaptureModeSwitcherDelegate
extension VideoPlayerViewController: CaptureModeSwitcherDelegate {
    
    func captureModeSwitcher(_ switcher: CaptureModeSwitcher, didRequestSwitchTo mode: CaptureMode) {
        // 检查是否需要确认
        do {
            try screenshotManager.switchMode(to: mode, force: false)
        } catch ScreenshotSessionError.needConfirmation(let currentMode, let newMode, let currentCount) {
            showModeConfirmationAlert(from: currentMode, to: newMode, currentCount: currentCount) { [weak self] confirmed in
                if confirmed {
                    try? self?.screenshotManager.switchMode(to: mode, force: true)
                } else {
                    // 恢复之前的模式
                    switcher.setCurrentMode(currentMode)
                }
            }
        } catch {
            print("模式切换失败: \(error)")
        }
    }
    
    func captureModeSwitcher(_ switcher: CaptureModeSwitcher, didConfirmSwitchTo mode: CaptureMode) {
        // 已确认切换
        print("已切换到模式: \(mode.displayName)")
    }
    
    private func showModeConfirmationAlert(from currentMode: CaptureMode, to newMode: CaptureMode, currentCount: Int, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "切换模式",
            message: "切换到\(newMode.displayName)模式将清空当前的\(currentCount)张截图，是否继续？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定切换", style: .destructive) { _ in
            completion(true)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            completion(false)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - 🆕 ScreenshotPreviewBarDelegate
extension VideoPlayerViewController: ScreenshotPreviewBarDelegate {
    
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didTapScreenshot screenshot: ScreenshotItem, at index: Int) {
        if isInSelectionMode {
            // 多选模式：切换选中状态
            toggleScreenshotSelection(screenshot)
            
            // 更新缩略图栏的选择显示
            screenshotPreviewBar.setScreenshotSelected(screenshot, isSelected: selectedScreenshots.contains(screenshot))
        } else {
            // 🎯 固定三分屏设计：单击截图时不弹出界面，保持界面连续性
            // 根据Wink风格设计，在固定布局内操作，不破坏用户体验
            print("📸 单击截图 - 固定三分屏模式，无需弹出界面")
            
            // 触感反馈
            HapticFeedbackManager.shared.lightImpact()
            
            // 🎯 提示用户可以长按进入多选模式
            showOperationHint()
        }
    }
    
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didDeleteScreenshot screenshot: ScreenshotItem, at index: Int) {
        // 删除截图
        screenshotManager.removeScreenshot(at: index)
        
        // 触感反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestCapture mode: CaptureMode) {
        // 请求截图
        print("📷 请求截图: \(mode.displayName)")
        // 这里可以直接触发截图功能
    }
    
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestPreviewAll screenshots: [ScreenshotItem]) {
        // 预览所有截图 - 使用新的批量保存逻辑
        guard !screenshots.isEmpty else { return }
        
        // 进入多选模式并选择所有截图
        enterSelectionMode()
        selectedScreenshots = Set(screenshots)
        
        // 直接跳转到处理中心
        let processingVC = ScreenshotProcessingViewController(
            screenshots: screenshots,
            mode: screenshotManager.currentMode
        )
        let navController = UINavigationController(rootViewController: processingVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestEnhanceAll screenshots: [ScreenshotItem]) {
        // 批量画质修复 - 跳转到处理中心
        guard !screenshots.isEmpty else { return }
        
        let processingVC = ScreenshotProcessingViewController(
            screenshots: screenshots,
            mode: screenshotManager.currentMode
        )
        let navController = UINavigationController(rootViewController: processingVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestClearAll mode: CaptureMode) {
        // 清空所有截图
        let alert = UIAlertController(
            title: "清空截图",
            message: "确定要删除所有\(screenshotManager.screenshots.count)张截图吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
            self.screenshotManager.clearAllScreenshots()
            HapticFeedbackManager.shared.lightImpact()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // 🆕 长按手势处理
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didLongPressScreenshot screenshot: ScreenshotItem, at index: Int) {
        // 长按进入多选模式
        if !isInSelectionMode {
            enterSelectionMode()
            
            // 自动选择被长按的截图
            selectedScreenshots.insert(screenshot)
            screenshotPreviewBar.setScreenshotSelected(screenshot, isSelected: true)
            
            HapticFeedbackManager.shared.mediumImpact()
            print("🔄 长按进入多选模式，已选择第 \(index + 1) 张截图")
        }
    }
}

// MARK: - 🆕 辅助方法扩展
extension VideoPlayerViewController {
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

