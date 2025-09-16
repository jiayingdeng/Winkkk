//
//  TimelineView.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  时间轴自定义控件 - 精确帧定位和拖拽手势
//

import UIKit
import AVFoundation

protocol TimelineViewDelegate: AnyObject {
    func timelineView(_ timelineView: TimelineView, didSeekToProgress progress: Double)
    func timelineViewDidBeginSeeking(_ timelineView: TimelineView)
    func timelineViewDidEndSeeking(_ timelineView: TimelineView)
}

class TimelineView: UIView {
    
    // MARK: - Properties
    weak var delegate: TimelineViewDelegate?
    
    private var duration: Double = 0
    private var currentProgress: Double = 0
    private var isDragging = false
    
    // MARK: - UI Components
    private let trackView = UIView()
    private let progressView = UIView()
    private let thumbView = UIView()
    private let thumbnailContainerView = UIView()
    
    // 缩略图相关
    private var thumbnailImageViews: [UIImageView] = []
    private let thumbnailCount = 10 // 显示10个缩略图
    private var videoURL: URL?
    
    // 手势
    private var panGesture: UIPanGestureRecognizer!
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // 缩略图容器
        thumbnailContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        thumbnailContainerView.layer.cornerRadius = 8
        thumbnailContainerView.layer.masksToBounds = true
        addSubview(thumbnailContainerView)
        
        // 轨道
        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        trackView.layer.cornerRadius = 2
        addSubview(trackView)
        
        // 进度条
        progressView.backgroundColor = ThemeManager.buttonPrimary
        progressView.layer.cornerRadius = 2
        addSubview(progressView)
        
        // 拖拽滑块
        setupThumbView()
        addSubview(thumbView)
        
