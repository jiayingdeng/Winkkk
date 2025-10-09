//
//  ScreenshotDetailSheet.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图详情预览Sheet - 支持左右滑动切换和选择操作
//

import UIKit
import Photos
import PhotosUI

protocol ScreenshotDetailSheetDelegate: AnyObject {
    // 纯预览Sheet只需要基础的委托方法（如果需要的话可以在这里添加）
}

class ScreenshotDetailSheet: UIViewController, PHLivePhotoViewDelegate {
    
    // MARK: - Properties
    weak var delegate: ScreenshotDetailSheetDelegate?
    private let screenshots: [ScreenshotItem]
    private var currentIndex: Int
    private let showShareButton: Bool  // 🆕 是否显示分享按钮
    private var hasScrolledToInitialIndex = false  // 🔧 标记是否已经滚动到初始位置
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let navigationBar = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton()
    private let shareButton = UIButton()
    
    // MARK: - Initialization
    init(screenshots: [ScreenshotItem], currentIndex: Int = 0, showShareButton: Bool = true) {
        self.screenshots = screenshots
        self.currentIndex = min(max(currentIndex, 0), screenshots.count - 1)
        self.showShareButton = showShareButton  // 🆕 保存配置
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupGestures()
        updateUI()
        setupThemeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 🔧 只在第一次布局时滚动到目标位置，避免显示跳跃
        if !hasScrolledToInitialIndex && scrollView.frame.width > 0 {
            scrollToCurrentIndex(animated: false)
            hasScrolledToInitialIndex = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("📱 ScreenshotDetailSheet已完全显示")
        
        // 🎯 优化的Live Photo自动播放策略
        // 使用更长的延迟确保所有Live Photo都已加载完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("🎬 视图显示后尝试自动播放Live Photos...")
            self.tryAutoPlayLivePhotos()
        }
        
        // 🎯 备用机制：再次尝试播放（防止第一次失败）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔄 备用播放机制触发...")
            self.tryAutoPlayLivePhotos()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 使用渐变背景，与截图处理中心保持一致
        view.addSubview(gradientBackgroundView)
        
        setupNavigationBar()
        setupScrollView()
        
        view.addSubview(navigationBar)
        view.addSubview(scrollView)
    }
    
    private func setupNavigationBar() {
        navigationBar.backgroundColor = .clear
        
        // 标题 - 使用主题色
        titleLabel.text = "\(currentIndex + 1) / \(screenshots.count)"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ThemeManager.overlayTextWhite
        titleLabel.textAlignment = .center
        
        // 关闭按钮 - 使用主题色
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(ThemeManager.navigationBarButtonIcon, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // 分享按钮 - 使用主题色，显式设置渲染模式
        if let shareImage = UIImage(systemName: "square.and.arrow.up")?.withRenderingMode(.alwaysTemplate) {
            shareButton.setImage(shareImage, for: .normal)
        }
        shareButton.tintColor = ThemeManager.navigationBarButtonIcon
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        shareButton.isHidden = !showShareButton  // 🆕 根据配置控制显示/隐藏
        
        navigationBar.addSubview(titleLabel)
        navigationBar.addSubview(closeButton)
        navigationBar.addSubview(shareButton)
    }
    
    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.distribution = .fillEqually  // 🔧 修复：确保每个图片视图宽度相等
        
        scrollView.addSubview(stackView)
        
        // 添加截图预览视图
        for screenshot in screenshots {
            let previewView = createImageView(for: screenshot)
            stackView.addArrangedSubview(previewView)
        }
    }
    
    
    private func createImageView(for screenshot: ScreenshotItem) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear  // 🎨 使用透明背景，展示粉紫色渐变
        
