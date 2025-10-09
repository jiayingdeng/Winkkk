//
//  MultiSubjectCompositeTestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/22.
//  多主体合成测试页面 - 上传视频自动提取关键帧并合成
//

import UIKit
import AVFoundation
import PhotosUI

class MultiSubjectCompositeTestViewController: UIViewController {
    
    // MARK: - UI Components
    
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!
    
    // 控制区域
    @IBOutlet private weak var controlStackView: UIStackView!
    @IBOutlet private weak var selectVideoButton: UIButton!
    @IBOutlet private weak var sceneTypeSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var frameCountSlider: UISlider!
    @IBOutlet private weak var frameCountLabel: UILabel!
    @IBOutlet private weak var processButton: UIButton!
    
    // 进度显示
    @IBOutlet private weak var progressView: UIProgressView!
    @IBOutlet private weak var statusLabel: UILabel!
    
    // 关键帧预览区域
    @IBOutlet private weak var keyFramesStackView: UIStackView!
    @IBOutlet private weak var keyFramesScrollView: UIScrollView!
    
    // 合成结果显示
    @IBOutlet private weak var resultImageView: UIImageView!
    @IBOutlet private weak var resultInfoLabel: UILabel!
    @IBOutlet private weak var saveButton: UIButton!
    
    // MARK: - Properties
    
    private var selectedVideoURL: URL?
    private var extractedFrames: [UIImage] = []
    private var compositeResult: UIImage?
    private let timeSequenceManager = TimeSequenceModeManager.shared
    private let subjectExtractionEngine = SubjectExtractionEngine()
    private var detectionParameters = DetectionParameters()
    private var currentExtractionResults: [ExtractionResult] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "多主体合成测试"
        
        // 设置控制区域
        setupControlArea()
        
        // 设置关键帧预览区域
        setupKeyFramesArea()
        
        // 设置结果显示区域
        setupResultArea()
        
