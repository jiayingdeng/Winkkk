//
//  BatchSelectionToolbar.swift
//  Winkkk
//
//  Created on 2025-01-19.
//

import UIKit

/// 批量选择工具栏
class BatchSelectionToolbar: UIView {
    
    // MARK: - Properties
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?
    var onDelete: (() -> Void)?
    var onShare: (() -> Void)?
    var onCancel: (() -> Void)?
    
    private var selectedCount: Int = 0 {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - UI Components
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let containerStackView = UIStackView()
    
    // 左侧：取消按钮
    private let cancelButton = UIButton(type: .system)
    
    // 中间：选择信息和操作
    private let centerStackView = UIStackView()
    private let selectionLabel = UILabel()
    private let selectAllButton = UIButton(type: .system)
    
    // 右侧：操作按钮
    private let actionsStackView = UIStackView()
    private let shareButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // 背景效果
        backgroundView.layer.cornerRadius = 12
        backgroundView.clipsToBounds = true
        
        // 主容器
        containerStackView.axis = .horizontal
        containerStackView.alignment = .center
        containerStackView.distribution = .equalSpacing
        containerStackView.spacing = 16
        
        // 取消按钮
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        
        // 中间栈视图
        centerStackView.axis = .horizontal
        centerStackView.alignment = .center
        centerStackView.spacing = 12
        
        // 选择信息标签
        selectionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        selectionLabel.textColor = .label
        selectionLabel.text = "未选择"
        
        // 全选/全不选按钮
        selectAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        selectAllButton.setTitleColor(.systemBlue, for: .normal)
        selectAllButton.setTitle("全选", for: .normal)
        
        // 操作按钮栈视图
        actionsStackView.axis = .horizontal
        actionsStackView.alignment = .center
        actionsStackView.spacing = 16
        
        // 分享按钮
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .systemBlue
        shareButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        shareButton.layer.cornerRadius = 22
        shareButton.isEnabled = false
        
        // 删除按钮
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        deleteButton.layer.cornerRadius = 22
        deleteButton.isEnabled = false
        
        // 添加子视图
        addSubview(backgroundView)
        addSubview(containerStackView)
        
        containerStackView.addArrangedSubview(cancelButton)
        containerStackView.addArrangedSubview(centerStackView)
        containerStackView.addArrangedSubview(actionsStackView)
        
        centerStackView.addArrangedSubview(selectionLabel)
        centerStackView.addArrangedSubview(selectAllButton)
        
        actionsStackView.addArrangedSubview(shareButton)
        actionsStackView.addArrangedSubview(deleteButton)
    }
    
    private func setupConstraints() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 背景视图
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 主容器
            containerStackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            // 操作按钮大小
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            deleteButton.widthAnchor.constraint(equalToConstant: 44),
            deleteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupActions() {
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        selectAllButton.addTarget(self, action: #selector(selectAllTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func cancelTapped() {
        HapticFeedbackManager.shared.lightImpact()
        onCancel?()
    }
    
    @objc private func selectAllTapped() {
        HapticFeedbackManager.shared.lightImpact()
        
        if selectedCount == 0 {
            onSelectAll?()
        } else {
            onDeselectAll?()
        }
    }
    
    @objc private func shareTapped() {
        HapticFeedbackManager.shared.lightImpact()
        onShare?()
    }
    
    @objc private func deleteTapped() {
        HapticFeedbackManager.shared.mediumImpact()
        onDelete?()
    }
    
    // MARK: - Public Methods
    /// 更新选择数量
    func updateSelectionCount(_ count: Int, total: Int) {
        selectedCount = count
        
        // 更新选择信息
        if count == 0 {
            selectionLabel.text = "未选择"
        } else {
            selectionLabel.text = "已选择 \(count) 项"
        }
        
        // 更新全选按钮
        if count == 0 {
            selectAllButton.setTitle("全选", for: .normal)
        } else if count == total {
            selectAllButton.setTitle("全不选", for: .normal)
        } else {
            selectAllButton.setTitle("全选", for: .normal)
        }
        
        // 更新操作按钮状态
        let hasSelection = count > 0
        shareButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
        
        shareButton.alpha = hasSelection ? 1.0 : 0.5
        deleteButton.alpha = hasSelection ? 1.0 : 0.5
    }
    
    private func updateUI() {
        // 根据选择数量更新UI状态
        let hasSelection = selectedCount > 0
        
        // 动画更新按钮状态
        UIView.animate(withDuration: 0.2) {
            self.shareButton.transform = hasSelection ? .identity : CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.deleteButton.transform = hasSelection ? .identity : CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }
    
    /// 显示工具栏（从底部滑入）
    func show(animated: Bool = true) {
        guard isHidden else { return }
        
        isHidden = false
        
        if animated {
            transform = CGAffineTransform(translationX: 0, y: bounds.height)
            alpha = 0
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                self.transform = .identity
                self.alpha = 1
            }
        }
    }
    
    /// 隐藏工具栏（滑出到底部）
    func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard !isHidden else {
            completion?()
            return
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                self.transform = CGAffineTransform(translationX: 0, y: self.bounds.height)
                self.alpha = 0
            }) { _ in
                self.isHidden = true
                self.transform = .identity
                completion?()
            }
        } else {
            isHidden = true
            completion?()
        }
    }
}

// MARK: - 主题扩展
extension BatchSelectionToolbar {
    
    func updateTheme() {
        backgroundView.effect = UIBlurEffect(style: .systemMaterial)
        
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        selectAllButton.setTitleColor(.systemBlue, for: .normal)
        selectionLabel.textColor = .label
        
        shareButton.tintColor = .systemBlue
        shareButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
    }
    
    // MARK: - Public Methods
    func updateSelectedCount(_ count: Int) {
        selectedCount = count
    }
}
