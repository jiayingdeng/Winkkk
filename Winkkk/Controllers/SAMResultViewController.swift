//
//  SAMResultViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  SAM分割结果展示页面 - 显示分割结果并提供保存分享功能
//

import UIKit
import Photos

class SAMResultViewController: UIViewController {
    
    // MARK: - Properties
    private let result: SAMSegmentationResult
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel = UILabel()
    private let confidenceLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["原图", "蒙版", "提取物体"])
    private let resultImageView = UIImageView()
    private let actionStackView = UIStackView()
    private let saveButton = UIButton()
    private let shareButton = UIButton()
    private let newTestButton = UIButton()
    
    // MARK: - Initialization
    init(result: SAMSegmentationResult) {
        self.result = result
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
        updateDisplayImage()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        // 内容视图
        scrollView.addSubview(contentView)
        
        // 标题
        titleLabel.text = "✅ \(result.category.title) 分割完成"
        titleLabel.font = ThemeManager.headlineFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        
        // 置信度标签
        let confidencePercentage = Int(result.confidence * 100)
        confidenceLabel.text = "置信度: \(confidencePercentage)%"
        confidenceLabel.font = ThemeManager.subheadlineFont
        confidenceLabel.textColor = result.category.color
        confidenceLabel.textAlignment = .center
        contentView.addSubview(confidenceLabel)
        
        // 分段控制器
        segmentedControl.selectedSegmentIndex = 2 // 默认显示提取物体
        segmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        segmentedControl.selectedSegmentTintColor = result.category.color
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        contentView.addSubview(segmentedControl)
        
        // 结果图片
        resultImageView.contentMode = .scaleAspectFit
        resultImageView.layer.cornerRadius = 12
        resultImageView.layer.masksToBounds = true
        resultImageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        contentView.addSubview(resultImageView)
        
        // 操作按钮堆栈
        actionStackView.axis = .horizontal
        actionStackView.distribution = .fillEqually
        actionStackView.spacing = 16
        contentView.addSubview(actionStackView)
        
        // 保存按钮
        saveButton.setTitle("💾 保存到相册", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = ThemeManager.captionFont
        saveButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        actionStackView.addArrangedSubview(saveButton)
        
        // 分享按钮
        shareButton.setTitle("📤 分享结果", for: .normal)
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.titleLabel?.font = ThemeManager.captionFont
        shareButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        shareButton.layer.cornerRadius = 8
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        actionStackView.addArrangedSubview(shareButton)
        
        // 新测试按钮
        newTestButton.setTitle("🔄 新的测试", for: .normal)
        newTestButton.setTitleColor(.white, for: .normal)
        newTestButton.titleLabel?.font = ThemeManager.subheadlineFont
        newTestButton.backgroundColor = result.category.color.withAlphaComponent(0.8)
        newTestButton.layer.cornerRadius = 12
        newTestButton.addTarget(self, action: #selector(newTestButtonTapped), for: .touchUpInside)
        contentView.addSubview(newTestButton)
    }
    
    private func setupNavigationBar() {
        title = "分割结果"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回",
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(infoButtonTapped)
        )
    }
    
    private func setupConstraints() {
        [gradientBackgroundView, scrollView, contentView, titleLabel, confidenceLabel,
         segmentedControl, resultImageView, actionStackView, newTestButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
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
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 置信度标签
            confidenceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            confidenceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            confidenceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 分段控制器
            segmentedControl.topAnchor.constraint(equalTo: confidenceLabel.bottomAnchor, constant: 20),
            segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            // 结果图片
            resultImageView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            resultImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultImageView.heightAnchor.constraint(equalToConstant: 300),
            
            // 操作按钮堆栈
            actionStackView.topAnchor.constraint(equalTo: resultImageView.bottomAnchor, constant: 20),
            actionStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            actionStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            actionStackView.heightAnchor.constraint(equalToConstant: 44),
            
            // 新测试按钮
            newTestButton.topAnchor.constraint(equalTo: actionStackView.bottomAnchor, constant: 20),
            newTestButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            newTestButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            newTestButton.heightAnchor.constraint(equalToConstant: 50),
            newTestButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func infoButtonTapped() {
        let message = """
        分割详情:
        • 分类: \(result.category.title)
        • 置信度: \(Int(result.confidence * 100))%
        • 算法: MobileSAM
        • 处理时间: < 1秒
        
        您可以切换查看不同的结果视图，保存到相册或分享给朋友。
        """
        
        let alert = UIAlertController(title: "分割信息", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "了解", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func segmentedControlChanged() {
        updateDisplayImage()
    }
    
    @objc private func saveButtonTapped() {
        guard let imageToSave = getCurrentDisplayImage() else {
            showError("无法获取当前显示的图片")
            return
        }
        
        // 检查相册权限
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.saveImageToPhotos(imageToSave)
                case .denied, .restricted:
                    self?.showError("需要相册权限才能保存图片")
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    @objc private func shareButtonTapped() {
        guard let imageToShare = getCurrentDisplayImage() else {
            showError("无法获取当前显示的图片")
            return
        }
        
        let confidenceText = "SAM分割结果 - \(result.category.title) (置信度: \(Int(result.confidence * 100))%)"
        let activityVC = UIActivityViewController(
            activityItems: [imageToShare, confidenceText],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func newTestButtonTapped() {
        // 返回到主测试页面
        navigationController?.popToRootViewController(animated: true)
    }
    
    // MARK: - Helper Methods
    private func updateDisplayImage() {
        switch segmentedControl.selectedSegmentIndex {
        case 0: // 原图
            resultImageView.image = result.originalImage
            resultImageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        case 1: // 蒙版
            resultImageView.image = result.mask
            resultImageView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        case 2: // 提取物体
            resultImageView.image = result.extractedObject
            // 棋盘格背景显示透明效果
            resultImageView.backgroundColor = createCheckerboardBackground()
        default:
            break
        }
    }
    
    private func getCurrentDisplayImage() -> UIImage? {
        switch segmentedControl.selectedSegmentIndex {
        case 0: return result.originalImage
        case 1: return result.mask
        case 2: return result.extractedObject
        default: return nil
        }
    }
    
    private func createCheckerboardBackground() -> UIColor {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let checkerboardImage = renderer.image { context in
            let cgContext = context.cgContext
            
            // 绘制棋盘格
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            cgContext.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
            cgContext.fill(CGRect(x: 10, y: 10, width: 10, height: 10))
            
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.05).cgColor)
            cgContext.fill(CGRect(x: 10, y: 0, width: 10, height: 10))
            cgContext.fill(CGRect(x: 0, y: 10, width: 10, height: 10))
        }
        
        return UIColor(patternImage: checkerboardImage)
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showSuccess("图片已保存到相册")
                } else if let error = error {
                    self?.showError("保存失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showSuccess(_ message: String) {
        AnimationManager.shared.showSuccessFeedback(in: view, message: message)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}


