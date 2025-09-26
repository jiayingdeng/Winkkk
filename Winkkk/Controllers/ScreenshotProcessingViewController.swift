//
//  ScreenshotProcessingViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图处理中心 - 批量操作和功能选择界面
//

import UIKit
import AVFoundation
import Photos
import PhotosUI

class ScreenshotProcessingViewController: UIViewController {
    
    // MARK: - Properties
    private let screenshots: [ScreenshotItem]
    private let mode: CaptureMode
    private var processingOptions: [ProcessingOption] = []
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 头部区域
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    
    // 预览区域
    private let previewContainerView = UIView()
    private let collectionView: UICollectionView
    private let collectionFlowLayout = UICollectionViewFlowLayout()
    
    // 操作选项区域
    private let optionsTableView = UITableView()
    
    // MARK: - Initialization
    init(screenshots: [ScreenshotItem], mode: CaptureMode) {
        self.screenshots = screenshots
        self.mode = mode
        
        // 配置集合视图布局
        collectionFlowLayout.scrollDirection = .horizontal
        collectionFlowLayout.itemSize = CGSize(width: 60, height: 60)
        collectionFlowLayout.minimumInteritemSpacing = 8
        collectionFlowLayout.minimumLineSpacing = 8
        collectionFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionFlowLayout)
        
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
        setupProcessingOptions()
        configureNavigationBar()
        
        // 进入处理中心的触感反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 头部区域
        setupHeaderView()
        
        // 预览区域
        setupPreviewArea()
        
        // 操作选项表格
        setupOptionsTableView()
        
        // 添加到内容视图
        contentView.addSubview(headerView)
        contentView.addSubview(previewContainerView)
        contentView.addSubview(optionsTableView)
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // 标题
        titleLabel.font = ThemeManager.titleFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)
        
        // 数量标签
        countLabel.font = ThemeManager.captionFont
        countLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        countLabel.textAlignment = .center
        headerView.addSubview(countLabel)
        
        // 根据模式设置标题
        switch mode {
        case .stillImage:
            titleLabel.text = "截图处理中心"
            countLabel.text = "已选择 \(screenshots.count) 张截图"
        case .livePhoto:
            titleLabel.text = "Live Photo处理中心"
            countLabel.text = "已选择 \(screenshots.count) 个Live Photo"
        }
    }
    
    private func setupPreviewArea() {
        previewContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        previewContainerView.layer.cornerRadius = ThemeManager.standardCornerRadius
        previewContainerView.clipsToBounds = true
        
        // 集合视图
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // 注册单元格
        collectionView.register(ProcessingThumbnailCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
        
        previewContainerView.addSubview(collectionView)
    }
    
    private func setupOptionsTableView() {
        optionsTableView.backgroundColor = .clear
        optionsTableView.separatorStyle = .none
        optionsTableView.dataSource = self
        optionsTableView.delegate = self
        
        // 注册单元格
        optionsTableView.register(ProcessingOptionCell.self, forCellReuseIdentifier: "OptionCell")
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainerView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        optionsTableView.translatesAutoresizingMaskIntoConstraints = false
        
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
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 头部区域
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 80),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 40),
            
            // 数量标签
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            countLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 预览区域
            previewContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            previewContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewContainerView.heightAnchor.constraint(equalToConstant: 80),
            
            // 集合视图
            collectionView.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -10),
            
            // 操作选项表格
            optionsTableView.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: 20),
            optionsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            optionsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            optionsTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            optionsTableView.heightAnchor.constraint(equalToConstant: CGFloat(processingOptions.count * 60))
        ])
    }
    
    private func configureNavigationBar() {
        title = mode.displayName + "处理"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
    
    // MARK: - Processing Options Setup
    private func setupProcessingOptions() {
        switch mode {
        case .stillImage:
            processingOptions = [
                ProcessingOption(
                    title: "✨ 开始新的创作",
                    description: "返回录制页面重新截图",
                    icon: "plus.circle.fill",
                    action: { [weak self] in self?.startNewCreation() }
                ),
                ProcessingOption(
                    title: "✨ 批量画质修复",
                    description: "AI智能修复图片质量",
                    icon: "wand.and.stars",
                    action: { [weak self] in self?.showBatchImageEnhancement() }
                ),
                ProcessingOption(
                    title: "🧩 创建拼图",
                    description: "将多张截图制作成拼图",
                    icon: "square.grid.3x3",
                    action: { [weak self] in self?.showCollageCreation() }
                ),
                ProcessingOption(
                    title: "📤 批量分享",
                    description: "一键分享所有图片",
                    icon: "square.and.arrow.up",
                    action: { [weak self] in self?.showBatchShare() }
                )
            ]
            
        case .livePhoto:
            processingOptions = [
                ProcessingOption(
                    title: "✨ 开始新的创作",
                    description: "返回录制页面重新制作Live Photo",
                    icon: "plus.circle.fill",
                    action: { [weak self] in self?.startNewCreation() }
                ),
                ProcessingOption(
                    title: "▶️ 播放Live Photo",
                    description: "预览Live Photo动画效果",
                    icon: "play.circle",
                    action: { [weak self] in self?.playLivePhotos() }
                ),
                // TODO: 临时隐藏设置封面功能 - 等功能完成后恢复
                // ProcessingOption(
                //     title: "🖼️ 设置封面",
                //     description: "选择Live Photo的封面帧",
                //     icon: "photo",
                //     action: { [weak self] in self?.setCoverFrame() }
                // ),
                ProcessingOption(
                    title: "📤 分享Live Photo",
                    description: "分享Live Photo到其他应用",
                    icon: "square.and.arrow.up",
                    action: { [weak self] in self?.shareLivePhotos() }
                )
            ]
        }
        
        // 更新表格高度约束
        DispatchQueue.main.async {
            if let heightConstraint = self.optionsTableView.constraints.first(where: { $0.firstAttribute == .height }) {
                heightConstraint.constant = CGFloat(self.processingOptions.count * 60)
            }
        }
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension ScreenshotProcessingViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return screenshots.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThumbnailCell", for: indexPath) as! ProcessingThumbnailCell
        let screenshot = screenshots[indexPath.item]
        cell.configure(with: screenshot)
        return cell
    }
}

