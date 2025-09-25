//
//  DETRSegmentationTestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/22.
//  DETR模型分割测试页面
//

import UIKit
import PhotosUI

class DETRSegmentationTestViewController: UIViewController {
    
    // MARK: - UI Components
    
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!
    
    // 控制区域
    @IBOutlet private weak var controlStackView: UIStackView!
    @IBOutlet private weak var categorySegmentedControl: UISegmentedControl!
    @IBOutlet private weak var selectImageButton: UIButton!
    @IBOutlet private weak var processButton: UIButton!
    
    // 图片显示区域
    @IBOutlet private weak var originalImageView: UIImageView!
    @IBOutlet private weak var segmentedImageView: UIImageView!
    @IBOutlet private weak var maskImageView: UIImageView!
    
    // 信息显示区域
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var confidenceLabel: UILabel!
    @IBOutlet private weak var detectedClassesTextView: UITextView!
    @IBOutlet private weak var processingTimeLabel: UILabel!
    @IBOutlet private weak var navigationHintLabel: UILabel!
    
    // MARK: - Properties
    
    private var currentImage: UIImage?
    private var segmentationManager = EnhancedSubjectSegmentationManager.shared
    private var processingStartTime: Date?
    private var modelStatusTimer: Timer?
    
    // MARK: - Public Methods
    
    func setInitialImage(_ image: UIImage) {
        print("🖼️ setInitialImage: 设置预设图片，尺寸: \(image.size)")
        currentImage = image
        // 如果视图已经加载，立即更新UI
        if isViewLoaded {
            print("🖼️ setInitialImage: 视图已加载，立即更新UI")
            updateImageViews()
        } else {
            print("🖼️ setInitialImage: 视图未加载，将在viewDidAppear中更新")
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        initializeSegmentationManager()
        startModelStatusTimer()
        showWelcomeHint()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 如果有预设的图片，确保UI正确更新
        if let image = currentImage {
            print("📱 viewDidAppear: 检测到预设图片，更新UI")
            updateImageViews()
            statusLabel?.text = "✅ 图片已预载，可以开始分割"
            statusLabel?.textColor = .systemGreen
        }
    }
    
    deinit {
        modelStatusTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "DETR分割测试"
        
        // 设置导航栏
        setupNavigationBar()
        
        // 设置分类选择器
        setupCategorySegmentedControl()
        
        // 设置按钮
        setupButtons()
        
        // 设置图片视图
        setupImageViews()
        
        // 设置信息显示区域
        setupInfoViews()
        
        // 初始状态
        updateUIState(isProcessing: false, hasImage: false)
    }
    
    private func setupNavigationBar() {
        // 左侧按钮 - 返回设置
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(returnToSettings)
        )
        settingsButton.tintColor = .systemBlue
        
        // 中间按钮 - 返回主页
        let homeButton = UIBarButtonItem(
            image: UIImage(systemName: "house.fill"),
            style: .plain,
            target: self,
            action: #selector(returnToHome)
        )
        homeButton.tintColor = .systemGreen
        
        // 右侧按钮 - 清除结果
        let clearButton = UIBarButtonItem(
            title: "清除",
            style: .plain,
            target: self,
            action: #selector(clearResults)
        )
        clearButton.tintColor = .systemRed
        
        // 设置导航栏按钮
        navigationItem.leftBarButtonItem = settingsButton
        navigationItem.rightBarButtonItems = [clearButton, homeButton]
        
        // 添加导航栏标题样式
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .label
    }
    
