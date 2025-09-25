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
        flowLayout.minimumInteritemSpacing = 10
        flowLayout.minimumLineSpacing = 15
        flowLayout.sectionInset = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "视频分割测试"
        navigationItem.largeTitleDisplayMode = .never
        
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
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "选择视频文件，自动提取关键帧并进行DeepLabV3主体分割测试"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .systemGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        [titleLabel, subtitleLabel].forEach {
            contentView.addSubview($0)
        }
    }
    
    private func setupVideoSelectionView() {
        videoSelectionView.backgroundColor = .systemGray6
        videoSelectionView.layer.cornerRadius = 12
        
        selectVideoButton.setTitle("📁 选择视频文件", for: .normal)
        selectVideoButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        selectVideoButton.backgroundColor = .systemBlue
        selectVideoButton.setTitleColor(.white, for: .normal)
        selectVideoButton.layer.cornerRadius = 10
        selectVideoButton.addTarget(self, action: #selector(selectVideoTapped), for: .touchUpInside)
        
        videoInfoLabel.text = "尚未选择视频"
        videoInfoLabel.font = .systemFont(ofSize: 14, weight: .regular)
        videoInfoLabel.textColor = .systemGray
        videoInfoLabel.numberOfLines = 0
        videoInfoLabel.textAlignment = .center
        
        [selectVideoButton, videoInfoLabel].forEach {
            videoSelectionView.addSubview($0)
        }
        
        contentView.addSubview(videoSelectionView)
    }
    
    private func setupControlView() {
        controlView.backgroundColor = .systemBackground
        controlView.layer.cornerRadius = 12
        controlView.layer.borderWidth = 1
        controlView.layer.borderColor = UIColor.systemGray4.cgColor
        
        startProcessingButton.setTitle("🚀 开始处理", for: .normal)
        startProcessingButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        startProcessingButton.backgroundColor = .systemGreen
        startProcessingButton.setTitleColor(.white, for: .normal)
        startProcessingButton.layer.cornerRadius = 8
        startProcessingButton.addTarget(self, action: #selector(startProcessingTapped), for: .touchUpInside)
        
        frameCountSlider.minimumValue = 3
        frameCountSlider.maximumValue = 10
        frameCountSlider.value = 5
        frameCountSlider.addTarget(self, action: #selector(frameCountChanged), for: .valueChanged)
        
        frameCountLabel.text = "提取帧数: 5"
        frameCountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        frameCountLabel.textAlignment = .center
        
        [startProcessingButton, frameCountSlider, frameCountLabel].forEach {
            controlView.addSubview($0)
        }
        
        contentView.addSubview(controlView)
    }
    
    private func setupProgressView() {
        progressView.backgroundColor = .systemGray6.withAlphaComponent(0.8)
        progressView.layer.cornerRadius = 10
        progressView.isHidden = true
        
        progressBar.progressTintColor = .systemBlue
        progressBar.trackTintColor = .systemGray4
        
        progressLabel.text = "正在处理..."
        progressLabel.font = .systemFont(ofSize: 14, weight: .medium)
        progressLabel.textAlignment = .center
        
        timeRemainingLabel.text = ""
        timeRemainingLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeRemainingLabel.textColor = .systemGray
        timeRemainingLabel.textAlignment = .center
        
        [progressBar, progressLabel, timeRemainingLabel].forEach {
            progressView.addSubview($0)
        }
        
        contentView.addSubview(progressView)
    }
    
    private func setupResultsView() {
        // 结果标题区域
        resultsHeaderView.backgroundColor = .systemBackground
        
        resultsHeaderLabel.text = "🎯 分割结果"
        resultsHeaderLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        statisticsLabel.text = ""
        statisticsLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statisticsLabel.textColor = .systemGray
        statisticsLabel.numberOfLines = 0
        
        [resultsHeaderLabel, statisticsLabel].forEach {
            resultsHeaderView.addSubview($0)
        }
        
        // 配置CollectionView
        collectionView.backgroundColor = .systemBackground
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
        bottomActionsView.backgroundColor = .systemGray6.withAlphaComponent(0.5)
        bottomActionsView.layer.cornerRadius = 12
        
        exportButton.setTitle("📤 导出结果", for: .normal)
        exportButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        exportButton.backgroundColor = .systemIndigo
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 8
        exportButton.addTarget(self, action: #selector(exportResultsTapped), for: .touchUpInside)
        
        clearButton.setTitle("🗑 清除结果", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        clearButton.backgroundColor = .systemRed.withAlphaComponent(0.8)
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
            collectionView.heightAnchor.constraint(equalToConstant: 400),
            
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
    @objc private func selectVideoTapped() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
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
        // TODO: 实现结果导出功能
        showAlert(title: "功能开发中", message: "结果导出功能正在开发中...")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate
extension VideoSegmentationTestViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let videoURL = urls.first else { return }
        
        // 获取视频访问权限
        _ = videoURL.startAccessingSecurityScopedResource()
        
        currentVideoURL = videoURL
        
        // 获取视频信息
        Task {
            if let videoInfo = await frameExtractor.getVideoInfo(from: videoURL) {
                await MainActor.run {
                    self.currentVideoInfo = videoInfo
                    self.updateVideoInfo(videoInfo)
                    self.updateUIState()
                }
            }
        }
    }
    
    private func updateVideoInfo(_ info: ExtractedVideoInfo) {
        videoInfoLabel.text = """
        📁 \(currentVideoURL?.lastPathComponent ?? "")
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
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 45) / 2 // 2列布局，考虑间距
        let height: CGFloat = 220
        return CGSize(width: width, height: height)
    }
}
