//
//  VideoPlayerViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频播放编辑视图控制器 - AVPlayer集成和自定义控件
//

import UIKit
import AVFoundation

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
    private let controlPanelBlurView = BlurEffectView(style: .regular, intensity: 0.9)
    
    // 播放控制
    private let playPauseButton = UIButton()
    private let timelineView = TimelineView()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    
    // 截图按钮
    private let screenshotButton = UIButton()
    
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
    private var controlPanelHeightConstraint: NSLayoutConstraint?
    private var timelineWidthConstraint: NSLayoutConstraint?  // 动态宽度约束
    
    // MARK: - Dependencies
    private let screenshotEngine = ScreenshotEngine()
    
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
        controlPanelBlurView.layer.cornerRadius = ThemeManager.largeCornerRadius
        controlPanelBlurView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        // 🎯 允许时间轴溢出控制面板边界
        controlPanelBlurView.clipsToBounds = false
        view.addSubview(controlPanelBlurView)
        
        // 播放/暂停按钮
        setupPlayPauseButton()
        
        // 截图按钮
        setupScreenshotButton()
        
        // 时间标签
        setupTimeLabels()
        
        // 添加到控制面板
        controlPanelBlurView.contentView.addSubview(playPauseButton)
        controlPanelBlurView.contentView.addSubview(screenshotButton)
        controlPanelBlurView.contentView.addSubview(timelineView)
        controlPanelBlurView.contentView.addSubview(currentTimeLabel)
        controlPanelBlurView.contentView.addSubview(totalTimeLabel)
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
        
        // 设置图文布局
        screenshotButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        screenshotButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        
        screenshotButton.addTarget(self, action: #selector(screenshotButtonTapped), for: .touchUpInside)
        screenshotButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        screenshotButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
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
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
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
            
            // 播放器容器
            playerContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            playerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            playerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            playerContainerView.bottomAnchor.constraint(equalTo: controlPanelBlurView.topAnchor, constant: -20),
            
            // 控制面板
            controlPanelBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlPanelBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlPanelBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // 高度约束将动态设置
            
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
            
            // 播放按钮
            playPauseButton.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: 16),
            playPauseButton.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor, constant: -60),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 截图按钮
            screenshotButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            screenshotButton.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor, constant: 60),
            screenshotButton.widthAnchor.constraint(equalToConstant: 80),
            screenshotButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // 🎯 初始化动态约束
        controlPanelHeightConstraint = controlPanelBlurView.heightAnchor.constraint(equalToConstant: 210)
        controlPanelHeightConstraint?.isActive = true
        
        // 🎯 初始化时间轴动态宽度约束 (实现15%溢出效果)
        let screenWidth = UIScreen.main.bounds.width
        let overflowWidth = screenWidth + (screenWidth * 0.15)  // 屏幕宽度 + 15%溢出
        timelineWidthConstraint = timelineView.widthAnchor.constraint(equalToConstant: overflowWidth)
        timelineWidthConstraint?.isActive = true
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
        // 🎯 编辑器模式：停止流动以便精确截图
        stopFlowing()
        
        // 🎯 Wink风格：使用竖线位置的截取时间，而非当前播放时间
        let captureTime = timelineView.getCurrentCaptureTime()
        let cmCaptureTime = CMTime(seconds: captureTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
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
        
        // 显示截图预览界面（用户可选择是否进行画质修复）
        let previewVC = ScreenshotPreviewViewController(image: image, timestamp: captureTime)
        let navController = UINavigationController(rootViewController: previewVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneButtonTapped() {
        // 保存当前编辑状态或其他操作
        dismiss(animated: true)
    }
    
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
    
    // 🎯 动态响应式高度适配
    private func updateControlPanelHeight() {
        let safeAreaBottom = view.safeAreaInsets.bottom
        let baseHeight: CGFloat = 210  // 基础高度
        let panelHeight = baseHeight + safeAreaBottom
        
        // 确保控制面板不会占用太多屏幕空间（最多不超过屏幕高度的40%）
        let maxHeight = view.bounds.height * 0.4
        let finalHeight = min(panelHeight, maxHeight)
        
        // 如果高度被限制，相应调整内部间距
        let heightReduction = panelHeight - finalHeight
        let adjustedSpacing = max(8, 20 - heightReduction * 0.3)  // 动态间距
        
        // 更新约束
        controlPanelHeightConstraint?.constant = finalHeight
        
        // 🎯 更新时间轴动态宽度 (响应屏幕变化)
        updateTimelineWidth()
        
        print("📱 VideoPlayerViewController 响应式布局:")
        print("   屏幕高度: \(view.bounds.height)")
        print("   安全区域底部: \(safeAreaBottom)")
        print("   最终面板高度: \(finalHeight) (限制前: \(panelHeight))")
        print("   动态间距: \(adjustedSpacing)")
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
