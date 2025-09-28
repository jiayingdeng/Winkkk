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
    
    // 动态约束引用
    private var previewHeightConstraint: NSLayoutConstraint!
    
    // 布局选择区域
    private let layoutSectionView = UIView()
    private let layoutTitleLabel = UILabel()
    private let templateCollectionView: UICollectionView
    private let templateFlowLayout = UICollectionViewFlowLayout()
    
    // 比例选择区域
    private let aspectRatioSectionView = UIView()
    private let aspectRatioTitleLabel = UILabel()
    private let aspectRatioCollectionView: UICollectionView
    private let aspectRatioFlowLayout = UICollectionViewFlowLayout()
    
    // 状态标签（移到头部区域）
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
    private let enhanceButton = UIButton() // 新增画质修复按钮
    
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 当视图布局改变时（比如屏幕旋转），更新预览框高度
        if view.bounds.width > 0 && previewHeightConstraint != nil {
            updatePreviewContainerHeight(animated: false)
        }
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
        
        // 底部按钮
        setupBottomButtons()
        
        // 添加到内容视图
        contentView.addSubview(headerView)
        contentView.addSubview(previewContainerView)
        contentView.addSubview(layoutSectionView)
        contentView.addSubview(aspectRatioSectionView)
        contentView.addSubview(editingSectionView)
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
        
        // 状态标签（移到头部区域）
        statusLabel.font = ThemeManager.captionFont
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        statusLabel.textAlignment = .center
        statusLabel.text = ""
        headerView.addSubview(statusLabel)
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
        previewPlaceholder.text = "选择布局后自动生成拼图"
        previewPlaceholder.numberOfLines = 0
        previewContainerView.addSubview(previewPlaceholder)
    }
    
    private func setupLayoutSection() {
        layoutSectionView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        layoutSectionView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 标题
        layoutTitleLabel.font = ThemeManager.buttonFont
        layoutTitleLabel.textColor = .white
        layoutTitleLabel.text = "选择布局模板"
        layoutSectionView.addSubview(layoutTitleLabel)
        
        
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
    
    
    private func setupBottomButtons() {
        bottomButtonsView.backgroundColor = .clear
        
        // 重置按钮
        resetButton.setTitle("🔄 重置", for: .normal)
        resetButton.titleLabel?.font = ThemeManager.buttonFont
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        resetButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        resetButton.addTarget(self, action: #selector(resetCollage), for: .touchUpInside)
        resetButton.isEnabled = true  // 重置按钮始终可用
        resetButton.alpha = 1.0
        bottomButtonsView.addSubview(resetButton)
        
        // 保存按钮
        saveButton.setTitle("💾 保存", for: .normal)
        saveButton.titleLabel?.font = ThemeManager.buttonFont
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = ThemeManager.buttonSecondary
        saveButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        saveButton.addTarget(self, action: #selector(saveCollage), for: .touchUpInside)
        saveButton.isEnabled = false  // 初始禁用，拼图生成后启用
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
        
        // 画质修复按钮
        enhanceButton.setTitle("🎨 画质修复", for: .normal)
        enhanceButton.titleLabel?.font = ThemeManager.buttonFont
        enhanceButton.setTitleColor(.white, for: .normal)
        enhanceButton.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.8)
        enhanceButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        enhanceButton.addTarget(self, action: #selector(enhanceCollageTapped), for: .touchUpInside)
        enhanceButton.isEnabled = false
        enhanceButton.alpha = 0.5
        bottomButtonsView.addSubview(enhanceButton)
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
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonsView.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        enhanceButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 40),
            
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            countLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            countLabel.heightAnchor.constraint(equalToConstant: 20),
            
            statusLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            statusLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // 预览区域 - 使用动态高度
            previewContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            previewContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            previewImageView.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 16),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 16),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -16),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -16),
            
            previewPlaceholder.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),
            previewPlaceholder.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
            previewPlaceholder.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 16),
            previewPlaceholder.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -16),
            
            // 布局选择区域 - 优化高度
            layoutSectionView.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: 16),
            layoutSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            layoutSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            layoutSectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
            
            layoutTitleLabel.topAnchor.constraint(equalTo: layoutSectionView.topAnchor, constant: 16),
            layoutTitleLabel.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor, constant: 16),
            layoutTitleLabel.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor, constant: -16),
            layoutTitleLabel.heightAnchor.constraint(equalToConstant: 24),
            
            templateCollectionView.topAnchor.constraint(equalTo: layoutTitleLabel.bottomAnchor, constant: 12),
            templateCollectionView.leadingAnchor.constraint(equalTo: layoutSectionView.leadingAnchor, constant: 16),
            templateCollectionView.trailingAnchor.constraint(equalTo: layoutSectionView.trailingAnchor, constant: -16),
            templateCollectionView.heightAnchor.constraint(equalToConstant: 80),
            templateCollectionView.bottomAnchor.constraint(lessThanOrEqualTo: layoutSectionView.bottomAnchor, constant: -16),
            
            // 比例选择区域 - 优化高度
            aspectRatioSectionView.topAnchor.constraint(equalTo: layoutSectionView.bottomAnchor, constant: 16),
            aspectRatioSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            aspectRatioSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            aspectRatioSectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            
            aspectRatioTitleLabel.topAnchor.constraint(equalTo: aspectRatioSectionView.topAnchor, constant: 16),
            aspectRatioTitleLabel.leadingAnchor.constraint(equalTo: aspectRatioSectionView.leadingAnchor, constant: 16),
            aspectRatioTitleLabel.trailingAnchor.constraint(equalTo: aspectRatioSectionView.trailingAnchor, constant: -16),
            aspectRatioTitleLabel.heightAnchor.constraint(equalToConstant: 24),
            
            aspectRatioCollectionView.topAnchor.constraint(equalTo: aspectRatioTitleLabel.bottomAnchor, constant: 8),
            aspectRatioCollectionView.leadingAnchor.constraint(equalTo: aspectRatioSectionView.leadingAnchor, constant: 16),
            aspectRatioCollectionView.trailingAnchor.constraint(equalTo: aspectRatioSectionView.trailingAnchor, constant: -16),
            aspectRatioCollectionView.heightAnchor.constraint(equalToConstant: 50),
            aspectRatioCollectionView.bottomAnchor.constraint(lessThanOrEqualTo: aspectRatioSectionView.bottomAnchor, constant: -8),
            
            // 图片编辑区域 - 优化高度
            editingSectionView.topAnchor.constraint(equalTo: aspectRatioSectionView.bottomAnchor, constant: 16),
            editingSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            editingSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            editingSectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            
            editingTitleLabel.topAnchor.constraint(equalTo: editingSectionView.topAnchor, constant: 16),
            editingTitleLabel.leadingAnchor.constraint(equalTo: editingSectionView.leadingAnchor, constant: 16),
            editingTitleLabel.trailingAnchor.constraint(equalTo: editingSectionView.trailingAnchor, constant: -16),
            editingTitleLabel.heightAnchor.constraint(equalToConstant: 24),
            
            imageSelectionCollectionView.topAnchor.constraint(equalTo: editingTitleLabel.bottomAnchor, constant: 8),
            imageSelectionCollectionView.leadingAnchor.constraint(equalTo: editingSectionView.leadingAnchor, constant: 16),
            imageSelectionCollectionView.trailingAnchor.constraint(equalTo: editingSectionView.trailingAnchor, constant: -16),
            imageSelectionCollectionView.heightAnchor.constraint(equalToConstant: 70),
            
            editingControlsView.topAnchor.constraint(equalTo: imageSelectionCollectionView.bottomAnchor, constant: 8),
            editingControlsView.leadingAnchor.constraint(equalTo: editingSectionView.leadingAnchor, constant: 16),
            editingControlsView.trailingAnchor.constraint(equalTo: editingSectionView.trailingAnchor, constant: -16),
            editingControlsView.heightAnchor.constraint(equalToConstant: 36),
            editingControlsView.bottomAnchor.constraint(lessThanOrEqualTo: editingSectionView.bottomAnchor, constant: -16),
            
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
            
            // 底部按钮 - 直接连接编辑区域
            bottomButtonsView.topAnchor.constraint(equalTo: editingSectionView.bottomAnchor, constant: 24),
            bottomButtonsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bottomButtonsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bottomButtonsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            bottomButtonsView.heightAnchor.constraint(equalToConstant: 52),
            
            resetButton.leadingAnchor.constraint(equalTo: bottomButtonsView.leadingAnchor),
            resetButton.centerYAnchor.constraint(equalTo: bottomButtonsView.centerYAnchor),
            resetButton.widthAnchor.constraint(equalTo: bottomButtonsView.widthAnchor, multiplier: 0.2),
            resetButton.heightAnchor.constraint(equalToConstant: 52),
            
            saveButton.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor, constant: 8),
            saveButton.centerYAnchor.constraint(equalTo: bottomButtonsView.centerYAnchor),
            saveButton.widthAnchor.constraint(equalTo: bottomButtonsView.widthAnchor, multiplier: 0.25),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            
            shareButton.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 8),
            shareButton.centerYAnchor.constraint(equalTo: bottomButtonsView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalTo: bottomButtonsView.widthAnchor, multiplier: 0.25),
            shareButton.heightAnchor.constraint(equalToConstant: 52),
            
            enhanceButton.leadingAnchor.constraint(equalTo: shareButton.trailingAnchor, constant: 8),
            enhanceButton.trailingAnchor.constraint(equalTo: bottomButtonsView.trailingAnchor),
            enhanceButton.centerYAnchor.constraint(equalTo: bottomButtonsView.centerYAnchor),
            enhanceButton.heightAnchor.constraint(equalToConstant: 52)
        ])
        
        // 设置初始预览框高度约束
        updatePreviewContainerHeight(animated: false)
    }
    
    // MARK: - Preview Container Height Management
    private func updatePreviewContainerHeight(animated: Bool = true) {
        // 移除现有的高度约束（如果存在）
        if previewHeightConstraint != nil {
            previewHeightConstraint.isActive = false
        }
        
        // 计算新的高度
        let containerWidth = view.bounds.width - 32 // 左右各16的边距
        let targetSize = calculatePreviewSize(containerWidth: containerWidth)
        
        // 创建新的高度约束
        previewHeightConstraint = previewContainerView.heightAnchor.constraint(equalToConstant: targetSize.height)
        previewHeightConstraint.isActive = true
        
        // 执行布局更新
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
                self.view.layoutIfNeeded()
            })
        } else {
            view.layoutIfNeeded()
        }
    }
    
    private func calculatePreviewSize(containerWidth: CGFloat) -> CGSize {
        let contentWidth = containerWidth - 32 // 内部左右各16的边距
        let aspectRatio = getAspectRatioValue()
        
        let targetHeight: CGFloat
        if aspectRatio > 1.0 {
            // 横向比例，宽度优先
            targetHeight = contentWidth / aspectRatio + 32 // 加上内部上下边距
        } else {
            // 纵向或正方形比例，适当提高最大高度限制
            let maxHeight = containerWidth * 1.2 // 提高最大高度限制，让预览更清晰
            targetHeight = min(contentWidth / aspectRatio + 32, maxHeight)
        }
        
        return CGSize(width: containerWidth, height: max(350, targetHeight)) // 提高最小高度到350
    }
    
    private func getAspectRatioValue() -> CGFloat {
        switch selectedAspectRatio {
        case .square1_1:
            return 1.0
        case .portrait3_4:
            return 3.0/4.0
        case .landscape4_3:
            return 4.0/3.0
        case .widescreen16_9:
            return 16.0/9.0
        case .full:
            return view.bounds.width / view.bounds.height
        }
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
    
    
    
    @objc private func resetCollage() {
        HapticFeedbackManager.shared.buttonTap()
        
        collageImage = nil
        previewImageView.image = nil
        previewPlaceholder.isHidden = false
        previewPlaceholder.text = "选择布局后自动生成拼图"
        enableBottomButtons(false)
        statusLabel.text = ""
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
        
        statusLabel.text = "图片编辑已重置，拼图已更新"
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
    
    @objc private func enhanceCollageTapped() {
        guard let collageImage = collageImage else {
            showAlert(title: "提示", message: "请先生成拼图")
            return
        }
        
        HapticFeedbackManager.shared.buttonTap()
        
        // 跳转到画质修复页面，传入拼图结果
        let imageEnhanceVC = ImageEnhanceViewController(
            image: collageImage,
            timestamp: Date().timeIntervalSince1970
        )
        
        navigationController?.pushViewController(imageEnhanceVC, animated: true)
    }
    
    // MARK: - Helper Methods
    private func updatePreview() {
        // 自动生成预览拼图
        DispatchQueue.global(qos: .userInitiated).async {
            // 使用高质量的固定尺寸生成拼图，确保最终输出质量
            let generatedImage = self.createCollageImageWithTemplate(size: self.calculateCollageSize())
            
            DispatchQueue.main.async {
                if let image = generatedImage {
                    self.collageImage = image
                    self.previewImageView.image = image
                    self.previewPlaceholder.isHidden = true
                    self.enableBottomButtons(true)
                    self.statusLabel.text = "拼图已生成，可以保存或分享"
                    HapticFeedbackManager.shared.lightImpact()
                } else {
                    self.previewPlaceholder.isHidden = false
                    self.previewPlaceholder.text = "拼图生成失败"
                    self.statusLabel.text = "拼图生成失败，请重试"
                }
            }
        }
    }
    
    private func calculateCollageSize() -> CGSize {
        // 使用更高的基础尺寸，确保输出质量
        let baseSize: CGFloat = 1200
        
        switch selectedAspectRatio {
        case .square1_1:
            return CGSize(width: baseSize, height: baseSize)
        case .portrait3_4:
            return CGSize(width: baseSize * 3/4, height: baseSize)
        case .landscape4_3:
            return CGSize(width: baseSize * 4/3, height: baseSize)
        case .widescreen16_9:
            return CGSize(width: baseSize * 16/9, height: baseSize)
        case .full:
            return UIScreen.main.bounds.size
        }
    }
    
    
    private func enableBottomButtons(_ enabled: Bool) {
        // 重置按钮始终可用
        resetButton.isEnabled = true
        resetButton.alpha = 1.0
        
        // 其他按钮根据拼图生成状态调整
        saveButton.isEnabled = enabled
        shareButton.isEnabled = enabled
        enhanceButton.isEnabled = enabled
        
        saveButton.alpha = enabled ? 1.0 : 0.5
        shareButton.alpha = enabled ? 1.0 : 0.5
        enhanceButton.alpha = enabled ? 1.0 : 0.5
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
    
    private func createCollageImage() -> UIImage? {
        let collageSize = calculateCollageSize()
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
                // 更新预览框高度（布局模板变化可能影响最佳显示尺寸）
                updatePreviewContainerHeight(animated: true)
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
                // 更新预览框高度
                updatePreviewContainerHeight(animated: true)
                // 更新预览内容
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
