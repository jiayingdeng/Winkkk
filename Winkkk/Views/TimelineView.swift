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
    
    // 🎯 新增：播放状态同步相关回调
    func timelineView(_ timelineView: TimelineView, didUpdateProgressDuringPlayback progress: Double)
    func timelineViewDidRequestPlay(_ timelineView: TimelineView)
    func timelineViewDidRequestPause(_ timelineView: TimelineView)
}

// MARK: - TimelineViewDelegate Default Implementation
extension TimelineViewDelegate {
    
    /// 🎯 为新协议方法提供默认实现，确保向后兼容
    func timelineView(_ timelineView: TimelineView, didUpdateProgressDuringPlayback progress: Double) {
        // 默认行为：将播放进度更新转发给普通的跳转方法
        // 子类可以重写此方法来实现播放时的特殊处理
        self.timelineView(timelineView, didSeekToProgress: progress)
    }
    
    func timelineViewDidRequestPlay(_ timelineView: TimelineView) {
        // 默认实现：空操作
        // 子类可以重写此方法来处理播放请求
    }
    
    func timelineViewDidRequestPause(_ timelineView: TimelineView) {
        // 默认实现：空操作  
        // 子类可以重写此方法来处理暂停请求
    }
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
    
    // 🎯 新增：播放状态跟踪
    private var isPlaying = false
    private var isPlaybackProgressUpdate = false  // 标记是否为播放中的进度更新
    
    // 🆕 Live Photo模式支持
    private var isLivePhotoMode = false
    
    // MARK: - Scrolling Container Architecture
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 🎯 提供scrollView访问接口 (供VideoPlayerViewController使用)
    var timelineScrollView: UIScrollView {
        return scrollView
    }
    
    // 🎯 提供playheadIndicator访问接口 (供VideoPlayerViewController约束控制)
    var playheadIndicatorView: UIView {
        return playheadIndicator
    }
    
    // MARK: - UI Components (now in content view)
    private let trackView = UIView()
    private let progressView = UIView()
    private let thumbView = UIView()
    private let thumbnailContainerView = UIView()
    private let timeScaleView = UIView() // 新增：时间刻度显示
    private let playheadIndicator = UIView() // 🎯 新增：白色竖直指示器
    
    // 🆕 Live Photo模式组件
    private let livePhotoRangeView = UIView()      // 3秒范围显示
    
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
    