        // 初始状态
        updateUIState(.initial)
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
    }
    
    private func setupControlArea() {
        // 视频选择按钮
        selectVideoButton.setTitle("📹 选择测试视频", for: .normal)
        selectVideoButton.backgroundColor = ThemeManager.buttonPrimary
        selectVideoButton.setTitleColor(ThemeManager.shared.currentTheme == .lightMinimal ? .white : ThemeManager.primaryText, for: .normal)
        selectVideoButton.layer.cornerRadius = 8
        selectVideoButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
        // 场景类型选择 - 使用新的智能检测类型
        sceneTypeSegmentedControl.removeAllSegments()
        for (index, subjectType) in SubjectType.allCases.enumerated() {
            let title = "\(subjectType.icon) \(subjectType.rawValue)"
            sceneTypeSegmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        sceneTypeSegmentedControl.selectedSegmentIndex = 0 // 默认选择食物类
        sceneTypeSegmentedControl.addTarget(self, action: #selector(sceneTypeChanged), for: .valueChanged)
        
        // 帧数滑块
        frameCountSlider.minimumValue = 3
        frameCountSlider.maximumValue = 9
        frameCountSlider.value = 5
        frameCountSlider.isContinuous = true
        updateFrameCountLabel()
        
        // 处理按钮
        processButton.setTitle("🚀 开始智能处理", for: .normal)
        processButton.backgroundColor = ThemeManager.success
        processButton.setTitleColor(.white, for: .normal)
        processButton.layer.cornerRadius = 8
        processButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
        // 进度条
        progressView.isHidden = true
        progressView.progressTintColor = ThemeManager.buttonPrimary
        
        // 添加调试参数界面
        setupDebugParametersUI()
    }
    
    private func setupDebugParametersUI() {
        // 创建调试参数容器
        let debugContainer = UIView()
        debugContainer.backgroundColor = ThemeManager.cardBackground
        debugContainer.layer.cornerRadius = 8
        debugContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "🔧 智能检测参数调试"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = ThemeManager.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建参数滑块
        let parametersStack = createParametersStackView()
        
        // 添加保存配置按钮
        let saveConfigButton = UIButton(type: .system)
        saveConfigButton.setTitle("💾 保存最佳配置", for: .normal)
        saveConfigButton.backgroundColor = ThemeManager.buttonPrimary
        saveConfigButton.setTitleColor(ThemeManager.shared.currentTheme == .lightMinimal ? .white : ThemeManager.primaryText, for: .normal)
        saveConfigButton.layer.cornerRadius = 6
        saveConfigButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        saveConfigButton.addTarget(self, action: #selector(saveBestConfigTapped), for: .touchUpInside)
        saveConfigButton.translatesAutoresizingMaskIntoConstraints = false
        
        debugContainer.addSubview(titleLabel)
        debugContainer.addSubview(parametersStack)
        debugContainer.addSubview(saveConfigButton)
        controlStackView.addArrangedSubview(debugContainer)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: debugContainer.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: debugContainer.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: debugContainer.trailingAnchor, constant: -16),
            
            parametersStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            parametersStack.leadingAnchor.constraint(equalTo: debugContainer.leadingAnchor, constant: 16),
            parametersStack.trailingAnchor.constraint(equalTo: debugContainer.trailingAnchor, constant: -16),
            
            saveConfigButton.topAnchor.constraint(equalTo: parametersStack.bottomAnchor, constant: 12),
            saveConfigButton.centerXAnchor.constraint(equalTo: debugContainer.centerXAnchor),
            saveConfigButton.widthAnchor.constraint(equalToConstant: 120),
            saveConfigButton.heightAnchor.constraint(equalToConstant: 32),
            saveConfigButton.bottomAnchor.constraint(equalTo: debugContainer.bottomAnchor, constant: -12)
        ])
    }
    
    private func createParametersStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 显著性检测阈值
        let saliencySlider = createParameterSlider(
            title: "显著性阈值",
            value: detectionParameters.saliencyThreshold,
            range: 0.1...1.0,
            tag: 1
        )
        
        // 边缘检测阈值
        let edgeSlider = createParameterSlider(
            title: "边缘检测",
            value: detectionParameters.edgeThreshold,
            range: 0.05...0.5,
            tag: 2
        )
        
        // 轮廓平滑度
        let contourSlider = createParameterSlider(
            title: "轮廓平滑",
            value: detectionParameters.contourSmoothness,
            range: 0.1...2.0,
            tag: 3
        )
        
        // 背景移除强度
        let backgroundSlider = createParameterSlider(
            title: "背景移除",
            value: detectionParameters.backgroundRemovalStrength,
            range: 0.1...1.0,
            tag: 4
        )
        
        stackView.addArrangedSubview(saliencySlider)
        stackView.addArrangedSubview(edgeSlider)
        stackView.addArrangedSubview(contourSlider)
        stackView.addArrangedSubview(backgroundSlider)
        
        return stackView
    }
    
    private func createParameterSlider(title: String, value: Float, range: ClosedRange<Float>, tag: Int) -> UIView {
        let container = UIView()
        
        let label = UILabel()
        label.text = "\(title): \(String(format: "%.2f", value))"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let slider = UISlider()
        slider.minimumValue = range.lowerBound
        slider.maximumValue = range.upperBound
        slider.value = value
        slider.tag = tag
        slider.addTarget(self, action: #selector(parameterSliderChanged(_:)), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        container.addSubview(slider)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func setupKeyFramesArea() {
        keyFramesScrollView.showsHorizontalScrollIndicator = true
        keyFramesScrollView.showsVerticalScrollIndicator = false
        keyFramesStackView.axis = .horizontal
        keyFramesStackView.spacing = 8
        keyFramesStackView.distribution = .fillEqually
    }
    
    private func setupResultArea() {
        resultImageView.contentMode = .scaleAspectFit
        resultImageView.backgroundColor = ThemeManager.cardBackground
        resultImageView.layer.cornerRadius = 8
        resultImageView.clipsToBounds = true
        
        saveButton.setTitle("💾 保存到相册", for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonPrimary
        saveButton.setTitleColor(ThemeManager.shared.currentTheme == .lightMinimal ? .white : ThemeManager.primaryText, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        saveButton.isHidden = true
    }
    
    // MARK: - Actions
    
    @IBAction private func selectVideoButtonTapped(_ sender: UIButton) {
        presentVideoSelector()
    }
    
    @IBAction private func frameCountSliderChanged(_ sender: UISlider) {
        updateFrameCountLabel()
    }
    
    @IBAction private func processButtonTapped(_ sender: UIButton) {
        guard let videoURL = selectedVideoURL else {
            showAlert(title: "提示", message: "请先选择一个测试视频")
            return
        }
        
        startProcessing(videoURL: videoURL)
    }
    
    @IBAction private func saveButtonTapped(_ sender: UIButton) {
        guard let image = compositeResult else { return }
        saveImageToPhotos(image)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func sceneTypeChanged() {
        // 更新检测参数中的场景类型
        let selectedType = SubjectType.allCases[sceneTypeSegmentedControl.selectedSegmentIndex]
        detectionParameters.subjectType = selectedType
        subjectExtractionEngine.updateParameters(detectionParameters)
        
        // 如果已有提取结果，重新处理
        if !extractedFrames.isEmpty {
            reprocessCurrentFrames()
        }
    }
    
    @objc private func parameterSliderChanged(_ sender: UISlider) {
        // 更新对应的参数
        switch sender.tag {
        case 1: // 显著性阈值
            detectionParameters.saliencyThreshold = sender.value
        case 2: // 边缘检测
            detectionParameters.edgeThreshold = sender.value
        case 3: // 轮廓平滑
            detectionParameters.contourSmoothness = sender.value
        case 4: // 背景移除
            detectionParameters.backgroundRemovalStrength = sender.value
        default:
            break
        }
        
        // 更新标签显示
        if let container = sender.superview,
           let label = container.subviews.first(where: { $0 is UILabel }) as? UILabel {
            let title = label.text?.components(separatedBy: ":").first ?? ""
            label.text = "\(title): \(String(format: "%.2f", sender.value))"
        }
        
        // 更新引擎参数
        subjectExtractionEngine.updateParameters(detectionParameters)
        
        // 如果已有提取结果，实时更新预览
        if !currentExtractionResults.isEmpty {
            updateStagePreview()
        }
    }
    
    private func reprocessCurrentFrames() {
        guard !extractedFrames.isEmpty else { return }
        
        Task {
            await processFramesWithIntelligentExtraction(frames: extractedFrames)
        }
    }
    
    private func updateStagePreview() {
        // 实时更新三阶段预览（仅更新第一帧作为示例）
        guard let firstFrame = extractedFrames.first else { return }
        
        Task {
            let result = await subjectExtractionEngine.extractSubject(from: firstFrame)
            
            DispatchQueue.main.async { [weak self] in
                self?.updateStagePreviewUI(result: result)
            }
        }
    }
    
    private func updateStagePreviewUI(result: ExtractionResult) {
        // 这里可以更新三阶段预览UI
        // 当前先简单显示在控制台
        print("🔍 检测结果:")
        print("- 场景类型: \(result.detectedSubjectType.rawValue)")
        print("- 置信度: \(String(format: "%.2f", result.confidence))")
        print("- 处理时间: \(String(format: "%.3f", result.processingTime))秒")
    }
    
    @objc private func saveBestConfigTapped() {
        let selectedType = SubjectType.allCases[sceneTypeSegmentedControl.selectedSegmentIndex]
        subjectExtractionEngine.saveBestConfiguration(for: selectedType)
        
        // 显示保存成功提示
        let alert = UIAlertController(
            title: "✅ 配置已保存",
            message: "已保存 \(selectedType.icon) \(selectedType.rawValue) 的最佳参数配置",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Video Selection
    
    private func presentVideoSelector() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Processing
    
    private func startProcessing(videoURL: URL) {
        updateUIState(.processing)
        
        let frameCount = Int(frameCountSlider.value)
        let sceneType: SceneType = sceneTypeSegmentedControl.selectedSegmentIndex == 0 ? .objectChange : .personAction
        
        statusLabel.text = "正在提取关键帧..."
        progressView.setProgress(0.2, animated: true)
        
        // 提取关键帧
        extractKeyFrames(from: videoURL, count: frameCount) { [weak self] frames in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let frames = frames, !frames.isEmpty {
                    self.extractedFrames = frames
                    self.displayKeyFrames(frames)
                    self.progressView.setProgress(0.4, animated: true)
                    self.statusLabel.text = "关键帧提取完成，开始智能主体检测..."
                    
                    // 使用新的智能提取引擎处理
                    Task {
                        await self.processFramesWithIntelligentExtraction(frames: frames)
                    }
                } else {
                    self.updateUIState(.failed)
                    self.statusLabel.text = "关键帧提取失败"
                }
            }
        }
    }
    
    private func extractKeyFrames(from videoURL: URL, count: Int, completion: @escaping ([UIImage]?) -> Void) {
        Task {
            do {
                let asset = AVAsset(url: videoURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.maximumSize = CGSize(width: 1080, height: 1080)
                
                var frames: [UIImage] = []
                
                // 计算均匀分布的时间点
                for i in 0..<count {
                    let progress = Double(i) / Double(count - 1)
                    let timeSeconds = durationSeconds * progress
                    let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)
                    
                    do {
                        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                        let image = UIImage(cgImage: cgImage)
                        frames.append(image)
                    } catch {
                        print("提取第\(i+1)帧失败: \(error)")
                    }
                }
                
                completion(frames.isEmpty ? nil : frames)
            } catch {
                print("视频处理失败: \(error)")
                completion(nil)
            }
        }
    }
    
    private func displayKeyFrames(_ frames: [UIImage]) {
        // 清除之前的视图
        keyFramesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let frameWidth: CGFloat = 100
        let frameHeight: CGFloat = 100
        
        for (index, frame) in frames.enumerated() {
            let containerView = UIView()
            containerView.layer.cornerRadius = 8
            containerView.clipsToBounds = true
            containerView.backgroundColor = .systemGray5
            
            let imageView = UIImageView(image: frame)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            
            let label = UILabel()
            label.text = "帧\(index + 1)"
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textAlignment = .center
            label.textColor = .systemBlue
            
            containerView.addSubview(imageView)
            containerView.addSubview(label)
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                imageView.heightAnchor.constraint(equalToConstant: frameHeight - 20),
                
                label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 2),
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -2)
            ])
            
            containerView.widthAnchor.constraint(equalToConstant: frameWidth).isActive = true
            containerView.heightAnchor.constraint(equalToConstant: frameHeight).isActive = true
            
            keyFramesStackView.addArrangedSubview(containerView)
        }
    }
    
    // MARK: - Intelligent Subject Extraction
    
    /// 使用智能提取引擎处理帧
    private func processFramesWithIntelligentExtraction(frames: [UIImage]) async {
        currentExtractionResults.removeAll()
        
        DispatchQueue.main.async {
            self.statusLabel.text = "🤖 正在进行智能主体检测..."
            self.progressView.setProgress(0.5, animated: true)
        }
        
        // 对每一帧进行智能提取
        for (index, frame) in frames.enumerated() {
            let result = await subjectExtractionEngine.extractSubject(from: frame)
            currentExtractionResults.append(result)
            
            let progress = 0.5 + (0.3 * Float(index + 1) / Float(frames.count))
            DispatchQueue.main.async {
                self.progressView.setProgress(progress, animated: true)
                self.statusLabel.text = "🤖 智能检测中... (\(index + 1)/\(frames.count))"
            }
        }
        
        DispatchQueue.main.async {
            self.statusLabel.text = "🎨 正在创建智能合成..."
            self.progressView.setProgress(0.8, animated: true)
        }
        
        // 使用智能提取结果进行合成
        let result = await createIntelligentComposite(extractionResults: currentExtractionResults)
        
        DispatchQueue.main.async {
            if let result = result {
                self.compositeResult = result
                self.resultImageView.image = result
                self.progressView.setProgress(1.0, animated: true)
                self.statusLabel.text = "✅ 智能合成完成！"
                
                // 显示智能检测结果信息
                self.displayIntelligentDetectionInfo()
                self.updateUIState(.completed)
            } else {
                self.statusLabel.text = "❌ 智能合成失败"
                self.updateUIState(.failed)
            }
        }
    }
    
    /// 使用智能提取结果创建合成图像
    private func createIntelligentComposite(extractionResults: [ExtractionResult]) async -> UIImage? {
        guard let firstResult = extractionResults.first else { return nil }
        
        print("🎯 开始智能多主体合成，帧数: \(extractionResults.count)")
        
        // 计算布局（优先水平排列）
        let layout = calculateIntelligentLayout(
            frameCount: extractionResults.count,
            baseSize: firstResult.originalImage.size,
            detectedType: firstResult.detectedSubjectType
        )
        
        // 创建画布
        UIGraphicsBeginImageContextWithOptions(layout.canvasSize, false, 0.0)
        
        // 使用第一帧作为背景
        firstResult.originalImage.draw(in: CGRect(origin: .zero, size: layout.canvasSize))
        
        // 放置每个智能提取的主体
        for (index, result) in extractionResults.enumerated() {
            let position = layout.positions[index]
            let targetRect = CGRect(origin: position, size: layout.subjectSize)
            
            // 使用智能提取的结果
            result.finalResult.draw(in: targetRect)
        }
        
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("✅ 智能多主体合成完成")
        return compositeImage
    }
    
    /// 计算智能布局（基于检测类型优化）
    private func calculateIntelligentLayout(
        frameCount: Int,
        baseSize: CGSize,
        detectedType: SubjectType
    ) -> (canvasSize: CGSize, positions: [CGPoint], subjectSize: CGSize) {
        
        // 根据检测到的主体类型调整尺寸策略
        let sizeMultiplier: CGFloat = {
            switch detectedType {
            case .food: return 0.3     // 食物类保持较大尺寸
            case .person: return 0.35  // 人物需要更大空间
            case .plant: return 0.28   // 植物可以稍小
            case .object: return 0.32  // 物品中等尺寸
            case .auto: return 0.3     // 默认尺寸
            }
        }()
        
        let subjectWidth = baseSize.width * sizeMultiplier
        let subjectHeight = baseSize.height * sizeMultiplier
        let spacing: CGFloat = 15 // 减小间距，让更多主体能水平排列
        
        // 优先水平排列策略
        if frameCount <= 6 {  // 增加水平排列的上限
            // 水平排列
            let canvasWidth = baseSize.width
            let canvasHeight = baseSize.height
            var positions: [CGPoint] = []
            
            let totalSubjectWidth = CGFloat(frameCount) * subjectWidth + CGFloat(frameCount - 1) * spacing
            
            if totalSubjectWidth <= canvasWidth {
                // 能够完全水平排列
                let startX = (canvasWidth - totalSubjectWidth) / 2
                let centerY = (canvasHeight - subjectHeight) / 2
                
                for i in 0..<frameCount {
                    let x = startX + CGFloat(i) * (subjectWidth + spacing)
                    positions.append(CGPoint(x: x, y: centerY))
                }
            } else {
                // 调整尺寸以适应水平排列
                let adjustedWidth = (canvasWidth - CGFloat(frameCount - 1) * spacing) / CGFloat(frameCount)
                let adjustedHeight = adjustedWidth * (subjectHeight / subjectWidth)
                let centerY = (canvasHeight - adjustedHeight) / 2
                
                for i in 0..<frameCount {
                    let x = CGFloat(i) * (adjustedWidth + spacing)
                    positions.append(CGPoint(x: x, y: centerY))
                }
                
                return (
                    canvasSize: baseSize,
                    positions: positions,
                    subjectSize: CGSize(width: adjustedWidth, height: adjustedHeight)
                )
            }
            
            return (
                canvasSize: baseSize,
                positions: positions,
                subjectSize: CGSize(width: subjectWidth, height: subjectHeight)
            )
        } else {
            // 网格排列（只有在主体太多时才使用）
            let cols = 3
            let rows = (frameCount + cols - 1) / cols
            
            let canvasWidth = baseSize.width
            let canvasHeight = baseSize.height
            
            let gridWidth = CGFloat(cols) * subjectWidth + CGFloat(cols - 1) * spacing
            let gridHeight = CGFloat(rows) * subjectHeight + CGFloat(rows - 1) * spacing
            
            let startX = (canvasWidth - gridWidth) / 2
            let startY = (canvasHeight - gridHeight) / 2
            
            var positions: [CGPoint] = []
            
            for i in 0..<frameCount {
                let row = i / cols
                let col = i % cols
                let x = startX + CGFloat(col) * (subjectWidth + spacing)
                let y = startY + CGFloat(row) * (subjectHeight + spacing)
                positions.append(CGPoint(x: x, y: y))
            }
            
            return (
                canvasSize: baseSize,
                positions: positions,
                subjectSize: CGSize(width: subjectWidth, height: subjectHeight)
            )
        }
    }
    
    /// 显示智能检测信息
    private func displayIntelligentDetectionInfo() {
        guard let firstResult = currentExtractionResults.first else { return }
        
        let avgConfidence = currentExtractionResults.map { $0.confidence }.reduce(0, +) / Float(currentExtractionResults.count)
        let avgProcessingTime = currentExtractionResults.map { $0.processingTime }.reduce(0, +) / Double(currentExtractionResults.count)
        
        let info = """
        🤖 智能检测结果:
        场景类型: \(firstResult.detectedSubjectType.icon) \(firstResult.detectedSubjectType.rawValue)
        提取帧数: \(currentExtractionResults.count)
        平均置信度: \(String(format: "%.1f%%", avgConfidence * 100))
        平均处理时间: \(String(format: "%.2f", avgProcessingTime))秒
        合成尺寸: \(Int(compositeResult?.size.width ?? 0)) × \(Int(compositeResult?.size.height ?? 0))
        """
        resultInfoLabel.text = info
    }
    
    private func performComposite(frames: [UIImage], sceneType: SceneType) {
        // 保留原有方法作为回退机制
        Task {
            let result = await createMultiSubjectComposite(frames: frames, sceneType: sceneType)
            
            DispatchQueue.main.async {
                if let result = result {
                    self.compositeResult = result
                    self.resultImageView.image = result
                    self.progressView.setProgress(1.0, animated: true)
                    self.statusLabel.text = "✅ 合成完成！"
                    
                    let info = """
                    场景类型: \(sceneType == .objectChange ? "物体变化" : "人物动作")
                    提取帧数: \(frames.count)
                    合成尺寸: \(Int(result.size.width)) × \(Int(result.size.height))
                    """
                    self.resultInfoLabel.text = info
                    
                    self.updateUIState(.completed)
                } else {
                    self.statusLabel.text = "❌ 合成失败"
                    self.updateUIState(.failed)
                }
            }
        }
    }
    
    /// 创建多主体合成图像
    private func createMultiSubjectComposite(frames: [UIImage], sceneType: SceneType) async -> UIImage? {
        guard let firstFrame = frames.first else { return nil }
        
        print("🎯 开始多主体合成，帧数: \(frames.count)")
        
        // 计算布局
        let layout = calculateOptimalLayout(frameCount: frames.count, frameSize: firstFrame.size)
        
        // 创建画布
        UIGraphicsBeginImageContextWithOptions(layout.canvasSize, false, 0.0)
        
        // 使用第一帧作为背景
        firstFrame.draw(in: CGRect(origin: .zero, size: layout.canvasSize))
        
        // 提取并放置每个主体
        for (index, frame) in frames.enumerated() {
            let extractedSubject = extractSubjectFromFrame(frame, targetSize: layout.subjectSize)
            let position = layout.positions[index]
            let targetRect = CGRect(origin: position, size: layout.subjectSize)
            
            extractedSubject.draw(in: targetRect)
        }
        
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("✅ 多主体合成完成")
        return compositeImage
    }
    
    /// 计算最佳布局
    private func calculateOptimalLayout(frameCount: Int, frameSize: CGSize) -> (canvasSize: CGSize, positions: [CGPoint], subjectSize: CGSize) {
        let subjectWidth = frameSize.width * 0.25
        let subjectHeight = frameSize.height * 0.3
        let spacing: CGFloat = 20
        
        switch frameCount {
        case 1...3:
            // 水平排列
            let canvasWidth = frameSize.width
            let canvasHeight = frameSize.height
            var positions: [CGPoint] = []
            
            let totalSubjectWidth = CGFloat(frameCount) * subjectWidth + CGFloat(frameCount - 1) * spacing
            let startX = (canvasWidth - totalSubjectWidth) / 2
            let centerY = (canvasHeight - subjectHeight) / 2
            
            for i in 0..<frameCount {
                let x = startX + CGFloat(i) * (subjectWidth + spacing)
                positions.append(CGPoint(x: x, y: centerY))
            }
            
            return (CGSize(width: canvasWidth, height: canvasHeight), positions, CGSize(width: subjectWidth, height: subjectHeight))
            
        default:
            // 网格排列
            let cols = 3
            let rows = (frameCount + cols - 1) / cols
            
            let canvasWidth = frameSize.width
            let canvasHeight = frameSize.height
            var positions: [CGPoint] = []
            
            let totalGridWidth = CGFloat(cols) * subjectWidth + CGFloat(cols - 1) * spacing
            let totalGridHeight = CGFloat(rows) * subjectHeight + CGFloat(rows - 1) * spacing
            let startX = (canvasWidth - totalGridWidth) / 2
            let startY = (canvasHeight - totalGridHeight) / 2
            
            for i in 0..<frameCount {
                let row = i / cols
                let col = i % cols
                let x = startX + CGFloat(col) * (subjectWidth + spacing)
                let y = startY + CGFloat(row) * (subjectHeight + spacing)
                positions.append(CGPoint(x: x, y: y))
            }
            
            return (CGSize(width: canvasWidth, height: canvasHeight), positions, CGSize(width: subjectWidth, height: subjectHeight))
        }
    }
    
    /// 从帧中提取主体
    private func extractSubjectFromFrame(_ frame: UIImage, targetSize: CGSize) -> UIImage {
        // 简单的中心裁剪作为主体提取
        let cropRect = CGRect(
            x: (frame.size.width - targetSize.width) / 2,
            y: (frame.size.height - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        
        guard let cgImage = frame.cgImage?.cropping(to: cropRect) else {
            return frame
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    
    // MARK: - UI State Management
    
    private enum UIState {
        case initial
        case processing
        case completed
        case failed
    }
    
    private func updateUIState(_ state: UIState) {
        switch state {
        case .initial:
            processButton.isEnabled = selectedVideoURL != nil
            progressView.isHidden = true
            statusLabel.text = "选择视频并开始测试"
            saveButton.isHidden = true
            
        case .processing:
            processButton.isEnabled = false
            progressView.isHidden = false
            progressView.setProgress(0.0, animated: false)
            saveButton.isHidden = true
            
        case .completed:
            processButton.isEnabled = true
            progressView.isHidden = true
            saveButton.isHidden = false
            
        case .failed:
            processButton.isEnabled = true
            progressView.isHidden = true
            saveButton.isHidden = true
        }
    }
    
    private func updateFrameCountLabel() {
        let count = Int(frameCountSlider.value)
        frameCountLabel.text = "提取帧数: \(count)"
    }
    
    // MARK: - Helper Methods
    
    private func saveImageToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        let title = error == nil ? "保存成功" : "保存失败"
        let message = error?.localizedDescription ?? "图片已保存到相册"
        showAlert(title: title, message: message)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension MultiSubjectCompositeTestViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showAlert(title: "错误", message: "视频加载失败: \(error.localizedDescription)")
                }
                return
            }
            
            guard let url = url else { return }
            
            // 复制到临时目录
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                DispatchQueue.main.async {
                    self?.selectedVideoURL = tempURL
                    self?.selectVideoButton.setTitle("✅ 视频已选择", for: .normal)
                    self?.selectVideoButton.backgroundColor = .systemGreen
                    self?.updateUIState(.initial)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(title: "错误", message: "视频处理失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
