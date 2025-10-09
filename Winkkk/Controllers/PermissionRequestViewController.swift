//
//  PermissionRequestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  权限请求视图控制器
//

import UIKit
import AVFoundation
import Photos

protocol PermissionRequestDelegate: AnyObject {
    func permissionRequestDidComplete()
    func permissionRequestDidCancel()
}

class PermissionRequestViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: PermissionRequestDelegate?
    
    // MARK: - Dependencies
    private let hapticManager = HapticFeedbackManager.shared
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Permission Cards
    private var permissionCards: [PermissionCard] = []
    private let stackView = UIStackView()
    
    // Button
    private let continueButton = CapsuleButton(title: "继续", style: .primary, size: .medium)
    private let laterButton = UIButton()
    
    // MARK: - Permission Data
    private let permissions: [PermissionData] = [
        PermissionData(
            type: .camera,
            title: "相机权限",
            description: "录制精彩视频，捕捉美好瞬间",
            iconName: "camera.fill",
            color: ThemeManager.buttonPrimary,
            isRequired: true
        ),
        PermissionData(
            type: .microphone,
            title: "麦克风权限",
            description: "录制带声音的视频，记录完整回忆",
            iconName: "mic.fill",
            color: ThemeManager.success,
            isRequired: true
        ),
        PermissionData(
            type: .photoLibrary,
            title: "相册权限",
            description: "保存和导入视频，管理你的作品",
            iconName: "photo.fill",
            color: ThemeManager.warning,
            isRequired: false
        )
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupPermissionCards()
        checkExistingPermissions()
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
        
        // 标题
        titleLabel.text = "应用需要以下权限"
        titleLabel.textColor = ThemeManager.overlayTextWhite
        titleLabel.font = ThemeManager.titleFont
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.text = "为了给您提供最佳体验，\n请允许以下权限"
        subtitleLabel.textColor = ThemeManager.overlaySecondaryText
        subtitleLabel.font = ThemeManager.bodyFont
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        contentView.addSubview(subtitleLabel)
        
        // 权限卡片容器
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fillEqually
        contentView.addSubview(stackView)
        
        // 继续按钮
        continueButton.setTitle("授予权限", for: .normal)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        contentView.addSubview(continueButton)
        
        // 稍后按钮
        laterButton.setTitle("稍后再说", for: .normal)
        laterButton.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        laterButton.titleLabel?.font = ThemeManager.bodyFont
        laterButton.addTarget(self, action: #selector(laterButtonTapped), for: .touchUpInside)
        contentView.addSubview(laterButton)
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        laterButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            
            // 副标题
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            
            // 权限卡片
            stackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 继续按钮
            continueButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            // continueButton高度由CapsuleButton内部管理，无需重复设置约束
            
            // 稍后按钮
            laterButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 15),
            laterButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            laterButton.heightAnchor.constraint(equalToConstant: 30),
            laterButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupPermissionCards() {
        permissionCards.removeAll()
        
        for permission in permissions {
            let card = PermissionCard(permission: permission)
            card.delegate = self
            permissionCards.append(card)
            stackView.addArrangedSubview(card)
            
            card.heightAnchor.constraint(equalToConstant: 80).isActive = true
        }
    }
    
    // MARK: - Permission Checking
    private func checkExistingPermissions() {
        for card in permissionCards {
            card.updatePermissionStatus()
        }
        
        updateContinueButton()
    }
    
    private func updateContinueButton() {
        let allRequiredGranted = permissionCards
            .filter { $0.permission.isRequired }
            .allSatisfy { $0.isPermissionGranted }
        
        if allRequiredGranted {
            continueButton.setTitle("开始使用", for: .normal)
            continueButton.backgroundColor = ThemeManager.success
        } else {
            continueButton.setTitle("授予权限", for: .normal)
            continueButton.backgroundColor = ThemeManager.buttonPrimary
        }
    }
    
    // MARK: - Actions
    @objc private func continueButtonTapped() {
        hapticManager.trigger(.medium)
        requestAllPermissions()
    }
    
    @objc private func laterButtonTapped() {
        hapticManager.trigger(.light)
        delegate?.permissionRequestDidCancel()
    }
    
    private func requestAllPermissions() {
        let deniedCards = permissionCards.filter { !$0.isPermissionGranted }
        
        if deniedCards.isEmpty {
            // 所有权限都已获得
            delegate?.permissionRequestDidComplete()
            return
        }
        
        // 逐个请求权限
        requestNextPermission(from: deniedCards, index: 0)
    }
    
    private func requestNextPermission(from cards: [PermissionCard], index: Int) {
        guard index < cards.count else {
            // 所有权限请求完成
            checkExistingPermissions()
            
            // 检查必需权限是否都已获得
            let allRequiredGranted = permissionCards
                .filter { $0.permission.isRequired }
                .allSatisfy { $0.isPermissionGranted }
            
            if allRequiredGranted {
                delegate?.permissionRequestDidComplete()
            } else {
                showPermissionDeniedAlert()
            }
            return
        }
        
        let card = cards[index]
        card.requestPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.hapticManager.trigger(.success)
                } else {
                    self?.hapticManager.trigger(.warning)
                }
                self?.requestNextPermission(from: cards, index: index + 1)
            }
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "权限需求",
            message: "应用需要相机和麦克风权限才能正常工作。您可以稍后在设置中启用这些权限。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "稍后", style: .cancel) { [weak self] _ in
            self?.delegate?.permissionRequestDidCancel()
        })
        
        present(alert, animated: true)
    }
}

