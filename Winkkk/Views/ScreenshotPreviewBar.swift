//
//  ScreenshotPreviewBar.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图预览栏 - 会话隔离设计
//

import UIKit
import Combine

protocol ScreenshotPreviewBarDelegate: AnyObject {
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didTapScreenshot screenshot: ScreenshotItem, at index: Int)
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestCapture mode: CaptureMode)
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestPreviewAll screenshots: [ScreenshotItem])
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestEnhanceAll screenshots: [ScreenshotItem])
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestClearAll mode: CaptureMode)
    
    // 🆕 添加长按手势支持（可选方法，提供默认实现）
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didLongPressScreenshot screenshot: ScreenshotItem, at index: Int)
}

// 🆕 为长按手势提供默认实现，使其成为可选方法
extension ScreenshotPreviewBarDelegate {
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didLongPressScreenshot screenshot: ScreenshotItem, at index: Int) {
        // 默认空实现，委托方可以选择是否重写此方法
    }
}

class ScreenshotPreviewBar: UIView {
    
    // MARK: - Properties
    weak var delegate: ScreenshotPreviewBarDelegate?
    private let screenshotManager = ScreenshotManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private let containerView = UIView()
    // 🆕 移除独立毛玻璃效果，使用透明背景（统一容器提供毛玻璃）
    // private let blurEffectView = BlurEffectView(style: .regular, intensity: 0.95)
    
    // 头部信息区域
    private let headerView = UIView()
    private let hintLabel = UILabel()
    private let clearButton = UIButton()
    
    // 截图滚动区域
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    // 操作按钮区域
    private let actionButtonsContainer = UIView()
    private let captureButton = UIButton()
    private let previewButton = UIButton()
    private let enhanceButton = UIButton()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupObservers()
        updateUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        setupObservers()
        updateUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 🆕 使用透明背景，毛玻璃效果由统一容器提供
        backgroundColor = .clear
        
        // 主容器 - 直接添加到self，不再使用独立毛玻璃
        containerView.backgroundColor = .clear
        addSubview(containerView)
        
        // 设置子组件
        setupHeaderView()
        setupScrollView()
        setupActionButtons()
        
        // 添加到容器
        containerView.addSubview(headerView)
        containerView.addSubview(scrollView)
        containerView.addSubview(actionButtonsContainer)
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // 提示标签
        hintLabel.font = ThemeManager.captionFont
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.textAlignment = .left
        hintLabel.numberOfLines = 1
        headerView.addSubview(hintLabel)
        
        // 清空按钮
        clearButton.setTitle("🗑 清空", for: .normal)
        clearButton.setTitleColor(UIColor.systemRed, for: .normal)
        clearButton.titleLabel?.font = ThemeManager.captionFont
        clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        clearButton.layer.cornerRadius = ThemeManager.smallCornerRadius
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        headerView.addSubview(clearButton)
        
