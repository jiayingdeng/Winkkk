//
//  ScreenshotViewSheet.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  截图查看Sheet - 纯查看功能，无操作按钮
//

import UIKit

class ScreenshotViewSheet: UIViewController {
    
    // MARK: - Properties
    private let screenshot: ScreenshotItem
    
    // MARK: - UI Components
    private let gradientBackgroundView = GradientBackgroundView()
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    
    // MARK: - Initialization
    init(screenshot: ScreenshotItem) {
        self.screenshot = screenshot
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureImage()
        
        // 轻微震动反馈
        HapticFeedbackManager.shared.lightImpact()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 渐变背景
        view.addSubview(gradientBackgroundView)
        
        // 滚动视图用于支持缩放
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        // 图像视图
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        scrollView.addSubview(imageView)
        
        // 关闭按钮
        setupCloseButton()
        
        // 添加双击缩放手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
    }
    
    private func setupCloseButton() {
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        closeButton.layer.cornerRadius = 20
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // 添加按压效果
        closeButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        closeButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
        
        view.addSubview(closeButton)
    }
    
    private func setupConstraints() {
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // 图像视图
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // 关闭按钮
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func configureImage() {
        imageView.image = screenshot.image
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        HapticFeedbackManager.shared.buttonTap()
        dismiss(animated: true)
    }
    
    @objc private func buttonPressed(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = .identity
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        HapticFeedbackManager.shared.lightImpact()
        
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let location = gesture.location(in: imageView)
            let rect = CGRect(x: location.x - 50, y: location.y - 50, width: 100, height: 100)
            scrollView.zoom(to: rect, animated: true)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension ScreenshotViewSheet: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 保持图像居中
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                   y: scrollView.contentSize.height * 0.5 + offsetY)
    }
}
