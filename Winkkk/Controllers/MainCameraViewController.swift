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
        
        // 触感反馈管理器已在单例初始化时准备好
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
        
        // 设置模式切换器
        setupModeSwitcher()
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
        
        // 相册按钮
        setupGalleryButton()
        
        // 录制按钮
        setupRecordButton()
        
        // 设置按钮
        setupSettingsButton()
        
        // 设置模式切换器
        setupModeSwitcher()
        
        // 确保控制面板可以交互
        controlPanelBlurView.isUserInteractionEnabled = true
        controlPanelBlurView.contentView.isUserInteractionEnabled = true
        
        // 添加按钮到控制面板
        controlPanelBlurView.contentView.addSubview(galleryButton)
        controlPanelBlurView.contentView.addSubview(recordButton)
        controlPanelBlurView.contentView.addSubview(settingsButton)
        
        // 模式切换器已在 setupModeSwitcher() 中添加
        
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
        modeSwitcherButton.setTitle("时间序列模式", for: .normal)
        modeSwitcherButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        modeSwitcherButton.layer.cornerRadius = 22
        modeSwitcherButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        modeSwitcherButton.setTitleColor(.white, for: .normal)
        modeSwitcherButton.addTarget(self, action: #selector(modeSwitcherButtonTapped), for: .touchUpInside)
        
        view.addSubview(modeSwitcherButton)
        
        modeSwitcherButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            modeSwitcherButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            modeSwitcherButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSwitcherButton.heightAnchor.constraint(equalToConstant: 44),
            modeSwitcherButton.widthAnchor.constraint(equalToConstant: 180)
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
            controlPanelBlurView.heightAnchor.constraint(equalToConstant: 140 + view.safeAreaInsets.bottom),
            
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
            settingsButton.leadingAnchor.constraint(equalTo: recordButton.trailingAnchor, constant: 60),
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
        print("🔽 按钮按下: \(button == recordButton ? "录制按钮" : "其他按钮")")
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ button: UIButton) {
        print("🔼 按钮释放: \(button == recordButton ? "录制按钮" : "其他按钮")")
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = .identity
        }
    }
}

// MARK: - Recording Management
extension MainCameraViewController {
    
    private func startRecording() {
        guard !isRecording else { return }
        
        cameraManager.startRecording { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isRecording = true
                    self?.startRecordingTimer()
                    
                    // 触觉反馈
                    self?.hapticManager.recordingStart()
                    
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
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
            self?.editVideo(url: url)
        })
        
        alert.addAction(UIAlertAction(title: "保存到相册", style: .default) { [weak self] _ in
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
    
    private func editVideo(url: URL) {
        // 根据当前模式决定跳转到哪个界面
        if TimeSequenceModeManager.shared.isTimeSequenceMode,
           let sceneType = TimeSequenceModeManager.shared.selectedSceneType {
            // 时间序列模式：跳转到时间序列处理界面
            let timeSequenceVC = TimeSequenceViewController(videoURL: url, sceneType: sceneType)
            let navController = UINavigationController(rootViewController: timeSequenceVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
            
            // 重置时间序列模式状态
            TimeSequenceModeManager.shared.reset()
            
            // 重置模式切换按钮
            modeSwitcherButton.setTitle("普通录像", for: .normal)
            modeSwitcherButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
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
        // 触觉反馈
        hapticManager.buttonTap()
        
        // 检查是否正在录制
        guard !isRecording else {
            let alert = UIAlertController(
                title: "无法切换模式",
                message: "请先停止当前录制",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        // 显示录像模式选择界面
        let alert = UIAlertController(
            title: "📹 选择录像模式",
            message: "选择您要使用的录像模式",
            preferredStyle: .actionSheet
        )
        
        // 普通录像模式
        alert.addAction(UIAlertAction(title: "📹 普通录像", style: .default) { _ in
            self.switchToNormalMode()
        })
        
        // 时间序列录像模式
        alert.addAction(UIAlertAction(title: "⏰ 时间序列录像", style: .default) { _ in
            self.showTimeSequenceModeOptions()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if alert.preferredStyle == .actionSheet,
           let popover = alert.popoverPresentationController {
            popover.sourceView = modeSwitcherButton
            popover.sourceRect = modeSwitcherButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func switchToNormalMode() {
        // 切换到普通录像模式
        modeSwitcherButton.setTitle("普通录像", for: .normal)
        modeSwitcherButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        
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
            • 记录变化过程
            • 创建艺术效果图
            • 需要固定拍摄位置
            
            🎯 适合场景：
            • 面包发酵 • 植物生长
            • 化妆过程 • 手工制作
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
        modeSwitcherButton.setTitle("时间序列模式", for: .normal)
        modeSwitcherButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        
        // 切换到时间序列模式
        TimeSequenceModeManager.shared.switchToTimeSequenceMode(with: sceneType)
        
        // 显示模式切换成功提示
        let alert = UIAlertController(
            title: "✅ 模式切换成功",
            message: "已切换到时间序列录像模式\n场景：\(sceneType.displayName)",
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
}

// 已删除的 SceneSelectionViewControllerDelegate 相关代码

// 已删除的 ShootingGuideViewControllerDelegate 相关代码

// 重复的 ModeSwitcherViewDelegate 扩展已移除

