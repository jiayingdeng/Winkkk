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
    private let originalImages: [UIImage]
    private var imageItems: [CollageImageItem]
    private var collageImage: UIImage?
    private var selectedImageIndex: Int? // 当前选中的图片索引
    private var selectedLayout: CollageLayout = .grid
    private var selectedAspectRatio: AspectRatio = .square1_1
    private var selectedLayoutTemplate: CollageLayoutTemplate = GridLayoutTemplate()
    private let availableTemplates: [CollageLayoutTemplate] = [
        GridLayoutTemplate(),
        HorizontalLayoutTemplate(),
        VerticalLayoutTemplate(),
        MosaicLayoutTemplate()
    ]
    
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
    private let templateTitleLabel = UILabel()
    private let templateCollectionView: UICollectionView
    private let templateFlowLayout = UICollectionViewFlowLayout()
    
    // 比例选择区域
    private let aspectRatioSectionView = UIView()
    private let aspectRatioTitleLabel = UILabel()
    private let aspectRatioCollectionView: UICollectionView
    private let aspectRatioFlowLayout = UICollectionViewFlowLayout()
    
    // 控制面板
    private let controlPanelView = UIView()
    private let generateButton = UIButton()
    private let progressView = UIProgressView()
    private let statusLabel = UILabel()
    
    // 图片编辑区域
    private let editingSectionView = UIView()
    private let editingTitleLabel = UILabel()
    private let imageSelectionCollectionView: UICollectionView
    private let imageSelectionFlowLayout = UICollectionViewFlowLayout()
    private let editingControlsView = UIView()
    private let rotateLeftButton = UIButton()
    private let rotateRightButton = UIButton()
    private let flipHorizontalButton = UIButton()
    private let flipVerticalButton = UIButton()
    private let resetEditingButton = UIButton()
    
    // 底部按钮
    private let bottomButtonsView = UIView()
    private let saveButton = UIButton()
    private let shareButton = UIButton()
    private let resetButton = UIButton()
    
    // MARK: - Initialization
    init(images: [UIImage]) {
        self.originalImages = images
        self.imageItems = images.map { CollageImageItem(image: $0) }
        
        // 初始化 aspectRatio collection view
        aspectRatioFlowLayout.scrollDirection = .horizontal
        aspectRatioFlowLayout.minimumLineSpacing = 12
        aspectRatioFlowLayout.minimumInteritemSpacing = 8
        aspectRatioFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        aspectRatioCollectionView = UICollectionView(frame: .zero, collectionViewLayout: aspectRatioFlowLayout)
        
        // 初始化 template collection view
        templateFlowLayout.scrollDirection = .horizontal
        templateFlowLayout.minimumLineSpacing = 12
        templateFlowLayout.minimumInteritemSpacing = 8
        templateFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        templateCollectionView = UICollectionView(frame: .zero, collectionViewLayout: templateFlowLayout)
        
        // 初始化 image selection collection view
        imageSelectionFlowLayout.scrollDirection = .horizontal
        imageSelectionFlowLayout.minimumLineSpacing = 8
        imageSelectionFlowLayout.minimumInteritemSpacing = 8
        imageSelectionFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        imageSelectionCollectionView = UICollectionView(frame: .zero, collectionViewLayout: imageSelectionFlowLayout)
        
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
        
        // 比例选择区域
        setupAspectRatioSection()
        
        // 图片编辑区域
        setupEditingSection()
        
        // 控制面板
        setupControlPanel()
        
        // 底部按钮
        setupBottomButtons()
        
        // 添加到内容视图
        contentView.addSubview(headerView)
        contentView.addSubview(previewContainerView)
        contentView.addSubview(layoutSectionView)
        contentView.addSubview(aspectRatioSectionView)
        contentView.addSubview(editingSectionView)
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
        countLabel.text = "已选择 \(imageItems.count) 张图片"
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
        
        // 模板选择标题
        templateTitleLabel.font = ThemeManager.captionFont
        templateTitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        templateTitleLabel.text = "布局模板"
        layoutSectionView.addSubview(templateTitleLabel)
        
        // 模板选择集合视图
        templateCollectionView.backgroundColor = .clear
        templateCollectionView.showsHorizontalScrollIndicator = false
        templateCollectionView.delegate = self
        templateCollectionView.dataSource = self
        templateCollectionView.register(LayoutTemplateCollectionViewCell.self, forCellWithReuseIdentifier: "TemplateCell")
        layoutSectionView.addSubview(templateCollectionView)
    }
    
    private func setupAspectRatioSection() {
        aspectRatioSectionView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        aspectRatioSectionView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 标题
        aspectRatioTitleLabel.font = ThemeManager.buttonFont
        aspectRatioTitleLabel.textColor = .white
        aspectRatioTitleLabel.text = "选择比例"
        aspectRatioSectionView.addSubview(aspectRatioTitleLabel)
        
        // 比例选择集合视图
        aspectRatioCollectionView.backgroundColor = .clear
        aspectRatioCollectionView.showsHorizontalScrollIndicator = false
        aspectRatioCollectionView.delegate = self
        aspectRatioCollectionView.dataSource = self
        aspectRatioCollectionView.register(AspectRatioCollectionViewCell.self, forCellWithReuseIdentifier: "AspectRatioCell")
        aspectRatioSectionView.addSubview(aspectRatioCollectionView)
    }
    
    private func setupEditingSection() {
        editingSectionView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        editingSectionView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 标题
        editingTitleLabel.font = ThemeManager.buttonFont
        editingTitleLabel.textColor = .white
        editingTitleLabel.text = "编辑图片"
        editingSectionView.addSubview(editingTitleLabel)
        
        // 图片选择集合视图
        imageSelectionCollectionView.backgroundColor = .clear
        imageSelectionCollectionView.showsHorizontalScrollIndicator = false
        imageSelectionCollectionView.delegate = self
        imageSelectionCollectionView.dataSource = self
        imageSelectionCollectionView.register(EditingImageCollectionViewCell.self, forCellWithReuseIdentifier: "EditingImageCell")
        editingSectionView.addSubview(imageSelectionCollectionView)
        
        // 编辑控制按钮容器
        editingControlsView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        editingControlsView.layer.cornerRadius = 8
        editingSectionView.addSubview(editingControlsView)
        
        // 配置编辑按钮
        setupEditingButtons()
    }
    
    private func setupEditingButtons() {
        // 左旋转按钮
        rotateLeftButton.setTitle("↶", for: .normal)
        rotateLeftButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        rotateLeftButton.setTitleColor(.white, for: .normal)
        rotateLeftButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        rotateLeftButton.layer.cornerRadius = 6
        rotateLeftButton.addTarget(self, action: #selector(rotateLeftTapped), for: .touchUpInside)
        editingControlsView.addSubview(rotateLeftButton)
        
        // 右旋转按钮
        rotateRightButton.setTitle("↷", for: .normal)
        rotateRightButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        rotateRightButton.setTitleColor(.white, for: .normal)
        rotateRightButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        rotateRightButton.layer.cornerRadius = 6
        rotateRightButton.addTarget(self, action: #selector(rotateRightTapped), for: .touchUpInside)
        editingControlsView.addSubview(rotateRightButton)
        
        // 水平镜像按钮
        flipHorizontalButton.setTitle("↔", for: .normal)
        flipHorizontalButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        flipHorizontalButton.setTitleColor(.white, for: .normal)
        flipHorizontalButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        flipHorizontalButton.layer.cornerRadius = 6
        flipHorizontalButton.addTarget(self, action: #selector(flipHorizontalTapped), for: .touchUpInside)
        editingControlsView.addSubview(flipHorizontalButton)
        
        // 垂直镜像按钮
        flipVerticalButton.setTitle("↕", for: .normal)
        flipVerticalButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        flipVerticalButton.setTitleColor(.white, for: .normal)
        flipVerticalButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        flipVerticalButton.layer.cornerRadius = 6
        flipVerticalButton.addTarget(self, action: #selector(flipVerticalTapped), for: .touchUpInside)
        editingControlsView.addSubview(flipVerticalButton)
        
        // 重置编辑按钮
        resetEditingButton.setTitle("重置", for: .normal)
        resetEditingButton.titleLabel?.font = ThemeManager.captionFont
        resetEditingButton.setTitleColor(.white, for: .normal)
        resetEditingButton.backgroundColor = UIColor.red.withAlphaComponent(0.7)
        resetEditingButton.layer.cornerRadius = 6
        resetEditingButton.addTarget(self, action: #selector(resetEditingTapped), for: .touchUpInside)
        editingControlsView.addSubview(resetEditingButton)
        
        // 默认禁用编辑按钮
        updateEditingButtonsState()
    }
    
    private func setupControlPanel() {
        controlPanelView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        controlPanelView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 生成按钮
        generateButton.setTitle("🎨 生成拼图", for: .normal)
        generateButton.titleLabel?.font = ThemeManager.buttonFont
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.backgroundColor = ThemeManager.buttonPrimary
        generateButton.layer.cornerRadius = ThemeManager.standardCornerRadius
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
        resetButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        resetButton.addTarget(self, action: #selector(resetCollage), for: .touchUpInside)
        resetButton.isEnabled = false
        resetButton.alpha = 0.5
        bottomButtonsView.addSubview(resetButton)
        
        // 保存按钮
        saveButton.setTitle("💾 保存", for: .normal)
        saveButton.titleLabel?.font = ThemeManager.buttonFont
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonSecondary
        saveButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        saveButton.addTarget(self, action: #selector(saveCollage), for: .touchUpInside)
        saveButton.isEnabled = false
        saveButton.alpha = 0.5
        bottomButtonsView.addSubview(saveButton)
        
        // 分享按钮
        shareButton.setTitle("📤 分享", for: .normal)
        shareButton.titleLabel?.font = ThemeManager.buttonFont
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.backgroundColor = ThemeManager.buttonPrimary
        shareButton.layer.cornerRadius = ThemeManager.standardCornerRadius
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
        templateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        templateCollectionView.translatesAutoresizingMaskIntoConstraints = false
        aspectRatioSectionView.translatesAutoresizingMaskIntoConstraints = false
        aspectRatioTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        aspectRatioCollectionView.translatesAutoresizingMaskIntoConstraints = false
        editingSectionView.translatesAutoresizingMaskIntoConstraints = false
        editingTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        imageSelectionCollectionView.translatesAutoresizingMaskIntoConstraints = false
        editingControlsView.translatesAutoresizingMaskIntoConstraints = false
        rotateLeftButton.translatesAutoresizingMaskIntoConstraints = false
        rotateRightButton.translatesAutoresizingMaskIntoConstraints = false
        flipHorizontalButton.translatesAutoresizingMaskIntoConstraints = false
        flipVerticalButton.translatesAutoresizingMaskIntoConstraints = false
        resetEditingButton.translatesAutoresizingMaskIntoConstraints = false
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
            layoutSectionView.heightAnchor.constraint(equalToConstant: 180),
            
            layoutTitleLabel.topAnchor.constraint(equalTo: layoutSectionView.topAnchor, constant: 16),
            layoutTitleLabel.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor, constant: 16),
            layoutTitleLabel.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor, constant: -16),
            layoutTitleLabel.heightAnchor.constraint(equalToConstant: 24),
            
            layoutSegmentedControl.topAnchor.constraint(equalTo: layoutTitleLabel.bottomAnchor, constant: 12),
            layoutSegmentedControl.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor, constant: 16),
            layoutSegmentedControl.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor, constant: -16),
            layoutSegmentedControl.heightAnchor.constraint(equalToConstant: 36),
            
            templateTitleLabel.topAnchor.constraint(equalTo: layoutSegmentedControl.bottomAnchor, constant: 16),
            templateTitleLabel.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor, constant: 16),
            templateTitleLabel.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor, constant: -16),
            templateTitleLabel.heightAnchor.constraint(equalToConstant: 20),
            
            templateCollectionView.topAnchor.constraint(equalTo: templateTitleLabel.bottomAnchor, constant: 8),
            templateCollectionView.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor),
            templateCollectionView.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor),
            templateCollectionView.heightAnchor.constraint(equalToConstant: 70),
            
            // 比例选择区域
            aspectRatioSectionView.topAnchor.constraint(equalTo: layoutSectionView.bottomAnchor, constant: 20),
            aspectRatioSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            aspectRatioSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            aspectRatioSectionView.heightAnchor.constraint(equalToConstant: 100),
            
            aspectRatioTitleLabel.topAnchor.constraint(equalTo: aspectRatioSectionView.topAnchor, constant: 16),
            aspectRatioTitleLabel.leadingAnchor.constraint(equalTo: aspectRatioSectionView.leadingAnchor, constant: 16),
            aspectRatioTitleLabel.trailingAnchor.constraint(equalTo: aspectRatioSectionView.trailingAnchor, constant: -16),
            aspectRatioTitleLabel.heightAnchor.constraint(equalToConstant: 24),
            
            aspectRatioCollectionView.topAnchor.constraint(equalTo: aspectRatioTitleLabel.bottomAnchor, constant: 12),
            aspectRatioCollectionView.leadingAnchor.constraint(equalTo: aspectRatioSectionView.leadingAnchor),
            aspectRatioCollectionView.trailingAnchor.constraint(equalTo: aspectRatioSectionView.trailingAnchor),
            aspectRatioCollectionView.bottomAnchor.constraint(equalTo: aspectRatioSectionView.bottomAnchor, constant: -8),
            
            // 图片编辑区域
            editingSectionView.topAnchor.constraint(equalTo: aspectRatioSectionView.bottomAnchor, constant: 20),
            editingSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            editingSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            editingSectionView.heightAnchor.constraint(equalToConstant: 160),
            
            editingTitleLabel.topAnchor.constraint(equalTo: editingSectionView.topAnchor, constant: 16),
            editingTitleLabel.leadingAnchor.constraint(equalTo: editingSectionView.leadingAnchor, constant: 16),
            editingTitleLabel.trailingAnchor.constraint(equalTo: editingSectionView.trailingAnchor, constant: -16),
            editingTitleLabel.heightAnchor.constraint(equalToConstant: 24),
            
            imageSelectionCollectionView.topAnchor.constraint(equalTo: editingTitleLabel.bottomAnchor, constant: 12),
            imageSelectionCollectionView.leadingAnchor.constraint(equalTo: editingSectionView.leadingAnchor),
            imageSelectionCollectionView.trailingAnchor.constraint(equalTo: editingSectionView.trailingAnchor),
            imageSelectionCollectionView.heightAnchor.constraint(equalToConstant: 70),
            
            editingControlsView.topAnchor.constraint(equalTo: imageSelectionCollectionView.bottomAnchor, constant: 8),
            editingControlsView.leadingAnchor.constraint(equalTo: editingSectionView.leadingAnchor, constant: 16),
            editingControlsView.trailingAnchor.constraint(equalTo: editingSectionView.trailingAnchor, constant: -16),
            editingControlsView.heightAnchor.constraint(equalToConstant: 36),
            
            rotateLeftButton.leadingAnchor.constraint(equalTo: editingControlsView.leadingAnchor, constant: 8),
            rotateLeftButton.centerYAnchor.constraint(equalTo: editingControlsView.centerYAnchor),
            rotateLeftButton.widthAnchor.constraint(equalToConstant: 36),
            rotateLeftButton.heightAnchor.constraint(equalToConstant: 28),
            
            rotateRightButton.leadingAnchor.constraint(equalTo: rotateLeftButton.trailingAnchor, constant: 8),
            rotateRightButton.centerYAnchor.constraint(equalTo: editingControlsView.centerYAnchor),
            rotateRightButton.widthAnchor.constraint(equalToConstant: 36),
            rotateRightButton.heightAnchor.constraint(equalToConstant: 28),
            
            flipHorizontalButton.leadingAnchor.constraint(equalTo: rotateRightButton.trailingAnchor, constant: 8),
            flipHorizontalButton.centerYAnchor.constraint(equalTo: editingControlsView.centerYAnchor),
            flipHorizontalButton.widthAnchor.constraint(equalToConstant: 36),
            flipHorizontalButton.heightAnchor.constraint(equalToConstant: 28),
            
            flipVerticalButton.leadingAnchor.constraint(equalTo: flipHorizontalButton.trailingAnchor, constant: 8),
            flipVerticalButton.centerYAnchor.constraint(equalTo: editingControlsView.centerYAnchor),
            flipVerticalButton.widthAnchor.constraint(equalToConstant: 36),
            flipVerticalButton.heightAnchor.constraint(equalToConstant: 28),
            
            resetEditingButton.trailingAnchor.constraint(equalTo: editingControlsView.trailingAnchor, constant: -8),
            resetEditingButton.centerYAnchor.constraint(equalTo: editingControlsView.centerYAnchor),
            resetEditingButton.widthAnchor.constraint(equalToConstant: 48),
            resetEditingButton.heightAnchor.constraint(equalToConstant: 28),
            
            // 控制面板
            controlPanelView.topAnchor.constraint(equalTo: editingSectionView.bottomAnchor, constant: 20),
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
        selectedAspectRatio = .square1_1
        aspectRatioCollectionView.reloadData()
    }
    
    // MARK: - Editing Actions
    
    @objc private func rotateLeftTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].rotateCounterClockwise()
        
        // 更新图片选择集合视图
        imageSelectionCollectionView.reloadItems(at: [IndexPath(item: selectedIndex, section: 0)])
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func rotateRightTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].rotateClockwise()
        
        // 更新图片选择集合视图
        imageSelectionCollectionView.reloadItems(at: [IndexPath(item: selectedIndex, section: 0)])
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func flipHorizontalTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].flipHorizontally()
        
        // 更新图片选择集合视图
        imageSelectionCollectionView.reloadItems(at: [IndexPath(item: selectedIndex, section: 0)])
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func flipVerticalTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].flipVertically()
        
        // 更新图片选择集合视图
        imageSelectionCollectionView.reloadItems(at: [IndexPath(item: selectedIndex, section: 0)])
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func resetEditingTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].resetEditing()
        
        // 更新图片选择集合视图
        imageSelectionCollectionView.reloadItems(at: [IndexPath(item: selectedIndex, section: 0)])
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
        
        statusLabel.text = "图片编辑已重置"
    }
    
    private func updateEditingButtonsState() {
        let hasSelection = selectedImageIndex != nil
        
        rotateLeftButton.isEnabled = hasSelection
        rotateRightButton.isEnabled = hasSelection
        flipHorizontalButton.isEnabled = hasSelection
        flipVerticalButton.isEnabled = hasSelection
        resetEditingButton.isEnabled = hasSelection
        
        let alpha: CGFloat = hasSelection ? 1.0 : 0.5
        rotateLeftButton.alpha = alpha
        rotateRightButton.alpha = alpha
        flipHorizontalButton.alpha = alpha
        flipVerticalButton.alpha = alpha
        resetEditingButton.alpha = alpha
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
        let collageSize = selectedAspectRatio.size
        return createCollageImageWithTemplate(size: collageSize)
    }
    
    private func createCollageImageWithTemplate(size collageSize: CGSize) -> UIImage? {
        if !selectedLayoutTemplate.isSupported(for: imageItems.count) {
            // 如果当前模板不支持图片数量，回退到网格布局
            selectedLayoutTemplate = GridLayoutTemplate()
        }
        
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let bounds = CGRect(origin: .zero, size: collageSize)
            let frames = selectedLayoutTemplate.calculateFrames(for: imageItems.count, in: bounds)
            
            for (index, imageItem) in imageItems.enumerated() {
                let image = imageItem.processedImage
                if index < frames.count {
                    let frame = frames[index]
                    
                    // 计算图片的绘制区域，保持宽高比并居中裁剪
                    let imageAspectRatio = image.size.width / image.size.height
                    let frameAspectRatio = frame.width / frame.height
                    
                    var drawRect = frame
                    if imageAspectRatio > frameAspectRatio {
                        // 图片更宽，需要裁剪宽度
                        let newWidth = frame.height * imageAspectRatio
                        drawRect = CGRect(x: frame.midX - newWidth/2, y: frame.minY, width: newWidth, height: frame.height)
                    } else {
                        // 图片更高，需要裁剪高度
                        let newHeight = frame.width / imageAspectRatio
                        drawRect = CGRect(x: frame.minX, y: frame.midY - newHeight/2, width: frame.width, height: newHeight)
                    }
                    
                    // 绘制图片
                    image.draw(in: drawRect)
                }
            }
        }
    }
    
    private func createGridCollage(size collageSize: CGSize) -> UIImage? {
        let imageCount = imageItems.count
        let gridSize = calculateGridSize(for: imageCount)
        
        let renderer = UIGraphicsImageRenderer(size: collageSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: collageSize))
            
            let cellWidth = collageSize.width / CGFloat(gridSize.cols)
            let cellHeight = collageSize.height / CGFloat(gridSize.rows)
            let spacing: CGFloat = 4
            
            for (index, imageItem) in imageItems.enumerated() {
                let image = imageItem.processedImage
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
    
    private func createHorizontalCollage(size collageSize: CGSize) -> UIImage? {
        let imageCount = imageItems.count
        // 对于横向拼图，可能需要调整宽度以适应所有图片
        let adjustedSize = CGSize(width: max(collageSize.width, collageSize.height), height: collageSize.height)
        
        let renderer = UIGraphicsImageRenderer(size: adjustedSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: adjustedSize))
            
            let imageWidth = adjustedSize.width / CGFloat(imageItems.count)
            let spacing: CGFloat = 4
            
            for (index, imageItem) in imageItems.enumerated() {
                let image = imageItem.processedImage
                let x = CGFloat(index) * imageWidth + spacing
                let y: CGFloat = spacing
                let width = imageWidth - spacing * 2
                let height = adjustedSize.height - spacing * 2
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image.draw(in: rect)
            }
        }
    }
    
    private func createVerticalCollage(size collageSize: CGSize) -> UIImage? {
        let imageCount = imageItems.count
        // 对于竖向拼图，可能需要调整高度以适应所有图片
        let adjustedSize = CGSize(width: collageSize.width, height: max(collageSize.height, collageSize.width))
        
        let renderer = UIGraphicsImageRenderer(size: adjustedSize)
        
        return renderer.image { context in
            // 设置白色背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: adjustedSize))
            
            let imageHeight = adjustedSize.height / CGFloat(imageItems.count)
            let spacing: CGFloat = 4
            
            for (index, imageItem) in imageItems.enumerated() {
                let image = imageItem.processedImage
                let x: CGFloat = spacing
                let y = CGFloat(index) * imageHeight + spacing
                let width = adjustedSize.width - spacing * 2
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

// MARK: - CollageLayoutTemplate Protocol
protocol CollageLayoutTemplate {
    var templateName: String { get }
    var templateIcon: String { get } // emoji icon
    func calculateFrames(for imageCount: Int, in bounds: CGRect) -> [CGRect]
    func isSupported(for imageCount: Int) -> Bool
}

// MARK: - Layout Template Implementations
class GridLayoutTemplate: CollageLayoutTemplate {
    let templateName = "网格布局"
    let templateIcon = "⚏"
    
    func calculateFrames(for imageCount: Int, in bounds: CGRect) -> [CGRect] {
        let gridSize = calculateGridSize(for: imageCount)
        let cellWidth = bounds.width / CGFloat(gridSize.cols)
        let cellHeight = bounds.height / CGFloat(gridSize.rows)
        let spacing: CGFloat = 4
        
        var frames: [CGRect] = []
        for index in 0..<imageCount {
            let row = index / gridSize.cols
            let col = index % gridSize.cols
            
            let x = CGFloat(col) * cellWidth + spacing
            let y = CGFloat(row) * cellHeight + spacing
            let width = cellWidth - spacing * 2
            let height = cellHeight - spacing * 2
            
            frames.append(CGRect(x: x, y: y, width: width, height: height))
        }
        return frames
    }
    
    func isSupported(for imageCount: Int) -> Bool {
        return imageCount >= 2 && imageCount <= 9
    }
    
    private func calculateGridSize(for count: Int) -> (rows: Int, cols: Int) {
        switch count {
        case 2: return (1, 2)
        case 3: return (2, 2)
        case 4: return (2, 2)
        case 5, 6: return (2, 3)
        case 7, 8, 9: return (3, 3)
        default: return (2, 2)
        }
    }
}

class HorizontalLayoutTemplate: CollageLayoutTemplate {
    let templateName = "横向布局"
    let templateIcon = "⚌"
    
    func calculateFrames(for imageCount: Int, in bounds: CGRect) -> [CGRect] {
        let imageWidth = bounds.width / CGFloat(imageCount)
        let spacing: CGFloat = 4
        
        var frames: [CGRect] = []
        for index in 0..<imageCount {
            let x = CGFloat(index) * imageWidth + spacing
            let y: CGFloat = spacing
            let width = imageWidth - spacing * 2
            let height = bounds.height - spacing * 2
            
            frames.append(CGRect(x: x, y: y, width: width, height: height))
        }
        return frames
    }
    
    func isSupported(for imageCount: Int) -> Bool {
        return imageCount >= 2 && imageCount <= 6
    }
}

class VerticalLayoutTemplate: CollageLayoutTemplate {
    let templateName = "竖向布局"
    let templateIcon = "⚍"
    
    func calculateFrames(for imageCount: Int, in bounds: CGRect) -> [CGRect] {
        let imageHeight = bounds.height / CGFloat(imageCount)
        let spacing: CGFloat = 4
        
        var frames: [CGRect] = []
        for index in 0..<imageCount {
            let x: CGFloat = spacing
            let y = CGFloat(index) * imageHeight + spacing
            let width = bounds.width - spacing * 2
            let height = imageHeight - spacing * 2
            
            frames.append(CGRect(x: x, y: y, width: width, height: height))
        }
        return frames
    }
    
    func isSupported(for imageCount: Int) -> Bool {
        return imageCount >= 2 && imageCount <= 6
    }
}

class MosaicLayoutTemplate: CollageLayoutTemplate {
    let templateName = "马赛克布局"
    let templateIcon = "⊞"
    
    func calculateFrames(for imageCount: Int, in bounds: CGRect) -> [CGRect] {
        var frames: [CGRect] = []
        let spacing: CGFloat = 4
        
        switch imageCount {
        case 2:
            // 一大一小，大图占左侧2/3
            let mainWidth = bounds.width * 2/3 - spacing
            let sideWidth = bounds.width * 1/3 - spacing * 2
            frames.append(CGRect(x: spacing, y: spacing, width: mainWidth, height: bounds.height - spacing * 2))
            frames.append(CGRect(x: mainWidth + spacing * 2, y: spacing, width: sideWidth, height: bounds.height - spacing * 2))
            
        case 3:
            // 大图占左侧，右侧两个小图上下排列
            let mainWidth = bounds.width * 2/3 - spacing
            let sideWidth = bounds.width * 1/3 - spacing * 2
            let sideHeight = (bounds.height - spacing * 3) / 2
            
            frames.append(CGRect(x: spacing, y: spacing, width: mainWidth, height: bounds.height - spacing * 2))
            frames.append(CGRect(x: mainWidth + spacing * 2, y: spacing, width: sideWidth, height: sideHeight))
            frames.append(CGRect(x: mainWidth + spacing * 2, y: sideHeight + spacing * 2, width: sideWidth, height: sideHeight))
            
        case 4:
            // 2x2网格，但第一张图占据左上角双倍大小
            let halfWidth = (bounds.width - spacing * 3) / 2
            let halfHeight = (bounds.height - spacing * 3) / 2
            
            frames.append(CGRect(x: spacing, y: spacing, width: halfWidth, height: halfHeight))
            frames.append(CGRect(x: halfWidth + spacing * 2, y: spacing, width: halfWidth, height: halfHeight))
            frames.append(CGRect(x: spacing, y: halfHeight + spacing * 2, width: halfWidth, height: halfHeight))
            frames.append(CGRect(x: halfWidth + spacing * 2, y: halfHeight + spacing * 2, width: halfWidth, height: halfHeight))
            
        default:
            // 回退到网格布局
            return GridLayoutTemplate().calculateFrames(for: imageCount, in: bounds)
        }
        
        return frames
    }
    
    func isSupported(for imageCount: Int) -> Bool {
        return imageCount >= 2 && imageCount <= 4
    }
}

// MARK: - CollageImageItem Data Model
class CollageImageItem {
    let originalImage: UIImage
    private var _processedImage: UIImage?
    
    // 编辑状态
    var rotationAngle: CGFloat = 0.0 // 旋转角度（度）
    var isFlippedHorizontally: Bool = false // 水平镜像
    var isFlippedVertically: Bool = false // 垂直镜像
    var scale: CGFloat = 1.0 // 缩放比例
    var translation: CGPoint = .zero // 平移偏移
    
    // 计算后的图片
    var processedImage: UIImage {
        if _processedImage == nil || needsUpdate {
            _processedImage = generateProcessedImage()
            needsUpdate = false
        }
        return _processedImage ?? originalImage
    }
    
    private var needsUpdate: Bool = true
    
    init(image: UIImage) {
        self.originalImage = image
    }
    
    // MARK: - Editing Methods
    
    /// 顺时针旋转90度
    func rotateClockwise() {
        rotationAngle += 90
        if rotationAngle >= 360 {
            rotationAngle -= 360
        }
        markNeedsUpdate()
    }
    
    /// 逆时针旋转90度
    func rotateCounterClockwise() {
        rotationAngle -= 90
        if rotationAngle < 0 {
            rotationAngle += 360
        }
        markNeedsUpdate()
    }
    
    /// 水平镜像
    func flipHorizontally() {
        isFlippedHorizontally.toggle()
        markNeedsUpdate()
    }
    
    /// 垂直镜像
    func flipVertically() {
        isFlippedVertically.toggle()
        markNeedsUpdate()
    }
    
    /// 重置所有编辑
    func resetEditing() {
        rotationAngle = 0.0
        isFlippedHorizontally = false
        isFlippedVertically = false
        scale = 1.0
        translation = .zero
        markNeedsUpdate()
    }
    
    private func markNeedsUpdate() {
        needsUpdate = true
        _processedImage = nil
    }
    
    private func generateProcessedImage() -> UIImage {
        let size = originalImage.size
        let bounds = CGRect(origin: .zero, size: size)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 移动到图片中心
            cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            
            // 应用镜像变换
            var scaleX: CGFloat = isFlippedHorizontally ? -1 : 1
            var scaleY: CGFloat = isFlippedVertically ? -1 : 1
            
            // 应用缩放
            scaleX *= scale
            scaleY *= scale
            cgContext.scaleBy(x: scaleX, y: scaleY)
            
            // 应用旋转
            let radians = rotationAngle * .pi / 180
            cgContext.rotate(by: radians)
            
            // 应用平移
            cgContext.translateBy(x: translation.x, y: translation.y)
            
            // 绘制图片（从中心点开始）
            let drawRect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            originalImage.draw(in: drawRect)
        }
    }
}

// MARK: - EditingImageCollectionViewCell
class EditingImageCollectionViewCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let selectionOverlay = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = 8
        layer.borderWidth = 2
        layer.borderColor = UIColor.clear.cgColor
        clipsToBounds = true
        
        // 图片视图
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        
        // 选中状态遮罩
        selectionOverlay.backgroundColor = ThemeManager.buttonPrimary.withAlphaComponent(0.3)
        selectionOverlay.isHidden = true
        addSubview(selectionOverlay)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView.frame = bounds
        selectionOverlay.frame = bounds
    }
    
    func configure(with imageItem: CollageImageItem, isSelected: Bool) {
        imageView.image = imageItem.processedImage
        
        if isSelected {
            layer.borderColor = ThemeManager.buttonPrimary.cgColor
            selectionOverlay.isHidden = false
        } else {
            layer.borderColor = UIColor.clear.cgColor
            selectionOverlay.isHidden = true
        }
    }
}