// MARK: - UICollectionViewDelegate  
extension ScreenshotProcessingViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let screenshot = screenshots[indexPath.item]
        
        // 弹出Sheet查看大图
        let viewSheet = ScreenshotViewSheet(screenshot: screenshot)
        viewSheet.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            viewSheet.sheetPresentationController?.detents = [.medium(), .large()]
        }
        present(viewSheet, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ScreenshotProcessingViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return processingOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath) as! ProcessingOptionCell
        let option = processingOptions[indexPath.row]
        cell.configure(with: option)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ScreenshotProcessingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let option = processingOptions[indexPath.row]
        HapticFeedbackManager.shared.buttonTap()
        
        // 执行对应的操作
        option.action()
    }
}

// MARK: - Processing Actions
extension ScreenshotProcessingViewController {
    
    private func showBatchImageEnhancement() {
        print("🎨 批量画质修复")
        
        // 检查是否有图片可以处理
        guard !screenshots.isEmpty else {
            showAlert(title: "无法处理", message: "没有可用的图片进行画质修复")
            return
        }
        
        // 如果只有一张图片，直接跳转到单图修复界面
        if screenshots.count == 1 {
            guard let firstImage = screenshots.first?.image else {
                showAlert(title: "错误", message: "无法加载图片")
                return
            }
            
            // 触觉反馈
            HapticFeedbackManager.shared.buttonTap()
            
            // 跳转到单图画质修复页面
            let imageEnhanceVC = ImageEnhanceViewController(
                image: firstImage,
                timestamp: Date().timeIntervalSince1970
            )
            navigationController?.pushViewController(imageEnhanceVC, animated: true)
            
        } else {
            // 多张图片，跳转到批量修复界面
            // 触觉反馈
            HapticFeedbackManager.shared.buttonTap()
            
            // 跳转到批量画质修复页面
            let batchEnhanceVC = BatchImageEnhanceViewController(screenshots: screenshots)
            navigationController?.pushViewController(batchEnhanceVC, animated: true)
        }
    }
    
    private func showCollageCreation() {
        print("🧩 创建拼图")
        
        // 检查是否是普通截图模式且有多张图片
        guard mode == .stillImage && screenshots.count > 1 else {
            showAlert(title: "无法创建拼图", message: "拼图功能仅支持多张普通截图")
            return
        }
        
        // 提取所有图片
        let images = screenshots.compactMap { $0.image }
        guard images.count == screenshots.count else {
            showAlert(title: "错误", message: "部分图片无法加载")
            return
        }
        
        // 触觉反馈
        HapticFeedbackManager.shared.buttonTap()
        
        // 跳转到拼图创建页面
        let collageVC = CollageViewController(images: images)
        navigationController?.pushViewController(collageVC, animated: true)
    }
    
    
    
