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
    func screenshotPreviewBar(_ previewBar: ScreenshotPreviewBar, didRequestClearAll mode: CaptureMode)
    
    
}

// 🆕 为可选方法提供默认实现
extension ScreenshotPreviewBarDelegate {
    
}

class ScreenshotPreviewBar: UIView {
    
    // MARK: - Properties
    weak var delegate: ScreenshotPreviewBarDelegate?
    private let screenshotManager = ScreenshotManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI Components
    // 🔧 移除containerView - 直接使用self作为容器，避免双重边界
    // 🆕 移除独立毛玻璃效果，使用透明背景（统一容器提供毛玻璃）
    // private let blurEffectView = BlurEffectView(style: .regular, intensity: 0.95)
    
    // 头部信息区域
    private let headerView = UIView()
    private let hintLabel = UILabel()
    private let clearButton = UIButton()
    
    // 截图滚动区域
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    
    // 📝 操作按钮区域已移除 - 使用点击预览替代
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        updateUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        updateUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 🆕 使用透明背景，毛玻璃效果由统一容器提供
        backgroundColor = .clear
        
        // 🎯 关键修复：提高整个预览栏的层级，确保在TimelineView之上
        layer.zPosition = 1500  // 高于TimelineView但低于按钮
        isUserInteractionEnabled = true
        
        // 🔧 直接使用self作为容器，避免双重边界
        // 设置子组件
        setupHeaderView()
        setupScrollView()
        
        // 直接添加到self
        addSubview(headerView)
        addSubview(scrollView)
        
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // 提示标签
        hintLabel.font = ThemeManager.captionFont
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.textAlignment = .left
        hintLabel.numberOfLines = 1
        headerView.addSubview(hintLabel)
        
        // 🌟 清空按钮 - 现代圆润设计
        clearButton.setTitle("🗑", for: .normal)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        clearButton.backgroundColor = UIColor.systemRed
        clearButton.layer.cornerRadius = 14  // 更圆润
        clearButton.layer.shadowColor = UIColor.systemRed.cgColor
        clearButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        clearButton.layer.shadowOpacity = 0.3
        clearButton.layer.shadowRadius = 4
        clearButton.layer.borderWidth = 1.5
        clearButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        
        // 🌟 添加按钮交互动画
        addButtonTouchEffects(to: clearButton)
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
            clearButton.widthAnchor.constraint(equalToConstant: 30),
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
    
    // 📝 setupActionButtons 已移除 - 操作通过点击缩略图完成
    
    // 📝 setupCaptureButton 已移除
    
    // 📝 setupPreviewButton 已移除
    
    // 📝 setupEnhanceButton 已移除
    
    // 📝 addButtonTouchEffects 已移除
    
    private func setupConstraints() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // 🔧 关键修复：设置约束优先级，确保ScrollView不被压缩
        let scrollViewHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 60)
        scrollViewHeightConstraint.priority = UILayoutPriority(1000)  // 最高优先级，绝对不能压缩
        
        let headerHeightConstraint = headerView.heightAnchor.constraint(equalToConstant: 30)
        headerHeightConstraint.priority = UILayoutPriority(999)  // 高优先级
        
        
        NSLayoutConstraint.activate([
            // 头部视图
            headerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            headerHeightConstraint,
            
            // 滚动视图 - 最关键的约束，绝对不能被压缩
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollViewHeightConstraint,
            
        ])
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
        
        // 📝 按钮主题色设置已移除
        
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
            // 🆕 弹出Sheet预览
            self.presentScreenshotDetailSheet(for: screenshot, at: index)
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
    // 📝 captureButtonTapped 已移除
    
    // 📝 previewButtonTapped 已移除
    
    // 📝 enhanceButtonTapped 已移除
    
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
    
    // 📝 buttonPressed/buttonReleased 已移除
    
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
    
    // 🌟 添加按钮交互动画效果
    private func addButtonTouchEffects(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    @objc private func buttonPressed(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction]) {
            button.transform = .identity
        }
    }
    
    // MARK: - 🆕 Sheet Preview Methods
    private func presentScreenshotDetailSheet(for screenshot: ScreenshotItem, at index: Int) {
        let screenshots = screenshotManager.screenshots
        let detailSheet = ScreenshotDetailSheet(screenshots: screenshots, currentIndex: index)
        detailSheet.delegate = self
        // 详情页会自动监听MultiSelectionManager的状态
        
        findParentViewController()?.present(detailSheet, animated: true)
    }
}

// MARK: - 🆕 ScreenshotDetailSheetDelegate
extension ScreenshotPreviewBar: ScreenshotDetailSheetDelegate {
    // 纯预览Sheet不需要复杂的委托方法实现
    // 如果未来需要添加新的委托方法，可以在这里实现
}
