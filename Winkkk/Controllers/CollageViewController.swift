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
    private var selectionBorderLayer: CAShapeLayer? // 预览框选中边框
    private let allTemplates: [CollageLayoutTemplate] = [
        GridLayoutTemplate(),
        HorizontalLayoutTemplate(),
        VerticalLayoutTemplate()
    ]
    
    // 根据当前图片数量和比例获取可用模板
    private var availableTemplates: [CollageLayoutTemplate] {
        let imageCount = imageItems.count
        return allTemplates.filter { template in
            // 奇数图片时不显示网格布局
            if template is GridLayoutTemplate && imageCount % 2 != 0 {
                return false
            }
            
            // 根据比例过滤布局模板
            if !isTemplateCompatibleWithAspectRatio(template, aspectRatio: selectedAspectRatio) {
                return false
            }
            
            return template.isSupported(for: imageCount)
        }
    }
    
    // 检查模板是否与比例兼容
    private func isTemplateCompatibleWithAspectRatio(_ template: CollageLayoutTemplate, aspectRatio: AspectRatio) -> Bool {
        switch aspectRatio {
        case .portrait3_4:
            // 竖屏比例：适合竖向布局和网格布局
            return template is VerticalLayoutTemplate || template is GridLayoutTemplate
        case .landscape4_3, .widescreen16_9:
            // 横屏比例：适合横向布局和网格布局
            return template is HorizontalLayoutTemplate || template is GridLayoutTemplate
        case .square1_1:
            // 正方形：所有布局都适合
            return true
        case .full:
            // 全屏：所有布局都适合
            return true
        }
    }
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 头部区域
    private let headerView = UIView()
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
    
    // 长按提示文字
    private let longPressHintLabel = UILabel()
    
    // 轻量级浮动工具栏（选中图片时显示）
    private let lightEditToolbar = UIView()
    private let toolbarRotateLeftButton = UIButton(type: .system)
    private let toolbarRotateRightButton = UIButton(type: .system)
    private let toolbarFlipHButton = UIButton(type: .system)
    private let toolbarFlipVButton = UIButton(type: .system)
    private let toolbarResetButton = UIButton(type: .system)
    private let toolbarHintLabel = UILabel()
    
    // 底部按钮
    private let bottomButtonsView = UIView()
    
    // 第一行按钮
    private let firstRowButtonsView = UIView()
    private let saveButton = UIButton()
    private let shareButton = UIButton()
    private let resetButton = UIButton()
    
    // 第二行按钮
    private let secondRowButtonsView = UIView()
    private let backToProcessingButton = UIButton() // 返回截图中心按钮
    private let enhanceButton = UIButton() // 画质修复按钮
    
    // MARK: - 直接编辑手势相关（🆕 简化版）
    
    // 手势识别器
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
    
    // 手势开始时的状态
    private var gestureBeginTranslation = CGPoint.zero
    
    // 首次选中图片的引导提示
    private var hasShownFirstTimeGuidance = false
    private var gestureBeginScale: CGFloat = 1.0
    private var gestureBeginRotation: CGFloat = 0.0
    
    // 🆕 实时手势预览图层（即时视觉反馈）
    private var gesturePreviewImageView: UIImageView?
    private var gesturePreviewInitialFrame: CGRect = .zero
    
    // 手势累积状态（支持多手势同时）
    private var currentGestureTranslation = CGPoint.zero
    private var currentGestureScale: CGFloat = 1.0
    private var currentGestureRotation: CGFloat = 0
    
    // 手势节流相关
    private var gestureUpdateTimer: Timer?
    private var needsGestureUpdate = false
    
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
        
        // 给预览框添加点击手势识别
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCollageImageTap(_:)))
        previewImageView.isUserInteractionEnabled = true
        previewImageView.addGestureRecognizer(tapGesture)
        
        // 添加长按手势识别器
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleCollageImageLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5  // 0.5秒触发长按
        previewImageView.addGestureRecognizer(longPressGesture)
        
        // 🆕 添加双击手势进入编辑模式
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePreviewDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        previewImageView.addGestureRecognizer(doubleTapGesture)
        
        // 设置手势优先级：双击优先于单击
        tapGesture.require(toFail: doubleTapGesture)
        
        // 🎨 添加直接编辑手势（拖动、缩放、旋转）
        setupDirectEditGestures()
        
        // 确保选择的模板可用
        validateSelectedTemplate()
        
        updatePreview()
        
        // 进入拼图页面的触感反馈
        HapticFeedbackManager.shared.lightImpact()
        
        // 监听主题切换通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: .themeDidChange,
            object: nil
        )
    }
    
    deinit {
        // 移除主题切换通知监听
        NotificationCenter.default.removeObserver(self, name: .themeDidChange, object: nil)
    }
    
    // MARK: - Theme Change Handler
    
    /// 处理主题切换
    @objc private func handleThemeChange() {
        // 更新头部区域颜色
        countLabel.textColor = ThemeManager.primaryText
        statusLabel.textColor = ThemeManager.secondaryText
        
        // 更新预览区域颜色
        previewContainerView.backgroundColor = ThemeManager.backgroundSecondary
        previewImageView.backgroundColor = ThemeManager.cardBackground
        previewPlaceholder.textColor = ThemeManager.secondaryText
        longPressHintLabel.textColor = ThemeManager.placeholderText
        
        // 更新布局和比例选择区域颜色
        layoutSectionView.backgroundColor = ThemeManager.cardBackground
        layoutTitleLabel.textColor = ThemeManager.primaryText
        aspectRatioSectionView.backgroundColor = ThemeManager.cardBackground
        aspectRatioTitleLabel.textColor = ThemeManager.primaryText
        
        // 更新轻量级工具栏颜色
        lightEditToolbar.backgroundColor = ThemeManager.toolbarBackground
        toolbarHintLabel.textColor = ThemeManager.warning
        
        // 更新工具栏按钮颜色
        let toolbarButtons = [toolbarRotateLeftButton, toolbarRotateRightButton, 
                              toolbarFlipHButton, toolbarFlipVButton, toolbarResetButton]
        for button in toolbarButtons {
            button.tintColor = ThemeManager.buttonTextOnPrimary
            button.backgroundColor = ThemeManager.backgroundSecondary.withAlphaComponent(0.7)
        }
        
        // 更新底部按钮颜色
        backToProcessingButton.setTitleColor(ThemeManager.buttonTextOnPrimary, for: .normal)
        backToProcessingButton.backgroundColor = ThemeManager.buttonPrimary
        
        enhanceButton.setTitleColor(ThemeManager.primaryText, for: .normal)
        enhanceButton.backgroundColor = ThemeManager.buttonSecondary
        
        // 更新其他按钮颜色
        saveButton.setTitleColor(ThemeManager.buttonTextOnPrimary, for: .normal)
        saveButton.backgroundColor = ThemeManager.success
        
        shareButton.setTitleColor(ThemeManager.buttonTextOnPrimary, for: .normal)
        shareButton.backgroundColor = ThemeManager.buttonPrimary
        
        resetButton.setTitleColor(ThemeManager.primaryText, for: .normal)
        resetButton.backgroundColor = ThemeManager.buttonSecondary
        
        print("✅ CollageViewController: 主题已更新")
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
        
        // 比例选择区域
        setupAspectRatioSection()
        
        // 布局选择区域
        setupLayoutSection()
        
        // 底部按钮
        setupBottomButtons()
        
        // 轻量级浮动工具栏
        setupLightEditToolbar()
        
        // 添加到内容视图
        contentView.addSubview(headerView)
        contentView.addSubview(previewContainerView)
        contentView.addSubview(aspectRatioSectionView)
        contentView.addSubview(layoutSectionView)
        contentView.addSubview(bottomButtonsView)
        contentView.addSubview(lightEditToolbar) // 工具栏在最上层
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // 数量标签 - 使用主题文字色，确保清晰可见
        countLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        countLabel.textColor = ThemeManager.primaryText
        countLabel.textAlignment = .center
        countLabel.text = "已选择 \(imageItems.count) 张图片"
        // 添加阴影增强可读性
        countLabel.layer.shadowColor = UIColor.black.cgColor
        countLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        countLabel.layer.shadowOpacity = 0.5
        countLabel.layer.shadowRadius = 2
        headerView.addSubview(countLabel)
        
        // 状态标签（移到头部区域）- 使用主题次要文字色
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = ThemeManager.secondaryText
        statusLabel.textAlignment = .center
        statusLabel.text = ""
        // 添加阴影增强可读性
        statusLabel.layer.shadowColor = UIColor.black.cgColor
        statusLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        statusLabel.layer.shadowOpacity = 0.3
        statusLabel.layer.shadowRadius = 1
        headerView.addSubview(statusLabel)
    }
    
    private func setupPreviewArea() {
        previewContainerView.backgroundColor = ThemeManager.backgroundSecondary
        previewContainerView.layer.cornerRadius = ThemeManager.standardCornerRadius
        previewContainerView.clipsToBounds = true
        
        // 预览图片
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true
        previewImageView.layer.cornerRadius = 8
        previewImageView.backgroundColor = ThemeManager.cardBackground
        previewContainerView.addSubview(previewImageView)
        
        // 占位文字 - 使用主题文字颜色
        previewPlaceholder.font = ThemeManager.captionFont
        previewPlaceholder.textColor = ThemeManager.secondaryText
        previewPlaceholder.textAlignment = .center
        previewPlaceholder.text = "选择布局后自动生成拼图"
        previewPlaceholder.numberOfLines = 0
        previewContainerView.addSubview(previewPlaceholder)
        
        // 长按提示文字 - 使用主题占位符颜色
        longPressHintLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        longPressHintLabel.textColor = ThemeManager.placeholderText
        longPressHintLabel.textAlignment = .center
        longPressHintLabel.text = "💡 长按选中图片，直接拖动/缩放/旋转"
        longPressHintLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainerView.addSubview(longPressHintLabel)
        
        // 长按提示文字约束
        NSLayoutConstraint.activate([
            longPressHintLabel.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -8),
            longPressHintLabel.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor)
        ])
    }
    
    // MARK: - 直接编辑手势设置
    private func setupDirectEditGestures() {
        // 拖动手势
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDirectPan(_:)))
        panGesture.delegate = self
        previewImageView.addGestureRecognizer(panGesture)
        
        // 缩放手势
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleDirectPinch(_:)))
        pinchGesture.delegate = self
        previewImageView.addGestureRecognizer(pinchGesture)
        
        // 旋转手势
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleDirectRotation(_:)))
        rotationGesture.delegate = self
        previewImageView.addGestureRecognizer(rotationGesture)
        
        print("✅ 直接编辑手势已添加到previewImageView")
    }
    
    private func setupLayoutSection() {
        layoutSectionView.backgroundColor = ThemeManager.cardBackground
        layoutSectionView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 标题 - 使用主题文字颜色
        layoutTitleLabel.font = ThemeManager.buttonFont
        layoutTitleLabel.textColor = ThemeManager.primaryText
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
        aspectRatioSectionView.backgroundColor = ThemeManager.backgroundSecondary
        aspectRatioSectionView.layer.cornerRadius = ThemeManager.standardCornerRadius
        
        // 标题 - 使用主题文字颜色
        aspectRatioTitleLabel.font = ThemeManager.buttonFont
        aspectRatioTitleLabel.textColor = ThemeManager.primaryText
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
    
    private func setupBottomButtons() {
        bottomButtonsView.backgroundColor = .clear
        
        // 设置第一行按钮容器
        setupFirstRowButtons()
        
        // 设置第二行按钮容器
        setupSecondRowButtons()
        
        // 添加容器到主视图
        bottomButtonsView.addSubview(firstRowButtonsView)
        bottomButtonsView.addSubview(secondRowButtonsView)
    }
    
    private func setupFirstRowButtons() {
        firstRowButtonsView.backgroundColor = .clear
        
        // 保存按钮 - 使用主题色确保清晰可见
        saveButton.setTitle("💾 保存", for: .normal)
        saveButton.titleLabel?.font = ThemeManager.buttonFont
        saveButton.setTitleColor(ThemeManager.buttonTextOnPrimary, for: .normal)
        saveButton.backgroundColor = ThemeManager.success
        saveButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        saveButton.addTarget(self, action: #selector(saveCollage), for: .touchUpInside)
        saveButton.isEnabled = false  // 初始禁用，拼图生成后启用
        saveButton.alpha = 0.5
        firstRowButtonsView.addSubview(saveButton)
        
        // 分享按钮 - 使用主题色确保清晰可见
        shareButton.setTitle("📤 分享", for: .normal)
        shareButton.titleLabel?.font = ThemeManager.buttonFont
        shareButton.setTitleColor(ThemeManager.buttonTextOnPrimary, for: .normal)
        shareButton.backgroundColor = ThemeManager.buttonPrimary
        shareButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        shareButton.addTarget(self, action: #selector(shareCollage), for: .touchUpInside)
        shareButton.isEnabled = false
        shareButton.alpha = 0.5
        firstRowButtonsView.addSubview(shareButton)
        
        // 重置按钮 - 使用主题色确保清晰可见
        resetButton.setTitle("🔄 重置", for: .normal)
        resetButton.titleLabel?.font = ThemeManager.buttonFont
        resetButton.setTitleColor(ThemeManager.primaryText, for: .normal)
        resetButton.backgroundColor = ThemeManager.buttonSecondary
        resetButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        resetButton.addTarget(self, action: #selector(resetCollage), for: .touchUpInside)
        resetButton.isEnabled = true  // 重置按钮始终可用
        resetButton.alpha = 1.0
        firstRowButtonsView.addSubview(resetButton)
    }
    
    private func setupSecondRowButtons() {
        secondRowButtonsView.backgroundColor = .clear
        
        // 返回截图中心按钮 - 使用主题色
        backToProcessingButton.setTitle("📷 返回截图中心", for: .normal)
        backToProcessingButton.titleLabel?.font = ThemeManager.buttonFont
        backToProcessingButton.setTitleColor(ThemeManager.buttonTextOnPrimary, for: .normal)
        backToProcessingButton.backgroundColor = ThemeManager.buttonPrimary
        backToProcessingButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        backToProcessingButton.addTarget(self, action: #selector(backToProcessingTapped), for: .touchUpInside)
        backToProcessingButton.isEnabled = true  // 始终可用
        backToProcessingButton.alpha = 1.0
        secondRowButtonsView.addSubview(backToProcessingButton)
        
        // 画质修复按钮 - 使用主题色
        enhanceButton.setTitle("🎨 画质修复", for: .normal)
        enhanceButton.titleLabel?.font = ThemeManager.buttonFont
        enhanceButton.setTitleColor(ThemeManager.primaryText, for: .normal)
        enhanceButton.backgroundColor = ThemeManager.buttonSecondary
        enhanceButton.layer.cornerRadius = ThemeManager.standardCornerRadius
        enhanceButton.addTarget(self, action: #selector(enhanceCollageTapped), for: .touchUpInside)
        enhanceButton.isEnabled = false
        enhanceButton.alpha = 0.5
        secondRowButtonsView.addSubview(enhanceButton)
    }
    
    private func setupLightEditToolbar() {
        // 工具栏容器样式 - 使用主题按钮主色并增加不透明度确保可见性
        lightEditToolbar.backgroundColor = ThemeManager.toolbarBackground
        lightEditToolbar.layer.cornerRadius = 20
        lightEditToolbar.layer.shadowColor = UIColor.black.cgColor
        lightEditToolbar.layer.shadowOffset = CGSize(width: 0, height: 4)
        lightEditToolbar.layer.shadowOpacity = 0.3
        lightEditToolbar.layer.shadowRadius = 8
        lightEditToolbar.isHidden = true // 默认隐藏
        lightEditToolbar.alpha = 0
        
        // 手势提示标签 - 增强视觉效果，使用主题文字色
        toolbarHintLabel.text = "💡 试试：拖动调整位置 • 双指缩放/旋转"
        toolbarHintLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        toolbarHintLabel.textColor = ThemeManager.warning // 使用主题警告色（黄/橙色系）
        toolbarHintLabel.textAlignment = .center
        toolbarHintLabel.numberOfLines = 1
        toolbarHintLabel.adjustsFontSizeToFitWidth = true
        toolbarHintLabel.minimumScaleFactor = 0.8
        lightEditToolbar.addSubview(toolbarHintLabel)
        
        // 按钮样式配置
        let buttons = [
            (toolbarRotateLeftButton, "rotate.left", "左转"),
            (toolbarRotateRightButton, "rotate.right", "右转"),
            (toolbarFlipHButton, "arrow.left.and.right", "水平翻转"),
            (toolbarFlipVButton, "arrow.up.and.down", "垂直翻转"),
            (toolbarResetButton, "arrow.counterclockwise", "还原")
        ]
        
        for (button, iconName, _) in buttons {
            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
                button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            }
            button.tintColor = ThemeManager.buttonTextOnPrimary
            button.backgroundColor = ThemeManager.toolbarButtonBackground
            button.layer.cornerRadius = 22
            button.clipsToBounds = true
            lightEditToolbar.addSubview(button)
        }
        
        // 绑定按钮事件
        toolbarRotateLeftButton.addTarget(self, action: #selector(toolbarRotateLeftTapped), for: .touchUpInside)
        toolbarRotateRightButton.addTarget(self, action: #selector(toolbarRotateRightTapped), for: .touchUpInside)
        toolbarFlipHButton.addTarget(self, action: #selector(toolbarFlipHTapped), for: .touchUpInside)
        toolbarFlipVButton.addTarget(self, action: #selector(toolbarFlipVTapped), for: .touchUpInside)
        toolbarResetButton.addTarget(self, action: #selector(toolbarResetTapped), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
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
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonsView.translatesAutoresizingMaskIntoConstraints = false
        
        // 第一行按钮
        firstRowButtonsView.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 第二行按钮
        secondRowButtonsView.translatesAutoresizingMaskIntoConstraints = false
        backToProcessingButton.translatesAutoresizingMaskIntoConstraints = false
        enhanceButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 轻量级工具栏
        lightEditToolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbarHintLabel.translatesAutoresizingMaskIntoConstraints = false
        toolbarRotateLeftButton.translatesAutoresizingMaskIntoConstraints = false
        toolbarRotateRightButton.translatesAutoresizingMaskIntoConstraints = false
        toolbarFlipHButton.translatesAutoresizingMaskIntoConstraints = false
        toolbarFlipVButton.translatesAutoresizingMaskIntoConstraints = false
        toolbarResetButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            headerView.heightAnchor.constraint(equalToConstant: 50),
            
            countLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
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
            
            // 比例选择区域 - 优化高度
            aspectRatioSectionView.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: 16),
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
            
            // 布局选择区域 - 优化高度
            layoutSectionView.topAnchor.constraint(equalTo: aspectRatioSectionView.bottomAnchor, constant: 16),
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
            
            // 底部按钮 - 直接连接布局选择区域
            bottomButtonsView.topAnchor.constraint(equalTo: layoutSectionView.bottomAnchor, constant: 24),
            bottomButtonsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bottomButtonsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bottomButtonsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            bottomButtonsView.heightAnchor.constraint(equalToConstant: 116), // 双行高度: 52 + 8 + 52 + 4
            
            // 第一行按钮容器
            firstRowButtonsView.topAnchor.constraint(equalTo: bottomButtonsView.topAnchor),
            firstRowButtonsView.leadingAnchor.constraint(equalTo: bottomButtonsView.leadingAnchor),
            firstRowButtonsView.trailingAnchor.constraint(equalTo: bottomButtonsView.trailingAnchor),
            firstRowButtonsView.heightAnchor.constraint(equalToConstant: 52),
            
            // 第一行按钮: 保存、分享、重置
            saveButton.leadingAnchor.constraint(equalTo: firstRowButtonsView.leadingAnchor),
            saveButton.centerYAnchor.constraint(equalTo: firstRowButtonsView.centerYAnchor),
            saveButton.widthAnchor.constraint(equalTo: firstRowButtonsView.widthAnchor, multiplier: 0.32),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            
            shareButton.centerXAnchor.constraint(equalTo: firstRowButtonsView.centerXAnchor),
            shareButton.centerYAnchor.constraint(equalTo: firstRowButtonsView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalTo: firstRowButtonsView.widthAnchor, multiplier: 0.32),
            shareButton.heightAnchor.constraint(equalToConstant: 52),
            
            resetButton.trailingAnchor.constraint(equalTo: firstRowButtonsView.trailingAnchor),
            resetButton.centerYAnchor.constraint(equalTo: firstRowButtonsView.centerYAnchor),
            resetButton.widthAnchor.constraint(equalTo: firstRowButtonsView.widthAnchor, multiplier: 0.32),
            resetButton.heightAnchor.constraint(equalToConstant: 52),
            
            // 第二行按钮容器
            secondRowButtonsView.topAnchor.constraint(equalTo: firstRowButtonsView.bottomAnchor, constant: 12),
            secondRowButtonsView.leadingAnchor.constraint(equalTo: bottomButtonsView.leadingAnchor),
            secondRowButtonsView.trailingAnchor.constraint(equalTo: bottomButtonsView.trailingAnchor),
            secondRowButtonsView.heightAnchor.constraint(equalToConstant: 52),
            
            // 第二行按钮: 返回截图中心、画质修复
            backToProcessingButton.leadingAnchor.constraint(equalTo: secondRowButtonsView.leadingAnchor),
            backToProcessingButton.centerYAnchor.constraint(equalTo: secondRowButtonsView.centerYAnchor),
            backToProcessingButton.widthAnchor.constraint(equalTo: secondRowButtonsView.widthAnchor, multiplier: 0.48),
            backToProcessingButton.heightAnchor.constraint(equalToConstant: 52),
            
            enhanceButton.trailingAnchor.constraint(equalTo: secondRowButtonsView.trailingAnchor),
            enhanceButton.centerYAnchor.constraint(equalTo: secondRowButtonsView.centerYAnchor),
            enhanceButton.widthAnchor.constraint(equalTo: secondRowButtonsView.widthAnchor, multiplier: 0.48),
            enhanceButton.heightAnchor.constraint(equalToConstant: 52),
            
            // 轻量级工具栏 - 固定在预览图下方
            lightEditToolbar.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: 12),
            lightEditToolbar.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            lightEditToolbar.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -32),
            lightEditToolbar.heightAnchor.constraint(equalToConstant: 100),
            
            // 工具栏内部布局 - 手势提示标签
            toolbarHintLabel.topAnchor.constraint(equalTo: lightEditToolbar.topAnchor, constant: 12),
            toolbarHintLabel.centerXAnchor.constraint(equalTo: lightEditToolbar.centerXAnchor),
            toolbarHintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: lightEditToolbar.leadingAnchor, constant: 16),
            toolbarHintLabel.trailingAnchor.constraint(lessThanOrEqualTo: lightEditToolbar.trailingAnchor, constant: -16),
            
            // 工具栏按钮（水平排列，44x44圆形）
            toolbarRotateLeftButton.topAnchor.constraint(equalTo: toolbarHintLabel.bottomAnchor, constant: 12),
            toolbarRotateLeftButton.leadingAnchor.constraint(equalTo: lightEditToolbar.leadingAnchor, constant: 16),
            toolbarRotateLeftButton.widthAnchor.constraint(equalToConstant: 44),
            toolbarRotateLeftButton.heightAnchor.constraint(equalToConstant: 44),
            
            toolbarRotateRightButton.leadingAnchor.constraint(equalTo: toolbarRotateLeftButton.trailingAnchor, constant: 12),
            toolbarRotateRightButton.centerYAnchor.constraint(equalTo: toolbarRotateLeftButton.centerYAnchor),
            toolbarRotateRightButton.widthAnchor.constraint(equalToConstant: 44),
            toolbarRotateRightButton.heightAnchor.constraint(equalToConstant: 44),
            
            toolbarFlipHButton.leadingAnchor.constraint(equalTo: toolbarRotateRightButton.trailingAnchor, constant: 12),
            toolbarFlipHButton.centerYAnchor.constraint(equalTo: toolbarRotateLeftButton.centerYAnchor),
            toolbarFlipHButton.widthAnchor.constraint(equalToConstant: 44),
            toolbarFlipHButton.heightAnchor.constraint(equalToConstant: 44),
            
            toolbarFlipVButton.leadingAnchor.constraint(equalTo: toolbarFlipHButton.trailingAnchor, constant: 12),
            toolbarFlipVButton.centerYAnchor.constraint(equalTo: toolbarRotateLeftButton.centerYAnchor),
            toolbarFlipVButton.widthAnchor.constraint(equalToConstant: 44),
            toolbarFlipVButton.heightAnchor.constraint(equalToConstant: 44),
            
            toolbarResetButton.leadingAnchor.constraint(equalTo: toolbarFlipVButton.trailingAnchor, constant: 12),
            toolbarResetButton.trailingAnchor.constraint(equalTo: lightEditToolbar.trailingAnchor, constant: -16),
            toolbarResetButton.centerYAnchor.constraint(equalTo: toolbarRotateLeftButton.centerYAnchor),
            toolbarResetButton.widthAnchor.constraint(equalToConstant: 44),
            toolbarResetButton.heightAnchor.constraint(equalToConstant: 44)
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
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
            // 延迟更新边框，确保图片已渲染
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateCollageSelectionBorder()
            }
        }
    }
    
    @objc private func rotateRightTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].rotateClockwise()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func flipHorizontalTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].flipHorizontally()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func flipVerticalTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].flipVertically()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func resetEditingTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].resetEditing()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
        
        statusLabel.text = "图片编辑已重置，拼图已更新"
    }
    
    // MARK: - Movement Actions
    
    @objc private func moveUpTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].moveUp()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func moveDownTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].moveDown()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func moveLeftTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].moveLeft()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func moveRightTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].moveRight()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    // MARK: - Scale Actions
    
    @objc private func scaleUpTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].scaleUp()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    @objc private func scaleDownTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.buttonTap()
        imageItems[selectedIndex].scaleDown()
        // 图片已更新（旧的编辑集合视图已移除）
        
        // 如果有生成的拼图，自动重新生成预览
        if collageImage != nil {
            updatePreview()
        }
    }
    
    private func updateEditingButtonsState() {
        // 旧的编辑面板已移除，此方法保留以维持兼容性
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
    
    @objc private func backToProcessingTapped() {
        HapticFeedbackManager.shared.buttonTap()
        
        // 返回到截图处理中心
        // 查找导航堆栈中的 ScreenshotProcessingViewController
        for viewController in navigationController?.viewControllers.reversed() ?? [] {
            if viewController is ScreenshotProcessingViewController {
                navigationController?.popToViewController(viewController, animated: true)
                return
            }
        }
        
        // 如果找不到截图处理中心，则返回上一级页面
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Collage Image Tap Handling
    
    @objc private func handleCollageImageTap(_ gesture: UITapGestureRecognizer) {
        // 确保有拼图生成
        guard collageImage != nil else { return }
        
        // 获取点击坐标
        let tapLocation = gesture.location(in: previewImageView)
        
        // 判断点击的是哪张图片
        if let tappedIndex = hitTestCollageImage(point: tapLocation) {
            let previousSelectedIndex = selectedImageIndex
            selectedImageIndex = tappedIndex
            
            if previousSelectedIndex != selectedImageIndex {
                HapticFeedbackManager.shared.buttonTap()
                
                // 更新编辑按钮状态
                updateEditingButtonsState()
                
                // 更新预览框选中边框
                updateCollageSelectionBorder()
                
                // 🆕 显示轻量级工具栏
                showLightEditToolbar()
                
                // 🆕 首次选中时显示引导提示
                if !hasShownFirstTimeGuidance {
                    hasShownFirstTimeGuidance = true
                    showFirstTimeGuidance()
                }
                
                // 同步更新下方小图面板的选中状态
                var indexPathsToReload: [IndexPath] = [IndexPath(item: tappedIndex, section: 0)]
                if let previousIndex = previousSelectedIndex {
                    indexPathsToReload.append(IndexPath(item: previousIndex, section: 0))
                } // imageSelectionCollectionView已移除
            }
        } else {
            // 🆕 点击空白处，取消选择并隐藏工具栏
            if selectedImageIndex != nil {
                selectedImageIndex = nil
                selectionBorderLayer?.removeFromSuperlayer()
                selectionBorderLayer = nil
                hideLightEditToolbar()
                updateEditingButtonsState()
                HapticFeedbackManager.shared.lightImpact()
            }
        }
    }
    
    // MARK: - Collage Image Long Press Handling
    
    @objc private func handleCollageImageLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 只在手势开始时触发（避免重复触发）
        guard gesture.state == .began else { return }
        
        print("✅ 长按手势触发 (.began)")
        
        // 确保有拼图生成
        guard collageImage != nil else { return }
        
        // 获取长按位置
        let longPressLocation = gesture.location(in: previewImageView)
        
        // 判断长按的是哪张图片
        if let longPressedIndex = hitTestCollageImage(point: longPressLocation) {
            print("🎯 选中图片索引: \(longPressedIndex)")
            
            // 先选中该图片（如果尚未选中）
            if selectedImageIndex != longPressedIndex {
                selectedImageIndex = longPressedIndex
                updateCollageSelectionBorder()
                updateEditingButtonsState() // imageSelectionCollectionView已移除
            }
            
            // 触觉反馈
            HapticFeedbackManager.shared.mediumImpact()
            
            // 🆕 显示轻量级工具栏
            showLightEditToolbar()
            
            print("🎨 长按进入手势编辑模式")
        }
    }
    
    /// 🆕 处理双击手势 - 进入编辑模式
    @objc private func handlePreviewDoubleTap(_ gesture: UITapGestureRecognizer) {
        print("🎨 双击手势触发")
        
        // 确保有拼图生成
        guard collageImage != nil else { return }
        
        // 获取双击位置
        let tapLocation = gesture.location(in: previewImageView)
        
        // 判断双击的是哪张图片
        if let tappedIndex = hitTestCollageImage(point: tapLocation) {
            print("🎯 双击选中图片索引: \(tappedIndex)")
            
            // 选中该图片
            selectedImageIndex = tappedIndex
            updateCollageSelectionBorder()
            updateEditingButtonsState() // imageSelectionCollectionView已移除
            
            // 触觉反馈
            HapticFeedbackManager.shared.mediumImpact()
            
            // 显示轻量级工具栏
            showLightEditToolbar()
        }
    }
    
    /// 根据点击坐标判断点击的是哪张图片
    private func hitTestCollageImage(point: CGPoint) -> Int? {
        // 获取实际图片显示区域
        let actualImageRect = getImageDisplayRect()
        
        // 判断点击是否在图片区域内
        guard actualImageRect.contains(point) else {
            return nil
        }
        
        // 转换为相对于图片区域的坐标
        let relativePoint = CGPoint(
            x: point.x - actualImageRect.origin.x,
            y: point.y - actualImageRect.origin.y
        )
        
        let imageSize = actualImageRect.size
        
        // 根据当前布局模板判断
        if selectedLayoutTemplate is HorizontalLayoutTemplate {
            // 横向布局：左右平分
            let imageCount = imageItems.count
            let sectionWidth = imageSize.width / CGFloat(imageCount)
            let index = Int(relativePoint.x / sectionWidth)
            return (index >= 0 && index < imageCount) ? index : nil
        } else if selectedLayoutTemplate is VerticalLayoutTemplate {
            // 纵向布局：上下平分
            let imageCount = imageItems.count
            let sectionHeight = imageSize.height / CGFloat(imageCount)
            let index = Int(relativePoint.y / sectionHeight)
            return (index >= 0 && index < imageCount) ? index : nil
        } else if selectedLayoutTemplate is GridLayoutTemplate {
            // 网格布局：计算行列
            let imageCount = imageItems.count
            let gridSize = calculateGridSizeForHitTest(for: imageCount)
            let cellWidth = imageSize.width / CGFloat(gridSize.cols)
            let cellHeight = imageSize.height / CGFloat(gridSize.rows)
            
            let col = Int(relativePoint.x / cellWidth)
            let row = Int(relativePoint.y / cellHeight)
            let index = row * gridSize.cols + col
            return (index >= 0 && index < imageCount) ? index : nil
        }
        
        return nil
    }
    
    private func calculateGridSizeForHitTest(for count: Int) -> (rows: Int, cols: Int) {
        switch count {
        case 2: return (1, 2)
        case 3: return (2, 2)
        case 4: return (2, 2)
        case 5, 6: return (2, 3)
        case 7, 8, 9: return (3, 3)
        default: return (2, 2)
        }
    }
    
    /// 更新预览框选中边框
    private func updateCollageSelectionBorder() {
        // 移除旧边框
        selectionBorderLayer?.removeFromSuperlayer()
        selectionBorderLayer = nil
        
        guard let selectedIndex = selectedImageIndex, collageImage != nil else { return }
        
        // 获取实际图片显示区域
        let actualImageRect = getImageDisplayRect()
        let imageSize = actualImageRect.size
        
        // 根据布局模式和选中索引，计算相对于图片区域的边框位置
        let relativeBorderRect: CGRect
        
        if selectedLayoutTemplate is HorizontalLayoutTemplate {
            // 横向布局
            let imageCount = imageItems.count
            let sectionWidth = imageSize.width / CGFloat(imageCount)
            relativeBorderRect = CGRect(x: CGFloat(selectedIndex) * sectionWidth, y: 0, width: sectionWidth, height: imageSize.height)
        } else if selectedLayoutTemplate is VerticalLayoutTemplate {
            // 纵向布局
            let imageCount = imageItems.count
            let sectionHeight = imageSize.height / CGFloat(imageCount)
            relativeBorderRect = CGRect(x: 0, y: CGFloat(selectedIndex) * sectionHeight, width: imageSize.width, height: sectionHeight)
        } else if selectedLayoutTemplate is GridLayoutTemplate {
            // 网格布局
            let imageCount = imageItems.count
            let gridSize = calculateGridSizeForHitTest(for: imageCount)
            let cellWidth = imageSize.width / CGFloat(gridSize.cols)
            let cellHeight = imageSize.height / CGFloat(gridSize.rows)
            
            let row = selectedIndex / gridSize.cols
            let col = selectedIndex % gridSize.cols
            relativeBorderRect = CGRect(x: CGFloat(col) * cellWidth, y: CGFloat(row) * cellHeight, width: cellWidth, height: cellHeight)
        } else {
            return
        }
        
        // 转换为相对于 previewImageView 的绝对坐标
        let borderRect = CGRect(
            x: actualImageRect.origin.x + relativeBorderRect.origin.x,
            y: actualImageRect.origin.y + relativeBorderRect.origin.y,
            width: relativeBorderRect.width,
            height: relativeBorderRect.height
        )
        
        // 创建并添加边框层
        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(rect: borderRect).cgPath
        borderLayer.strokeColor = UIColor.systemBlue.cgColor
        borderLayer.lineWidth = 4
        borderLayer.fillColor = UIColor.clear.cgColor
        previewImageView.layer.addSublayer(borderLayer)
        selectionBorderLayer = borderLayer
    }
    
    // MARK: - Helper Methods
    
    /// 计算图片在 UIImageView 中的实际显示区域（scaleAspectFit 模式）
    private func getImageDisplayRect() -> CGRect {
        guard let image = previewImageView.image else {
            return previewImageView.bounds
        }
        
        let imageSize = image.size
        let viewSize = previewImageView.bounds.size
        
        // 防止除零错误
        guard imageSize.width > 0 && imageSize.height > 0 && viewSize.width > 0 && viewSize.height > 0 else {
            return previewImageView.bounds
        }
        
        // 计算宽高比
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displayRect = CGRect.zero
        
        if imageAspect > viewAspect {
            // 图片更宽，以宽度为准
            let displayWidth = viewSize.width
            let displayHeight = displayWidth / imageAspect
            let y = (viewSize.height - displayHeight) / 2
            displayRect = CGRect(x: 0, y: y, width: displayWidth, height: displayHeight)
        } else {
            // 图片更高或相等，以高度为准
            let displayHeight = viewSize.height
            let displayWidth = displayHeight * imageAspect
            let x = (viewSize.width - displayWidth) / 2
            displayRect = CGRect(x: x, y: 0, width: displayWidth, height: displayHeight)
        }
        
        return displayRect
    }
    
    private func validateSelectedTemplate() {
        // 检查当前选择的模板是否在可用模板中
        let currentTemplateType = type(of: selectedLayoutTemplate)
        let isCurrentTemplateAvailable = availableTemplates.contains { template in
            type(of: template) == currentTemplateType
        }
        
        // 如果当前模板不可用，选择第一个可用的模板
        if !isCurrentTemplateAvailable && !availableTemplates.isEmpty {
            selectedLayoutTemplate = availableTemplates[0]
        }
    }
    
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
                    
                    // 延迟更新选中边框，确保图片已渲染
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.updateCollageSelectionBorder()
                    }
                } else {
                    self.previewPlaceholder.isHidden = false
                    self.previewPlaceholder.text = "拼图生成失败"
                    self.statusLabel.text = "拼图生成失败，请重试"
                }
            }
        }
    }
    
    /// 实时重新生成拼图（用于手势编辑）
    private func regenerateCollageIfNeeded() {
        // 确保有选中的模板
        guard collageImage != nil else { return }
        
        // 异步生成，避免阻塞 UI
        DispatchQueue.global(qos: .userInitiated).async {
            let generatedImage = self.createCollageImageWithTemplate(size: self.calculateCollageSize())
            
            DispatchQueue.main.async {
                if let image = generatedImage {
                    self.collageImage = image
                    self.previewImageView.image = image
                    
                    // 延迟更新选中边框
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.updateCollageSelectionBorder()
                    }
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
        // 第一行按钮状态
        saveButton.isEnabled = enabled
        shareButton.isEnabled = enabled
        resetButton.isEnabled = true  // 重置按钮始终可用
        
        saveButton.alpha = enabled ? 1.0 : 0.5
        shareButton.alpha = enabled ? 1.0 : 0.5
        resetButton.alpha = 1.0
        
        // 第二行按钮状态
        backToProcessingButton.isEnabled = true  // 返回按钮始终可用
        enhanceButton.isEnabled = enabled
        
        backToProcessingButton.alpha = 1.0
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
                    
                    // 保存图形上下文状态
                    context.cgContext.saveGState()
                    
                    // 裁剪到frame区域
                    context.cgContext.clip(to: frame)
                    
                    // 计算图片的绘制区域，保持宽高比并居中裁剪（AspectFill）
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
                    
                    // 恢复图形上下文状态
                    context.cgContext.restoreGState()
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
    
    /// 向上移动
    func moveUp(_ distance: CGFloat = 10.0) {
        translation.y -= distance
        // 边界检查
        translation.y = max(translation.y, -100.0)
        markNeedsUpdate()
    }
    
    /// 向下移动
    func moveDown(_ distance: CGFloat = 10.0) {
        translation.y += distance
        // 边界检查
        translation.y = min(translation.y, 100.0)
        markNeedsUpdate()
    }
    
    /// 向左移动
    func moveLeft(_ distance: CGFloat = 10.0) {
        translation.x -= distance
        // 边界检查
        translation.x = max(translation.x, -100.0)
        markNeedsUpdate()
    }
    
    /// 向右移动
    func moveRight(_ distance: CGFloat = 10.0) {
        translation.x += distance
        // 边界检查
        translation.x = min(translation.x, 100.0)
        markNeedsUpdate()
    }
    
    /// 放大
    func scaleUp(_ factor: CGFloat = 0.1) {
        scale += factor
        // 边界检查
        scale = min(scale, 3.0)
        markNeedsUpdate()
    }
    
    /// 缩小
    func scaleDown(_ factor: CGFloat = 0.1) {
        scale -= factor
        // 边界检查
        scale = max(scale, 0.2)
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
    
    // MARK: - 手势编辑方法（🆕 新增）
    
    /// 应用手势平移（实时）
    func updateTranslation(_ offset: CGPoint) {
        self.translation.x = max(min(offset.x, 200), -200)
        self.translation.y = max(min(offset.y, 200), -200)
        markNeedsUpdate()
    }
    
    /// 应用手势缩放（实时）
    func updateScale(_ newScale: CGFloat) {
        self.scale = max(min(newScale, 3.0), 0.5)
        markNeedsUpdate()
    }
    
    /// 应用手势旋转（实时，可选）
    func updateRotation(_ angleDegrees: CGFloat) {
        self.rotationAngle = angleDegrees.truncatingRemainder(dividingBy: 360)
        markNeedsUpdate()
    }
    
    /// 保存编辑快照（用于取消时恢复）
    func createSnapshot() -> EditingSnapshot {
        return EditingSnapshot(
            translation: translation,
            scale: scale,
            rotation: rotationAngle,
            flippedH: isFlippedHorizontally,
            flippedV: isFlippedVertically
        )
    }
    
    /// 恢复快照
    func restore(from snapshot: EditingSnapshot) {
        translation = snapshot.translation
        scale = snapshot.scale
        rotationAngle = snapshot.rotation
        isFlippedHorizontally = snapshot.flippedH
        isFlippedVertically = snapshot.flippedV
        markNeedsUpdate()
    }
}

// MARK: - 编辑快照结构体（🆕 新增）
struct EditingSnapshot {
    let translation: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    let flippedH: Bool
    let flippedV: Bool
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
            
            // 检查是否真的改变了模板
            if type(of: template) != type(of: selectedLayoutTemplate) {
                selectedLayoutTemplate = template
                HapticFeedbackManager.shared.buttonTap()
                collectionView.reloadData()
                // 更新预览框高度（布局模板变化可能影响最佳显示尺寸）
                updatePreviewContainerHeight(animated: true)
                updatePreview()
            }
        }
        // imageSelectionCollectionView 已移除，改用长按+手势直接编辑
        else {
            let previousAspectRatio = selectedAspectRatio
            selectedAspectRatio = AspectRatio.allCases[indexPath.item]
            
            if previousAspectRatio != selectedAspectRatio {
                HapticFeedbackManager.shared.buttonTap()
                collectionView.reloadData()
                
                // 验证当前选择的模板是否仍然可用
                validateSelectedTemplate()
                
                // 刷新模板集合视图（因为可用模板可能已经改变）
                templateCollectionView.reloadData()
                
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
        } else {
            return CGSize(width: 60, height: 60)
        }
    }
}

// MARK: - 直接编辑手势处理
extension CollageViewController: UIGestureRecognizerDelegate {
    
    // MARK: - 🆕 实时手势预览系统
    
    /// 创建手势预览图层（在手势开始时调用）
    private func createGesturePreviewLayer() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        // 如果已经存在，直接返回（支持多手势同时）
        if gesturePreviewImageView != nil {
            return
        }
        
        // 获取选中图片在拼图中的frame
        guard let imageFrame = getImageFrameInCollage(at: selectedIndex) else { return }
        
        // 创建预览图层
        let previewImageView = UIImageView()
        previewImageView.image = imageItems[selectedIndex].processedImage
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewImageView.frame = imageFrame
        
        // 添加到 previewImageView 上方
        self.previewImageView.addSubview(previewImageView)
        self.gesturePreviewImageView = previewImageView
        self.gesturePreviewInitialFrame = imageFrame
        
        // 重置手势累积状态
        self.currentGestureTranslation = .zero
        self.currentGestureScale = 1.0
        self.currentGestureRotation = 0
        
        // 添加轻微的视觉效果，表明这是预览层
        previewImageView.layer.borderColor = UIColor.systemYellow.cgColor
        previewImageView.layer.borderWidth = 2
        previewImageView.alpha = 0.95
    }
    
    /// 移除手势预览图层
    private func removeGesturePreviewLayer() {
        gesturePreviewImageView?.removeFromSuperview()
        gesturePreviewImageView = nil
        
        // 重置手势累积状态
        currentGestureTranslation = .zero
        currentGestureScale = 1.0
        currentGestureRotation = 0
    }
    
    /// 获取指定索引的图片在拼图中的显示frame
    private func getImageFrameInCollage(at index: Int) -> CGRect? {
        guard index < imageItems.count else { return nil }
        
        // 获取拼图图像的显示区域
        let displayRect = getImageDisplayRect()
        
        // 获取布局模板的frames
        let collageSize = selectedAspectRatio.size
        let collageBounds = CGRect(origin: .zero, size: collageSize)
        let frames = selectedLayoutTemplate.calculateFrames(for: imageItems.count, in: collageBounds)
        
        guard index < frames.count else { return nil }
        
        // 将布局frame转换为实际显示frame
        let layoutFrame = frames[index]
        let scaleX = displayRect.width / collageSize.width
        let scaleY = displayRect.height / collageSize.height
        
        let actualFrame = CGRect(
            x: displayRect.minX + layoutFrame.minX * scaleX,
            y: displayRect.minY + layoutFrame.minY * scaleY,
            width: layoutFrame.width * scaleX,
            height: layoutFrame.height * scaleY
        )
        
        return actualFrame
    }
    
    /// 更新手势预览图层的transform（实时响应手势）
    private func updateGesturePreviewTransform() {
        guard let previewImageView = gesturePreviewImageView else { return }
        
        // 构建复合transform（按照正确的顺序：缩放 → 旋转 → 平移）
        var transform = CGAffineTransform.identity
        
        // 1. 应用缩放
        if currentGestureScale != 1.0 {
            transform = transform.scaledBy(x: currentGestureScale, y: currentGestureScale)
        }
        
        // 2. 应用旋转
        if currentGestureRotation != 0 {
            transform = transform.rotated(by: currentGestureRotation)
        }
        
        // 3. 应用平移
        if currentGestureTranslation != .zero {
            transform = transform.translatedBy(x: currentGestureTranslation.x, y: currentGestureTranslation.y)
        }
        
        // 应用transform
        previewImageView.transform = transform
    }
    
    // MARK: - 手势节流系统
    
    /// 节流更新拼图（避免频繁重绘）
    private func scheduleGestureUpdate() {
        needsGestureUpdate = true
        
        // 如果定时器不存在，创建一个（60ms = 16fps，平衡流畅度和性能）
        if gestureUpdateTimer == nil {
            gestureUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.needsGestureUpdate {
                    self.regenerateCollageIfNeeded()
                    self.needsGestureUpdate = false
                }
            }
        }
    }
    
    /// 停止节流定时器并执行最后一次更新
    private func finishGestureUpdate() {
        gestureUpdateTimer?.invalidate()
        gestureUpdateTimer = nil
        if needsGestureUpdate {
            regenerateCollageIfNeeded()
            needsGestureUpdate = false
        }
    }
    
    @objc private func handleDirectPan(_ gesture: UIPanGestureRecognizer) {
        guard let selectedIndex = selectedImageIndex else { return }
        
        let translation = gesture.translation(in: previewImageView)
        
        switch gesture.state {
        case .began:
            gestureBeginTranslation = imageItems[selectedIndex].translation
            HapticFeedbackManager.shared.lightImpact()
            
            // 🆕 创建实时预览图层
            createGesturePreviewLayer()
            
            // 显示实时反馈
            showGestureFeedback("正在拖动位置 📍")
            
        case .changed:
            // 🆕 更新累积状态并实时更新预览图层（60fps 视觉反馈）
            currentGestureTranslation = translation
            updateGesturePreviewTransform()
            
            // 更新数据模型（用于最终生成拼图）
            let newTranslation = CGPoint(
                x: gestureBeginTranslation.x + translation.x,
                y: gestureBeginTranslation.y + translation.y
            )
            imageItems[selectedIndex].translation = newTranslation
            
        case .ended, .cancelled:
            // 🆕 移除预览图层并重新生成拼图
            removeGesturePreviewLayer()
            regenerateCollageIfNeeded()
            HapticFeedbackManager.shared.lightImpact()
            
            // 恢复原始提示
            hideGestureFeedback()
            
        default:
            break
        }
    }
    
    @objc private func handleDirectPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let selectedIndex = selectedImageIndex else { return }
        
        switch gesture.state {
        case .began:
            gestureBeginScale = imageItems[selectedIndex].scale
            HapticFeedbackManager.shared.lightImpact()
            
            // 🆕 创建实时预览图层
            createGesturePreviewLayer()
            
            // 显示实时反馈
            showGestureFeedback("正在双指缩放 🔍")
            
        case .changed:
            let newScale = max(0.5, min(3.0, gestureBeginScale * gesture.scale))
            
            // 🆕 更新累积状态并实时更新预览图层（60fps 视觉反馈）
            currentGestureScale = gesture.scale
            updateGesturePreviewTransform()
            
            // 更新数据模型（用于最终生成拼图）
            imageItems[selectedIndex].scale = newScale
            
        case .ended, .cancelled:
            // 🆕 移除预览图层并重新生成拼图
            removeGesturePreviewLayer()
            regenerateCollageIfNeeded()
            HapticFeedbackManager.shared.lightImpact()
            
            // 恢复原始提示
            hideGestureFeedback()
            
        default:
            break
        }
    }
    
    @objc private func handleDirectRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let selectedIndex = selectedImageIndex else { return }
        
        switch gesture.state {
        case .began:
            gestureBeginRotation = imageItems[selectedIndex].rotationAngle
            HapticFeedbackManager.shared.lightImpact()
            
            // 🆕 创建实时预览图层
            createGesturePreviewLayer()
            
            // 显示实时反馈
            showGestureFeedback("正在双指旋转 🔄")
            
        case .changed:
            let newRotation = gestureBeginRotation + gesture.rotation * 180 / .pi
            
            // 🆕 更新累积状态并实时更新预览图层（60fps 视觉反馈）
            currentGestureRotation = gesture.rotation
            updateGesturePreviewTransform()
            
            // 更新数据模型（用于最终生成拼图）
            imageItems[selectedIndex].updateRotation(newRotation)
            
        case .ended, .cancelled:
            // 🆕 移除预览图层并重新生成拼图
            removeGesturePreviewLayer()
            regenerateCollageIfNeeded()
            HapticFeedbackManager.shared.lightImpact()
            
            // 恢复原始提示
            hideGestureFeedback()
            
        default:
            break
        }
    }
    
    // 允许多个手势同时识别
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - 🆕 Light Edit Toolbar
extension CollageViewController {
    
