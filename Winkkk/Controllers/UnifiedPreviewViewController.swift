//
//  UnifiedPreviewViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  统一预览控制器 - 会话隔离设计简化版
//

import UIKit
import Photos
import AVFoundation
import PhotosUI
import AVKit

class UnifiedPreviewViewController: UIViewController {
    
    // MARK: - Properties
    private let screenshots: [ScreenshotItem]
    private let captureMode: CaptureMode
    private var currentIndex: Int
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 图像显示区域
    private let imageContainerView = UIView()
    private let mainImageView = UIImageView()
    
    // 多图模式：缩略图条
    private let thumbnailCollectionView: UICollectionView
    private let thumbnailFlowLayout = UICollectionViewFlowLayout()
    
    // 操作按钮面板
    private let actionPanelBlurView = BlurEffectView(style: .regular, intensity: 0.9)
    private let actionButtonsStackView = UIStackView()
    
    // 图像信息
    private let infoLabel = UILabel()
    
    // 进度提示
    private var progressAlert: UIAlertController?
    
    // MARK: - Initialization
    init(screenshots: [ScreenshotItem], captureMode: CaptureMode, initialIndex: Int = 0) {
        self.screenshots = screenshots
        self.captureMode = captureMode
        self.currentIndex = initialIndex
        
        // 配置缩略图集合视图
        thumbnailFlowLayout.scrollDirection = .horizontal
        thumbnailFlowLayout.itemSize = CGSize(width: 60, height: 60)
        thumbnailFlowLayout.minimumInteritemSpacing = 8
        thumbnailFlowLayout.minimumLineSpacing = 8
        thumbnailFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        thumbnailCollectionView = UICollectionView(frame: .zero, collectionViewLayout: thumbnailFlowLayout)
        
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
        configureForCurrentMode()
        
        // 成功进入预览的触感反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showPreviewAnimation()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        scrollView.addSubview(contentView)
        
        // 图像容器和图像视图
        setupImageView()
        
        // 缩略图集合视图
        setupThumbnailCollectionView()
        
        // 操作面板
        setupActionPanel()
        
        // 导航栏
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回",
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
    }
    
    private func setupImageView() {
        imageContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        imageContainerView.layer.cornerRadius = ThemeManager.standardCornerRadius
        imageContainerView.clipsToBounds = true
        contentView.addSubview(imageContainerView)
        
        mainImageView.contentMode = .scaleAspectFit
        mainImageView.clipsToBounds = true
        mainImageView.backgroundColor = .clear
        imageContainerView.addSubview(mainImageView)
        
        // 添加双击缩放手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        mainImageView.addGestureRecognizer(doubleTapGesture)
        mainImageView.isUserInteractionEnabled = true
        
        // 图像信息标签
        setupInfoLabel()
    }
    
    private func setupInfoLabel() {
        infoLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        infoLabel.font = ThemeManager.captionFont
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 2
        contentView.addSubview(infoLabel)
    }
    
