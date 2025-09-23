//
//  SubjectExtractionDebugViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/22.
//  主体提取调试页面 - 专门测试和调试三阶段主体提取算法
//

import UIKit
import Photos
import AVFoundation

class SubjectExtractionDebugViewController: UIViewController {
    
    // MARK: - Properties
    
    private let subjectExtractionEngine = SubjectExtractionEngine()
    private var detectionParameters = DetectionParameters()
    private var currentTestImage: UIImage?
    private var currentExtractionResult: ExtractionResult?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header
    private let subtitleLabel = UILabel()
    
    // 图像选择区域
    private let imageSelectionCard = UIView()
    private let selectImageButton = UIButton(type: .system)
    private let originalImageView = UIImageView()
    private let imageInfoLabel = UILabel()
    
    // 参数调节区域
    private let parametersCard = UIView()
    private let parametersLabel = UILabel()
    private var parameterSliders: [UISlider] = []
    
    // 场景类型选择
    private let sceneTypeCard = UIView()
    private let sceneTypeLabel = UILabel()
    private let sceneTypeSegmentedControl = UISegmentedControl()
    
    // 处理按钮
    private let processButton = UIButton(type: .system)
    private let processingIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    
    // 三阶段结果展示
    private let resultsCard = UIView()
    private let resultsLabel = UILabel()
    
    // Stage 1: Vision框架检测结果
    private let stage1Card = UIView()
    private let stage1Label = UILabel()
    private let stage1ImageView = UIImageView()
    private let stage1InfoLabel = UILabel()
    
    // Stage 2: 轮廓检测结果  
    private let stage2Card = UIView()
    private let stage2Label = UILabel()
    private let stage2ImageView = UIImageView()
    private let stage2InfoLabel = UILabel()
    
    // Stage 3: 最终提取结果
    private let stage3Card = UIView()
    private let stage3Label = UILabel()
    private let stage3ImageView = UIImageView()
    private let stage3InfoLabel = UILabel()
    
    // 性能信息
    // 复杂背景预设区域
    private let presetsCard = UIView()
    private let presetsLabel = UILabel()
    private let breadPresetButton = UIButton(type: .system)
    private let metalReflectionButton = UIButton(type: .system)
    private let outdoorLightButton = UIButton(type: .system)
    private let resetDefaultButton = UIButton(type: .system)
    
    private let performanceCard = UIView()
    private let performanceLabel = UILabel()
    private let performanceInfoLabel = UILabel()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        setupConstraints()
        loadDefaultParameters()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 强制清理所有可能的重叠元素
        cleanupOverlappingElements()
        
        // 重新设置副标题
        subtitleLabel.text = "🤖 测试Vision框架 + Core Image + 颜色分析三阶段算法"
        subtitleLabel.setNeedsDisplay()
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    // MARK: - Setup Methods
    
    private func cleanupOverlappingElements() {
        // 清理所有可能导致重叠的元素
        view.subviews.forEach { subview in
            removeOverlappingElements(from: subview)
        }
        contentView.subviews.forEach { subview in
            removeOverlappingElements(from: subview)
        }
    }
    
    private func removeOverlappingElements(from view: UIView) {
        // 递归清理所有子视图中的重叠元素
        if let label = view as? UILabel {
            let text = label.text ?? ""
            if label != subtitleLabel && 
               (text.contains("数据预设") || text.contains("智能数据") || text.contains("预设")) {
                label.removeFromSuperview()
                return
            }
        }
        
        if let button = view as? UIButton {
            let title = button.title(for: .normal) ?? ""
            if title.contains("数据预设") || title.contains("智能数据") {
                button.removeFromSuperview()
                return
            }
        }
        
        // 递归检查子视图
        view.subviews.forEach { subview in
            removeOverlappingElements(from: subview)
        }
    }
    