    // MARK: - 暂时注释的功能
    /*
    private func showBatchResize() {
        print("📏 批量调整尺寸")
        // TODO: 实现批量尺寸调整功能
    }
    
    private func showBatchWatermark() {
        print("🏷️ 批量添加水印")
        // TODO: 实现批量水印功能
    }
    
    private func saveBatchToPhotos() {
        print("💾 保存到相册")
        // TODO: 实现批量保存到相册功能 (前面步骤已保存，此处重复)
    }
    */
    
    private func showBatchShare() {
        print("📤 批量分享")
        
        // 检查是否有图片可以分享
        guard !screenshots.isEmpty else {
            showAlert(title: "无法分享", message: "没有可用的图片进行分享")
            return
        }
        
        // 获取第一张图片作为主要分享对象
        guard let firstImage = screenshots.first?.image else {
            showAlert(title: "错误", message: "无法加载图片")
            return
        }
        
        // 触觉反馈
        HapticFeedbackManager.shared.buttonTap()
        
        // 跳转到分享页面
        let shareVC = ShareViewController(
            image: firstImage,
            originalImage: firstImage
        )
        navigationController?.pushViewController(shareVC, animated: true)
    }
    
    private func playLivePhotos() {
        print("▶️ 播放Live Photo")
        
        // 获取Live Photo类型的截图
        let livePhotos = screenshots.filter { $0.mode == .livePhoto }
        guard !livePhotos.isEmpty else {
            showAlert(title: "提示", message: "没有Live Photo可以播放")
            return
        }
        
        // 使用现有的截图详情界面来播放Live Photo
        let detailSheet = ScreenshotDetailSheet(screenshots: livePhotos, currentIndex: 0)
        present(detailSheet, animated: true)
    }
    
