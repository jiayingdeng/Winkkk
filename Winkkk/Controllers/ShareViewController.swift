//
//  ShareViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  分享视图控制器 - UIActivityViewController和自定义分享项
//

import UIKit

class ShareViewController: UIViewController {
    
    // MARK: - Properties
    private let shareImage: UIImage
    private let originalImage: UIImage?
    private var watermarkedImage: UIImage?
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 图像预览
    private let imagePreviewView = UIImageView()
    private let previewContainer = UIView()
    
    // 水印控制
    private let watermarkSection = UIView()
    private let watermarkToggle = UISwitch()
    private let watermarkLabel = UILabel()
    private let watermarkPreview = UILabel()
    
    // 分享选项
    private let shareOptionsSection = UIView()
    private let shareButton = UIButton()
    private let saveButton = UIButton()
    private let copyButton = UIButton()
    
    // MARK: - Dependencies
    private let watermarkManager = WatermarkManager()
    
    // MARK: - Initialization
    init(image: UIImage, originalImage: UIImage? = nil) {
        self.shareImage = image
        self.originalImage = originalImage
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
        configureInitialState()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        setupScrollView()
        
        // 图像预览
        setupImagePreview()
        
        // 水印控制
        setupWatermarkSection()
        
        // 分享选项
        setupShareOptions()
        
        // 导航栏
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        title = "分享"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
    
    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
        
        scrollView.addSubview(contentView)
    }
    
    private func setupImagePreview() {
        // 预览容器
        previewContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        previewContainer.layer.cornerRadius = ThemeManager.standardCornerRadius
        previewContainer.layer.masksToBounds = true
        contentView.addSubview(previewContainer)
        
        // 图像预览
        imagePreviewView.image = shareImage
        imagePreviewView.contentMode = .scaleAspectFit
        imagePreviewView.clipsToBounds = true
        previewContainer.addSubview(imagePreviewView)
        
        // 添加边框
        previewContainer.layer.borderWidth = 1
        previewContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
    }
    
