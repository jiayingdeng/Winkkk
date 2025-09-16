//
//  OnboardingViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  引导页面控制器 - 权限申请和功能引导
//

import UIKit
import AVFoundation
import Photos

class OnboardingViewController: UIViewController {
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 页面指示器
    private let pageControl = UIPageControl()
    private var currentPageIndex = 0 {
        didSet {
            updateUI()
        }
    }
    
    // 引导页面内容
    private var onboardingPages: [OnboardingPage] = []
    private var currentPageView: OnboardingPageView?
    
    // 按钮
    private let continueButton = CapsuleButton(title: "继续", style: .primary, size: .medium)
    private let skipButton = UIButton()
    
    // MARK: - Data
    private let onboardingData: [OnboardingPageData] = [
        OnboardingPageData(
            title: "欢迎使用 Winkkk",
            subtitle: "专为爱美的你打造",
            description: "轻松从视频中截取完美瞬间\n让每一帧都成为精彩回忆",
            imageName: "heart.fill",
            backgroundColor: ThemeManager.primaryGradientStart
        ),
        OnboardingPageData(
            title: "录制精彩视频",
            subtitle: "记录美好时光",
            description: "支持高清录制\n内置梦幻滤镜效果",
            imageName: "video.fill",
            backgroundColor: ThemeManager.buttonPrimary
        ),
        OnboardingPageData(
            title: "精准截图时刻",
            subtitle: "捕捉完美瞬间",
            description: "逐帧精确定位\n高质量截图导出",
            imageName: "camera.viewfinder",
            backgroundColor: ThemeManager.success
        ),
        OnboardingPageData(
            title: "智能画质修复",
            subtitle: "让图片更加清晰",
            description: "AI算法优化画质\n轻松获得专业效果",
            imageName: "wand.and.stars",
            backgroundColor: ThemeManager.secondaryText
        ),
        OnboardingPageData(
            title: "一键分享到小红书",
            subtitle: "展示你的精彩",
            description: "支持多平台分享\n可添加专属水印",
            imageName: "square.and.arrow.up",
            backgroundColor: ThemeManager.warning
        )
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🎬 OnboardingViewController: viewDidLoad")
        setupUI()
        setupConstraints()
        setupGestures()
        updateUI()
        print("✅ OnboardingViewController: viewDidLoad completed")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 在布局完成后设置页面，确保view.bounds是正确的
        if onboardingPages.isEmpty {
            setupPages()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🎭 OnboardingViewController: viewDidAppear")
        
        // 添加进入动画
        animatePageEntrance()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        scrollView.addSubview(contentView)
        
        // 页面指示器
        pageControl.numberOfPages = onboardingData.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        view.addSubview(pageControl)
        
        // 继续按钮
        continueButton.setTitle("继续", for: .normal)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        
        // 跳过按钮
        skipButton.setTitle("跳过", for: .normal)
        skipButton.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        skipButton.titleLabel?.font = ThemeManager.bodyFont
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        view.addSubview(skipButton)
    }
    
    private func setupPages() {
        // 确保view有正确的bounds
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            print("⚠️ OnboardingViewController: View bounds not ready, skipping page setup")
            return
        }
        
        onboardingPages.removeAll()
        
        for (index, data) in onboardingData.enumerated() {
            let pageView = OnboardingPageView(data: data)
            pageView.frame = CGRect(
                x: CGFloat(index) * view.bounds.width,
                y: 0,
                width: view.bounds.width,
                height: view.bounds.height - 200 // 留出底部按钮空间
            )
            contentView.addSubview(pageView)
            
            let page = OnboardingPage(view: pageView, data: data)
            onboardingPages.append(page)
        }
        
        contentView.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width * CGFloat(onboardingData.count),
            height: view.bounds.height - 200
        )
        
        scrollView.contentSize = contentView.frame.size
        
        print("✅ OnboardingViewController: Pages setup completed with \(onboardingPages.count) pages")
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            scrollView.heightAnchor.constraint(equalToConstant: view.bounds.height - 200),
            
