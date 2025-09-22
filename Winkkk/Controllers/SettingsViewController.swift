//
//  SettingsViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  设置视图控制器 - 视频质量、主题、相册管理设置
//

import UIKit
import AVFoundation

class SettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    // MARK: - Data
    private var sections: [SettingsSection] = []
    
    // MARK: - Dependencies
    private let videoManager = VideoManager.shared
    
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
            
            // 画质修复设置
            SettingsSection(
                title: "画质修复",
                items: [
                    SettingsItem(
                        type: .selection,
                        title: "默认修复强度",
                        subtitle: "中度修复",
                        icon: "wand.and.stars",
                        action: { [weak self] in self?.showEnhanceSettings() }
                    ),
                    SettingsItem(
                        type: .toggle,
                        title: "自动画质修复",
                        subtitle: "截图后自动应用修复",
                        icon: "autostartstop",
                        isOn: UserDefaults.standard.bool(forKey: "AutoEnhanceEnabled"),
                        switchAction: { isOn in
                            UserDefaults.standard.set(isOn, forKey: "AutoEnhanceEnabled")
                        }
                    )
                ]
            ),
            
            // 分享设置
            SettingsSection(
                title: "分享设置",
                items: [
                    SettingsItem(
                        type: .toggle,
                        title: "默认添加水印",
                        subtitle: "分享时自动添加应用水印",
                        icon: "drop.fill",
                        isOn: UserDefaults.standard.bool(forKey: "DefaultWatermarkEnabled"),
                        switchAction: { isOn in
                            UserDefaults.standard.set(isOn, forKey: "DefaultWatermarkEnabled")
                        }
                    ),
                    SettingsItem(
                        type: .selection,
                        title: "水印样式",
                        subtitle: "默认样式",
                        icon: "paintbrush.fill",
                        action: { [weak self] in self?.showWatermarkSettings() }
                    )
                ]
            ),
            
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
                        title: "DETR智能分割测试",
                        subtitle: "测试DETR模型多类别分割效果（人物、动物、植物、食物）",
                        icon: "brain.head.profile",
                        action: { [weak self] in self?.showDETRSegmentationTest() }
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
        dismiss(animated: true)
    }
    
    // MARK: - Settings Actions
    private func showVideoQualitySettings() {
        let alert = UIAlertController(title: "视频质量", message: "选择录制视频的质量", preferredStyle: .actionSheet)
        
        let qualities = ["4K (超高清)", "1080P (高清)", "720P (标清)"]
        let presets: [AVCaptureSession.Preset] = [.hd4K3840x2160, .hd1920x1080, .hd1280x720]
        
        for (index, quality) in qualities.enumerated() {
            alert.addAction(UIAlertAction(title: quality, style: .default) { [weak self] _ in
                UserDefaults.standard.set(presets[index].rawValue, forKey: "VideoQualityPreset")
                self?.updateVideoQualitySubtitle(quality)
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
    
    private func showEnhanceSettings() {
        let alert = UIAlertController(title: "默认修复强度", message: "选择图片画质修复的默认强度", preferredStyle: .actionSheet)
        
        let levels = ["轻度修复", "中度修复", "重度修复"]
        
        for (index, level) in levels.enumerated() {
            alert.addAction(UIAlertAction(title: level, style: .default) { [weak self] _ in
                UserDefaults.standard.set(index + 1, forKey: "DefaultEnhanceLevel")
                self?.updateEnhanceSubtitle(level)
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showWatermarkSettings() {
        let alert = UIAlertController(title: "水印样式", message: "选择默认的水印样式", preferredStyle: .actionSheet)
        
        let styles = ["默认样式", "简约样式", "优雅样式"]
        
        for (index, style) in styles.enumerated() {
            alert.addAction(UIAlertAction(title: style, style: .default) { [weak self] _ in
                UserDefaults.standard.set(index, forKey: "DefaultWatermarkStyle")
                self?.updateWatermarkSubtitle(style)
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
                    self?.showCleanupSuccess(cleanupResult)
                    self?.refreshCacheInfo()
                    
                case .failure(let error):
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
    
    private func updateEnhanceSubtitle(_ level: String) {
        updateSubtitle(sectionTitle: "画质修复", itemTitle: "默认修复强度", newSubtitle: level)
    }
    
    private func updateWatermarkSubtitle(_ style: String) {
        updateSubtitle(sectionTitle: "分享设置", itemTitle: "水印样式", newSubtitle: style)
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
        
        let item = sections[indexPath.section].items[indexPath.row]
        item.action?()
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = UIColor.white.withAlphaComponent(0.8)
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 容器
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        contentView.addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeManager.buttonPrimary
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.subheadlineFont
        titleLabel.textColor = .white
        containerView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.font = ThemeManager.captionFont
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        containerView.addSubview(subtitleLabel)
        
        // 辅助图标
        accessoryImageView.image = UIImage(systemName: "chevron.right")
        accessoryImageView.contentMode = .scaleAspectFit
        accessoryImageView.tintColor = UIColor.white.withAlphaComponent(0.5)
        containerView.addSubview(accessoryImageView)
        
        setupConstraints()
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 容器
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        contentView.addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeManager.success
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.subheadlineFont
        titleLabel.textColor = .white
        containerView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.font = ThemeManager.captionFont
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        containerView.addSubview(subtitleLabel)
        
        // 开关
        switchControl.onTintColor = ThemeManager.buttonPrimary
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        containerView.addSubview(switchControl)
        
        setupConstraints()
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // 容器
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        contentView.addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeManager.warning
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.subheadlineFont
        titleLabel.textColor = .white
        containerView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.font = ThemeManager.captionFont
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        subtitleLabel.textAlignment = .right
        containerView.addSubview(subtitleLabel)
        
        setupConstraints()
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
    }
    
    private func loadStorageData() {
        // TODO: 实现存储数据加载
        storageItems = [
            StorageItem(title: "视频文件", size: "1.2 GB", icon: "video.fill"),
            StorageItem(title: "截图文件", size: "156 MB", icon: "photo.fill"),
            StorageItem(title: "缩略图缓存", size: "23.4 MB", icon: "square.grid.2x2.fill"),
            StorageItem(title: "临时文件", size: "8.7 MB", icon: "doc.fill")
        ]
        tableView.reloadData()
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
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
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.size
        cell.imageView?.image = UIImage(systemName: item.icon)
        cell.imageView?.tintColor = ThemeManager.buttonPrimary
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor.white.withAlphaComponent(0.7)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "存储详情"
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = UIColor.white.withAlphaComponent(0.8)
        }
    }
}

struct StorageItem {
    let title: String
    let size: String
    let icon: String
}
