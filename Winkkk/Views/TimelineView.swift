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

// MARK: - Time Resolution Enum
enum TimeResolution {
    case seconds      // 1x-2x: 显示秒
    case halfSeconds  // 2x-4x: 显示0.5秒间隔
    case frames       // 4x+: 显示帧级别刻度
    
    var displayName: String {
        switch self {
        case .seconds: return "秒级"
        case .halfSeconds: return "精细"
        case .frames: return "帧级别"
        }
    }
    
    var intervalInSeconds: Double {
        switch self {
        case .seconds: return 1.0
        case .halfSeconds: return 0.5
        case .frames: return 1.0/30.0  // 默认30fps，实际会根据视频帧率调整
        }
    }
}

// MARK: - Time Formatting Extensions
extension Double {
    
    /// 格式化为时间字符串 (MM:SS 或 HH:MM:SS)
    func formattedTimeString() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// 根据帧率计算帧数
    func frameNumber(at frameRate: Double) -> Int {
        return Int(self * frameRate)
    }
    
    /// 格式化为帧数显示 (如 "15f")
    func formattedFrameString(at frameRate: Double) -> String {
        let frameInSecond = frameNumber(at: frameRate) % Int(frameRate)
        return "\(frameInSecond)f"
    }
}

class TimelineView: UIView {
    
    // MARK: - Properties
    weak var delegate: TimelineViewDelegate?
    
    private var duration: Double = 0
    private var currentProgress: Double = 0
    private var isDragging = false
    private var isZooming = false
    
    // MARK: - Scrolling Container Architecture
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // MARK: - UI Components (now in content view)
    private let trackView = UIView()
    private let progressView = UIView()
    private let thumbView = UIView()
    private let thumbnailContainerView = UIView()
    private let timeScaleView = UIView() // 新增：时间刻度显示
    private let playheadIndicator = UIView() // 🎯 新增：白色竖直指示器
    
    // 缩略图相关
    private var thumbnailImageViews: [UIImageView] = []
    private var currentThumbnailCount = 10 // 当前缩略图数量（可动态调整）
    private var videoURL: URL?
    
    // 手势
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    
    // MARK: - Zoom and Content Size
    private var zoomScale: CGFloat = 1.0
    private let minZoomScale: CGFloat = 0.5  // 显示完整视频
    private let maxZoomScale: CGFloat = 8.0  // 帧级别精度
    private var baseContentWidth: CGFloat = 0  // 基础内容宽度（1x时）
    private var currentContentWidth: CGFloat = 0  // 当前实际内容宽度
    
    // MARK: - Time Resolution
    private var currentTimeResolution: TimeResolution = .seconds
    private var frameRate: Double = 30.0  // 视频帧率
    
    // MARK: - Coordinate System
    private var timeToPixelRatio: Double = 0  // 时间到像素的转换比例
    
    // MARK: - Layout Constraints
    private var playheadIndicatorCenterXConstraint: NSLayoutConstraint?  // 🎯 播放头指示器位置约束
    
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
        
        // 配置滚动容器
        setupScrollContainer()
        
        // 配置内容视图组件
        setupContentComponents()
        
