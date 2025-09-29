//
//  MainCameraViewController.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  主相机视图控制器 - 全屏相机预览和录制控制
//

import UIKit
import AVFoundation
import SwiftUI

class MainCameraViewController: UIViewController {
    
    // MARK: - UI Components
    private let cameraPreviewView = UIView()
    private let gradientBackgroundView = GradientBackgroundView()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // 底部控制面板
    private let controlPanelBlurView = BlurEffectView(style: .regular, intensity: 0.9)
    private let recordButton = UIButton()
    private let galleryButton = UIButton()
    private let settingsButton = UIButton()
    
    // 时间序列模式切换按钮
    private let modeSwitcherButton = UIButton(type: .system)
    private let modeSwitcherMainLabel = UILabel()
    private let modeSwitcherSubLabel = UILabel()
    
    // 当前模式状态
    private var isTimeSequenceMode = false
    
    // 录制状态指示
    private let recordingIndicatorView = UIView()
    private let recordingTimeLabel = UILabel()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // 状态变量
    private var isRecording = false {
        didSet {
            updateRecordingUI()
        }
    }
    
    // MARK: - Dependencies
    private lazy var cameraManager = CameraManager()
    
    // 触感反馈管理器
    private let hapticManager = HapticFeedbackManager.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupCameraPreview()
        configureTheme()
        setupNotificationObservers()
        
        // 🆕 主动预热录制系统
        preWarmRecordingSystem()
        