    private func setupThumbnailCollectionView() {
        thumbnailCollectionView.backgroundColor = .clear
        thumbnailCollectionView.showsHorizontalScrollIndicator = false
        thumbnailCollectionView.dataSource = self
        thumbnailCollectionView.delegate = self
        
        // 注册单元格
        thumbnailCollectionView.register(ThumbnailCollectionViewCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
        
        contentView.addSubview(thumbnailCollectionView)
    }
    
    private func setupActionPanel() {
        actionPanelBlurView.layer.cornerRadius = ThemeManager.largeCornerRadius
        actionPanelBlurView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(actionPanelBlurView)
        
        // 配置按钮堆栈视图
        actionButtonsStackView.axis = .horizontal
        actionButtonsStackView.spacing = 12
        actionButtonsStackView.distribution = .fillEqually
        actionButtonsStackView.alignment = .center
        
        actionPanelBlurView.contentView.addSubview(actionButtonsStackView)
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        mainImageView.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        thumbnailCollectionView.translatesAutoresizingMaskIntoConstraints = false
        actionPanelBlurView.translatesAutoresizingMaskIntoConstraints = false
        actionButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
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
            scrollView.bottomAnchor.constraint(equalTo: actionPanelBlurView.topAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 图像容器
            imageContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            imageContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // 图像视图
            mainImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            mainImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            mainImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            mainImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            
            // 缩略图集合视图（多图模式）
            thumbnailCollectionView.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 16),
            thumbnailCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailCollectionView.heightAnchor.constraint(equalToConstant: 60),
            
            // 信息标签
            infoLabel.topAnchor.constraint(equalTo: thumbnailCollectionView.bottomAnchor, constant: 16),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            infoLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // 操作面板
            actionPanelBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionPanelBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionPanelBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            actionPanelBlurView.heightAnchor.constraint(equalToConstant: 100 + view.safeAreaInsets.bottom),
            
            // 按钮堆栈视图
            actionButtonsStackView.topAnchor.constraint(equalTo: actionPanelBlurView.contentView.topAnchor, constant: 20),
            actionButtonsStackView.leadingAnchor.constraint(equalTo: actionPanelBlurView.contentView.leadingAnchor, constant: 20),
            actionButtonsStackView.trailingAnchor.constraint(equalTo: actionPanelBlurView.contentView.trailingAnchor, constant: -20),
            actionButtonsStackView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - 模式配置
    private func configureForCurrentMode() {
        switch (captureMode, screenshots.count) {
        case (.stillImage, 1):
            configureSingleStillImage()
        case (.stillImage, let count) where count > 1:
            configureMultipleStillImages()
        case (.livePhoto, 1):
            configureSingleLivePhoto()
        case (.livePhoto, let count) where count > 1:
            configureMultipleLivePhotos()
        default:
            break
        }
        
        // 更新当前显示的图片
        updateCurrentImage()
        updateImageInfo()
    }
    
    // MARK: - 普通截图 - 单图模式
    private func configureSingleStillImage() {
        title = "图片预览"
        thumbnailCollectionView.isHidden = true
        
        // 调整图像容器高度（单图模式更大）
        imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor, multiplier: 1.3).isActive = true
        
        let actions = [
            createActionButton(title: "✨ 画质修复", action: #selector(enhanceSingleImage)),
            createActionButton(title: "💾 保存", action: #selector(saveSingleImage)),
            createActionButton(title: "📤 分享", action: #selector(shareSingleImage))
        ]
        
        setupActionButtons(actions)
    }
    
    // MARK: - 普通截图 - 多图模式
    private func configureMultipleStillImages() {
        title = "图片预览 (\(currentIndex + 1)/\(screenshots.count))"
        thumbnailCollectionView.isHidden = false
        
        // 调整图像容器高度（多图模式适中）
        imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor, multiplier: 1.0).isActive = true
        
        let actions = [
            createActionButton(title: "✨ 批量修复", action: #selector(enhanceAllImages)),
            createActionButton(title: "🧩 拼图", action: #selector(createCollage)),
            createActionButton(title: "💾 保存", action: #selector(saveAllImages)),
            createActionButton(title: "📤 分享", action: #selector(shareAllImages))
        ]
        
        setupActionButtons(actions)
        
        // 刷新缩略图集合并选中当前项
        thumbnailCollectionView.reloadData()
        DispatchQueue.main.async {
            self.thumbnailCollectionView.selectItem(
                at: IndexPath(item: self.currentIndex, section: 0),
                animated: false,
                scrollPosition: .centeredHorizontally
            )
        }
    }
    
    // MARK: - Live Photo - 单个模式
    private func configureSingleLivePhoto() {
        title = "Live Photo预览"
        thumbnailCollectionView.isHidden = true
        
        // 调整图像容器高度
        imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor, multiplier: 1.3).isActive = true
        
        let actions = [
            createActionButton(title: "▶️ 播放", action: #selector(playLivePhoto)),
            createActionButton(title: "🖼️ 设置封面", action: #selector(setCover)),
            createActionButton(title: "💾 保存", action: #selector(saveSingleLivePhoto)),
            createActionButton(title: "📤 分享", action: #selector(shareSingleLivePhoto))
        ]
        
        setupActionButtons(actions)
    }
    
    // MARK: - Live Photo - 多个模式
    private func configureMultipleLivePhotos() {
        title = "Live Photo预览 (\(currentIndex + 1)/\(screenshots.count))"
        thumbnailCollectionView.isHidden = false
        
        // 调整图像容器高度
        imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor, multiplier: 1.0).isActive = true
        
        let actions = [
            createActionButton(title: "▶️ 播放", action: #selector(playCurrentLivePhoto)),
            createActionButton(title: "💾 批量保存", action: #selector(saveAllLivePhotos)),
            createActionButton(title: "📤 分享", action: #selector(shareAllLivePhotos))
        ]
        
        setupActionButtons(actions)
        
        // 刷新缩略图集合并选中当前项
        thumbnailCollectionView.reloadData()
        DispatchQueue.main.async {
            self.thumbnailCollectionView.selectItem(
                at: IndexPath(item: self.currentIndex, section: 0),
                animated: false,
                scrollPosition: .centeredHorizontally
            )
        }
    }
    
    // MARK: - 辅助方法
    private func createActionButton(title: String, action: Selector) -> UIButton {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = captureMode.themeColor
        button.layer.cornerRadius = ThemeManager.standardCornerRadius
        button.titleLabel?.font = ThemeManager.buttonFont
        
        button.addTarget(self, action: action, for: .touchUpInside)
        addButtonTouchEffects(to: button)
        
        return button
    }
    
    private func setupActionButtons(_ buttons: [UIButton]) {
        actionButtonsStackView.arrangedSubviews.forEach { view in
            actionButtonsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        buttons.forEach { button in
            actionButtonsStackView.addArrangedSubview(button)
        }
    }
    
    private func addButtonTouchEffects(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    private func updateCurrentImage() {
        guard currentIndex < screenshots.count else { return }
        let screenshot = screenshots[currentIndex]
        mainImageView.image = screenshot.image
    }
    
    private func updateImageInfo() {
        guard currentIndex < screenshots.count else { return }
        let screenshot = screenshots[currentIndex]
        
        let imageSize = screenshot.image?.size ?? .zero
        let timestamp = String.formatTime(screenshot.timestamp)
        let modeText = screenshot.mode.displayName
        
        infoLabel.text = "\(modeText) - 尺寸: \(Int(imageSize.width)) × \(Int(imageSize.height))\n时间: \(timestamp)"
    }
    
    // MARK: - 动画
    private func showPreviewAnimation() {
        // 图像从小到大的出现动画
        mainImageView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        mainImageView.alpha = 0
        
        UIView.animate(withDuration: 0.6, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.mainImageView.transform = .identity
            self.mainImageView.alpha = 1
        }
        
        // 缩略图条淡入
        if !thumbnailCollectionView.isHidden {
            thumbnailCollectionView.alpha = 0
            UIView.animate(withDuration: 0.4, delay: 0.4) {
                self.thumbnailCollectionView.alpha = 1
            }
        }
        
        // 按钮依次出现
        for (index, button) in actionButtonsStackView.arrangedSubviews.enumerated() {
            button.alpha = 0
            UIView.animate(withDuration: 0.3, delay: 0.5 + Double(index) * 0.1) {
                button.alpha = 1
            }
        }
    }
    
    // MARK: - Actions - 普通截图模式
    @objc private func enhanceSingleImage() {
        HapticFeedbackManager.shared.buttonTap()
        let screenshot = screenshots[currentIndex]
        
        guard let image = screenshot.image else {
            showAlert(title: "错误", message: "无法加载图片")
            return
        }
        
        let enhanceVC = ImageEnhanceViewController(
            image: image,
            timestamp: screenshot.timestamp
        )
        
        let navController = UINavigationController(rootViewController: enhanceVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
        
        print("📸 单图画质修复: \(screenshot.timestamp)")
    }
    
    @objc private func enhanceAllImages() {
        HapticFeedbackManager.shared.buttonTap()
        
        let images = screenshots.compactMap { $0.image }
        guard !images.isEmpty else {
            showAlert(title: "修复失败", message: "没有可修复的图片")
            return
        }
        
        showBatchEnhancementOptions(for: images)
    }
    
    @objc private func createCollage() {
        HapticFeedbackManager.shared.buttonTap()
        
        // 检查是否是普通截图模式且有多张图片
        guard captureMode == .stillImage && screenshots.count > 1 else {
            showAlert(title: "无法创建拼图", message: "拼图功能仅支持多张普通截图")
            return
        }
        
        // 提取所有图片
        let images = screenshots.compactMap { $0.image }
        guard images.count == screenshots.count else {
            showAlert(title: "错误", message: "部分图片无法加载")
            return
        }
        
        // 创建拼图界面
        createCollageViewController(with: images)
    }
    
    private func createCollageViewController(with images: [UIImage]) {
        // TODO: 实现拼图编辑界面
        print("🧩 创建拼图: \(images.count)张图片")
        
        // 临时方案：显示选择对话框
        showCollageOptionsAlert(images: images)
    }
    
    private func showCollageOptionsAlert(images: [UIImage]) {
        let alert = UIAlertController(
            title: "选择拼图模式",
            message: "请选择你希望的拼图布局",
            preferredStyle: .actionSheet
        )
        
        // 网格布局
        alert.addAction(UIAlertAction(title: "🗺️ 网格布局", style: .default) { _ in
            self.createGridCollage(images: images)
        })
        
        // 横向排列
        alert.addAction(UIAlertAction(title: "↔️ 横向排列", style: .default) { _ in
            self.createHorizontalCollage(images: images)
        })
        
        // 竖向排列
        alert.addAction(UIAlertAction(title: "↕️ 竖向排列", style: .default) { _ in
            self.createVerticalCollage(images: images)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func createGridCollage(images: [UIImage]) {
        print("🗺️ 创建网格拼图: \(images.count)张图片")
        
        // 计算网格布局
        let imageCount = images.count
        let gridSize = calculateGridSize(for: imageCount)
        let collageSize = CGSize(width: 800, height: 800) // 固定拼图尺寸
        
        // 创建拼图图像
        if let collageImage = createGridCollageImage(images: images, gridSize: gridSize, collageSize: collageSize) {
            showCollagePreview(image: collageImage, type: "网格布局")
        } else {
            showAlert(title: "拼图失败", message: "无法创建网格拼图")
        }
    }
    
    private func createHorizontalCollage(images: [UIImage]) {
        print("↔️ 创建横向拼图: \(images.count)张图片")
        
        let imageCount = images.count
        let collageSize = CGSize(width: 800 * imageCount, height: 800) // 横向拼接，宽度成倍增加
        
        // 创建横向拼图
        if let collageImage = createHorizontalCollageImage(images: images, collageSize: collageSize) {
            showCollagePreview(image: collageImage, type: "横向排列")
        } else {
            showAlert(title: "拼图失败", message: "无法创建横向拼图")
        }
    }
    
    private func createVerticalCollage(images: [UIImage]) {
        print("↕️ 创建竖向拼图: \(images.count)张图片")
        
        let imageCount = images.count
        let collageSize = CGSize(width: 800, height: 800 * imageCount) // 竖向拼接，高度成倍增加
        
        // 创建竖向拼图
        if let collageImage = createVerticalCollageImage(images: images, collageSize: collageSize) {
            showCollagePreview(image: collageImage, type: "竖向排列")
        } else {
            showAlert(title: "拼图失败", message: "无法创建竖向拼图")
        }
    }
    
    private func showCollageResult(type: String) {
        showAlert(title: "拼图功能待实现", message: "\(type)拼图功能正在开发中") {
            // 在用户点击确定后返回
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: - Actions - Live Photo模式
    @objc private func playLivePhoto() {
        HapticFeedbackManager.shared.buttonTap()
        let screenshot = screenshots[currentIndex]
        
        guard let videoSource = screenshot.videoSource else {
            showAlert(title: "播放失败", message: "找不到视频源文件")
            return
        }
        
        createAndPlayLivePhoto(from: videoSource.filePath, timestamp: screenshot.timestamp)
    }
    
    @objc private func playCurrentLivePhoto() {
        HapticFeedbackManager.shared.buttonTap()
        playLivePhoto() // 重用单个Live Photo播放逻辑
    }
    
    @objc private func setCover() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现Live Photo封面设置
        print("🖼️ 设置Live Photo封面")
    }
    
    // MARK: - Actions - 通用
    @objc private func saveSingleImage() {
        HapticFeedbackManager.shared.buttonTap()
        let screenshot = screenshots[currentIndex]
        guard let image = screenshot.image else {
            showAlert(title: "保存失败", message: "无法加载图片")
            return
        }
        
        // 请求相册权限
        requestPhotoLibraryPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(self?.image(_:didFinishSavingWithError:contextInfo:)), nil)
                } else {
                    self?.showAlert(title: "保存失败", message: "需要相册访问权限才能保存图片")
                }
            }
        }
    }
    
    @objc private func saveAllImages() {
        HapticFeedbackManager.shared.buttonTap()
        
        let images = screenshots.compactMap { $0.image }
        guard !images.isEmpty else {
            showAlert(title: "保存失败", message: "没有可保存的图片")
            return
        }
        
        // 请求相册权限
        requestPhotoLibraryPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.performBatchSave(images: images)
                } else {
                    self?.showAlert(title: "保存失败", message: "需要相册访问权限才能保存图片")
                }
            }
        }
    }
    
    @objc private func saveSingleLivePhoto() {
        HapticFeedbackManager.shared.buttonTap()
        let screenshot = screenshots[currentIndex]
        
        guard let videoSource = screenshot.videoSource else {
            showAlert(title: "保存失败", message: "找不到视频源文件")
            return
        }
        
        // 请求相册权限
        requestPhotoLibraryPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.createAndSaveLivePhoto(from: videoSource.filePath, timestamp: screenshot.timestamp)
                } else {
                    self?.showAlert(title: "保存失败", message: "需要相册访问权限才能保存Live Photo")
                }
            }
        }
    }
    
    @objc private func saveAllLivePhotos() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现批量Live Photo保存
        print("💾 批量保存Live Photo")
    }
    
    @objc private func shareSingleImage() {
        HapticFeedbackManager.shared.buttonTap()
        let screenshot = screenshots[currentIndex]
        
        guard let image = screenshot.image else {
            showAlert(title: "分享失败", message: "无法加载图片")
            return
        }
        
        let activityItems: [Any] = [image]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func shareAllImages() {
        HapticFeedbackManager.shared.buttonTap()
        
        let images = screenshots.compactMap { $0.image }
        guard !images.isEmpty else {
            showAlert(title: "分享失败", message: "没有可分享的图片")
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: images, applicationActivities: nil)
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func shareSingleLivePhoto() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现Live Photo分享
        print("📤 分享Live Photo")
    }
    
    @objc private func shareAllLivePhotos() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现批量Live Photo分享
        print("📤 批量分享Live Photo")
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneButtonTapped() {
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
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        HapticFeedbackManager.shared.lightImpact()
        
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let location = gesture.location(in: mainImageView)
            let rect = CGRect(x: location.x - 50, y: location.y - 50, width: 100, height: 100)
            scrollView.zoom(to: rect, animated: true)
        }
    }
    
    // MARK: - Save Callback
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            HapticFeedbackManager.shared.notificationError()
            showErrorAlert(message: error.localizedDescription)
        } else {
            HapticFeedbackManager.shared.notificationSuccess()
            showSuccessAlert(message: "图片已保存到相册")
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "保存失败", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showSuccessAlert(message: String) {
        let alert = UIAlertController(title: "保存成功", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - 🆕 辅助方法
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    // MARK: - 保存功能辅助方法
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
    
    private func performBatchSave(images: [UIImage]) {
        var savedCount = 0
        let totalCount = images.count
        
        // 创建进度提示
        let alert = UIAlertController(title: "正在保存", message: "已保存 0/\(totalCount) 张图片", preferredStyle: .alert)
        present(alert, animated: true)
        
        for (index, image) in images.enumerated() {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            savedCount += 1
            
            // 更新进度
            DispatchQueue.main.async {
                alert.message = "已保存 \(savedCount)/\(totalCount) 张图片"
                
                // 如果全部完成
                if savedCount == totalCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        alert.dismiss(animated: true) {
                            HapticFeedbackManager.shared.notificationSuccess()
                            self.showAlert(title: "保存完成", message: "已成功保存 \(totalCount) 张图片到相册")
                        }
                    }
                }
            }
        }
    }
    
    
    // MARK: - 拼图功能辅助方法
    private func calculateGridSize(for count: Int) -> (rows: Int, cols: Int) {
        switch count {
        case 2: return (1, 2)
        case 3: return (2, 2) // 3张图片用2x2网格，空一个位置
        case 4: return (2, 2)
        case 5, 6: return (2, 3)
        case 7, 8, 9: return (3, 3)
        default: return (2, 2)
        }
    }
    
    private func createGridCollageImage(images: [UIImage], gridSize: (rows: Int, cols: Int), collageSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let cellWidth = collageSize.width / CGFloat(gridSize.cols)
            let cellHeight = collageSize.height / CGFloat(gridSize.rows)
            let spacing: CGFloat = 4 // 图片间距
            
            for (index, image) in images.enumerated() {
                let row = index / gridSize.cols
                let col = index % gridSize.cols
                
                let x = CGFloat(col) * cellWidth + spacing
                let y = CGFloat(row) * cellHeight + spacing
                let width = cellWidth - spacing * 2
                let height = cellHeight - spacing * 2
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image.draw(in: rect)
            }
        }
    }
    
    private func createHorizontalCollageImage(images: [UIImage], collageSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let imageWidth = collageSize.width / CGFloat(images.count)
            let spacing: CGFloat = 4
            
            for (index, image) in images.enumerated() {
                let x = CGFloat(index) * imageWidth + spacing
                let y: CGFloat = spacing
                let width = imageWidth - spacing * 2
                let height = collageSize.height - spacing * 2
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image.draw(in: rect)
            }
        }
    }
    
    private func createVerticalCollageImage(images: [UIImage], collageSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let imageHeight = collageSize.height / CGFloat(images.count)
            let spacing: CGFloat = 4
            
            for (index, image) in images.enumerated() {
                let x: CGFloat = spacing
                let y = CGFloat(index) * imageHeight + spacing
                let width = collageSize.width - spacing * 2
                let height = imageHeight - spacing * 2
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image.draw(in: rect)
            }
        }
    }
    
    private func showCollagePreview(image: UIImage, type: String) {
        let alert = UIAlertController(title: "拼图完成", message: "已创建\(type)拼图", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "保存到相册", style: .default) { _ in
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.collageImage(_:didFinishSavingWithError:contextInfo:)), nil)
        })
        
        alert.addAction(UIAlertAction(title: "分享", style: .default) { _ in
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            
            // iPad适配
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            self.present(activityVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func collageImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            HapticFeedbackManager.shared.notificationError()
            showAlert(title: "保存失败", message: error.localizedDescription)
        } else {
            HapticFeedbackManager.shared.notificationSuccess()
            showAlert(title: "拼图保存成功", message: "拼图已保存到相册")
        }
    }
}

// MARK: - UIScrollViewDelegate
extension UnifiedPreviewViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mainImageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 保持图像居中
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        mainImageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                       y: scrollView.contentSize.height * 0.5 + offsetY)
    }
}

// MARK: - UICollectionViewDataSource
extension UnifiedPreviewViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screenshots.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThumbnailCell", for: indexPath) as! ThumbnailCollectionViewCell
        let screenshot = screenshots[indexPath.item]
        cell.configure(with: screenshot)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension UnifiedPreviewViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        currentIndex = indexPath.item
        updateCurrentImage()
        updateImageInfo()
        
