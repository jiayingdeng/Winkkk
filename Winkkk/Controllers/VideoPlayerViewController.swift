//
//  VideoPlayerViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频播放编辑视图控制器 - AVPlayer集成和自定义控件
//

import UIKit
import AVFoundation

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
    
    // 状态变量
    private var isPlaying = false {
        didSet {
            updatePlayPauseButton()
        }
    }

    private var videoDuration: CMTime = .zero
    private var currentTime: CMTime = .zero
    
    // 🎯 响应式布局约束
    private var controlPanelHeightConstraint: NSLayoutConstraint?
    
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
            
            // 时间轴
            timelineView.topAnchor.constraint(equalTo: controlPanelBlurView.topAnchor, constant: 20),
            timelineView.leadingAnchor.constraint(equalTo: controlPanelBlurView.leadingAnchor, constant: 60),
            timelineView.trailingAnchor.constraint(equalTo: controlPanelBlurView.trailingAnchor, constant: -60),
            timelineView.heightAnchor.constraint(equalToConstant: 110),  // 🎯 适配新的时间轴高度 (60→110px)
            
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
        
        // 🎯 初始化动态高度约束
        controlPanelHeightConstraint = controlPanelBlurView.heightAnchor.constraint(equalToConstant: 210)
        controlPanelHeightConstraint?.isActive = true
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
    
    // MARK: - Player Control
    @objc private func playPauseButtonTapped() {
        if isPlaying {
            pausePlayer()
        } else {
            playPlayer()
        }
    }
    
    private func playPlayer() {
        player?.play()
        isPlaying = true
    }
    
    private func pausePlayer() {
        player?.pause()
        isPlaying = false
    }
    
    private func seekToTime(_ time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateTimeLabels()
    }
    
    private func updatePlayPauseButton() {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    private func updatePlaybackTime(_ time: CMTime) {
        currentTime = time
        updateTimeLabels()
        
        // 更新时间轴
        if videoDuration.seconds > 0 {
            let progress = time.seconds / videoDuration.seconds
            timelineView.setProgress(progress)
        }
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
    
    // MARK: - Screenshot
    @objc private func screenshotButtonTapped() {
        pausePlayer()
        
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
        // 显示截图预览界面（用户可选择是否进行画质修复）
        let previewVC = ScreenshotPreviewViewController(image: image, timestamp: currentTime.seconds)
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
        // 播放结束，重置到开始
        seekToTime(.zero)
        isPlaying = false
    }
    
    // MARK: - Cleanup
    private func cleanupPlayer() {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        
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
        
        print("📱 VideoPlayerViewController 响应式布局:")
        print("   屏幕高度: \(view.bounds.height)")
        print("   安全区域底部: \(safeAreaBottom)")
        print("   最终面板高度: \(finalHeight) (限制前: \(panelHeight))")
        print("   动态间距: \(adjustedSpacing)")
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus" {
            DispatchQueue.main.async { [weak self] in
                guard let player = self?.player else { return }
                self?.isPlaying = player.timeControlStatus == .playing
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
        
        // 可选：也可以同步更新播放位置
        // seekToTime(captureTime)
    }
    
    func timelineViewDidBeginSeeking(_ timelineView: TimelineView) {
        pausePlayer()
    }
    
    func timelineViewDidEndSeeking(_ timelineView: TimelineView) {
        // 可以选择恢复播放或保持暂停状态
    }
}
