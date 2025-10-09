//
//  VideoSegmentationTestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/25.
//  视频分割测试页面控制器
//

import UIKit
import AVFoundation
import MobileCoreServices
import UniformTypeIdentifiers
import PhotosUI

class VideoSegmentationTestViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 头部区域
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // 视频选择区域
    private let videoSelectionView = UIView()
    private let selectVideoButton = UIButton(type: .system)
    private let videoInfoLabel = UILabel()
    
    // 处理控制区域
    private let controlView = UIView()
    private let startProcessingButton = UIButton(type: .system)
    private let frameCountSlider = UISlider()
    private let frameCountLabel = UILabel()
    
    // 进度显示区域
    private let progressView = UIView()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let progressLabel = UILabel()
    private let timeRemainingLabel = UILabel()
    
    // 结果展示区域
    private let resultsHeaderView = UIView()
    private let resultsHeaderLabel = UILabel()
    private let statisticsLabel = UILabel()
    
    private let collectionView: UICollectionView
    private let flowLayout = UICollectionViewFlowLayout()
    
    // 底部操作区域
    private let bottomActionsView = UIView()
    private let exportButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    
    // MARK: - Properties
    private var currentVideoURL: URL?
    private var currentVideoInfo: ExtractedVideoInfo?
    private var frameResults: [FrameSegmentationResult] = []
    private var processingSession: VideoSegmentationSession?
    
    private var frameExtractor = VideoFrameExtractor.shared
    private var deepLabManager = DeepLabV3Manager.shared
    
    private var isProcessing = false
    private var processingStartTime: Date?
    private var currentProcessingIndex = 0
    
    // 图片预览相关属性
    private var currentPreviewImage: UIImage?
    private var currentPreviewTitle: String?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        initializeDeepLab()
    }
    
    init() {
        // 设置CollectionView布局
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumInteritemSpacing = 0 // 单列布局不需要列间距
        flowLayout.minimumLineSpacing = 20 // 增加行间距
        flowLayout.sectionInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.background
        navigationItem.title = "视频分割测试"
        navigationItem.largeTitleDisplayMode = .never
        
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        setupScrollView()
        setupHeaderViews()
        setupVideoSelectionView()
        setupControlView()
        setupProgressView()
        setupResultsView()
        setupBottomActions()
        
        updateUIState()
    }
    
    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
    }
    
    private func setupHeaderViews() {
        titleLabel.text = "📹 视频分割测试"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = ThemeManager.primaryText
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "从相册选择视频，自动提取关键帧并进行DeepLabV3主体分割测试"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = ThemeManager.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        [titleLabel, subtitleLabel].forEach {
            contentView.addSubview($0)
        }
    }
    
    private func setupVideoSelectionView() {
        videoSelectionView.backgroundColor = ThemeManager.cardBackground
        videoSelectionView.layer.cornerRadius = 12
        
        selectVideoButton.setTitle("📱 从相册选择视频", for: .normal)
        selectVideoButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        selectVideoButton.backgroundColor = ThemeManager.buttonPrimary
        selectVideoButton.setTitleColor(ThemeManager.shared.currentTheme == .lightMinimal ? .white : ThemeManager.primaryText, for: .normal)
        selectVideoButton.layer.cornerRadius = 10
        selectVideoButton.addTarget(self, action: #selector(selectVideoTapped), for: .touchUpInside)
        
        videoInfoLabel.text = "尚未选择视频"
        videoInfoLabel.font = .systemFont(ofSize: 14, weight: .regular)
        videoInfoLabel.textColor = ThemeManager.secondaryText
        videoInfoLabel.numberOfLines = 0
        videoInfoLabel.textAlignment = .center
        
        [selectVideoButton, videoInfoLabel].forEach {
            videoSelectionView.addSubview($0)
        }
        
        contentView.addSubview(videoSelectionView)
    }
    
    private func setupControlView() {
        controlView.backgroundColor = ThemeManager.cardBackground
        controlView.layer.cornerRadius = 12
        controlView.layer.borderWidth = 1
        controlView.layer.borderColor = ThemeManager.separator.cgColor
        
        startProcessingButton.setTitle("🚀 开始处理", for: .normal)
        startProcessingButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        startProcessingButton.backgroundColor = ThemeManager.success
        startProcessingButton.setTitleColor(.white, for: .normal)
        startProcessingButton.layer.cornerRadius = 8
        startProcessingButton.addTarget(self, action: #selector(startProcessingTapped), for: .touchUpInside)
        
        frameCountSlider.minimumValue = 3
        frameCountSlider.maximumValue = 10
        frameCountSlider.value = 5
        frameCountSlider.addTarget(self, action: #selector(frameCountChanged), for: .valueChanged)
        
        frameCountLabel.text = "提取帧数: 5"
        frameCountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        frameCountLabel.textColor = ThemeManager.primaryText
        frameCountLabel.textAlignment = .center
        
        [startProcessingButton, frameCountSlider, frameCountLabel].forEach {
            controlView.addSubview($0)
        }
        
        contentView.addSubview(controlView)
    }
    
    private func setupProgressView() {
        progressView.backgroundColor = ThemeManager.cardBackground.withAlphaComponent(0.8)
        progressView.layer.cornerRadius = 10
        progressView.isHidden = true
        
        progressBar.progressTintColor = ThemeManager.buttonPrimary
        progressBar.trackTintColor = ThemeManager.separator
        
        progressLabel.text = "正在处理..."
        progressLabel.font = .systemFont(ofSize: 14, weight: .medium)
        progressLabel.textColor = ThemeManager.primaryText
        progressLabel.textAlignment = .center
        
        timeRemainingLabel.text = ""
        timeRemainingLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeRemainingLabel.textColor = ThemeManager.secondaryText
        timeRemainingLabel.textAlignment = .center
        
        [progressBar, progressLabel, timeRemainingLabel].forEach {
            progressView.addSubview($0)
        }
        
        contentView.addSubview(progressView)
    }
    
    private func setupResultsView() {
        // 结果标题区域
        resultsHeaderView.backgroundColor = ThemeManager.background
        
        resultsHeaderLabel.text = "🎯 分割结果"
        resultsHeaderLabel.font = .systemFont(ofSize: 20, weight: .bold)
        resultsHeaderLabel.textColor = ThemeManager.primaryText
        
        statisticsLabel.text = ""
        statisticsLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statisticsLabel.textColor = ThemeManager.secondaryText
        statisticsLabel.numberOfLines = 0
        
        [resultsHeaderLabel, statisticsLabel].forEach {
            resultsHeaderView.addSubview($0)
        }
        
        // 配置CollectionView
        collectionView.backgroundColor = ThemeManager.background
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(
            FrameSegmentationCollectionViewCell.self,
            forCellWithReuseIdentifier: FrameSegmentationCollectionViewCell.identifier
        )
        
        [resultsHeaderView, collectionView].forEach {
            contentView.addSubview($0)
        }
    }
    
    private func setupBottomActions() {
        bottomActionsView.backgroundColor = ThemeManager.cardBackground.withAlphaComponent(0.5)
        bottomActionsView.layer.cornerRadius = 12
        
        exportButton.setTitle("📤 导出结果", for: .normal)
        exportButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        exportButton.backgroundColor = ThemeManager.buttonPrimary
        exportButton.setTitleColor(ThemeManager.shared.currentTheme == .lightMinimal ? .white : ThemeManager.primaryText, for: .normal)
        exportButton.layer.cornerRadius = 8
        exportButton.addTarget(self, action: #selector(exportResultsTapped), for: .touchUpInside)
        
        clearButton.setTitle("🗑 清除结果", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        clearButton.backgroundColor = ThemeManager.error
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.layer.cornerRadius = 8
        clearButton.addTarget(self, action: #selector(clearResultsTapped), for: .touchUpInside)
        
        [exportButton, clearButton].forEach {
            bottomActionsView.addSubview($0)
        }
        
        contentView.addSubview(bottomActionsView)
    }
    
    private func setupConstraints() {
        [scrollView, contentView, titleLabel, subtitleLabel, videoSelectionView,
         selectVideoButton, videoInfoLabel, controlView, startProcessingButton,
         frameCountSlider, frameCountLabel, progressView, progressBar,
         progressLabel, timeRemainingLabel, resultsHeaderView, resultsHeaderLabel,
         statisticsLabel, collectionView, bottomActionsView, exportButton,
         clearButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Headers
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Video Selection
            videoSelectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 25),
            videoSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            videoSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            videoSelectionView.heightAnchor.constraint(equalToConstant: 120),
            
            selectVideoButton.topAnchor.constraint(equalTo: videoSelectionView.topAnchor, constant: 15),
            selectVideoButton.centerXAnchor.constraint(equalTo: videoSelectionView.centerXAnchor),
            selectVideoButton.widthAnchor.constraint(equalToConstant: 200),
            selectVideoButton.heightAnchor.constraint(equalToConstant: 44),
            
            videoInfoLabel.topAnchor.constraint(equalTo: selectVideoButton.bottomAnchor, constant: 10),
            videoInfoLabel.leadingAnchor.constraint(equalTo: videoSelectionView.leadingAnchor, constant: 15),
            videoInfoLabel.trailingAnchor.constraint(equalTo: videoSelectionView.trailingAnchor, constant: -15),
            videoInfoLabel.bottomAnchor.constraint(equalTo: videoSelectionView.bottomAnchor, constant: -15),
            
            // Control View
            controlView.topAnchor.constraint(equalTo: videoSelectionView.bottomAnchor, constant: 20),
            controlView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            controlView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            controlView.heightAnchor.constraint(equalToConstant: 120),
            
            startProcessingButton.topAnchor.constraint(equalTo: controlView.topAnchor, constant: 15),
            startProcessingButton.centerXAnchor.constraint(equalTo: controlView.centerXAnchor),
            startProcessingButton.widthAnchor.constraint(equalToConstant: 150),
            startProcessingButton.heightAnchor.constraint(equalToConstant: 36),
            
            frameCountSlider.topAnchor.constraint(equalTo: startProcessingButton.bottomAnchor, constant: 15),
            frameCountSlider.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 20),
            frameCountSlider.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -20),
            
            frameCountLabel.topAnchor.constraint(equalTo: frameCountSlider.bottomAnchor, constant: 8),
            frameCountLabel.centerXAnchor.constraint(equalTo: controlView.centerXAnchor),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: controlView.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 80),
            
            progressBar.topAnchor.constraint(equalTo: progressView.topAnchor, constant: 15),
            progressBar.leadingAnchor.constraint(equalTo: progressView.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: progressView.trailingAnchor, constant: -20),
            
            progressLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            progressLabel.centerXAnchor.constraint(equalTo: progressView.centerXAnchor),
            
            timeRemainingLabel.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 5),
            timeRemainingLabel.centerXAnchor.constraint(equalTo: progressView.centerXAnchor),
            
            // Results Header
            resultsHeaderView.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 25),
            resultsHeaderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsHeaderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultsHeaderView.heightAnchor.constraint(equalToConstant: 80),
            
            resultsHeaderLabel.topAnchor.constraint(equalTo: resultsHeaderView.topAnchor),
            resultsHeaderLabel.leadingAnchor.constraint(equalTo: resultsHeaderView.leadingAnchor),
            
            statisticsLabel.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 8),
            statisticsLabel.leadingAnchor.constraint(equalTo: resultsHeaderView.leadingAnchor),
            statisticsLabel.trailingAnchor.constraint(equalTo: resultsHeaderView.trailingAnchor),
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: resultsHeaderView.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 600), // 增加高度以适应单列布局
            
            // Bottom Actions
            bottomActionsView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 20),
            bottomActionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bottomActionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bottomActionsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            bottomActionsView.heightAnchor.constraint(equalToConstant: 60),
            
            exportButton.leadingAnchor.constraint(equalTo: bottomActionsView.leadingAnchor, constant: 15),
            exportButton.centerYAnchor.constraint(equalTo: bottomActionsView.centerYAnchor),
            exportButton.widthAnchor.constraint(equalToConstant: 120),
            exportButton.heightAnchor.constraint(equalToConstant: 36),
            
            clearButton.trailingAnchor.constraint(equalTo: bottomActionsView.trailingAnchor, constant: -15),
            clearButton.centerYAnchor.constraint(equalTo: bottomActionsView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 120),
            clearButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    // MARK: - DeepLab Initialization
    private func initializeDeepLab() {
        do {
            try deepLabManager.initialize()
        } catch {
            showAlert(title: "初始化失败", message: "DeepLabV3模型初始化失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func selectVideoTapped() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func startProcessingTapped() {
        guard let videoURL = currentVideoURL else {
            showAlert(title: "错误", message: "请先选择视频文件")
            return
        }
        
        guard !isProcessing else {
            showAlert(title: "提示", message: "正在处理中，请等待当前任务完成")
            return
        }
        
        let frameCount = Int(frameCountSlider.value)
        startVideoProcessing(videoURL: videoURL, frameCount: frameCount)
    }
    
    @objc private func frameCountChanged() {
        let count = Int(frameCountSlider.value)
        frameCountLabel.text = "提取帧数: \(count)"
    }
    
    @objc private func exportResultsTapped() {
        guard let session = processingSession else {
            showAlert(title: "提示", message: "没有可导出的结果")
            return
        }
        
        exportProcessingResults(session)
    }
    
    @objc private func clearResultsTapped() {
        clearAllResults()
    }
    
    // MARK: - Video Processing
    private func startVideoProcessing(videoURL: URL, frameCount: Int) {
        isProcessing = true
        processingStartTime = Date()
        currentProcessingIndex = 0
        frameResults.removeAll()
        
        updateUIState()
        showProgressView()
        
        // 第一步：提取视频帧
        frameExtractor.extractFrames(
            from: videoURL,
            frameCount: frameCount,
            progressCallback: { [weak self] current, total in
                DispatchQueue.main.async {
                    let progress = Float(current) / Float(total) * 0.3 // 帧提取占30%进度
                    self?.updateProgress(progress, message: "提取视频帧 \(current)/\(total)")
                }
            },
            completion: { [weak self] result in
                switch result {
                case .success(let frames):
                    self?.processExtractedFrames(frames, from: videoURL)
                case .failure(let error):
                    self?.handleProcessingError(error)
                }
            }
        )
    }
    
    private func processExtractedFrames(_ frames: [UIImage], from videoURL: URL) {
        guard let videoInfo = currentVideoInfo else { return }
        
        let totalFrames = frames.count
        let frameDuration = videoInfo.duration / Double(totalFrames)
        
        // 创建初始结果数据
        for (index, frame) in frames.enumerated() {
            let timePosition = frameDuration * Double(index)
            let result = FrameSegmentationResult(
                frameIndex: index,
                timePosition: timePosition,
                originalImage: frame,
                segmentationResult: DeepLabSegmentationResult(
                    originalImage: frame,
                    subjectImage: frame,
                    maskImage: frame,
                    confidence: 0.0,
                    subjectPixelRatio: 0.0,
                    maskQuality: 0.0
                ),
                processingTime: 0.0,
                status: .pending
            )
            frameResults.append(result)
        }
        
        // 更新UI显示所有帧
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
        
        // 开始批量分割处理
        processFramesSequentially()
    }
    
    private func processFramesSequentially() {
        guard currentProcessingIndex < frameResults.count else {
            // 所有处理完成
            completeProcessing()
            return
        }
        
        let frameIndex = currentProcessingIndex
        var frameResult = frameResults[frameIndex]
        
        // 更新状态为处理中
        frameResult.status = .processing
        frameResults[frameIndex] = frameResult
        
        DispatchQueue.main.async {
            let indexPath = IndexPath(item: frameIndex, section: 0)
            self.collectionView.reloadItems(at: [indexPath])
        }
        
        let startTime = Date()
        
        // 进行分割
        deepLabManager.segmentSubjects(from: frameResult.originalImage) { [weak self] result in
            let processingTime = Date().timeIntervalSince(startTime)
            
            switch result {
            case .success(let segmentationResult):
                // 创建完成的结果
                let completedResult = FrameSegmentationResult(
                    frameIndex: frameResult.frameIndex,
                    timePosition: frameResult.timePosition,
                    originalImage: frameResult.originalImage,
                    segmentationResult: segmentationResult,
                    processingTime: processingTime,
                    status: .completed
                )
                
                self?.frameResults[frameIndex] = completedResult
                
                DispatchQueue.main.async {
                    let indexPath = IndexPath(item: frameIndex, section: 0)
                    if let cell = self?.collectionView.cellForItem(at: indexPath) as? FrameSegmentationCollectionViewCell {
                        cell.configure(with: completedResult)
                        cell.playCompletionAnimation()
                    }
                }
                
            case .failure(let error):
                // 处理失败
                frameResult.status = .failed(error)
                self?.frameResults[frameIndex] = frameResult
                
                DispatchQueue.main.async {
                    let indexPath = IndexPath(item: frameIndex, section: 0)
                    self?.collectionView.reloadItems(at: [indexPath])
                }
            }
            
            // 更新进度
            self?.currentProcessingIndex += 1
            let progress = 0.3 + (Float(self?.currentProcessingIndex ?? 0) / Float(self?.frameResults.count ?? 1)) * 0.7
            let message = "分割处理 \(self?.currentProcessingIndex ?? 0)/\(self?.frameResults.count ?? 0)"
            
            DispatchQueue.main.async {
                self?.updateProgress(progress, message: message)
                
                // 继续处理下一帧
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                    self?.processFramesSequentially()
                }
            }
        }
    }
    
    private func completeProcessing() {
        guard let extractedVideoInfo = currentVideoInfo else { return }
        
        isProcessing = false
        // Convert ExtractedVideoInfo to VideoInfo
        let videoInfo = VideoInfo(
            width: Int32(extractedVideoInfo.resolution.width),
            height: Int32(extractedVideoInfo.resolution.height),
            duration: extractedVideoInfo.duration
        )
        processingSession = VideoSegmentationSession(videoInfo: videoInfo, frameResults: frameResults)
        
        DispatchQueue.main.async {
            self.updateProgress(1.0, message: "处理完成！")
            self.hideProgressView()
            self.updateStatistics()
            self.updateUIState()
        }
    }
    
    private func handleProcessingError(_ error: Error) {
        isProcessing = false
        
        DispatchQueue.main.async {
            self.hideProgressView()
            self.updateUIState()
            self.showAlert(title: "处理失败", message: error.localizedDescription)
        }
    }
    
    // MARK: - UI Updates
    private func updateUIState() {
        startProcessingButton.isEnabled = !isProcessing && currentVideoURL != nil
        selectVideoButton.isEnabled = !isProcessing
        frameCountSlider.isEnabled = !isProcessing
        
        let hasResults = !frameResults.isEmpty
        exportButton.isEnabled = hasResults && !isProcessing
        clearButton.isEnabled = hasResults && !isProcessing
        bottomActionsView.isHidden = !hasResults
        
        if isProcessing {
            startProcessingButton.setTitle("处理中...", for: .normal)
            startProcessingButton.backgroundColor = .systemGray
        } else {
            startProcessingButton.setTitle("🚀 开始处理", for: .normal)
            startProcessingButton.backgroundColor = .systemGreen
        }
    }
    
    private func showProgressView() {
        progressView.isHidden = false
        progressBar.progress = 0.0
        progressLabel.text = "正在准备..."
        timeRemainingLabel.text = ""
    }
    
    private func hideProgressView() {
        progressView.isHidden = true
    }
    
    private func updateProgress(_ progress: Float, message: String) {
        progressBar.progress = progress
        progressLabel.text = message
        
        // 计算剩余时间
        if let startTime = processingStartTime, progress > 0.1 {
            let elapsedTime = Date().timeIntervalSince(startTime)
            let estimatedTotalTime = elapsedTime / Double(progress)
            let remainingTime = estimatedTotalTime - elapsedTime
            
            if remainingTime > 0 {
                timeRemainingLabel.text = String(format: "预计剩余: %.0f秒", remainingTime)
            }
        }
    }
    
    private func updateStatistics() {
        guard let session = processingSession else { return }
        statisticsLabel.text = session.sessionStats.formattedSummary
    }
    
    // MARK: - Helper Methods
    private func clearAllResults() {
        frameResults.removeAll()
        processingSession = nil
        collectionView.reloadData()
        statisticsLabel.text = ""
        updateUIState()
    }
    
    private func exportProcessingResults(_ session: VideoSegmentationSession) {
        let subjectImages = frameResults.compactMap { result -> UIImage? in
            if case .completed = result.status {
                return result.subjectImage
            }
            return nil
        }
        
        guard !subjectImages.isEmpty else {
            showAlert(title: "无可导出内容", message: "没有找到已完成的主体图")
            return
        }
        
        let alert = UIAlertController(
            title: "导出主体图",
            message: "发现 \(subjectImages.count) 张主体图，是否全部保存到相册？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "全部保存", style: .default) { _ in
            self.batchSaveImages(subjectImages)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func batchSaveImages(_ images: [UIImage]) {
        // 检查权限
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.performBatchImageSave(images)
                case .denied, .restricted:
                    self?.showPermissionDeniedAlert()
                case .notDetermined:
                    self?.showAlert(title: "权限未确定", message: "请在设置中允许访问相册权限")
                @unknown default:
                    self?.showAlert(title: "未知错误", message: "无法获取相册权限状态")
                }
            }
        }
    }
    
    private func performBatchImageSave(_ images: [UIImage]) {
        let totalCount = images.count
        var successCount = 0
        var errorCount = 0
        
        // 创建进度提示
        let alert = UIAlertController(title: "正在保存...", message: "0/\(totalCount)", preferredStyle: .alert)
        present(alert, animated: true)
        
        let dispatchGroup = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            dispatchGroup.enter()
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        successCount += 1
                    } else {
                        errorCount += 1
                    }
                    
                    // 更新进度
                    alert.message = "\(successCount + errorCount)/\(totalCount)"
                    
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            alert.dismiss(animated: true) {
                self.showBatchSaveResult(successCount: successCount, errorCount: errorCount, totalCount: totalCount)
            }
        }
    }
    
    private func showBatchSaveResult(successCount: Int, errorCount: Int, totalCount: Int) {
        let title: String
        let message: String
        
        if errorCount == 0 {
            title = "全部保存成功 ✅"
            message = "已成功保存 \(successCount) 张主体图到相册"
        } else if successCount == 0 {
            title = "保存失败 ❌"
            message = "所有图片保存失败"
        } else {
            title = "部分保存成功 ⚠️"
            message = "成功保存 \(successCount) 张，失败 \(errorCount) 张"
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension VideoSegmentationTestViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        // 获取视频文件
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
            guard let url = url, error == nil else {
                DispatchQueue.main.async {
                    self?.showAlert(title: "错误", message: "无法加载选择的视频文件")
                }
                return
            }
            
            // 复制到临时目录
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                DispatchQueue.main.async {
                    self?.currentVideoURL = tempURL
                    
                    // 获取视频信息
                    Task {
                        if let videoInfo = await self?.frameExtractor.getVideoInfo(from: tempURL) {
                            await MainActor.run {
                                self?.currentVideoInfo = videoInfo
                                self?.updateVideoInfo(videoInfo)
                                self?.updateUIState()
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(title: "错误", message: "无法处理选择的视频文件：\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateVideoInfo(_ info: ExtractedVideoInfo) {
        videoInfoLabel.text = """
        📱 从相册选择的视频
        🎬 时长: \(info.formattedDuration) | 分辨率: \(info.formattedResolution)
        📊 大小: \(info.formattedFileSize) | 帧率: \(String(format: "%.1f fps", info.frameRate))
        """
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate
extension VideoSegmentationTestViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return frameResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FrameSegmentationCollectionViewCell.identifier,
            for: indexPath
        ) as! FrameSegmentationCollectionViewCell
        
        let result = frameResults[indexPath.item]
        cell.configure(with: result)
        cell.delegate = self
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 30 // 单列布局，左右各15间距
        // 计算实际需要的高度：headerView(40) + imageStackView(280) + metricsView(50) + spacing(24) + padding(16) = 410
        let height: CGFloat = 410
        return CGSize(width: width, height: height)
    }
}

// MARK: - FrameSegmentationCellDelegate
extension VideoSegmentationTestViewController: FrameSegmentationCellDelegate {
    
    func frameSegmentationCell(_ cell: FrameSegmentationCollectionViewCell, didTapOriginalImage image: UIImage, frameIndex: Int) {
        showImagePreview(image: image, title: "原图 - 帧 \(frameIndex + 1)")
    }
    
    func frameSegmentationCell(_ cell: FrameSegmentationCollectionViewCell, didTapSubjectImage image: UIImage, frameIndex: Int) {
        showImagePreview(image: image, title: "主体图 - 帧 \(frameIndex + 1)")
    }
    
    func frameSegmentationCell(_ cell: FrameSegmentationCollectionViewCell, didLongPressSubjectImage image: UIImage, frameIndex: Int, at location: CGPoint) {
        showContextMenu(for: image, frameIndex: frameIndex, at: location, in: cell)
    }
    
    private func showImagePreview(image: UIImage, title: String) {
        // 检查是否已经有模态视图在展示
        if presentedViewController != nil {
            print("⚠️ 已有模态视图在展示，跳过图片预览")
            return
        }
        
        // 创建图片预览视图控制器
        let previewVC = UIViewController()
        previewVC.view.backgroundColor = .systemBackground
        previewVC.title = title
        
        // 创建图片视图
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        previewVC.view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: previewVC.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: previewVC.view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: previewVC.view.trailingAnchor, constant: -20),
            imageView.bottomAnchor.constraint(equalTo: previewVC.view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // 添加关闭按钮
        previewVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .done,
            target: self,
            action: #selector(dismissImagePreview)
        )
        
        // 添加操作按钮
        var actions: [UIBarButtonItem] = []
        
        if title.contains("主体图") {
            let saveButton = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.down"),
                style: .plain,
                target: self,
                action: #selector(saveCurrentPreviewImage)
            )
            saveButton.accessibilityLabel = "保存到相册"
            
            let shareButton = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain,
                target: self,
                action: #selector(shareCurrentPreviewImage)
            )
            shareButton.accessibilityLabel = "分享图片"
            
            actions.append(contentsOf: [saveButton, shareButton])
        }
        
        let infoButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(showCurrentImageInfo)
        )
        infoButton.accessibilityLabel = "图片信息"
        actions.append(infoButton)
        
        if !actions.isEmpty {
            previewVC.navigationItem.leftBarButtonItems = actions
        }
        
        // 存储当前预览的图片和标题，供按钮操作使用
        currentPreviewImage = image
        currentPreviewTitle = title
        
        let navController = UINavigationController(rootViewController: previewVC)
        navController.modalPresentationStyle = .pageSheet
        
        present(navController, animated: true)
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        // 检查权限
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.performImageSave(image)
                case .denied, .restricted:
                    self?.showPermissionDeniedAlert()
                case .notDetermined:
                    self?.showAlert(title: "权限未确定", message: "请在设置中允许访问相册权限")
                @unknown default:
                    self?.showAlert(title: "未知错误", message: "无法获取相册权限状态")
                }
            }
        }
    }
    
    private func performImageSave(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAsset(from: image)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showSuccessAlert()
                } else {
                    self?.showAlert(title: "保存失败", message: error?.localizedDescription ?? "未知错误")
                }
            }
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "需要相册权限",
            message: "请在设置中允许Winkkk访问相册，以保存主体图片",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: "保存成功 ✅",
            message: "主体图已成功保存到相册",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func shareImage(_ image: UIImage) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    private func showImageInfo(_ image: UIImage, title: String) {
        let size = image.size
        let scale = image.scale
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // 计算图片大小（字节）
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return }
        let sizeInBytes = imageData.count
        let sizeInKB = Double(sizeInBytes) / 1024.0
        let sizeInMB = sizeInKB / 1024.0
        
        let sizeString: String
        if sizeInMB >= 1.0 {
            sizeString = String(format: "%.2f MB", sizeInMB)
        } else {
            sizeString = String(format: "%.1f KB", sizeInKB)
        }
        
        // 尝试获取处理信息
        var processingInfo = ""
        if title.contains("帧") {
            let frameNumber = extractFrameNumber(from: title)
            if frameNumber > 0 && frameNumber <= frameResults.count {
                let result = frameResults[frameNumber - 1]
                if case .completed = result.status {
                    let processingTime = result.processingTime
                    let timeString = processingTime < 1.0 ? 
                        String(format: "%.0fms", processingTime * 1000) : 
                        String(format: "%.2fs", processingTime)
                    
                    processingInfo = """
                    
                    🔬 处理信息:
                    ⏱ 处理时间: \(timeString)
                    🎯 置信度: \(Int(result.confidence * 100))%
                    📊 主体占比: \(String(format: "%.1f%%", result.subjectPixelRatio * 100))
                    ⭐ 质量评级: \(result.quality.displayText)
                    """
                }
            }
        }
        
        let info = """
        📸 图片信息
        
        🏷 标题: \(title)
        📐 显示尺寸: \(Int(size.width)) × \(Int(size.height))
        🔍 像素尺寸: \(Int(pixelSize.width)) × \(Int(pixelSize.height))
        📊 文件大小: \(sizeString)
        🎨 色彩空间: \(image.cgImage?.colorSpace?.name.map { String($0) } ?? "未知")
        📱 缩放比例: \(scale)x\(processingInfo)
        """
        
        let alert = UIAlertController(title: "图片信息", message: info, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func extractFrameNumber(from title: String) -> Int {
        let pattern = "帧\\s*(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
            let numberRange = match.range(at: 1)
            if let range = Range(numberRange, in: title) {
                return Int(String(title[range])) ?? 0
            }
        }
        return 0
    }
    
    private func showContextMenu(for image: UIImage, frameIndex: Int, at location: CGPoint, in cell: UICollectionViewCell) {
        let alert = UIAlertController(title: "主体图 - 帧 \(frameIndex + 1)", message: "选择操作", preferredStyle: .actionSheet)
        
        // 快速保存
        alert.addAction(UIAlertAction(title: "💾 保存到相册", style: .default) { _ in
            self.saveImageToPhotos(image)
        })
        
        // 快速分享
        alert.addAction(UIAlertAction(title: "📤 分享图片", style: .default) { _ in
            self.shareImage(image)
        })
        
        // 查看大图
        alert.addAction(UIAlertAction(title: "🔍 查看大图", style: .default) { _ in
            self.showImagePreview(image: image, title: "主体图 - 帧 \(frameIndex + 1)")
        })
        
        // 图片信息
        alert.addAction(UIAlertAction(title: "ℹ️ 图片信息", style: .default) { _ in
            self.showImageInfo(image, title: "主体图 - 帧 \(frameIndex + 1)")
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = CGRect(x: location.x, y: location.y, width: 1, height: 1)
            popover.permittedArrowDirections = .any
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Image Preview Actions
    
    @objc private func dismissImagePreview() {
        dismiss(animated: true)
    }
    
    @objc private func saveCurrentPreviewImage() {
        guard let image = currentPreviewImage else { return }
        saveImageToPhotos(image)
    }
    
    @objc private func shareCurrentPreviewImage() {
        guard let image = currentPreviewImage else { return }
        shareImage(image)
    }
    
    @objc private func showCurrentImageInfo() {
        guard let image = currentPreviewImage,
              let title = currentPreviewTitle else { return }
        showImageInfo(image, title: title)
    }
}
