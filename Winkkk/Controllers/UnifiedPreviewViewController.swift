//
//  UnifiedPreviewViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  统一预览控制器 - 会话隔离设计简化版
//

import UIKit

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
        // TODO: 集成现有的ImageEnhanceViewController
        print("📸 单图画质修复: \(screenshot.timestamp)")
    }
    
    @objc private func enhanceAllImages() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 集成批量修复功能
        print("📸 批量画质修复: \(screenshots.count)张")
    }
    
    @objc private func createCollage() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 集成拼图功能
        print("🧩 创建拼图: \(screenshots.count)张")
    }
    
    // MARK: - Actions - Live Photo模式
    @objc private func playLivePhoto() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现Live Photo播放
        print("▶️ 播放Live Photo")
    }
    
    @objc private func playCurrentLivePhoto() {
        HapticFeedbackManager.shared.buttonTap()
        let screenshot = screenshots[currentIndex]
        // TODO: 实现当前Live Photo播放
        print("▶️ 播放当前Live Photo: \(screenshot.timestamp)")
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
        guard let image = screenshot.image else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func saveAllImages() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现批量保存
        print("💾 批量保存: \(screenshots.count)张")
    }
    
    @objc private func saveSingleLivePhoto() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现Live Photo保存
        print("💾 保存Live Photo")
    }
    
    @objc private func saveAllLivePhotos() {
        HapticFeedbackManager.shared.buttonTap()
        // TODO: 实现批量Live Photo保存
        print("💾 批量保存Live Photo")
    }
    
    @objc private func shareSingleImage() {
        HapticFeedbackManager.shared.buttonTap()
        let screenshot = screenshots[currentIndex]
        guard let image = screenshot.image else { return }
        
        let shareVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        present(shareVC, animated: true)
    }
    
    @objc private func shareAllImages() {
        HapticFeedbackManager.shared.buttonTap()
        let images = screenshots.compactMap { $0.image }
        let shareVC = UIActivityViewController(activityItems: images, applicationActivities: nil)
        present(shareVC, animated: true)
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