    private func setupNavigation() {
        title = "主体提取调试"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 确保导航栏不透明，避免内容重叠
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.backgroundColor = .systemBackground
        
        // 强制设置导航栏外观以避免重叠
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        // 添加返回按钮
        let backButton = UIBarButtonItem(
            title: "返回",
            style: .plain,
            target: self,
            action: #selector(dismissViewController)
        )
        navigationItem.leftBarButtonItem = backButton
        
        // 添加保存结果按钮
        let saveButton = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveResults)
        )
        navigationItem.rightBarButtonItem = saveButton
        saveButton.isEnabled = false
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeaderSection()
        setupImageSelectionSection()
        setupParametersSection()
        setupComplexBackgroundPresets()
        setupSceneTypeSection()
        setupProcessSection()
        setupResultsSection()
        setupPerformanceSection()
    }
    
    private func setupHeaderSection() {
        // 清理任何可能的重复标签
        contentView.subviews.compactMap { $0 as? UILabel }.forEach { label in
            if label != subtitleLabel && (label.text?.contains("数据预设") == true || label.text?.contains("智能") == true) {
                label.removeFromSuperview()
            }
        }
        
        // 移除重复的大标题，使用简洁的说明文字
        subtitleLabel.text = "🤖 测试Vision框架 + Core Image + 颜色分析三阶段算法"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .systemBlue
        subtitleLabel.numberOfLines = 0
        subtitleLabel.backgroundColor = .clear // 确保背景透明
        
        // 只添加副标题，避免与导航栏标题重叠
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
    }
    
    private func setupImageSelectionSection() {
        imageSelectionCard.backgroundColor = UIColor.systemGray6
        imageSelectionCard.layer.cornerRadius = 12
        imageSelectionCard.layer.shadowColor = UIColor.black.cgColor
        imageSelectionCard.layer.shadowOffset = CGSize(width: 0, height: 2)
        imageSelectionCard.layer.shadowOpacity = 0.1
        imageSelectionCard.layer.shadowRadius = 4
        
        selectImageButton.setTitle("📸 选择测试图像", for: .normal)
        selectImageButton.setTitleColor(.white, for: .normal)
        selectImageButton.backgroundColor = .systemBlue
        selectImageButton.layer.cornerRadius = 8
        selectImageButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        selectImageButton.addTarget(self, action: #selector(selectImageTapped), for: .touchUpInside)
        
        originalImageView.contentMode = .scaleAspectFit
        originalImageView.backgroundColor = UIColor.systemGray5
        originalImageView.layer.cornerRadius = 8
        originalImageView.clipsToBounds = true
        originalImageView.image = UIImage(systemName: "photo.on.rectangle")
        originalImageView.tintColor = .systemGray3
        
        imageInfoLabel.text = "请选择一张包含明显主体的图像进行测试"
        imageInfoLabel.font = UIFont.systemFont(ofSize: 14)
        imageInfoLabel.textColor = .systemGray
        imageInfoLabel.textAlignment = .center
        imageInfoLabel.numberOfLines = 0
        
        [imageSelectionCard, selectImageButton, originalImageView, imageInfoLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        imageSelectionCard.addSubview(selectImageButton)
        imageSelectionCard.addSubview(originalImageView)
        imageSelectionCard.addSubview(imageInfoLabel)
    }
    
    private func setupParametersSection() {
        parametersCard.backgroundColor = UIColor.systemGray6
        parametersCard.layer.cornerRadius = 12
        
        parametersLabel.text = "🎛️ 算法参数调节"
        parametersLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        [parametersCard, parametersLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        parametersCard.addSubview(parametersLabel)
        
        // 创建参数滑块
        createParameterSliders()
    }
    
    private func createParameterSliders() {
        let parameters = [
            ("显著性阈值", detectionParameters.saliencyThreshold, 0.0...1.0),
            ("Vision置信度", detectionParameters.visionConfidenceThreshold, 0.0...1.0),
            ("边缘检测阈值", detectionParameters.edgeThreshold, 0.01...0.5),
            ("轮廓平滑度", detectionParameters.contourSmoothness, 0.1...2.0),
            ("形态学半径", detectionParameters.morphologyRadius, 1.0...10.0),
            ("背景移除强度", detectionParameters.backgroundRemovalStrength, 0.1...1.0),
            ("羽化半径", detectionParameters.featherRadius, 1.0...20.0),
            ("对比度增强", detectionParameters.contrastEnhancement, 0.5...2.0),
            ("亮度调整", detectionParameters.brightnessAdjustment + 0.5, 0.0...1.0)  // 转换为正值显示
        ]
        
        for (index, (title, value, range)) in parameters.enumerated() {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            
            let label = UILabel()
            label.text = "\(title): \(String(format: "%.2f", value))"
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            let slider = UISlider()
            slider.minimumValue = Float(range.lowerBound)
            slider.maximumValue = Float(range.upperBound) 
            slider.value = value
            slider.tag = index
            slider.addTarget(self, action: #selector(parameterSliderChanged(_:)), for: .valueChanged)
            slider.translatesAutoresizingMaskIntoConstraints = false
            
            container.addSubview(label)
            container.addSubview(slider)
            parametersCard.addSubview(container)
            parameterSliders.append(slider)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                
                slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
                slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                slider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                
                container.heightAnchor.constraint(equalToConstant: 60),
                container.leadingAnchor.constraint(equalTo: parametersCard.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(equalTo: parametersCard.trailingAnchor, constant: -16)
            ])
            
            if index == 0 {
                container.topAnchor.constraint(equalTo: parametersLabel.bottomAnchor, constant: 16).isActive = true
            } else {
                container.topAnchor.constraint(equalTo: parameterSliders[index-1].superview!.bottomAnchor, constant: 8).isActive = true
            }
        }
    }
    
    private func setupComplexBackgroundPresets() {
        presetsCard.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        presetsCard.layer.cornerRadius = 12
        presetsCard.layer.borderWidth = 1
        presetsCard.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
        
        presetsLabel.text = "⚙️ 复杂背景快速预设"
        presetsLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        presetsLabel.textColor = .systemOrange
        
        // 面包烘烤预设
        breadPresetButton.setTitle("🍞 面包/烘烤预设", for: .normal)
        breadPresetButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.2)
        breadPresetButton.layer.cornerRadius = 8
        breadPresetButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        breadPresetButton.addTarget(self, action: #selector(applyBreadPreset), for: .touchUpInside)
        
        // 金属反光预设
        metalReflectionButton.setTitle("🔧 金属反光预设", for: .normal)
        metalReflectionButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.2)
        metalReflectionButton.layer.cornerRadius = 8
        metalReflectionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        metalReflectionButton.addTarget(self, action: #selector(applyMetalReflectionPreset), for: .touchUpInside)
        
        // 强光环境预设
        outdoorLightButton.setTitle("☀️ 强光环境预设", for: .normal)
        outdoorLightButton.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2)
        outdoorLightButton.layer.cornerRadius = 8
        outdoorLightButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        outdoorLightButton.addTarget(self, action: #selector(applyOutdoorLightPreset), for: .touchUpInside)
        
        // 重置默认
        resetDefaultButton.setTitle("🔄 重置默认", for: .normal)
        resetDefaultButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
        resetDefaultButton.layer.cornerRadius = 8
        resetDefaultButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        resetDefaultButton.addTarget(self, action: #selector(resetToDefault), for: .touchUpInside)
        
        [presetsCard, presetsLabel, breadPresetButton, metalReflectionButton, outdoorLightButton, resetDefaultButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        presetsCard.addSubview(presetsLabel)
        presetsCard.addSubview(breadPresetButton)
        presetsCard.addSubview(metalReflectionButton)
        presetsCard.addSubview(outdoorLightButton)
        presetsCard.addSubview(resetDefaultButton)
    }
    
    private func setupSceneTypeSection() {
        sceneTypeCard.backgroundColor = UIColor.systemGray6
        sceneTypeCard.layer.cornerRadius = 12
        
        sceneTypeLabel.text = "🎯 场景类型选择"
        sceneTypeLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        // 创建场景类型选择控件
        let items = SubjectType.allCases.map { "\($0.icon) \($0.rawValue)" }
        sceneTypeSegmentedControl.removeAllSegments()
        for (index, item) in items.enumerated() {
            sceneTypeSegmentedControl.insertSegment(withTitle: item, at: index, animated: false)
        }
        sceneTypeSegmentedControl.selectedSegmentIndex = 4 // 默认选择"自动检测"
        sceneTypeSegmentedControl.addTarget(self, action: #selector(sceneTypeChanged), for: .valueChanged)
        
        [sceneTypeCard, sceneTypeLabel, sceneTypeSegmentedControl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        sceneTypeCard.addSubview(sceneTypeLabel)
        sceneTypeCard.addSubview(sceneTypeSegmentedControl)
    }
    
    private func setupProcessSection() {
        processButton.setTitle("🚀 开始三阶段提取", for: .normal)
        processButton.setTitleColor(.white, for: .normal)
        processButton.backgroundColor = .systemGreen
        processButton.layer.cornerRadius = 12
        processButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        processButton.addTarget(self, action: #selector(startExtraction), for: .touchUpInside)
        processButton.isEnabled = false
        
        processingIndicator.hidesWhenStopped = true
        processingIndicator.color = .systemBlue
        
        statusLabel.text = "请先选择测试图像"
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .systemGray
        statusLabel.numberOfLines = 0
        
        [processButton, processingIndicator, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
    }
    
    private func setupResultsSection() {
        resultsCard.backgroundColor = UIColor.systemGray6
        resultsCard.layer.cornerRadius = 12
        resultsCard.isHidden = true
        
        resultsLabel.text = "📊 三阶段提取结果"
        resultsLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        [resultsCard, resultsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        resultsCard.addSubview(resultsLabel)
        
        setupStageCards()
    }
    
    private func setupStageCards() {
        // Stage 1 Card
        setupStageCard(
            card: stage1Card,
            label: stage1Label,
            imageView: stage1ImageView,
            infoLabel: stage1InfoLabel,
            title: "🔍 第一阶段：Vision框架检测",
            description: "显著性检测 + 场景分类 + 粗略定位"
        )
        
        // Stage 2 Card  
        setupStageCard(
            card: stage2Card,
            label: stage2Label,
            imageView: stage2ImageView,
            infoLabel: stage2InfoLabel,
            title: "✂️ 第二阶段：轮廓检测优化",
            description: "边缘检测 + 轮廓优化 + 精确边界"
        )
        
        // Stage 3 Card
        setupStageCard(
            card: stage3Card,
            label: stage3Label,
            imageView: stage3ImageView,
            infoLabel: stage3InfoLabel,
            title: "🎨 第三阶段：背景移除",
            description: "颜色分析 + 背景移除 + 最终提取"
        )
    }
    
    private func setupStageCard(
        card: UIView,
        label: UILabel,
        imageView: UIImageView,
        infoLabel: UILabel,
        title: String,
        description: String
    ) {
        card.backgroundColor = UIColor.systemBackground
        card.layer.cornerRadius = 8
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.systemGray4.cgColor
        
        label.text = title
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .systemBlue
        
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.systemGray6
        imageView.layer.cornerRadius = 6
        imageView.clipsToBounds = true
        
        infoLabel.text = description
        infoLabel.font = UIFont.systemFont(ofSize: 12)
        infoLabel.textColor = .systemGray
        infoLabel.numberOfLines = 0
        
        [card, label, imageView, infoLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            resultsCard.addSubview($0)
        }
        
        card.addSubview(label)
        card.addSubview(imageView)
        card.addSubview(infoLabel)
    }
    
    private func setupPerformanceSection() {
        performanceCard.backgroundColor = UIColor.systemGray6
        performanceCard.layer.cornerRadius = 12
        performanceCard.isHidden = true
        
        performanceLabel.text = "⚡ 性能分析"
        performanceLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        performanceInfoLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        performanceInfoLabel.textColor = .systemGray
        performanceInfoLabel.numberOfLines = 0
        
        [performanceCard, performanceLabel, performanceInfoLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        performanceCard.addSubview(performanceLabel)
        performanceCard.addSubview(performanceInfoLabel)
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View - 增加额外的安全边距避免重叠
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header - 只保留副标题
            subtitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Image Selection Card
            imageSelectionCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            imageSelectionCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageSelectionCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageSelectionCard.heightAnchor.constraint(equalToConstant: 280),
            
            selectImageButton.topAnchor.constraint(equalTo: imageSelectionCard.topAnchor, constant: 16),
            selectImageButton.leadingAnchor.constraint(equalTo: imageSelectionCard.leadingAnchor, constant: 16),
            selectImageButton.trailingAnchor.constraint(equalTo: imageSelectionCard.trailingAnchor, constant: -16),
            selectImageButton.heightAnchor.constraint(equalToConstant: 44),
            
            originalImageView.topAnchor.constraint(equalTo: selectImageButton.bottomAnchor, constant: 16),
            originalImageView.leadingAnchor.constraint(equalTo: imageSelectionCard.leadingAnchor, constant: 16),
            originalImageView.trailingAnchor.constraint(equalTo: imageSelectionCard.trailingAnchor, constant: -16),
            originalImageView.heightAnchor.constraint(equalToConstant: 160),
            
            imageInfoLabel.topAnchor.constraint(equalTo: originalImageView.bottomAnchor, constant: 8),
            imageInfoLabel.leadingAnchor.constraint(equalTo: imageSelectionCard.leadingAnchor, constant: 16),
            imageInfoLabel.trailingAnchor.constraint(equalTo: imageSelectionCard.trailingAnchor, constant: -16),
            imageInfoLabel.bottomAnchor.constraint(equalTo: imageSelectionCard.bottomAnchor, constant: -16),
            
            // Parameters Card
            parametersCard.topAnchor.constraint(equalTo: imageSelectionCard.bottomAnchor, constant: 20),
            parametersCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            parametersCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            parametersLabel.topAnchor.constraint(equalTo: parametersCard.topAnchor, constant: 16),
            parametersLabel.leadingAnchor.constraint(equalTo: parametersCard.leadingAnchor, constant: 16),
            parametersLabel.trailingAnchor.constraint(equalTo: parametersCard.trailingAnchor, constant: -16),
            
            // Scene Type Card
            sceneTypeCard.topAnchor.constraint(equalTo: parametersCard.bottomAnchor, constant: 20),
            sceneTypeCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sceneTypeCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sceneTypeCard.heightAnchor.constraint(equalToConstant: 100),
            
            sceneTypeLabel.topAnchor.constraint(equalTo: sceneTypeCard.topAnchor, constant: 16),
            sceneTypeLabel.leadingAnchor.constraint(equalTo: sceneTypeCard.leadingAnchor, constant: 16),
            sceneTypeLabel.trailingAnchor.constraint(equalTo: sceneTypeCard.trailingAnchor, constant: -16),
            
            sceneTypeSegmentedControl.topAnchor.constraint(equalTo: sceneTypeLabel.bottomAnchor, constant: 12),
            sceneTypeSegmentedControl.leadingAnchor.constraint(equalTo: sceneTypeCard.leadingAnchor, constant: 16),
            sceneTypeSegmentedControl.trailingAnchor.constraint(equalTo: sceneTypeCard.trailingAnchor, constant: -16),
            sceneTypeSegmentedControl.bottomAnchor.constraint(equalTo: sceneTypeCard.bottomAnchor, constant: -16),
            
            // Process Section
            processButton.topAnchor.constraint(equalTo: sceneTypeCard.bottomAnchor, constant: 24),
            processButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            processButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            processButton.heightAnchor.constraint(equalToConstant: 50),
            
            processingIndicator.topAnchor.constraint(equalTo: processButton.bottomAnchor, constant: 16),
            processingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: processingIndicator.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Results Card
            resultsCard.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            resultsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            resultsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            resultsLabel.topAnchor.constraint(equalTo: resultsCard.topAnchor, constant: 16),
            resultsLabel.leadingAnchor.constraint(equalTo: resultsCard.leadingAnchor, constant: 16),
            resultsLabel.trailingAnchor.constraint(equalTo: resultsCard.trailingAnchor, constant: -16),
        ])
        
        setupStageCardConstraints()
        
        NSLayoutConstraint.activate([
            // Performance Card
            performanceCard.topAnchor.constraint(equalTo: resultsCard.bottomAnchor, constant: 20),
            performanceCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            performanceCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            performanceCard.heightAnchor.constraint(equalToConstant: 120),
            performanceCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            performanceLabel.topAnchor.constraint(equalTo: performanceCard.topAnchor, constant: 16),
            performanceLabel.leadingAnchor.constraint(equalTo: performanceCard.leadingAnchor, constant: 16),
            performanceLabel.trailingAnchor.constraint(equalTo: performanceCard.trailingAnchor, constant: -16),
            
            performanceInfoLabel.topAnchor.constraint(equalTo: performanceLabel.bottomAnchor, constant: 8),
            performanceInfoLabel.leadingAnchor.constraint(equalTo: performanceCard.leadingAnchor, constant: 16),
            performanceInfoLabel.trailingAnchor.constraint(equalTo: performanceCard.trailingAnchor, constant: -16),
            performanceInfoLabel.bottomAnchor.constraint(equalTo: performanceCard.bottomAnchor, constant: -16),
        ])
        
        // Update parameters card height
        if let lastSlider = parameterSliders.last {
            NSLayoutConstraint.activate([
                parametersCard.bottomAnchor.constraint(equalTo: lastSlider.superview!.bottomAnchor, constant: 16)
            ])
        }
    }
    
    private func setupStageCardConstraints() {
        let cards = [stage1Card, stage2Card, stage3Card]
        let imageViews = [stage1ImageView, stage2ImageView, stage3ImageView]
        let labels = [stage1Label, stage2Label, stage3Label] 
        let infoLabels = [stage1InfoLabel, stage2InfoLabel, stage3InfoLabel]
        
        for (index, card) in cards.enumerated() {
            let imageView = imageViews[index]
            let label = labels[index]
            let infoLabel = infoLabels[index]
            
            NSLayoutConstraint.activate([
                // Card positioning
                card.leadingAnchor.constraint(equalTo: resultsCard.leadingAnchor, constant: 16),
                card.trailingAnchor.constraint(equalTo: resultsCard.trailingAnchor, constant: -16),
                card.heightAnchor.constraint(equalToConstant: 200),
                
                // Label
                label.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
                
                // Image View
                imageView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
                imageView.heightAnchor.constraint(equalToConstant: 120),
                
                // Info Label
                infoLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
                infoLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                infoLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
                infoLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            ])
            
            if index == 0 {
                card.topAnchor.constraint(equalTo: resultsLabel.bottomAnchor, constant: 16).isActive = true
            } else {
                card.topAnchor.constraint(equalTo: cards[index-1].bottomAnchor, constant: 16).isActive = true
            }
            
            if index == cards.count - 1 {
                resultsCard.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: 16).isActive = true
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func selectImageTapped() {
        let alert = UIAlertController(title: "选择图像", message: "选择测试图像来源", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "从相册选择", style: .default) { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        })
        
        alert.addAction(UIAlertAction(title: "拍照", style: .default) { _ in
            self.presentImagePicker(sourceType: .camera)
        })
        
        alert.addAction(UIAlertAction(title: "使用示例图像", style: .default) { _ in
            self.loadSampleImage()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = selectImageButton
            popover.sourceRect = selectImageButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            showAlert(title: "不可用", message: "该功能在此设备上不可用")
            return
        }
        
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    private func loadSampleImage() {
        // 使用系统图标作为示例
        if let sampleImage = UIImage(systemName: "heart.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal) {
            setupSelectedImage(sampleImage)
        }
    }
    
    @objc private func parameterSliderChanged(_ sender: UISlider) {
        // 更新对应的参数
        switch sender.tag {
        case 0: detectionParameters.saliencyThreshold = sender.value
        case 1: detectionParameters.visionConfidenceThreshold = sender.value
        case 2: detectionParameters.edgeThreshold = sender.value
        case 3: detectionParameters.contourSmoothness = sender.value
        case 4: detectionParameters.morphologyRadius = sender.value
        case 5: detectionParameters.backgroundRemovalStrength = sender.value
        case 6: detectionParameters.featherRadius = sender.value
        case 7: detectionParameters.contrastEnhancement = sender.value
        case 8: detectionParameters.brightnessAdjustment = sender.value - 0.5  // 转换回正负值
        default: break
        }
        
        // 更新标签显示
        if let container = sender.superview,
           let label = container.subviews.first(where: { $0 is UILabel }) as? UILabel {
            let title = label.text?.components(separatedBy: ":").first ?? ""
            label.text = "\(title): \(String(format: "%.2f", sender.value))"
        }
        
        // 更新引擎参数
        subjectExtractionEngine.updateParameters(detectionParameters)
        
        // 如果有结果，可以选择实时更新
        // updatePreviewIfNeeded()
    }
    
    @objc private func sceneTypeChanged() {
        let selectedType = SubjectType.allCases[sceneTypeSegmentedControl.selectedSegmentIndex]
        detectionParameters.subjectType = selectedType
        subjectExtractionEngine.updateParameters(detectionParameters)
        
        print("🎯 场景类型切换为: \(selectedType.rawValue)")
    }
    
    // MARK: - Preset Actions
    
    @objc private func applyBreadPreset() {
        // 🍞 面包/烘烤预设：专门针对你的面包图像优化
        detectionParameters.saliencyThreshold = 0.35
        detectionParameters.visionConfidenceThreshold = 0.25
        detectionParameters.edgeThreshold = 0.03  // 降低以检测更细微边缘
        detectionParameters.contourSmoothness = 1.2  // 增加以平滑圆形轮廓
        detectionParameters.morphologyRadius = 2.0  // 适中的半径
        detectionParameters.backgroundRemovalStrength = 0.85  // 增强以对抗金属反光
        detectionParameters.featherRadius = 3.0  // 保持边缘清晰
        detectionParameters.contrastEnhancement = 1.3  // 增强对比度
        detectionParameters.brightnessAdjustment = -0.15  // 减少反光
        detectionParameters.subjectType = .food
        
        updateUIWithCurrentParameters()
        showPresetAppliedFeedback("🍞 已应用面包/烘烤预设")
    }
    
    @objc private func applyMetalReflectionPreset() {
        // 🔧 金属反光预设：针对强反光背景
        detectionParameters.saliencyThreshold = 0.4
        detectionParameters.visionConfidenceThreshold = 0.2
        detectionParameters.edgeThreshold = 0.02
        detectionParameters.contourSmoothness = 1.5
        detectionParameters.morphologyRadius = 3.0
        detectionParameters.backgroundRemovalStrength = 0.9
        detectionParameters.featherRadius = 2.5
        detectionParameters.contrastEnhancement = 1.4
        detectionParameters.brightnessAdjustment = -0.2
        detectionParameters.subjectType = .object
        
        updateUIWithCurrentParameters()
        showPresetAppliedFeedback("🔧 已应用金属反光预设")
    }
    
    @objc private func applyOutdoorLightPreset() {
        // ☀️ 强光环境预设：适合强光照射的复杂环境
        detectionParameters.saliencyThreshold = 0.45
        detectionParameters.visionConfidenceThreshold = 0.3
        detectionParameters.edgeThreshold = 0.04
        detectionParameters.contourSmoothness = 1.0
        detectionParameters.morphologyRadius = 2.5
        detectionParameters.backgroundRemovalStrength = 0.75
        detectionParameters.featherRadius = 4.0
        detectionParameters.contrastEnhancement = 1.1
        detectionParameters.brightnessAdjustment = -0.05
        detectionParameters.subjectType = .auto
        
        updateUIWithCurrentParameters()
        showPresetAppliedFeedback("☀️ 已应用强光环境预设")
    }
    
    @objc private func resetToDefault() {
        // 🔄 重置为默认参数
        detectionParameters = DetectionParameters()
        updateUIWithCurrentParameters()
        showPresetAppliedFeedback("🔄 已重置为默认参数")
    }
    
    private func updateUIWithCurrentParameters() {
        // 更新所有滑块和UI显示
        let parameterValues = [
            detectionParameters.saliencyThreshold,
            detectionParameters.visionConfidenceThreshold,
            detectionParameters.edgeThreshold,
            detectionParameters.contourSmoothness,
            detectionParameters.morphologyRadius,
            detectionParameters.backgroundRemovalStrength,
            detectionParameters.featherRadius,
            detectionParameters.contrastEnhancement,
            detectionParameters.brightnessAdjustment + 0.5  // 转换为显示值
        ]
        
        let parameterTitles = [
            "显著性阈值", "Vision置信度", "边缘检测阈值", "轮廓平滑度",
            "形态学半径", "背景移除强度", "羽化半径", "对比度增强", "亮度调整"
        ]
        
        for (index, slider) in parameterSliders.enumerated() {
            if index < parameterValues.count {
                slider.value = parameterValues[index]
                
                // 更新标签
                if let container = slider.superview,
                   let label = container.subviews.first(where: { $0 is UILabel }) as? UILabel {
                    label.text = "\(parameterTitles[index]): \(String(format: "%.2f", parameterValues[index]))"
                }
            }
        }
        
        // 更新场景类型选择器
        if let typeIndex = SubjectType.allCases.firstIndex(of: detectionParameters.subjectType) {
            sceneTypeSegmentedControl.selectedSegmentIndex = typeIndex
        }
        
        // 更新引擎参数
        subjectExtractionEngine.updateParameters(detectionParameters)
    }
    
    private func showPresetAppliedFeedback(_ message: String) {
        let alert = UIAlertController(title: "预设已应用", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
        
        // 可选：添加视觉反馈
        AnimationManager.shared.showSuccessFeedback(in: view, message: message)
    }
    
    @objc private func startExtraction() {
        guard let testImage = currentTestImage else {
            showAlert(title: "错误", message: "请先选择测试图像")
            return
        }
        
        print("🚀 开始三阶段主体提取...")
        
        // UI状态切换
        processButton.isEnabled = false
        processingIndicator.startAnimating()
        statusLabel.text = "🤖 正在进行智能主体提取..."
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        // 隐藏之前的结果
        resultsCard.isHidden = true
        performanceCard.isHidden = true
        
        Task {
            // 执行三阶段提取
            let result = await subjectExtractionEngine.extractSubject(from: testImage)
            
            DispatchQueue.main.async { [weak self] in
                self?.handleExtractionResult(result)
            }
        }
    }
    
    @objc private func dismissViewController() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func saveResults() {
        guard let result = currentExtractionResult else { return }
        
        // 保存最终结果到相册
        UIImageWriteToSavedPhotosAlbum(result.finalResult, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showAlert(title: "保存失败", message: error.localizedDescription)
        } else {
            showAlert(title: "保存成功", message: "提取结果已保存到相册")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadDefaultParameters() {
        detectionParameters = DetectionParameters()
        subjectExtractionEngine.updateParameters(detectionParameters)
        sceneTypeSegmentedControl.selectedSegmentIndex = 4 // 自动检测
    }
    
    private func setupSelectedImage(_ image: UIImage) {
        currentTestImage = image
        originalImageView.image = image
        
        // 更新图像信息
        let size = image.size
        let scale = image.scale
        imageInfoLabel.text = "图像尺寸: \(Int(size.width))×\(Int(size.height)) 比例: \(scale)x"
        imageInfoLabel.textColor = .systemBlue
        
        // 启用处理按钮
        processButton.isEnabled = true
        statusLabel.text = "✅ 图像已选择，可以开始提取"
        statusLabel.textColor = .systemGreen
        
        print("📸 已选择测试图像: \(Int(size.width))×\(Int(size.height))")
    }
    
    private func handleExtractionResult(_ result: ExtractionResult) {
        currentExtractionResult = result
        
        // 更新UI状态
        processButton.isEnabled = true
        processingIndicator.stopAnimating()
        navigationItem.rightBarButtonItem?.isEnabled = true
        
        if let error = result.errorMessage {
            statusLabel.text = "❌ 提取失败: \(error)"
            statusLabel.textColor = .systemRed
            return
        }
        
        statusLabel.text = "✅ 提取完成！检测类型: \(result.detectedSubjectType.icon)\(result.detectedSubjectType.rawValue)"
        statusLabel.textColor = .systemGreen
        
        // 显示结果
        displayExtractionResults(result)
        
        print("✅ 三阶段提取完成，处理时间: \(String(format: "%.2f", result.processingTime))秒")
    }
    
    private func displayExtractionResults(_ result: ExtractionResult) {
        // 显示结果卡片
        resultsCard.isHidden = false
        performanceCard.isHidden = false
        
        // Stage 1 结果
        if let stage1Image = result.stage1Result {
            stage1ImageView.image = stage1Image
            stage1InfoLabel.text = "检测类型: \(result.detectedSubjectType.rawValue)\n置信度: \(String(format: "%.1f%%", result.confidence * 100))"
            stage1InfoLabel.textColor = .systemGreen
        } else {
            stage1ImageView.image = UIImage(systemName: "xmark.circle.fill")?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            stage1InfoLabel.text = "第一阶段检测失败"
            stage1InfoLabel.textColor = .systemRed
        }
        
        // Stage 2 结果
        if let stage2Image = result.stage2Result {
            stage2ImageView.image = stage2Image
            let bounds = result.boundingRect
            stage2InfoLabel.text = "边界: (\(Int(bounds.origin.x)), \(Int(bounds.origin.y))) \(Int(bounds.width))×\(Int(bounds.height))"
            stage2InfoLabel.textColor = .systemGreen
        } else {
            stage2ImageView.image = UIImage(systemName: "xmark.circle.fill")?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            stage2InfoLabel.text = "第二阶段轮廓检测失败"
            stage2InfoLabel.textColor = .systemRed
        }
        
        // Stage 3 结果（最终结果）
        stage3ImageView.image = result.finalResult
        let finalSize = result.finalResult.size
        stage3InfoLabel.text = "最终尺寸: \(Int(finalSize.width))×\(Int(finalSize.height))\n提取质量: \(result.confidence > 0.7 ? "优秀" : result.confidence > 0.4 ? "良好" : "一般")"
        stage3InfoLabel.textColor = .systemGreen
        
        // 性能信息
        let processingTime = result.processingTime
        let imageSize = result.originalImage.size
        performanceInfoLabel.text = """
        处理时间: \(String(format: "%.3f", processingTime)) 秒
        原图尺寸: \(Int(imageSize.width)) × \(Int(imageSize.height))
        检测置信度: \(String(format: "%.1f%%", result.confidence * 100))
        算法效率: \(processingTime < 1.0 ? "优秀" : processingTime < 3.0 ? "良好" : "需优化")
        """
        
        // 滚动到结果区域
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let resultsRect = self.resultsCard.frame
            self.scrollView.scrollRectToVisible(resultsRect, animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension SubjectExtractionDebugViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage else {
            showAlert(title: "错误", message: "无法获取选择的图像")
            return
        }
        
        setupSelectedImage(image)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