    private func setupCategorySegmentedControl() {
        guard let segmentedControl = categorySegmentedControl else {
            print("⚠️ categorySegmentedControl is nil - IBOutlet not connected")
            return
        }
        
        segmentedControl.removeAllSegments()
        
        for (index, category) in EnhancedSubjectSegmentationManager.SegmentationCategory.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: category.displayName, at: index, animated: false)
        }
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
    }
    
    private func setupButtons() {
        // 选择图片按钮
        guard let selectBtn = selectImageButton else {
            print("⚠️ selectImageButton is nil - IBOutlet not connected")
            return
        }
        selectBtn.setTitle("📷 选择图片", for: .normal)
        selectBtn.backgroundColor = .systemBlue
        selectBtn.setTitleColor(.white, for: .normal)
        selectBtn.layer.cornerRadius = 8
        selectBtn.addTarget(self, action: #selector(selectImageTapped), for: .touchUpInside)
        
        // 处理按钮
        guard let processBtn = processButton else {
            print("⚠️ processButton is nil - IBOutlet not connected")
            return
        }
        processBtn.setTitle("🎯 开始分割", for: .normal)
        processBtn.backgroundColor = .systemGreen
        processBtn.setTitleColor(.white, for: .normal)
        processBtn.layer.cornerRadius = 8
        processBtn.addTarget(self, action: #selector(processImageTapped), for: .touchUpInside)
    }
    
    private func setupImageViews() {
        [originalImageView, segmentedImageView, maskImageView].forEach { imageView in
            imageView?.contentMode = .scaleAspectFit
            imageView?.backgroundColor = .systemGray6
            imageView?.layer.cornerRadius = 8
            imageView?.clipsToBounds = true
            imageView?.layer.borderWidth = 1
            imageView?.layer.borderColor = UIColor.systemGray4.cgColor
        }
        
        // 添加标签
        addLabelToImageView(originalImageView, text: "原图")
        addLabelToImageView(segmentedImageView, text: "分割结果")
        addLabelToImageView(maskImageView, text: "分割遮罩")
    }
    
    private func addLabelToImageView(_ imageView: UIImageView?, text: String) {
        guard let imageView = imageView else {
            print("⚠️ imageView is nil for label: \(text)")
            return
        }
        
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // 确保imageView本身也设置了正确的AutoLayout属性
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            label.topAnchor.constraint(equalTo: imageView.topAnchor),
            label.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupInfoViews() {
        statusLabel?.text = "请选择图片开始测试"
        statusLabel?.textColor = .systemBlue
        
        confidenceLabel?.text = "置信度: --"
        processingTimeLabel?.text = "处理时间: --"
        
        detectedClassesTextView?.backgroundColor = .systemGray6
        detectedClassesTextView?.layer.cornerRadius = 8
        detectedClassesTextView?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        detectedClassesTextView?.text = "检测结果将在这里显示..."
        
        // 设置导航提示
        navigationHintLabel?.text = "💡 提示：点击左上角齿轮图标返回设置，点击右上角房子图标返回主页"
        navigationHintLabel?.textColor = .systemGray
        navigationHintLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        navigationHintLabel?.textAlignment = .center
        navigationHintLabel?.numberOfLines = 0
    }
    
    private func initializeSegmentationManager() {
        statusLabel?.text = "🔄 正在加载DETR模型..."
        statusLabel?.textColor = .systemOrange
        
        // 在后台线程初始化模型，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.segmentationManager.initialize()
                DispatchQueue.main.async {
                    self?.statusLabel?.text = "✅ DETR模型加载成功"
                    self?.statusLabel?.textColor = .systemGreen
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel?.text = "❌ 模型加载失败: \(error.localizedDescription)"
                    self?.statusLabel?.textColor = .systemRed
                    self?.processButton?.isEnabled = false
                }
            }
        }
    }
    
    private func startModelStatusTimer() {
        modelStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateUIStateIfNeeded()
            }
        }
    }
    
    private func updateUIStateIfNeeded() {
        // 检查模型是否已准备就绪
        let modelReady = segmentationManager.isModelReady()
        
        // 如果模型已加载完成，停止定时器并更新UI
        if modelReady {
            modelStatusTimer?.invalidate()
            modelStatusTimer = nil
            
            // 只有在有图片的情况下才更新状态为可以分割
            let hasImage = currentImage != nil
            if hasImage {
                statusLabel?.text = "✅ 图片已加载，可以开始分割"
                statusLabel?.textColor = .systemGreen
                processButton?.isEnabled = true
            }
        }
    }
    
    private func updateImageViews() {
        originalImageView?.image = currentImage
        updateUIState(isProcessing: false, hasImage: currentImage != nil)
    }
    
    private func updateUIState(isProcessing: Bool, hasImage: Bool) {
        processButton?.isEnabled = hasImage && !isProcessing && segmentationManager.isModelReady()
        selectImageButton?.isEnabled = !isProcessing
        categorySegmentedControl?.isEnabled = !isProcessing
        
        if isProcessing {
            statusLabel?.text = "🔄 DETR模型分析中，请稍候..."
            statusLabel?.textColor = .systemOrange
        } else if hasImage {
            if segmentationManager.isModelReady() {
                statusLabel?.text = "✅ 图片已加载，可以开始分割"
                statusLabel?.textColor = .systemGreen
            } else {
                statusLabel?.text = "⏳ 模型加载中，请稍候..."
                statusLabel?.textColor = .systemOrange
            }
        } else {
            statusLabel?.text = "请选择图片开始测试"
            statusLabel?.textColor = .systemBlue
        }
    }
    
    // MARK: - Actions
    
    @objc private func categoryChanged() {
        guard let segmentedControl = categorySegmentedControl else { return }
        let selectedCategory = EnhancedSubjectSegmentationManager.SegmentationCategory.allCases[segmentedControl.selectedSegmentIndex]
        segmentationManager.setSegmentationCategory(selectedCategory)
        statusLabel?.text = "🎯 分割类别: \(selectedCategory.displayName)"
    }
    
    @objc private func selectImageTapped() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func processImageTapped() {
        guard let image = currentImage else {
            showAlert(title: "提示", message: "请先选择一张图片")
            return
        }
        
        // 检查模型是否已初始化
        guard segmentationManager.isModelReady() else {
            showAlert(title: "提示", message: "模型正在加载中，请稍后再试")
            return
        }
        
        print("🚀 开始处理图片分割...")
        print("📸 图片信息: \(image.size), scale: \(image.scale)")
        updateUIState(isProcessing: true, hasImage: true)
        processingStartTime = Date()
        
        // 确保在后台线程处理
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            print("🔄 分割管理器开始处理...")
            self?.segmentationManager.segmentSubject(from: image) { result in
                DispatchQueue.main.async {
                    print("✅ 分割处理完成，更新UI")
                    self?.handleSegmentationResult(result)
                }
            }
        }
    }
    
    @objc private func clearResults() {
        currentImage = nil
        originalImageView?.image = nil
        segmentedImageView?.image = nil
        maskImageView?.image = nil
        
        statusLabel?.text = "请选择图片开始测试"
        statusLabel?.textColor = .systemBlue
        confidenceLabel?.text = "置信度: --"
        processingTimeLabel?.text = "处理时间: --"
        detectedClassesTextView?.text = "检测结果将在这里显示..."
        
        updateUIState(isProcessing: false, hasImage: false)
    }
    
    @objc private func returnToSettings() {
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 添加按钮动画
        if let settingsButton = navigationItem.leftBarButtonItem {
            animateButtonTap(settingsButton)
        }
        
        // 返回到设置页面
        if let settingsVC = findSettingsViewController() {
            dismiss(animated: true) {
                // 如果设置页面是模态展示的，直接dismiss
                if settingsVC.presentingViewController != nil {
                    settingsVC.dismiss(animated: true)
                } else {
                    // 如果设置页面在导航栈中，pop到设置页面
                    settingsVC.navigationController?.popToViewController(settingsVC, animated: true)
                }
            }
        } else {
            // 如果找不到设置页面，直接dismiss当前页面
            dismiss(animated: true)
        }
    }
    
    @objc private func returnToHome() {
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 添加按钮动画
        if let homeButton = navigationItem.rightBarButtonItems?.last {
            animateButtonTap(homeButton)
        }
        
        // 返回到主界面
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // 关闭所有模态视图
            rootVC.dismiss(animated: true) {
                // 如果根视图是导航控制器，pop到根视图
                if let navController = rootVC as? UINavigationController {
                    navController.popToRootViewController(animated: true)
                }
            }
        }
    }
    
    private func findSettingsViewController() -> SettingsViewController? {
        // 在当前导航栈中查找设置页面
        if let navController = navigationController {
            for viewController in navController.viewControllers {
                if let settingsVC = viewController as? SettingsViewController {
                    return settingsVC
                }
            }
        }
        
        // 在presented视图控制器中查找
        var currentVC = presentingViewController
        while let vc = currentVC {
            if let settingsVC = vc as? SettingsViewController {
                return settingsVC
            }
            if let navController = vc as? UINavigationController {
                for viewController in navController.viewControllers {
                    if let settingsVC = viewController as? SettingsViewController {
                        return settingsVC
                    }
                }
            }
            currentVC = vc.presentingViewController
        }
        
        return nil
    }
    
    private func animateButtonTap(_ button: UIBarButtonItem) {
        // 创建按钮动画效果
        UIView.animate(withDuration: 0.1, animations: {
            // 这里可以添加按钮的视觉反馈动画
            // 由于UIBarButtonItem没有直接的视图属性，我们通过改变tintColor来实现反馈
            let originalColor = button.tintColor
            button.tintColor = .systemOrange
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                button.tintColor = originalColor
            }
        })
    }
    
    private func showWelcomeHint() {
        // 延迟显示欢迎提示，让用户注意到导航按钮
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.displayNavigationHint()
        }
    }
    
    private func displayNavigationHint() {
        let alert = UIAlertController(
            title: "🎯 DETR分割测试",
            message: "欢迎使用DETR智能分割测试！\n\n📱 导航提示：\n• 左上角齿轮图标：返回设置页面\n• 右上角房子图标：返回主界面\n• 右上角清除按钮：清空测试结果\n\n现在请选择一张图片开始测试吧！",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "开始测试", style: .default) { [weak self] _ in
            // 用户点击开始测试后，可以自动触发图片选择
            self?.selectImageTapped()
        })
        
        alert.addAction(UIAlertAction(title: "我知道了", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Helper Methods
    
    
    private func handleSegmentationResult(_ result: Result<EnhancedSegmentationResult, SegmentationError>) {
        let processingTime = processingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        updateUIState(isProcessing: false, hasImage: true)
        
        switch result {
        case .success(let segmentationResult):
            // 显示结果图片
            segmentedImageView?.image = segmentationResult.subjectImage
            maskImageView?.image = segmentationResult.maskImage
            
            // 更新信息
            statusLabel?.text = "✅ 分割完成"
            statusLabel?.textColor = .systemGreen
            
            confidenceLabel?.text = String(format: "置信度: %.1f%%", segmentationResult.confidence * 100)
            processingTimeLabel?.text = String(format: "处理时间: %.2f秒", processingTime)
            
            // 显示检测到的类别
            displayDetectedClasses(segmentationResult.detectedClasses)
            
        case .failure(let error):
            statusLabel?.text = "❌ 分割失败: \(error.localizedDescription)"
            statusLabel?.textColor = .systemRed
            
            processingTimeLabel?.text = String(format: "处理时间: %.2f秒", processingTime)
            detectedClassesTextView?.text = "处理失败，请重试"
        }
    }
    
    private func displayDetectedClasses(_ classes: [DetectedClass]) {
        if classes.isEmpty {
            detectedClassesTextView?.text = "未检测到任何目标类别"
            return
        }
        
        var text = "检测到的类别:\n\n"
        
        for (index, detectedClass) in classes.prefix(10).enumerated() { // 只显示前10个
            text += String(format: "%d. %@ (%.1f%%, %d像素)\n", 
                          index + 1,
                          detectedClass.className,
                          detectedClass.confidence * 100,
                          detectedClass.pixelCount)
        }
        
        if classes.count > 10 {
            text += "\n... 还有 \(classes.count - 10) 个类别"
        }
        
        detectedClassesTextView?.text = text
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension DETRSegmentationTestViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    print("📷 PHPicker: 成功加载图片，尺寸: \(image.size)")
                    self?.currentImage = image
                    self?.originalImageView?.image = image
                    self?.updateUIState(isProcessing: false, hasImage: true)
                    print("📷 PHPicker: UI状态已更新")
                } else {
                    print("❌ PHPicker: 无法加载图片，错误: \(error?.localizedDescription ?? "未知错误")")
                    self?.showAlert(title: "错误", message: "无法加载选择的图片")
                }
            }
        }
    }
}
