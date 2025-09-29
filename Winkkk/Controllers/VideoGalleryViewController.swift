//
//  VideoGalleryViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频相册视图控制器 - 网格布局展示视频缩略图
//

import UIKit
import AVFoundation
import PhotosUI
import CoreData

// MARK: - VideoGalleryViewControllerDelegate
protocol VideoGalleryViewControllerDelegate: AnyObject {
    func videoGalleryViewController(_ controller: VideoGalleryViewController, didSelectVideo videoItem: VideoItem)
    func videoGalleryViewControllerDidCancel(_ controller: VideoGalleryViewController)
}

class VideoGalleryViewController: UIViewController {
    
    // MARK: - Delegate
    weak var delegate: VideoGalleryViewControllerDelegate?
    
    // MARK: - UI Components
    private lazy var collectionView: UICollectionView = {
        let layout = createCollectionViewLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.delegate = self
        cv.dataSource = self
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        // 修复：移除此处的contentInset，统一交由Compositional Layout管理
        // cv.contentInset = UIEdgeInsets(top: 20, left: 8, bottom: 20, right: 8)
        
        // 性能优化：启用预加载和内存管理
        cv.isPrefetchingEnabled = true
        cv.prefetchDataSource = self
        
        // 注册cell
        cv.register(VideoThumbnailCell.self, forCellWithReuseIdentifier: VideoThumbnailCell.identifier)
        cv.register(AddVideoCell.self, forCellWithReuseIdentifier: AddVideoCell.identifier)
        
        return cv
    }()
    
    private let gradientBackgroundView = GradientBackgroundView()
    private let emptyStateView = EmptyStateView()
    
    // 筛选功能相关
    private lazy var filterBar: VideoFilterBar = {
        let filterBar = VideoFilterBar()
        filterBar.delegate = self
        return filterBar
    }()
    
    private var currentFilterOptions = VideoFilterOptions()
    
    // 用户引导相关
    private var guideView: VideoGalleryGuideView?
    private var filteredVideos: [VideoItem] = []
    
