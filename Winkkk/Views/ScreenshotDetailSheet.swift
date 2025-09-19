//
//  ScreenshotDetailSheet.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图详情预览Sheet - 支持左右滑动切换和选择操作
//

import UIKit

protocol ScreenshotDetailSheetDelegate: AnyObject {
    func screenshotDetailSheet(_ sheet: ScreenshotDetailSheet, didSelectScreenshot screenshot: ScreenshotItem, isSelected: Bool)
    func screenshotDetailSheet(_ sheet: ScreenshotDetailSheet, didRequestProcessingCenter selectedScreenshots: [ScreenshotItem])
}

class ScreenshotDetailSheet: UIViewController {
    
    // MARK: - Properties
    weak var delegate: ScreenshotDetailSheetDelegate?
    private let screenshots: [ScreenshotItem]
    private var currentIndex: Int
    private var selectedScreenshots = Set<String>() // 使用ID集合跟踪选中状态
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let navigationBar = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton()
    private let selectButton = UIButton()
    private let bottomActionBar = UIView()
    private let selectedCountLabel = UILabel()
    private let processingCenterButton = UIButton()
    
    // MARK: - Initialization
    init(screenshots: [ScreenshotItem], currentIndex: Int = 0) {
        self.screenshots = screenshots
        self.currentIndex = min(max(currentIndex, 0), screenshots.count - 1)
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupGestures()
        updateUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToCurrentIndex(animated: false)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupNavigationBar()
        setupScrollView()
        setupBottomActionBar()
        
        view.addSubview(navigationBar)
        view.addSubview(scrollView)
        view.addSubview(bottomActionBar)
    }
    
    private func setupNavigationBar() {
        navigationBar.backgroundColor = .systemBackground
        
        // 标题
        titleLabel.text = "\(currentIndex + 1) / \(screenshots.count)"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        // 关闭按钮
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.label, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // 选择按钮
        selectButton.setTitle("选择", for: .normal)
        selectButton.setTitleColor(.systemBlue, for: .normal)
        selectButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        
        navigationBar.addSubview(titleLabel)
        navigationBar.addSubview(closeButton)
        navigationBar.addSubview(selectButton)
    }
    
    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.distribution = .equalSpacing
        
        scrollView.addSubview(stackView)
        
        // 添加截图图片视图
        for screenshot in screenshots {
            let imageView = createImageView(for: screenshot)
            stackView.addArrangedSubview(imageView)
        }
    }
    
    private func setupBottomActionBar() {
        bottomActionBar.backgroundColor = .systemBackground
        
        // 选中数量标签
        selectedCountLabel.text = "已选择 0 张"
        selectedCountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        selectedCountLabel.textColor = .secondaryLabel
        
        // 进入处理中心按钮
        processingCenterButton.setTitle("进入处理中心", for: .normal)
        processingCenterButton.setTitleColor(.white, for: .normal)
        processingCenterButton.backgroundColor = .systemBlue
        processingCenterButton.layer.cornerRadius = 8
        processingCenterButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        processingCenterButton.addTarget(self, action: #selector(processingCenterButtonTapped), for: .touchUpInside)
        processingCenterButton.isEnabled = false
        processingCenterButton.alpha = 0.5
        
        bottomActionBar.addSubview(selectedCountLabel)
        bottomActionBar.addSubview(processingCenterButton)
    }
    
    private func createImageView(for screenshot: ScreenshotItem) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.image = screenshot.image
        
        // 设置固定宽度为屏幕宽度
        imageView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width).isActive = true
        
        return imageView
    }
    
    private func setupConstraints() {
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomActionBar.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        selectedCountLabel.translatesAutoresizingMaskIntoConstraints = false
        processingCenterButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 导航栏
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: 44),
            
            // 导航栏内容
            titleLabel.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            
            closeButton.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            selectButton.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor, constant: -16),
            selectButton.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            selectButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomActionBar.topAnchor),
            
            // StackView
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // 底部操作栏
            bottomActionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomActionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomActionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomActionBar.heightAnchor.constraint(equalToConstant: 60),
            
            // 底部操作栏内容
            selectedCountLabel.leadingAnchor.constraint(equalTo: bottomActionBar.leadingAnchor, constant: 16),
            selectedCountLabel.centerYAnchor.constraint(equalTo: bottomActionBar.centerYAnchor),
            
            processingCenterButton.trailingAnchor.constraint(equalTo: bottomActionBar.trailingAnchor, constant: -16),
            processingCenterButton.centerYAnchor.constraint(equalTo: bottomActionBar.centerYAnchor),
            processingCenterButton.heightAnchor.constraint(equalToConstant: 40),
            processingCenterButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    private func setupGestures() {
        // 双击缩放手势（可选实现）
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func selectButtonTapped() {
        guard currentIndex < screenshots.count else { return }
        
        let screenshot = screenshots[currentIndex]
        let isCurrentlySelected = selectedScreenshots.contains(screenshot.id)
        
        if isCurrentlySelected {
            selectedScreenshots.remove(screenshot.id)
        } else {
            selectedScreenshots.insert(screenshot.id)
        }
        
        delegate?.screenshotDetailSheet(self, didSelectScreenshot: screenshot, isSelected: !isCurrentlySelected)
        updateUI()
    }
    
    @objc private func processingCenterButtonTapped() {
        let selected = screenshots.filter { selectedScreenshots.contains($0.id) }
        delegate?.screenshotDetailSheet(self, didRequestProcessingCenter: selected)
        dismiss(animated: true)
    }
    
    @objc private func doubleTapped() {
        // TODO: 实现双击缩放功能
    }
    
    // MARK: - Helper Methods
    private func updateUI() {
        // 更新标题
        titleLabel.text = "\(currentIndex + 1) / \(screenshots.count)"
        
        // 更新选择按钮
        guard currentIndex < screenshots.count else { return }
        let screenshot = screenshots[currentIndex]
        let isSelected = selectedScreenshots.contains(screenshot.id)
        selectButton.setTitle(isSelected ? "取消选择" : "选择", for: .normal)
        selectButton.setTitleColor(isSelected ? .systemOrange : .systemBlue, for: .normal)
        
        // 更新底部操作栏
        let selectedCount = selectedScreenshots.count
        selectedCountLabel.text = "已选择 \(selectedCount) 张"
        
        processingCenterButton.isEnabled = selectedCount > 0
        processingCenterButton.alpha = selectedCount > 0 ? 1.0 : 0.5
    }
    
    private func scrollToCurrentIndex(animated: Bool) {
        let offsetX = CGFloat(currentIndex) * scrollView.frame.width
        scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
    }
    
    // MARK: - Public Methods
    func setSelectedScreenshots(_ selected: Set<String>) {
        selectedScreenshots = selected
        updateUI()
    }
}

// MARK: - UIScrollViewDelegate
extension ScreenshotDetailSheet: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.frame.width
        let newIndex = Int(scrollView.contentOffset.x / pageWidth)
        
        if newIndex != currentIndex && newIndex >= 0 && newIndex < screenshots.count {
            currentIndex = newIndex
            updateUI()
        }
    }
}