    // MARK: - Content Padding (for complete scroll range)
    // 🎯 内部逻辑：padding基于TimelineView自身宽度，保持内部一致性
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }  // 用于centerX计算
    private var leftPadding: CGFloat { bounds.width / 2 }  // 左侧填充，让视频开头能到达中心
    private var rightPadding: CGFloat { bounds.width / 2 } // 右侧填充，让视频结尾能到达中心
    
    // MARK: - Time Resolution
    private var currentTimeResolution: TimeResolution = .seconds
    private var frameRate: Double = 30.0  // 视频帧率
    
    // MARK: - Coordinate System
    private var timeToPixelRatio: Double = 0  // 时间到像素的转换比例
    
    // MARK: - Layout Constraints
    // 🎯 播放头指示器约束将由VideoPlayerViewController管理
    
    // 🔑 动态约束引用 - 用于实时更新缩略图和时间刻度的位置
    private var thumbnailContainerLeadingConstraint: NSLayoutConstraint!
    private var thumbnailContainerWidthConstraint: NSLayoutConstraint!
    private var timeScaleLeadingConstraint: NSLayoutConstraint!
    private var timeScaleWidthConstraint: NSLayoutConstraint!
    
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
        trackView.backgroundColor = .clear  // 🎯 透明但保留点击功能
        trackView.layer.cornerRadius = 2
        contentView.addSubview(trackView)
        
        // 🎯 轨道设为透明 - 视觉上不可见但保留点击跳转功能
        
        // 🎯 Wink编辑器模式：移除传统播放器组件
        // ❌ 不再添加进度条和滑块
        // progressView - 传统播放进度显示
        // thumbView - 传统滑块控制
        
        // 🎯 白色竖直指示器 - Wink风格的唯一定位器
        setupPlayheadIndicator()
        contentView.addSubview(playheadIndicator)
        
        // 🎯 确保白色竖线始终在最顶层，不被缩略图遮挡
        playheadIndicator.layer.zPosition = 1000
        
        // 🆕 Live Photo模式组件
        setupLivePhotoComponents()
        contentView.addSubview(livePhotoRangeView)
        
        // 🎯 设置传统组件但隐藏（保持代码兼容性）
        setupThumbView()
        progressView.backgroundColor = ThemeManager.buttonPrimary
        progressView.layer.cornerRadius = 2
        contentView.addSubview(progressView)
        contentView.addSubview(thumbView)
        
        // 🎯 隐藏传统播放器组件
        thumbView.isHidden = true
        progressView.isHidden = true
    }
    
    // 🎯 设置播放头指示器（白色竖线）- 增强截图瞄准器地位
    private func setupPlayheadIndicator() {
        playheadIndicator.backgroundColor = UIColor.white
        playheadIndicator.layer.cornerRadius = 1.5  // 稍微增加圆角
        
        // 🎯 增强阴影效果，突出截图瞄准器地位
        playheadIndicator.layer.shadowColor = UIColor.black.cgColor
        playheadIndicator.layer.shadowOffset = CGSize(width: 0, height: 2)
        playheadIndicator.layer.shadowRadius = 4  // 增大阴影半径
        playheadIndicator.layer.shadowOpacity = 0.8  // 增强阴影透明度
        playheadIndicator.layer.masksToBounds = false
        
        // 🎯 增强发光效果 - Wink级别视觉反馈
        playheadIndicator.layer.borderWidth = 1.0  // 增加边框宽度
        playheadIndicator.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        
        // 🎯 添加微妙的脉冲动画，增强用户注意力
        addPulseAnimation()
    }
    
    // 🎯 添加脉冲动画突出截图瞄准器
    private func addPulseAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.05
        pulseAnimation.duration = 1.5
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        playheadIndicator.layer.add(pulseAnimation, forKey: "pulse")
    }
    
    // 🆕 设置Live Photo模式组件
    private func setupLivePhotoComponents() {
        // 设置3秒范围指示器
        livePhotoRangeView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
        livePhotoRangeView.layer.cornerRadius = 4
        livePhotoRangeView.layer.borderWidth = 1
        livePhotoRangeView.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
        livePhotoRangeView.isHidden = true  // 默认隐藏
        
        // 添加文字标签
        let label = UILabel()
        label.text = "3s"
        label.textColor = UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0)  // 🎯 深紫色 #6633AA
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        livePhotoRangeView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: livePhotoRangeView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: livePhotoRangeView.centerYAnchor)
        ])
    }
    
    // 🆕 公开方法：设置Live Photo模式
    func setLivePhotoMode(_ enabled: Bool) {
        isLivePhotoMode = enabled
        livePhotoRangeView.isHidden = !enabled
        
        if enabled {
            updateLivePhotoRangePosition()
        }
    }
    
    // 🎯 修复：更新Live Photo范围位置（智能居中，基于白色竖线屏幕位置）
    private func updateLivePhotoRangePosition() {
        guard isLivePhotoMode, duration > 0, timeToPixelRatio > 0 else { return }
        
        // 🎯 正确获取白色竖线相对于TimelineView的位置
        // 白色竖线被约束到屏幕中心，需要计算屏幕中心相对于当前滚动视图内容的位置
        guard let parentView = superview else { return }
        
        // 🎯 正确计算白色竖线在TimelineView中的位置
        // 白色竖线应该在TimelineView的可见区域中心
        let timelineVisibleWidth = scrollView.bounds.width
        let playheadScreenX = scrollView.contentOffset.x + timelineVisibleWidth / 2
        
        // 🎯 获取当前白色竖线对应的时间
        let currentTime = getCurrentCaptureTime()
        
        // 🎯 计算Live Photo的时间范围（与ScreenshotEngine逻辑一致）
        let keyPhotoOffset: Double = 1.5
        let livePhotoDuration: Double = 3.0
        
        let idealStartTime = currentTime - keyPhotoOffset
        let idealEndTime = idealStartTime + livePhotoDuration
        
        // 🎯 实际可用的时间范围（考虑视频边界）
        let actualStartTime = max(0, idealStartTime)
        let actualEndTime = min(duration, idealEndTime)
        let actualDuration = actualEndTime - actualStartTime
        
        // 🎯 计算3秒范围的显示宽度
        let idealRangeWidth = CGFloat(livePhotoDuration * timeToPixelRatio)
        let actualRangeWidth = CGFloat(actualDuration * timeToPixelRatio)
        
        // 🎯 智能定位：粉色轴始终以白色竖线为中心，但受视频边界限制
        var rangeStartX: CGFloat
        
        // 🎯 首先尝试以白色竖线为中心
        let centerBasedStartX = playheadScreenX - idealRangeWidth / 2
        
        // 🔍 详细调试信息
        print("🔍 [LivePhoto居中调试]")
        print("   playheadScreenX: \(playheadScreenX)")
        print("   idealRangeWidth: \(idealRangeWidth)")
        print("   centerBasedStartX: \(centerBasedStartX)")
        print("   leftPadding: \(leftPadding)")
        print("   getActualVideoWidth(): \(getActualVideoWidth())")
        print("   右边界: \(leftPadding + getActualVideoWidth())")
        
        if centerBasedStartX < leftPadding {
            // 🎯 如果居中会导致粉色轴超出左边界，则左对齐边界
            rangeStartX = leftPadding
            print("   ❌ 超出左边界，使用左对齐: \(rangeStartX)")
        } else if centerBasedStartX + idealRangeWidth > leftPadding + getActualVideoWidth() {
            // 🎯 如果居中会导致粉色轴超出右边界，则右对齐边界
            rangeStartX = leftPadding + getActualVideoWidth() - idealRangeWidth
            print("   ❌ 超出右边界，使用右对齐: \(rangeStartX)")
        } else {
            // 🎯 可以完美居中
            rangeStartX = centerBasedStartX
            print("   ✅ 完美居中: \(rangeStartX)")
        }
        
        // 🎯 边界检查已在上面处理，这里使用实际范围宽度
        // 如果实际范围宽度与理想宽度不同，需要重新调整位置
        if actualRangeWidth != idealRangeWidth {
            // 重新计算基于实际宽度的居中位置
            let actualCenterBasedStartX = playheadScreenX - actualRangeWidth / 2
            rangeStartX = max(leftPadding, actualCenterBasedStartX)
            rangeStartX = min(leftPadding + getActualVideoWidth() - actualRangeWidth, rangeStartX)
        }
        
        // 🎯 如果没有有效的截图范围，则隐藏指示器
        if actualDuration < 0.1 || actualRangeWidth <= 0 {
            livePhotoRangeView.isHidden = true
            return
        } else {
            livePhotoRangeView.isHidden = false
        }
        
        livePhotoRangeView.frame = CGRect(
            x: rangeStartX,
            y: timeScaleView.frame.minY,
            width: actualRangeWidth,
            height: timeScaleView.frame.height
        )
        
        // 🎯 动态更新标签显示实际时长
        updateLivePhotoRangeLabel(actualDuration)
        
        print("🎥 Live Photo智能居中: currentTime=\(String(format: "%.2f", currentTime)), playheadX=\(playheadScreenX), centerBasedStartX=\(centerBasedStartX), rangeStartX=\(rangeStartX), idealWidth=\(idealRangeWidth), actualWidth=\(actualRangeWidth), actualDuration=\(String(format: "%.2f", actualDuration))")
    }
    
    /// 🎯 更新Live Photo范围标签显示实际时长
    private func updateLivePhotoRangeLabel(_ duration: Double) {
        // 查找标签视图
        if let label = livePhotoRangeView.subviews.first(where: { $0 is UILabel }) as? UILabel {
            // 根据时长显示不同格式
            if duration >= 3.0 {
                label.text = "3.0s"  // 完整时长
            } else if duration >= 1.0 {
                label.text = String(format: "%.1fs", duration)  // 保留一位小数
            } else {
                label.text = String(format: "%.2fs", duration)  // 保留两位小数
            }
        }
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
        
        // 🔑 创建动态约束引用
        thumbnailContainerLeadingConstraint = thumbnailContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0)
        thumbnailContainerWidthConstraint = thumbnailContainerView.widthAnchor.constraint(equalToConstant: 0)
        timeScaleLeadingConstraint = timeScaleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0)
        timeScaleWidthConstraint = timeScaleView.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            // 滚动视图 - 填满整个TimelineView
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 内容视图约束将在updateContentSize中动态设置
            
            // 🎯 关键修复：缩略图容器与视频内容区域对齐
            thumbnailContainerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailContainerLeadingConstraint, // 🔑 动态约束
            thumbnailContainerWidthConstraint, // 🔑 动态约束
            thumbnailContainerView.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.6),  // 60%高度
            
            // 🎯 关键修复：时间刻度与视频内容区域对齐
            timeScaleView.topAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor),
            timeScaleLeadingConstraint, // 🔑 动态约束
            timeScaleWidthConstraint, // 🔑 动态约束
            timeScaleView.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.2),  // 20%高度
            
            // 🎯 优化布局：播放轨道紧贴时间刻度（占20%高度）
            trackView.topAnchor.constraint(equalTo: timeScaleView.bottomAnchor),
            trackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            trackView.widthAnchor.constraint(equalTo: self.widthAnchor),  // 🎯 与TimelineView同宽
            trackView.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.2),  // 20%高度
            
            // 进度条 (在内容视图中) - 🎯 隐藏但保持兼容性
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.heightAnchor.constraint(equalTo: trackView.heightAnchor),
            // 宽度约束将动态更新
            
            // 滑块 (在内容视图中) - 🎯 隐藏但保持兼容性
            thumbView.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 24),
            thumbView.heightAnchor.constraint(equalToConstant: 24),
            // 位置约束将动态更新
            
            // 🎯 播放头指示器 (白色竖线) - 从缩略图上方延伸到缩略图底部
            playheadIndicator.topAnchor.constraint(equalTo: thumbnailContainerView.topAnchor, constant: -8),
            playheadIndicator.bottomAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor),
            playheadIndicator.widthAnchor.constraint(equalToConstant: 2)
            // centerX约束将动态更新，跟随播放进度
        ])
        
        // 🎯 注意：playheadIndicator的centerX约束现在由VideoPlayerViewController管理
        // 这确保了它能精确对齐到屏幕中心而不是TimelineView中心
        
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
    /// 计算动态内容宽度（包含左右padding）
    private func calculateContentWidth() -> CGFloat {
        guard baseContentWidth > 0 else {
            baseContentWidth = bounds.width  // 🎯 基于TimelineView宽度，保持内部一致性
            return baseContentWidth + leftPadding + rightPadding
        }
        // 🎯 总内容宽度 = 左padding + 实际视频内容 + 右padding
        let actualVideoWidth = baseContentWidth * zoomScale
        return leftPadding + actualVideoWidth + rightPadding
    }
    
    /// 获取实际视频内容宽度（不包含padding）
    private func getActualVideoWidth() -> CGFloat {
        guard baseContentWidth > 0 else { return bounds.width }  // 🎯 fallback使用TimelineView宽度
        return baseContentWidth * zoomScale
    }
    
    /// 更新内容尺寸
    private func updateContentSize() {
        currentContentWidth = calculateContentWidth()
        contentView.frame = CGRect(x: 0, y: 0, width: currentContentWidth, height: bounds.height)
        scrollView.contentSize = CGSize(width: currentContentWidth, height: bounds.height)
        
        // 🎯 更新时间到像素的转换比例（基于实际视频内容宽度，不包含padding）
        if duration > 0 {
            let actualVideoWidth = getActualVideoWidth()
            timeToPixelRatio = Double(actualVideoWidth) / duration
            // 内容更新调试日志已优化
        }
        
        // 🔑 关键修复：动态更新缩略图和时间刻度的约束，使其与视频内容区域对齐
        updateVideoContentAreaConstraints()
        
        // 🎯 修复问题3：缩放时重新生成缩略图，确保与视频帧精确对应
        generateThumbnails()
    }
    
    /// 🔑 核心修复方法：更新视频内容区域约束，确保缩略图和时间刻度对齐
    private func updateVideoContentAreaConstraints() {
        guard thumbnailContainerLeadingConstraint != nil,
              thumbnailContainerWidthConstraint != nil,
              timeScaleLeadingConstraint != nil,
              timeScaleWidthConstraint != nil else {
            return // 约束尚未初始化
        }
        
        // 🎯 关键：视频内容区域 = leftPadding起始 + 实际视频宽度
        let videoContentStartX = leftPadding
        let videoContentWidth = getActualVideoWidth()
        
        // 🔑 更新缩略图容器约束：与视频内容区域完全对齐
        thumbnailContainerLeadingConstraint.constant = videoContentStartX
        thumbnailContainerWidthConstraint.constant = videoContentWidth
        
        // 🔑 更新时间刻度约束：与视频内容区域完全对齐
        timeScaleLeadingConstraint.constant = videoContentStartX
        timeScaleWidthConstraint.constant = videoContentWidth
        
        print("🔧 视频内容区域约束更新: startX=\(videoContentStartX), width=\(videoContentWidth), leftPadding=\(leftPadding)")
    }
    
    /// 时间坐标转换为像素坐标（考虑leftPadding偏移）
    private func timeToCoordinate(_ time: Double) -> CGFloat {
        guard duration > 0 else { return leftPadding }
        // 时间 → 视频内容区域的像素位置 → 加上leftPadding得到最终位置
        let videoContentX = CGFloat(time * timeToPixelRatio)
        return leftPadding + videoContentX
    }
    
    /// 🔑 新增：时间坐标转换为视频内容区域内的相对坐标（用于时间刻度绘制）
    private func timeToVideoContentCoordinate(_ time: Double) -> CGFloat {
        guard duration > 0, timeToPixelRatio > 0 else { return 0 }
        // 时间 → 视频内容区域内的像素位置（0秒 = x:0, duration = x:videoContentWidth）
        return CGFloat(time * timeToPixelRatio)
    }
    
    /// 像素坐标转换为时间（考虑leftPadding偏移）
    private func coordinateToTime(_ x: CGFloat) -> Double {
        guard timeToPixelRatio > 0 else { return 0 }
        // 总像素位置 → 减去leftPadding得到视频内容区域位置 → 转换为时间
        let videoContentX = x - leftPadding
        let time = Double(videoContentX) / timeToPixelRatio
        // 🎯 修复：添加上界约束，防止时间刻度溢出视频时长
        return max(0, min(duration, time))
    }
    
    /// 🎯 Wink风格：获取当前竖线位置对应的截取时间
    func getCurrentCaptureTime() -> Double {
        // 🎯 修复：竖线约束到屏幕中心，但需要计算相对于TimelineView的位置
        let timelineCenter = bounds.width / 2  // TimelineView自身的中心
        let absoluteX = timelineCenter + scrollView.contentOffset.x  // 相对于内容视图的绝对位置
        
        // 🎯 使用更新后的坐标转换方法（已考虑padding）
        let captureTime = coordinateToTime(absoluteX)
        let clampedTime = max(0, min(duration, captureTime))  // 限制在有效范围内
        
        // 调试日志已移除以提升性能
        
        // 🎯 帧级别精度：在高缩放时对齐到帧边界
        if currentTimeResolution == .frames && zoomScale >= 4.0 {
            return alignToFrameBoundary(clampedTime)
        }
        
        return clampedTime
    }
    
    /// 🎯 将时间对齐到最近的帧边界
    private func alignToFrameBoundary(_ time: Double) -> Double {
        let frameDuration = 1.0 / frameRate
        let frameNumber = round(time / frameDuration)
        return frameNumber * frameDuration
    }
    
    /// 🎯 计算基于视频时间范围的有效滚动边界
    /// 
    /// 设计目标：
    /// - 让视频开头（0秒）能滚动到屏幕中心白色竖线位置
    /// - 让视频结尾（duration）能滚动到屏幕中心白色竖线位置
    /// - 防止滚动到视频内容区域之外的空白区域
    ///
    /// 坐标系统说明：
    /// - contentView 总宽度 = leftPadding + 视频内容宽度 + rightPadding
    /// - leftPadding = bounds.width / 2  （让视频开头能到达中心）
    /// - rightPadding = bounds.width / 2 （让视频结尾能到达中心）
    /// - 视频内容宽度 = baseContentWidth × zoomScale
    private func getValidScrollRange() -> (min: CGFloat, max: CGFloat) {
        guard duration > 0, bounds.width > 0 else {
            print("🔍 DEBUG-P4: getValidScrollRange early return - duration=\(duration), bounds.width=\(bounds.width)")
            return (min: 0, max: 0)
        }
        
        let centerX = bounds.width / 2  // 屏幕中心位置（白色竖线固定在此）
        
        // ✅ 修复：让视频开头能到达中心
        // timeToCoordinate(0) 返回 leftPadding，即视频内容的起始位置
        let videoStartX = timeToCoordinate(0)
        let minScrollOffset = videoStartX - centerX
        
        // ✅ 修复：基于真实视频内容宽度计算结束位置
        // 之前的问题：timeToCoordinate(duration) 计算可能不够精确
        // 现在直接使用：leftPadding + 实际视频内容宽度
        let videoEndX = leftPadding + getActualVideoWidth()
        let maxScrollOffset = videoEndX - centerX
        
        return (min: minScrollOffset, max: maxScrollOffset)
    }
    
    /// 🎯 同步滚动到指定截取时间
    func scrollToCaptureTime(_ time: Double, animated: Bool = true) {
        // 🎯 使用更新后的坐标转换（已考虑padding）
        let targetX = timeToCoordinate(time)
        let centerX = bounds.width / 2  // 🎯 修复：基于TimelineView宽度计算中心位置
        
        // 计算需要的滚动偏移，让目标时间点移动到中心竖线位置
        let scrollOffsetX = targetX - centerX
        
        // 🎯 使用基于时间的滚动边界约束
        let scrollRange = getValidScrollRange()
        let clampedOffset = max(scrollRange.min, min(scrollRange.max, scrollOffsetX))
        
        // 🎯 使用自定义时长的平滑动画（0.5秒，Apple风格的easeInOut曲线）
        if animated {
            UIView.animate(
                withDuration: 0.5,  // 🎯 从 0.25-0.3s 增加到 0.5s，更丝滑
                delay: 0,
                options: [.curveEaseInOut, .allowUserInteraction],  // 🎯 easeInOut 曲线最自然
                animations: {
                    self.scrollView.setContentOffset(CGPoint(x: clampedOffset, y: 0), animated: false)
                },
                completion: nil
            )
        } else {
            scrollView.setContentOffset(CGPoint(x: clampedOffset, y: 0), animated: false)
        }
        
        // 🎯 滚动后更新Live Photo范围指示器
        if isLivePhotoMode {
            DispatchQueue.main.async {
                self.updateLivePhotoRangePosition()
            }
        }
    }
    
    // MARK: - Public Methods
    func setDuration(_ duration: Double) {
        self.duration = duration
        updateContentSize()
        generateThumbnails()
        updateTimeResolution()
        generateTimeScale()  // 🎯 修复问题1：确保初始刻度立即生成
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
    
    func setProgress(_ progress: Double, animated: Bool = true) {
        // 🎯 修复：播放时允许进度更新，但区分播放和手动操作
        currentProgress = progress
        let targetTime = progress * duration
        
        // 🎯 关键修复：播放时标记为播放进度更新，避免触发反向同步
        isPlaybackProgressUpdate = true
        
        // 🎯 播放状态下，同步时间轴滚动位置到播放进度
        if isPlaying {
            scrollToCaptureTime(targetTime, animated: animated)
            
            // 🎯 播放时更新Live Photo范围指示器
            if isLivePhotoMode {
                updateLivePhotoRangePosition()
            }
        }
        
        // 🎯 修复：延迟重置标志，让滚动动画完成后的回调也能识别为播放进度更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // 🎯 更新为 0.5s，匹配新动画时长
            self.isPlaybackProgressUpdate = false
        }
    }
    
    // 🎯 新增：播放状态控制方法
    func startPlayback() {
        isPlaying = true
        delegate?.timelineViewDidRequestPlay(self)
    }
    
    func pausePlayback() {
        isPlaying = false
        delegate?.timelineViewDidRequestPause(self)
    }
    
    func setPlaybackState(_ playing: Bool) {
        isPlaying = playing
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
    
    // MARK: - Time Scale Generation
    private var lastVisibleRange: (start: CGFloat, end: CGFloat) = (0, 0)
    private var lastScaleUpdateTime: TimeInterval = 0
    private let scaleUpdateThreshold: TimeInterval = 0.1 // 最小更新间隔
    
    private func generateTimeScale() {
        // 🎯 性能优化：限制更新频率
        let currentMediaTime = CACurrentMediaTime()
        if currentMediaTime - lastScaleUpdateTime < scaleUpdateThreshold {
            return
        }
        lastScaleUpdateTime = currentMediaTime
        
        guard duration > 0, bounds.width > 0 else { return }
        
        // 🎯 确定需要绘制的可见时间范围
        let visibleStartOffset = scrollView.contentOffset.x
        let visibleEndOffset = visibleStartOffset + scrollView.bounds.width
        
        // 🎯 性能优化：只有可见范围明显变化时才重新绘制
        let rangeDiff = abs(visibleStartOffset - lastVisibleRange.start) + abs(visibleEndOffset - lastVisibleRange.end)
        if rangeDiff < bounds.width * 0.1 {
            return  // 变化幅度小于10%，跳过更新
        }
        lastVisibleRange = (visibleStartOffset, visibleEndOffset)
        
        // 清空旧的刻度图层
        timeScaleView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // 🎯 修复：正确计算可见时间范围，确保不会因为padding产生负时间
        let startTime = max(0, coordinateToTime(visibleStartOffset))
        let endTime = min(duration, coordinateToTime(visibleEndOffset))
        
        // 🎯 获取刻度间隔
        let interval = getCurrentTimeInterval()
        
        var tickCount = 0
        
        // 🔑 关键修复：时间刻度坐标转换为相对于时间刻度视图的坐标
        // 0秒在视频内容区域的起始位置，对应时间刻度视图的x=0位置
        let zeroTimeScaleX = timeToVideoContentCoordinate(0)
        if zeroTimeScaleX >= -10 && zeroTimeScaleX <= timeScaleView.bounds.width + 10 {
            drawTickMark(at: zeroTimeScaleX, for: 0, interval: interval)
            tickCount += 1
        }
        
        // 结尾刻度：duration对应视频内容区域的结尾位置
        let endTimeScaleX = timeToVideoContentCoordinate(duration)
        if endTimeScaleX >= -10 && endTimeScaleX <= timeScaleView.bounds.width + 10 {
            drawTickMark(at: endTimeScaleX, for: duration, interval: interval)
            tickCount += 1
        }
        
        // 🎯 绘制中间的间隔刻度
        var tickTime = max(0, floor(startTime / interval) * interval)
        
        let epsilon = 0.001
        while tickTime <= endTime + epsilon && tickTime <= duration + epsilon {
            let isZeroTick = abs(tickTime - 0) < epsilon
            let isEndTick = abs(tickTime - duration) < epsilon
            
            if !isZeroTick && !isEndTick {
                // 🔑 使用视频内容区域坐标系
                let timeScaleX = timeToVideoContentCoordinate(tickTime)
                
                // 扩展绘制范围，减少边界闪烁
                if timeScaleX >= -10 && timeScaleX <= timeScaleView.bounds.width + 10 {
                    drawTickMark(at: timeScaleX, for: tickTime, interval: interval)
                    tickCount += 1
                }
            }
            
            tickTime += interval
        }
        
        // 刻度生成完成，已优化坐标计算逻辑
    }
    
    /// 绘制单个刻度线和文字
    private func drawTickMark(at x: CGFloat, for time: Double, interval: Double) {
        let isMainTick = shouldDrawTimeLabel(for: time, interval: interval)
        
        // ✅ 修复：只在刻度线可见范围内绘制
        let tickX = x - 0.5
        if tickX >= -1 && tickX <= timeScaleView.bounds.width + 1 {
            // 绘制刻度线
            let tickLayer = CALayer()
            // 🎯 修复问题2：改为深紫色，与粉紫背景协调且清晰（使用主题色）
            tickLayer.backgroundColor = ThemeManager.timelineTickColor.cgColor
            tickLayer.frame = CGRect(
                x: tickX,
                y: timeScaleView.bounds.height - (isMainTick ? 9 : 6),
                width: 1,
                height: isMainTick ? 9 : 6
            )
            timeScaleView.layer.addSublayer(tickLayer)
        }
        
        // 只在主刻度位置绘制时间文字
        if isMainTick {
            let textLayer = CATextLayer()
            textLayer.string = formatTimeForDisplay(time)
            textLayer.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            textLayer.fontSize = 11
            // 🎯 修复：改为深紫色，与刻度线颜色一致（使用主题色）
            textLayer.foregroundColor = ThemeManager.timelineTickColor.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            
            // 计算文字尺寸并居中对齐
            let textSize = (textLayer.string as? String)?.size(withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium)
            ]) ?? CGSize(width: 40, height: 12)
            
            // ✅ 修复：文字位置只有在完全可见时才绘制，否则跳过
            let halfTextWidth = textSize.width / 2
            let textLeftEdge = x - halfTextWidth
            let textRightEdge = x + halfTextWidth
            
            // 🎯 修复问题4：放宽边界检查，确保0秒和结尾时间可见
            let margin: CGFloat = 25  // 允许边界文字部分超出
            if textLeftEdge >= -margin && textRightEdge <= timeScaleView.bounds.width + margin {
                textLayer.frame = CGRect(
                    x: textLeftEdge,
                    y: 2,
                    width: textSize.width,
                    height: textSize.height
                )
                timeScaleView.layer.addSublayer(textLayer)
            }
        }
    }
    
    /// 判断是否应该绘制时间文字（避免文字过于密集）
    private func shouldDrawTimeLabel(for time: Double, interval: Double) -> Bool {
        switch currentTimeResolution {
        case .seconds:
            return abs(time.truncatingRemainder(dividingBy: 1.0)) < 0.01
        case .halfSeconds:
            return abs(time.truncatingRemainder(dividingBy: 1.0)) < 0.01
        case .frames:
            let frameInterval = 1.0 / frameRate
            let framesPerSecond = Int(1.0 / frameInterval)
            let frameNumber = Int(time / frameInterval)
            return frameNumber % max(1, framesPerSecond / 4) == 0  // 每秒显示4个主刻度
        }
    }
    
    /// 格式化时间显示
    private func formatTimeForDisplay(_ time: Double) -> String {
        switch currentTimeResolution {
        case .seconds, .halfSeconds:
            return time.formattedTimeString()
        case .frames:
            return time.formattedFrameString(at: frameRate)
        }
    }
    
    private func centerCurrentProgressIfNeeded() {
        // 🎯 Wink编辑器模式：不再自动跟踪播放位置
        // ❌ 移除播放位置自动跟踪逻辑
        // ✅ 白色竖线固定在中心，用户通过滚动选择截图位置
        
        // 保留方法用于兼容性，但不执行任何跟踪操作
        // 在编辑器模式下，位置控制完全由用户主导
    }
    
    /// 🎯 Wink编辑器模式：移除播放头跟踪逻辑
    private func shouldAutoTrackPlayhead(currentTimeX: CGFloat, visibleWidth: CGFloat, currentOffsetX: CGFloat) -> Bool {
        // ❌ 不再需要播放头跟踪判断
        // ✅ 白色竖线固定在中心，无需跟踪
        return false
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
        // 🎯 修复：基于实际视频内容区域宽度计算，确保填满整个时间轴
        let videoContentWidth = getActualVideoWidth()
        
        // 🎯 每个缩略图的理想宽度（像素）- 根据缩放级别动态调整
        // 随着缩放增加，理想宽度逐渐减小，让缩略图数量增加更平滑
        let idealThumbnailWidth: CGFloat = {
            if zoomScale >= 4.0 {
                return 55  // 高缩放（4x+）：密集显示，精准定位
            } else if zoomScale >= 2.0 {
                // 2-4x：线性插值 80 → 55
                let factor = (zoomScale - 2.0) / 2.0  // 0.0 → 1.0
                return 80 - factor * 25  // 80 → 55
            } else if zoomScale >= 1.0 {
                // 1-2x：线性插值 90 → 80
                let factor = (zoomScale - 1.0) / 1.0  // 0.0 → 1.0
                return 90 - factor * 10  // 90 → 80
            } else {
                return 90  // 低缩放（<1x）：稀疏显示，宽大清晰
            }
        }()
        
        // 🎯 核心算法：基于视频内容宽度和理想缩略图宽度，直接计算数量
        // 随着缩放增加，videoContentWidth增大，缩略图数量自然增加
        // 同时保持每个缩略图的宽度在理想范围内，确保比例正常
        let optimalCount = Int(ceil(videoContentWidth / idealThumbnailWidth))
        
        // 🎯 智能上限：根据视频时长动态调整最大数量
        let dynamicMaxCount: Int = {
            if duration < 30 {
                return 800  // 30秒内：超高密度
            } else if duration < 60 {
                return 600  // 1分钟内：高密度
            } else if duration < 120 {
                return 500  // 2分钟内：中高密度
            } else if duration < 300 {
                return 400  // 5分钟内：中等密度
            } else {
                return 300  // 长视频：基础密度
            }
        }()
        
        let clampedCount = max(5, min(dynamicMaxCount, optimalCount))
        let actualThumbnailWidth = videoContentWidth / CGFloat(clampedCount)
        
        print("🖼️ 缩略图计算: 时长=\(duration)s, 视频宽度=\(videoContentWidth)px, 缩放=\(String(format: "%.2f", zoomScale))x, 理想宽度=\(idealThumbnailWidth)px, 计算数量=\(optimalCount), 最终数量=\(clampedCount), 实际宽度=\(String(format: "%.1f", actualThumbnailWidth))px")
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
        
        // 🔑 关键修复：缩略图基于视频内容区域宽度，不再基于TimelineView宽度
        let containerWidth = getActualVideoWidth()  // 使用视频内容宽度
        let thumbnailWidth = containerWidth / CGFloat(count)
        let thumbnailHeight: CGFloat = 60  // 40 → 60px，与约束保持一致
        
        // 🎯 关键修复：动态计算高质量缩略图分辨率
        let targetThumbnailSize = calculateOptimalThumbnailSize(
            displayWidth: thumbnailWidth, 
            displayHeight: thumbnailHeight
        )
        
        // 配置高质量图像生成器
        imageGenerator.appliesPreferredTrackTransform = true
        // 🎯 修复问题3：设置零时间容差，确保缩略图与视频帧精确对应
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
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
            
            // 🎯 使用 frame 布局 - 缩略图容器已居中，从0开始布局
            imageView.frame = CGRect(
                x: CGFloat(i) * thumbnailWidth,
                y: 0,
                width: thumbnailWidth,
                height: 60  // 40 → 60px
            )
            
            // 🎯 修复问题3：将缩略图时间对齐到视频帧边界，确保精确对应
            let timePercent = Double(i) / Double(max(1, count - 1))
            let targetTime = duration * timePercent
            
            // 对齐到最近的视频帧边界
            let frameDuration = 1.0 / frameRate
            let frameNumber = round(targetTime / frameDuration)
            var alignedTime = frameNumber * frameDuration
            
            // 🔑 关键修复：确保对齐后的时间不超出视频时长（避免最后一帧生成失败）
            // 为安全起见，最后一帧提前一个帧的时间
            if alignedTime >= duration {
                alignedTime = max(0, duration - frameDuration)
            }
            
            let time = CMTime(seconds: alignedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            
            generateThumbnail(at: time, for: imageView, using: imageGenerator)
        }
        
        print("🖼️ 生成 \(count) 个缩略图, 每个宽度: \(thumbnailWidth), 容器宽度: \(containerWidth)")
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
    
    // MARK: - Wink Editor Mode (移除传统进度更新)
    private func updateProgressUI() {
        // 🎯 Wink编辑器模式：不再更新传统播放进度
        // ❌ 移除滑块位置更新
        // ❌ 移除进度条宽度更新  
        // ✅ 白色竖线固定在中心，无需更新位置
        
        // 保留方法用于兼容性，但内部逻辑已清空
        // 所有定位逻辑现在基于固定的白色竖线
    }
    
    
    private func updateProgressConstraints() {
        // 🎯 Wink编辑器模式：不再需要进度条约束更新
        // ❌ 进度条已隐藏，无需更新约束
        // 保留方法用于兼容性
    }
    
    // MARK: - Gesture Handling (Wink编辑器模式)
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        // 🎯 Wink逻辑：拖拽滚动时间轴内容，白色竖线保持固定
        let translation = gesture.translation(in: scrollView)
        
        switch gesture.state {
        case .began:
            isDragging = true
            delegate?.timelineViewDidBeginSeeking(self)
            
            // 🎯 白色竖线脉冲效果，强调截图瞄准器
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.playheadIndicator.transform = CGAffineTransform(scaleX: 1.2, y: 1.0)
            }
            
            // 触觉反馈
            HapticFeedbackManager.shared.sliderValueChanged()
            
        case .changed:
            // 🎯 计算新的滚动偏移 (拖拽移动时间轴内容)
            let currentOffsetX = scrollView.contentOffset.x
            let newOffsetX = currentOffsetX - translation.x  // 反向滚动，符合直觉
            
            // 🎯 使用基于视频时间范围的滚动边界约束
            let scrollRange = getValidScrollRange()
            let clampedOffsetX = max(scrollRange.min, min(scrollRange.max, newOffsetX))
            
            print("🔍 DEBUG-P4: Pan gesture - newOffsetX=\(newOffsetX), scrollRange=\(scrollRange), clampedOffsetX=\(clampedOffsetX)")
            if clampedOffsetX != newOffsetX {
                print("🔍 DEBUG-P4: Pan gesture - ⚠️ CLAMPED! Original=\(newOffsetX) → Clamped=\(clampedOffsetX)")
            }
            
            // 更新滚动位置
            scrollView.setContentOffset(CGPoint(x: clampedOffsetX, y: 0), animated: false)
            
            // 重置translation避免累加
            gesture.setTranslation(.zero, in: scrollView)
            
            // 🎯 实时通知截取时间变化（基于固定白色竖线）
            let captureTime = getCurrentCaptureTime()
            let progress = duration > 0 ? captureTime / duration : 0
            
            // 🎯 区分播放中的进度更新和用户手动跳转
            if isPlaybackProgressUpdate {
                delegate?.timelineView(self, didUpdateProgressDuringPlayback: progress)
            } else {
                delegate?.timelineView(self, didSeekToProgress: progress)
                // 用户手动操作时暂停播放
                if isPlaying {
                    pausePlayback()
                }
            }
            
            // 🎯 拖拽时更新Live Photo范围指示器
            if isLivePhotoMode {
                updateLivePhotoRangePosition()
            }
            
        case .ended, .cancelled:
            isDragging = false
            delegate?.timelineViewDidEndSeeking(self)
            
            // 🎯 恢复白色竖线大小
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.playheadIndicator.transform = .identity
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
                
                // 🎯 使用基于视频时间范围的滚动边界约束
                let scrollRange = getValidScrollRange()
                let clampedOffset = max(scrollRange.min, min(scrollRange.max, newScrollOffset))
                
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
        
        // 🎯 缩放时更新Live Photo范围指示器
        if isLivePhotoMode {
            updateLivePhotoRangePosition()
        }
        
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
            baseContentWidth = bounds.width  // 🎯 基于TimelineView宽度，保持内部一致性
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
        guard currentThumbnailCount > 0, bounds.width > 0 else { return }
        
        // 🎯 关键修复：缩略图容器宽度应该与视频内容区域宽度一致，而不是TimelineView宽度
        // 这样缩略图数量增加时，它们会平铺在更宽的区域上，通过滚动查看
        let containerWidth = getActualVideoWidth()  // 使用视频内容区域宽度
        let thumbnailWidth = containerWidth / CGFloat(currentThumbnailCount)
        
        for (index, imageView) in thumbnailImageViews.enumerated() {
            imageView.frame = CGRect(
                x: CGFloat(index) * thumbnailWidth,
                y: 0,
                width: thumbnailWidth,
                height: 60  // 40 → 60px
            )
        }
        
        print("🖼️ 更新缩略图布局: \(currentThumbnailCount)个, 每个宽度: \(thumbnailWidth), 容器宽度: \(containerWidth)")
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
        
        // 🎯 如果点击在轨道区域，直接跳转到该位置（现在轨道与TimelineView同宽）
        let trackFrame = CGRect(
            x: 0,
            y: trackView.frame.minY,
            width: bounds.width,  // 轨道现在与TimelineView同宽
            height: trackView.frame.height
        )
        
        if trackFrame.contains(locationInContent) {
            // 🎯 调整坐标转换：点击位置相对于TimelineView，需要转换为contentView坐标系
            let clickXInTimeline = locationInScrollView.x  // 相对于TimelineView的x坐标
            let clickXInContent = clickXInTimeline + scrollView.contentOffset.x  // 转换为contentView坐标系
            
            let currentTime = coordinateToTime(clickXInContent)
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
        // 🎯 Wink编辑器模式：只处理截图时间变化通知
        // ❌ 不再更新传统播放器的进度条和滑块
        
        // 🎯 滚动时更新Live Photo范围指示器
        if isLivePhotoMode {
            updateLivePhotoRangePosition()
        }
        
        // 🎯 新增：滚动时刷新时间刻度
        generateTimeScale()
        
        // 🎯 注意：不在这里触发 didSeekToProgress 回调，避免过于频繁
        // 回调已移至：手势结束、滚动减速结束等明确的用户操作完成时机
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
        // 自动滚动动画结束（播放时的自动跟踪滚动）
        // 🎯 注意：不在这里触发 didSeekToProgress，因为：
        // 1. 播放时的滚动是由 setProgress() 驱动的，不需要反向通知
        // 2. 避免播放结束时触发 performVideoSeek() 的连锁反应
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
    
    // 🎯 新增：关键修复 - 允许按钮区域的触摸事件优先处理
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchPoint = touch.location(in: self)
        
        // 🚨 方法1: 通过响应链查找是否点击了UIButton
        if let superview = self.superview {
            let touchPointInSuperview = touch.location(in: superview)
            if let hitView = superview.hitTest(touchPointInSuperview, with: nil) {
                // 检查是否点击了UIButton或其子视图
                var currentView: UIView? = hitView
                while currentView != nil {
                    if currentView is UIButton {
                        print("🎯 TimelineView: 检测到按钮点击(\(type(of: currentView!))), 手势识别器让步")
                        return false
                    }
                    currentView = currentView?.superview
                }
            }
        }
        
        // 🚨 方法2: 直接检查触摸视图类型
        let touchView = touch.view
        if touchView is UIButton {
            print("🎯 TimelineView: 直接检测到按钮触摸, 手势识别器让步")
            return false
        }
        
        // 🚨 方法3: 检查触摸视图的父视图
        var parentView = touchView?.superview
        while parentView != nil {
            if parentView is UIButton {
                print("🎯 TimelineView: 检测到按钮父视图触摸, 手势识别器让步")
                return false
            }
            parentView = parentView?.superview
        }
        
        return true
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            // 🎯 Wink编辑器模式：拖拽在整个时间轴区域都可以进行
            // ❌ 不再检查滑块区域（滑块已隐藏）
            // ✅ 拖拽手势控制时间轴内容滚动
            return true  // 整个时间轴区域：内容滚动控制
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
    
    // MARK: - External Updates
    /// 处理边界变化，重新计算布局和内容尺寸
    func handleBoundsChange() {
        // ✅ 修复：当TimelineView宽度发生变化时，重新计算所有依赖于bounds的值
        DispatchQueue.main.async { [weak self] in
            self?.updateContentSize()
            self?.generateTimeScale()
            
            // 如果是Live Photo模式，更新范围位置
            if self?.isLivePhotoMode == true {
                self?.updateLivePhotoRangePosition()
            }
        }
    }
}
