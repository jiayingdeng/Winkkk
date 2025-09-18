//
//  UnifiedBottomControlPanel.swift
//  Winkkk
//
//  Created on 2025-01-18
//  统一底部控制面板 - 整合时间轴、截图预览、主控制按钮
//

import UIKit
import AVFoundation

// MARK: - 协议定义
protocol UnifiedBottomControlPanelDelegate: AnyObject {
    // 播放控制
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapPlayPause isPlaying: Bool)
    
    // 时间轴控制
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didSeekToTime time: Double)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didStartSeeking time: Double)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didEndSeeking time: Double)
    
    // 截图功能
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapCapture mode: CaptureMode)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapClearScreenshots: Void)
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didSelectScreenshot item: ScreenshotItem)
    
    // 增强功能
    func bottomControlPanel(_ panel: UnifiedBottomControlPanel, didTapEnhance screenshots: [ScreenshotItem])
}

// MARK: - 截图模式枚举
enum CaptureMode {
    case stillImage
    case livePhoto
}

// MARK: - 主类定义
class UnifiedBottomControlPanel: UIView {
    
    // MARK: - 代理
    weak var delegate: UnifiedBottomControlPanelDelegate?
    
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
        collectionView.register(ScreenshotThumbnailView.self, forCellWithReuseIdentifier: "ScreenshotThumbnailView")
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
        button.backgroundColor = ThemeManager.accent.withAlphaComponent(0.8)
        button.layer.cornerRadius = ThemeManager.smallCornerRadius
        button.titleLabel?.font = ThemeManager.buttonFont
        return button
    }()
    
    // MARK: - 数据
    private var screenshots: [ScreenshotItem] = []
    private var currentCaptureMode: CaptureMode = .stillImage
    private var isPlaying: Bool = false
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
        setupActions()
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
        
        // 时间标签样式
        [currentTimeLabel, totalTimeLabel].forEach { label in
            label.font = ThemeManager.captionFont
            label.textColor = ThemeManager.secondaryText
            label.textAlignment = .center
        }
        
        timelineContainer.addSubview(timelineView)
        timelineContainer.addSubview(currentTimeLabel)
        timelineContainer.addSubview(totalTimeLabel)
    }
    
    private func setupScreenshotsContainer() {
        // 设置固定高度容器
        screenshotsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 头部信息区域
        previewHeaderStackView.addArrangedSubview(hintLabel)
        previewHeaderStackView.addArrangedSubview(clearButton)
        
        // CollectionView设置
        screenshotsCollectionView.dataSource = self
        screenshotsCollectionView.delegate = self
        
        screenshotsContainer.addSubview(previewHeaderStackView)
        screenshotsContainer.addSubview(screenshotsCollectionView)
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
    }
    
    private func setupActions() {
        // 按钮事件
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        enhanceButton.addTarget(self, action: #selector(enhanceButtonTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - 按钮事件处理 (基础框架)
    @objc private func playPauseButtonTapped() {
        // 将在后续阶段实现
        print("🎯 PlayPause button tapped")
    }
    
    @objc private func captureButtonTapped() {
        // 将在后续阶段实现
        print("🎯 Capture button tapped")
    }
    
    @objc private func enhanceButtonTapped() {
        // 将在后续阶段实现
        print("🎯 Enhance button tapped")
    }
    
    @objc private func clearButtonTapped() {
        // 将在后续阶段实现
        print("🎯 Clear button tapped")
    }
}

// MARK: - CollectionView DataSource (基础框架)
extension UnifiedBottomControlPanel: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screenshots.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ScreenshotThumbnailView", for: indexPath) as! ScreenshotThumbnailView
        // 配置将在后续阶段实现
        return cell
    }
}

// MARK: - CollectionView Delegate (基础框架)
extension UnifiedBottomControlPanel: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 选择逻辑将在后续阶段实现
        print("🎯 Screenshot selected at index: \(indexPath.item)")
    }
}
