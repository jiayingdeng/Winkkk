//
//  ScreenshotPreviewViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图预览视图控制器 - 显示截图并提供操作选项
//

import UIKit

class ScreenshotPreviewViewController: UIViewController {
    
    // MARK: - Properties
    private let image: UIImage
    private let timestamp: Double
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 图像显示
    private let imageView = UIImageView()
    private let imageContainerView = UIView()
    
    // 操作按钮面板
    private let actionPanelBlurView = BlurEffectView(style: .regular, intensity: 0.9)
    private let enhanceButton = UIButton()
    private let saveButton = UIButton()
    private let shareButton = UIButton()
    
    // 图像信息
    private let infoLabel = UILabel()
    
    // MARK: - Initialization
    init(image: UIImage, timestamp: Double) {
        self.image = image
        self.timestamp = timestamp
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
        configureImage()
        
        // 成功截图的触感反馈
        HapticFeedbackManager.shared.screenshotSuccess()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 显示截图成功动画
        showScreenshotSuccessAnimation()
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
        
        // 操作面板
        setupActionPanel()
        
        // 导航栏
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        title = "截图预览"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
    
    private func setupImageView() {
        imageContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        imageContainerView.layer.cornerRadius = ThemeManager.standardCornerRadius
        imageContainerView.clipsToBounds = true
        contentView.addSubview(imageContainerView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageContainerView.addSubview(imageView)
        
        // 添加双击缩放手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTapGesture)
        imageView.isUserInteractionEnabled = true
        
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
    
    private func setupActionPanel() {
        actionPanelBlurView.layer.cornerRadius = ThemeManager.largeCornerRadius
        actionPanelBlurView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(actionPanelBlurView)
        
        // 画质修复按钮
        setupEnhanceButton()
        
        // 保存按钮
        setupSaveButton()
        
        // 分享按钮
        setupShareButton()
        
        // 添加到面板
        actionPanelBlurView.contentView.addSubview(enhanceButton)
        actionPanelBlurView.contentView.addSubview(saveButton)
        actionPanelBlurView.contentView.addSubview(shareButton)
    }
    
    private func setupEnhanceButton() {
        enhanceButton.setTitle("✨ 画质修复", for: .normal)
        enhanceButton.setTitleColor(.white, for: .normal)
        enhanceButton.backgroundColor = ThemeManager.buttonPrimary
        enhanceButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        enhanceButton.titleLabel?.font = ThemeManager.buttonFont
        
        // 添加渐变效果
        let gradientLayer = ThemeManager.buttonGradient
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        gradientLayer.cornerRadius = ThemeManager.standardCornerRadius
        enhanceButton.layer.insertSublayer(gradientLayer, at: 0)
        
        enhanceButton.addTarget(self, action: #selector(enhanceButtonTapped), for: .touchUpInside)
        enhanceButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        enhanceButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    private func setupSaveButton() {
        saveButton.setTitle("💾 保存", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.success
        saveButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        saveButton.titleLabel?.font = ThemeManager.buttonFont
        
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        saveButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    private func setupShareButton() {
        shareButton.setTitle("📤 分享", for: .normal)
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.backgroundColor = ThemeManager.cardBackground
        shareButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        shareButton.titleLabel?.font = ThemeManager.buttonFont
        
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        shareButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        actionPanelBlurView.translatesAutoresizingMaskIntoConstraints = false
        enhanceButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor, multiplier: 1.2),
            
            // 图像视图
            imageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            
            // 信息标签
            infoLabel.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 16),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            infoLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // 操作面板
            actionPanelBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionPanelBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionPanelBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            actionPanelBlurView.heightAnchor.constraint(equalToConstant: 120 + view.safeAreaInsets.bottom),
            
            // 画质修复按钮（主要按钮，居中显示）
            enhanceButton.centerXAnchor.constraint(equalTo: actionPanelBlurView.centerXAnchor),
            enhanceButton.topAnchor.constraint(equalTo: actionPanelBlurView.topAnchor, constant: 20),
            enhanceButton.widthAnchor.constraint(equalToConstant: 200),
            enhanceButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 保存按钮
            saveButton.topAnchor.constraint(equalTo: enhanceButton.bottomAnchor, constant: 12),
            saveButton.leadingAnchor.constraint(equalTo: actionPanelBlurView.leadingAnchor, constant: 30),
            saveButton.widthAnchor.constraint(equalTo: actionPanelBlurView.widthAnchor, multiplier: 0.4),
            saveButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 分享按钮
            shareButton.topAnchor.constraint(equalTo: enhanceButton.bottomAnchor, constant: 12),
            shareButton.trailingAnchor.constraint(equalTo: actionPanelBlurView.trailingAnchor, constant: -30),
            shareButton.widthAnchor.constraint(equalTo: actionPanelBlurView.widthAnchor, multiplier: 0.4),
            shareButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func configureImage() {
        imageView.image = image
        
        // 设置图像信息
        let imageSize = image.size
        let timestamp = String.formatTime(self.timestamp)
        infoLabel.text = "尺寸: \(Int(imageSize.width)) × \(Int(imageSize.height))\n时间: \(timestamp)"
    }
    
    // MARK: - Animations
    private func showScreenshotSuccessAnimation() {
        // 显示成功动画
        AnimationManager.shared.showHeartSuccessAnimation(in: view, at: imageView.center)
        
        // 图像从小到大的出现动画
        imageView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        imageView.alpha = 0
        
        UIView.animate(withDuration: 0.6, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.imageView.transform = .identity
            self.imageView.alpha = 1
        }
        
        // 按钮依次出现
        enhanceButton.alpha = 0
        saveButton.alpha = 0
        shareButton.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0.5) {
            self.enhanceButton.alpha = 1
        }
        
        UIView.animate(withDuration: 0.3, delay: 0.6) {
            self.saveButton.alpha = 1
        }
        
        UIView.animate(withDuration: 0.3, delay: 0.7) {
            self.shareButton.alpha = 1
        }
    }
    
    // MARK: - Actions
    @objc private func enhanceButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        
        let enhanceVC = ImageEnhanceViewController(image: image, timestamp: timestamp)
        let navController = UINavigationController(rootViewController: enhanceVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    @objc private func saveButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        
        // 保存图片到相册
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func shareButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        
        let shareVC = ShareViewController(image: image, originalImage: image)
        let navController = UINavigationController(rootViewController: shareVC)
        present(navController, animated: true)
    }
    
    @objc private func cancelButtonTapped() {
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
            let location = gesture.location(in: imageView)
            let rect = CGRect(x: location.x - 50, y: location.y - 50, width: 100, height: 100)
            scrollView.zoom(to: rect, animated: true)
        }
    }
    
    // MARK: - Save Callback
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            HapticFeedbackManager.shared.notificationError()
            
            let alert = UIAlertController(
                title: "保存失败",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        } else {
            HapticFeedbackManager.shared.notificationSuccess()
            
            let alert = UIAlertController(
                title: "保存成功",
                message: "图片已保存到相册",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension ScreenshotPreviewViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 保持图像居中
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                   y: scrollView.contentSize.height * 0.5 + offsetY)
    }
}
