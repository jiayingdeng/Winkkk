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
    
    // 导航栏按钮
    private lazy var importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = ThemeManager.primaryText
        button.addTarget(self, action: #selector(importButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = ThemeManager.primaryText
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
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
        setupFetchedResultsController()
        loadVideos()
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
        
        // 添加集合视图
        view.addSubview(collectionView)
        
        // 添加空状态视图
        view.addSubview(emptyStateView)
        emptyStateView.isHidden = true
    }
    
    private func setupNavigationBar() {
        title = "我的视频"
        
        // 自定义导航栏外观
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        
        // 设置导航栏按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        
        // 添加多主体测试按钮
        let testButton = UIButton(type: .system)
        testButton.setImage(UIImage(systemName: "testtube.2"), for: .normal)
        testButton.tintColor = ThemeManager.primaryText
        testButton.addTarget(self, action: #selector(testButtonTapped), for: .touchUpInside)
        
        let rightButtons = UIStackView(arrangedSubviews: [testButton, importButton])
        rightButtons.axis = .horizontal
        rightButtons.spacing = 16
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightButtons)
        
        // 设置标题样式
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: ThemeManager.primaryText,
            .font: ThemeManager.headlineFont
        ]
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 集合视图
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 空状态视图
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
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
    
    @objc private func testButtonTapped() {
        print("🧪 VideoGallery: Test button tapped")
        presentMultiSubjectCompositeTest()
    }
    
    /// 打开多主体合成测试页面
    private func presentMultiSubjectCompositeTest() {
        let storyboard = UIStoryboard(name: "MultiSubjectCompositeTest", bundle: nil)
        guard let testViewController = storyboard.instantiateViewController(withIdentifier: "MultiSubjectCompositeTestViewController") as? MultiSubjectCompositeTestViewController else {
            print("❌ 无法加载多主体合成测试页面")
            return
        }
        
        let navigationController = UINavigationController(rootViewController: testViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
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
            return cell
        } else {
            // 视频缩略图
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoThumbnailCell.identifier, for: indexPath) as! VideoThumbnailCell
            let video = videos[indexPath.item - 1]
            cell.configure(with: video)
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
            importButtonTapped()
        } else {
            // 选择视频
            let video = videos[indexPath.item - 1]
            if let delegate = delegate {
                delegate.videoGalleryViewController(self, didSelectVideo: video)
            } else {
                openVideoEditor(with: video)
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
}

// MARK: - NSFetchedResultsControllerDelegate
extension VideoGalleryViewController: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("📱 VideoGallery: Core Data content changed")
        videos = fetchedResultsController.fetchedObjects ?? []
        
        // 使用防抖机制，避免频繁更新UI
        scheduleUIUpdate()
    }
}