            // 页面指示器
            pageControl.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 20),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 继续按钮
            continueButton.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 30),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            // continueButton高度由CapsuleButton内部管理，无需重复设置约束
            
            // 跳过按钮
            skipButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 15),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(swipeLeft(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipeRight(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        pageControl.currentPage = currentPageIndex
        
        // 更新按钮文本
        if currentPageIndex == onboardingData.count - 1 {
            continueButton.setTitle("开始使用", for: .normal)
            skipButton.isHidden = true
        } else {
            continueButton.setTitle("继续", for: .normal)
            skipButton.isHidden = false
        }
        
        // 更新背景颜色
        UIView.animate(withDuration: 0.5) {
            self.view.backgroundColor = self.onboardingData[self.currentPageIndex].backgroundColor.withAlphaComponent(0.3)
        }
    }
    
    // MARK: - Actions
    @objc private func continueButtonTapped() {
        if currentPageIndex < onboardingData.count - 1 {
            // 下一页
            currentPageIndex += 1
            scrollToCurrentPage()
        } else {
            // 最后一页，请求权限
            requestPermissions()
        }
    }
    
    @objc private func skipButtonTapped() {
        // 直接请求权限
        requestPermissions()
    }
    
    @objc private func pageControlChanged(_ sender: UIPageControl) {
        currentPageIndex = sender.currentPage
        scrollToCurrentPage()
    }
    
    @objc private func swipeLeft(_ gesture: UISwipeGestureRecognizer) {
        if currentPageIndex < onboardingData.count - 1 {
            currentPageIndex += 1
            scrollToCurrentPage()
        }
    }
    
    @objc private func swipeRight(_ gesture: UISwipeGestureRecognizer) {
        if currentPageIndex > 0 {
            currentPageIndex -= 1
            scrollToCurrentPage()
        }
    }
    
    private func scrollToCurrentPage() {
        let offsetX = CGFloat(currentPageIndex) * scrollView.frame.width
        scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
        
        animatePageTransition()
    }
    
    // MARK: - Animations
    private func animatePageEntrance() {
        guard let currentPage = onboardingPages.first else { return }
        
        AnimationManager.shared.springScale(currentPage.view, fromScale: 0.8, toScale: 1.0)
        AnimationManager.shared.fadeIn(currentPage.view)
    }
    
    private func animatePageTransition() {
        guard currentPageIndex < onboardingPages.count else { return }
        let currentPage = onboardingPages[currentPageIndex]
        
        AnimationManager.shared.springScale(currentPage.view, fromScale: 0.95, toScale: 1.0)
    }
    
    // MARK: - Permission Management
    private func requestPermissions() {
        // 显示权限请求页面
        showPermissionRequest()
    }
    
    private func showPermissionRequest() {
        let permissionVC = PermissionRequestViewController()
        permissionVC.delegate = self
        
        let navController = UINavigationController(rootViewController: permissionVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - Completion
    private func completeOnboarding() {
        // 标记引导完成
        UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
        
        // 跳转到主界面
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate {
            let mainCameraVC = MainCameraViewController()
            let navigationController = UINavigationController(rootViewController: mainCameraVC)
            sceneDelegate.window?.rootViewController = navigationController
        }
    }
}

// MARK: - UIScrollViewDelegate
extension OnboardingViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageIndex = Int(scrollView.contentOffset.x / scrollView.frame.width)
        if pageIndex != currentPageIndex {
            currentPageIndex = pageIndex
            animatePageTransition()
        }
    }
}

// MARK: - PermissionRequestDelegate
extension OnboardingViewController: PermissionRequestDelegate {
    
    func permissionRequestDidComplete() {
        dismiss(animated: true) {
            self.completeOnboarding()
        }
    }
    
    func permissionRequestDidCancel() {
        dismiss(animated: true)
    }
}

// MARK: - Data Structures
struct OnboardingPageData {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let backgroundColor: UIColor
}

struct OnboardingPage {
    let view: OnboardingPageView
    let data: OnboardingPageData
}

// MARK: - OnboardingPageView
class OnboardingPageView: UIView {
    
    private let data: OnboardingPageData
    
    // UI Components
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let decorationView = UIView()
    
    init(data: OnboardingPageData) {
        self.data = data
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
        configureContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 图标
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        addSubview(iconView)
        
        // 装饰视图
        decorationView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        decorationView.layer.cornerRadius = 60
        addSubview(decorationView)
        
        // 标题
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
        titleLabel.font = ThemeManager.titleFont
        titleLabel.numberOfLines = 0
        addSubview(titleLabel)
        
        // 副标题
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.font = ThemeManager.subheadlineFont
        subtitleLabel.numberOfLines = 0
        addSubview(subtitleLabel)
        
        // 描述
        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        descriptionLabel.font = ThemeManager.bodyFont
        descriptionLabel.numberOfLines = 0
        addSubview(descriptionLabel)
    }
    
    private func setupConstraints() {
        [decorationView, iconView, titleLabel, subtitleLabel, descriptionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // 装饰视图
            decorationView.centerXAnchor.constraint(equalTo: centerXAnchor),
            decorationView.topAnchor.constraint(equalTo: topAnchor, constant: 80),
            decorationView.widthAnchor.constraint(equalToConstant: 120),
            decorationView.heightAnchor.constraint(equalToConstant: 120),
            
            // 图标
            iconView.centerXAnchor.constraint(equalTo: decorationView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: decorationView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: decorationView.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            // 副标题
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            // 描述
            descriptionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40)
        ])
    }
    
    private func configureContent() {
        iconView.image = UIImage(systemName: data.imageName)
        titleLabel.text = data.title
        subtitleLabel.text = data.subtitle
        descriptionLabel.text = data.description
        
        // 添加渐变效果到装饰视图
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            data.backgroundColor.withAlphaComponent(0.3).cgColor,
            data.backgroundColor.withAlphaComponent(0.1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        gradientLayer.cornerRadius = 60
        
        decorationView.layer.insertSublayer(gradientLayer, at: 0)
    }
}