        // 设置固定宽度为屏幕宽度
        containerView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width).isActive = true
        
        // 检查是否是Live Photo
        if screenshot.isLivePhoto, 
           let videoPath = screenshot.livePhotoVideoPath,
           let identifier = screenshot.livePhotoIdentifier {
            
            // 创建Live Photo视图
            let livePhotoView = PHLivePhotoView()
            livePhotoView.contentMode = .scaleAspectFit
            livePhotoView.translatesAutoresizingMaskIntoConstraints = false
            
            // 🎯 关键配置：启用音频播放和手势识别
            livePhotoView.isMuted = false
            
            // 确保手势识别器已启用（用于长按播放）
            livePhotoView.playbackGestureRecognizer.isEnabled = true
            print("✅ Live Photo手势识别器已启用")
            
            // 设置委托来监听播放状态
            livePhotoView.delegate = self
            
            // 🎯 添加标签以便后续查找
            livePhotoView.tag = 9999
            
            // 异步加载Live Photo - 直接使用原始文件，绕过LivePhotoMaker的二次处理
            Task {
                do {
                    let livePhoto = try await loadLivePhotoDirectly(
                        imageURL: screenshot.displayImagePath,
                        videoURL: videoPath
                    )
                    
                    await MainActor.run {
                        livePhotoView.livePhoto = livePhoto
                        print("📸 Live Photo已加载到视图")
                        
                        // 🎯 优化的自动播放逻辑
                        // 确保视图完全加载后再播放，使用更长的延迟确保稳定性
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            // 再次确认Live Photo数据和视图状态
                            if livePhotoView.livePhoto != nil && 
                               livePhotoView.superview != nil &&
                               livePhotoView.window != nil {
                                self.startLivePhotoAutoplay(livePhotoView)
                            }
                        }
                    }
                } catch {
                    print("❌ Live Photo加载失败: \(error)")
                    // 如果Live Photo加载失败，显示静态图片
                    await MainActor.run {
                        self.setupStaticImageView(in: containerView, with: screenshot)
                    }
                }
            }
            
            // 添加Live Photo标识
            let livePhotoIndicator = createLivePhotoIndicator()
            
            containerView.addSubview(livePhotoView)
            containerView.addSubview(livePhotoIndicator)
            
            NSLayoutConstraint.activate([
                livePhotoView.topAnchor.constraint(equalTo: containerView.topAnchor),
                livePhotoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                livePhotoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                livePhotoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                
                livePhotoIndicator.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 16),
                livePhotoIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
            ])
        } else {
            // 创建普通图片视图
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.image = screenshot.image
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        return containerView
    }
    
    private func createLivePhotoIndicator() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = ThemeManager.overlayMaskBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = "LIVE"
        iconLabel.textColor = ThemeManager.buttonTextOnPrimary  // 使用主题色（始终白色）
        iconLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let circleView = UIView()
        circleView.backgroundColor = .clear
        circleView.layer.borderColor = ThemeManager.buttonTextOnPrimary.cgColor  // 使用主题色（始终白色）
        circleView.layer.borderWidth = 1.5
        circleView.layer.cornerRadius = 6
        circleView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(iconLabel)
        containerView.addSubview(circleView)
        
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: 60),
            containerView.heightAnchor.constraint(equalToConstant: 32),
            
            iconLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            iconLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            circleView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            circleView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            circleView.widthAnchor.constraint(equalToConstant: 12),
            circleView.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        return containerView
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // 导航栏
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: 44),
            
            // 导航栏内容
            titleLabel.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            
            closeButton.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            shareButton.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor, constant: -16),
            shareButton.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // StackView
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // 🔧 关键修复：设置stackView的宽度以启用水平滚动
            stackView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * CGFloat(screenshots.count))
        ])
    }
    
    private func setupGestures() {
        // 双击缩放手势（可选实现）
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        
        let currentScreenshot = screenshots[currentIndex]
        
        // 根据截图类型准备分享内容
        var activityItems: [Any] = []
        
        if currentScreenshot.isLivePhoto,
           let livePhotoVideoPath = currentScreenshot.livePhotoVideoPath,
           FileManager.default.fileExists(atPath: livePhotoVideoPath.path) {
            // Live Photo 分享视频文件
            activityItems.append(livePhotoVideoPath)
        } else if let image = currentScreenshot.image {
            // 普通截图分享图片
            activityItems.append(image)
        } else {
            // 无法加载图片，显示错误提示
            let alert = UIAlertController(
                title: "分享失败",
                message: "无法加载当前图片",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        // 创建分享 Sheet
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // iPad 适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    
    
    @objc private func doubleTapped() {
        // TODO: 实现双击缩放功能
    }
    
    // MARK: - Helper Methods
    private func updateUI() {
        // 更新标题
        titleLabel.text = "\(currentIndex + 1) / \(screenshots.count)"
    }
    
    private func scrollToCurrentIndex(animated: Bool) {
        let offsetX = CGFloat(currentIndex) * scrollView.frame.width
        scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
    }
    
    // MARK: - Cleanup Methods
    
    // MARK: - Live Photo Auto Play
    
    /// 尝试自动播放当前可见的Live Photo
    private func tryAutoPlayLivePhotos() {
        print("🎯 尝试自动播放Live Photo...")
        
        // 遍历所有子视图寻找Live Photo视图
        for subview in stackView.arrangedSubviews {
            if let containerView = subview as? UIView {
                for childView in containerView.subviews {
                    if let livePhotoView = childView as? PHLivePhotoView,
                       livePhotoView.livePhoto != nil {
                        print("🔍 找到Live Photo视图，尝试播放...")
                        livePhotoView.startPlayback(with: .full)
                        print("🎥 Live Photo自动播放已触发")
                        // 只播放第一个找到的Live Photo
                        return
                    }
                }
            }
        }
        print("❌ 未找到可播放的Live Photo视图")
    }
    
    // MARK: - PHLivePhotoViewDelegate
    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        let styleString = playbackStyle == .full ? "完整播放" : "提示播放"
        print("🎬 Live Photo开始播放 - 风格: \(styleString)")
        
        // 🎯 添加视觉反馈：Live Photo开始播放时稍微缩放
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction]) {
            livePhotoView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                livePhotoView.transform = .identity
            }
        }
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        let styleString = playbackStyle == .full ? "完整播放" : "提示播放"
        print("⏹️ Live Photo播放结束 - 风格: \(styleString)")
    }
    
    /// 🎯 新增：手动触发Live Photo播放的方法
    private func manuallyTriggerLivePhotoPlayback() {
        print("👆 手动触发Live Photo播放...")
        
        // 方法1：通过tag查找
        if let livePhotoView = view.viewWithTag(9999) as? PHLivePhotoView {
            triggerLivePhotoPlayback(livePhotoView)
            return
        }
        
        // 方法2：遍历查找
        findAndTriggerLivePhotoInSubviews(stackView)
    }
    
    /// 递归查找并触发Live Photo播放
    private func findAndTriggerLivePhotoInSubviews(_ parentView: UIView) {
        for subview in parentView.subviews {
            if let livePhotoView = subview as? PHLivePhotoView,
               livePhotoView.livePhoto != nil {
                triggerLivePhotoPlayback(livePhotoView)
                return
            }
            // 递归查找子视图
            findAndTriggerLivePhotoInSubviews(subview)
        }
    }
    
    /// 优化的Live Photo自动播放方法
    private func startLivePhotoAutoplay(_ livePhotoView: PHLivePhotoView) {
        print("🎬 开始Live Photo自动播放...")
        
        // 验证必要条件
        guard livePhotoView.livePhoto != nil,
              livePhotoView.superview != nil,
              livePhotoView.window != nil else {
            print("❌ Live Photo播放条件不满足")
            return
        }
        
        // 🎯 关键修复：使用完整播放模式而不是hint模式
        print("🎥 触发Live Photo完整播放...")
        livePhotoView.startPlayback(with: .full)
        
        // 🎯 备用方案：如果完整播放失败，0.5秒后再次尝试
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if livePhotoView.livePhoto != nil && livePhotoView.superview != nil {
                print("🔄 备用播放尝试...")
                livePhotoView.startPlayback(with: .full)
            }
        }
        
        print("✅ Live Photo自动播放已启动（full模式）")
    }
    
    /// 触发Live Photo播放的核心方法（保留用于手动触发）
    private func triggerLivePhotoPlayback(_ livePhotoView: PHLivePhotoView) {
        print("🔍 手动触发Live Photo播放")
        
        guard livePhotoView.livePhoto != nil else {
            print("❌ Live Photo数据不存在")
            return
        }
        
        // 手动触发时使用完整播放模式
        livePhotoView.startPlayback(with: .full)
        print("🎥 Live Photo手动播放已启动（full模式）")
    }
    
    /// 模拟Live Photo手势触发
    private func simulateLivePhotoGesture(_ livePhotoView: PHLivePhotoView) {
        print("👆 模拟Live Photo手势触发...")
        
        // 创建触摸事件
        let center = CGPoint(x: livePhotoView.bounds.midX, y: livePhotoView.bounds.midY)
        
        // 模拟长按手势
        let longPress = UILongPressGestureRecognizer()
        longPress.minimumPressDuration = 0.1
        
        // 手动触发手势识别器
        if livePhotoView.playbackGestureRecognizer.isEnabled {
            // 尝试通过反射或其他方式触发播放
            livePhotoView.playbackGestureRecognizer.isEnabled = false
            livePhotoView.playbackGestureRecognizer.isEnabled = true
            print("🔄 重置了手势识别器状态")
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 清理委托引用
        for subview in stackView.arrangedSubviews {
            if let livePhotoView = subview as? PHLivePhotoView {
                livePhotoView.delegate = nil
            }
        }
    }
    
    // MARK: - Theme Management
    
    /// 设置主题观察者
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: .themeDidChange,
            object: nil
        )
    }
    
    /// 处理主题切换
    @objc private func handleThemeChange() {
        updateNavigationBarColors()
    }
    
    /// 更新导航栏颜色
    private func updateNavigationBarColors() {
        titleLabel.textColor = ThemeManager.overlayTextWhite
        closeButton.setTitleColor(ThemeManager.navigationBarButtonIcon, for: .normal)
        shareButton.tintColor = ThemeManager.navigationBarButtonIcon
    }
    
    /// 设置静态图片视图的辅助方法
    private func setupStaticImageView(in containerView: UIView, with screenshot: ScreenshotItem) {
        // 清除现有子视图
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        // 创建静态图片视图
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear  // 🎨 使用透明背景，展示粉紫色渐变
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 加载图片
        if let image = UIImage(contentsOfFile: screenshot.displayImagePath.path) {
            imageView.image = image
        }
        
        containerView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    // MARK: - Live Photo Direct Loading
    
    /// 直接加载Live Photo，绕过LivePhotoMaker的二次处理
    /// 这个方法直接使用原始的图片和视频文件URL，避免破坏Live Photo元数据
    private func loadLivePhotoDirectly(imageURL: URL, videoURL: URL) async throws -> PHLivePhoto {
        print("📸 直接加载Live Photo（绕过LivePhotoMaker）")
        print("   图片URL: \(imageURL)")
        print("   视频URL: \(videoURL)")
        
        // 验证文件存在性
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw NSError(domain: "LivePhotoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片文件不存在"])
        }
        
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw NSError(domain: "LivePhotoError", code: -2, userInfo: [NSLocalizedDescriptionKey: "视频文件不存在"])
        }
        
        // 使用原始文件直接创建Live Photo请求
        return try await withCheckedThrowingContinuation { continuation in
            PHLivePhoto.request(withResourceFileURLs: [imageURL, videoURL],
                              placeholderImage: nil,
                              targetSize: CGSize.zero,
                              contentMode: .aspectFit,
                              resultHandler: { livePhoto, info in
                // 检查是否是降级（预览）图像，如果是，则忽略并等待最终版本
                if let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool, isDegraded {
                    print("🏞️ 收到降级版Live Photo，忽略...")
                    return
                }
                
                if let livePhoto = livePhoto {
                    print("✅ Live Photo直接加载成功（最终版）")
                    continuation.resume(returning: livePhoto)
                } else {
                    // 如果最终获取失败，则抛出错误
                    let error = info[PHLivePhotoInfoErrorKey] as? Error ??
                               NSError(domain: "LivePhotoError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Live Photo加载失败"])
                    print("❌ Live Photo直接加载失败: \(error)")
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    
}

// MARK: - UIScrollViewDelegate
extension ScreenshotDetailSheet: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.frame.width
        let newIndex = Int(scrollView.contentOffset.x / pageWidth)
        
        if newIndex != currentIndex && newIndex >= 0 && newIndex < screenshots.count {
            currentIndex = newIndex
            updateUI()
        }
    }
}