// MARK: - PermissionCardDelegate
extension PermissionRequestViewController: PermissionCardDelegate {
    
    func permissionCardDidRequestPermission(_ card: PermissionCard) {
        card.requestPermission { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateContinueButton()
            }
        }
    }
}

// MARK: - Permission Data Structure
struct PermissionData {
    let type: PermissionType
    let title: String
    let description: String
    let iconName: String
    let color: UIColor
    let isRequired: Bool
}

enum PermissionType {
    case camera
    case microphone
    case photoLibrary
}

// MARK: - Permission Card
protocol PermissionCardDelegate: AnyObject {
    func permissionCardDidRequestPermission(_ card: PermissionCard)
}

class PermissionCard: UIView {
    
    // MARK: - Properties
    let permission: PermissionData
    weak var delegate: PermissionCardDelegate?
    
    private let containerView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let statusView = UIView()
    private let statusLabel = UILabel()
    
    var isPermissionGranted: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - Initialization
    init(permission: PermissionData) {
        self.permission = permission
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
        setupGestures()
        configureContent()
        updatePermissionStatus()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 容器
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        addSubview(containerView)
        
        // 图标
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = permission.color
        containerView.addSubview(iconView)
        
        // 标题
        titleLabel.textColor = ThemeManager.overlayTextWhite
        titleLabel.font = ThemeManager.subheadlineFont
        containerView.addSubview(titleLabel)
        
        // 描述
        descriptionLabel.textColor = ThemeManager.overlaySecondaryText
        descriptionLabel.font = ThemeManager.captionFont
        descriptionLabel.numberOfLines = 2
        containerView.addSubview(descriptionLabel)
        
        // 状态视图
        statusView.layer.cornerRadius = 8
        containerView.addSubview(statusView)
        
        // 状态标签
        statusLabel.textColor = ThemeManager.overlayTextWhite
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textAlignment = .center
        statusView.addSubview(statusLabel)
    }
    
    private func setupConstraints() {
        [containerView, iconView, titleLabel, descriptionLabel, statusView, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // 容器
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 图标
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: -16),
            
            // 描述
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            
            // 状态视图
            statusView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            statusView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusView.widthAnchor.constraint(equalToConstant: 60),
            statusView.heightAnchor.constraint(equalToConstant: 24),
            
            // 状态标签
            statusLabel.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor)
        ])
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        addGestureRecognizer(tapGesture)
    }
    
    private func configureContent() {
        iconView.image = UIImage(systemName: permission.iconName)
        titleLabel.text = permission.title
        descriptionLabel.text = permission.description
    }
    
    // MARK: - Permission Status
    func updatePermissionStatus() {
        switch permission.type {
        case .camera:
            isPermissionGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphone:
            isPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .photoLibrary:
            isPermissionGranted = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ||
                                 PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
        }
    }
    
    private func updateUI() {
        UIView.animate(withDuration: 0.3) {
            if self.isPermissionGranted {
                self.statusView.backgroundColor = ThemeManager.success
                self.statusLabel.text = "已授权"
                self.containerView.layer.borderColor = ThemeManager.success.withAlphaComponent(0.5).cgColor
            } else {
                self.statusView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
                self.statusLabel.text = self.permission.isRequired ? "需要" : "可选"
                self.containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            }
        }
    }
    
    // MARK: - Permission Request
    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch permission.type {
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isPermissionGranted = granted
                    completion(granted)
                }
            }
            
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isPermissionGranted = granted
                    completion(granted)
                }
            }
            
        case .photoLibrary:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    let granted = status == .authorized || status == .limited
                    self?.isPermissionGranted = granted
                    completion(granted)
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func cardTapped() {
        if !isPermissionGranted {
            HapticFeedbackManager.shared.trigger(.light)
            delegate?.permissionCardDidRequestPermission(self)
        }
    }
}
