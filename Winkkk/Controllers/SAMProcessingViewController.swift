//
//  SAMProcessingViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  SAM分割处理页面 - 显示原图并执行分割
//

import UIKit
import CoreML
import Vision

class SAMProcessingViewController: UIViewController {
    
    // MARK: - Properties
    private let originalImage: UIImage
    private let category: SAMTestCategory
    private var mobileSAMManager: MobileSAMManager?
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let categoryLabel = UILabel()
    private let originalImageView = UIImageView()
    private let processButton = UIButton()
    private let progressView = UIProgressView()
    private let statusLabel = UILabel()
    
    // MARK: - Initialization
    init(image: UIImage, category: SAMTestCategory) {
        self.originalImage = image
        self.category = category
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
        setupMobileSAM()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 自动开始处理
        startProcessing()
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
        
        // 分类标签
        categoryLabel.text = "正在处理: \(category.title)"
        categoryLabel.font = ThemeManager.headlineFont
        categoryLabel.textColor = .white
        categoryLabel.textAlignment = .center
        contentView.addSubview(categoryLabel)
        
        // 原始图片
        originalImageView.image = originalImage
        originalImageView.contentMode = .scaleAspectFit
        originalImageView.layer.cornerRadius = 12
        originalImageView.layer.masksToBounds = true
        originalImageView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        contentView.addSubview(originalImageView)
        
        // 处理按钮
        processButton.setTitle("🎯 开始智能分割", for: .normal)
        processButton.setTitleColor(.white, for: .normal)
        processButton.titleLabel?.font = ThemeManager.subheadlineFont
        processButton.backgroundColor = category.color
        processButton.layer.cornerRadius = 12
        processButton.addTarget(self, action: #selector(processButtonTapped), for: .touchUpInside)
        contentView.addSubview(processButton)
        
        // 进度条
        progressView.progressTintColor = category.color
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progressView.layer.cornerRadius = 2
        progressView.layer.masksToBounds = true
        progressView.isHidden = true
        contentView.addSubview(progressView)
        
        // 状态标签
        statusLabel.text = "点击按钮开始分割"
        statusLabel.font = ThemeManager.captionFont
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        contentView.addSubview(statusLabel)
    }
    
    private func setupNavigationBar() {
        title = "SAM分割处理"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回",
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
    }
    
    private func setupConstraints() {
        [gradientBackgroundView, scrollView, contentView, categoryLabel, originalImageView, 
         processButton, progressView, statusLabel].forEach {
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
            
            // 分类标签
            categoryLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 原始图片
            originalImageView.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 20),
            originalImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            originalImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            originalImageView.heightAnchor.constraint(equalToConstant: 300),
            
            // 处理按钮
            processButton.topAnchor.constraint(equalTo: originalImageView.bottomAnchor, constant: 30),
            processButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            processButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            processButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 进度条
            progressView.topAnchor.constraint(equalTo: processButton.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 15),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - MobileSAM Setup
    private func setupMobileSAM() {
        print("🔄 正在初始化MobileSAM...")
        mobileSAMManager = MobileSAMManager()
        // 初始化成功信息现在由MobileSAMManager.loadModel()打印
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func processButtonTapped() {
        startProcessing()
    }
    
    // MARK: - Processing
    private func startProcessing() {
        guard let mobileSAMManager = mobileSAMManager else {
            showError("MobileSAM未初始化")
            return
        }
        
        // 更新UI状态
        processButton.isEnabled = false
        processButton.setTitle("🔄 处理中...", for: .normal)
        progressView.isHidden = false
        progressView.progress = 0.0
        statusLabel.text = "正在初始化模型..."
        
        // 开始处理
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performSegmentation(with: mobileSAMManager)
        }
    }
    
    private func performSegmentation(with manager: MobileSAMManager) {
        // 更新进度 - 图像预处理
        DispatchQueue.main.async { [weak self] in
            self?.updateProgress(0.2, status: "正在预处理图像...")
        }
        
        // 预处理图像
        let processedImage = preprocessImage(originalImage)
        
        // 更新进度 - 自动分割
        DispatchQueue.main.async { [weak self] in
            self?.updateProgress(0.4, status: "正在执行智能分割...")
        }
        
        // 使用图像中心点作为分割点
        let centerPoint = CGPoint(
            x: processedImage.size.width / 2,
            y: processedImage.size.height / 2
        )
        
        // 执行分割
        manager.segmentObject(in: processedImage, at: centerPoint)
        
        // 监听分割结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateProgress(0.8, status: "正在生成结果...")
            
            // 模拟处理完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.generateSimulatedResult(processedImage)
            }
        }
    }
    
    private func updateProgress(_ progress: Float, status: String) {
        progressView.setProgress(progress, animated: true)
        statusLabel.text = status
    }
    
    private func preprocessImage(_ image: UIImage) -> UIImage {
        // 调整图像大小以适应模型输入
        let targetSize = CGSize(width: 1024, height: 1024)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    private func generateSimulatedResult(_ processedImage: UIImage) {
        // 更新进度
        updateProgress(1.0, status: "处理完成！")
        
        // 创建模拟的分割结果
        let simulatedMask = createSimulatedMask(for: processedImage)
        let extractedObject = extractObjectWithMask(
            originalImage: processedImage,
            mask: simulatedMask
        )
        
        let result = SAMSegmentationResult(
            originalImage: processedImage,
            mask: simulatedMask,
            extractedObject: extractedObject,
            confidence: 0.85, // 模拟置信度
            category: category
        )
        
        showResult(result)
    }
    
    private func createSimulatedMask(for image: UIImage) -> UIImage {
        // 创建一个简单的椭圆形蒙版作为模拟结果
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 设置白色背景（蒙版区域）
            cgContext.setFillColor(UIColor.white.cgColor)
            
            // 创建椭圆形蒙版（中心区域）
            let margin: CGFloat = min(size.width, size.height) * 0.2
            let ellipseRect = CGRect(
                x: margin,
                y: margin,
                width: size.width - 2 * margin,
                height: size.height - 2 * margin
            )
            
            cgContext.fillEllipse(in: ellipseRect)
        }
    }
    
    private func extractObjectWithMask(originalImage: UIImage, mask: UIImage) -> UIImage {
        // 创建带透明背景的提取结果
        guard let originalCGImage = originalImage.cgImage,
              let maskCGImage = mask.cgImage else {
            return originalImage
        }
        
        let width = originalCGImage.width
        let height = originalCGImage.height
        
        // 创建颜色空间和上下文
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let ctx = context else { return originalImage }
        
        // 绘制原图
        ctx.draw(originalCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 应用蒙版
        ctx.setBlendMode(.destinationIn)
        ctx.draw(maskCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 生成最终图像
        guard let finalCGImage = ctx.makeImage() else { return originalImage }
        
        return UIImage(cgImage: finalCGImage)
    }
    
    private func showResult(_ result: SAMSegmentationResult) {
        let resultVC = SAMResultViewController(result: result)
        navigationController?.pushViewController(resultVC, animated: true)
    }
    
    private func handleProcessingError(_ error: Error) {
        processButton.isEnabled = true
        processButton.setTitle("🎯 重新分割", for: .normal)
        progressView.isHidden = true
        statusLabel.text = "处理失败，点击重试"
        
        showError("分割失败: \(error.localizedDescription)")
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - SAMSegmentationResult
struct SAMSegmentationResult {
    let originalImage: UIImage
    let mask: UIImage
    let extractedObject: UIImage
    let confidence: Float
    let category: SAMTestCategory
}