        setupConstraints()
    }
    
    private func setupThumbView() {
        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = 12
        thumbView.layer.borderWidth = 2
        thumbView.layer.borderColor = ThemeManager.buttonPrimary.cgColor
        
        // 添加阴影
        thumbView.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
        thumbView.layer.shadowRadius = 4
        thumbView.layer.shadowOpacity = 1.0
        thumbView.layer.masksToBounds = false
        
        // 内部指示线
        let indicatorLine = UIView()
        indicatorLine.backgroundColor = ThemeManager.buttonPrimary
        indicatorLine.layer.cornerRadius = 1
        thumbView.addSubview(indicatorLine)
        
        indicatorLine.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicatorLine.centerXAnchor.constraint(equalTo: thumbView.centerXAnchor),
            indicatorLine.centerYAnchor.constraint(equalTo: thumbView.centerYAnchor),
            indicatorLine.widthAnchor.constraint(equalToConstant: 2),
            indicatorLine.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupConstraints() {
        thumbnailContainerView.translatesAutoresizingMaskIntoConstraints = false
        trackView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 缩略图容器
            thumbnailContainerView.topAnchor.constraint(equalTo: topAnchor),
            thumbnailContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            thumbnailContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            thumbnailContainerView.heightAnchor.constraint(equalToConstant: 40),
            
            // 轨道
            trackView.topAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor, constant: 8),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 4),
            
            // 进度条
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.heightAnchor.constraint(equalTo: trackView.heightAnchor),
            // 宽度约束将动态更新
            
            // 滑块
            thumbView.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 24),
            thumbView.heightAnchor.constraint(equalToConstant: 24)
            // 位置约束将动态更新
        ])
        
        updateProgressConstraints()
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }
    
    // MARK: - Public Methods
    func setDuration(_ duration: Double) {
        self.duration = duration
        generateThumbnails()
    }
    
    func setVideoURL(_ url: URL) {
        self.videoURL = url
        generateThumbnails()
    }
    
    func setProgress(_ progress: Double) {
        guard !isDragging else { return }
        currentProgress = max(0, min(1, progress))
        updateProgressUI()
    }
    
    // MARK: - Thumbnail Generation
    private func generateThumbnails() {
        guard let videoURL = videoURL, duration > 0 else { return }
        
        // 清除现有缩略图
        thumbnailImageViews.forEach { $0.removeFromSuperview() }
        thumbnailImageViews.removeAll()
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.maximumSize = CGSize(width: 60, height: 40)
        
        let thumbnailWidth = bounds.width / CGFloat(thumbnailCount)
        
        for i in 0..<thumbnailCount {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            
            thumbnailContainerView.addSubview(imageView)
            thumbnailImageViews.append(imageView)
            
            // 设置约束
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: thumbnailContainerView.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: thumbnailContainerView.leadingAnchor, constant: CGFloat(i) * thumbnailWidth),
                imageView.widthAnchor.constraint(equalToConstant: thumbnailWidth)
            ])
            
            // 异步生成缩略图
            let timePercent = Double(i) / Double(thumbnailCount - 1)
            let time = CMTime(seconds: duration * timePercent, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            
            generateThumbnail(at: time, for: imageView, using: imageGenerator)
        }
    }
    
    private func generateThumbnail(at time: CMTime, for imageView: UIImageView, using imageGenerator: AVAssetImageGenerator) {
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak imageView] _, cgImage, _, result, error in
            DispatchQueue.main.async {
                guard let imageView = imageView, let cgImage = cgImage else { return }
                imageView.image = UIImage(cgImage: cgImage)
            }
        }
    }
    
    // MARK: - Progress Update
    private func updateProgressUI() {
        updateProgressConstraints()
        
        // 更新滑块位置
        let thumbCenterX = bounds.width * currentProgress
        thumbView.center.x = thumbCenterX
        
        // 添加微妙的缩放动画
        if !isDragging {
            UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                self.thumbView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.thumbView.transform = .identity
                }
            }
        }
    }
    
    private func updateProgressConstraints() {
        // 移除旧的宽度约束
        progressView.constraints.forEach { constraint in
            if constraint.firstAttribute == .width {
                progressView.removeConstraint(constraint)
            }
        }
        
        // 添加新的宽度约束
        let progressWidth = bounds.width * currentProgress
        progressView.widthAnchor.constraint(equalToConstant: progressWidth).isActive = true
        
        layoutIfNeeded()
    }
    
    // MARK: - Gesture Handling
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let progress = max(0, min(1, location.x / bounds.width))
        
        switch gesture.state {
        case .began:
            isDragging = true
            delegate?.timelineViewDidBeginSeeking(self)
            
            // 放大滑块
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.thumbView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }
            
            // 触觉反馈
            HapticFeedbackManager.shared.sliderValueChanged()
            
        case .changed:
            currentProgress = progress
            updateProgressUI()
            delegate?.timelineView(self, didSeekToProgress: progress)
            
        case .ended, .cancelled:
            isDragging = false
            delegate?.timelineViewDidEndSeeking(self)
            
            // 恢复滑块大小
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.thumbView.transform = .identity
            }
            
            // 轻微触觉反馈
            HapticFeedbackManager.shared.sliderValueChanged()
            
        default:
            break
        }
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 重新生成缩略图如果视图大小发生变化
        if !thumbnailImageViews.isEmpty && bounds.width > 0 {
            updateThumbnailLayout()
        }
        
        updateProgressUI()
    }
    
    private func updateThumbnailLayout() {
        let thumbnailWidth = bounds.width / CGFloat(thumbnailCount)
        
        for (index, imageView) in thumbnailImageViews.enumerated() {
            imageView.frame = CGRect(
                x: CGFloat(index) * thumbnailWidth,
                y: 0,
                width: thumbnailWidth,
                height: 40
            )
        }
    }
    
    // MARK: - Touch Events
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 如果点击在轨道区域，直接跳转到该位置
        if trackView.frame.contains(location) {
            let progress = max(0, min(1, location.x / bounds.width))
            currentProgress = progress
            updateProgressUI()
            delegate?.timelineView(self, didSeekToProgress: progress)
            
            // 触觉反馈
            HapticFeedbackManager.shared.sliderValueChanged()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TimelineView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            let location = gestureRecognizer.location(in: self)
            // 只在滑块附近或轨道上才允许拖拽
            let thumbFrame = thumbView.frame.insetBy(dx: -20, dy: -20)
            return thumbFrame.contains(location) || trackView.frame.contains(location)
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

// MARK: - Custom Properties
extension TimelineView {
    
    /// 获取当前时间（秒）
    var currentTime: Double {
        return duration * currentProgress
    }
    
    /// 获取当前时间的格式化字符串
    var currentTimeString: String {
        return String.formatTime(currentTime)
    }
    
    /// 设置当前时间（秒）
    func setCurrentTime(_ time: Double) {
        guard duration > 0 else { return }
        let progress = time / duration
        setProgress(progress)
    }
    
    /// 跳转到指定百分比位置
    func seekToPercent(_ percent: Double) {
        let clampedPercent = max(0, min(1, percent))
        currentProgress = clampedPercent
        updateProgressUI()
        delegate?.timelineView(self, didSeekToProgress: clampedPercent)
    }
    
    /// 向前跳转指定秒数
    func seekForward(by seconds: Double) {
        let newTime = currentTime + seconds
        setCurrentTime(min(newTime, duration))
    }
    
    /// 向后跳转指定秒数
    func seekBackward(by seconds: Double) {
        let newTime = currentTime - seconds
        setCurrentTime(max(newTime, 0))
    }
}

// MARK: - Accessibility
extension TimelineView {
    
    override func accessibilityIncrement() {
        seekForward(by: 5) // 向前5秒
    }
    
    override func accessibilityDecrement() {
        seekBackward(by: 5) // 向后5秒
    }
    
    override var accessibilityLabel: String? {
        get {
            return "视频时间轴"
        }
        set { }
    }
    
    override var accessibilityValue: String? {
        get {
            let currentTimeStr = String.formatTime(currentTime)
            let durationStr = String.formatTime(duration)
            return "\(currentTimeStr) / \(durationStr)"
        }
        set { }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            return .adjustable
        }
        set { }
    }
}
