//
//  SAMSegmentationTestViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  SAM分割测试主页面 - 提供分类选择界面
//

import UIKit
import PhotosUI

class SAMSegmentationTestViewController: UIViewController {
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let collectionView: UICollectionView
    
    // MARK: - Data
    private let categories: [SAMTestCategory] = [
        SAMTestCategory(
            id: "plants",
            title: "🌱 植物类",
            subtitle: "花朵、叶子、树木",
            icon: "leaf.fill",
            color: UIColor.systemGreen
        ),
        SAMTestCategory(
            id: "food",
            title: "🍎 食品类",
            subtitle: "水果、蔬菜、食物",
            icon: "fork.knife",
            color: UIColor.systemOrange
        ),
        SAMTestCategory(
            id: "jewelry",
            title: "💎 首饰类",
            subtitle: "戒指、项链、手表",
            icon: "sparkles",
            color: UIColor.systemPurple
        ),
        SAMTestCategory(
            id: "people",
            title: "👤 人物类",
            subtitle: "人脸、人体、手部",
            icon: "person.fill",
            color: UIColor.systemBlue
        ),
        SAMTestCategory(
            id: "animals",
            title: "🐾 动物类",
            subtitle: "宠物、野生动物",
            icon: "pawprint.fill",
            color: UIColor.systemBrown
        ),
        SAMTestCategory(
            id: "dailyItems",
            title: "🏠 日用品类",
            subtitle: "家具、电子产品",
            icon: "house.fill",
            color: UIColor.systemCyan
        ),
        SAMTestCategory(
            id: "vehicles",
            title: "🚗 交通工具",
            subtitle: "汽车、自行车",
            icon: "car.fill",
            color: UIColor.systemRed
        ),
        SAMTestCategory(
            id: "misc",
            title: "🎲 其他物体",
            subtitle: "综合测试",
            icon: "questionmark.circle.fill",
            color: UIColor.systemGray
        )
    ]
    
    // MARK: - Lifecycle
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        // 设置collection view layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
        
        // 内容视图
        scrollView.addSubview(contentView)
        
        // 标题
        titleLabel.text = "🎯 SAM分割测试"
        titleLabel.font = ThemeManager.headlineFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.text = "选择物体类别开始测试MobileSAM分割效果"
        subtitleLabel.font = ThemeManager.subheadlineFont
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        contentView.addSubview(subtitleLabel)
        
        // 集合视图
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(SAMCategoryCell.self, forCellWithReuseIdentifier: SAMCategoryCell.identifier)
        collectionView.showsVerticalScrollIndicator = false
        contentView.addSubview(collectionView)
    }
    
    private func setupNavigationBar() {
        title = "SAM分割测试"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // 帮助按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"),
            style: .plain,
            target: self,
            action: #selector(helpButtonTapped)
        )
    }
    
    private func setupConstraints() {
        [gradientBackgroundView, scrollView, contentView, titleLabel, subtitleLabel, collectionView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
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
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 副标题
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 集合视图
            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 600) // 临时高度
        ])
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func helpButtonTapped() {
        let alert = UIAlertController(
            title: "SAM分割测试说明",
            message: "1. 选择物体类别\n2. 从相册选择图片\n3. 自动分割主体物体\n4. 查看分割结果\n5. 保存或分享结果",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "了解", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Category Selection
    private func handleCategorySelection(_ category: SAMTestCategory) {
        print("🎯 选择分类: \(category.title)")
        
        // 创建图片选择器
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        
        // 保存当前选择的分类
        picker.view.tag = categories.firstIndex(where: { $0.id == category.id }) ?? 0
        
        present(picker, animated: true)
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate
extension SAMSegmentationTestViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SAMCategoryCell.identifier, for: indexPath) as! SAMCategoryCell
        cell.configure(with: categories[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let category = categories[indexPath.item]
        handleCategorySelection(category)
        
        // 添加选择动画
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.1, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    cell.transform = .identity
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 40 // 左右各20
        let itemSpacing: CGFloat = 16
        let availableWidth = collectionView.frame.width - padding - itemSpacing
        let itemWidth = availableWidth / 2
        
        return CGSize(width: itemWidth, height: 120)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension SAMSegmentationTestViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        let categoryIndex = picker.view.tag
        let selectedCategory = categories[categoryIndex]
        
        // 获取图片
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (object, error) in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.processSelectedImage(image, category: selectedCategory)
                } else if let error = error {
                    self?.showError("无法加载图片: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func processSelectedImage(_ image: UIImage, category: SAMTestCategory) {
        print("🖼️ 开始处理图片，分类: \(category.title)")
        
        // 跳转到处理页面
        let processingVC = SAMProcessingViewController(image: image, category: category)
        navigationController?.pushViewController(processingVC, animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - SAMTestCategory
struct SAMTestCategory {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: UIColor
}

// MARK: - SAMCategoryCell
class SAMCategoryCell: UICollectionViewCell {
    static let identifier = "SAMCategoryCell"
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = containerView.bounds
    }
    
    private func setupUI() {
        // 容器
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        
        // 渐变背景
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.2).cgColor,
            UIColor.white.withAlphaComponent(0.05).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        containerView.layer.insertSublayer(gradientLayer, at: 0)
        
        contentView.addSubview(containerView)
        
        // 图标
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        containerView.addSubview(iconImageView)
        
        // 标题
        titleLabel.font = ThemeManager.subheadlineFont
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        containerView.addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.font = ThemeManager.captionFont
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        containerView.addSubview(subtitleLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        [containerView, iconImageView, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with category: SAMTestCategory) {
        iconImageView.image = UIImage(systemName: category.icon)
        titleLabel.text = category.title
        subtitleLabel.text = category.subtitle
        
        // 更新渐变颜色
        gradientLayer.colors = [
            category.color.withAlphaComponent(0.3).cgColor,
            category.color.withAlphaComponent(0.1).cgColor
        ]
        
        iconImageView.tintColor = category.color.withAlphaComponent(0.9)
    }
}