        // 布局
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hintLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            
            clearButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 60),
            clearButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.decelerationRate = .fast
        
        // 配置堆叠视图
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        
        scrollView.addSubview(stackView)
        
        // 堆叠视图约束
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    private func setupActionButtons() {
        actionButtonsContainer.backgroundColor = .clear
        
        // 截图按钮
        setupCaptureButton()
        
        // 预览按钮
        setupPreviewButton()
        
        // 修复按钮
        setupEnhanceButton()
        
        // 添加到容器
        actionButtonsContainer.addSubview(captureButton)
        actionButtonsContainer.addSubview(previewButton)
        actionButtonsContainer.addSubview(enhanceButton)
        
        // 布局
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        previewButton.translatesAutoresizingMaskIntoConstraints = false
        enhanceButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 截图按钮（左侧）
            captureButton.leadingAnchor.constraint(equalTo: actionButtonsContainer.leadingAnchor),
            captureButton.centerYAnchor.constraint(equalTo: actionButtonsContainer.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 预览按钮（中间）
            previewButton.centerXAnchor.constraint(equalTo: actionButtonsContainer.centerXAnchor),
            previewButton.centerYAnchor.constraint(equalTo: actionButtonsContainer.centerYAnchor),
            previewButton.widthAnchor.constraint(equalToConstant: 80),
            previewButton.heightAnchor.constraint(equalToConstant: 40),
            
            // 修复按钮（右侧）
            enhanceButton.trailingAnchor.constraint(equalTo: actionButtonsContainer.trailingAnchor),
            enhanceButton.centerYAnchor.constraint(equalTo: actionButtonsContainer.centerYAnchor),
            enhanceButton.widthAnchor.constraint(equalToConstant: 80),
            enhanceButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupCaptureButton() {
        captureButton.setTitle("📷 截图", for: .normal)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = ThemeManager.buttonPrimary
        captureButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        captureButton.titleLabel?.font = ThemeManager.buttonFont
        
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        addButtonTouchEffects(to: captureButton)
    }
    
    private func setupPreviewButton() {
        previewButton.setTitle("👁 预览", for: .normal)
        previewButton.setTitleColor(.white, for: .normal)
        previewButton.backgroundColor = ThemeManager.cardBackground
        previewButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        previewButton.titleLabel?.font = ThemeManager.buttonFont
        
        previewButton.addTarget(self, action: #selector(previewButtonTapped), for: .touchUpInside)
        addButtonTouchEffects(to: previewButton)
    }
    
    private func setupEnhanceButton() {
        enhanceButton.setTitle("✨ 修复", for: .normal)
        enhanceButton.setTitleColor(.white, for: .normal)
        enhanceButton.backgroundColor = ThemeManager.success
        enhanceButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        enhanceButton.titleLabel?.font = ThemeManager.buttonFont
        
        enhanceButton.addTarget(self, action: #selector(enhanceButtonTapped), for: .touchUpInside)
        addButtonTouchEffects(to: enhanceButton)
    }
    
    private func addButtonTouchEffects(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        actionButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 🔧 优化：减少内部间距，避免约束冲突
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            // 头部视图
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 30),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 60),
            
            // 操作按钮容器 - 使用优先级约束避免冲突
            actionButtonsContainer.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            actionButtonsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            actionButtonsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        
        // 🔧 使用优先级约束避免冲突
        let bottomConstraint = actionButtonsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        bottomConstraint.priority = UILayoutPriority(999)
        bottomConstraint.isActive = true
        
        let minHeightConstraint = actionButtonsContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        minHeightConstraint.priority = UILayoutPriority(1000)
        minHeightConstraint.isActive = true
    }
    
    // MARK: - Observers
    private func setupObservers() {
        // 监听ScreenshotManager的变化
        screenshotManager.$screenshots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateUI()
            }
            .store(in: &cancellables)
        
        screenshotManager.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateUI()
            }
            .store(in: &cancellables)
        
        // 监听通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenshotAdded(_:)),
            name: .screenshotAdded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenshotRemoved(_:)),
            name: .screenshotRemoved,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(allScreenshotsCleared),
            name: .allScreenshotsCleared,
            object: nil
        )
    }
    
    // MARK: - UI Updates
    func updateWithScreenshots(_ screenshots: [ScreenshotItem]) {
        updateUI()
    }
    
    private func updateUI() {
        updateHintLabel()
        updateScreenshots()
        updateButtonStates()
    }
    
    private func updateHintLabel() {
        let count = screenshotManager.screenshotCount
        let mode = screenshotManager.currentMode
        let maxCount = mode.maxCount
        
        if count == 0 {
            hintLabel.text = "\(mode.displayName)模式 (最多\(maxCount)张)"
        } else {
            hintLabel.text = "已截\(count)张: \(mode.displayName) (最多\(maxCount)张)"
        }
        
        // 根据模式设置主题色
        let themeColor = mode.themeColor
        captureButton.backgroundColor = themeColor
        
        // 接近上限时的警告色
        if count >= maxCount - 2 {
            hintLabel.textColor = UIColor.systemOrange
        } else {
            hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        }
    }
    
    private func updateScreenshots() {
        // 清空现有视图
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // 添加新的截图视图
        for (index, screenshot) in screenshotManager.screenshots.enumerated() {
            let thumbnailView = createScreenshotThumbnailView(for: screenshot, at: index)
            stackView.addArrangedSubview(thumbnailView)
        }
        
        // 自动滚动到最新截图
        if !screenshotManager.screenshots.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollToRight(animated: true)
            }
        }
    }
    
    private func updateButtonStates() {
        let count = screenshotManager.screenshotCount
        let hasScreenshots = count > 0
        let isAtLimit = screenshotManager.isAtMaxLimit
        
        // 截图按钮
        captureButton.isEnabled = !isAtLimit
        captureButton.alpha = isAtLimit ? 0.5 : 1.0
        
        // 预览按钮
        previewButton.isEnabled = hasScreenshots
        previewButton.alpha = hasScreenshots ? 1.0 : 0.5
        
        // 修复按钮（Live Photo模式下隐藏）
        let shouldShowEnhance = hasScreenshots && screenshotManager.currentMode == .stillImage
        enhanceButton.isHidden = !shouldShowEnhance
        enhanceButton.alpha = shouldShowEnhance ? 1.0 : 0.5
        
        // 清空按钮
        clearButton.isEnabled = hasScreenshots
        clearButton.alpha = hasScreenshots ? 1.0 : 0.5
    }
    
    private func createScreenshotThumbnailView(for screenshot: ScreenshotItem, at index: Int) -> ScreenshotThumbnailView {
        let thumbnailView = ScreenshotThumbnailView()
        thumbnailView.configure(with: screenshot)
        
        thumbnailView.onDeleteTap = { [weak self] in
            self?.deleteScreenshot(at: index)
        }
        
        thumbnailView.onTap = { [weak self] in
            guard let self = self else { return }
            self.delegate?.screenshotPreviewBar(self, didTapScreenshot: screenshot, at: index)
        }
        
        thumbnailView.onLongPress = { [weak self] in
            guard let self = self else { return }
            self.delegate?.screenshotPreviewBar(self, didLongPressScreenshot: screenshot, at: index)
        }
        
        return thumbnailView
    }
    
    private func deleteScreenshot(at index: Int) {
        screenshotManager.removeScreenshot(at: index)
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func scrollToRight(animated: Bool) {
        let rightOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        scrollView.setContentOffset(CGPoint(x: rightOffset, y: 0), animated: animated)
    }
    
    // MARK: - Actions
    @objc private func captureButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        delegate?.screenshotPreviewBar(self, didRequestCapture: screenshotManager.currentMode)
    }
    
    @objc private func previewButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        delegate?.screenshotPreviewBar(self, didRequestPreviewAll: screenshotManager.screenshots)
    }
    
    @objc private func enhanceButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        delegate?.screenshotPreviewBar(self, didRequestEnhanceAll: screenshotManager.screenshots)
    }
    
    @objc private func clearButtonTapped() {
        HapticFeedbackManager.shared.lightImpact()
        
        let alert = UIAlertController(
            title: "清空确认",
            message: "确定要清空所有\(screenshotManager.currentMode.displayName)吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.screenshotPreviewBar(self, didRequestClearAll: self.screenshotManager.currentMode)
            self.screenshotManager.clearAllScreenshots()
            HapticFeedbackManager.shared.notificationSuccess()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        findParentViewController()?.present(alert, animated: true)
    }
    
    @objc private func buttonPressed(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = .identity
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func screenshotAdded(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    @objc private func screenshotRemoved(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    @objc private func allScreenshotsCleared() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    // MARK: - 🆕 多选状态管理方法
    private var isInSelectionMode = false
    private var selectedScreenshots: Set<ScreenshotItem> = []
    
    func setSelectionMode(_ selectionMode: Bool) {
        isInSelectionMode = selectionMode
        updateSelectionModeUI()
        
        if !selectionMode {
            selectedScreenshots.removeAll()
            updateAllThumbnailSelectionStates()
        }
    }
    
    func selectAllItems() {
        selectedScreenshots = Set(screenshotManager.screenshots)
        updateAllThumbnailSelectionStates()
        print("🔄 已选择所有 \(selectedScreenshots.count) 张截图")
    }
    
    func deselectAllItems() {
        selectedScreenshots.removeAll()
        updateAllThumbnailSelectionStates()
        print("🔄 已取消选择所有截图")
    }
    
    func setScreenshotSelected(_ screenshot: ScreenshotItem, isSelected: Bool) {
        if isSelected {
            selectedScreenshots.insert(screenshot)
        } else {
            selectedScreenshots.remove(screenshot)
        }
        
        // 更新对应缩略图的选择状态
        updateThumbnailSelectionState(for: screenshot, isSelected: isSelected)
        print("🔄 设置截图选择状态: \(isSelected), 当前已选择: \(selectedScreenshots.count)")
    }
    
    private func updateSelectionModeUI() {
        UIView.animate(withDuration: 0.3) {
            // 在多选模式下，可以调整整体透明度或其他视觉效果
            if self.isInSelectionMode {
                // 多选模式下的视觉反馈
                self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            } else {
                // 普通模式
                self.backgroundColor = .clear
            }
        }
    }
    
    private func updateAllThumbnailSelectionStates() {
        // 更新所有缩略图的选择状态
        for (index, screenshot) in screenshotManager.screenshots.enumerated() {
            let isSelected = selectedScreenshots.contains(screenshot)
            updateThumbnailSelectionState(for: screenshot, isSelected: isSelected)
        }
    }
    
    private func updateThumbnailSelectionState(for screenshot: ScreenshotItem, isSelected: Bool) {
        // 找到对应的缩略图视图并更新选择状态
        for subview in scrollView.subviews {
            if let thumbnailView = subview as? ScreenshotThumbnailView {
                // 这里需要通过某种方式识别对应的截图
                // 可以通过tag或其他方式关联
                thumbnailView.setSelected(isSelected, animated: true)
            }
        }
    }
}