        // 设置约束
        setupConstraints()
    }
    
    private func setupScrollContainer() {
        // 配置滚动视图
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.delegate = self
        addSubview(scrollView)
        
        // 配置内容视图
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)
    }
    
    private func setupContentComponents() {
        // 时间刻度视图
        timeScaleView.backgroundColor = .clear
        contentView.addSubview(timeScaleView)
        
        // 缩略图容器
        thumbnailContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        thumbnailContainerView.layer.cornerRadius = 8
        thumbnailContainerView.layer.masksToBounds = true
        contentView.addSubview(thumbnailContainerView)
        
        // 轨道
        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        trackView.layer.cornerRadius = 2
        contentView.addSubview(trackView)
        
        // 进度条
        progressView.backgroundColor = ThemeManager.buttonPrimary
        progressView.layer.cornerRadius = 2
        contentView.addSubview(progressView)
        
        // 🎯 白色竖直指示器 - Wink风格的播放头指示器
        setupPlayheadIndicator()
        contentView.addSubview(playheadIndicator)
        
        // 拖拽滑块
        setupThumbView()
        contentView.addSubview(thumbView)
    }
    
    // 🎯 设置播放头指示器（白色竖线）
    private func setupPlayheadIndicator() {
        playheadIndicator.backgroundColor = UIColor.white
        playheadIndicator.layer.cornerRadius = 1
        
        // 添加阴影增强可见性
        playheadIndicator.layer.shadowColor = UIColor.black.cgColor
        playheadIndicator.layer.shadowOffset = CGSize(width: 0, height: 1)
        playheadIndicator.layer.shadowRadius = 2
        playheadIndicator.layer.shadowOpacity = 0.5
        playheadIndicator.layer.masksToBounds = false
        
        // 添加微妙的发光效果
        playheadIndicator.layer.borderWidth = 0.5
        playheadIndicator.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
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
        // 设置组件的 translatesAutoresizingMaskIntoConstraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        timeScaleView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainerView.translatesAutoresizingMaskIntoConstraints = false
        trackView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        playheadIndicator.translatesAutoresizingMaskIntoConstraints = false  // 🎯 新增
        
        NSLayoutConstraint.activate([
            // 滚动视图 - 填满整个TimelineView
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 内容视图约束将在updateContentSize中动态设置
            
            // 时间刻度视图 (在内容视图中) - 🎯 增加高度
            timeScaleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            timeScaleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            timeScaleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            timeScaleView.heightAnchor.constraint(equalToConstant: 30),  // 20 → 30px
            
            // 缩略图容器 (在内容视图中) - 🎯 增加高度
            thumbnailContainerView.topAnchor.constraint(equalTo: timeScaleView.bottomAnchor, constant: 6),  // 4 → 6px间距
            thumbnailContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailContainerView.heightAnchor.constraint(equalToConstant: 60),  // 40 → 60px
            
            // 轨道 (在内容视图中)
            trackView.topAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor, constant: 8),
            trackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 4),
            
            // 进度条 (在内容视图中)
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.heightAnchor.constraint(equalTo: trackView.heightAnchor),
            // 宽度约束将动态更新
            
            // 滑块 (在内容视图中)
            thumbView.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 24),
            thumbView.heightAnchor.constraint(equalToConstant: 24),
            // 位置约束将动态更新
            
            // 🎯 播放头指示器 (白色竖线) - 穿过整个时间轴区域
            playheadIndicator.topAnchor.constraint(equalTo: timeScaleView.topAnchor),
            playheadIndicator.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            playheadIndicator.widthAnchor.constraint(equalToConstant: 2)
            // centerX约束将动态更新，跟随播放进度
        ])
        
        // 🎯 Wink风格：播放头指示器固定在TimelineView中心
        playheadIndicatorCenterXConstraint = playheadIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        playheadIndicatorCenterXConstraint?.isActive = true
        
        updateProgressConstraints()
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)
    }
    
    // MARK: - Core Coordinate System Methods
    /// 计算动态内容宽度
    private func calculateContentWidth() -> CGFloat {
        guard baseContentWidth > 0 else {
            baseContentWidth = bounds.width
            return baseContentWidth
        }
        return baseContentWidth * zoomScale
    }
    
    /// 更新内容尺寸
    private func updateContentSize() {
        currentContentWidth = calculateContentWidth()
        contentView.frame = CGRect(x: 0, y: 0, width: currentContentWidth, height: bounds.height)
        scrollView.contentSize = CGSize(width: currentContentWidth, height: bounds.height)
        
        // 更新时间到像素的转换比例
        if duration > 0 {
            timeToPixelRatio = Double(currentContentWidth) / duration
        }
    }
    
    /// 时间坐标转换为像素坐标
    private func timeToCoordinate(_ time: Double) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time * timeToPixelRatio)
    }
    
    /// 像素坐标转换为时间
    private func coordinateToTime(_ x: CGFloat) -> Double {
        guard timeToPixelRatio > 0 else { return 0 }
        return Double(x) / timeToPixelRatio
    }
    
    /// 🎯 Wink风格：获取当前竖线位置对应的截取时间
    func getCurrentCaptureTime() -> Double {
        // 计算竖线在内容视图中的位置
        let centerX = bounds.width / 2  // 竖线固定在TimelineView中心
        let relativeX = centerX + scrollView.contentOffset.x  // 相对于内容的位置
        
        // 转换为时间
        let captureTime = coordinateToTime(relativeX)
        return max(0, min(duration, captureTime))  // 限制在有效范围内
    }
    
    /// 🎯 同步滚动到指定截取时间
    func scrollToCaptureTime(_ time: Double) {
        let targetX = timeToCoordinate(time)
        let centerX = bounds.width / 2
        let scrollOffsetX = max(0, targetX - centerX)
        let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let clampedOffset = min(scrollOffsetX, maxOffset)
        
        scrollView.setContentOffset(CGPoint(x: clampedOffset, y: 0), animated: true)
    }
    
    // MARK: - Public Methods
    func setDuration(_ duration: Double) {
        self.duration = duration
        updateContentSize()
        generateThumbnails()
        updateTimeResolution()
    }
    
    func setVideoURL(_ url: URL) {
        self.videoURL = url
        extractVideoFrameRate(from: url)
        generateThumbnails()
    }
    
    // MARK: - Video Analysis
    private func extractVideoFrameRate(from url: URL) {
        let asset = AVAsset(url: url)
        
        // 异步获取视频帧率
        Task {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                if let videoTrack = tracks.first {
                    let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                    
                    await MainActor.run {
                        self.frameRate = Double(nominalFrameRate)
                        print("📹 检测到视频帧率: \(self.frameRate) fps")
                        
                        // 更新时间精度（如果当前是帧级别显示）
                        if self.currentTimeResolution == .frames {
                            self.updateTimeResolution()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("⚠️ 无法获取视频帧率，使用默认值: \(self.frameRate) fps")
                }
            }
        }
    }
    
    func setProgress(_ progress: Double) {
        guard !isDragging && !isZooming else { return }
        currentProgress = max(0, min(1, progress))
        updateProgressUI()
        centerCurrentProgressIfNeeded()
    }
    
    // MARK: - Time Resolution Management
    private func updateTimeResolution() {
        let previousResolution = currentTimeResolution
        
        // 根据缩放级别自动调整时间精度
        if zoomScale <= 2.0 {
            currentTimeResolution = .seconds
        } else if zoomScale <= 4.0 {
            currentTimeResolution = .halfSeconds
        } else {
            currentTimeResolution = .frames
        }
        
        // 如果精度发生变化，重新生成时间刻度
        if previousResolution != currentTimeResolution {
            print("🎯 时间精度切换: \(previousResolution.displayName) → \(currentTimeResolution.displayName)")
            generateTimeScale()
        }
    }
    
    /// 获取当前精度下的时间间隔
    private func getCurrentTimeInterval() -> Double {
        switch currentTimeResolution {
        case .seconds:
            return 1.0
        case .halfSeconds:
            return 0.5
        case .frames:
            return 1.0 / frameRate  // 使用实际帧率
        }
    }
    
    // MARK: - Time Scale Generation (Placeholder for Task 7)
    private func generateTimeScale() {
        // TODO: 将在任务7中实现完整的时间刻度系统
        print("TimeScale: \(currentTimeResolution.displayName) @ \(zoomScale)x")
    }
    
    private func centerCurrentProgressIfNeeded() {
        // 只在播放时自动跟踪，手动操作时不干扰
        guard !isDragging && !isZooming else { return }
        
        let currentTimeX = timeToCoordinate(duration * currentProgress)
        let visibleWidth = scrollView.bounds.width
        let currentOffsetX = scrollView.contentOffset.x
        
        // 检查播放位置是否需要跟踪
        let shouldTrack = shouldAutoTrackPlayhead(currentTimeX: currentTimeX, 
                                                  visibleWidth: visibleWidth, 
                                                  currentOffsetX: currentOffsetX)
        
        if shouldTrack {
            let targetOffsetX = currentTimeX - visibleWidth / 2
            let maxOffsetX = max(0, currentContentWidth - visibleWidth)
            let clampedOffsetX = max(0, min(maxOffsetX, targetOffsetX))
            
            // 平滑跟踪动画
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.scrollView.setContentOffset(CGPoint(x: clampedOffsetX, y: 0), animated: false)
            }
            
            print("🎯 自动跟踪播放位置: \(currentProgress * duration)s")
        }
    }
    
    /// 判断是否应该自动跟踪播放头
    private func shouldAutoTrackPlayhead(currentTimeX: CGFloat, visibleWidth: CGFloat, currentOffsetX: CGFloat) -> Bool {
        let leftEdge = currentOffsetX
        let rightEdge = currentOffsetX + visibleWidth
        let bufferZone = visibleWidth * 0.1 // 10% 缓冲区
        
        // 如果播放头快要离开可见区域，就开始跟踪
        return currentTimeX <= leftEdge + bufferZone || currentTimeX >= rightEdge - bufferZone
    }
    
    // MARK: - Thumbnail Generation (Density-Based)
    private func generateThumbnails() {
        guard let videoURL = videoURL, duration > 0, currentContentWidth > 0 else { return }
        
        // 基于时间密度计算缩略图数量
        let optimalThumbnailCount = calculateOptimalThumbnailCount()
        generateThumbnailsWithCount(optimalThumbnailCount)
    }
    
    /// 基于内容宽度和缩放级别计算最优缩略图数量
    private func calculateOptimalThumbnailCount() -> Int {
        // 每个缩略图的理想宽度（像素）
        let idealThumbnailWidth: CGFloat = 80
        
        // 基于内容宽度计算缩略图数量
        let basedOnWidth = Int(currentContentWidth / idealThumbnailWidth)
        
        // 基于视频时长计算缩略图数量（避免太密集）
        let maxThumbnailsPerSecond = max(1.0, zoomScale * 0.5)
        let basedOnDuration = Int(duration * maxThumbnailsPerSecond)
        
        // 取两者中较小值，并限制在合理范围内
        let optimalCount = min(basedOnWidth, basedOnDuration)
        let clampedCount = max(5, min(50, optimalCount))
        
        print("🖼️ 缩略图计算: 宽度基准=\(basedOnWidth), 时长基准=\(basedOnDuration), 最终=\(clampedCount)")
        return clampedCount
    }
    
    /// 🎯 计算最优缩略图生成分辨率（解决清晰度问题）
    private func calculateOptimalThumbnailSize(displayWidth: CGFloat, displayHeight: CGFloat) -> CGSize {
        // 获取设备像素密度
        let screenScale = UIScreen.main.scale
        
        // 计算基础目标分辨率（确保足够高清）
        let baseTargetWidth = displayWidth * screenScale
        let baseTargetHeight = displayHeight * screenScale
        
        // 根据缩放级别进一步调整分辨率
        let qualityMultiplier: CGFloat = {
            // 缩放级别越高，用户越可能关注细节，提供更高分辨率
            if zoomScale >= 4.0 {
                return 2.0  // 高精度模式，超高清晰度
            } else if zoomScale >= 2.0 {
                return 1.5  // 中等精度，高清晰度
            } else {
                return 1.2  // 基础模式，确保清晰
            }
        }()
        
        let finalWidth = baseTargetWidth * qualityMultiplier
        let finalHeight = baseTargetHeight * qualityMultiplier
        
        // 限制最大分辨率，避免内存过度消耗
        let maxWidth: CGFloat = 320
        let maxHeight: CGFloat = 240
        
        let clampedWidth = min(finalWidth, maxWidth)
        let clampedHeight = min(finalHeight, maxHeight)
        
        print("📱 缩略图分辨率计算: 设备倍率=\(screenScale)x, 质量倍率=\(qualityMultiplier)x, 最终=\(clampedWidth)x\(clampedHeight)")
        
        return CGSize(width: clampedWidth, height: clampedHeight)
    }
    
    private func generateThumbnailsWithCount(_ count: Int) {
        guard let videoURL = videoURL, duration > 0 else { return }
        
        // 更新当前缩略图数量
        currentThumbnailCount = count
        
        // 🎯 性能优化：清除现有缩略图
        thumbnailImageViews.forEach { imageView in
            // 取消进行中的异步图像加载，避免资源浪费
            imageView.image = nil
            imageView.removeFromSuperview()
        }
        thumbnailImageViews.removeAll()
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // 计算显示尺寸 - 🎯 更新缩略图高度
        let thumbnailWidth = currentContentWidth / CGFloat(count)
        let thumbnailHeight: CGFloat = 60  // 40 → 60px，与约束保持一致
        
        // 🎯 关键修复：动态计算高质量缩略图分辨率
        let targetThumbnailSize = calculateOptimalThumbnailSize(
            displayWidth: thumbnailWidth, 
            displayHeight: thumbnailHeight
        )
        
        // 配置高质量图像生成器
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.maximumSize = targetThumbnailSize
        
        print("🖼️ 缩略图生成配置: 显示尺寸=\(thumbnailWidth)x\(thumbnailHeight), 生成尺寸=\(targetThumbnailSize)")
        
        for i in 0..<count {
            let imageView = UIImageView()
            
            // 🎯 优化显示质量配置
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            imageView.layer.cornerRadius = 2
            imageView.layer.borderWidth = 0.5
            imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            
            // 确保高质量图像渲染
            imageView.layer.contentsGravity = .resizeAspectFill
            imageView.layer.magnificationFilter = .linear  // 高质量缩放
            imageView.layer.minificationFilter = .trilinear  // 高质量缩小
            
            thumbnailContainerView.addSubview(imageView)
            thumbnailImageViews.append(imageView)
            
            // 使用 frame 布局而不是约束（性能更好）
            imageView.frame = CGRect(
                x: CGFloat(i) * thumbnailWidth,
                y: 0,
                width: thumbnailWidth,
                height: 60  // 40 → 60px
            )
            
            // 异步生成缩略图
            let timePercent = Double(i) / Double(max(1, count - 1))
            let time = CMTime(seconds: duration * timePercent, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            
            generateThumbnail(at: time, for: imageView, using: imageGenerator)
        }
        
        print("🖼️ 生成 \(count) 个缩略图, 每个宽度: \(thumbnailWidth), 总宽度: \(currentContentWidth)")
    }
    
    private func generateThumbnail(at time: CMTime, for imageView: UIImageView, using imageGenerator: AVAssetImageGenerator) {
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak imageView] _, cgImage, _, result, error in
            DispatchQueue.main.async {
                guard let imageView = imageView, let cgImage = cgImage else { 
                    if let error = error {
                        print("⚠️ 缩略图生成失败: \(error.localizedDescription)")
                    }
                    return 
                }
                
                // 🎯 使用高质量图像创建
                let highQualityImage = UIImage(cgImage: cgImage)
                imageView.image = highQualityImage
                
                // 确保图像视图以最佳质量显示
                imageView.layer.shouldRasterize = false  // 避免栅格化降低质量
                imageView.layer.allowsEdgeAntialiasing = true  // 边缘抗锯齿
                
                print("✅ 高质量缩略图加载完成: \(cgImage.width)x\(cgImage.height)")
            }
        }
    }
    
    // MARK: - Progress Update
    private func updateProgressUI() {
        updateProgressConstraints()
        
        // 使用新的坐标转换系统更新滑块位置
        let currentTime = duration * currentProgress
        let thumbCenterX = timeToCoordinate(currentTime)
        thumbView.center.x = thumbCenterX
        
        // 添加微妙的缩放动画（仅在非交互状态）
        if !isDragging && !isZooming {
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
        
        // 使用新的坐标系统计算进度条宽度
        let currentTime = duration * currentProgress
        let progressWidth = timeToCoordinate(currentTime)
        progressView.widthAnchor.constraint(equalToConstant: progressWidth).isActive = true
        
        layoutIfNeeded()
    }
    
    // MARK: - Gesture Handling
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        // 将手势位置转换为内容视图坐标
        let locationInScrollView = gesture.location(in: scrollView)
        let locationInContent = CGPoint(
            x: locationInScrollView.x + scrollView.contentOffset.x,
            y: locationInScrollView.y
        )
        
        // 使用新的坐标转换系统
        let currentTime = coordinateToTime(locationInContent.x)
        let progress = duration > 0 ? max(0, min(1, currentTime / duration)) : 0
        
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
    
    // MARK: - Zoom Gesture Handling
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            isZooming = true
            // 暂停播放进度更新，避免在缩放时产生冲突
            delegate?.timelineViewDidBeginSeeking(self)
            
            // 轻微触觉反馈
            HapticFeedbackManager.shared.lightImpact()
            
            print("🔍 开始缩放手势，当前级别: \(zoomScale)x")
            
        case .changed:
            // 记录缩放前的中心点信息
            let gestureLocationInScrollView = gesture.location(in: scrollView)
            let centerOffsetBeforeZoom = scrollView.contentOffset.x + gestureLocationInScrollView.x
            let centerTimeBeforeZoom = coordinateToTime(centerOffsetBeforeZoom)
            
            // 计算新的缩放级别
            let newScale = zoomScale * gesture.scale
            let clampedScale = max(minZoomScale, min(maxZoomScale, newScale))
            
            // 只有当缩放级别确实发生变化时才更新
            if abs(clampedScale - zoomScale) > 0.01 {
                zoomScale = clampedScale
                updateZoomScale()
                
                // 缩放后保持相同的时间点在手势中心
                let newCenterCoordinate = timeToCoordinate(centerTimeBeforeZoom)
                let newScrollOffset = newCenterCoordinate - gestureLocationInScrollView.x
                let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
                let clampedOffset = max(0, min(maxOffset, newScrollOffset))
                
                scrollView.setContentOffset(CGPoint(x: clampedOffset, y: 0), animated: false)
                
                print("📍 缩放到 \(zoomScale)x, 保持时间点 \(centerTimeBeforeZoom)s 在中心")
            }
            
            // 重置手势缩放比例
            gesture.scale = 1.0
            
        case .ended, .cancelled:
            isZooming = false
            delegate?.timelineViewDidEndSeeking(self)
            
            // 完成触觉反馈
            HapticFeedbackManager.shared.mediumImpact()
            
            // 显示缩放级别提示
            showZoomLevelIndicator()
            
            print("✅ 缩放完成，最终级别: \(zoomScale)x")
            
        default:
            break
        }
    }
    
    private func updateZoomScale() {
        // 更新内容尺寸（这是关键的变化！）
        updateContentSize()
        
        // 根据缩放级别重新生成缩略图
        regenerateThumbnailsForZoom()
        
        // 更新时间精度
        updateTimeResolution()
        
        // 重新布局所有组件
        updateThumbnailLayout()
        updateProgressUI()
        
        // 添加缩放视觉反馈
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            // 轻微的视觉反馈，但主要变化是内容宽度
            let scaleTransform = 1.0 + (self.zoomScale - 1.0) * 0.01
            self.thumbnailContainerView.transform = CGAffineTransform(scaleX: scaleTransform, y: 1.0)
        }
    }
    
    private func regenerateThumbnailsForZoom() {
        // 使用新的密度计算方法
        let newThumbnailCount = calculateOptimalThumbnailCount()
        
        // 🎯 关键优化：总是重新生成缩略图以确保最佳质量
        // 因为缩放级别变化会影响最优分辨率
        generateThumbnailsWithCount(newThumbnailCount)
        
        print("🔍 缩放级别: \(zoomScale)x, 缩略图数量: \(newThumbnailCount), 重新生成高质量缩略图")
    }
    
    private func showZoomLevelIndicator() {
        // 创建缩放级别指示器
        let indicator = UILabel()
        let resolutionText = currentTimeResolution.displayName
        indicator.text = String(format: "%.1fx - %@", zoomScale, resolutionText)
        indicator.textColor = .white
        indicator.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        indicator.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        indicator.textAlignment = .center
        indicator.layer.cornerRadius = 12
        indicator.layer.masksToBounds = true
        
        // 根据文字内容动态调整宽度
        let textSize = indicator.sizeThatFits(CGSize(width: 200, height: 24))
        indicator.frame = CGRect(x: 0, y: 0, width: textSize.width + 20, height: 24)
        indicator.center = CGPoint(x: bounds.midX, y: bounds.midY - 30)
        
        addSubview(indicator)
        
        // 动画显示和隐藏
        indicator.alpha = 0
        indicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            indicator.alpha = 1
            indicator.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, options: .curveEaseInOut) {
                indicator.alpha = 0
                indicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            } completion: { _ in
                indicator.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 初始化基础宽度（如果还未设置）
        if baseContentWidth == 0 && bounds.width > 0 {
            baseContentWidth = bounds.width
            print("📐 初始化基础宽度: \(baseContentWidth)")
        }
        
        // 更新内容尺寸
        if bounds.width > 0 {
            updateContentSize()
        }
        
        // 重新生成缩略图如果视图大小发生变化
        if !thumbnailImageViews.isEmpty && bounds.width > 0 {
            updateThumbnailLayout()
        }
        
        updateProgressUI()
    }
    
    private func updateThumbnailLayout() {
        guard currentThumbnailCount > 0, currentContentWidth > 0 else { return }
        
        // 使用动态内容宽度而不是视图宽度
        let thumbnailWidth = currentContentWidth / CGFloat(currentThumbnailCount)
        
        for (index, imageView) in thumbnailImageViews.enumerated() {
            imageView.frame = CGRect(
                x: CGFloat(index) * thumbnailWidth,
                y: 0,
                width: thumbnailWidth,
                height: 60  // 40 → 60px
            )
        }
        
        print("🖼️ 更新缩略图布局: \(currentThumbnailCount)个, 每个宽度: \(thumbnailWidth), 总宽度: \(currentContentWidth)")
    }
    
    // MARK: - Touch Events
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let locationInScrollView = touch.location(in: scrollView)
        let locationInContent = CGPoint(
            x: locationInScrollView.x + scrollView.contentOffset.x,
            y: locationInScrollView.y
        )
        
        // 如果点击在轨道区域，直接跳转到该位置
        let trackFrame = CGRect(
            x: 0,
            y: trackView.frame.minY,
            width: currentContentWidth,
            height: trackView.frame.height
        )
        
        if trackFrame.contains(locationInContent) {
            let currentTime = coordinateToTime(locationInContent.x)
            let progress = duration > 0 ? max(0, min(1, currentTime / duration)) : 0
            
            currentProgress = progress
            updateProgressUI()
            delegate?.timelineView(self, didSeekToProgress: progress)
            
            // 触觉反馈
            HapticFeedbackManager.shared.sliderValueChanged()
        }
    }
}

