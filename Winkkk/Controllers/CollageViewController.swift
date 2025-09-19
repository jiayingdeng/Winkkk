//
//  CollageViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  拼图创建视图控制器 - 布局选择、参数调节、预览编辑
//

import UIKit

class CollageViewController: UIViewController {
    
    // MARK: - Properties
    private let images: [UIImage]
    private var collageImage: UIImage?
    private var selectedLayout: CollageLayout = .grid
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 头部区域
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    
    // 预览区域
    private let previewContainerView = UIView()
    private let previewImageView = UIImageView()
    private let previewPlaceholder = UILabel()
    
    // 布局选择区域
    private let layoutSectionView = UIView()
    private let layoutTitleLabel = UILabel()
    private let layoutSegmentedControl = UISegmentedControl(items: ["🗺️ 网格", "↔️ 横向", "↕️ 竖向"])
    
    // 控制面板
    private let controlPanelView = UIView()
    private let generateButton = UIButton()
    private let progressView = UIProgressView()
    private let statusLabel = UILabel()
    
    // 底部按钮
    private let bottomButtonsView = UIView()
    private let saveButton = UIButton()
    private let shareButton = UIButton()
    private let resetButton = UIButton()
    
    // MARK: - Initialization
    init(images: [UIImage]) {
        self.images = images
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureNavigationBar()
        updatePreview()
        
        // 进入拼图页面的触感反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 头部区域
        setupHeaderView()
        
        // 预览区域
        setupPreviewArea()
        
        // 布局选择区域
        setupLayoutSection()
        
        // 控制面板
        setupControlPanel()
        
        // 底部按钮
        setupBottomButtons()
        
        // 添加到内容视图
        contentView.addSubview(headerView)
        contentView.addSubview(previewContainerView)
        contentView.addSubview(layoutSectionView)
        contentView.addSubview(controlPanelView)
        contentView.addSubview(bottomButtonsView)
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // 标题
        titleLabel.font = ThemeManager.titleFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.text = "创建拼图"
        headerView.addSubview(titleLabel)
        
        // 数量标签
        countLabel.font = ThemeManager.captionFont
        countLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        countLabel.textAlignment = .center
        countLabel.text = "已选择 \(images.count) 张图片"
        headerView.addSubview(countLabel)
    }
    
    private func setupPreviewArea() {
        previewContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        previewContainerView.layer.cornerRadius = ThemeManager.standardCornerRadius
        previewContainerView.clipsToBounds = true
        
        // 预览图片
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true
        previewImageView.layer.cornerRadius = 8
        previewImageView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        previewContainerView.addSubview(previewImageView)
        
        // 占位文字
        previewPlaceholder.font = ThemeManager.captionFont
        previewPlaceholder.textColor = UIColor.white.withAlphaComponent(0.6)
        previewPlaceholder.textAlignment = .center
        previewPlaceholder.text = "选择布局后生成预览"
        previewPlaceholder.numberOfLines = 0
        previewContainerView.addSubview(previewPlaceholder)
    }
    