        // 更新标题
        if screenshots.count > 1 {
            title = "\(captureMode.displayName)预览 (\(currentIndex + 1)/\(screenshots.count))"
        }
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    // MARK: - 批量画质修复功能
    
    /// 显示批量修复选项
    private func showBatchEnhancementOptions(for images: [UIImage]) {
        let alert = UIAlertController(
            title: "批量画质修复",
            message: "选择修复强度，将对 \(images.count) 张图片应用修复",
            preferredStyle: .actionSheet
        )
        
        // 添加修复强度选项
        alert.addAction(UIAlertAction(title: "🟡 轻度修复", style: .default) { _ in
            self.performBatchEnhancement(images: images, level: 1)
        })
        
        alert.addAction(UIAlertAction(title: "🟠 中度修复", style: .default) { _ in
            self.performBatchEnhancement(images: images, level: 2)
        })
        
        alert.addAction(UIAlertAction(title: "🔴 重度修复", style: .default) { _ in
            self.performBatchEnhancement(images: images, level: 3)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    /// 执行批量画质修复
    private func performBatchEnhancement(images: [UIImage], level: Int) {
        let totalCount = images.count
        var processedCount = 0
        var enhancedImages: [UIImage] = []
        
        // 显示进度提示
        let progressAlert = UIAlertController(
            title: "正在修复图片",
            message: "已处理 0/\(totalCount) 张图片",
            preferredStyle: .alert
        )
        
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        progressAlert.view.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: progressAlert.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: progressAlert.view.bottomAnchor, constant: -20)
        ])
        
        present(progressAlert, animated: true)
        
        // 创建ImageEnhancer实例
        let enhancer = ImageEnhancer()
        
        // 批量处理图片
        let processingQueue = DispatchQueue(label: "batchEnhancement", qos: .userInitiated)
        
        for (index, image) in images.enumerated() {
            processingQueue.async {
                // 将Int转换为EnhanceLevel
                let enhanceLevel: EnhanceLevel = {
                    switch level {
                    case 1: return .light
                    case 2: return .medium
                    case 3: return .heavy
                    default: return .medium
                    }
                }()
                
                // 异步处理画质修复
                enhancer.enhanceImage(image, level: enhanceLevel) { result in
                    let enhancedImage = (try? result.get()) ?? image
                    
                    DispatchQueue.main.async {
                        processedCount += 1
                        enhancedImages.append(enhancedImage)
                        
                        // 更新进度
                        progressAlert.message = "已处理 \(processedCount)/\(totalCount) 张图片"
                        
                        // 如果全部完成
                        if processedCount == totalCount {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                progressAlert.dismiss(animated: true) {
                                    self.showBatchEnhancementResult(enhancedImages: enhancedImages, level: level)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// 显示批量修复结果
    private func showBatchEnhancementResult(enhancedImages: [UIImage], level: Int) {
        HapticFeedbackManager.shared.notificationSuccess()
        
        let levelText = ["", "轻度", "中度", "重度"][level]
        
        let alert = UIAlertController(
            title: "修复完成",
            message: "已完成 \(enhancedImages.count) 张图片的\(levelText)修复",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "查看结果", style: .default) { _ in
            self.showEnhancedImagesPreview(enhancedImages)
        })
        
        alert.addAction(UIAlertAction(title: "保存到相册", style: .default) { _ in
            self.saveBatchEnhancedImages(enhancedImages)
        })
        
        alert.addAction(UIAlertAction(title: "稍后处理", style: .cancel))
        
        present(alert, animated: true)
    }
    
    /// 显示修复后的图片预览
    private func showEnhancedImagesPreview(_ enhancedImages: [UIImage]) {
        // 创建临时的ScreenshotItem用于预览
        var tempScreenshots: [ScreenshotItem] = []
        
        for (index, image) in enhancedImages.enumerated() {
            if index < screenshots.count {
                let originalScreenshot = screenshots[index]
                // 这里应该创建新的临时截图项目，但为了简化，我们直接使用原始的
                tempScreenshots.append(originalScreenshot)
            }
        }
        
        if !tempScreenshots.isEmpty {
            let previewVC = UnifiedPreviewViewController(
                screenshots: tempScreenshots,
                captureMode: captureMode,
                initialIndex: 0
            )
            
            let navController = UINavigationController(rootViewController: previewVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }
    
    /// 批量保存修复后的图片
    private func saveBatchEnhancedImages(_ enhancedImages: [UIImage]) {
        requestPhotoLibraryPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.performBatchSave(images: enhancedImages)
                } else {
                    self?.showAlert(title: "保存失败", message: "需要相册访问权限才能保存图片")
                }
            }
        }
    }
    
    // MARK: - Live Photo 功能辅助方法
    
    /// 创建并播放Live Photo
    private func createAndPlayLivePhoto(from videoURL: URL, timestamp: Double) {
        showProgressAlert(title: "正在创建Live Photo", message: "正在从视频中提取3秒片段...")
        
        // 计算3秒片段的时间范围（以当前时间戳为中心）
        let centerTime = CMTime(seconds: timestamp, preferredTimescale: 600)
        let startTime = CMTime(seconds: max(0, timestamp - 1.5), preferredTimescale: 600)
        let endTime = CMTime(seconds: timestamp + 1.5, preferredTimescale: 600)
        
        // 创建视频片段
        createVideoSegment(from: videoURL, startTime: startTime, endTime: endTime) { [weak self] result in
            DispatchQueue.main.async {
                self?.dismissProgressAlert()
                
                switch result {
                case .success(let segmentURL):
                    self?.playVideoSegment(segmentURL)
                case .failure(let error):
                    self?.showAlert(title: "播放失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    /// 创建并保存Live Photo
    private func createAndSaveLivePhoto(from videoURL: URL, timestamp: Double) {
        showProgressAlert(title: "正在创建Live Photo", message: "正在处理视频片段...")
        
        // 计算3秒片段的时间范围
        let startTime = CMTime(seconds: max(0, timestamp - 1.5), preferredTimescale: 600)
        let endTime = CMTime(seconds: timestamp + 1.5, preferredTimescale: 600)
        
        // 创建视频片段
        createVideoSegment(from: videoURL, startTime: startTime, endTime: endTime) { [weak self] result in
            switch result {
            case .success(let segmentURL):
                self?.saveLivePhotoToLibrary(videoURL: segmentURL, timestamp: timestamp)
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.dismissProgressAlert()
                    self?.showAlert(title: "创建失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    /// 创建视频片段
    private func createVideoSegment(from videoURL: URL, startTime: CMTime, endTime: CMTime, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: videoURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        
        guard let exportSession = exportSession else {
            completion(.failure(NSError(domain: "VideoExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])))
            return
        }
        
        // 设置时间范围
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        exportSession.timeRange = timeRange
        
        // 设置输出URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("livephoto_\(UUID().uuidString).mov")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        // 导出视频片段
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed, .cancelled:
                completion(.failure(exportSession.error ?? NSError(domain: "VideoExport", code: -2, userInfo: [NSLocalizedDescriptionKey: "视频导出失败"])))
            default:
                completion(.failure(NSError(domain: "VideoExport", code: -3, userInfo: [NSLocalizedDescriptionKey: "未知错误"])))
            }
        }
    }
    
    /// 播放视频片段
    private func playVideoSegment(_ videoURL: URL) {
        let player = AVPlayer(url: videoURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    /// 保存Live Photo到相册
    private func saveLivePhotoToLibrary(videoURL: URL, timestamp: Double) {
        // 获取当前截图作为Live Photo的静态图片
        let screenshot = screenshots[currentIndex]
        guard let stillImage = screenshot.image else {
            DispatchQueue.main.async {
                self.dismissProgressAlert()
                self.showAlert(title: "保存失败", message: "无法获取静态图片")
            }
            return
        }
        
        DispatchQueue.main.async {
            self.dismissProgressAlert()
            
            // 目前iOS限制，我们保存静态图片和视频到相册
            // 真正的Live Photo需要更复杂的实现
            self.saveLivePhotoAlternative(stillImage: stillImage, videoURL: videoURL)
        }
    }
    
    /// Live Photo替代方案：分别保存图片和视频
    private func saveLivePhotoAlternative(stillImage: UIImage, videoURL: URL) {
        var savedCount = 0
        let totalCount = 2
        
        let alert = UIAlertController(title: "正在保存", message: "Live Photo将以图片+视频形式保存", preferredStyle: .alert)
        present(alert, animated: true)
        
        // 保存静态图片
        UIImageWriteToSavedPhotosAlbum(stillImage, nil, nil, nil)
        savedCount += 1
        
        // 保存视频
        UISaveVideoAtPathToSavedPhotosAlbum(videoURL.path, nil, nil, nil)
        savedCount += 1
        
        // 延迟显示完成消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true) {
                HapticFeedbackManager.shared.notificationSuccess()
                self.showAlert(title: "保存完成", message: "Live Photo已保存为图片和视频到相册")
            }
        }
    }
    
    // MARK: - 进度提示辅助方法
    
    private func showProgressAlert(title: String, message: String) {
        dismissProgressAlert() // 先关闭之前的提示
        
        progressAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // 添加活动指示器
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        
        progressAlert?.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: progressAlert!.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: progressAlert!.view.bottomAnchor, constant: -20)
        ])
        
        present(progressAlert!, animated: true)
    }
    
    private func dismissProgressAlert() {
        progressAlert?.dismiss(animated: true)
        progressAlert = nil
    }
}

// MARK: - ThumbnailCollectionViewCell
class ThumbnailCollectionViewCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let selectionIndicator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 图片视图
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        contentView.addSubview(imageView)
        
        // 选中指示器
        selectionIndicator.backgroundColor = ThemeManager.buttonPrimary
        selectionIndicator.layer.cornerRadius = 4
        selectionIndicator.isHidden = true
        contentView.addSubview(selectionIndicator)
        
        // 布局
        imageView.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            selectionIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            selectionIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 8),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    func configure(with screenshot: ScreenshotItem) {
        imageView.image = screenshot.image
    }
    
    override var isSelected: Bool {
        didSet {
            selectionIndicator.isHidden = !isSelected
            imageView.layer.borderColor = isSelected ? 
                ThemeManager.buttonPrimary.cgColor : 
                UIColor.white.withAlphaComponent(0.5).cgColor
        }
    }
}
