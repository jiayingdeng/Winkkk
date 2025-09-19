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
                // 🌟 时间序列模式 - 特色功能，突出显示
                ProcessingOption(
                    title: "⏰ 时间序列模式",
                    description: "将视频关键时刻融合成一张艺术图片",
                    icon: "clock.arrow.circlepath",
                    action: { [weak self] in self?.showTimeSequenceMode() }
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
                // 📏 批量调整尺寸 - 暂时不需要
                /*
                ProcessingOption(
                    title: "📏 批量调整尺寸",
                    description: "统一调整图片尺寸",
                    icon: "crop",
                    action: { [weak self] in self?.showBatchResize() }
                ),
                */
                // 🏷️ 批量添加水印 - 暂时不需要
                /*
                ProcessingOption(
                    title: "🏷️ 批量添加水印",
                    description: "为所有图片添加水印",
                    icon: "text.badge.plus",
                    action: { [weak self] in self?.showBatchWatermark() }
                ),
                */
                ProcessingOption(
                    title: "📤 批量分享",
                    description: "一键分享所有图片",
                    icon: "square.and.arrow.up",
                    action: { [weak self] in self?.showBatchShare() }
                )
                // 💾 保存到相册 - 在上一步"完成"时已保存，此处重复
                /*
                ProcessingOption(
                    title: "💾 保存到相册",
                    description: "保存所有图片到系统相册",
                    icon: "photo.on.rectangle",
                    action: { [weak self] in self?.saveBatchToPhotos() }
                )
                */
            ]
            
        case .livePhoto:
            processingOptions = [
                ProcessingOption(
                    title: "▶️ 播放Live Photo",
                    description: "预览Live Photo动画效果",
                    icon: "play.circle",
                    action: { [weak self] in self?.playLivePhotos() }
                ),
                ProcessingOption(
                    title: "🖼️ 设置封面",
                    description: "选择Live Photo的封面帧",
                    icon: "photo",
                    action: { [weak self] in self?.setCoverFrame() }
                ),
                ProcessingOption(
                    title: "✨ 批量画质修复",
                    description: "AI智能修复Live Photo质量",
                    icon: "wand.and.stars",
                    action: { [weak self] in self?.showBatchImageEnhancement() }
                ),
                ProcessingOption(
                    title: "💾 保存Live Photo",
                    description: "保存到系统相册Live Photo格式",
                    icon: "livephoto",
                    action: { [weak self] in self?.saveLivePhotos() }
                ),
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
        // TODO: 实现批量画质修复功能
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
        
        // 显示拼图选择对话框
        showCollageOptionsAlert(images: images)
    }
    
    // MARK: - 时间序列模式 (新增核心功能)
    private func showTimeSequenceMode() {
        print("⏰ 时间序列模式")
        
        // 检查是否有视频截图可用于时间序列处理
        guard !screenshots.isEmpty else {
            showAlert(title: "无法处理", message: "没有可用的截图进行时间序列处理")
            return
        }
        
        // 触觉反馈
        HapticFeedbackManager.shared.buttonTap()
        
        // 跳转到时间序列处理页面
        let timeSequenceVC = TimeSequenceViewController(screenshots: screenshots)
        navigationController?.pushViewController(timeSequenceVC, animated: true)
    }
    
    // showTimeSequenceInfoAlert 方法已移除 - 现在直接跳转到 TimeSequenceViewController
    
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
        // TODO: 实现批量分享功能
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
        
        // 使用现有的截图详情界面来设置Live Photo封面
        let detailSheet = ScreenshotDetailSheet(screenshots: livePhotos, currentIndex: 0)
        present(detailSheet, animated: true)
    }
    
    private func saveLivePhotos() {
        print("💾 保存Live Photo")
        
        // 获取Live Photo类型的截图
        let livePhotos = screenshots.filter { $0.mode == .livePhoto }
        guard !livePhotos.isEmpty else {
            showAlert(title: "提示", message: "没有Live Photo可以保存")
            return
        }
        
        // 显示保存确认
        let alert = UIAlertController(
            title: "保存Live Photo",
            message: "将\(livePhotos.count)个Live Photo保存到系统相册？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            self.performLivePhotoSave(livePhotos)
        })
        
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
    
    /// 执行Live Photo保存操作
    private func performLivePhotoSave(_ livePhotos: [ScreenshotItem]) {
        // 显示保存进度
        let progressAlert = UIAlertController(
            title: "保存中",
            message: "正在保存Live Photo到相册...",
            preferredStyle: .alert
        )
        present(progressAlert, animated: true)
        
        // 使用ScreenshotManager的批量保存功能
        ScreenshotManager.shared.batchSaveLivePhotosToAlbum(
            livePhotos,
            progress: { completed, total in
                DispatchQueue.main.async {
                    progressAlert.message = "正在保存Live Photo (\(completed)/\(total))..."
                }
            },
            completion: { successCount, failureCount in
                DispatchQueue.main.async {
                    progressAlert.dismiss(animated: true) {
                        self.showSaveResult(successCount: successCount, failureCount: failureCount)
                    }
                }
            }
        )
    }
    
    /// 显示保存结果
    private func showSaveResult(successCount: Int, failureCount: Int) {
        let title: String
        let message: String
        
        if failureCount == 0 {
            title = "保存成功"
            message = "已成功保存\(successCount)个Live Photo到相册"
        } else if successCount == 0 {
            title = "保存失败"
            message = "保存失败，请检查相册权限设置"
        } else {
            title = "部分保存成功"
            message = "成功保存\(successCount)个，失败\(failureCount)个Live Photo"
        }
        
        showAlert(title: title, message: message)
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
    }
}

// MARK: - 🧩 拼图功能实现 (从UnifiedPreviewViewController迁移)
extension ScreenshotProcessingViewController {
    
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
    
    // MARK: - 拼图辅助方法
    
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
        
        alert.addAction(UIAlertAction(title: "预览", style: .default) { _ in
            // 使用ScreenshotViewSheet预览拼图
            let tempScreenshot = ScreenshotItem(context: PersistenceController.shared.container.viewContext)
            // 这里需要临时创建一个ScreenshotItem来预览拼图
            let viewSheet = ScreenshotViewSheet(screenshot: tempScreenshot)
            viewSheet.modalPresentationStyle = .pageSheet
            self.present(viewSheet, animated: true)
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
