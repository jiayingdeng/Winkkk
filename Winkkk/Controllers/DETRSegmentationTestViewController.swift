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
    
    // MARK: - Properties
    
    private var currentImage: UIImage?
    private var segmentationManager = EnhancedSubjectSegmentationManager.shared
    private var processingStartTime: Date?
    
    // MARK: - Public Methods
    
    func setInitialImage(_ image: UIImage) {
        currentImage = image
        // 如果视图已经加载，立即更新UI
        if isViewLoaded {
            updateImageViews()
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        initializeSegmentationManager()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "DETR分割测试"
        
        // 设置导航栏
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "清除",
            style: .plain,
            target: self,
            action: #selector(clearResults)
        )
        
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
    }
    
    private func initializeSegmentationManager() {
        do {
            try segmentationManager.initialize()
            statusLabel?.text = "✅ DETR模型加载成功"
            statusLabel?.textColor = .systemGreen
        } catch {
            statusLabel?.text = "❌ 模型加载失败: \(error.localizedDescription)"
            statusLabel?.textColor = .systemRed
            processButton?.isEnabled = false
        }
    }
    
    private func updateImageViews() {
        originalImageView?.image = currentImage
        updateUIState(isProcessing: false, hasImage: currentImage != nil)
    }
    
    private func updateUIState(isProcessing: Bool, hasImage: Bool) {
        processButton?.isEnabled = hasImage && !isProcessing
        selectImageButton?.isEnabled = !isProcessing
        categorySegmentedControl?.isEnabled = !isProcessing
        
        if isProcessing {
            statusLabel?.text = "🔄 正在处理..."
            statusLabel?.textColor = .systemOrange
        } else if hasImage {
            statusLabel?.text = "✅ 图片已加载，可以开始分割"
            statusLabel?.textColor = .systemGreen
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
        
        updateUIState(isProcessing: true, hasImage: true)
        processingStartTime = Date()
        
        segmentationManager.segmentSubject(from: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleSegmentationResult(result)
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
                    self?.currentImage = image
                    self?.originalImageView?.image = image
                    self?.updateUIState(isProcessing: false, hasImage: true)
                    self?.statusLabel?.text = "✅ 图片加载成功，可以开始分割"
                    self?.statusLabel?.textColor = .systemGreen
                } else {
                    self?.showAlert(title: "错误", message: "无法加载选择的图片")
                }
            }
        }
    }
}