    /// 显示轻量级工具栏
    private func showLightEditToolbar() {
        guard lightEditToolbar.alpha == 0 else { return }
        
        lightEditToolbar.isHidden = false
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.lightEditToolbar.alpha = 1.0
            self.lightEditToolbar.transform = .identity
        } completion: { _ in
            // 添加手势提示的脉动动画，吸引注意力
            self.animateGestureHint()
        }
    }
    
    /// 手势提示的脉动动画
    private func animateGestureHint() {
        UIView.animate(withDuration: 0.6, delay: 0, options: [.autoreverse, .repeat]) {
            self.toolbarHintLabel.alpha = 0.6
        }
        
        // 3秒后停止动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.toolbarHintLabel.layer.removeAllAnimations()
            UIView.animate(withDuration: 0.3) {
                self.toolbarHintLabel.alpha = 1.0
            }
        }
    }
    
    /// 显示手势实时反馈
    private func showGestureFeedback(_ text: String) {
        // 停止所有动画
        toolbarHintLabel.layer.removeAllAnimations()
        
        // 更新文本并高亮显示
        UIView.transition(with: toolbarHintLabel, duration: 0.2, options: .transitionCrossDissolve) {
            self.toolbarHintLabel.text = text
            self.toolbarHintLabel.textColor = ThemeManager.success
            self.toolbarHintLabel.alpha = 1.0
        }
    }
    
    /// 隐藏手势反馈，恢复原始提示
    private func hideGestureFeedback() {
        UIView.transition(with: toolbarHintLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.toolbarHintLabel.text = "💡 试试：拖动调整位置 • 双指缩放/旋转"
            self.toolbarHintLabel.textColor = ThemeManager.warning
        }
    }
    
    /// 首次选中图片时显示引导提示
    private func showFirstTimeGuidance() {
        // 停止脉动动画
        toolbarHintLabel.layer.removeAllAnimations()
        
        // 显示醒目的引导文字
        UIView.transition(with: toolbarHintLabel, duration: 0.4, options: .transitionCrossDissolve) {
            self.toolbarHintLabel.text = "✨ 太棒了！现在可以直接用手势调整图片啦"
            self.toolbarHintLabel.textColor = UIColor.systemOrange
            self.toolbarHintLabel.alpha = 1.0
        }
        
        // 2秒后恢复为常规提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.transition(with: self.toolbarHintLabel, duration: 0.4, options: .transitionCrossDissolve) {
                self.toolbarHintLabel.text = "💡 试试：拖动调整位置 • 双指缩放/旋转"
                self.toolbarHintLabel.textColor = UIColor.systemYellow
            }
        }
    }
    
    /// 隐藏轻量级工具栏
    private func hideLightEditToolbar() {
        guard lightEditToolbar.alpha > 0 else { return }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
            self.lightEditToolbar.alpha = 0
            self.lightEditToolbar.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            self.lightEditToolbar.isHidden = true
        }
    }
    
    /// 工具栏按钮：向左旋转 90°
    @objc private func toolbarRotateLeftTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.lightImpact()
        
        // 当前旋转角度减去 90° (逆时针)
        let currentRotation = imageItems[selectedIndex].rotationAngle
        imageItems[selectedIndex].updateRotation(currentRotation - 90)
        
        regenerateCollageIfNeeded()
        
        print("🔄 向左旋转 90°")
    }
    
    /// 工具栏按钮：向右旋转 90°
    @objc private func toolbarRotateRightTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.lightImpact()
        
        // 当前旋转角度加上 90° (顺时针)
        let currentRotation = imageItems[selectedIndex].rotationAngle
        imageItems[selectedIndex].updateRotation(currentRotation + 90)
        
        regenerateCollageIfNeeded()
        
        print("🔄 向右旋转 90°")
    }
    
    /// 工具栏按钮：水平翻转
    @objc private func toolbarFlipHTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.lightImpact()
        
        // 切换水平翻转状态
        imageItems[selectedIndex].flipHorizontally()
        
        regenerateCollageIfNeeded()
        
        print("↔️ 水平翻转")
    }
    
    /// 工具栏按钮：垂直翻转
    @objc private func toolbarFlipVTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.lightImpact()
        
        // 切换垂直翻转状态
        imageItems[selectedIndex].flipVertically()
        
        regenerateCollageIfNeeded()
        
        print("↕️ 垂直翻转")
    }
    
    /// 工具栏按钮：还原当前图片的所有变换
    @objc private func toolbarResetTapped() {
        guard let selectedIndex = selectedImageIndex else { return }
        
        HapticFeedbackManager.shared.mediumImpact()
        
        // 还原所有变换
        imageItems[selectedIndex].resetEditing()
        
        regenerateCollageIfNeeded()
        
        print("🔄 还原图片变换")
    }
}
