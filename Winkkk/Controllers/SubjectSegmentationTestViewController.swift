//
//  SubjectSegmentationTestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/22.
//  主体分割测试页面 - 独立测试功能，不影响主流程
//

import UIKit
import Photos

class SubjectSegmentationTestViewController: UIViewController {
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // 图片选择区域
    private let imageSelectionView = UIView()
    private let selectImageButton = CapsuleButton(title: "选择图片", style: .primary, size: .medium)
    private let selectedImageView = UIImageView()
    
    // 处理控制区域
    private let controlView = UIView()
    private let processButton = CapsuleButton(title: "开始分割", style: .secondary, size: .medium)
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    // 结果展示区域
    private let resultsView = UIView()
    private let originalImageView = UIImageView()
    private let subjectImageView = UIImageView()
    private let maskImageView = UIImageView()
    
    // 结果标签
    private let originalLabel = UILabel()
    private let subjectLabel = UILabel()
    private let maskLabel = UILabel()
    private let confidenceLabel = UILabel()
    
    // MARK: - Properties
    private var selectedImage: UIImage? {
        didSet {
            updateUI()
        }
    }
    
    private var segmentationResult: SegmentationResult? {
        didSet {
            displayResults()
        }
    }
    
    private var isProcessing = false {
        didSet {
            updateProcessingUI()
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureNavigationBar()
        initializeSegmentationManager()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Header设置
        setupHeader()
        
        // 图片选择区域
        setupImageSelectionView()
        
        // 控制区域
        setupControlView()
        
        // 结果展示区域
        setupResultsView()
        
        // 添加到内容视图
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(imageSelectionView)
        contentView.addSubview(controlView)
        contentView.addSubview(resultsView)
        
        // 初始状态
        updateUI()
    }
    
    private func setupHeader() {
        titleLabel.text = "AI主体分割测试"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "使用DeepLabV3模型进行图像分割测试"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = .systemGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
    }
    
    private func setupImageSelectionView() {
        imageSelectionView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        imageSelectionView.layer.cornerRadius = 16
        imageSelectionView.layer.borderWidth = 2
        imageSelectionView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        // 选择按钮
        selectImageButton.addTarget(self, action: #selector(selectImageTapped), for: UIControl.Event.touchUpInside)
        
        // 图片预览
        selectedImageView.contentMode = .scaleAspectFit
        selectedImageView.clipsToBounds = true
        selectedImageView.layer.cornerRadius = 12
        selectedImageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        selectedImageView.isHidden = true
        
        imageSelectionView.addSubview(selectImageButton)
        imageSelectionView.addSubview(selectedImageView)
    }
    
    private func setupControlView() {
        controlView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        controlView.layer.cornerRadius = 16
        
        // 处理按钮
        processButton.addTarget(self, action: #selector(processImageTapped), for: UIControl.Event.touchUpInside)
        processButton.isEnabled = false
        
        // 状态标签
        statusLabel.text = "请先选择一张图片"
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .systemGray
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // 进度条
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progressView.isHidden = true
        
        controlView.addSubview(processButton)
        controlView.addSubview(statusLabel)
        controlView.addSubview(progressView)
    }
    
    private func setupResultsView() {
        resultsView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        resultsView.layer.cornerRadius = 16
        resultsView.isHidden = true
        
        // 配置图片视图
        [originalImageView, subjectImageView, maskImageView].forEach { imageView in
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
            resultsView.addSubview(imageView)
        }
        
        // 配置标签
        originalLabel.text = "原图"
        subjectLabel.text = "主体"
        maskLabel.text = "遮罩"
        confidenceLabel.text = ""
        
        [originalLabel, subjectLabel, maskLabel, confidenceLabel].forEach { label in
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            resultsView.addSubview(label)
        }
    }
    
    private func setupConstraints() {
        // 禁用自动布局
        [gradientBackgroundView, scrollView, contentView, titleLabel, subtitleLabel,
         imageSelectionView, selectImageButton, selectedImageView,
         controlView, processButton, statusLabel, progressView,
         resultsView, originalImageView, subjectImageView, maskImageView,
         originalLabel, subjectLabel, maskLabel, confidenceLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // 背景
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
            
            // Header
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 图片选择区域
            imageSelectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            imageSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageSelectionView.heightAnchor.constraint(equalToConstant: 200),
            
            selectImageButton.centerXAnchor.constraint(equalTo: imageSelectionView.centerXAnchor),
            selectImageButton.centerYAnchor.constraint(equalTo: imageSelectionView.centerYAnchor),
            
            selectedImageView.topAnchor.constraint(equalTo: imageSelectionView.topAnchor, constant: 16),
            selectedImageView.leadingAnchor.constraint(equalTo: imageSelectionView.leadingAnchor, constant: 16),
            selectedImageView.trailingAnchor.constraint(equalTo: imageSelectionView.trailingAnchor, constant: -16),
            selectedImageView.bottomAnchor.constraint(equalTo: imageSelectionView.bottomAnchor, constant: -16),
            
            // 控制区域
            controlView.topAnchor.constraint(equalTo: imageSelectionView.bottomAnchor, constant: 20),
            controlView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            controlView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            controlView.heightAnchor.constraint(equalToConstant: 120),
            
            processButton.topAnchor.constraint(equalTo: controlView.topAnchor, constant: 20),
            processButton.centerXAnchor.constraint(equalTo: controlView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: processButton.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // 结果区域
            resultsView.topAnchor.constraint(equalTo: controlView.bottomAnchor, constant: 20),
            resultsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultsView.heightAnchor.constraint(equalToConstant: 280),
            resultsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
        
        // 结果区域内部约束
        setupResultsConstraints()
    }
    
    private func setupResultsConstraints() {
        let imageHeight: CGFloat = 120
        let labelHeight: CGFloat = 20
        
        NSLayoutConstraint.activate([
            // 图片视图
            originalImageView.topAnchor.constraint(equalTo: resultsView.topAnchor, constant: 20),
            originalImageView.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 16),
            originalImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            originalImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            
            subjectImageView.topAnchor.constraint(equalTo: resultsView.topAnchor, constant: 20),
            subjectImageView.centerXAnchor.constraint(equalTo: resultsView.centerXAnchor),
            subjectImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            subjectImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            
            maskImageView.topAnchor.constraint(equalTo: resultsView.topAnchor, constant: 20),
            maskImageView.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -16),
            maskImageView.widthAnchor.constraint(equalTo: resultsView.widthAnchor, multiplier: 0.28),
            maskImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            
            // 标签
            originalLabel.topAnchor.constraint(equalTo: originalImageView.bottomAnchor, constant: 8),
            originalLabel.centerXAnchor.constraint(equalTo: originalImageView.centerXAnchor),
            originalLabel.heightAnchor.constraint(equalToConstant: labelHeight),
            
            subjectLabel.topAnchor.constraint(equalTo: subjectImageView.bottomAnchor, constant: 8),
            subjectLabel.centerXAnchor.constraint(equalTo: subjectImageView.centerXAnchor),
            subjectLabel.heightAnchor.constraint(equalToConstant: labelHeight),
            
            maskLabel.topAnchor.constraint(equalTo: maskImageView.bottomAnchor, constant: 8),
            maskLabel.centerXAnchor.constraint(equalTo: maskImageView.centerXAnchor),
            maskLabel.heightAnchor.constraint(equalToConstant: labelHeight),
            
            confidenceLabel.topAnchor.constraint(equalTo: originalLabel.bottomAnchor, constant: 20),
            confidenceLabel.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 16),
            confidenceLabel.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -16),
            confidenceLabel.heightAnchor.constraint(equalToConstant: labelHeight),
        ])
    }
    
    private func configureNavigationBar() {
        title = "AI分割测试"
        
        // 关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        
        // 设置导航栏样式
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .systemBlue
    }
    
    // MARK: - Segmentation Manager
    private func initializeSegmentationManager() {
        do {
            try SubjectSegmentationManager.shared.initialize()
            statusLabel.text = "AI模型已就绪，请选择图片"
        } catch {
            statusLabel.text = "AI模型初始化失败: \(error.localizedDescription)"
            statusLabel.textColor = .systemRed
        }
    }
    
    // MARK: - Actions
    @objc private func selectImageTapped() {
        let alert = UIAlertController(title: "选择图片", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
            self?.presentImagePicker()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = selectImageButton
            popover.sourceRect = selectImageButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func processImageTapped() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        segmentationResult = nil
        
        statusLabel.text = "正在分析图片..."
        statusLabel.textColor = .systemGray
        
        // 模拟进度
        animateProgress()
        
        SubjectSegmentationManager.shared.segmentSubject(from: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let segmentationResult):
                    self?.segmentationResult = segmentationResult
                    self?.statusLabel.text = "分割完成！"
                    self?.statusLabel.textColor = .systemGreen
                    
                case .failure(let error):
                    self?.statusLabel.text = "分割失败: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                }
            }
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        let hasImage = selectedImage != nil
        
        selectImageButton.isHidden = hasImage
        selectedImageView.isHidden = !hasImage
        processButton.isEnabled = hasImage && !isProcessing
        
        if let image = selectedImage {
            selectedImageView.image = image
        }
    }
    
    private func updateProcessingUI() {
        processButton.isEnabled = !isProcessing && selectedImage != nil
        progressView.isHidden = !isProcessing
        
        if !isProcessing {
            progressView.progress = 0
        }
    }
    
    private func displayResults() {
        guard let result = segmentationResult else {
            resultsView.isHidden = true
            return
        }
        
        resultsView.isHidden = false
        
        originalImageView.image = result.originalImage
        subjectImageView.image = result.subjectImage
        maskImageView.image = result.maskImage
        
        let confidencePercent = Int(result.confidence * 100)
        confidenceLabel.text = "分割置信度: \(confidencePercent)%"
        confidenceLabel.textColor = result.confidence > 0.5 ? .systemGreen : .systemOrange
    }
    
    private func animateProgress() {
        progressView.progress = 0
        UIView.animate(withDuration: 2.0, delay: 0, options: [.curveEaseInOut], animations: {
            self.progressView.progress = 0.9
        })
    }
}

// MARK: - Image Picker
extension SubjectSegmentationTestViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private func presentImagePicker() {
        // 检查权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.showImagePicker()
                case .denied, .restricted:
                    self?.showPermissionAlert()
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func showImagePicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "需要相册权限",
            message: "请在设置中允许访问相册",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            selectedImage = image
            segmentationResult = nil // 重置结果
        }
        
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