// MARK: - UIScrollViewDelegate
extension TimelineView: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 滚动时更新进度条和滑块位置
        updateProgressUI()
        
        // 🎯 Wink风格：滚动时实时通知截取时间变化（性能优化：减少频繁回调）
        if !isDragging && !isZooming {  // 仅在非交互状态时回调
            let captureTime = getCurrentCaptureTime()
            let progress = duration > 0 ? captureTime / duration : 0
            delegate?.timelineView(self, didSeekToProgress: progress)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 用户开始手动滚动时，暂停自动跟踪
        print("👆 用户开始手动滚动，暂停自动跟踪")
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 滚动结束时可以进行性能优化，如懒加载缩略图
        updateVisibleThumbnails()
        
        // 🎯 滚动结束时更新截取时间
        let captureTime = getCurrentCaptureTime()
        let progress = duration > 0 ? captureTime / duration : 0
        delegate?.timelineView(self, didSeekToProgress: progress)
        
        print("📍 滚动减速结束，可恢复自动跟踪")
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateVisibleThumbnails()
            print("📍 滚动拖拽结束，可恢复自动跟踪")
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        // 自动滚动动画结束
        print("✅ 自动跟踪滚动完成")
    }
    
    // MARK: - Visible Thumbnails Optimization (Placeholder for Task 10)
    private func updateVisibleThumbnails() {
        // TODO: 将在任务10中实现可见区域优化
        let visibleRect = CGRect(
            x: scrollView.contentOffset.x,
            y: 0,
            width: scrollView.bounds.width,
            height: scrollView.bounds.height
        )
        
        let startTime = coordinateToTime(visibleRect.minX)
        let endTime = coordinateToTime(visibleRect.maxX)
        
        print("👀 可见时间范围: \(startTime.formattedTimeString()) - \(endTime.formattedTimeString())")
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TimelineView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许缩放手势和拖拽手势同时进行
        if (gestureRecognizer == pinchGesture && otherGestureRecognizer == panGesture) ||
           (gestureRecognizer == panGesture && otherGestureRecognizer == pinchGesture) {
            return true
        }
        return false
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            let location = gestureRecognizer.location(in: self)
            // 🎯 Wink风格：拖拽优先于滚动，可以在整个时间轴区域进行
            // 但滑块区域优先级更高（精确控制播放进度）
            let thumbFrame = thumbView.frame.insetBy(dx: -20, dy: -20)
            if thumbFrame.contains(location) {
                return true  // 滑块区域：播放进度控制
            }
            // 其他区域：内容滚动（Wink风格截取定位）
            return false  // 让scrollView处理滚动
        } else if gestureRecognizer == pinchGesture {
            // 🎯 缩放手势在整个时间轴区域都可以进行
            return true
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