// MARK: - LayoutTemplateCollectionViewCell
class LayoutTemplateCollectionViewCell: UICollectionViewCell {
    
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = 8
        layer.borderWidth = 2
        layer.borderColor = UIColor.clear.cgColor
        
        // 图标标签
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.textAlignment = .center
        addSubview(iconLabel)
        
        // 名称标签
        nameLabel.font = ThemeManager.captionFont
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        addSubview(nameLabel)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        iconLabel.frame = CGRect(x: 8, y: 8, width: bounds.width - 16, height: 30)
        nameLabel.frame = CGRect(x: 4, y: bounds.height - 32, width: bounds.width - 8, height: 28)
    }
    
    func configure(with template: CollageLayoutTemplate, isSelected: Bool, isSupported: Bool) {
        iconLabel.text = template.templateIcon
        nameLabel.text = template.templateName
        
        if isSelected {
            layer.borderColor = ThemeManager.buttonPrimary.cgColor
            backgroundColor = ThemeManager.buttonPrimary.withAlphaComponent(0.2)
        } else {
            layer.borderColor = UIColor.clear.cgColor
            backgroundColor = UIColor.white.withAlphaComponent(0.1)
        }
        
        alpha = isSupported ? 1.0 : 0.5
        iconLabel.alpha = isSupported ? 1.0 : 0.6
        nameLabel.alpha = isSupported ? 1.0 : 0.6
    }
}

