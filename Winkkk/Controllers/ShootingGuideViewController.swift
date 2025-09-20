//
//  ShootingGuideViewController.swift
//  Winkkk
//
//  Created by AI Assistant on 2024/09/20.
//

import UIKit
import AVKit

/// 拍摄指导界面代理协议
protocol ShootingGuideViewControllerDelegate: AnyObject {
    func shootingGuideViewControllerDidStartRecording(_ controller: ShootingGuideViewController)
    func shootingGuideViewControllerDidCancel(_ controller: ShootingGuideViewController)
}

/// 拍摄指导界面 - 根据场景显示具体拍摄指导
class ShootingGuideViewController: UIViewController {
    
    // MARK: - 代理和数据
    weak var delegate: ShootingGuideViewControllerDelegate?
    private let sceneType: SceneType
    private let shootingGuide: ShootingGuide
    
    // MARK: - UI组件
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let sceneIconLabel = UILabel()
    private let sceneTitleLabel = UILabel()
    private let difficultyLabel = UILabel()
    
    private let durationCard = UIView()
    private let tipsCard = UIView()
    private let setupCard = UIView()
    
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemRed
        button.setTitle("🎬 开始录像", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 25
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return button
    }()
    
    // MARK: - 初始化
    init(sceneType: SceneType) {
        self.sceneType = sceneType
        self.shootingGuide = ShootingGuide.guide(for: sceneType)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupContent()
        setupActions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateContentAppearance()
    }
    
    // MARK: - UI设置
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupScrollView()
        setupHeaderView()
        setupCards()
        setupButtons()
        setupConstraints()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = UIColor.secondarySystemBackground
        headerView.layer.cornerRadius = 16
        
        sceneIconLabel.font = UIFont.systemFont(ofSize: 60)
        sceneIconLabel.textAlignment = .center
        
        sceneTitleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        sceneTitleLabel.textColor = .label
        sceneTitleLabel.textAlignment = .center
        
        difficultyLabel.font = UIFont.systemFont(ofSize: 16)
        difficultyLabel.textColor = .secondaryLabel
        difficultyLabel.textAlignment = .center
        
