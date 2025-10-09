//
//  SettingsViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  设置视图控制器 - 视频质量、主题、相册管理设置
//

import UIKit
import AVFoundation
import SwiftUI

class SettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    // MARK: - Data
    private var sections: [SettingsSection] = []
    
    // MARK: - Dependencies
    private let videoManager = VideoManager.shared
    private let hapticManager = HapticFeedbackManager.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSections()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshCacheInfo()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 导航栏
        title = "设置"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // 表格视图
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        
        // 注册自定义cell
        tableView.register(SettingsCell.self, forCellReuseIdentifier: SettingsCell.identifier)
        tableView.register(SettingsSwitchCell.self, forCellReuseIdentifier: SettingsSwitchCell.identifier)
        tableView.register(SettingsDetailCell.self, forCellReuseIdentifier: SettingsDetailCell.identifier)
        
        view.addSubview(tableView)
    }
    
    private func setupSections() {
        sections = [
            // 视频设置
            SettingsSection(
                title: "视频设置",
                items: [
                    SettingsItem(
                        type: .selection,
                        title: "视频质量",
                        subtitle: getCurrentVideoQuality(),
                        icon: "video.fill",
                        action: { [weak self] in self?.showVideoQualitySettings() }
                    ),
                    SettingsItem(
                        type: .selection,
                        title: "录制时长限制",
                        subtitle: "无限制",
                        icon: "timer",
                        action: { [weak self] in self?.showRecordingDurationSettings() }
                    )
                ]
            ),
            
            // 外观（已隐藏主题切换入口）
            // SettingsSection(
            //     title: "外观",
            //     items: [
            //         SettingsItem(
            //             type: .selection,
            //             title: "主题",
            //             subtitle: ThemeManager.shared.currentTheme.displayName,
            //             icon: "paintbrush.fill",
            //             action: { [weak self] in self?.showThemeSettings() }
            //         )
            //     ]
            // ),
            
            // 存储管理
            SettingsSection(
                title: "存储管理",
                items: [
                    SettingsItem(
                        type: .detail,
                        title: "缓存大小",
                        subtitle: "计算中...",
                        icon: "internaldrive",
                        action: { [weak self] in self?.showStorageDetails() }
                    ),
                    SettingsItem(
                        type: .action,
                        title: "清理缓存",
                        subtitle: "清除缩略图和临时文件",
                        icon: "trash",
                        action: { [weak self] in self?.showCleanCacheAlert() }
                    )
                ]
            ),
            
            // 开发者选项 (调试用)
            SettingsSection(
                title: "开发者选项",
                items: [
                    SettingsItem(
                        type: .action,
                        title: "🔍 主体提取调试",
                        subtitle: "测试Vision框架+Core Image三阶段智能主体提取算法",
                        icon: "magnifyingglass.circle",
                        action: { [weak self] in self?.showSubjectExtractionDebug() }
                    ),
                    SettingsItem(
                        type: .action,
                        title: "🎯 MobileSAM智能分割",
                        subtitle: "AI驱动的物体精确分割（支持任意点击物体）",
                        icon: "scissors.badge.ellipsis",
                        action: { [weak self] in self?.showSAMSegmentationTest() }
                    ),
                    SettingsItem(
                        type: .action,
                        title: "🎯 DeepLabV3人物分割",
                        subtitle: "专业人物分割测试（运动轨迹场景优化）",
                        icon: "person.crop.circle.fill",
                        action: { [weak self] in self?.showDeepLabV3Test() }
                    ),
                    SettingsItem(
                        type: .action,
                        title: "DETR智能分割测试",
                        subtitle: "测试DETR模型多类别分割效果（人物、动物、植物、食物）",
                        icon: "brain.head.profile",
                        action: { [weak self] in self?.showDETRSegmentationTest() }
                    ),
                    SettingsItem(
                        type: .action,
                        title: "📹 DeepLabV3视频分割测试",
                        subtitle: "选择视频文件提取关键帧，测试DeepLabV3批量人物分割效果与一致性",
                        icon: "video.badge.waveform",
                        action: { [weak self] in self?.showVideoSegmentationTest() }
                    ),
                    SettingsItem(
                        type: .action,
                        title: "多主体合成测试",
                        subtitle: "上传视频自动提取关键帧，测试多主体共享背景合成效果",
                        icon: "camera.macro.circle",
                        action: { [weak self] in self?.showMultiSubjectCompositeTest() }
                    )
                ]
            ),
            
            // 关于
            SettingsSection(
                title: "关于",
                items: [
                    SettingsItem(
                        type: .detail,
                        title: "版本",
                        subtitle: getAppVersion(),
                        icon: "info.circle",
                        action: nil
                    ),
                    SettingsItem(
                        type: .action,
                        title: "隐私政策",
                        subtitle: "查看隐私政策",
                        icon: "hand.raised.fill",
                        action: { [weak self] in self?.showPrivacyPolicy() }
                    ),
                    SettingsItem(
                        type: .action,
                        title: "反馈与建议",
                        subtitle: "帮助我们改进应用",
                        icon: "heart.text.square",
                        action: { [weak self] in self?.showFeedback() }
                    )
                ]
            )
        ]
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 表格视图
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func refreshCacheInfo() {
        videoManager.getCacheSize { [weak self] result in
            switch result {
            case .success(let info):
                self?.updateCacheSizeInfo(info)
            case .failure:
                break
            }
        }
    }
    
    private func updateCacheSizeInfo(_ info: CacheSizeInfo) {
        if let storageSection = sections.first(where: { $0.title == "存储管理" }),
           let cacheItem = storageSection.items.first(where: { $0.title == "缓存大小" }) {
            cacheItem.subtitle = info.formattedTotalSize
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        hapticManager.lightImpact()
        dismiss(animated: true)
    }
    
    // MARK: - Settings Actions
    private func showVideoQualitySettings() {
        let alert = UIAlertController(title: "视频质量", message: "选择录制视频的质量", preferredStyle: .actionSheet)
        
        let qualities = ["4K (超高清)", "1080P (高清)", "720P (标清)"]
        let presets: [AVCaptureSession.Preset] = [.hd4K3840x2160, .hd1920x1080, .hd1280x720]
        
        for (index, quality) in qualities.enumerated() {
            alert.addAction(UIAlertAction(title: quality, style: .default) { [weak self] _ in
                self?.hapticManager.lightImpact()
                UserDefaults.standard.set(presets[index].rawValue, forKey: "VideoQualityPreset")
                self?.updateVideoQualitySubtitle(quality)
                
                // 🎯 发送通知更新相机质量设置
                NotificationCenter.default.post(
                    name: .videoQualityDidChange, 
                    object: nil, 
                    userInfo: ["preset": presets[index]]
                )
                print("✅ 用户更改视频质量为: \(quality)")
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showRecordingDurationSettings() {
        let alert = UIAlertController(title: "录制时长限制", message: "设置单次录制的最大时长", preferredStyle: .actionSheet)
        
        let durations = ["无限制", "30秒", "1分钟", "3分钟", "5分钟"]
        let values = [0, 30, 60, 180, 300]
        
        for (index, duration) in durations.enumerated() {
            alert.addAction(UIAlertAction(title: duration, style: .default) { [weak self] _ in
                UserDefaults.standard.set(values[index], forKey: "MaxRecordingDuration")
                self?.updateRecordingDurationSubtitle(duration)
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showThemeSettings() {
        let alert = UIAlertController(title: "选择主题", message: "切换应用外观主题", preferredStyle: .actionSheet)
        
        // 遍历所有主题
        for theme in AppTheme.allCases {
            let isCurrentTheme = ThemeManager.shared.currentTheme == theme
            let title = isCurrentTheme ? "\(theme.displayName) ✓" : theme.displayName
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                // 切换主题
                ThemeManager.shared.switchTheme(to: theme, animated: true)
                
                // 更新设置项显示
                self?.updateThemeSubtitle(theme.displayName)
                
                // 刷新界面（渐变背景会自动监听主题变化）
                self?.tableView.reloadData()
                
                print("✅ 用户切换主题为: \(theme.displayName)")
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
    
    
    private func showStorageDetails() {
        let storageVC = StorageDetailViewController()
        let navController = UINavigationController(rootViewController: storageVC)
        present(navController, animated: true)
    }
    
    private func showCleanCacheAlert() {
        hapticManager.notificationWarning()
        let alert = UIAlertController(
            title: "清理缓存",
            message: "这将删除所有缩略图和临时文件，但不会影响您的视频和截图。确定继续吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "清理", style: .destructive) { [weak self] _ in
            self?.performCacheCleanup()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func performCacheCleanup() {
        AnimationManager.shared.startLoadingAnimation(on: view)
        
        videoManager.cleanupCache { [weak self] result in
            DispatchQueue.main.async {
                AnimationManager.shared.stopLoadingAnimation(on: self?.view ?? UIView())
                
                switch result {
                case .success(let cleanupResult):
                    self?.hapticManager.notificationSuccess()
                    self?.showCleanupSuccess(cleanupResult)
                    self?.refreshCacheInfo()
                    
                case .failure(let error):
                    self?.hapticManager.notificationError()
                    self?.showError(error)
                }
            }
        }
    }
    
    private func showCleanupSuccess(_ result: CacheCleanupResult) {
        let message = "成功清理 \(result.totalDeletedCount) 个文件，释放 \(String.formatFileSize(result.totalDeletedSize)) 空间"
        
        AnimationManager.shared.showSuccessFeedback(in: view, message: "清理完成！")
        
        let alert = UIAlertController(title: "清理完成", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showPrivacyPolicy() {
        // TODO: 实现隐私政策页面
        let alert = UIAlertController(title: "隐私政策", message: "我们重视您的隐私，所有数据仅存储在本地设备上，不会上传到任何服务器。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showFeedback() {
        // TODO: 实现反馈页面
        let alert = UIAlertController(title: "反馈与建议", message: "感谢您使用 Winkkk！如有建议或问题，请通过 App Store 评价告诉我们。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "去评价", style: .default) { _ in
            // TODO: 跳转到App Store评价页面
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Developer Options
    private func showSubjectExtractionDebug() {
        print("🔍 启动主体提取调试页面...")
        let debugVC = SubjectExtractionDebugViewController()
        let navController = UINavigationController(rootViewController: debugVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showSAMSegmentationTest() {
        print("🎯 启动MobileSAM分割页面...")
        let mobileSAMVC = MobileSAMHostingController()
        let navController = UINavigationController(rootViewController: mobileSAMVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showDeepLabV3Test() {
        print("🎯 启动DeepLabV3人物分割测试页面...")
        let testVC = DeepLabV3TestViewController()
        let navController = UINavigationController(rootViewController: testVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showDETRSegmentationTest() {
        let storyboard = UIStoryboard(name: "DETRSegmentationTest", bundle: nil)
        guard let testVC = storyboard.instantiateViewController(withIdentifier: "DETRSegmentationTestViewController") as? DETRSegmentationTestViewController else {
            print("❌ 无法从Storyboard加载DETRSegmentationTestViewController")
            return
        }
        let navController = UINavigationController(rootViewController: testVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showVideoSegmentationTest() {
        let testVC = VideoSegmentationTestViewController()
        let navController = UINavigationController(rootViewController: testVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showMultiSubjectCompositeTest() {
        let storyboard = UIStoryboard(name: "MultiSubjectCompositeTest", bundle: nil)
        guard let testVC = storyboard.instantiateViewController(withIdentifier: "MultiSubjectCompositeTestViewController") as? MultiSubjectCompositeTestViewController else {
            print("❌ 无法从Storyboard加载MultiSubjectCompositeTestViewController")
            return
        }
        let navController = UINavigationController(rootViewController: testVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - Helper Methods
    private func getCurrentVideoQuality() -> String {
        let preset = UserDefaults.standard.string(forKey: "VideoQualityPreset") ?? AVCaptureSession.Preset.hd1920x1080.rawValue
        
        switch preset {
        case AVCaptureSession.Preset.hd4K3840x2160.rawValue:
            return "4K (超高清)"
        case AVCaptureSession.Preset.hd1920x1080.rawValue:
            return "1080P (高清)"
        case AVCaptureSession.Preset.hd1280x720.rawValue:
            return "720P (标清)"
        default:
            return "1080P (高清)"
        }
    }
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func updateVideoQualitySubtitle(_ quality: String) {
        updateSubtitle(sectionTitle: "视频设置", itemTitle: "视频质量", newSubtitle: quality)
    }
    
    private func updateRecordingDurationSubtitle(_ duration: String) {
        updateSubtitle(sectionTitle: "视频设置", itemTitle: "录制时长限制", newSubtitle: duration)
    }
    
    private func updateThemeSubtitle(_ themeName: String) {
        updateSubtitle(sectionTitle: "外观", itemTitle: "主题", newSubtitle: themeName)
    }
    
    
    private func updateSubtitle(sectionTitle: String, itemTitle: String, newSubtitle: String) {
        if let section = sections.first(where: { $0.title == sectionTitle }),
           let item = section.items.first(where: { $0.title == itemTitle }) {
            item.subtitle = newSubtitle
            tableView.reloadData()
        }
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "错误", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        
        switch item.type {
        case .toggle:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.identifier, for: indexPath) as! SettingsSwitchCell
            cell.configure(with: item)
            return cell
            
        case .detail:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.identifier, for: indexPath) as! SettingsDetailCell
            cell.configure(with: item)
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.identifier, for: indexPath) as! SettingsCell
            cell.configure(with: item)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        hapticManager.lightImpact()
        
        let item = sections[indexPath.section].items[indexPath.row]
        item.action?()
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.overlayTextWhite
            headerView.textLabel?.font = ThemeManager.subheadlineFont
        }
    }
}

// MARK: - Settings Data Structures
class SettingsSection {
    let title: String
    let items: [SettingsItem]
    
    init(title: String, items: [SettingsItem]) {
        self.title = title
        self.items = items
    }
}

class SettingsItem {
    let type: SettingsItemType
    let title: String
    var subtitle: String
    let icon: String
    let action: (() -> Void)?
    let isOn: Bool
    let switchAction: ((Bool) -> Void)?
    
    init(type: SettingsItemType, title: String, subtitle: String, icon: String, action: (() -> Void)? = nil) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
        self.isOn = false
        self.switchAction = nil
    }
    
    init(type: SettingsItemType, title: String, subtitle: String, icon: String, isOn: Bool, switchAction: @escaping (Bool) -> Void) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = nil
        self.isOn = isOn
        self.switchAction = switchAction
    }
}

enum SettingsItemType {
    case selection
    case toggle
    case detail
    case action
}

// MARK: - Settings Cells
class SettingsCell: UITableViewCell {
    static let identifier = "SettingsCell"
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let accessoryImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupThemeObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 容器
        containerView.backgroundColor = ThemeManager.overlayTextWhite.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        contentView.addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeManager.buttonPrimary
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.subheadlineFont
        titleLabel.textColor = ThemeManager.overlayTextWhite
        containerView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.font = ThemeManager.captionFont
        subtitleLabel.textColor = ThemeManager.overlaySecondaryText
        containerView.addSubview(subtitleLabel)
        
        // 辅助图标
        accessoryImageView.image = UIImage(systemName: "chevron.right")
        accessoryImageView.contentMode = .scaleAspectFit
        accessoryImageView.tintColor = ThemeManager.overlaySecondaryText.withAlphaComponent(0.7)
        containerView.addSubview(accessoryImageView)
        
        setupConstraints()
    }
    
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateThemeColors),
            name: .themeDidChange,
            object: nil
        )
    }
    
    @objc private func updateThemeColors() {
        iconImageView.tintColor = ThemeManager.buttonPrimary
        titleLabel.textColor = ThemeManager.overlayTextWhite
        subtitleLabel.textColor = ThemeManager.overlaySecondaryText
        accessoryImageView.tintColor = ThemeManager.overlaySecondaryText.withAlphaComponent(0.7)
    }
    
    private func setupConstraints() {
        [containerView, iconImageView, titleLabel, subtitleLabel, accessoryImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: accessoryImageView.leadingAnchor, constant: -16),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            accessoryImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            accessoryImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            accessoryImageView.widthAnchor.constraint(equalToConstant: 16),
            accessoryImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with item: SettingsItem) {
        iconImageView.image = UIImage(systemName: item.icon)
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        
        accessoryImageView.isHidden = item.action == nil
    }
}

class SettingsSwitchCell: UITableViewCell {
    static let identifier = "SettingsSwitchCell"
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let switchControl = UISwitch()
    
    private var switchAction: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupThemeObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 容器
        containerView.backgroundColor = ThemeManager.overlayTextWhite.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        contentView.addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeManager.success
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.subheadlineFont
        titleLabel.textColor = ThemeManager.overlayTextWhite
        containerView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.font = ThemeManager.captionFont
        subtitleLabel.textColor = ThemeManager.overlaySecondaryText
        containerView.addSubview(subtitleLabel)
        
        // 开关
        switchControl.onTintColor = ThemeManager.buttonPrimary
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        containerView.addSubview(switchControl)
        
        setupConstraints()
    }
    
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateThemeColors),
            name: .themeDidChange,
            object: nil
        )
    }
    
    @objc private func updateThemeColors() {
        iconImageView.tintColor = ThemeManager.success
        titleLabel.textColor = ThemeManager.overlayTextWhite
        subtitleLabel.textColor = ThemeManager.overlaySecondaryText
        switchControl.onTintColor = ThemeManager.buttonPrimary
    }
    
    private func setupConstraints() {
        [containerView, iconImageView, titleLabel, subtitleLabel, switchControl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -16),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            switchControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    func configure(with item: SettingsItem) {
        iconImageView.image = UIImage(systemName: item.icon)
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        switchControl.isOn = item.isOn
        switchAction = item.switchAction
    }
    
    @objc private func switchValueChanged() {
        HapticFeedbackManager.shared.trigger(.light)
        switchAction?(switchControl.isOn)
    }
}

class SettingsDetailCell: UITableViewCell {
    static let identifier = "SettingsDetailCell"
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupThemeObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 容器
        containerView.backgroundColor = ThemeManager.overlayTextWhite.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        contentView.addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeManager.warning
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.subheadlineFont
        titleLabel.textColor = ThemeManager.overlayTextWhite
        containerView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.font = ThemeManager.captionFont
        subtitleLabel.textColor = ThemeManager.overlaySecondaryText
        subtitleLabel.textAlignment = .right
        containerView.addSubview(subtitleLabel)
        
        setupConstraints()
    }
    
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateThemeColors),
            name: .themeDidChange,
            object: nil
        )
    }
    
    @objc private func updateThemeColors() {
        iconImageView.tintColor = ThemeManager.warning
        titleLabel.textColor = ThemeManager.overlayTextWhite
        subtitleLabel.textColor = ThemeManager.overlaySecondaryText
    }
    
    private func setupConstraints() {
        [containerView, iconImageView, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: subtitleLabel.leadingAnchor, constant: -16),
            
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            subtitleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            subtitleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }
    
    func configure(with item: SettingsItem) {
        iconImageView.image = UIImage(systemName: item.icon)
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
    }
}

// MARK: - StorageDetailViewController
class StorageDetailViewController: UIViewController {
    
    private let gradientBackgroundView = GradientBackgroundView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var storageItems: [StorageItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadStorageData()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        title = "存储详情"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(closeButtonTapped))
        
        // 表格视图
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        // 布局
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "StorageCell")
        
        // 添加下拉刷新
        setupRefreshControl()
    }
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(refreshStorageData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    @objc private func refreshStorageData() {
        StorageAnalyzer.shared.getDetailedStorageInfo(forceRefresh: true) { [weak self] result in
            DispatchQueue.main.async {
                self?.tableView.refreshControl?.endRefreshing()
                
                switch result {
                case .success(let storageInfo):
                    self?.updateStorageItems(with: storageInfo)
                    
                case .failure(let error):
                    print("❌ StorageDetail: 刷新存储信息失败: \(error)")
                    self?.showErrorState(error)
                }
            }
        }
    }
    
    private func loadStorageData() {
        // 显示加载状态
        AnimationManager.shared.startLoadingAnimation(on: view)
        
        StorageAnalyzer.shared.getDetailedStorageInfo { [weak self] result in
            DispatchQueue.main.async {
                AnimationManager.shared.stopLoadingAnimation(on: self?.view ?? UIView())
                
                switch result {
                case .success(let storageInfo):
                    self?.updateStorageItems(with: storageInfo)
                    
                case .failure(let error):
                    print("❌ StorageDetail: 加载存储信息失败: \(error)")
                    // 显示错误状态，但保留基本界面
                    self?.showErrorState(error)
                }
            }
        }
    }
    
    private func updateStorageItems(with storageInfo: DetailedStorageInfo) {
        storageItems = storageInfo.categories.map { category in
            StorageItem(
                title: category.title,
                size: category.formattedSize,
                icon: category.icon,
                fileCount: category.fileCount,
                canCleanup: category.canCleanup,
                categoryType: category.type
            )
        }
        
        // 更新导航标题显示总大小
        title = "存储详情 (\(storageInfo.formattedTotalSize))"
        
        tableView.reloadData()
    }
    
    private func showErrorState(_ error: Error) {
        // 显示基本的错误信息，但不影响界面
        storageItems = [
            StorageItem(title: "加载失败", size: "请下拉刷新", icon: "exclamationmark.triangle.fill")
        ]
        tableView.reloadData()
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Storage Interaction Methods
    
    private func showInfoAlert(for item: StorageItem) {
        let title = item.title
        let message: String
        
        if item.title.contains("视频") {
            message = "用户视频文件，包含您录制和导入的所有视频。这些文件不会被自动清理。"
        } else if item.title.contains("截图") {
            message = "从视频中截取的图片文件，这些是您的重要数据，不会被自动清理。"
        } else {
            message = "该类型文件暂不支持清理操作。"
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showCleanupConfirmation(for item: StorageItem, categoryType: StorageCategoryType) {
        let title = "清理 \(item.title)"
        let message = "即将清理 \(item.size) 的\(categoryType.description)。\n\n此操作不会影响您的重要数据，清理后可以释放存储空间。"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 确认清理按钮
        alert.addAction(UIAlertAction(title: "确认清理", style: .destructive) { [weak self] _ in
            self?.performCleanup(categoryType: categoryType, itemTitle: item.title)
        })
        
        present(alert, animated: true)
    }
    
    private func performCleanup(categoryType: StorageCategoryType, itemTitle: String) {
        // 显示加载动画
        AnimationManager.shared.startLoadingAnimation(on: view)
        
        StorageAnalyzer.shared.cleanupCategory(categoryType) { [weak self] result in
            DispatchQueue.main.async {
                AnimationManager.shared.stopLoadingAnimation(on: self?.view ?? UIView())
                
                switch result {
                case .success(let cleanupResult):
                    self?.showCleanupSuccess(result: cleanupResult, categoryTitle: itemTitle)
                    // 重新加载数据
                    self?.loadStorageData()
                    
                case .failure(let error):
                    self?.showCleanupError(error: error, categoryTitle: itemTitle)
                }
            }
        }
    }
    
    private func showCleanupSuccess(result: CacheCleanupResult, categoryTitle: String) {
        let title = "清理完成"
        let message = "成功清理 \(categoryTitle)\n" +
                     "删除文件: \(result.totalDeletedCount) 个\n" +
                     "释放空间: \(String.formatFileSize(result.totalDeletedSize))"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showCleanupError(error: Error, categoryTitle: String) {
        let title = "清理失败"
        let message = "清理 \(categoryTitle) 时出现错误:\n\(error.localizedDescription)"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - StorageDetailViewController DataSource
extension StorageDetailViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storageItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StorageCell", for: indexPath)
        
        let item = storageItems[indexPath.row]
        
        // 移除旧的主题观察者，添加新的
        NotificationCenter.default.removeObserver(cell, name: .themeDidChange, object: nil)
        NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak cell] _ in
            cell?.backgroundColor = ThemeManager.overlayTextWhite.withAlphaComponent(0.1)
            cell?.imageView?.tintColor = ThemeManager.buttonPrimary
            cell?.textLabel?.textColor = ThemeManager.overlayTextWhite
            cell?.detailTextLabel?.textColor = ThemeManager.overlaySecondaryText
        }
        
        cell.backgroundColor = ThemeManager.overlayTextWhite.withAlphaComponent(0.1)
        cell.textLabel?.text = item.title
        
        // 显示大小和文件数量
        if item.fileCount > 0 {
            cell.detailTextLabel?.text = "\(item.size) (\(item.fileCount) 个文件)"
        } else {
            cell.detailTextLabel?.text = item.size
        }
        
        cell.imageView?.image = UIImage(systemName: item.icon)
        cell.imageView?.tintColor = ThemeManager.buttonPrimary
        cell.textLabel?.textColor = ThemeManager.overlayTextWhite
        cell.detailTextLabel?.textColor = ThemeManager.overlaySecondaryText
        
        // 可清理的项目显示不同的样式
        if item.canCleanup {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "存储详情"
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = storageItems[indexPath.row]
        
        // 只有可清理的项目才能点击
        guard item.canCleanup, let categoryType = item.categoryType else {
            showInfoAlert(for: item)
            return
        }
        
        showCleanupConfirmation(for: item, categoryType: categoryType)
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.overlayTextWhite
        }
    }
}

struct StorageItem {
    let title: String
    let size: String
    let icon: String
    let fileCount: Int
    let canCleanup: Bool
    let categoryType: StorageCategoryType?
    
    // 便利初始化器，用于错误状态
    init(title: String, size: String, icon: String) {
        self.title = title
        self.size = size
        self.icon = icon
        self.fileCount = 0
        self.canCleanup = false
        self.categoryType = nil
    }
    
    // 完整初始化器，用于正常数据
    init(title: String, size: String, icon: String, fileCount: Int, canCleanup: Bool, categoryType: StorageCategoryType) {
        self.title = title
        self.size = size
        self.icon = icon
        self.fileCount = fileCount
        self.canCleanup = canCleanup
        self.categoryType = categoryType
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let videoQualityDidChange = Notification.Name("videoQualityDidChange")
}
