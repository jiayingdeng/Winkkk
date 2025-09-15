//
//  VideoPlayerViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频播放编辑视图控制器 - 占位符实现
//

import UIKit
import AVFoundation

class VideoPlayerViewController: UIViewController {
    
    // MARK: - Properties
    private let videoURL: URL
    
    // MARK: - Initialization
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = ThemeManager.background
        title = "视频编辑"
        
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // 临时占位符标签
        let placeholderLabel = UILabel()
        placeholderLabel.text = "视频播放器界面\n(待实现)"
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        placeholderLabel.font = ThemeManager.headlineFont
        placeholderLabel.textColor = ThemeManager.primaryText
        
        view.addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}