        headerView.addSubview(sceneIconLabel)
        headerView.addSubview(sceneTitleLabel)
        headerView.addSubview(difficultyLabel)
    }
    
    private func setupCards() {
        // 时长卡片
        durationCard.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        durationCard.layer.cornerRadius = 12
        durationCard.layer.borderWidth = 1
        durationCard.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        
        // 技巧卡片
        tipsCard.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        tipsCard.layer.cornerRadius = 12
        tipsCard.layer.borderWidth = 1
        tipsCard.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        // 准备卡片
        setupCard.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        setupCard.layer.cornerRadius = 12
        setupCard.layer.borderWidth = 1
        setupCard.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
    }
    
    private func setupButtons() {
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        let allViews = [headerView, durationCard, tipsCard, setupCard, startButton, cancelButton]
        allViews.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        let headerSubviews = [sceneIconLabel, sceneTitleLabel, difficultyLabel]
        headerSubviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // HeaderView
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 180),
            
            // HeaderView内容
            sceneIconLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            sceneIconLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            sceneTitleLabel.topAnchor.constraint(equalTo: sceneIconLabel.bottomAnchor, constant: 12),
            sceneTitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            sceneTitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            difficultyLabel.topAnchor.constraint(equalTo: sceneTitleLabel.bottomAnchor, constant: 8),
            difficultyLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            difficultyLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            difficultyLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // DurationCard
            durationCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            durationCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            durationCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // TipsCard
            tipsCard.topAnchor.constraint(equalTo: durationCard.bottomAnchor, constant: 16),
            tipsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tipsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // SetupCard
            setupCard.topAnchor.constraint(equalTo: tipsCard.bottomAnchor, constant: 16),
            setupCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            setupCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // StartButton
            startButton.topAnchor.constraint(equalTo: setupCard.bottomAnchor, constant: 32),
            startButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            
            // CancelButton
            cancelButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - 内容设置
    private func setupContent() {
        // 头部内容
        sceneIconLabel.text = sceneType.icon
        sceneTitleLabel.text = sceneType.displayName
        difficultyLabel.text = sceneType.difficultyText
        
        // 创建卡片内容
        createDurationCard()
        createTipsCard()
        createSetupCard()
        
        // 初始动画状态
        let allCards = [headerView, durationCard, tipsCard, setupCard, startButton, cancelButton]
        allCards.forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 30)
        }
    }
    
    private func createDurationCard() {
        let titleLabel = createCardTitleLabel("⏱️ 录制时长", color: .systemGreen)
        let contentLabel = createCardContentLabel(shootingGuide.duration)
        
        durationCard.addSubview(titleLabel)
        durationCard.addSubview(contentLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: durationCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: durationCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func createTipsCard() {
        let titleLabel = createCardTitleLabel("💡 拍摄要点", color: .systemBlue)
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        
        for (index, tip) in shootingGuide.tips.enumerated() {
            let tipLabel = createCardContentLabel("\(index + 1). \(tip)")
            tipLabel.numberOfLines = 0
            stackView.addArrangedSubview(tipLabel)
        }
        
        tipsCard.addSubview(titleLabel)
        tipsCard.addSubview(stackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: tipsCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: tipsCard.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: tipsCard.trailingAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: tipsCard.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: tipsCard.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: tipsCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func createSetupCard() {
        let titleLabel = createCardTitleLabel("🔧 准备步骤", color: .systemOrange)
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        
        for (index, instruction) in shootingGuide.setupInstructions.enumerated() {
            let instructionLabel = createCardContentLabel("\(index + 1). \(instruction)")
            instructionLabel.numberOfLines = 0
            stackView.addArrangedSubview(instructionLabel)
        }
        
        setupCard.addSubview(titleLabel)
        setupCard.addSubview(stackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: setupCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: setupCard.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: setupCard.trailingAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: setupCard.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: setupCard.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: setupCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func createCardTitleLabel(_ text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = color
        return label
    }
    
    private func createCardContentLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }
    
    // MARK: - 事件处理
    private func setupActions() {
        // 添加长按手势显示高级设置
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        startButton.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func startButtonTapped() {
        // 按钮动画
        UIView.animate(withDuration: 0.1, animations: {
            self.startButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.startButton.transform = .identity
            }
        }
        
        // 延迟执行以显示动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.startRecording()
        }
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.shootingGuideViewControllerDidCancel(self)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            showAdvancedSettings()
        }
    }
    
    // MARK: - 录像相关
    private func startRecording() {
        // 显示最后确认
        let alert = UIAlertController(
            title: "🎬 准备就绪！",
            message: "确认已按照指导完成准备？\n\n点击\"开始\"将跳转到录像界面",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "开始录像", style: .default) { _ in
            // 设置场景模式
            TimeSequenceModeManager.shared.switchToTimeSequenceMode(with: self.sceneType)
            self.delegate?.shootingGuideViewControllerDidStartRecording(self)
        })
        
        alert.addAction(UIAlertAction(title: "再检查一下", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showAdvancedSettings() {
        let alert = UIAlertController(
            title: "⚙️ 高级设置",
            message: "可以调整时间序列处理参数",
            preferredStyle: .actionSheet
        )
        
        let parameters = TimeSequenceParameters.defaultParameters(for: sceneType)
        
        alert.addAction(UIAlertAction(title: "帧间隔: \(parameters.frameInterval)秒", style: .default) { _ in
            self.adjustFrameInterval()
        })
        
        alert.addAction(UIAlertAction(title: "最大帧数: \(parameters.totalFrames)", style: .default) { _ in
            self.adjustTotalFrames()
        })
        
        alert.addAction(UIAlertAction(title: "处理模式: \(parameters.processingMode)", style: .default) { _ in
            self.adjustProcessingMode()
        })
        
        alert.addAction(UIAlertAction(title: "恢复默认", style: .destructive) { _ in
            let defaultParams = TimeSequenceParameters.defaultParameters(for: self.sceneType)
            TimeSequenceModeManager.shared.updateProcessingParameters(defaultParams)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = startButton
            popover.sourceRect = startButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - 参数调整方法
    private func adjustFrameInterval() {
        // 这里可以实现帧间隔调整逻辑
        showSimpleAlert(title: "帧间隔调整", message: "此功能正在开发中")
    }
    
    private func adjustTotalFrames() {
        // 这里可以实现总帧数调整逻辑
        showSimpleAlert(title: "总帧数调整", message: "此功能正在开发中")
    }
    
    private func adjustProcessingMode() {
        // 这里可以实现处理模式调整逻辑
        showSimpleAlert(title: "处理模式调整", message: "此功能正在开发中")
    }
    
    private func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - 动画
    private func animateContentAppearance() {
        let allCards = [headerView, durationCard, tipsCard, setupCard, startButton, cancelButton]
        
        for (index, card) in allCards.enumerated() {
            let delay = Double(index) * 0.1
            
            UIView.animate(
                withDuration: 0.6,
                delay: delay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [],
                animations: {
                    card.alpha = 1
                    card.transform = .identity
                }
            )
        }
    }
}

// MARK: - 扩展：便利方法

extension ShootingGuideViewController {
    
    /// 便利初始化方法
    /// - Parameters:
    ///   - sceneType: 场景类型
    ///   - delegate: 代理对象
    /// - Returns: 配置好的拍摄指导控制器
    static func create(sceneType: SceneType, delegate: ShootingGuideViewControllerDelegate? = nil) -> ShootingGuideViewController {
        let controller = ShootingGuideViewController(sceneType: sceneType)
        controller.delegate = delegate
        return controller
    }
    
    /// 以模态方式展示
    /// - Parameters:
    ///   - parent: 父控制器
    ///   - sceneType: 场景类型
    ///   - delegate: 代理对象
    static func presentModal(from parent: UIViewController, sceneType: SceneType, delegate: ShootingGuideViewControllerDelegate? = nil) {
        let controller = create(sceneType: sceneType, delegate: delegate)
        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .pageSheet
        
        if #available(iOS 15.0, *) {
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        parent.present(navController, animated: true)
    }
}
