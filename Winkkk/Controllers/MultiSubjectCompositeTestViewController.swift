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
        selectVideoButton.backgroundColor = .systemBlue
        selectVideoButton.setTitleColor(.white, for: .normal)
        selectVideoButton.layer.cornerRadius = 8
        selectVideoButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
        // 场景类型选择
        sceneTypeSegmentedControl.removeAllSegments()
        sceneTypeSegmentedControl.insertSegment(withTitle: "物体变化", at: 0, animated: false)
        sceneTypeSegmentedControl.insertSegment(withTitle: "人物动作", at: 1, animated: false)
        sceneTypeSegmentedControl.selectedSegmentIndex = 0
        
        // 帧数滑块
        frameCountSlider.minimumValue = 3
        frameCountSlider.maximumValue = 9
        frameCountSlider.value = 5
        frameCountSlider.isContinuous = true
        updateFrameCountLabel()
        
        // 处理按钮
        processButton.setTitle("🚀 开始处理", for: .normal)
        processButton.backgroundColor = .systemGreen
        processButton.setTitleColor(.white, for: .normal)
        processButton.layer.cornerRadius = 8
        processButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
        // 进度条
        progressView.isHidden = true
        progressView.progressTintColor = .systemBlue
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
        resultImageView.backgroundColor = .systemGray6
        resultImageView.layer.cornerRadius = 8
        resultImageView.clipsToBounds = true
        
        saveButton.setTitle("💾 保存到相册", for: .normal)
        saveButton.backgroundColor = .systemOrange
        saveButton.setTitleColor(.white, for: .normal)
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
                    self.progressView.setProgress(0.6, animated: true)
                    self.statusLabel.text = "关键帧提取完成，正在合成..."
                    
                    // 开始合成
                    self.performComposite(frames: frames, sceneType: sceneType)
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
    
    private func performComposite(frames: [UIImage], sceneType: SceneType) {
        Task {
            // 使用简单的合成算法
            let result = await createMultiSubjectComposite(frames: frames, sceneType: sceneType)
            
            DispatchQueue.main.async {
                if let result = result {
                    self.compositeResult = result
                    self.resultImageView.image = result
                    self.progressView.setProgress(1.0, animated: true)
                    self.statusLabel.text = "✅ 合成完成！"
                    
                    // 显示结果信息
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
