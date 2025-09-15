//
//  SettingsViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  设置视图控制器 - 占位符实现
//

import UIKit

class SettingsViewController: UIViewController {
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = ThemeManager.background
        title = "设置"
        
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // 临时占位符标签
        let placeholderLabel = UILabel()
        placeholderLabel.text = "设置界面\n(待实现)"
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