// MARK: - AspectRatio Enum
enum AspectRatio: CaseIterable {
    case portrait3_4    // 3:4 (竖屏)
    case square1_1      // 1:1 (正方形)
    case landscape4_3   // 4:3 (横屏)
    case widescreen16_9 // 16:9 (宽屏)
    case full          // 自适应屏幕

    var displayName: String {
        switch self {
        case .portrait3_4: return "3:4"
        case .square1_1: return "1:1"
        case .landscape4_3: return "4:3"
        case .widescreen16_9: return "16:9"
        case .full: return "FULL"
        }
    }
    
    var emoji: String {
        switch self {
        case .portrait3_4: return "📱"
        case .square1_1: return "⬜"
        case .landscape4_3: return "📺"
        case .widescreen16_9: return "🖥️"
        case .full: return "📱"
        }
    }
    
    var size: CGSize {
        let baseHeight: CGFloat = 800
        switch self {
        case .portrait3_4: return CGSize(width: baseHeight * 3/4, height: baseHeight)
        case .square1_1: return CGSize(width: baseHeight, height: baseHeight)
        case .landscape4_3: return CGSize(width: baseHeight * 4/3, height: baseHeight)
        case .widescreen16_9: return CGSize(width: baseHeight * 16/9, height: baseHeight)
        case .full: return UIScreen.main.bounds.size
        }
    }
}

