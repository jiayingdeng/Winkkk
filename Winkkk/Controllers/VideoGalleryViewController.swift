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
        
        // 注册cell
        cv.register(VideoThumbnailCell.self, forCellWithReuseIdentifier: VideoThumbnailCell.identifier)
        cv.register(AddVideoCell.self, forCellWithReuseIdentifier: AddVideoCell.identifier)
        
        return cv
    }()
    
    private let gradientBackgroundView = GradientBackgroundView()
    private let emptyStateView = EmptyStateView()
    
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
        button.tintColor = ThemeManager.primaryText
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
        print("📱 VideoGallery: Deinitializing")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ThemeManager.background
        
        // 添加渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 添加副标题视图
        view.addSubview(subtitleView)
        
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
        title = "我的创作"
        
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
            // 创建右侧按钮栈
            let stackView = UIStackView(arrangedSubviews: [selectButton, importButton])
            stackView.axis = .horizontal
            stackView.spacing = 16
            stackView.alignment = .center
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: stackView)
        }
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        subtitleView.translatesAutoresizingMaskIntoConstraints = false
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
            
            // 集合视图
            collectionView.topAnchor.constraint(equalTo: subtitleView.bottomAnchor),
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
            videos = fetchedResultsController.fetchedObjects ?? []
            print("✅ VideoGallery: Loaded \(videos.count) videos")
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
    
    // 🆕 延迟清理方法 - 避免与NSFetchedResultsController初始化冲突
    private func performDeferredCleanup() {
        print("📱 VideoGallery: 开始延迟清理检查")
        
        // 🔧 修改清理策略：每次启动都检查孤儿记录，但智能决定是否执行清理
        videoManager.checkForOrphanRecords { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let orphanCount):
                    if orphanCount > 0 {
                        print("🧹 VideoGallery: 发现 \(orphanCount) 个孤儿记录，开始清理")
                        self?.executeCleanup()
                    } else {
                        print("✅ VideoGallery: 没有发现孤儿记录，跳过清理")
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
                    self?.updateUI()
                    
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
            videos = fetchedResultsController.fetchedObjects ?? []
            print("✅ VideoGallery: Refreshed \(videos.count) videos")
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
            
            let hasVideos = !self.videos.isEmpty
            self.emptyStateView.isHidden = hasVideos
            self.collectionView.isHidden = !hasVideos
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
        
        let alert = UIAlertController(
            title: "导出视频",
            message: "确定要导出选中的 \(selectedVideoItems.count) 个视频到系统相册吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "导出", style: .default) { [weak self] _ in
            self?.performBatchExport()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func deleteButtonTapped() {
        guard !selectedVideoItems.isEmpty else { return }
        
        let alert = UIAlertController(
            title: "删除视频",
            message: "确定要删除选中的 \(selectedVideoItems.count) 个视频吗？此操作无法撤销。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.performBatchDelete()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
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
        
        // 动画更新collection view
        UIView.animate(withDuration: 0.3) {
            self.collectionView.reloadData()
        }
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedVideoItems.removeAll()
        updateToolbarForNormalMode()
        
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
            title = "已选择 \(selectedCount) 个视频"
        } else {
            title = "选择视频"
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
        if !hasShownGuidance && videos.isEmpty {
            showFirstTimeGuidance()
            UserDefaults.standard.set(true, forKey: "VideoGalleryGuidanceShown")
        }
    }
    
    private func showFirstTimeGuidance() {
        let alert = UIAlertController(
            title: "欢迎使用应用内相册",
            message: """
            🎬 这里存储您在应用内创建的视频作品
            
            ✨ 主要功能：
            • 录制的视频会自动保存在这里
            • 可以从系统相册导入视频
            • 处理完成后可导出到系统相册分享
            
            💡 与系统相册的区别：
            • 应用内相册：私密存储，支持高级编辑
            • 系统相册：公共存储，便于分享
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "开始创作", style: .default) { [weak self] _ in
            // 可以在这里添加引导到录制界面的逻辑
        })
        
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "错误",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension VideoGalleryViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count + 1 // +1 for add video cell
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
            let video = videos[indexPath.item - 1]
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
            let video = videos[indexPath.item - 1]
            
            if isSelectionMode {
                // 选择模式下处理多选
                if selectedVideoItems.contains(video) {
                    selectedVideoItems.remove(video)
                } else {
                    selectedVideoItems.insert(video)
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
        print("导出视频到系统相册: \(video.fileName)")
        
        // 检查文件是否存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: video.filePath.path) {
            print("❌ 视频文件不存在: \(video.filePath.path)")
            let alert = UIAlertController(
                title: "导出失败",
                message: "视频文件不存在，无法导出到系统相册",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        print("✅ 视频文件存在，开始导出到系统相册")
        
        // 显示导出进度指示器
        let loadingAlert = UIAlertController(title: "导出中", message: "正在导出视频到系统相册...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 导出视频到系统相册
        UISaveVideoAtPathToSavedPhotosAlbum(video.filePath.path, self, #selector(videoExportComplete(_:didFinishSavingWithError:contextInfo:)), nil)
        print("🔄 UISaveVideoAtPathToSavedPhotosAlbum已调用")
    }
    
    @objc private func videoExportComplete(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("🎬 视频导出回调被调用")
        print("   路径: \(videoPath)")
        print("   错误: \(error?.localizedDescription ?? "无错误")")
        
        // 关闭进度指示器
        dismiss(animated: true) { [weak self] in
            if let error = error {
                print("❌ 视频导出到系统相册失败: \(error.localizedDescription)")
                
                // 显示错误消息
                let alert = UIAlertController(
                    title: "导出失败", 
                    message: "无法导出视频到系统相册: \(error.localizedDescription)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self?.present(alert, animated: true)
                
            } else {
                print("✅ 视频成功导出到系统相册")
                
                // 显示成功消息
                let alert = UIAlertController(
                    title: "导出成功", 
                    message: "视频已成功导出到系统相册",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self?.present(alert, animated: true)
            }
        }
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
            
            self.videos = fetchedObjects
            
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
