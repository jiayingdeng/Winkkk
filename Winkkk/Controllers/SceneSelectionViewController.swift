//
//  SceneSelectionViewController.swift
//  Winkkk
//
//  Created by AI Assistant on 2024/09/20.
//

import UIKit

/// 场景选择界面代理协议
protocol SceneSelectionViewControllerDelegate: AnyObject {
    func sceneSelectionViewController(_ controller: SceneSelectionViewController, didSelectScene sceneType: SceneType)
    func sceneSelectionViewControllerDidCancel(_ controller: SceneSelectionViewController)
}

/// 场景选择界面 - 选择时间序列录像场景类型
class SceneSelectionViewController: UIViewController {
    
    // MARK: - 代理
    weak var delegate: SceneSelectionViewControllerDelegate?
    
    // MARK: - UI组件
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "⏰ 选择录像场景"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "不同场景有不同的拍摄技巧，选择最合适的类型"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - 新增：时间序列模式说明区域
    private let modeInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        return view
    }()
    
    private let modeInfoTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "💡 时间序列录像模式"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .systemBlue
        label.textAlignment = .center
        return label
    }()
    
    private let modeInfoContentLabel: UILabel = {
        let label = UILabel()
        label.text = "• 记录运动轨迹过程，创建动态艺术效果图\n• 需要固定拍摄位置\n• 适合：人物动作、宠物活动、运动轨迹、舞蹈表演"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .label
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.distribution = .fill
        stack.alignment = .fill
        return stack
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        return button
    }()
    
    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        createSceneCards()
        setupActions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateCardsAppearance()
    }
    
    // MARK: - UI设置
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(modeInfoView)
        contentView.addSubview(stackView)
        contentView.addSubview(cancelButton)
        
        // 添加模式说明内容
        modeInfoView.addSubview(modeInfoTitleLabel)
        modeInfoView.addSubview(modeInfoContentLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        modeInfoView.translatesAutoresizingMaskIntoConstraints = false
        modeInfoTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        modeInfoContentLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // TitleLabel
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // SubtitleLabel
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // ModeInfoView
            modeInfoView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            modeInfoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            modeInfoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // ModeInfoTitleLabel
            modeInfoTitleLabel.topAnchor.constraint(equalTo: modeInfoView.topAnchor, constant: 12),
            modeInfoTitleLabel.leadingAnchor.constraint(equalTo: modeInfoView.leadingAnchor, constant: 16),
            modeInfoTitleLabel.trailingAnchor.constraint(equalTo: modeInfoView.trailingAnchor, constant: -16),
            
            // ModeInfoContentLabel
            modeInfoContentLabel.topAnchor.constraint(equalTo: modeInfoTitleLabel.bottomAnchor, constant: 8),
            modeInfoContentLabel.leadingAnchor.constraint(equalTo: modeInfoView.leadingAnchor, constant: 16),
            modeInfoContentLabel.trailingAnchor.constraint(equalTo: modeInfoView.trailingAnchor, constant: -16),
            modeInfoContentLabel.bottomAnchor.constraint(equalTo: modeInfoView.bottomAnchor, constant: -12),
            
            // StackView
            stackView.topAnchor.constraint(equalTo: modeInfoView.bottomAnchor, constant: 30),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // CancelButton
            cancelButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),
            cancelButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            cancelButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - 创建场景卡片
    private func createSceneCards() {
        // 只显示运动轨迹选项，隐藏物体变化和人物动作
        let availableScenes: [SceneType] = [.sportMotion]
        
        for sceneType in availableScenes {
            let cardView = createSceneCard(for: sceneType)
            stackView.addArrangedSubview(cardView)
        }
    }
    
    private func createSceneCard(for sceneType: SceneType) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.secondarySystemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.layer.shadowOpacity = 0.1
        
        // 图标
        let iconLabel = UILabel()
        iconLabel.text = sceneType.icon
        iconLabel.font = UIFont.systemFont(ofSize: 40)
        iconLabel.textAlignment = .center
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = sceneType.displayName
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        // 描述
        let descLabel = UILabel()
        descLabel.text = sceneType.description
        descLabel.font = UIFont.systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        
        // 难度标签
        let difficultyLabel = UILabel()
        difficultyLabel.text = sceneType.difficultyText
        difficultyLabel.font = UIFont.systemFont(ofSize: 12)
        difficultyLabel.textColor = .tertiaryLabel
        difficultyLabel.textAlignment = .center
        
        // 推荐标签（仅对新手推荐的场景显示）
        let recommendedBadge = UIView()
        if sceneType.isRecommendedForBeginners {
            recommendedBadge.backgroundColor = UIColor.systemGreen
            recommendedBadge.layer.cornerRadius = 12
            
            let badgeLabel = UILabel()
            badgeLabel.text = "推荐新手"
            badgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            badgeLabel.textColor = .white
            badgeLabel.textAlignment = .center
            
            recommendedBadge.addSubview(badgeLabel)
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                badgeLabel.centerXAnchor.constraint(equalTo: recommendedBadge.centerXAnchor),
                badgeLabel.centerYAnchor.constraint(equalTo: recommendedBadge.centerYAnchor),
                recommendedBadge.widthAnchor.constraint(equalToConstant: 80),
                recommendedBadge.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        // 布局
        cardView.addSubview(iconLabel)
        cardView.addSubview(titleLabel)
        cardView.addSubview(descLabel)
        cardView.addSubview(difficultyLabel)
        if sceneType.isRecommendedForBeginners {
            cardView.addSubview(recommendedBadge)
        }
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        difficultyLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendedBadge.translatesAutoresizingMaskIntoConstraints = false
        
        var constraints = [
            // 图标
            iconLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            iconLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            // 描述
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            // 难度
            difficultyLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 16),
            difficultyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            difficultyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            // 卡片最小高度 (增加了空间以适应内容)
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ]
        
        // 推荐标签约束
        if sceneType.isRecommendedForBeginners {
            constraints.append(contentsOf: [
                recommendedBadge.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
                recommendedBadge.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12)
            ])
        }
        
        // 确保难度标签始终固定在底部
        constraints.append(
            difficultyLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        )
        
        NSLayoutConstraint.activate(constraints)
        
        // 点击事件
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(sceneCardTapped(_:)))
        cardView.addGestureRecognizer(tapGesture)
        cardView.tag = SceneType.allCases.firstIndex(of: sceneType) ?? 0
        
        // 初始动画状态
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        return cardView
    }
    
    // MARK: - 事件处理
    private func setupActions() {
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    }
    
    @objc private func sceneCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view else { return }
        let sceneType = SceneType.allCases[cardView.tag]
        
        // 卡片点击动画
        UIView.animate(withDuration: 0.1, animations: {
            cardView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                cardView.transform = .identity
            }
        }
        
        // 延迟选择以显示动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.selectScene(sceneType)
        }
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.sceneSelectionViewControllerDidCancel(self)
    }
    
    // MARK: - 场景选择
    private func selectScene(_ sceneType: SceneType) {
        // 显示选择确认
        let alert = UIAlertController(
            title: "\(sceneType.icon) \(sceneType.displayName)",
            message: "确认选择这个场景类型吗？\n\n\(sceneType.description)\n\n\(sceneType.difficultyText)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "查看拍摄指导", style: .default) { _ in
            self.showShootingGuide(for: sceneType)
        })
        
        alert.addAction(UIAlertAction(title: "直接开始录像", style: .default) { _ in
            self.delegate?.sceneSelectionViewController(self, didSelectScene: sceneType)
        })
        
        alert.addAction(UIAlertAction(title: "重新选择", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - 拍摄指导
    private func showShootingGuide(for sceneType: SceneType) {
        let guide = ShootingGuide.guide(for: sceneType)
        
        let alert = UIAlertController(
            title: "🎬 \(sceneType.displayName) 拍摄指导",
            message: createGuideMessage(guide),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "开始录像", style: .default) { _ in
            self.delegate?.sceneSelectionViewController(self, didSelectScene: sceneType)
        })
        
        alert.addAction(UIAlertAction(title: "返回选择", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func createGuideMessage(_ guide: ShootingGuide) -> String {
        var message = "\(guide.duration)\n\n📝 拍摄要点：\n"
        for (index, tip) in guide.tips.enumerated() {
            message += "\(index + 1). \(tip)\n"
        }
        
        message += "\n🔧 准备步骤：\n"
        for (index, instruction) in guide.setupInstructions.enumerated() {
            message += "\(index + 1). \(instruction)\n"
        }
        
        return message
    }
    
    // MARK: - 动画
    private func animateCardsAppearance() {
        let cards = stackView.arrangedSubviews
        
        for (index, card) in cards.enumerated() {
            let delay = Double(index) * 0.1
            
            UIView.animate(
                withDuration: 0.5,
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

// MARK: - 扩展：便利初始化

extension SceneSelectionViewController {
    
    /// 便利初始化方法
    /// - Parameter delegate: 代理对象
    /// - Returns: 配置好的场景选择控制器
    static func create(delegate: SceneSelectionViewControllerDelegate? = nil) -> SceneSelectionViewController {
        let controller = SceneSelectionViewController()
        controller.delegate = delegate
        return controller
    }
    
    /// 以模态方式展示
    /// - Parameters:
    ///   - parent: 父控制器
    ///   - delegate: 代理对象
    static func presentModal(from parent: UIViewController, delegate: SceneSelectionViewControllerDelegate? = nil) {
        let controller = create(delegate: delegate)
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