// MARK: - AspectRatioCollectionViewCell
class AspectRatioCollectionViewCell: UICollectionViewCell {
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.clear.cgColor
        
        // 图标标签
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.textAlignment = .center
        iconLabel.textColor = .white
        addSubview(iconLabel)
        
        // 名称标签
        nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.textColor = .white
        addSubview(nameLabel)
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconLabel.heightAnchor.constraint(equalToConstant: 30),
            
            nameLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
    
    func configure(with aspectRatio: AspectRatio, isSelected: Bool) {
        iconLabel.text = aspectRatio.emoji
        nameLabel.text = aspectRatio.displayName
        
        if isSelected {
            backgroundColor = ThemeManager.buttonPrimary.withAlphaComponent(0.8)
            layer.borderColor = ThemeManager.buttonPrimary.cgColor
        } else {
            backgroundColor = UIColor.white.withAlphaComponent(0.1)
            layer.borderColor = UIColor.clear.cgColor
        }
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate
extension CollageViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == templateCollectionView {
            return availableTemplates.count
        } else if collectionView == imageSelectionCollectionView {
            return imageItems.count
        } else {
            return AspectRatio.allCases.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == templateCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TemplateCell", for: indexPath) as! LayoutTemplateCollectionViewCell
            let template = availableTemplates[indexPath.item]
            let isSelected = type(of: template) == type(of: selectedLayoutTemplate)
            let isSupported = template.isSupported(for: imageItems.count)
            cell.configure(with: template, isSelected: isSelected, isSupported: isSupported)
            return cell
        } else if collectionView == imageSelectionCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditingImageCell", for: indexPath) as! EditingImageCollectionViewCell
            let imageItem = imageItems[indexPath.item]
            let isSelected = selectedImageIndex == indexPath.item
            cell.configure(with: imageItem, isSelected: isSelected)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AspectRatioCell", for: indexPath) as! AspectRatioCollectionViewCell
            let aspectRatio = AspectRatio.allCases[indexPath.item]
            let isSelected = aspectRatio == selectedAspectRatio
            cell.configure(with: aspectRatio, isSelected: isSelected)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == templateCollectionView {
            let template = availableTemplates[indexPath.item]
            
            // 检查模板是否支持当前图片数量
            guard template.isSupported(for: imageItems.count) else {
                HapticFeedbackManager.shared.notificationWarning()
                return
            }
            
            // 检查是否真的改变了模板
            if type(of: template) != type(of: selectedLayoutTemplate) {
                selectedLayoutTemplate = template
                HapticFeedbackManager.shared.buttonTap()
                collectionView.reloadData()
                updatePreview()
            }
        } else if collectionView == imageSelectionCollectionView {
            let previousSelectedIndex = selectedImageIndex
            selectedImageIndex = indexPath.item
            
            if previousSelectedIndex != selectedImageIndex {
                HapticFeedbackManager.shared.buttonTap()
                
                // 更新集合视图显示
                var indexPathsToReload: [IndexPath] = [indexPath]
                if let previousIndex = previousSelectedIndex {
                    indexPathsToReload.append(IndexPath(item: previousIndex, section: 0))
                }
                collectionView.reloadItems(at: indexPathsToReload)
                
                // 更新编辑按钮状态
                updateEditingButtonsState()
            }
        } else {
            let previousAspectRatio = selectedAspectRatio
            selectedAspectRatio = AspectRatio.allCases[indexPath.item]
            
            if previousAspectRatio != selectedAspectRatio {
                HapticFeedbackManager.shared.buttonTap()
                collectionView.reloadData()
                updatePreview()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == templateCollectionView {
            return CGSize(width: 80, height: 70)
        } else if collectionView == imageSelectionCollectionView {
            return CGSize(width: 70, height: 70)
        } else {
            return CGSize(width: 60, height: 60)
        }
    }
}