    private func setupWatermarkSection() {
        watermarkSection.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        watermarkSection.layer.cornerRadius = ThemeManager.standardCornerRadius
        contentView.addSubview(watermarkSection)
        
        // 水印标签
        watermarkLabel.text = "添加水印"
        watermarkLabel.textColor = .white
        watermarkLabel.font = ThemeManager.subheadlineFont
        watermarkSection.addSubview(watermarkLabel)
        
        // 水印开关
        watermarkToggle.onTintColor = ThemeManager.buttonPrimary
        watermarkToggle.addTarget(self, action: #selector(watermarkToggleChanged(_:)), for: .valueChanged)
        watermarkSection.addSubview(watermarkToggle)
        
        // 水印预览
        watermarkPreview.text = "用 Winkkk 截取的精彩瞬间✨"
        watermarkPreview.textColor = UIColor.white.withAlphaComponent(0.7)
        watermarkPreview.font = ThemeManager.captionFont
        watermarkPreview.numberOfLines = 0
        watermarkSection.addSubview(watermarkPreview)
    }
    
    private func setupShareOptions() {
        shareOptionsSection.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        shareOptionsSection.layer.cornerRadius = ThemeManager.standardCornerRadius
        contentView.addSubview(shareOptionsSection)
        
        // 分享按钮
        shareButton.setTitle("分享到...", for: .normal)
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.backgroundColor = ThemeManager.success
        shareButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        shareButton.titleLabel?.font = ThemeManager.buttonFont
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        shareOptionsSection.addSubview(shareButton)
        
        // 保存按钮
        saveButton.setTitle("保存到相册", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonPrimary
        saveButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        saveButton.titleLabel?.font = ThemeManager.buttonFont
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        shareOptionsSection.addSubview(saveButton)
        
        // 复制按钮
        copyButton.setTitle("复制图片", for: .normal)
        copyButton.setTitleColor(ThemeManager.primaryText, for: .normal)
        copyButton.backgroundColor = UIColor.clear
        copyButton.layer.borderWidth = 1
        copyButton.layer.borderColor = ThemeManager.primaryText.cgColor
        copyButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        copyButton.titleLabel?.font = ThemeManager.buttonFont
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        shareOptionsSection.addSubview(copyButton)
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        imagePreviewView.translatesAutoresizingMaskIntoConstraints = false
        watermarkSection.translatesAutoresizingMaskIntoConstraints = false
        shareOptionsSection.translatesAutoresizingMaskIntoConstraints = false
        
        // 水印部分
        watermarkLabel.translatesAutoresizingMaskIntoConstraints = false
        watermarkToggle.translatesAutoresizingMaskIntoConstraints = false
        watermarkPreview.translatesAutoresizingMaskIntoConstraints = false
        
        // 分享按钮
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 预览容器
            previewContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            previewContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor, multiplier: 1.2),
            
            // 图像预览
            imagePreviewView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            imagePreviewView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 8),
            imagePreviewView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -8),
            imagePreviewView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -8),
            
            // 水印部分
            watermarkSection.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 20),
            watermarkSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            watermarkSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            watermarkSection.heightAnchor.constraint(equalToConstant: 80),
            
            watermarkLabel.topAnchor.constraint(equalTo: watermarkSection.topAnchor, constant: 16),
            watermarkLabel.leadingAnchor.constraint(equalTo: watermarkSection.leadingAnchor, constant: 16),
            
            watermarkToggle.centerYAnchor.constraint(equalTo: watermarkLabel.centerYAnchor),
            watermarkToggle.trailingAnchor.constraint(equalTo: watermarkSection.trailingAnchor, constant: -16),
            
            watermarkPreview.topAnchor.constraint(equalTo: watermarkLabel.bottomAnchor, constant: 8),
            watermarkPreview.leadingAnchor.constraint(equalTo: watermarkSection.leadingAnchor, constant: 16),
            watermarkPreview.trailingAnchor.constraint(equalTo: watermarkSection.trailingAnchor, constant: -16),
            watermarkPreview.bottomAnchor.constraint(lessThanOrEqualTo: watermarkSection.bottomAnchor, constant: -8),
            
            // 分享选项
            shareOptionsSection.topAnchor.constraint(equalTo: watermarkSection.bottomAnchor, constant: 20),
            shareOptionsSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shareOptionsSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            shareOptionsSection.heightAnchor.constraint(equalToConstant: 180),
            shareOptionsSection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // 分享按钮
            shareButton.topAnchor.constraint(equalTo: shareOptionsSection.topAnchor, constant: 16),
            shareButton.leadingAnchor.constraint(equalTo: shareOptionsSection.leadingAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: shareOptionsSection.trailingAnchor, constant: -16),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            
            saveButton.topAnchor.constraint(equalTo: shareButton.bottomAnchor, constant: 12),
            saveButton.leadingAnchor.constraint(equalTo: shareOptionsSection.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: shareOptionsSection.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            
            copyButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 12),
            copyButton.leadingAnchor.constraint(equalTo: shareOptionsSection.leadingAnchor, constant: 16),
            copyButton.trailingAnchor.constraint(equalTo: shareOptionsSection.trailingAnchor, constant: -16),
            copyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func configureInitialState() {
        watermarkToggle.isOn = true // 默认开启水印
        updateWatermarkPreview()
    }
    
    // MARK: - Watermark Management
    @objc private func watermarkToggleChanged(_ sender: UISwitch) {
        updateWatermarkPreview()
        
        // 触觉反馈
        HapticFeedbackManager.shared.buttonTap()
    }
    
    private func updateWatermarkPreview() {
        if watermarkToggle.isOn {
            generateWatermarkedImage()
        } else {
            watermarkedImage = nil
            imagePreviewView.image = shareImage
        }
        
        UIView.animate(withDuration: 0.3) {
            self.watermarkPreview.alpha = self.watermarkToggle.isOn ? 1.0 : 0.5
        }
    }
    
    private func generateWatermarkedImage() {
        watermarkManager.addWatermark(to: shareImage, style: .default) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let watermarked):
                    self?.watermarkedImage = watermarked
                    self?.imagePreviewView.image = watermarked
                    
                case .failure(let error):
                    print("水印添加失败: \(error)")
                    // 继续使用原图
                    self?.watermarkedImage = nil
                    self?.imagePreviewView.image = self?.shareImage
                }
            }
        }
    }
    
    // MARK: - Share Actions
    @objc private func shareButtonTapped() {
        let imageToShare = getCurrentShareImage()
        
        let activityViewController = UIActivityViewController(
            activityItems: [imageToShare, getShareText()],
            applicationActivities: [CustomShareActivity()]
        )
        
        // 配置分享选项
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // iPad支持
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true)
        
        // 追踪分享事件
        trackShareEvent(type: "general")
    }
    
    @objc private func saveButtonTapped() {
        let imageToSave = getCurrentShareImage()
        
        // 保存到相册
        UIImageWriteToSavedPhotosAlbum(imageToSave, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
        // 追踪保存事件
        trackShareEvent(type: "save")
    }
    
    @objc private func copyButtonTapped() {
        let imageToShare = getCurrentShareImage()
        
        // 复制到剪贴板
        UIPasteboard.general.image = imageToShare
        
        // 显示成功提示
        showCopySuccessMessage()
        
        // 触觉反馈
        HapticFeedbackManager.shared.notificationSuccess()
        
        // 追踪复制事件
        trackShareEvent(type: "copy")
    }
    
    // MARK: - Helper Methods
    private func getCurrentShareImage() -> UIImage {
        return watermarkedImage ?? shareImage
    }
    
    private func getShareText() -> String {
        return "用 Winkkk 截取的精彩瞬间✨"
    }
    
    private func showCopySuccessMessage() {
        let alertController = UIAlertController(
            title: "已复制",
            message: "图片已复制到剪贴板",
            preferredStyle: .alert
        )
        
        present(alertController, animated: true)
        
        // 自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alertController.dismiss(animated: true)
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showSaveErrorAlert(error)
        } else {
            showSaveSuccessAlert()
        }
    }
    
    private func showSaveSuccessAlert() {
        let alert = UIAlertController(
            title: "保存成功",
            message: "图片已保存到相册",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
        
        // 成功触觉反馈
        HapticFeedbackManager.shared.notificationSuccess()
    }
    
    private func showSaveErrorAlert(_ error: Error) {
        let alert = UIAlertController(
            title: "保存失败",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
        
        // 错误触觉反馈
        HapticFeedbackManager.shared.notificationError()
    }
    
    private func trackShareEvent(type: String) {
        // TODO: 集成分析工具
        print("分享事件: \(type)")
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        
        // 🚀 优化：智能判断返回路径，优先返回到截图处理中心
        guard let navigationController = navigationController else { return }
        
        // 检查导航栈中是否有ScreenshotProcessingViewController
        let hasScreenshotProcessingVC = navigationController.viewControllers.contains { viewController in
            return viewController is ScreenshotProcessingViewController
        }
        
        if hasScreenshotProcessingVC {
            // 如果导航栈中有截图处理中心，返回到那里
            let targetViewController = navigationController.viewControllers.first { viewController in
                return viewController is ScreenshotProcessingViewController
            }
            
            if let targetVC = targetViewController {
                navigationController.popToViewController(targetVC, animated: true)
                return
            }
        }
        
        // 🎯 智能判断其他导航方式
        if navigationController.presentingViewController != nil {
            // 如果整个导航控制器是模态展示的，使用dismiss
            navigationController.dismiss(animated: true)
        } else if navigationController.viewControllers.count > 1 {
            // 如果是push的且有多个视图控制器，使用popViewController
            navigationController.popViewController(animated: true)
        } else {
            // 如果是根视图控制器，直接dismiss
            dismiss(animated: true)
        }
    }
}

// MARK: - Custom Share Activity
class CustomShareActivity: UIActivity {
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.winkkk.share.custom")
    }
    
    override var activityTitle: String? {
        return "Winkkk 分享"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "heart.fill")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems.contains { $0 is UIImage }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        // 准备自定义分享数据
    }
    
    override func perform() {
        // 执行自定义分享逻辑
        print("执行自定义分享")
        activityDidFinish(true)
    }
}
