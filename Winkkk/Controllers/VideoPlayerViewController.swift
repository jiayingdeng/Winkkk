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
import Photos

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

// ScreenshotError 定义已移至 ScreenshotEngine.swift 中统一管理

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
    
    // 🆕 底部安全区域填充视图 - 普通视图，让渐变背景透过来
    private let bottomSafeAreaFillerView = UIView()
    
    // 播放控制
    private let playPauseButton = UIButton()
    private let timelineView = TimelineView()
    private let timeInfoLabel = UILabel()  // 🎯 合并的时间信息标签 (当前时间 / 总时长)
    
    // 截图按钮
    private let screenshotButton = UIButton()
    
    // 🆕 多图截取系统组件
    private let captureModeSwitcher = CaptureModeSwitcher()
    private let screenshotPreviewBar = ScreenshotPreviewBar()
    
    // 🆕 批量操作面板 - 已移除，功能集成到ScreenshotPreviewBar中
    
    
    // 状态变量 - 🎯 编辑器模式重构
    private var isFlowing = false {  // 从isPlaying改为isFlowing
        didSet {
            updatePlayPauseButton()
        }
    }

    private var videoDuration: CMTime = .zero
    private var currentTime: CMTime = .zero
    private var cachedDurationString: String = "00:00"  // 🔧 缓存总时长字符串，避免重复格式化
    
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
    
    // 🆕 三分屏自适应布局约束（用于动态修改）
    private var playerContainerHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Dependencies
    private let screenshotEngine = ScreenshotEngine()
    private let screenshotManager = ScreenshotManager.shared
    
    // 截图预览栏高度约束
    private var screenshotPreviewBarHeightConstraint: NSLayoutConstraint?
    
    // 🆕 Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
        
        // 🆕 切换到当前视频的会话，隔离截图数据
        screenshotManager.switchVideoSession(to: videoURL)
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
        
        // 🆕 启用三分屏自适应布局（解决约束冲突）
        applyAdaptiveTriplePanelLayout()
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
        
        // 🆕 退出视频会话，清理临时截图
        screenshotManager.switchVideoSession(to: nil)
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
        
        // 🔧 确保截图按钮始终在最顶层，不被后续添加的组件遮挡
        controlPanelBlurView.contentView.bringSubviewToFront(screenshotButton)
        
        // 🆕 批量操作功能已集成到ScreenshotPreviewBar中
        
        // 导航栏
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        title = "视频编辑"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: ThemeManager.overlayTextWhite]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // 🎯 创建自定义保存按钮
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonPrimary
        saveButton.layer.cornerRadius = 8
        saveButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        saveButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        
        // 添加轻微的阴影效果
        saveButton.layer.shadowColor = UIColor.black.cgColor
        saveButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        saveButton.layer.shadowOpacity = 0.2
        saveButton.layer.shadowRadius = 4
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: saveButton)
    }
    
    private func setupControlPanel() {
        // 🆕 先添加底部安全区域填充视图（最底层）
        // 🎯 保持透明，让渐变背景透过来
        bottomSafeAreaFillerView.backgroundColor = .clear
        bottomSafeAreaFillerView.layer.cornerRadius = 0  // 移除圆角，完全填充底部
        bottomSafeAreaFillerView.clipsToBounds = true
        view.addSubview(bottomSafeAreaFillerView)
        
        // 🆕 设置统一毛玻璃容器
        unifiedControlPanelView.layer.cornerRadius = ThemeManager.largeCornerRadius
        unifiedControlPanelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        unifiedControlPanelView.clipsToBounds = false  // 🎯 改为 false，让毛玻璃效果延伸到底部
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
        controlPanelBlurView.contentView.addSubview(timeInfoLabel)  // 🎯 合并的时间标签
        controlPanelBlurView.contentView.addSubview(playPauseButton)
        controlPanelBlurView.contentView.addSubview(screenshotButton)
        
        // 🔧 确保截图按钮在最顶层，不被其他视图遮挡
        controlPanelBlurView.contentView.bringSubviewToFront(screenshotButton)
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
        screenshotButton.setTitle("截取当前画面", for: .normal)
        screenshotButton.tintColor = .white
        screenshotButton.backgroundColor = ThemeManager.success  // 🌟 移除透明度，更加鲜艳
        screenshotButton.layer.cornerRadius = ThemeManager.largeCornerRadius  // 🌟 更大圆角
        screenshotButton.titleLabel?.font = ThemeManager.buttonFont  // 🌟 更突出的字体
        
        // 🌟 增强视觉效果 - 高亮按钮
        screenshotButton.layer.shadowColor = ThemeManager.success.cgColor
        screenshotButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        screenshotButton.layer.shadowOpacity = 0.3
        screenshotButton.layer.shadowRadius = 8
        screenshotButton.layer.borderWidth = 2
        screenshotButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        // 🔧 确保按钮可交互
        screenshotButton.isUserInteractionEnabled = true
        screenshotButton.isHidden = false
        screenshotButton.alpha = 1.0
        
        // 设置图文布局 - 调整间距以适应更长文字
        screenshotButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
        screenshotButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        
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
        // 🎯 合并时间标签：显示 "当前时间 / 总时长"
        timeInfoLabel.text = "00:00 / 00:00"
        timeInfoLabel.textColor = .white
        timeInfoLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        timeInfoLabel.textAlignment = .center
        timeInfoLabel.numberOfLines = 1
    }
    
    private func setupConstraints() {
        // 🔧 关键修复：确保所有视图都禁用自动布局掩码
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        bottomSafeAreaFillerView.translatesAutoresizingMaskIntoConstraints = false  // 🆕 底部填充视图
        unifiedControlPanelView.translatesAutoresizingMaskIntoConstraints = false  // 🚨 关键修复
        controlPanelBlurView.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        screenshotButton.translatesAutoresizingMaskIntoConstraints = false
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timeInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 🎯 三分屏布局：视频区域 (53.3% - 默认值，可通过applyAdaptiveTriplePanelLayout()修改)
            playerContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            playerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            playerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // 🆕 底部安全区域填充视图 - 毛玻璃延伸到底部
            bottomSafeAreaFillerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomSafeAreaFillerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomSafeAreaFillerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomSafeAreaFillerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 🎯 统一毛玻璃容器 - 包含控制面板+模式切换器+截图预览栏
            unifiedControlPanelView.topAnchor.constraint(equalTo: playerContainerView.bottomAnchor, constant: 8),
            unifiedControlPanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            unifiedControlPanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            unifiedControlPanelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),  // 🎯 延伸到真正的底部，让毛玻璃颜色覆盖 Home Indicator 区域
            
            // 🎯 控制面板内容区域 - 在统一容器内部，使用弹性高度
            controlPanelBlurView.topAnchor.constraint(equalTo: unifiedControlPanelView.topAnchor),
            controlPanelBlurView.leadingAnchor.constraint(equalTo: unifiedControlPanelView.leadingAnchor),
            controlPanelBlurView.trailingAnchor.constraint(equalTo: unifiedControlPanelView.trailingAnchor),
            controlPanelBlurView.bottomAnchor.constraint(equalTo: unifiedControlPanelView.bottomAnchor),  // 🎯 直接贴底部
            controlPanelBlurView.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),  // 🎯 优化高度约束以适配压缩后的布局
            
            // 🎯 时间轴 - 允许视觉溢出屏幕边界 (Wink风格)
            timelineView.topAnchor.constraint(equalTo: captureModeSwitcher.bottomAnchor, constant: 6),  // 🎯 压缩：8pt → 6pt
            timelineView.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            timelineView.heightAnchor.constraint(equalToConstant: 88),  // 🎯 压缩：95pt → 88pt
            
            // 🎯 合并的时间标签 - 居中显示 "当前时间 / 总时长"
            timeInfoLabel.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 4),  // 🎯 压缩：6pt → 4pt
            timeInfoLabel.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            timeInfoLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),  // 最小宽度，支持自动扩展
            
            // 🎯 修复：播放和截图按钮与时间轴在同一水平区域，但固定在屏幕边界内
            // 播放按钮 - 位于屏幕左侧，与时间轴同一水平线
            playPauseButton.centerYAnchor.constraint(equalTo: timelineView.centerYAnchor),
            playPauseButton.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 20),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 🌟 截图按钮 - 移动到时间标签正下方，建立清晰的垂直布局链
            screenshotButton.topAnchor.constraint(equalTo: timeInfoLabel.bottomAnchor, constant: 6),  // 🎯 压缩：8pt → 6pt
            screenshotButton.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            screenshotButton.widthAnchor.constraint(equalToConstant: 180),  // 🌟 增加宽度以完整显示"截取当前画面"
            screenshotButton.heightAnchor.constraint(equalToConstant: 42)   // 🎯 压缩：44pt → 42pt
        ])
        
        // 🎯 初始化动态约束 - 三分屏布局
        // 默认视频区域高度：45% (优化以适配小屏设备)
        playerContainerHeightConstraint = playerContainerView.heightAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.heightAnchor,
            multiplier: 0.45
        )
        playerContainerHeightConstraint?.isActive = true
        
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
            // 🎯 控制面板内：截图预览栏 - 紧贴截图按钮下方，只用高度约束
            // ⚠️ 移除 bottomAnchor 约束，避免与 heightAnchor 冲突导致预览栏超出屏幕
            screenshotPreviewBar.topAnchor.constraint(equalTo: screenshotButton.bottomAnchor, constant: 6),  // 🎯 压缩：8pt → 6pt
            screenshotPreviewBar.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 16),
            screenshotPreviewBar.trailingAnchor.constraint(equalTo: controlPanelBlurView.trailingAnchor, constant: -16),
            // 🎯 关键：添加底部约束，确保预览栏不会超出安全区域
            screenshotPreviewBar.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            
            // 🎯 控制面板内：模式切换器 - 位于顶部
            captureModeSwitcher.topAnchor.constraint(equalTo: controlPanelBlurView.topAnchor, constant: 6),  // 🎯 压缩：8pt → 6pt
            captureModeSwitcher.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            captureModeSwitcher.heightAnchor.constraint(equalToConstant: 44),
            captureModeSwitcher.widthAnchor.constraint(equalToConstant: 280)
        ])
        
        // 🆕 截图预览栏动态高度约束 - 初始高度为0，有截图时再展开
        screenshotPreviewBarHeightConstraint = screenshotPreviewBar.heightAnchor.constraint(equalToConstant: 0)
        screenshotPreviewBarHeightConstraint?.isActive = true
    }
    
    // MARK: - Player Setup
    private func setupPlayer() {
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        // 🚀 关键优化1：配置缓冲策略（立即生效，减少卡顿）
        playerItem.preferredForwardBufferDuration = 3.0  // 预缓冲3秒
        
        // 🚀 关键优化2：启用自动缓冲管理
        if #available(iOS 10.0, *) {
            playerItem.automaticallyPreservesTimeOffsetFromLive = false
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        }
        
        // 🚀 关键优化3：配置高性能音视频输出（已移除，renderScale 是只读属性）
        
        player = AVPlayer(playerItem: playerItem)
        
        // 🚀 关键优化4：AVPlayer播放性能配置
        player?.automaticallyWaitsToMinimizeStalling = true  // 自动等待缓冲，避免卡顿
        player?.actionAtItemEnd = .pause
        
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
                    self.cachedDurationString = duration.formattedString  // 🔧 缓存总时长字符串
                    self.updateTimeInfoLabel()  // 🎯 使用合并标签更新
                    
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
        controlPanelBlurView.contentView.addSubview(captureModeSwitcher)  // 🎯 修改：移入内层容器
    }
    
    private func setupScreenshotPreviewBar() {
        screenshotPreviewBar.delegate = self
        screenshotPreviewBar.isHidden = false  // 🎯 固定三分屏：底部区域始终显示
        screenshotPreviewBar.alpha = 1.0
        // 🆕 添加到控制面板内部，实现功能聚合
        controlPanelBlurView.contentView.addSubview(screenshotPreviewBar)
    }
    
    // setupBatchOperationPanel 已移除 - 功能集成到ScreenshotPreviewBar中
    
    // 批量操作UI设置方法已移除 - 功能集成到ScreenshotPreviewBar中
    
    private func addButtonTouchEffects(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    private func setupMultiScreenshotSystem() {
        // 🆕 移除硬编码的初始模式设置，让会话加载时自动设置正确的模式
        // captureModeSwitcher.setCurrentMode(CaptureMode.stillImage) // 🔧 已移除
        
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
        
        // 🆕 根据截图是否存在来更新预览栏的高度
        let targetHeight: CGFloat = screenshots.isEmpty ? 0 : 105
        screenshotPreviewBarHeightConstraint?.constant = targetHeight
        
        // 使用动画使高度变化更平滑
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
        
        if !screenshots.isEmpty {
            print("📸 截图已添加到预览栏 (固定三分屏底部区域) - 高度: \(targetHeight)")
        } else {
            print("📸 预览栏已清空，高度收缩为0 (固定三分屏) - 高度: \(targetHeight)")
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
        
        // 🆕 关键修复：同步更新模式切换器的UI状态
        captureModeSwitcher.setCurrentMode(mode)
        print("📸 界面模式已同步更新: \(mode.displayName)")
    }
    
    // MARK: - Flow Control (编辑器模式)
    @objc private func playPauseButtonTapped() {
        if isFlowing {
            stopFlowing()
        } else {
            startFlowing()
        }
    }
    
    // 🎯 开始内容流动 (Wink编辑器模式) + 双轨同步播放
    private func startFlowing() {
        guard videoDuration.seconds > 0 else { return }
        
        // 计算流动速度 (像素/秒)
        let totalTimelineWidth = timelineView.timelineScrollView.contentSize.width
        let basePixelsPerSecond = totalTimelineWidth / CGFloat(videoDuration.seconds)
        let adjustedSpeed = basePixelsPerSecond * CGFloat(currentFlowSpeed.multiplier)
        
        // 🆕 启动AVPlayer播放，设置播放速度与流动速度同步
        player?.play()
        player?.rate = Float(currentFlowSpeed.multiplier)
        
        // 🎯 关键修复：设置时间轴播放状态为true
        timelineView.setPlaybackState(true)
        
        // 启动定时器，让内容流动
        flowTimer?.invalidate()
        flowTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updateFlowPosition(speed: adjustedSpeed)
        }
        
        isFlowing = true
        print("🎯 开始双轨同步流动 - 时间轴速度: \(currentFlowSpeed.displayName), 视频播放速度: \(currentFlowSpeed.multiplier)x")
    }
    
    // 🎯 停止内容流动 + 双轨同步暂停
    private func stopFlowing() {
        // 🆕 暂停AVPlayer播放
        player?.pause()
        
        // 🎯 关键修复：设置时间轴播放状态为false
        timelineView.setPlaybackState(false)
        
        // 停止时间轴滚动定时器
        flowTimer?.invalidate()
        flowTimer = nil
        isFlowing = false
        print("⏸️ 停止双轨同步流动 - 时间轴停止滚动，视频暂停播放")
    }
    
    // 🎯 编辑器模式：暂停播放 = 停止流动 (双轨同步)
    private func pausePlayer() {
        stopFlowing()  // 已包含player?.pause()调用，无需重复
    }
    
    // 🎯 更新流动位置 (双轨同步：时间轴 + 视频播放)
    private func updateFlowPosition(speed: CGFloat) {
        // 🎯 关键修复：基于视频播放进度更新时间轴，而不是基于滚动速度
        guard let currentPlayerTime = player?.currentTime() else { return }
        
        let currentVideoProgress = currentPlayerTime.seconds / videoDuration.seconds
        
        // 🎯 检查是否播放完毕
        if currentVideoProgress >= 1.0 {
            // 播放到末尾，停止双轨同步
            timelineView.setProgress(1.0)
            stopFlowing()  // 自动停止时间轴滚动和视频播放
        } else {
            // 🎯 修复：直接基于视频播放进度更新时间轴
            timelineView.setProgress(currentVideoProgress)
        }
        
        // 🎯 移除原有的反向同步逻辑，避免强制跳转
        // syncVideoPositionWithTimeline() - 不再需要
    }
    
    // 🆕 双轨同步：确保视频播放位置与时间轴位置匹配
    private func syncVideoPositionWithTimeline() {
        guard isFlowing, videoDuration.seconds > 0 else { return }
        
        // 🎯 关键修复：播放时不进行同步，避免强制跳转
        // 播放状态下，时间轴应该跟随视频播放进度，而不是反向控制
        // 只有在用户手动操作时间轴时才需要同步视频位置
        
        // 获取当前时间轴对应的时间位置
        let currentCaptureTime = timelineView.getCurrentCaptureTime()
        let targetTime = CMTime(seconds: currentCaptureTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // 获取当前视频播放时间
        guard let currentPlayerTime = player?.currentTime() else { return }
        
        // 🎯 修复：检查时间轴是否正在被用户手动操作
        let isTimelineBeingManipulated = timelineView.timelineScrollView.isTracking || 
                                        timelineView.timelineScrollView.isDragging ||
                                        timelineView.timelineScrollView.isDecelerating
        
        // 🎯 只有在时间轴被手动操作且差异较大时才进行同步
        if isTimelineBeingManipulated {
            let timeDifference = abs(currentCaptureTime - currentPlayerTime.seconds)
            
            if timeDifference > 0.5 { // 如果差异超过0.5秒，进行同步调整
                print("🔄 用户操作时间轴，同步视频到: \(currentCaptureTime)s (差异: \(timeDifference)s)")
                player?.seek(to: targetTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] completed in
                    if completed {
                        // 恢复播放速度
                        self?.player?.rate = Float(self?.currentFlowSpeed.multiplier ?? 1.0)
                    }
                }
            }
        }
        // 🎯 播放时不进行反向同步，让时间轴跟随视频播放进度
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
    
    // 🎯 更新合并的时间信息标签
    private func updateTimeInfoLabel() {
        let currentStr = currentTime.formattedString
        
        // 🔧 创建带样式的文本：当前时间 + 小字标签 / 总时长 + 小字标签
        let attributedString = NSMutableAttributedString()
        
        // 当前时间（正常大小）
        attributedString.append(NSAttributedString(
            string: currentStr,
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: ThemeManager.overlayTextWhite
            ]
        ))
        
        // "当前"标签（小字，半透明）
        attributedString.append(NSAttributedString(
            string: " 当前",
            attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: ThemeManager.overlaySecondaryText
            ]
        ))
        
        // 分隔符
        attributedString.append(NSAttributedString(
            string: " / ",
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: ThemeManager.overlayTextWhite
            ]
        ))
        
        // 总时长（正常大小）
        attributedString.append(NSAttributedString(
            string: cachedDurationString,
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: ThemeManager.overlayTextWhite
            ]
        ))
        
        // "总时长"标签（小字，半透明）
        attributedString.append(NSAttributedString(
            string: " 总时长",
            attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: ThemeManager.overlaySecondaryText
            ]
        ))
        
        timeInfoLabel.attributedText = attributedString
    }
    
    private func updateTimeLabels() {
        updateTimeInfoLabel()
    }
    
    // 🎯 更新截取时间标签（Wink风格）- 已移除，总时长保持固定
    private func updateCaptureTimeLabel(_ captureTime: CMTime) {
        // 🔧 修复：不再修改timeInfoLabel，避免总时长跳动
        // 总时长应该始终显示视频的总时长，而不是截取时间
        // 截取时间仅用于内部逻辑，不影响UI显示
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
    
    // 🎯 执行视频帧跳转 (仅在预览模式下，播放状态时不干扰)
    private func performVideoSeek(to time: CMTime) {
        // 🆕 双轨同步：如果正在播放流动，不执行手动跳转，避免干扰播放
        guard !isFlowing else {
            print("🎯 播放状态中，跳过手动帧跳转，保持播放连续性")
            return
        }
        
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            if completed {
                DispatchQueue.main.async {
                    self?.currentTime = time
                    // 🎯 更新合并的时间标签
                    self?.updateTimeInfoLabel()
                    print("🎯 预览模式：已跳转到 \(time.formattedString)")
                }
            }
        }
    }
    
    // MARK: - Screenshot
    @objc private func screenshotButtonTapped() {
        print("📸 截图按钮被点击！")
        
        // 🔧 添加调试信息确认按钮响应
        HapticFeedbackManager.shared.mediumImpact()
        print("🔧 DEBUG: 截图按钮响应正常，开始截图流程...")
        
        // 🎯 编辑器模式：停止流动以便精确截图
        stopFlowing()
        
        // 🎯 根据当前模式执行不同的截图操作
        let currentMode = screenshotManager.currentMode
        
        switch currentMode {
        case .stillImage:
            captureStillImage()
        case .livePhoto:
            captureLivePhoto()
        }
    }
    
    private func captureStillImage() {
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
    
    private func captureLivePhoto() {
        // 🎯 Live Photo模式：从竖线位置开始截取3秒片段
        let captureTime = timelineView.getCurrentCaptureTime()
        let cmCaptureTime = CMTime(seconds: captureTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        print("🎬 准备Live Photo截图 - 开始时间: \(captureTime)秒, CMTime: \(cmCaptureTime)")
        
        // 🚀 重要修复：暂停播放以避免资源冲突
        let wasPlaying = isFlowing
        if wasPlaying {
            print("⏸️ 暂停播放以避免Live Photo创建时的资源冲突")
            pausePlayer()
        }
        
        // 显示Live Photo创建进度
        showLivePhotoCreationProgress()
        
        // Live Photo创建不需要关联VideoItem，直接使用视频URL
        screenshotEngine.captureLivePhoto(from: videoURL, at: cmCaptureTime, for: nil) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLivePhotoCreationProgress()
                
                switch result {
                case .success(let screenshotItem):
                    self?.handleLivePhotoSuccess(screenshotItem: screenshotItem, captureTime: captureTime)
                case .failure(let error):
                    self?.handleLivePhotoError(error)
                }
            }
        }
    }
    
    private func handleScreenshotSuccess(_ image: UIImage) {
        // 🎯 使用截取时间作为时间戳，而非播放时间
        let captureTime = timelineView.getCurrentCaptureTime()
        
        // 🆕 创建截图项目 - 直接创建ScreenshotItem，不依赖VideoItem
        // 保存图片到Documents/Screenshots目录
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let screenshotsDirectory = documentsPath.appendingPathComponent("Screenshots")
        
        // 确保截图目录存在
        try? FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        
        let imageFileName = "screenshot_\(Date().timeIntervalSince1970)_\(UUID().uuidString).jpg"
        let imagePath = screenshotsDirectory.appendingPathComponent(imageFileName)
        
        // 保存图片到文件系统
        guard let imageData = image.jpegData(compressionQuality: 0.98) else {
            handleScreenshotError(ScreenshotError.imageProcessingFailed)
            return
        }
        
        do {
            try imageData.write(to: imagePath)
        } catch {
            handleScreenshotError(ScreenshotError.fileSaveFailed)
            return
        }
        
        // 创建截图项目，不依赖VideoItem - 直接使用Core Data
        let screenshot = PersistenceController.shared.createScreenshotItem(
            originalImagePath: imagePath,
            timestamp: captureTime,
            width: Int32(image.size.width),
            height: Int32(image.size.height),
            originalFileSize: Int64(imageData.count),
            videoSource: nil // 暂时不关联VideoItem，避免创建临时对象
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
            // 直接查看所有截图（移除多选模式）
            // 可以在这里添加其他查看逻辑
            
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
        let screenshots = screenshotManager.screenshots
        
        if screenshots.isEmpty {
            // 没有截图，直接返回
            dismiss(animated: true)
        } else {
            // 有截图，显示确认对话框
            showCancelConfirmationAlert(screenshotCount: screenshots.count)
        }
    }
    
    @objc private func doneButtonTapped() {
        // 检查是否有截图需要处理
        let screenshots = screenshotManager.screenshots
        
        if screenshots.isEmpty {
            // 🎯 无截图时，友好提示用户
            showNoScreenshotsAlert()
            return
        }
        
        // 有截图，请求相册权限并保存
        requestPhotosPermissionAndSave(screenshots: screenshots)
    }
    
    // 🎯 显示无截图提示
    private func showNoScreenshotsAlert() {
        let alert = UIAlertController(
            title: "还没有截图哦 📸",
            message: "您还没有截取任何精彩瞬间，要先截几张图片再保存吗？",
            preferredStyle: .alert
        )
        
        // 继续编辑按钮（主要操作）
        alert.addAction(UIAlertAction(
            title: "继续编辑",
            style: .default,
            handler: nil
        ))
        
        // 直接退出按钮（次要操作）
        alert.addAction(UIAlertAction(
            title: "直接退出",
            style: .cancel
        ) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Photos Permission & Save
    private func requestPhotosPermissionAndSave(screenshots: [ScreenshotItem]) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.saveScreenshotsToPhotoLibrary(screenshots: screenshots)
                    
                case .denied, .restricted:
                    self?.showPhotosPermissionDeniedAlert()
                    
                case .notDetermined:
                    // 用户未做选择，可以视为取消
                    print("用户未决定相册权限")
                    
                @unknown default:
                    self?.showPhotosPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func saveScreenshotsToPhotoLibrary(screenshots: [ScreenshotItem]) {
        let mode = screenshotManager.currentMode
        
        switch mode {
        case .stillImage:
            saveStillImages(screenshots)
        case .livePhoto:
            saveLivePhotos(screenshots)
        }
    }

    private func saveStillImages(_ screenshots: [ScreenshotItem]) {
        var savedCount = 0
        let totalCount = screenshots.count
        var lastError: Error?

        for screenshot in screenshots {
            guard let imageData = try? Data(contentsOf: screenshot.originalImagePath),
                  let image = UIImage(data: imageData) else {
                continue
            }
            
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            savedCount += 1
        }
        
        if savedCount > 0 {
            showSaveProgressAndNavigate(savedCount: savedCount, totalCount: totalCount)
        } else {
            showSaveFailureAlert()
        }
    }

    private func saveLivePhotos(_ screenshots: [ScreenshotItem]) {
        let dispatchGroup = DispatchGroup()
        var successCount = 0
        var errorCount = 0
        
        for screenshot in screenshots {
            guard let videoURL = screenshot.livePhotoVideoPath else {
                errorCount += 1
                continue
            }
            let imageURL = screenshot.originalImagePath
            
            dispatchGroup.enter()
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: imageURL, options: nil)
                request.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
            }) { success, error in
                if success {
                    successCount += 1
                    print("✅ Live Photo 保存成功: \(imageURL.lastPathComponent)")
                } else if let error = error {
                    errorCount += 1
                    print("❌ Live Photo 保存失败: \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if successCount > 0 {
                self.showSaveProgressAndNavigate(savedCount: successCount, totalCount: screenshots.count)
            } else {
                self.showSaveFailureAlert()
            }
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        // 这个方法会在每张图片保存完成后被调用
        if let error = error {
            print("❌ 截图保存到系统相册失败: \(error.localizedDescription)")
        } else {
            print("✅ 截图已保存到系统相册")
            // 🎯 更新所有截图的保存状态
            updateScreenshotsSaveStatus()
        }
    }
    
    /// 更新截图保存状态
    private func updateScreenshotsSaveStatus() {
        let screenshots = screenshotManager.screenshots
        for screenshot in screenshots {
            screenshot.isSavedToPhotos = true
        }
        // 保存到数据库
        PersistenceController.shared.save()
    }
    
    private func showSaveProgressAndNavigate(savedCount: Int, totalCount: Int) {
        // 显示简短的保存成功提示
        let message = totalCount == savedCount ? 
            "已将 \(savedCount) 张截图保存到系统相册" : 
            "已保存 \(savedCount)/\(totalCount) 张截图到系统相册"
        
        // 短暂显示成功提示后直接跳转
        showBriefSuccessMessage(message) { [weak self] in
            self?.navigateToScreenshotProcessing()
        }
    }
    
    private func showBriefSuccessMessage(_ message: String, completion: @escaping () -> Void) {
        // 创建简洁的成功提示视图
        let successView = UIView()
        successView.backgroundColor = UIColor(red: 255/255, green: 252/255, blue: 240/255, alpha: 0.95) // 温暖的米白色
        successView.layer.cornerRadius = 12
        successView.translatesAutoresizingMaskIntoConstraints = false
        
        let checkmarkLabel = UILabel()
        checkmarkLabel.text = "✅"
        checkmarkLabel.font = .systemFont(ofSize: 24)
        checkmarkLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = ThemeManager.primaryText
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        successView.addSubview(checkmarkLabel)
        successView.addSubview(messageLabel)
        view.addSubview(successView)
        
        // 布局约束
        NSLayoutConstraint.activate([
            successView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            successView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            successView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            successView.heightAnchor.constraint(equalToConstant: 100),
            
            checkmarkLabel.topAnchor.constraint(equalTo: successView.topAnchor, constant: 12),
            checkmarkLabel.centerXAnchor.constraint(equalTo: successView.centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: checkmarkLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: successView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: successView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: successView.bottomAnchor, constant: -12)
        ])
        
        // 动画显示
        successView.alpha = 0
        successView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, animations: {
            successView.alpha = 1
            successView.transform = .identity
        }) { _ in
            // 1.5秒后自动消失并跳转
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                UIView.animate(withDuration: 0.3, animations: {
                    successView.alpha = 0
                    successView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                }) { _ in
                    successView.removeFromSuperview()
                    completion()
                }
            }
        }
        
        // 触觉反馈
        HapticFeedbackManager.shared.notificationSuccess()
    }
    
    private func showPhotosPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "需要系统相册权限",
            message: "请在设置中允许访问系统相册，以保存截图",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "跳过保存", style: .default) { [weak self] _ in
            self?.navigateToScreenshotProcessing()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showSaveFailureAlert() {
        let alert = UIAlertController(
            title: "保存失败",
            message: "无法保存截图到系统相册，请检查权限设置",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            let screenshots = self?.screenshotManager.screenshots ?? []
            self?.requestPhotosPermissionAndSave(screenshots: screenshots)
        })
        
        alert.addAction(UIAlertAction(title: "跳过", style: .default) { [weak self] _ in
            self?.navigateToScreenshotProcessing()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showCancelConfirmationAlert(screenshotCount: Int) {
        let mode = screenshotManager.currentMode
        let modeText = mode == .livePhoto ? "实况照片" : "截图"
        
        let alert = UIAlertController(
            title: "确定要取消吗？",
            message: "当前有 \(screenshotCount) 张未保存的\(modeText)",
            preferredStyle: .alert
        )
        
        // 保留截图选项
        alert.addAction(UIAlertAction(title: "保留\(modeText)", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        // 丢弃截图选项
        alert.addAction(UIAlertAction(title: "丢弃\(modeText)", style: .destructive) { [weak self] _ in
            self?.clearScreenshotsAndDismiss()
        })
        
        // 继续编辑选项
        alert.addAction(UIAlertAction(title: "继续编辑", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func clearScreenshotsAndDismiss() {
        screenshotManager.clearAllScreenshots()
        HapticFeedbackManager.shared.lightImpact()
        dismiss(animated: true)
    }
    
    private func navigateToScreenshotProcessing() {
        // 跳转到处理中心
        let screenshots = screenshotManager.screenshots
        let processingVC = ScreenshotProcessingViewController(
            screenshots: screenshots,
            mode: screenshotManager.currentMode
        )
        let navController = UINavigationController(rootViewController: processingVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - 批量操作按钮动作已移除 - 功能集成到ScreenshotPreviewBar中
    
    // MARK: - 🆕 多选状态管理方法 - 现在使用MultiSelectionManager统一管理
    
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
    
    // MARK: - 🆕 三分屏自适应布局方法（可选启用）
    /// 应用三分屏自适应布局 - 此方法不会自动调用，需要手动启用
    /// 调用方式：在viewDidLoad中添加 applyAdaptiveTriplePanelLayout()
    private func applyAdaptiveTriplePanelLayout() {
        // 计算最优布局
        let config = AdaptiveTriplePanelLayoutManager.calculateOptimalLayout(for: view)
        
        guard config.isValid else {
            print("⚠️ 布局配置无效，保持原有布局")
            return
        }
        
        // 🎯 关键：只修改约束的 multiplier 和 priority，不改变业务逻辑
        // 这些修改不会影响任何按钮的 action 和 delegate 回调
        
        // 1️⃣ 修改视频区域高度约束
        if let oldConstraint = playerContainerHeightConstraint {
            oldConstraint.isActive = false
            playerContainerHeightConstraint = playerContainerView.heightAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.heightAnchor,
                multiplier: config.videoRatio
            )
            playerContainerHeightConstraint?.isActive = true
        }
        
        // 2️⃣ 修改控制面板高度约束（如果需要）
        // 注意：由于我们使用的是统一毛玻璃容器，它的高度由子视图（screenshotPreviewBar）决定
        // 所以这里不需要修改控制面板本身的高度
        
        print("✅ 三分屏自适应布局已应用")
        print("📱 当前设备类型: \(ScreenCategory.categorize(availableHeight: config.availableHeight))")
        print("📐 视频区域高度比例: \(String(format: "%.1f%%", config.videoRatio * 100))")
        print("📐 控制面板高度: \(config.controlPanelHeight)pt")
        
        // 布局会在下次 layoutSubviews 时自动生效
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
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
        
        // 三分屏响应式布局日志已优化
    }
    
    // 🎯 动态更新时间轴宽度 (实现15%溢出)
    private func updateTimelineWidth() {
        let screenWidth = view.bounds.width
        let overflowWidth = screenWidth + (screenWidth * 0.15)  // 15%溢出
        
        // ✅ 修复：确保约束更新和布局刷新
        if timelineWidthConstraint?.constant != overflowWidth {
            timelineWidthConstraint?.constant = overflowWidth
            
            // 强制立即布局更新，确保TimelineView获得正确宽度
            timelineView.setNeedsUpdateConstraints()
            UIView.performWithoutAnimation {
                timelineView.layoutIfNeeded()
            }
            
            // 通知TimelineView尺寸已更新，触发内部重新计算
            timelineView.handleBoundsChange()
        }
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus" {
            DispatchQueue.main.async { [weak self] in
                // 🎯 编辑器模式：不再同步AVPlayer的播放状态
                // 流动状态由用户手动控制，不跟随AVPlayer状态
                // AVPlayer状态变化日志已优化
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
        // 🎯 固定三分屏设计：单击截图时不弹出界面，保持界面连续性
        // 根据Wink风格设计，在固定布局内操作，不破坏用户体验
        print("📸 单击截图 - 固定三分屏模式，无需弹出界面")
        
        // 触感反馈
        HapticFeedbackManager.shared.lightImpact()
        
        // 🎯 提示用户可以长按进入多选模式
        showOperationHint()
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
        
        // 🎯 停止流动以便精确截图
        stopFlowing()
        
        // 🎯 根据模式执行不同的截图操作
        switch mode {
        case .stillImage:
            captureStillImage()
        case .livePhoto:
            captureLivePhoto()
        }
    }
    
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestPreviewAll screenshots: [ScreenshotItem]) {
        // 预览所有截图 - 使用新的批量保存逻辑
        guard !screenshots.isEmpty else { return }
        
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

// MARK: - Live Photo Support
extension VideoPlayerViewController {
    
    /// 处理Live Photo截图成功
    private func handleLivePhotoSuccess(screenshotItem: ScreenshotItem, captureTime: Double) {
        print("🎬 Live Photo创建成功！")
        
        // 🎯 保存到截图管理器
        screenshotManager.safeAddScreenshot(screenshotItem)
        
        // 🎯 显示成功动画
        showScreenshotSuccessAnimation()
        
        // 🎯 触觉反馈
        HapticFeedbackManager.shared.notificationSuccess()
        
        print("🎬 Live Photo截图已保存 - 时间戳: \(captureTime)")
    }
    
    /// 处理Live Photo创建错误
    private func handleLivePhotoError(_ error: Error) {
        print("❌ Live Photo创建失败: \(error.localizedDescription)")
        
        // 显示错误提示
        showAlert(
            title: "Live Photo创建失败",
            message: "无法创建Live Photo：\(error.localizedDescription)"
        )
        
        // 触觉反馈
        HapticFeedbackManager.shared.notificationError()
    }
    
    /// 显示Live Photo创建进度
    private func showLivePhotoCreationProgress() {
        // 创建进度提示视图
        let progressView = UIView()
        progressView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        progressView.layer.cornerRadius = 12
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tag = 999 // 用于后续移除
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "正在创建Live Photo..."
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        progressView.addSubview(activityIndicator)
        progressView.addSubview(label)
        view.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 200),
            progressView.heightAnchor.constraint(equalToConstant: 100),
            
            activityIndicator.centerXAnchor.constraint(equalTo: progressView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: progressView.topAnchor, constant: 20),
            
            label.centerXAnchor.constraint(equalTo: progressView.centerXAnchor),
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: progressView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: progressView.trailingAnchor, constant: -16)
        ])
        
        // 添加出现动画
        progressView.alpha = 0
        progressView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            progressView.alpha = 1
            progressView.transform = .identity
        }
    }
    
    /// 隐藏Live Photo创建进度
    private func hideLivePhotoCreationProgress() {
        guard let progressView = view.viewWithTag(999) else { return }
        
        UIView.animate(withDuration: 0.25, animations: {
            progressView.alpha = 0
            progressView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            progressView.removeFromSuperview()
        }
    }
}