    private func setupLayoutSection() {
        layoutSectionView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        layoutSectionView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 标题
        layoutTitleLabel.font = ThemeManager.buttonFont
        layoutTitleLabel.textColor = .white
        layoutTitleLabel.text = "选择布局"
        layoutSectionView.addSubview(layoutTitleLabel)
        
        // 分段控制器
        layoutSegmentedControl.selectedSegmentIndex = 0
        layoutSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layoutSegmentedControl.selectedSegmentTintColor = ThemeManager.buttonPrimary
        layoutSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        layoutSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        layoutSegmentedControl.addTarget(self, action: #selector(layoutChanged), for: .valueChanged)
        layoutSectionView.addSubview(layoutSegmentedControl)
    }
    
    private func setupControlPanel() {
        controlPanelView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        controlPanelView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 生成按钮
        generateButton.setTitle("🎨 生成拼图", for: .normal)
        generateButton.titleLabel?.font = ThemeManager.buttonFont
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.backgroundColor = ThemeManager.buttonPrimary
        generateButton.layer.cornerRadius = ThemeManager.buttonCornerRadius
        generateButton.addTarget(self, action: #selector(generateCollage), for: .touchUpInside)
        controlPanelView.addSubview(generateButton)
        
        // 进度条
        progressView.progressTintColor = ThemeManager.buttonPrimary
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.isHidden = true
        controlPanelView.addSubview(progressView)
        
        // 状态标签
        statusLabel.font = ThemeManager.captionFont
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        statusLabel.textAlignment = .center
        statusLabel.text = ""
        controlPanelView.addSubview(statusLabel)
    }
    
    private func setupBottomButtons() {
        bottomButtonsView.backgroundColor = .clear
        
        // 重置按钮
        resetButton.setTitle("🔄 重置", for: .normal)
        resetButton.titleLabel?.font = ThemeManager.buttonFont
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        resetButton.layer.cornerRadius = ThemeManager.buttonCornerRadius
        resetButton.addTarget(self, action: #selector(resetCollage), for: .touchUpInside)
        resetButton.isEnabled = false
        resetButton.alpha = 0.5
        bottomButtonsView.addSubview(resetButton)
        
        // 保存按钮
        saveButton.setTitle("💾 保存", for: .normal)
        saveButton.titleLabel?.font = ThemeManager.buttonFont
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonSecondary
        saveButton.layer.cornerRadius = ThemeManager.buttonCornerRadius
        saveButton.addTarget(self, action: #selector(saveCollage), for: .touchUpInside)
        saveButton.isEnabled = false
        saveButton.alpha = 0.5
        bottomButtonsView.addSubview(saveButton)
        
        // 分享按钮
        shareButton.setTitle("📤 分享", for: .normal)
        shareButton.titleLabel?.font = ThemeManager.buttonFont
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.backgroundColor = ThemeManager.buttonPrimary
        shareButton.layer.cornerRadius = ThemeManager.buttonCornerRadius
        shareButton.addTarget(self, action: #selector(shareCollage), for: .touchUpInside)
        shareButton.isEnabled = false
        shareButton.alpha = 0.5
        bottomButtonsView.addSubview(shareButton)
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainerView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        layoutSectionView.translatesAutoresizingMaskIntoConstraints = false
        layoutTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        layoutSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        controlPanelView.translatesAutoresizingMaskIntoConstraints = false
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonsView.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 头部区域
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 40),
            
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            countLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 预览区域
            previewContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            previewContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewContainerView.heightAnchor.constraint(equalToConstant: 200),
            
            previewImageView.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 16),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 16),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -16),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -16),
            
            previewPlaceholder.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),
            previewPlaceholder.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
            previewPlaceholder.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 16),
            previewPlaceholder.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -16),
            
            // 布局选择区域
            layoutSectionView.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: 20),
            layoutSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            layoutSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            layoutSectionView.heightAnchor.constraint(equalToConstant: 100),
            
            layoutTitleLabel.topAnchor.constraint(equalTo: layoutSectionView.topAnchor, constant: 16),
            layoutTitleLabel.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor, constant: 16),
            layoutTitleLabel.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor, constant: -16),
            layoutTitleLabel.heightAnchor.constraint(equalToConstant: 24),
            
            layoutSegmentedControl.topAnchor.constraint(equalTo: layoutTitleLabel.bottomAnchor, constant: 12),
            layoutSegmentedControl.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor, constant: 16),
            layoutSegmentedControl.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor, constant: -16),
            layoutSegmentedControl.heightAnchor.constraint(equalToConstant: 36),
            
            // 控制面板
            controlPanelView.topAnchor.constraint(equalTo: layoutSectionView.bottomAnchor, constant: 20),
            controlPanelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            controlPanelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            controlPanelView.heightAnchor.constraint(equalToConstant: 120),
            
            generateButton.topAnchor.constraint(equalTo: controlPanelView.topAnchor, constant: 16),
            generateButton.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            generateButton.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            generateButton.heightAnchor.constraint(equalToConstant: 48),
            
            progressView.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            statusLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 底部按钮
            bottomButtonsView.topAnchor.constraint(equalTo: controlPanelView.bottomAnchor, constant: 20),
            bottomButtonsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bottomButtonsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bottomButtonsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            bottomButtonsView.heightAnchor.constraint(equalToConstant: 48),
            
            resetButton.leadingAnchor.constraint(equalTo: bottomButtonsView.leadingAnchor),
            resetButton.centerYAnchor.constraint(equalTo: bottomButtonsView.centerYAnchor),
            resetButton.widthAnchor.constraint(equalTo: bottomButtonsView.widthAnchor, multiplier: 0.25),
            resetButton.heightAnchor.constraint(equalToConstant: 48),
            
            saveButton.centerXAnchor.constraint(equalTo: bottomButtonsView.centerXAnchor),
            saveButton.centerYAnchor.constraint(equalTo: bottomButtonsView.centerYAnchor),
            saveButton.widthAnchor.constraint(equalTo: bottomButtonsView.widthAnchor, multiplier: 0.35),
            saveButton.heightAnchor.constraint(equalToConstant: 48),
            
            shareButton.trailingAnchor.constraint(equalTo: bottomButtonsView.trailingAnchor),
            shareButton.centerYAnchor.constraint(equalTo: bottomButtonsView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalTo: bottomButtonsView.widthAnchor, multiplier: 0.35),
            shareButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func configureNavigationBar() {
        title = "创建拼图"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func layoutChanged() {
        HapticFeedbackManager.shared.buttonTap()
        
        switch layoutSegmentedControl.selectedSegmentIndex {
        case 0:
            selectedLayout = .grid
        case 1:
            selectedLayout = .horizontal
        case 2:
            selectedLayout = .vertical
        default:
            selectedLayout = .grid
        }
        
        updatePreview()
    }
    
    @objc private func generateCollage() {
        HapticFeedbackManager.shared.buttonTap()
        
        // 显示生成进度
        showGeneratingProgress()
        
        // 异步生成拼图
        DispatchQueue.global(qos: .userInitiated).async {
            let generatedImage = self.createCollageImage(with: self.selectedLayout)
            
            DispatchQueue.main.async {
                self.hideGeneratingProgress()
                
                if let image = generatedImage {
                    self.collageImage = image
                    self.previewImageView.image = image
                    self.previewPlaceholder.isHidden = true
                    self.enableBottomButtons(true)
                    self.statusLabel.text = "拼图生成完成"
                    HapticFeedbackManager.shared.notificationSuccess()
                } else {
                    self.statusLabel.text = "生成失败，请重试"
                    HapticFeedbackManager.shared.notificationError()
                }
            }
        }
    }
    
    @objc private func resetCollage() {
        HapticFeedbackManager.shared.buttonTap()
        
        collageImage = nil
        previewImageView.image = nil
        previewPlaceholder.isHidden = false
        previewPlaceholder.text = "选择布局后生成预览"
        enableBottomButtons(false)
        statusLabel.text = ""
        layoutSegmentedControl.selectedSegmentIndex = 0
        selectedLayout = .grid
    }
    
    @objc private func saveCollage() {
        guard let image = collageImage else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func shareCollage() {
        guard let image = collageImage else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    // MARK: - Helper Methods
    private func updatePreview() {
        statusLabel.text = "点击生成按钮创建拼图"
    }
    
    private func showGeneratingProgress() {
        generateButton.isEnabled = false
        generateButton.alpha = 0.5
        progressView.isHidden = false
        progressView.progress = 0.0
        statusLabel.text = "正在生成拼图..."
        
        // 模拟进度条动画
        UIView.animate(withDuration: 2.0) {
            self.progressView.progress = 1.0
        }
    }
    
    private func hideGeneratingProgress() {
        generateButton.isEnabled = true
        generateButton.alpha = 1.0
        progressView.isHidden = true
        progressView.progress = 0.0
    }
    
    private func enableBottomButtons(_ enabled: Bool) {
        resetButton.isEnabled = enabled
        saveButton.isEnabled = enabled
        shareButton.isEnabled = enabled
        
        resetButton.alpha = enabled ? 1.0 : 0.5
        saveButton.alpha = enabled ? 1.0 : 0.5
        shareButton.alpha = enabled ? 1.0 : 0.5
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            HapticFeedbackManager.shared.notificationError()
            showAlert(title: "保存失败", message: error.localizedDescription)
        } else {
            HapticFeedbackManager.shared.notificationSuccess()
            showAlert(title: "拼图保存成功", message: "拼图已保存到相册")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Collage Generation
extension CollageViewController {
    
    private func createCollageImage(with layout: CollageLayout) -> UIImage? {
        switch layout {
        case .grid:
            return createGridCollage()
        case .horizontal:
            return createHorizontalCollage()
        case .vertical:
            return createVerticalCollage()
        }
    }
    
    private func createGridCollage() -> UIImage? {
        let imageCount = images.count
        let gridSize = calculateGridSize(for: imageCount)
        let collageSize = CGSize(width: 800, height: 800)
        
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let cellWidth = collageSize.width / CGFloat(gridSize.cols)
            let cellHeight = collageSize.height / CGFloat(gridSize.rows)
            let spacing: CGFloat = 4
            
            for (index, image) in images.enumerated() {
                let row = index / gridSize.cols
                let col = index % gridSize.cols
                
                let x = CGFloat(col) * cellWidth + spacing
                let y = CGFloat(row) * cellHeight + spacing
                let width = cellWidth - spacing * 2
                let height = cellHeight - spacing * 2
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image.draw(in: rect)
            }
        }
    }
    
    private func createHorizontalCollage() -> UIImage? {
        let imageCount = images.count
        let collageSize = CGSize(width: 800 * imageCount, height: 800)
        
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let imageWidth = collageSize.width / CGFloat(images.count)
            let spacing: CGFloat = 4
            
            for (index, image) in images.enumerated() {
                let x = CGFloat(index) * imageWidth + spacing
                let y: CGFloat = spacing
                let width = imageWidth - spacing * 2
                let height = collageSize.height - spacing * 2
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image.draw(in: rect)
            }
        }
    }
    
    private func createVerticalCollage() -> UIImage? {
        let imageCount = images.count
        let collageSize = CGSize(width: 800, height: 800 * imageCount)
        
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let imageHeight = collageSize.height / CGFloat(images.count)
            let spacing: CGFloat = 4
            
            for (index, image) in images.enumerated() {
                let x: CGFloat = spacing
                let y = CGFloat(index) * imageHeight + spacing
                let width = collageSize.width - spacing * 2
                let height = imageHeight - spacing * 2
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image.draw(in: rect)
            }
        }
    }
    
    private func calculateGridSize(for count: Int) -> (rows: Int, cols: Int) {
        switch count {
        case 2: return (1, 2)
        case 3: return (2, 2) // 3张图片用2x2网格，空一个位置
        case 4: return (2, 2)
        case 5, 6: return (2, 3)
        case 7, 8, 9: return (3, 3)
        default: return (2, 2)
        }
    }
}

// MARK: - CollageLayout Enum
enum CollageLayout {
    case grid
    case horizontal
    case vertical
}
