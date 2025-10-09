//
//  VideoGalleryGuideView.swift
//  Winkkk
//
//  Created by Assistant on 2025/9/28.
//  用户引导气泡视图 - 为首次使用用户提供功能介绍
//

import UIKit

// MARK: - 引导步骤数据结构
struct GuideStep {
    let title: String
    let message: String
    let targetView: UIView?
    let arrowDirection: GuideArrowDirection
    let action: (() -> Void)?
    
    init(title: String, message: String, targetView: UIView? = nil, arrowDirection: GuideArrowDirection = .up, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.targetView = targetView
        self.arrowDirection = arrowDirection
        self.action = action
    }
}

enum GuideArrowDirection {
    case up, down, left, right, none
}

// MARK: - 引导视图协议
protocol VideoGalleryGuideDelegate: AnyObject {
    func guideDidComplete()
    func guideDidSkip()
}

// MARK: - 引导气泡视图
class VideoGalleryGuideView: UIView {
    
    // MARK: - Properties
    weak var delegate: VideoGalleryGuideDelegate?
    private var steps: [GuideStep] = []
    private var currentStepIndex = 0
    
    // MARK: - UI Components
    private let overlayView = UIView()
    private let bubbleView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let nextButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let arrowView = UIView()
    
    // MARK: - Layout Properties
    private var bubbleConstraints: [NSLayoutConstraint] = []
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        // 半透明遮罩
        overlayView.backgroundColor = ThemeManager.popupDimmingBackground
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlayView)
        
        // 引导气泡容器
        bubbleView.backgroundColor = UIColor.systemBackground
        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 4)
        bubbleView.layer.shadowRadius = 12
        bubbleView.layer.shadowOpacity = 0.15
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubbleView)
        
        // 标题标签
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(titleLabel)
        
        // 消息标签
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
        
        // 进度条
        progressView.progressTintColor = UIColor.systemBlue
        progressView.trackTintColor = UIColor.systemGray5
        progressView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(progressView)
        
        // 下一步按钮
        nextButton.setTitle("下一步", for: .normal)
        nextButton.setTitleColor(.systemBlue, for: .normal)
        nextButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(nextButton)
        
        // 跳过按钮
        skipButton.setTitle("跳过", for: .normal)
        skipButton.setTitleColor(.systemGray, for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(skipButton)
        
        // 箭头视图
        arrowView.backgroundColor = UIColor.systemBackground
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrowView)
        
        // 添加手势识别
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        overlayView.addGestureRecognizer(tapGesture)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 遮罩层填满整个视图
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 气泡内部布局
            titleLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -20),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -20),
            
            progressView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            skipButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            skipButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 20),
            skipButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -16),
            
            nextButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            nextButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -20),
            nextButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -16),
            
            // 气泡默认约束（会动态更新）
            bubbleView.widthAnchor.constraint(equalToConstant: 280),
            bubbleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bubbleView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    // MARK: - Public Methods
    func startGuide(with steps: [GuideStep]) {
        self.steps = steps
        self.currentStepIndex = 0
        showCurrentStep()
        
        // 添加动画进入
        alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    // MARK: - Private Methods
    private func showCurrentStep() {
        guard currentStepIndex < steps.count else {
            completeGuide()
            return
        }
        
        let step = steps[currentStepIndex]
        titleLabel.text = step.title
        messageLabel.text = step.message
        
        // 更新进度
        let progress = Float(currentStepIndex + 1) / Float(steps.count)
        progressView.setProgress(progress, animated: true)
        
        // 更新按钮文字
        if currentStepIndex == steps.count - 1 {
            nextButton.setTitle("完成", for: .normal)
        } else {
            nextButton.setTitle("下一步", for: .normal)
        }
        
        // 执行步骤动作
        step.action?()
        
        // 更新气泡位置
        updateBubblePosition(for: step)
        
        // 高亮目标视图
        highlightTargetView(step.targetView)
    }
    
    private func updateBubblePosition(for step: GuideStep) {
        // 移除旧约束
        NSLayoutConstraint.deactivate(bubbleConstraints)
        bubbleConstraints.removeAll()
        
        guard let targetView = step.targetView else {
            // 没有目标视图时居中显示
            bubbleConstraints = [
                bubbleView.centerXAnchor.constraint(equalTo: centerXAnchor),
                bubbleView.centerYAnchor.constraint(equalTo: centerYAnchor),
                bubbleView.widthAnchor.constraint(equalToConstant: 280)
            ]
            NSLayoutConstraint.activate(bubbleConstraints)
            return
        }
        
        // 获取目标视图在当前视图中的坐标
        let targetFrame = targetView.convert(targetView.bounds, to: self)
        
        // 获取安全区域
        let safeInsets = safeAreaInsets
        let topSafeArea = safeInsets.top
        let bottomSafeArea = safeInsets.bottom
        let leftSafeArea = safeInsets.left
        let rightSafeArea = safeInsets.right
        
        // 气泡尺寸和边距
        let bubbleWidth: CGFloat = 280
        let bubbleEstimatedHeight: CGFloat = 180 // 预估高度
        let margin: CGFloat = 20
        let edgeMargin: CGFloat = 20 // 距离屏幕边缘的最小距离
        
        // 根据箭头方向调整气泡位置，并确保不超出屏幕
        var verticalConstraint: NSLayoutConstraint
        var horizontalConstraint: NSLayoutConstraint
        
        switch step.arrowDirection {
        case .up:
            // 气泡在目标下方
            let proposedTop = targetFrame.maxY + margin
            let minTop = topSafeArea + edgeMargin
            let actualTop = max(proposedTop, minTop)
            
            verticalConstraint = bubbleView.topAnchor.constraint(equalTo: topAnchor, constant: actualTop)
            
            // 水平居中对齐目标，但确保不超出屏幕
            let proposedCenterX = targetFrame.midX
            let minCenterX = leftSafeArea + edgeMargin + bubbleWidth / 2
            let maxCenterX = bounds.width - rightSafeArea - edgeMargin - bubbleWidth / 2
            let actualCenterX = min(max(proposedCenterX, minCenterX), maxCenterX)
            
            horizontalConstraint = bubbleView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: actualCenterX)
            
        case .down:
            // 气泡在目标上方
            let proposedBottom = targetFrame.minY - margin
            let maxBottom = bounds.height - bottomSafeArea - edgeMargin
            let actualBottom = min(proposedBottom, maxBottom)
            
            verticalConstraint = bubbleView.bottomAnchor.constraint(equalTo: topAnchor, constant: actualBottom)
            
            // 水平居中对齐目标，但确保不超出屏幕
            let proposedCenterX = targetFrame.midX
            let minCenterX = leftSafeArea + edgeMargin + bubbleWidth / 2
            let maxCenterX = bounds.width - rightSafeArea - edgeMargin - bubbleWidth / 2
            let actualCenterX = min(max(proposedCenterX, minCenterX), maxCenterX)
            
            horizontalConstraint = bubbleView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: actualCenterX)
            
        case .left:
            // 气泡在目标右侧
            let proposedLeading = targetFrame.maxX + margin
            let minLeading = leftSafeArea + edgeMargin
            let actualLeading = max(proposedLeading, minLeading)
            
            horizontalConstraint = bubbleView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: actualLeading)
            
            // 垂直居中对齐目标，但确保不超出屏幕
            let proposedCenterY = targetFrame.midY
            let minCenterY = topSafeArea + edgeMargin + bubbleEstimatedHeight / 2
            let maxCenterY = bounds.height - bottomSafeArea - edgeMargin - bubbleEstimatedHeight / 2
            let actualCenterY = min(max(proposedCenterY, minCenterY), maxCenterY)
            
            verticalConstraint = bubbleView.centerYAnchor.constraint(equalTo: topAnchor, constant: actualCenterY)
            
        case .right:
            // 气泡在目标左侧
            let proposedTrailing = targetFrame.minX - margin
            let maxTrailing = bounds.width - rightSafeArea - edgeMargin
            let actualTrailing = min(proposedTrailing, maxTrailing)
            
            horizontalConstraint = bubbleView.trailingAnchor.constraint(equalTo: leadingAnchor, constant: actualTrailing)
            
            // 垂直居中对齐目标，但确保不超出屏幕
            let proposedCenterY = targetFrame.midY
            let minCenterY = topSafeArea + edgeMargin + bubbleEstimatedHeight / 2
            let maxCenterY = bounds.height - bottomSafeArea - edgeMargin - bubbleEstimatedHeight / 2
            let actualCenterY = min(max(proposedCenterY, minCenterY), maxCenterY)
            
            verticalConstraint = bubbleView.centerYAnchor.constraint(equalTo: topAnchor, constant: actualCenterY)
            
        case .none:
            // 居中显示
            verticalConstraint = bubbleView.centerYAnchor.constraint(equalTo: centerYAnchor)
            horizontalConstraint = bubbleView.centerXAnchor.constraint(equalTo: centerXAnchor)
        }
        
        bubbleConstraints = [
            verticalConstraint,
            horizontalConstraint,
            bubbleView.widthAnchor.constraint(equalToConstant: bubbleWidth),
            // 添加额外的安全约束，确保气泡不会超出屏幕
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: leftSafeArea + edgeMargin),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -(rightSafeArea + edgeMargin)),
            bubbleView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: topSafeArea + edgeMargin),
            bubbleView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -(bottomSafeArea + edgeMargin))
        ]
        
        NSLayoutConstraint.activate(bubbleConstraints)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.layoutIfNeeded()
        })
    }
    
    private func highlightTargetView(_ targetView: UIView?) {
        // 清除之前的高亮
        overlayView.layer.mask = nil
        
        guard let targetView = targetView else { return }
        
        // 创建遮罩路径，为目标视图留出透明区域
        let targetFrame = targetView.convert(targetView.bounds, to: self)
        let path = UIBezierPath(rect: bounds)
        let highlightPath = UIBezierPath(roundedRect: targetFrame.insetBy(dx: -8, dy: -8), cornerRadius: 8)
        path.append(highlightPath.reversing())
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        overlayView.layer.mask = maskLayer
    }
    
    private func completeGuide() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.delegate?.guideDidComplete()
            self.removeFromSuperview()
        }
    }
    
    // MARK: - Actions
    @objc private func nextButtonTapped() {
        // 触觉反馈
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator.impactOccurred()
        
        currentStepIndex += 1
        showCurrentStep()
    }
    
    @objc private func skipButtonTapped() {
        // 触觉反馈
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator.impactOccurred()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.delegate?.guideDidSkip()
            self.removeFromSuperview()
        }
    }
    
    @objc private func overlayTapped() {
        // 点击遮罩区域继续下一步
        nextButtonTapped()
    }
}
