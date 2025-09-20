//
//  ModeSwitcherView.swift
//  Winkkk
//
//  Created by AI Assistant on 2024/09/20.
//

import UIKit

/// 模式切换视图代理协议
protocol ModeSwitcherViewDelegate: AnyObject {
    func modeSwitcherDidRequestModeSelection(_ view: ModeSwitcherView)
    func modeSwitcherDidRequestModeInfo(_ view: ModeSwitcherView)
}

/// 模式切换视图 - 录像界面的模式切换按钮和说明弹窗
class ModeSwitcherView: UIView {
    
    // MARK: - 代理
    weak var delegate: ModeSwitcherViewDelegate?
    
    // MARK: - UI组件
    private let modeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        button.layer.cornerRadius = 25
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return button
    }()
    
    private let infoButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 15
        button.setTitle("?", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        return button
    }()
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
        updateModeDisplay()
        observeNotifications()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupActions()
        updateModeDisplay()
        observeNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI设置
    private func setupUI() {
        addSubview(modeButton)
        addSubview(infoButton)
        
        modeButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 模式按钮
            modeButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            modeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            modeButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 信息按钮
            infoButton.leadingAnchor.constraint(equalTo: modeButton.trailingAnchor, constant: 8),
            infoButton.centerYAnchor.constraint(equalTo: modeButton.centerYAnchor),
            infoButton.widthAnchor.constraint(equalToConstant: 30),
            infoButton.heightAnchor.constraint(equalToConstant: 30),
            
            // 容器约束
            trailingAnchor.constraint(equalTo: infoButton.trailingAnchor),
            leadingAnchor.constraint(equalTo: modeButton.leadingAnchor),
            topAnchor.constraint(equalTo: modeButton.topAnchor),
            bottomAnchor.constraint(equalTo: modeButton.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        modeButton.addTarget(self, action: #selector(modeButtonTapped), for: .touchUpInside)
        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - 通知观察
    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(modeDidChange),
            name: TimeSequenceModeManager.modeDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - 事件处理
    @objc private func modeButtonTapped() {
        delegate?.modeSwitcherDidRequestModeSelection(self)
    }
    
    @objc private func infoButtonTapped() {
        delegate?.modeSwitcherDidRequestModeInfo(self)
    }
    
    @objc private func modeDidChange() {
        updateModeDisplay()
    }
    
    // MARK: - 显示更新
    private func updateModeDisplay() {
        let manager = TimeSequenceModeManager.shared
        let icon = manager.currentModeIcon
        let name = manager.currentModeDisplayName
        
        modeButton.setTitle("\(icon) \(name)", for: .normal)
        
        // 根据模式调整按钮样式
        UIView.animate(withDuration: 0.3) {
            switch manager.currentMode {
            case .normal:
                self.modeButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                self.infoButton.backgroundColor = UIColor.systemBlue
            case .timeSequence:
                self.modeButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
                self.infoButton.backgroundColor = UIColor.systemOrange
            }
        }
    }
}

// MARK: - 模式说明弹窗

extension ModeSwitcherView {
    
    /// 显示模式说明弹窗
    /// - Parameter parentViewController: 父视图控制器
    func showModeInfoAlert(from parentViewController: UIViewController) {
        guard TimeSequenceModeManager.isTimeSequenceModeEnabled else {
            showSimpleAlert(title: "功能暂时不可用", message: "时间序列模式正在开发中", from: parentViewController)
            return
        }
        
        let alert = UIAlertController(
            title: "⏰ 时间序列录像模式",
            message: createModeInfoMessage(),
            preferredStyle: .alert
        )
        
        // 了解更多按钮
        alert.addAction(UIAlertAction(title: "了解更多", style: .default) { _ in
            self.showDetailedModeInfo(from: parentViewController)
        })
        
        // 切换模式按钮
        alert.addAction(UIAlertAction(title: "切换模式", style: .default) { _ in
            self.delegate?.modeSwitcherDidRequestModeSelection(self)
        })
        
        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        parentViewController.present(alert, animated: true)
    }
    
    /// 创建模式说明文本
    private func createModeInfoMessage() -> String {
        return """
        💡 这个模式专门用于：
        • 记录变化过程
        • 创建艺术效果图
        • 需要固定拍摄位置
        
        🎯 适合场景：
        • 面包发酵 • 植物生长
        • 化妆过程 • 手工制作
        """
    }
    
    /// 显示详细模式信息
    private func showDetailedModeInfo(from parentViewController: UIViewController) {
        let alert = UIAlertController(
            title: "🎬 拍摄技巧详解",
            message: createDetailedInfoMessage(),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "现在就试试", style: .default) { _ in
            self.delegate?.modeSwitcherDidRequestModeSelection(self)
        })
        
        alert.addAction(UIAlertAction(title: "稍后再说", style: .cancel))
        
        parentViewController.present(alert, animated: true)
    }
    
    /// 创建详细说明文本
    private func createDetailedInfoMessage() -> String {
        return """
        📐 关键要点：
        
        1️⃣ 固定拍摄：
           建议使用三脚架或稳定支撑
        
        2️⃣ 背景控制：
           保持背景完全不变
        
        3️⃣ 光线稳定：
           室内拍摄效果更佳
        
        4️⃣ 时长控制：
           通常8-20秒最合适
        
        5️⃣ 主体居中：
           确保变化主体在画面中央
        """
    }
    
    /// 显示简单提示
    private func showSimpleAlert(title: String, message: String, from parentViewController: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        parentViewController.present(alert, animated: true)
    }
}

// MARK: - 模式选择弹窗

extension ModeSwitcherView {
    
    /// 显示模式选择弹窗
    /// - Parameter parentViewController: 父视图控制器
    func showModeSelectionAlert(from parentViewController: UIViewController) {
        let manager = TimeSequenceModeManager.shared
        
        let alert = UIAlertController(
            title: "📹 选择录像模式",
            message: "当前模式：\(manager.currentModeDisplayName)",
            preferredStyle: .actionSheet
        )
        
        // 普通录像模式
        if !manager.isNormalMode {
            alert.addAction(UIAlertAction(title: "📹 普通录像", style: .default) { _ in
                manager.switchToNormalMode()
            })
        }
        
        // 时间序列模式
        if TimeSequenceModeManager.isTimeSequenceModeEnabled && !manager.isTimeSequenceMode {
            alert.addAction(UIAlertAction(title: "⏰ 时间序列录像", style: .default) { _ in
                // 这里应该跳转到场景选择界面
                // 暂时使用默认场景
                manager.switchToTimeSequenceMode(with: .objectChange)
                self.showSimpleAlert(
                    title: "✅ 已切换模式",
                    message: "现在可以开始时间序列录像了！",
                    from: parentViewController
                )
            })
        }
        
        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = modeButton
            popover.sourceRect = modeButton.bounds
        }
        
        parentViewController.present(alert, animated: true)
    }
}

// MARK: - 动画效果

extension ModeSwitcherView {
    
    /// 按钮点击动画
    func animateButtonTap(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
    }
    
    /// 模式切换成功动画
    func animateModeSwitch() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
}