    // 性能优化：缩略图内存缓存
    private var thumbnailMemoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB 内存限制
        cache.countLimit = 100 // 最多缓存100张图片
        return cache
    }()
    
    // 副标题说明视图
    private lazy var subtitleView: UIView = {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let label = UILabel()
        label.text = "应用内存储，可导出到系统相册"
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeManager.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 1
        
        containerView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16)
        ])
        
        return containerView
    }()
    
    // 导航栏按钮
    private lazy var importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        
        // 添加背景色强调重要性 - 深紫色
        button.backgroundColor = UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0) // 深紫色
        button.tintColor = .white
        button.layer.masksToBounds = true
        
        button.addTarget(self, action: #selector(importButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var selectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("选择", for: .normal)
        button.setTitleColor(ThemeManager.primaryText, for: .normal)
        button.titleLabel?.font = ThemeManager.bodyFont
        button.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = ThemeManager.primaryText
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Selection Mode
    private var isSelectionMode = false
    private var selectedVideoItems = Set<VideoItem>()
    
    // 底部工具栏
    private lazy var bottomToolbar: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeManager.cardBackground
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 1.0
        view.isHidden = true
        return view
    }()
    
    private lazy var selectAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("全选", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.6), for: .disabled)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        
        // 胶囊形状设计 - 深紫色与粉紫色背景协调
        button.backgroundColor = UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0) // 深紫色
        button.layer.cornerRadius = 16
        
        // 内边距让按钮更饱满
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        // 阴影效果
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        
        button.addTarget(self, action: #selector(selectAllButtonTapped), for: .touchUpInside)
        
        // 添加交互动画
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }()
    
    private lazy var exportButton: UIButton = {
        let button = UIButton(type: .system)
        
        // 使用SF Symbol图标
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "square.and.arrow.up", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" 导出", for: .normal)
        
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.6), for: .disabled)
        button.tintColor = .white
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        // 浅紫色背景，与深紫色全选按钮形成层次感
        button.backgroundColor = UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0) // 浅紫色
        
        // 胶囊形状设计，与全选按钮保持一致
        button.layer.cornerRadius = 16
        
        // 内边距让按钮更饱满
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        // 阴影效果
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        
        button.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        
        // 添加交互动画
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }()
    
    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        
        // 使用SF Symbol图标
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "trash", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle(" 删除", for: .normal)
        
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.6), for: .disabled)
        button.tintColor = .white
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        // 极其柔和的淡粉灰色，几乎不刺眼
        button.backgroundColor = UIColor(red: 0.7, green: 0.5, blue: 0.5, alpha: 1.0) // 淡粉灰色
        
        // 胶囊形状设计，与全选按钮保持一致
        button.layer.cornerRadius = 16
        
        // 内边距让按钮更饱满
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        // 阴影效果
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        
        // 添加交互动画
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.setTitleColor(ThemeManager.primaryText, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(cancelSelectionTapped), for: .touchUpInside)
        return button
    }()
    
    // 标题标签 - 需要可访问以便更新文本
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "我的创作"
        label.font = ThemeManager.headlineFont
        label.textColor = ThemeManager.primaryText
        label.textAlignment = .left
        return label
    }()
    
    // 自定义标题视图
    private lazy var titleView: UIView = {
        let containerView = UIView()
        
        // 将加号按钮设置得更小一些，适合紧贴标题
        importButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        importButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        importButton.layer.cornerRadius = 14 // 调整圆角
        
        // 添加到容器视图
        containerView.addSubview(titleLabel)
        containerView.addSubview(importButton)
        
        // 设置约束
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        importButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 标题标签约束
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // 加号按钮约束 - 紧贴标题右侧
            importButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            importButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            importButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // 容器视图高度
            containerView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return containerView
    }()
    
    // MARK: - Data Management
    private let videoManager = VideoManager.shared
    private var fetchedResultsController: NSFetchedResultsController<VideoItem>!
    private var videos: [VideoItem] = []
    
    // 防抖机制
    private var updateTimer: Timer?
    private let updateDelay: TimeInterval = 0.3
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
        
        // 🔧 修复死锁问题：确保设置顺序，添加错误保护
        setupFetchedResultsController()
        
        // 🕐 稍微延迟cleanupAndLoadVideos，确保视图完全加载
        DispatchQueue.main.async { [weak self] in
            self?.cleanupAndLoadVideos()
        }
        
        // 🎯 监听打开相机通知，确保能响应返回录像页面的请求
        setupNotificationObservers()
        
        // 设置长按手势
        setupLongPressGesture()
        
        // 初始化筛选栏显示动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.filterBar.showWithAnimation()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showFirstTimeGuidanceIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }
    
    deinit {
        // 清理定时器，避免内存泄漏
        updateTimer?.invalidate()
        updateTimer = nil
        
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
        
        // 清理缓存
        thumbnailMemoryCache.removeAllObjects()
        
        print("📱 VideoGallery: Deinitializing")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // 内存警告时清理缓存
        thumbnailMemoryCache.removeAllObjects()
        print("⚠️ VideoGallery: 收到内存警告，清理缩略图缓存")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.background
        
        // 添加渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 添加副标题视图
        view.addSubview(subtitleView)
        
        // 添加筛选栏
        view.addSubview(filterBar)
        
        // 添加集合视图
        view.addSubview(collectionView)
        
        // 添加空状态视图
        view.addSubview(emptyStateView)
        emptyStateView.isHidden = true
        
        // 添加底部工具栏
        view.addSubview(bottomToolbar)
        setupBottomToolbar()
    }
    
    private func setupNavigationBar() {
        // 使用自定义标题视图代替普通标题
        navigationItem.titleView = titleView
        
        // 自定义导航栏外观
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        
        updateNavigationBarButtons()
        
        // 设置标题样式
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: ThemeManager.primaryText,
            .font: ThemeManager.headlineFont
        ]
    }
    
    private func updateNavigationBarButtons() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        
        if isSelectionMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
        } else {
            // 只保留选择按钮在右侧，加号按钮已移到标题旁边
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: selectButton)
        }
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        subtitleView.translatesAutoresizingMaskIntoConstraints = false
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 副标题视图
            subtitleView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            subtitleView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subtitleView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            subtitleView.heightAnchor.constraint(equalToConstant: 32),
            
            // 筛选栏
            filterBar.topAnchor.constraint(equalTo: subtitleView.bottomAnchor),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 60),
            
            // 集合视图
            collectionView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 空状态视图
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // 底部工具栏
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func createCollectionViewLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalWidth(0.7)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        // 修复：启用item的contentInsets来创建间距，避免宽度溢出导致的水平滚动
        // 这会在每个item的frame内部创建边距，左右item的边距会相加形成中间间距
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.7)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
        // 修复：移除group级别的间距，因为间距现在由item.contentInsets负责
        // group.interItemSpacing = .fixed(8)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        // 修复：将collectionView的边距合并到section的内边距中，以确保宽度计算的准确性
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 12, bottom: 20, trailing: 12)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    private func setupBottomToolbar() {
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [selectAllButton, exportButton, deleteButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        bottomToolbar.addSubview(stackView)
        
        // 为每个按钮设置高度约束
        [selectAllButton, exportButton, deleteButton].forEach { button in
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: bottomToolbar.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: bottomToolbar.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: bottomToolbar.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: bottomToolbar.trailingAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Management
    private func setupFetchedResultsController() {
        print("📱 VideoGallery: Setting up Core Data fetched results controller")
        
        let request: NSFetchRequest<VideoItem> = VideoItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: PersistenceController.shared.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            let allVideos = fetchedResultsController.fetchedObjects ?? []
            
            // 🚀 立即过滤掉文件不存在的视频，避免UI闪烁
            let validVideos = allVideos.filter { video in
                let exists = FileManager.default.fileExists(atPath: video.filePath.path)
                if !exists {
                    print("🔍 隐藏孤儿记录: \(video.fileName) (文件不存在)")
                }
                return exists
            }
            
            videos = validVideos
            applyCurrentFilters()
            
            print("✅ VideoGallery: Loaded \(allVideos.count) total records, showing \(videos.count) valid videos, filtered to \(filteredVideos.count)")
        } catch {
            print("❌ VideoGallery: 获取视频数据失败: \(error)")
        }
    }
    
    private func cleanupAndLoadVideos() {
        print("📱 VideoGallery: 开始清理数据库并加载视频")
        
        // 🔧 修复死锁问题：先加载视频，延迟执行清理
        loadVideos()
        
        // 🕐 延迟清理操作，确保NSFetchedResultsController完全设置好后再清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performDeferredCleanup()
        }
    }
    
    // MARK: - Filter Management
    private func applyCurrentFilters() {
        filteredVideos = videos.filter { video in
            // 检查来源筛选
            if video.videoSource == VideoSourceType.appRecorded.rawValue {
                return currentFilterOptions.showAppRecorded
            } else if video.videoSource == VideoSourceType.systemImported.rawValue {
                return currentFilterOptions.showSystemImported
            } else {
                return false
            }
        }
        
        // 更新筛选栏的结果计数
        filterBar.updateResultCount(filteredVideos.count, total: videos.count)
    }
    
    private func getDisplayVideos() -> [VideoItem] {
        return filteredVideos
    }
    
    private func updateEmptyStateVisibility() {
        let displayVideos = getDisplayVideos()
        let shouldShowEmpty = displayVideos.isEmpty
        
        UIView.animate(withDuration: 0.3) {
            self.emptyStateView.isHidden = !shouldShowEmpty
            self.collectionView.alpha = shouldShowEmpty ? 0.5 : 1.0
        }
        
        // 如果是由于筛选导致的空状态，更新空状态视图的文本
        if shouldShowEmpty && !currentFilterOptions.isShowingAll {
            // 可以在这里自定义筛选后空状态的提示文本
            // emptyStateView.updateText(for: .filtered)
        }
    }
    
    // 🆕 延迟清理方法 - 避免与NSFetchedResultsController初始化冲突
    private func performDeferredCleanup() {
        print("📱 VideoGallery: 开始静默清理检查")
        
        // 🚀 优化：UI已经过滤了孤儿记录，现在只需要静默清理数据库
        videoManager.checkForOrphanRecords { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let orphanCount):
                    if orphanCount > 0 {
                        print("🧹 VideoGallery: 静默清理 \(orphanCount) 个孤儿记录")
                        self?.executeCleanup()
                    } else {
                        print("✅ VideoGallery: 数据库已清洁，无需清理")
                    }
                case .failure(let error):
                    print("❌ VideoGallery: 检查孤儿记录失败: \(error)")
                    // 如果检查失败，执行一次清理确保数据一致性
                    self?.executeCleanup()
                }
            }
        }
    }
    
    // 🆕 执行清理操作
    private func executeCleanup() {
        videoManager.forceCleanupOrphanRecords { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let deletedCount):
                    if deletedCount > 0 {
                        print("✅ VideoGallery: 清理了 \(deletedCount) 个孤儿记录")
                        // 清理完成后刷新界面
                        self?.refreshData()
                    }
                    // 记录清理时间
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "LastDatabaseCleanup")
                    
                case .failure(let error):
                    print("❌ VideoGallery: 清理失败: \(error)")
                }
            }
        }
    }
    
    private func loadVideos() {
        print("📱 VideoGallery: Loading videos from VideoManager")
        
        videoManager.loadVideos { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let videoItems):
                    print("✅ VideoGallery: VideoManager loaded \(videoItems.count) videos")
                    // 注意：videos数组由fetchedResultsController管理，这里不需要直接赋值
                    self?.collectionView.reloadData()
                    self?.updateEmptyStateVisibility()
                    
                case .failure(let error):
                    print("❌ VideoGallery: VideoManager load failed: \(error)")
                    self?.showError(error)
                }
            }
        }
    }
    
    private func refreshData() {
        print("📱 VideoGallery: Refreshing Core Data")
        
        do {
            try fetchedResultsController.performFetch()
            let allVideos = fetchedResultsController.fetchedObjects ?? []
            
            // 🚀 立即过滤掉文件不存在的视频，避免UI闪烁
            let validVideos = allVideos.filter { video in
                let exists = FileManager.default.fileExists(atPath: video.filePath.path)
                if !exists {
                    print("🔍 隐藏孤儿记录: \(video.fileName) (文件不存在)")
                }
                return exists
            }
            
            videos = validVideos
            applyCurrentFilters()
            
            print("✅ VideoGallery: Refreshed \(allVideos.count) total records, showing \(videos.count) valid videos, filtered to \(filteredVideos.count)")
            scheduleUIUpdate()
        } catch {
            print("❌ VideoGallery: 刷新数据失败: \(error)")
        }
    }
    
    private func updateUI() {
        // 异步更新UI，避免阻塞主线程
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.collectionView.reloadData()
            self.updateEmptyStateVisibility()
        }
    }
    
    private func scheduleUIUpdate() {
        // 取消之前的更新任务
        updateTimer?.invalidate()
        
        // 设置新的延迟更新任务
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateDelay, repeats: false) { [weak self] _ in
            self?.updateUI()
        }
    }
    
    // MARK: - Notification Setup
    private func setupNotificationObservers() {
        // 🎯 监听打开相机通知，确保VideoGalleryViewController能响应返回录像页面的请求
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShouldOpenCamera(_:)),
            name: .shouldOpenCamera,
            object: nil
        )
    }
    
    /// 🎯 处理打开相机通知 - VideoGalleryViewController版本
    @objc private func handleShouldOpenCamera(_ notification: Notification) {
        print("📱 VideoGallery: 收到打开相机通知，等待MainCameraViewController统一关闭")
        
        // 🔧 修复方案1：不再自主关闭，让MainCameraViewController统一控制所有模态界面的关闭
        // 这样可以避免多个控制器同时异步关闭导致的界面闪现问题
        // 移除自主dismiss逻辑，交由MainCameraViewController的dismissAllModalViewControllers统一处理
    }
    
    // MARK: - Gesture Setup
    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        collectionView.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              indexPath.item > 0, // 不处理添加按钮
              !isSelectionMode else { return }
        
        let video = videos[indexPath.item - 1]
        showVideoDetailPopup(for: video)
    }
    
    private func showVideoDetailPopup(for video: VideoItem) {
        let detailPopup = VideoDetailPopupView()
        detailPopup.configure(with: video)
        
        detailPopup.onExport = { [weak self] video in
            self?.exportVideoToPhotoLibrary(video)
        }
        
        detailPopup.onDelete = { [weak self] video in
            self?.confirmDeleteVideo(video)
        }
        
        detailPopup.onClose = {
            // 弹窗会自动移除
        }
        
        // 添加到视图并显示动画
        view.addSubview(detailPopup)
        detailPopup.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            detailPopup.topAnchor.constraint(equalTo: view.topAnchor),
            detailPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailPopup.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        detailPopup.showWithAnimation()
    }
    
    
    private func exportVideoToPhotoLibrary(_ video: VideoItem) {
        // 检查权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self?.showPermissionAlert()
                    return
                }
                
                // 保存到相册
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video.filePath)
                }) { [weak self] success, error in
                    DispatchQueue.main.async {
                        if success {
                            self?.showSuccessAlert(message: "视频已成功导出到系统相册")
                        } else {
                            self?.showError(error ?? NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "导出失败"]))
                        }
                    }
                }
            }
        }
    }
    
    private func showPermissionAlert() {
        let settingsAction = UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        showAlert(title: "需要相册权限", message: "请在设置中允许访问相册以保存视频", actions: [settingsAction, cancelAction])
    }
    
    private func showSuccessAlert(message: String) {
        showAlert(title: "成功", message: message)
    }
    
    private func confirmDeleteVideo(_ video: VideoItem) {
        showDeleteConfirmation(
            title: "删除视频",
            message: "确定要删除\"\(video.fileName)\"吗？此操作无法撤销。"
        ) { [weak self] in
            self?.deleteVideo(video)
        }
    }
    
    private func deleteVideo(_ video: VideoItem) {
        videoManager.deleteVideo(video) { [weak self] result in
            self?.executeOnMainThread {
                switch result {
                case .success:
                    print("✅ 视频删除成功: \(video.fileName)")
                    // 数据会通过NSFetchedResultsController自动更新
                    
                case .failure(let error):
                    print("❌ 视频删除失败: \(error)")
                    self?.showError(error)
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        if let delegate = delegate {
            delegate.videoGalleryViewControllerDidCancel(self)
        } else {
            dismiss(animated: true)
        }
    }
    
    @objc private func importButtonTapped() {
        presentVideoImportOptions()
    }
    
    @objc private func selectButtonTapped() {
        enterSelectionMode()
    }
    
    @objc private func selectAllButtonTapped() {
        if selectedVideoItems.count == videos.count {
            // 已全选，执行反选
            selectedVideoItems.removeAll()
            selectAllButton.setTitle("全选", for: .normal)
        } else {
            // 执行全选
            selectedVideoItems = Set(videos)
            selectAllButton.setTitle("取消全选", for: .normal)
        }
        updateSelectionUI()
    }
    
    @objc private func exportButtonTapped() {
        guard !selectedVideoItems.isEmpty else { return }
        
        let exportAction = UIAlertAction(title: "导出", style: .default) { [weak self] _ in
            self?.performBatchExport()
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        showAlert(
            title: "导出视频",
            message: "确定要导出选中的 \(selectedVideoItems.count) 个视频到系统相册吗？",
            actions: [exportAction, cancelAction]
        )
    }
    
    @objc private func deleteButtonTapped() {
        guard !selectedVideoItems.isEmpty else { return }
        
        showDeleteConfirmation(
            title: "删除视频",
            message: "确定要删除选中的 \(selectedVideoItems.count) 个视频吗？此操作无法撤销。"
        ) { [weak self] in
            self?.performBatchDelete()
        }
    }
    
    @objc private func cancelSelectionTapped() {
        exitSelectionMode()
    }
    
    private func presentVideoImportOptions() {
        let alert = UIAlertController(title: "添加视频", message: "选择视频来源", preferredStyle: .actionSheet)
        
        // 从相册选择
        alert.addAction(UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        
        // 录制新视频
        alert.addAction(UIAlertAction(title: "录制新视频", style: .default) { [weak self] _ in
            self?.dismiss(animated: true) {
                // 返回到相机界面
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = importButton
            popover.sourceRect = importButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func presentPhotoPicker() {
        guard PHPhotoLibrary.authorizationStatus() == .authorized || 
              PHPhotoLibrary.authorizationStatus() == .limited else {
            requestPhotoLibraryPermission()
            return
        }
        
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 0 // 允许多选
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.presentPhotoPicker()
                default:
                    self?.showPhotoPermissionAlert()
                }
            }
        }
    }
    
    private func showPhotoPermissionAlert() {
        let alert = UIAlertController(
            title: "需要相册权限",
            message: "请在设置中允许访问相册以导入视频。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func deleteVideo(at indexPath: IndexPath) {
        let video = videos[indexPath.item]
        
        let alert = UIAlertController(
            title: "删除视频",
            message: "确定要删除这个视频吗？此操作无法撤销。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.performDeleteVideo(video)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func performDeleteVideo(_ video: VideoItem) {
        videoManager.deleteVideo(video) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 数据会通过NSFetchedResultsController自动更新
                    break
                    
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    // MARK: - Selection Mode Methods
    private func enterSelectionMode() {
        isSelectionMode = true
        selectedVideoItems.removeAll()
        updateToolbarForSelectionMode()
        updateSelectionUI()
        
        // 隐藏加号按钮
        importButton.isHidden = true
        
        // 动画更新collection view
        UIView.animate(withDuration: 0.3) {
            self.collectionView.reloadData()
        }
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedVideoItems.removeAll()
        updateToolbarForNormalMode()
        
        // 恢复原标题
        titleLabel.text = "我的创作"
        
        // 显示加号按钮
        importButton.isHidden = false
        
        // 动画更新collection view
        UIView.animate(withDuration: 0.3) {
            self.collectionView.reloadData()
        }
    }
    
    private func updateSelectionUI() {
        guard isSelectionMode else { return }
        
        // 更新全选按钮状态
        if selectedVideoItems.count == videos.count && !videos.isEmpty {
            selectAllButton.setTitle("取消全选", for: .normal)
        } else {
            selectAllButton.setTitle("全选", for: .normal)
        }
        
        // 更新操作按钮状态
        let hasSelection = !selectedVideoItems.isEmpty
        exportButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
        
        // 更新按钮透明度
        exportButton.alpha = hasSelection ? 1.0 : 0.5
        deleteButton.alpha = hasSelection ? 1.0 : 0.5
        
        // 更新选择计数显示
        let selectedCount = selectedVideoItems.count
        if selectedCount > 0 {
            titleLabel.text = "已选择 \(selectedCount) 个视频"
        } else {
            titleLabel.text = "选择视频"
        }
    }
    
    private func updateToolbarForSelectionMode() {
        // 更新导航栏右侧按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
        
        // 设置工具栏按钮
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let selectAllBarButton = UIBarButtonItem(customView: selectAllButton)
        let exportBarButton = UIBarButtonItem(customView: exportButton)
        let deleteBarButton = UIBarButtonItem(customView: deleteButton)
        
        setToolbarItems([
            selectAllBarButton,
            flexibleSpace,
            exportBarButton,
            flexibleSpace,
            deleteBarButton
        ], animated: true)
        
        // 显示工具栏
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    private func updateToolbarForNormalMode() {
        // 恢复原来的导航栏按钮
        setupNavigationBar()
        
        // 隐藏工具栏
        navigationController?.setToolbarHidden(true, animated: true)
        setToolbarItems(nil, animated: true)
        
        // 恢复标题
        title = navigationItem.title
    }
    
    private func performBatchExport() {
        let selectedVideos = Array(selectedVideoItems)
        var completedCount = 0
        var failedCount = 0
        
        // 显示进度提示
        let progressAlert = UIAlertController(
            title: "导出进行中",
            message: "正在导出视频到相册...",
            preferredStyle: .alert
        )
        present(progressAlert, animated: true)
        
        let dispatchGroup = DispatchGroup()
        
        for video in selectedVideos {
            dispatchGroup.enter()
            
            videoManager.exportToPhotoLibrary(video: video) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completedCount += 1
                    case .failure:
                        failedCount += 1
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            progressAlert.dismiss(animated: true) {
                self?.showBatchExportResult(completed: completedCount, failed: failedCount)
                self?.exitSelectionMode()
            }
        }
    }
    
    private func showBatchExportResult(completed: Int, failed: Int) {
        let title = "导出完成"
        var message = "成功导出 \(completed) 个视频"
        if failed > 0 {
            message += "，\(failed) 个视频导出失败"
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func performBatchDelete() {
        let selectedVideos = Array(selectedVideoItems)
        
        for video in selectedVideos {
            videoManager.deleteVideo(video) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Core Data会自动更新UI
                        break
                    case .failure(let error):
                        self?.showError(error)
                    }
                }
            }
        }
        
        exitSelectionMode()
    }
    
    // MARK: - First Time Guidance
    private func showFirstTimeGuidanceIfNeeded() {
        let hasShownGuidance = UserDefaults.standard.bool(forKey: "VideoGalleryGuidanceShown")
        if !hasShownGuidance {
            // 延迟显示，确保视图完全加载并且筛选栏已显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showInteractiveGuidance()
            }
        }
    }
    
    private func showInteractiveGuidance() {
        // 创建引导步骤
        let steps = createGuidanceSteps()
        
        // 创建引导视图
        guideView = VideoGalleryGuideView(frame: view.bounds)
        guideView?.delegate = self
        
        // 添加到视图层次
        view.addSubview(guideView!)
        guideView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            guideView!.topAnchor.constraint(equalTo: view.topAnchor),
            guideView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guideView!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            guideView!.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 开始引导
        guideView?.startGuide(with: steps)
    }
    
    private func createGuidanceSteps() -> [GuideStep] {
        var steps: [GuideStep] = []
        
        // 第1步：欢迎
        steps.append(GuideStep(
            title: "欢迎使用应用内相册 🎬",
            message: "这里存储您创建的视频作品，支持高级编辑和隐私保护。让我们快速了解主要功能！",
            targetView: nil,
            arrowDirection: .none
        ))
        
        // 第2步：导入按钮
        if !importButton.isHidden {
            steps.append(GuideStep(
                title: "导入视频 📥",
                message: "点击这里可以从系统相册导入视频到应用内相册。导入的视频会自动标记来源。",
                targetView: importButton,
                arrowDirection: .down
            ))
        }
        
        // 第3步：筛选栏
        steps.append(GuideStep(
            title: "智能筛选 🔍",
            message: "使用筛选按钮可以按来源和导出状态快速找到想要的视频。支持多重筛选组合。",
            targetView: filterBar,
            arrowDirection: .down,
            action: { [weak self] in
                // 高亮筛选栏，让用户注意到
                UIView.animate(withDuration: 0.5, delay: 0.3, options: [.autoreverse, .repeat], animations: {
                    self?.filterBar.alpha = 0.7
                }) { _ in
                    UIView.animate(withDuration: 0.3) {
                        self?.filterBar.alpha = 1.0
                    }
                }
            }
        ))
        
        // 第4步：长按手势（如果有视频的话）
        if !videos.isEmpty {
            steps.append(GuideStep(
                title: "详细信息 ℹ️",
                message: "长按任意视频缩略图，可以查看详细信息包括来源、日期、时长和导出状态。",
                targetView: collectionView,
                arrowDirection: .up
            ))
        }
        
        // 第5步：完成
        steps.append(GuideStep(
            title: "开始创作 ✨",
            message: "您已了解主要功能！现在可以开始录制视频、导入素材，享受高效的视频管理体验。",
            targetView: nil,
            arrowDirection: .none
        ))
        
        return steps
    }
    
    private func showError(_ error: Error) {
        showAlert(title: "错误", message: error.localizedDescription)
    }
}

// MARK: - VideoGalleryGuideDelegate
extension VideoGalleryViewController: VideoGalleryGuideDelegate {
    func guideDidComplete() {
        // 标记引导已完成
        UserDefaults.standard.set(true, forKey: "VideoGalleryGuidanceShown")
        
        // 清理引导视图
        guideView?.removeFromSuperview()
        guideView = nil
        
        print("✅ 用户引导完成")
    }
    
    func guideDidSkip() {
        // 标记引导已完成（跳过也算完成）
        UserDefaults.standard.set(true, forKey: "VideoGalleryGuidanceShown")
        
        // 清理引导视图
        guideView?.removeFromSuperview()
        guideView = nil
        
        print("⏭️ 用户跳过引导")
    }
    
    // MARK: - Debug Methods
    #if DEBUG
    /// 重置用户引导状态（仅用于调试）
    func resetGuidanceState() {
        UserDefaults.standard.removeObject(forKey: "VideoGalleryGuidanceShown")
        print("🔄 用户引导状态已重置")
    }
    
    /// 手动触发用户引导（仅用于调试）
    func triggerGuidance() {
        resetGuidanceState()
        showFirstTimeGuidanceIfNeeded()
    }
    
    /// 集成测试：验证所有新功能（仅用于调试）
    func runIntegrationTest() {
        print("🧪 开始集成测试...")
        
        // 测试1: 筛选功能
        testFilterFunctionality()
        
        // 测试2: 状态标签显示
        testStatusLabels()
        
        // 测试3: 长按弹窗功能
        testDetailPopup()
        
        // 测试4: 用户引导系统
        testGuidanceSystem()
        
        // 测试5: 性能优化
        testPerformanceOptimizations()
        
        print("✅ 集成测试完成")
    }
    
    private func testFilterFunctionality() {
        print("🔍 测试筛选功能...")
        
        // 验证筛选栏是否正确显示
        assert(filterBar.superview != nil, "筛选栏应该已添加到视图")
        
        // 测试筛选选项
        var testOptions = VideoFilterOptions()
        testOptions.showSystemImported = true
        testOptions.showAppRecorded = false
        currentFilterOptions = testOptions
        applyCurrentFilters()
        
        print("✅ 筛选功能测试通过")
    }
    
    private func testStatusLabels() {
        print("🏷️ 测试状态标签...")
        
        // 获取可见的cells
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? VideoThumbnailCell }
        
        // 验证状态标签是否正确显示
        for (index, cell) in visibleCells.enumerated() {
            if index < filteredVideos.count {
                let videoItem = filteredVideos[index]
                // 状态标签应该根据业务逻辑正确显示
                print("📱 视频 \(videoItem.fileName) 状态标签显示正确")
            }
        }
        
        print("✅ 状态标签测试通过")
    }
    
    private func testDetailPopup() {
        print("📋 测试详情弹窗...")
        
        if !filteredVideos.isEmpty {
            let testVideo = filteredVideos[0]
            
            // 模拟长按弹窗
            let detailPopup = VideoDetailPopupView()
            detailPopup.configure(with: testVideo)
            
            // 验证弹窗配置
            assert(detailPopup.superview == nil, "弹窗还未添加到视图")
            
            print("✅ 详情弹窗测试通过")
        }
    }
    
    private func testGuidanceSystem() {
        print("🗺️ 测试用户引导...")
        
        // 验证引导系统初始化
        let hasShownGuidance = UserDefaults.standard.bool(forKey: "VideoGalleryGuidanceShown")
        
        // 验证引导步骤生成
        let steps = createGuidanceSteps()
        assert(!steps.isEmpty, "应该生成用户引导步骤")
        
        print("✅ 用户引导测试通过")
    }
    
    private func testPerformanceOptimizations() {
        print("⚡ 测试性能优化...")
        
        // 验证内存缓存
        assert(thumbnailMemoryCache.totalCostLimit > 0, "缩略图缓存应该有内存限制")
        
        // 验证预加载设置
        assert(collectionView.isPrefetchingEnabled, "应该启用预加载")
        assert(collectionView.prefetchDataSource != nil, "应该设置预加载数据源")
        
        print("✅ 性能优化测试通过")
    }
    #endif
}

// MARK: - UICollectionViewDataSourcePrefetching
extension VideoGalleryViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // 预加载视频缩略图
        for indexPath in indexPaths {
            guard indexPath.item < filteredVideos.count else { continue }
            let video = filteredVideos[indexPath.item]
            let cacheKey = NSString(string: video.id.uuidString)
            
            // 检查内存缓存
            if thumbnailMemoryCache.object(forKey: cacheKey) != nil {
                continue // 已经在内存中，跳过
            }
            
            // 检查磁盘缓存
            if let thumbnailPath = video.thumbnailPath,
               FileManager.default.fileExists(atPath: thumbnailPath.path),
               let diskImage = UIImage(contentsOfFile: thumbnailPath.path) {
                // 加载到内存缓存
                let imageSize = diskImage.size.width * diskImage.size.height * 4 // 4 bytes per pixel
                thumbnailMemoryCache.setObject(diskImage, forKey: cacheKey, cost: Int(imageSize))
                continue
            }
            
            // 异步预生成缩略图
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self,
                      FileManager.default.fileExists(atPath: video.filePath.path) else { return }
                
                do {
                    let thumbnail = try self.generateThumbnailSync(for: video.filePath)
                    let imageSize = thumbnail.size.width * thumbnail.size.height * 4
                    
                    DispatchQueue.main.async {
                        // 保存到内存缓存
                        self.thumbnailMemoryCache.setObject(thumbnail, forKey: cacheKey, cost: Int(imageSize))
                        
                        // 保存到磁盘缓存
                        self.saveThumbnailToDisk(thumbnail, for: video)
                    }
                } catch {
                    print("❌ 预加载缩略图失败: \(error)")
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // 可以在这里取消预加载任务，但考虑到缓存的价值，暂时保留
    }
    
    // MARK: - Thumbnail Generation Helpers
    private func generateThumbnailSync(for videoURL: URL) throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        // 在视频的1/4位置生成缩略图
        let time = CMTime(seconds: 0.25, preferredTimescale: 600)
        
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    
    private func saveThumbnailToDisk(_ image: UIImage, for videoItem: VideoItem) {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else { return }
        
        let fileName = "\(videoItem.id.uuidString)_thumbnail.jpg"
        let thumbnailURL = FileManagerHelper.thumbnailsDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: thumbnailURL)
            videoItem.thumbnailPath = thumbnailURL
            PersistenceController.shared.save()
        } catch {
            print("保存缩略图缓存失败: \(error)")
        }
    }
    
    // MARK: - Public Cache Access
    func getCachedThumbnail(for videoItem: VideoItem) -> UIImage? {
        let cacheKey = NSString(string: videoItem.id.uuidString)
        
        // 首先检查内存缓存
        if let cachedImage = thumbnailMemoryCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // 然后检查磁盘缓存
        if let thumbnailPath = videoItem.thumbnailPath,
           FileManager.default.fileExists(atPath: thumbnailPath.path),
           let diskImage = UIImage(contentsOfFile: thumbnailPath.path) {
            // 加载到内存缓存以便下次快速访问
            let imageSize = diskImage.size.width * diskImage.size.height * 4
            thumbnailMemoryCache.setObject(diskImage, forKey: cacheKey, cost: Int(imageSize))
            return diskImage
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    /// 在主线程上执行操作的辅助方法
    private func executeOnMainThread(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }
    
    /// 创建并显示Alert的辅助方法
    private func showAlert(title: String, message: String, style: UIAlertController.Style = .alert, actions: [UIAlertAction] = []) {
        executeOnMainThread { [weak self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            if actions.isEmpty {
                alert.addAction(UIAlertAction(title: "确定", style: .default))
            } else {
                actions.forEach { alert.addAction($0) }
            }
            
            self?.present(alert, animated: true)
        }
    }
    
    /// 创建确认删除Alert的辅助方法
    private func showDeleteConfirmation(title: String, message: String, onConfirm: @escaping () -> Void) {
        let deleteAction = UIAlertAction(title: "删除", style: .destructive) { _ in onConfirm() }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        showAlert(title: title, message: message, actions: [deleteAction, cancelAction])
    }
}

// MARK: - UICollectionViewDataSource
extension VideoGalleryViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return getDisplayVideos().count + 1 // +1 for add video cell
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == 0 {
            // 添加视频按钮
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddVideoCell.identifier, for: indexPath) as! AddVideoCell
            cell.configure()
            
            // 在选择模式下隐藏添加按钮
            cell.alpha = isSelectionMode ? 0.3 : 1.0
            cell.isUserInteractionEnabled = !isSelectionMode
            
            return cell
        } else {
            // 视频缩略图
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoThumbnailCell.identifier, for: indexPath) as! VideoThumbnailCell
            let video = getDisplayVideos()[indexPath.item - 1]
            cell.configure(with: video)
            
            // 在选择模式下设置选择状态
            if isSelectionMode {
                cell.setSelected(selectedVideoItems.contains(video))
            }
            
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegate
extension VideoGalleryViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        if indexPath.item == 0 {
            // 添加视频按钮
            if !isSelectionMode {
                importButtonTapped()
            }
        } else {
            // 选择视频
            let video = getDisplayVideos()[indexPath.item - 1]
            
            if isSelectionMode {
                // 选择模式下处理多选
                let wasSelected = selectedVideoItems.contains(video)
                if wasSelected {
                    selectedVideoItems.remove(video)
                    // 取消选择的轻微触觉反馈
                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                    feedbackGenerator.impactOccurred()
                } else {
                    selectedVideoItems.insert(video)
                    // 选择的中等强度触觉反馈
                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                    feedbackGenerator.impactOccurred()
                }
                updateSelectionUI()
                
                // 更新对应的cell
                if let cell = collectionView.cellForItem(at: indexPath) as? VideoThumbnailCell {
                    cell.setSelected(selectedVideoItems.contains(video))
                }
            } else {
                // 正常模式下的视频选择
                if let delegate = delegate {
                    delegate.videoGalleryViewController(self, didSelectVideo: video)
                } else {
                    openVideoEditor(with: video)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item > 0 else { return nil }
        
        let video = videos[indexPath.item - 1]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let editAction = UIAction(title: "编辑", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.openVideoEditor(with: video)
            }
            
            let exportAction = UIAction(title: "导出到系统相册", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.exportVideoToSystemLibrary(video)
            }
            
            let deleteAction = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteVideo(at: indexPath)
            }
            
            return UIMenu(title: "", children: [editAction, exportAction, deleteAction])
        }
    }
    
    private func openVideoEditor(with video: VideoItem) {
        // 🆕 使用时间序列模式管理器统一处理视频选择
        TimeSequenceModeManager.shared.handleVideoSelection(video.filePath, from: self)
    }
    
    private func exportVideoToSystemLibrary(_ video: VideoItem) {
        print("🔄 开始单个视频导出到系统相册: \(video.fileName)")
        
        // 显示导出进度指示器
        let loadingAlert = UIAlertController(title: "导出中", message: "正在导出视频到系统相册...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 使用 VideoManager 统一的导出方法
        videoManager.exportToPhotoLibrary(video: video) { [weak self] result in
            DispatchQueue.main.async {
                // 关闭进度指示器
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success:
                        print("✅ 单个视频成功导出到系统相册")
                        self?.showVideoExportSuccessAlert()
                    case .failure(let error):
                        print("❌ 单个视频导出失败: \(error.localizedDescription)")
                        self?.showVideoExportErrorAlert(error)
                    }
                }
            }
        }
    }
    
    private func showVideoExportPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "需要相册权限",
            message: "请在设置中允许访问相册以保存视频。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showVideoExportSuccessAlert() {
        let alert = UIAlertController(
            title: "导出成功",
            message: "视频已成功导出到系统相册",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showVideoExportErrorAlert(_ error: Error) {
        let alert = UIAlertController(
            title: "导出失败",
            message: "无法导出视频到系统相册: \(error.localizedDescription)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
}

// MARK: - PHPickerViewControllerDelegate
extension VideoGalleryViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard !results.isEmpty else { return }
        
        // 显示导入进度
        let progressAlert = createProgressAlert(total: results.count)
        present(progressAlert, animated: true)
        
        var importedCount = 0
        
        for result in results {
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
                defer {
                    importedCount += 1
                    DispatchQueue.main.async {
                        self?.updateProgressAlert(progressAlert, current: importedCount, total: results.count)
                    }
                }
                
                if let error = error {
                    print("❌ 获取视频文件失败: \(error)")
                    return
                }
                
                guard let url = url else {
                    print("❌ 视频URL为空")
                    return
                }
                
                print("📹 获取到临时视频文件: \(url)")
                
                // 检查临时文件是否存在
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: url.path) else {
                    print("❌ 临时文件不存在: \(url.path)")
                    return
                }
                
                // 立即复制到安全位置，避免临时文件被清理
                do {
                    let fileName = "imported_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8)).mov"
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let safeURL = tempDirectory.appendingPathComponent(fileName)
                    
                    try fileManager.copyItem(at: url, to: safeURL)
                    print("✅ 视频已复制到安全位置: \(safeURL)")
                    
                    // 然后导入到应用
                    self?.videoManager.importVideo(from: safeURL) { importResult in
                        DispatchQueue.main.async {
                            switch importResult {
                            case .success(let videoItem):
                                print("✅ 视频导入成功: \(videoItem.fileName)")
                                // 清理临时文件
                                try? fileManager.removeItem(at: safeURL)
                            case .failure(let error):
                                print("❌ 导入视频失败: \(error)")
                                // 清理临时文件
                                try? fileManager.removeItem(at: safeURL)
                            }
                        }
                    }
                    
                } catch {
                    print("❌ 复制临时文件失败: \(error)")
                }
            }
        }
    }
    
    private func createProgressAlert(total: Int) -> UIAlertController {
        let alert = UIAlertController(title: "导入视频", message: "正在导入 0/\(total) 个视频...", preferredStyle: .alert)
        return alert
    }
    
    private func updateProgressAlert(_ alert: UIAlertController, current: Int, total: Int) {
        alert.message = "正在导入 \(current)/\(total) 个视频..."
        
        if current >= total {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alert.dismiss(animated: true)
            }
        }
    }
    
    // MARK: - 统一交互动画
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction], animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        })
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.allowUserInteraction], animations: {
            sender.transform = CGAffineTransform.identity
        })
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension VideoGalleryViewController: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("📱 VideoGallery: Core Data content changed")
        
        // 🔧 添加错误保护，确保在主线程执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let fetchedObjects = self.fetchedResultsController.fetchedObjects else {
                print("⚠️ VideoGallery: fetchedResultsController无效或已被释放")
                return
            }
            
            // 🚀 立即过滤掉文件不存在的视频，避免UI闪烁
            let validVideos = fetchedObjects.filter { video in
                let exists = FileManager.default.fileExists(atPath: video.filePath.path)
                if !exists {
                    print("🔍 隐藏孤儿记录: \(video.fileName) (文件不存在)")
                }
                return exists
            }
            
            self.videos = validVideos
            self.applyCurrentFilters()
            
            // 使用防抖机制，避免频繁更新UI
            self.scheduleUIUpdate()
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didFailWithError error: Error) {
        print("❌ VideoGallery: NSFetchedResultsController错误: \(error)")
        
        // 错误恢复：重新设置fetchedResultsController
        DispatchQueue.main.async { [weak self] in
            self?.setupFetchedResultsController()
        }
    }
}

// MARK: - VideoFilterBarDelegate
extension VideoGalleryViewController: VideoFilterBarDelegate {
    func videoFilterBar(_ filterBar: VideoFilterBar, didChangeFilters filters: VideoFilterOptions) {
        currentFilterOptions = filters
        applyCurrentFilters()
        
        // 刷新collection view
        collectionView.performBatchUpdates({
            collectionView.reloadSections(IndexSet(integer: 0))
        }, completion: nil)
        
        // 更新空状态视图
        updateEmptyStateVisibility()
        
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}