        // 触感反馈管理器已在单例初始化时准备好
    }
    
    // 🆕 预热录制系统，减少首次录制延迟
    private func preWarmRecordingSystem() {
        print("🔥 MainCameraViewController: 开始预热录制系统")
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // 1. 预检查设备性能并调整录制质量
            self.optimizeRecordingQualityForDevice()
            
            // 2. 延迟预热，避免阻塞UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.performRecordingSystemPreCheck()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 隐藏导航栏和状态栏
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // 请求权限并启动相机
        requestPermissions()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 停止录制（如果正在录制）
        if isRecording {
            stopRecording()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    // MARK: - Recording System Optimization
    
    // 🆕 根据设备性能优化录制质量
    private func optimizeRecordingQualityForDevice() {
        let videoManager = VideoManager.shared
        let diagnostics = videoManager.getPerformanceDiagnostics()
        
        print("📊 设备性能诊断:")
        print("   - 性能等级: \(diagnostics.devicePerformanceLevel.displayName)")
        print("   - 推荐质量: \(diagnostics.recommendedQuality.displayName)")
        print("   - 温度状态: \(diagnostics.thermalState.displayName)")
        print("   - 内存压力: \(diagnostics.currentMemoryStatus.memoryPressure.displayName)")
        
        // 🎯 如果当前设置的质量过高，自动降级
        let currentQuality = videoManager.currentVideoQuality
        let recommendedQuality = diagnostics.recommendedQuality
        
        if currentQuality != recommendedQuality {
            print("⚡️ 检测到当前质量(\(currentQuality.displayName))高于推荐质量，自动降级到\(recommendedQuality.displayName)")
            videoManager.currentVideoQuality = recommendedQuality
            
            // 🚀 使用新的动态调整功能立即应用质量变更
            DispatchQueue.main.async { [weak self] in
                self?.cameraManager.adjustRecordingQuality(to: recommendedQuality)
            }
        }
    }
    
    // 🆕 执行录制系统预检查
    private func performRecordingSystemPreCheck() {
        print("🔍 MainCameraViewController: 执行录制系统预检查")
        
        // 1. 检查相机管理器状态
        let cameraReady = cameraManager.isReadyForRecording
        print("   - 相机管理器就绪: \(cameraReady ? "✅" : "❌")")
        
        // 2. 检查存储空间
        let freeSpace = FileManagerHelper.getAvailableSpaceInGB()
        let hasEnoughSpace = freeSpace > 1.0 // 至少1GB
        print("   - 可用存储空间: \(String(format: "%.1f", freeSpace))GB \(hasEnoughSpace ? "✅" : "❌")")
        
        // 3. 检查性能状态
        let diagnostics = VideoManager.shared.getPerformanceDiagnostics()
        let performanceOK = !diagnostics.hasCriticalIssues
        print("   - 性能状态: \(performanceOK ? "✅" : "⚠️ 有问题")")
        
        // 🎯 如果有问题，预先准备解决方案
        if !hasEnoughSpace {
            print("⚠️ 存储空间不足，建议用户清理空间")
        }
        
        if !performanceOK && diagnostics.thermalState == .critical {
            print("🌡️ 设备温度过高，录制质量将自动降级")
        }
        
        print("🏁 录制系统预检查完成")
    }
    
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // 添加渐变背景（作为加载时的背景）
        view.addSubview(gradientBackgroundView)
        
        // 相机预览视图
        cameraPreviewView.backgroundColor = .black
        view.addSubview(cameraPreviewView)
        
        // 录制状态指示器
        setupRecordingIndicator()
        
        // 底部控制面板
        setupControlPanel()
        
        // 注意：setupModeSwitcher() 已在 setupControlPanel() 中调用，避免重复调用
    }
    
    private func setupRecordingIndicator() {
        recordingIndicatorView.backgroundColor = UIColor.red
        recordingIndicatorView.layer.cornerRadius = 6
        recordingIndicatorView.isHidden = true
        view.addSubview(recordingIndicatorView)
        
        recordingTimeLabel.text = "00:00"
        recordingTimeLabel.textColor = .white
        recordingTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        recordingTimeLabel.isHidden = true
        view.addSubview(recordingTimeLabel)
    }
    
    private func setupControlPanel() {
        // 毛玻璃背景面板
        controlPanelBlurView.layer.cornerRadius = ThemeManager.largeCornerRadius
        controlPanelBlurView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(controlPanelBlurView)
        
        // 确保控制面板可以交互
        controlPanelBlurView.isUserInteractionEnabled = true
        controlPanelBlurView.contentView.isUserInteractionEnabled = true
        
        // 首先设置按钮样式
        setupGalleryButton()
        setupRecordButton()
        setupSettingsButton()
        
        // 添加按钮到控制面板
        controlPanelBlurView.contentView.addSubview(galleryButton)
        controlPanelBlurView.contentView.addSubview(recordButton)
        controlPanelBlurView.contentView.addSubview(settingsButton)
        
        // 最后设置模式切换器（此时所有按钮都已添加到视图层次结构中）
        setupModeSwitcher()
        
        print("🔧 控制面板配置完成，contentView交互: \(controlPanelBlurView.contentView.isUserInteractionEnabled)")
    }
    
    private func setupGalleryButton() {
        galleryButton.backgroundColor = ThemeManager.cardBackground
        galleryButton.layer.cornerRadius = 25
        galleryButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        galleryButton.tintColor = ThemeManager.primaryText
        
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        
        // 添加点击动画
        galleryButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        galleryButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    private func setupRecordButton() {
        recordButton.backgroundColor = ThemeManager.buttonPrimary
        recordButton.layer.cornerRadius = 40
        
        // 添加渐变效果
        let gradientLayer = ThemeManager.buttonGradient
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        gradientLayer.cornerRadius = 40
        recordButton.layer.insertSublayer(gradientLayer, at: 0)
        
        // 内部圆形指示器
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 25
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        // 禁用内部视图的交互，确保点击事件传递到父按钮
        innerCircle.isUserInteractionEnabled = false
        recordButton.addSubview(innerCircle)
        
        NSLayoutConstraint.activate([
            innerCircle.centerXAnchor.constraint(equalTo: recordButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 50),
            innerCircle.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // 确保按钮可以交互
        recordButton.isUserInteractionEnabled = true
        
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        recordButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
        
        print("🔧 录制按钮已配置，frame: \(recordButton.frame), isUserInteractionEnabled: \(recordButton.isUserInteractionEnabled)")
        
        // 添加阴影
        recordButton.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        recordButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        recordButton.layer.shadowRadius = 12
        recordButton.layer.shadowOpacity = 1.0
    }
    
    private func setupSettingsButton() {
        settingsButton.backgroundColor = ThemeManager.cardBackground
        settingsButton.layer.cornerRadius = 25
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = ThemeManager.primaryText
        
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        settingsButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    
    private func setupModeSwitcher() {
        // 配置主容器按钮
        modeSwitcherButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        modeSwitcherButton.layer.cornerRadius = 18
        modeSwitcherButton.isUserInteractionEnabled = true
        
        // 添加触摸事件
        modeSwitcherButton.addTarget(self, action: #selector(modeSwitcherButtonTapped), for: .touchUpInside)
        modeSwitcherButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        modeSwitcherButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside])
        
        print("🔧 模式切换按钮已配置，isUserInteractionEnabled: \(modeSwitcherButton.isUserInteractionEnabled)")
        
        // 配置主标签（大字）
        modeSwitcherMainLabel.text = "普通录像"
        modeSwitcherMainLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        modeSwitcherMainLabel.textColor = .white
        modeSwitcherMainLabel.textAlignment = .center
        modeSwitcherMainLabel.isUserInteractionEnabled = false
        
        // 配置副标签（小字）
        modeSwitcherSubLabel.text = "点击切换时间序列模式"
        modeSwitcherSubLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        modeSwitcherSubLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        modeSwitcherSubLabel.textAlignment = .center
        modeSwitcherSubLabel.isUserInteractionEnabled = false
        
        // 添加到主视图（而不是控制面板）
        view.addSubview(modeSwitcherButton)
        modeSwitcherButton.addSubview(modeSwitcherMainLabel)
        modeSwitcherButton.addSubview(modeSwitcherSubLabel)
        
        // 设置约束
        modeSwitcherButton.translatesAutoresizingMaskIntoConstraints = false
        modeSwitcherMainLabel.translatesAutoresizingMaskIntoConstraints = false
        modeSwitcherSubLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 主按钮约束 - 位于屏幕顶部安全区域下方
            modeSwitcherButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSwitcherButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 25),
            modeSwitcherButton.heightAnchor.constraint(equalToConstant: 40),
            modeSwitcherButton.widthAnchor.constraint(equalToConstant: 200),
            
            // 主标签约束
            modeSwitcherMainLabel.topAnchor.constraint(equalTo: modeSwitcherButton.topAnchor, constant: 6),
            modeSwitcherMainLabel.leadingAnchor.constraint(equalTo: modeSwitcherButton.leadingAnchor, constant: 8),
            modeSwitcherMainLabel.trailingAnchor.constraint(equalTo: modeSwitcherButton.trailingAnchor, constant: -8),
            modeSwitcherMainLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // 副标签约束
            modeSwitcherSubLabel.topAnchor.constraint(equalTo: modeSwitcherMainLabel.bottomAnchor, constant: 2),
            modeSwitcherSubLabel.leadingAnchor.constraint(equalTo: modeSwitcherButton.leadingAnchor, constant: 8),
            modeSwitcherSubLabel.trailingAnchor.constraint(equalTo: modeSwitcherButton.trailingAnchor, constant: -8),
            modeSwitcherSubLabel.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    private func setupConstraints() {
        // 渐变背景
        gradientBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        // 相机预览
        cameraPreviewView.translatesAutoresizingMaskIntoConstraints = false
        
        // 录制指示器
        recordingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        recordingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 控制面板
        controlPanelBlurView.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 模式切换器已在setupModeSwitcher中设置
        
        NSLayoutConstraint.activate([
            // 渐变背景
            gradientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 相机预览
            cameraPreviewView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraPreviewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraPreviewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 录制指示器
            recordingIndicatorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            recordingIndicatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            recordingIndicatorView.widthAnchor.constraint(equalToConstant: 12),
            recordingIndicatorView.heightAnchor.constraint(equalToConstant: 12),
            
            recordingTimeLabel.centerYAnchor.constraint(equalTo: recordingIndicatorView.centerYAnchor),
            recordingTimeLabel.leadingAnchor.constraint(equalTo: recordingIndicatorView.trailingAnchor, constant: 8),
            
            // 控制面板
            controlPanelBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlPanelBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlPanelBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlPanelBlurView.heightAnchor.constraint(equalToConstant: 160 + view.safeAreaInsets.bottom),
            
            // 按钮布局
            recordButton.centerXAnchor.constraint(equalTo: controlPanelBlurView.centerXAnchor),
            recordButton.topAnchor.constraint(equalTo: controlPanelBlurView.topAnchor, constant: 30),
            recordButton.widthAnchor.constraint(equalToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 80),
            
            galleryButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            galleryButton.trailingAnchor.constraint(equalTo: recordButton.leadingAnchor, constant: -60),
            galleryButton.widthAnchor.constraint(equalToConstant: 50),
            galleryButton.heightAnchor.constraint(equalToConstant: 50),
            
            settingsButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            settingsButton.leadingAnchor.constraint(equalTo: recordButton.trailingAnchor, constant: 40),
            settingsButton.widthAnchor.constraint(equalToConstant: 50),
            settingsButton.heightAnchor.constraint(equalToConstant: 50),
            
            
            // 模式切换器约束已在 setupModeSwitcher() 中设置
        ])
    }
    
    private func setupCameraPreview() {
        cameraManager.delegate = self
    }
    
    private func configureTheme() {
        ThemeManager.shared.configureTheme()
    }
    
    // MARK: - Notification Setup
    private func setupNotificationObservers() {
        // 监听时光序列处理完成通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimeSequenceProcessingCompleted(_:)),
            name: NSNotification.Name("TimeSequenceProcessingCompleted"),
            object: nil
        )
        
        // 🎯 监听打开相机通知（从处理中心返回时触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShouldOpenCamera(_:)),
            name: .shouldOpenCamera,
            object: nil
        )
    }
    
    @objc private func handleTimeSequenceProcessingCompleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // 检查是否需要重置模式
        let shouldResetMode = userInfo["shouldResetMode"] as? Bool ?? true
        let returnToTimeSequenceMode = userInfo["returnToTimeSequenceMode"] as? Bool ?? false
        
        if returnToTimeSequenceMode && !shouldResetMode {
            // 用户从时光序列处理页面返回，保持在时光序列模式
            print("🎬 用户从时光序列处理页面返回，保持时光序列模式状态")
            
            // 🆕 使用新的处理完成方法
            TimeSequenceModeManager.shared.handleProcessingCompleted(shouldKeepMode: true)
            
            // 确保界面状态与全局状态同步
            if TimeSequenceModeManager.shared.isTimeSequenceMode {
                isTimeSequenceMode = true
                updateModeSwitcherDisplay()
            }
        } else if shouldResetMode {
            // 处理完成，重置到普通模式
            print("✅ 时光序列处理完成，重置到普通模式")
            
            // 🆕 使用新的处理完成方法
            TimeSequenceModeManager.shared.handleProcessingCompleted(shouldKeepMode: false)
            isTimeSequenceMode = false
            updateModeSwitcherDisplay()
        }
    }
    
    /// 🎯 处理打开相机通知
    @objc private func handleShouldOpenCamera(_ notification: Notification) {
        print("📱 收到打开相机通知，准备展示录像页面")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 🔧 修复关键问题：关闭所有模态界面，回到主录像页面
            if self.presentedViewController != nil {
                print("🔄 检测到模态界面，准备关闭所有模态界面...")
                
                // 递归关闭所有模态界面
                self.dismissAllModalViewControllers {
                    print("✅ 所有模态界面已关闭，现在在主录像页面")
                    
                    // 确保状态已重置
                    self.isTimeSequenceMode = false
                    self.updateModeSwitcherDisplay()
                    
                    // 🚀 优化：快速检查相机状态并启动
                    self.ensureCameraReady()
                    
                    // 🔧 修复：安全地展示成功提示消息
                    self.safelyPresentSuccessAlert()
                }
            } else {
                print("✅ 当前已在主录像页面")
                
                // 确保状态已重置
                self.isTimeSequenceMode = false
                self.updateModeSwitcherDisplay()
                
                // 🚀 优化：快速检查相机状态并启动
                self.ensureCameraReady()
            }
        }
    }
    
    /// 🚀 新增：确保相机处于就绪状态
    private func ensureCameraReady() {
        // 如果相机已经在运行，直接返回
        if cameraManager.previewSession.isRunning {
            print("✅ 相机已在运行，无需重启")
            return
        }
        
        // 异步启动相机，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            DispatchQueue.main.async {
                self?.startCameraPreview()
                print("✅ 相机已重新启动")
            }
        }
    }
    
    /// 🔧 方案1：统一控制的模态界面关闭方法 - 修复版本
    private func dismissAllModalViewControllers(completion: @escaping () -> Void) {
        // 🚀 收集所有需要关闭的模态界面
        var modalsToClose: [UIViewController] = []
        var current = presentedViewController
        
        while let presented = current {
            modalsToClose.append(presented)
            current = presented.presentedViewController
        }
        
        guard !modalsToClose.isEmpty else {
            print("✅ MainCamera: 没有模态界面需要关闭")
            completion()
            return
        }
        
        print("🔄 MainCamera: 发现 \(modalsToClose.count) 个模态界面需要关闭")
        
        // 🔧 修复：打印界面层级信息，便于调试
        for (index, modal) in modalsToClose.enumerated() {
            print("  层级 \(index + 1): \(type(of: modal))")
        }
        
        // 🚀 修复关键问题：从最顶层模态界面开始递归关闭到MainCameraViewController
        // 确保所有嵌套的模态界面都被正确关闭，但MainCameraViewController本身不被dismiss
        print("🔄 MainCamera: 开始递归关闭所有模态界面")
        
        self.dismissModalRecursively(completion: completion)
    }
    
    /// 🔧 递归关闭模态界面的安全方法
    private func dismissModalRecursively(completion: @escaping () -> Void) {
        guard let presented = self.presentedViewController else {
            print("✅ MainCamera: 递归关闭完成，无更多模态界面")
            completion()
            return
        }
        
        print("🔄 MainCamera: 关闭模态界面: \(type(of: presented))")
        
        presented.dismiss(animated: true) { [weak self] in
            // 🚀 递归处理下一个模态界面
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.dismissModalRecursively(completion: completion)
            }
        }
    }
    
    /// 🔧 安全地展示成功提示Alert，避免"view not in window hierarchy"错误
    private func safelyPresentSuccessAlert() {
        // 🚀 验证视图控制器状态
        guard self.view.window != nil,
              self.presentedViewController == nil else {
            print("⚠️ MainCamera: 无法展示Alert，视图控制器状态不正确")
            return
        }
        
        // 🔧 使用小延迟确保界面完全稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  self.view.window != nil else {
                print("⚠️ MainCamera: Alert展示时视图控制器已不在窗口层级中")
                return
            }
            
            let alert = UIAlertController(
                title: "✨ 已回到录像页面",
                message: "可以开始新的创作了！",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            
            self.present(alert, animated: true) {
                print("✅ 成功展示回到录像页面提示")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Camera Management
extension MainCameraViewController {
    
    private func requestPermissions() {
        cameraManager.requestPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startCameraPreview()
                } else {
                    self?.showPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func startCameraPreview() {
        cameraManager.startSession()
        
        // 设置预览层
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.previewSession)
            previewLayer?.frame = cameraPreviewView.bounds
            previewLayer?.videoGravity = .resizeAspectFill
            cameraPreviewView.layer.addSublayer(previewLayer!)
        }
        
        // 隐藏渐变背景，显示相机预览
        UIView.animate(withDuration: 0.5) {
            self.gradientBackgroundView.alpha = 0
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "需要相机权限",
            message: "为了使用录制功能，请在设置中允许访问相机和麦克风。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - Actions
extension MainCameraViewController {
    
    @objc private func recordButtonTapped() {
        print("🎯 录制按钮被点击，当前状态：\(isRecording ? "录制中" : "未录制")")
        
        // 立即触感反馈确认按钮点击
        hapticManager.buttonTap()
        
        // 🧪 临时测试：同时尝试简化触感反馈
        hapticManager.simpleFeedback()
        
        // 🔬 超级彻底测试（只在第一次点击时执行）
        if !isRecording {
            hapticManager.thoroughHapticTest()
            
            // 🚨 最后的手段：系统级强制振动
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.hapticManager.forceSystemVibration()
            }
        }
        
        if isRecording {
            print("🛑 尝试停止录制...")
            stopRecording()
        } else {
            print("▶️ 尝试开始录制...")
            startRecording()
        }
    }
    
    @objc private func galleryButtonTapped() {
        let galleryVC = VideoGalleryViewController()
        let navController = UINavigationController(rootViewController: galleryVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    
    @objc private func buttonPressed(_ button: UIButton) {
        let buttonName = getButtonName(button)
        print("🔽 按钮按下: \(buttonName)")
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        let buttonName = getButtonName(button)
        print("🔼 按钮释放: \(buttonName)")
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = .identity
        }
    }
    
    private func getButtonName(_ button: UIButton) -> String {
        switch button {
        case recordButton:
            return "录制按钮"
        case galleryButton:
            return "图库按钮"
        case settingsButton:
            return "设置按钮"
        case modeSwitcherButton:
            return "模式切换按钮"
        default:
            return "其他按钮"
        }
    }
}

// MARK: - Recording Management
extension MainCameraViewController {
    
    private func startRecording() {
        guard !isRecording else { return }
        
        // 🚀 智能录制启动：先执行快速预检查和优化
        performQuickRecordingCheck { [weak self] canProceed in
            guard let self = self else { return }
            
            if !canProceed {
                print("❌ 快速预检查未通过，无法开始录制")
                return
            }
            
            // 🔧 修复：添加录制就绪状态检查
            guard self.cameraManager.isReadyForRecording else {
                print("⚠️ 相机管理器尚未准备好录制，尝试智能等待...")
                
                // 🆕 智能等待和重试机制
                self.attemptRecordingWithSmartRetry()
                return
            }

            self.cameraManager.startRecording { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.isRecording = true
                        self?.startRecordingTimer()
                        
                        // 触觉反馈
                        self?.hapticManager.recordingStart()
                        
                    case .failure(let error):
                        // 🔧 改进：提供更友好的错误处理
                        print("❌ 录制启动失败: \(error.localizedDescription)")
                        self?.handleRecordingStartFailure(error: error)
                    }
                }
            }
        }
    }
    
    // 🆕 快速录制前检查
    private func performQuickRecordingCheck(completion: @escaping (Bool) -> Void) {
        // 1. 检查存储空间
        let freeSpace = FileManagerHelper.getAvailableSpaceInGB()
        if freeSpace < 0.5 { // 少于500MB
            showStorageWarningAlert()
            completion(false)
            return
        }
        
        // 2. 检查设备性能状态
        let diagnostics = VideoManager.shared.getPerformanceDiagnostics()
        if diagnostics.hasCriticalIssues {
            // 自动降级质量以确保录制成功
            print("⚡️ 检测到性能问题，自动调整录制质量")
            let recommendedQuality = diagnostics.recommendedQuality
            VideoManager.shared.currentVideoQuality = recommendedQuality
            
            // 立即应用质量调整
            cameraManager.adjustRecordingQuality(to: recommendedQuality)
        }
        
        completion(true)
    }
    
    // 🆕 智能等待和重试录制
    private func attemptRecordingWithSmartRetry() {
        print("🔄 开始智能重试录制...")
        
        // 显示更友好的加载提示
        let loadingAlert = UIAlertController(
            title: "准备录制中",
            message: "正在优化相机设置，请稍候...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        // 给相机更多时间初始化，同时重置状态
        cameraManager.resetRecordingState()
        
        // 延迟重试
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            loadingAlert.dismiss(animated: true) {
                if self.cameraManager.isReadyForRecording {
                    print("✅ 智能重试成功，开始录制")
                    self.startRecording()
                } else {
                    print("❌ 智能重试失败")
                    self.showRecordingFailedAlert()
                }
            }
        }
    }
    
    // 🆕 存储空间不足警告
    private func showStorageWarningAlert() {
        let alert = UIAlertController(
            title: "存储空间不足",
            message: "设备存储空间不足，可能影响录制质量。建议清理空间后再试。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "继续录制", style: .default) { [weak self] _ in
            // 降级到最低质量继续录制
            VideoManager.shared.currentVideoQuality = .low
            self?.performActualRecording()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.hapticManager.notificationError()
        })
        
        present(alert, animated: true)
    }
    
    // 🆕 录制最终失败的提示
    private func showRecordingFailedAlert() {
        let alert = UIAlertController(
            title: "录制准备失败",
            message: "相机系统可能需要更多时间初始化。请稍后再试，或重启应用。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "稍后重试", style: .default) { [weak self] _ in
            self?.hapticManager.buttonTap()
        })
        
        alert.addAction(UIAlertAction(title: "确定", style: .cancel))
        
        present(alert, animated: true)
        hapticManager.notificationError()
    }
    
    // 🆕 执行实际录制（跳过检查）
    private func performActualRecording() {
        cameraManager.startRecording { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isRecording = true
                    self?.startRecordingTimer()
                    self?.hapticManager.recordingStart()
                    
                case .failure(let error):
                    print("❌ 强制录制也失败: \(error.localizedDescription)")
                    self?.handleRecordingStartFailure(error: error)
                }
            }
        }
    }
    
    // 🆕 处理录制启动失败的专门方法
    private func handleRecordingStartFailure(error: Error) {
        // 检查是否是初始化问题
        if let cameraError = error as? CameraError,
           case .outputSetupFailed = cameraError {
            
            let alert = UIAlertController(
                title: "录制启动失败",
                message: "相机组件还在初始化中，请稍等几秒后重试",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            
            // 提供重试选项
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.hapticManager.buttonTap() // 轻微提示用户可以重试
            }
        } else {
            // 其他类型的错误使用原有处理方式
            showError(error)
        }
        
        // 错误触觉反馈
        hapticManager.notificationError()
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        cameraManager.stopRecording { [weak self] result in
            DispatchQueue.main.async {
                self?.isRecording = false
                self?.stopRecordingTimer()
                
                switch result {
                case .success(let url):
                    self?.handleRecordingComplete(url: url)
                    
                    // 触觉反馈
                    self?.hapticManager.recordingStop()
                    
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingTime()
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
    
    private func updateRecordingTime() {
        guard let startTime = recordingStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        recordingTimeLabel.text = String.formatTime(elapsed)
    }
    
    private func updateRecordingUI() {
        UIView.animate(withDuration: 0.3) {
            self.recordingIndicatorView.isHidden = !self.isRecording
            self.recordingTimeLabel.isHidden = !self.isRecording
            
            // 更新录制按钮外观
            if self.isRecording {
                // 变为方形停止按钮
                if let innerCircle = self.recordButton.subviews.first {
                    innerCircle.layer.cornerRadius = 8
                    innerCircle.backgroundColor = UIColor.red
                }
                
                // 添加红色边框闪烁
                self.recordButton.layer.borderWidth = 3
                self.recordButton.layer.borderColor = UIColor.red.cgColor
                
            } else {
                // 恢复圆形录制按钮
                if let innerCircle = self.recordButton.subviews.first {
                    innerCircle.layer.cornerRadius = 25
                    innerCircle.backgroundColor = UIColor.white
                }
                
                self.recordButton.layer.borderWidth = 0
            }
        }
        
        // 录制指示器闪烁动画
        if isRecording {
            let blinkAnimation = CABasicAnimation(keyPath: "opacity")
            blinkAnimation.duration = 0.5
            blinkAnimation.repeatCount = .infinity
            blinkAnimation.autoreverses = true
            blinkAnimation.fromValue = 1.0
            blinkAnimation.toValue = 0.3
            recordingIndicatorView.layer.add(blinkAnimation, forKey: "blink")
            
            // 启动录制按钮呼吸光效动画
            AnimationManager.shared.startRecordingBreathingAnimation(on: recordButton)
        } else {
            recordingIndicatorView.layer.removeAnimation(forKey: "blink")
            
            // 停止录制按钮呼吸光效动画
            AnimationManager.shared.stopRecordingBreathingAnimation(on: recordButton)
        }
    }
    
    private func handleRecordingComplete(url: URL) {
        print("📹 录制完成，视频保存到: \(url)")
        
        // 显示录制完成选项
        let alert = UIAlertController(title: "录制完成", message: "选择下一步操作", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "直接编辑", style: .default) { [weak self] _ in
            self?.editVideoAndSaveToGallery(url: url)
        })
        
        alert.addAction(UIAlertAction(title: "保存到app相册", style: .default) { [weak self] _ in
            self?.saveVideoToAppGallery(url: url)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.cancelRecording(url: url)
        })
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = recordButton
            popover.sourceRect = recordButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func editVideoAndSaveToGallery(url: URL) {
        print("📹 开始保存视频到app相册并准备编辑")
        
        // 显示保存进度指示器
        let loadingAlert = UIAlertController(title: "保存中", message: "正在保存视频到app相册...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 先保存视频到app内部相册
        VideoManager.shared.saveVideo(from: url) { [weak self] result in
            DispatchQueue.main.async {
                // 关闭进度指示器
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let videoItem):
                        print("✅ 视频已保存到app相册，开始编辑")
                        print("📁 新的视频路径: \(videoItem.filePath)")
                        
                        // ⚠️ 关键修复：使用保存后的新路径，而不是原始临时路径
                        // 原始临时文件已经被moveItem移动走了，所以要使用新路径
                        self?.editVideo(url: videoItem.filePath)
                        
                        // 成功触觉反馈
                        self?.hapticManager.notificationSuccess()
                        
                    case .failure(let error):
                        print("❌ 保存视频到app相册失败: \(error)")
                        
                        // 保存失败，询问用户是否仍要编辑（使用原始路径，因为文件还在原位置）
                        let errorAlert = UIAlertController(
                            title: "保存失败",
                            message: "视频保存到app相册失败，是否仍要进入编辑？\n错误：\(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "仍要编辑", style: .default) { _ in
                            self?.editVideo(url: url)
                        })
                        errorAlert.addAction(UIAlertAction(title: "取消", style: .cancel))
                        self?.present(errorAlert, animated: true)
                        
                        // 错误触觉反馈
                        self?.hapticManager.notificationError()
                    }
                }
            }
        }
    }
    
    private func editVideo(url: URL) {
        // 根据当前模式决定跳转到哪个界面
        if TimeSequenceModeManager.shared.isTimeSequenceMode,
           let sceneType = TimeSequenceModeManager.shared.selectedSceneType {
            // 时间序列模式：跳转到时间序列处理界面
            let timeSequenceVC = TimeSequenceViewController(videoURL: url, sceneType: sceneType)
            let navController = UINavigationController(rootViewController: timeSequenceVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
            
            // ⚠️ 重要修改：不要立即重置模式状态！
            // 用户从时光序列处理页面返回时，应该回到时光序列模式的录像状态
            // 模式重置将在用户主动切换模式或完成处理后进行
            
        } else {
            // 普通模式：跳转到视频播放器
            let playerVC = VideoPlayerViewController(videoURL: url)
            let navController = UINavigationController(rootViewController: playerVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }
    
    private func saveVideoToAppGallery(url: URL) {
        print("保存视频到app内部相册: \(url)")
        
        // 检查文件是否存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            print("❌ 视频文件不存在: \(url.path)")
            let alert = UIAlertController(
                title: "保存失败",
                message: "视频文件不存在，无法保存到app相册",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        print("✅ 视频文件存在，开始保存到app内部相册")
        
        // 显示保存进度指示器
        let loadingAlert = UIAlertController(title: "保存中", message: "正在保存视频到app相册...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 保存视频到app内部相册
        VideoManager.shared.saveVideo(from: url) { [weak self] result in
            DispatchQueue.main.async {
                // 关闭进度指示器
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let videoItem):
                        print("✅ 视频成功保存到app内部相册")
                        
                        // 成功触觉反馈
                        self?.hapticManager.notificationSuccess()
                        
                        // 显示成功消息
                        let successAlert = UIAlertController(
                            title: "保存成功",
                            message: "视频已保存到app相册，可在相册中查看",
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(title: "查看相册", style: .default) { [weak self] _ in
                            self?.galleryButtonTapped()
                        })
                        successAlert.addAction(UIAlertAction(title: "确定", style: .cancel))
                        self?.present(successAlert, animated: true)
                        
                    case .failure(let error):
                        print("❌ 保存视频到app内部相册失败: \(error)")
                        
                        // 错误触觉反馈
                        self?.hapticManager.notificationError()
                        
                        // 显示错误消息
                        let errorAlert = UIAlertController(
                            title: "保存失败",
                            message: "无法保存到app相册: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                }
            }
        }
    }
    
    private func cancelRecording(url: URL) {
        print("取消录制，删除临时文件: \(url)")
        
        // 触觉反馈
        hapticManager.buttonTap()
        
        // 删除临时文件
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                print("✅ 临时文件已删除")
            }
        } catch {
            print("❌ 删除临时文件失败: \(error)")
        }
        
        // 可选：显示取消确认消息
        let alert = UIAlertController(
            title: "已取消",
            message: "录制已取消，临时文件已删除",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("🎬 视频保存回调被调用")
        print("   路径: \(videoPath)")
        print("   错误: \(error?.localizedDescription ?? "无错误")")
        
        // 关闭进度指示器
        dismiss(animated: true) { [weak self] in
            if let error = error {
                print("❌ 视频保存到相册失败: \(error.localizedDescription)")
                // 保存失败
                let alert = UIAlertController(
                    title: "保存失败", 
                    message: "无法保存视频到相册: \(error.localizedDescription)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self?.present(alert, animated: true)
                
                // 错误触觉反馈
                self?.hapticManager.notificationError()
            } else {
                print("✅ 视频成功保存到相册")
                // 保存成功
                let alert = UIAlertController(
                    title: "保存成功", 
                    message: "视频已成功保存到相册",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self?.present(alert, animated: true)
                
                // 播放成功音效和触觉反馈
                self?.hapticManager.notificationSuccess()
            }
        }
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "操作失败",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Layout Updates
extension MainCameraViewController {
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 更新预览层frame
        previewLayer?.frame = cameraPreviewView.bounds
        
        // 更新录制按钮渐变层
        if let gradientLayer = recordButton.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = recordButton.bounds
        }
        
        // 验证录制按钮的最终状态
        print("🔍 视图布局完成 - 录制按钮状态:")
        print("   Frame: \(recordButton.frame)")
        print("   isUserInteractionEnabled: \(recordButton.isUserInteractionEnabled)")
        print("   isHidden: \(recordButton.isHidden)")
        print("   alpha: \(recordButton.alpha)")
        print("   superview: \(recordButton.superview != nil ? "存在" : "nil")")
        
        if recordButton.frame != .zero {
            print("✅ 录制按钮布局正常")
        } else {
            print("❌ 录制按钮frame为零！")
        }
        
        // 验证模式切换按钮的状态
        print("🔍 视图布局完成 - 模式切换按钮状态:")
        print("   Frame: \(modeSwitcherButton.frame)")
        print("   isUserInteractionEnabled: \(modeSwitcherButton.isUserInteractionEnabled)")
        print("   isHidden: \(modeSwitcherButton.isHidden)")
        print("   alpha: \(modeSwitcherButton.alpha)")
        print("   superview: \(modeSwitcherButton.superview != nil ? "存在" : "nil")")
        print("   控制面板frame: \(controlPanelBlurView.frame)")
        
        if modeSwitcherButton.frame != .zero {
            print("✅ 模式切换按钮布局正常")
        } else {
            print("❌ 模式切换按钮frame为零！")
        }
    }
}

// MARK: - CameraManagerDelegate
extension MainCameraViewController: CameraManagerDelegate {
    
    func cameraManagerDidStartSession() {
        // 相机会话已启动
    }
    
    func cameraManagerDidStopSession() {
        // 相机会话已停止
    }
    
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.showError(error)
        }
    }
}

// MARK: - SceneSelectionViewControllerDelegate
extension MainCameraViewController: SceneSelectionViewControllerDelegate {
    func sceneSelectionViewController(_ controller: SceneSelectionViewController, didSelectScene sceneType: SceneType) {
        // 关闭场景选择界面
        controller.dismiss(animated: true) {
            // 启动时间序列录像模式
            self.startTimeSequenceRecording(with: sceneType)
        }
    }
    
    func sceneSelectionViewControllerDidCancel(_ controller: SceneSelectionViewController) {
        // 取消场景选择
        controller.dismiss(animated: true)
    }
}

// MARK: - Mode Switcher Actions
extension MainCameraViewController {
    
    @objc private func modeSwitcherButtonTapped() {
        print("🎯 模式切换按钮被点击！当前模式：\(isTimeSequenceMode ? "时间序列" : "普通录像")")
        print("🔍 录制状态：\(isRecording ? "录制中" : "未录制")")
        
        // 触觉反馈
        hapticManager.buttonTap()
        
        // 检查是否正在录制
        guard !isRecording else {
            print("⚠️ 当前正在录制，无法切换模式")
            let alert = UIAlertController(
                title: "无法切换模式",
                message: "请先停止当前录制",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        // 🎯 优化后的切换逻辑：直接根据当前状态切换
        if isTimeSequenceMode {
            print("📹 切换到普通录像模式")
            // 当前是时间序列模式，切换到普通模式
            switchToNormalMode()
        } else {
            print("⏰ 切换到时间序列模式")
            // 当前是普通模式，进入时间序列场景选择
            showTimeSequenceSceneSelection()
        }
    }
    
    // MARK: - 新增：直接显示场景选择
    private func showTimeSequenceSceneSelection() {
        // 直接进入场景选择界面（已融合说明信息）
        let sceneSelectionVC = SceneSelectionViewController()
        sceneSelectionVC.delegate = self
        let navController = UINavigationController(rootViewController: sceneSelectionVC)
        navController.modalPresentationStyle = .pageSheet
        
        if #available(iOS 15.0, *) {
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        present(navController, animated: true)
    }
    
    private func switchToNormalMode() {
        // 切换到普通录像模式
        isTimeSequenceMode = false
        
        // 🔧 修复：同步更新全局状态管理器
        TimeSequenceModeManager.shared.switchToNormalMode()
        
        updateModeSwitcherDisplay()
        
        // 更新界面状态
        let alert = UIAlertController(
            title: "✅ 模式切换成功",
            message: "已切换到普通录像模式",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showTimeSequenceModeOptions() {
        // 显示时间序列模式说明弹窗
        let alert = UIAlertController(
            title: "⏰ 时间序列录像模式",
            message: """
            💡 这个模式专门用于：
            • 记录运动轨迹过程
            • 创建动态艺术效果图
            • 需要固定拍摄位置
            
            🎯 适合场景：
            • 人物动作 • 宠物活动
            • 运动轨迹 • 舞蹈表演
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "了解更多", style: .default) { _ in
            self.showModeInfo()
        })
        alert.addAction(UIAlertAction(title: "切换模式", style: .default) { _ in
            self.showSceneSelection()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showSceneSelection() {
        // 进入场景选择界面
        let sceneSelectionVC = SceneSelectionViewController()
        sceneSelectionVC.delegate = self
        let navController = UINavigationController(rootViewController: sceneSelectionVC)
        navController.modalPresentationStyle = .pageSheet
        
        if #available(iOS 15.0, *) {
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        present(navController, animated: true)
    }
    
    private func startTimeSequenceRecording(with sceneType: SceneType) {
        // 切换到时间序列模式
        isTimeSequenceMode = true
        updateModeSwitcherDisplay()
        
        // 切换到时间序列模式
        TimeSequenceModeManager.shared.switchToTimeSequenceMode(with: sceneType)
        
        // 显示优化后的模式切换成功提示
        let alert = UIAlertController(
            title: "✅ 时间序列模式已启用",
            message: "📹 场景类型：\(sceneType.displayName)\n⚙️ 录制参数：已优化设置\n🎯 提示：保持拍摄位置稳定",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "开始录像", style: .default))
        present(alert, animated: true)
    }
    
    private func showModeInfo() {
        // 显示模式信息
        let alert = UIAlertController(
            title: "⏰ 时间序列模式",
            message: "时间序列模式可以将视频的关键时刻融合成一张艺术图片，适用于记录变化过程、延时摄影等场景。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "了解", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Mode Switcher State Management
    private func updateModeSwitcherDisplay() {
        UIView.animate(withDuration: 0.3) {
            if self.isTimeSequenceMode {
                // 时间序列模式
                self.modeSwitcherMainLabel.text = "⏰ 时间序列"
                self.modeSwitcherSubLabel.text = "点击切换普通录像"
                self.modeSwitcherButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            } else {
                // 普通录像模式
                self.modeSwitcherMainLabel.text = "📹 普通录像"
                self.modeSwitcherSubLabel.text = "点击切换时间序列模式"
                self.modeSwitcherButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
            }
        }
    }
}

// 已删除的 SceneSelectionViewControllerDelegate 相关代码

// 已删除的 ShootingGuideViewControllerDelegate 相关代码

// 重复的 ModeSwitcherViewDelegate 扩展已移除