    private func setCoverFrame() {
        print("🖼️ 设置封面")
        
        // 获取Live Photo类型的截图
        let livePhotos = screenshots.filter { $0.mode == .livePhoto }
        guard !livePhotos.isEmpty else {
            showAlert(title: "提示", message: "没有Live Photo可以设置封面")
            return
        }
        
        // 显示操作指南
        let alert = UIAlertController(
            title: "设置Live Photo封面",
            message: "在预览界面中，长按Live Photo可以播放动画，您可以选择喜欢的帧作为封面。\n\n注意：封面设置功能正在开发中，当前可以预览Live Photo效果。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "预览Live Photo", style: .default) { _ in
            // 触觉反馈
            HapticFeedbackManager.shared.buttonTap()
            
            // 跳转到详情界面预览
            let detailSheet = ScreenshotDetailSheet(screenshots: livePhotos, currentIndex: 0)
            self.present(detailSheet, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func shareLivePhotos() {
        print("📤 分享Live Photo")
        
        // 获取Live Photo类型的截图
        let livePhotos = screenshots.filter { $0.mode == .livePhoto }
        guard !livePhotos.isEmpty else {
            showAlert(title: "提示", message: "没有Live Photo可以分享")
            return
        }
        
        // 检查是否有有效的Live Photo
        let validLivePhotos = livePhotos.compactMap { screenshot -> URL? in
            guard let livePhotoVideoPath = screenshot.livePhotoVideoPath,
                  FileManager.default.fileExists(atPath: livePhotoVideoPath.path) else {
                return nil
            }
            return livePhotoVideoPath
        }
        
        guard !validLivePhotos.isEmpty else {
            showAlert(title: "错误", message: "没有可用的Live Photo文件")
            return
        }
        
        // 创建分享界面
        let activityVC = UIActivityViewController(
            activityItems: validLivePhotos,
            applicationActivities: nil
        )
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    /// 开始新的创作 - 返回录制页面
    private func startNewCreation() {
        print("✨ 开始新的创作")
        
        // 检查是否有内容需要放弃
        guard !screenshots.isEmpty else {
            // 没有内容，直接返回
            navigateBackToVideoPlayer()
            return
        }
        
        // 有内容，显示确认对话框
        let modeText = mode == .livePhoto ? "Live Photo" : "截图"
        let alert = UIAlertController(
            title: "开始新的创作",
            message: "当前有 \(screenshots.count) 张未保存的\(modeText)，确定要放弃并开始新的创作吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定开始", style: .destructive) { [weak self] _ in
            self?.clearCurrentContentAndNavigateBack()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    /// 清空当前内容并返回录制页面
    private func clearCurrentContentAndNavigateBack() {
        // 触觉反馈
        HapticFeedbackManager.shared.lightImpact()
        
        // 清空当前截图数据
        // 注意：这里不能直接调用screenshotManager.clearAllScreenshots()
        // 因为ScreenshotProcessingViewController是独立的界面，有自己的screenshots数组
        // 需要在导航回去时清空VideoPlayerViewController中的数据
        
        navigateBackToVideoPlayer()
    }
    
    /// 导航回到录制页面
    private func navigateBackToVideoPlayer() {
        // 方法1：如果是从VideoPlayerViewController模态呈现的，直接dismiss
        if let navigationController = self.navigationController,
           let presentingVC = navigationController.presentingViewController {
            
            // 检查presenting view controller是否是VideoPlayerViewController
            if let videoPlayerVC = presentingVC as? VideoPlayerViewController {
                // 清空VideoPlayerViewController中的截图数据
                clearVideoPlayerScreenshots(videoPlayerVC)
                
                dismiss(animated: true) {
                    print("✨ 已返回到录制页面，准备开始新的创作")
                }
                return
            }
            
            // 检查是否是嵌套在NavigationController中的VideoPlayerViewController
            if let navController = presentingVC as? UINavigationController,
               let videoPlayerVC = navController.topViewController as? VideoPlayerViewController {
                clearVideoPlayerScreenshots(videoPlayerVC)
                
                dismiss(animated: true) {
                    print("✨ 已返回到录制页面，准备开始新的创作")
                }
                return
            }
        }
        
        // 方法2：如果navigation stack中有VideoPlayerViewController，pop回去
        if let navigationController = self.navigationController {
            for viewController in navigationController.viewControllers {
                if let videoPlayerVC = viewController as? VideoPlayerViewController {
                    clearVideoPlayerScreenshots(videoPlayerVC)
                    navigationController.popToViewController(videoPlayerVC, animated: true)
                    return
                }
            }
        }
        
        // 方法3：兜底策略 - 直接dismiss并重置模式
        // 清空截图数据和重置模式
        ScreenshotManager.shared.clearAllScreenshots()
        TimeSequenceModeManager.shared.switchToNormalMode()
        
        dismiss(animated: true) {
            print("✨ 已返回，重置为普通录像模式，准备开始新的创作")
        }
    }
    
    /// 清空VideoPlayerViewController中的截图数据并重置到普通录像模式
    private func clearVideoPlayerScreenshots(_ videoPlayerVC: VideoPlayerViewController) {
        // 通过ScreenshotManager清空数据
        // 注意：这里假设VideoPlayerViewController使用的是同一个ScreenshotManager实例
        let screenshotManager = ScreenshotManager.shared
        screenshotManager.clearAllScreenshots()
        
        // 🎯 关键修复：确保返回到普通录像模式
        // 当用户点击"开始新的创作"时，应该回到普通录像模式，而不是保持时间序列模式
        TimeSequenceModeManager.shared.switchToNormalMode()
        
        print("✨ 已清空录制页面的截图数据，重置为普通录像模式，准备新的创作")
    }
    
    /// 显示提示对话框
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ProcessingOption
struct ProcessingOption {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
}

// MARK: - ProcessingOptionCell
class ProcessingOptionCell: UITableViewCell {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let arrowImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeManager.buttonPrimary
        contentView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.buttonFont
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)
        
        // 描述
        descriptionLabel.font = ThemeManager.captionFont
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        contentView.addSubview(descriptionLabel)
        
        // 箭头
        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = UIColor.white.withAlphaComponent(0.5)
        arrowImageView.contentMode = .scaleAspectFit
        contentView.addSubview(arrowImageView)
    }
    
    private func setupConstraints() {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 图标
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),
            
            // 标题
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -16),
            
            // 描述
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // 箭头
            arrowImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            arrowImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func configure(with option: ProcessingOption) {
        iconImageView.image = UIImage(systemName: option.icon)
        titleLabel.text = option.title
        descriptionLabel.text = option.description
        
        // 使用默认样式
        backgroundColor = .clear
        layer.cornerRadius = 0
        layer.borderWidth = 0
        layer.shadowOpacity = 0
        
        // 设置默认图标和文字颜色
        iconImageView.tintColor = ThemeManager.buttonPrimary
        titleLabel.font = ThemeManager.buttonFont
        titleLabel.textColor = .white
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.7)
    }
}


// MARK: - ProcessingThumbnailCell
class ProcessingThumbnailCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let overlayView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // 图片视图
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        contentView.addSubview(imageView)
        
        // 覆盖层（可用于选择状态等）
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlayView.layer.cornerRadius = 8
        overlayView.isHidden = true
        contentView.addSubview(overlayView)
    }
    
    private func setupConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with screenshot: ScreenshotItem) {
        imageView.image = screenshot.image
    }
}
