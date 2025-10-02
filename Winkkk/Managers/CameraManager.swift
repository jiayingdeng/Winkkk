//
//  CameraManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  相机管理器 - AVCaptureSession配置和视频录制逻辑
//

import AVFoundation
import UIKit
import Foundation

// MARK: - CameraManagerDelegate Protocol
protocol CameraManagerDelegate: AnyObject {
    func cameraManagerDidStartSession()
    func cameraManagerDidStopSession()
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
}

class CameraManager: NSObject {
    
    // MARK: - Properties
    weak var delegate: CameraManagerDelegate?
    
    private let captureSession = AVCaptureSession()
    
    /// 获取捕获会话（用于预览层）
    var previewSession: AVCaptureSession {
        return captureSession
    }
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var isSessionConfigured = false
    
    // 录制状态
    private var isRecording = false
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?
    
    // 🆕 录制就绪状态
    private var _isReadyForRecording = false
    var isReadyForRecording: Bool {
        return _isReadyForRecording && 
               captureSession.isRunning && 
               movieFileOutput != nil
    }
    
    // 设备性能配置
    private let devicePerformance = DeviceInfo.performanceLevel
    
    // 🆕 性能监控
    private let performanceMonitor = PerformanceMonitor.shared
    private var currentRecordingQuality: VideoQuality = .medium
    private var qualityDowngradeWarningShown = false
    
    // MARK: - Public Properties  
    var sessionPreview: AVCaptureSession {
        return captureSession
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        configureSession()
    }
    
    // MARK: - Permission Management
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch (cameraStatus, microphoneStatus) {
        case (.authorized, .authorized):
            completion(true)
            
        case (.notDetermined, _):
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.requestMicrophonePermission(completion: completion)
                } else {
                    completion(false)
                }
            }
            
        case (.authorized, .notDetermined):
            requestMicrophonePermission(completion: completion)
            
        default:
            completion(false)
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            completion(micGranted)
        }
    }
    
    // MARK: - Session Management
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.isSessionConfigured {
                self.configureSession()
            }
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                
                // 🆕 快速启动录制准备
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.performFastRecordingPreparation()
                }
                
                DispatchQueue.main.async {
                    self.delegate?.cameraManagerDidStartSession()
                }
            }
        }
    }
    
    // 🆕 快速录制准备
    private func performFastRecordingPreparation() {
        print("⚡️ CameraManager: 开始快速录制准备")
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 1. 确保movieFileOutput完全准备就绪
            if let movieOutput = self.movieFileOutput {
                // 检查输出连接状态
                let videoConnection = movieOutput.connection(with: .video)
                let audioConnection = movieOutput.connection(with: .audio)
                
                print("   - 视频连接状态: \(videoConnection?.isActive == true ? "✅" : "❌")")
                print("   - 音频连接状态: \(audioConnection?.isActive == true ? "✅" : "❌")")
                
                // 2. 预热录制系统
                if let videoDevice = self.videoDeviceInput?.device {
                    // 检查设备状态
                    print("   - 当前设备: \(videoDevice.localizedName)")
                    print("   - 设备就绪: \(videoDevice.isConnected ? "✅" : "❌")")
                }
                
                // 3. 加速标记录制就绪状态（如果所有条件都满足）
                DispatchQueue.main.async {
                    if !self._isReadyForRecording && 
                       self.captureSession.isRunning &&
                       videoConnection?.isActive == true {
                        
                        // 减少延迟，更快地标记为就绪
                        self._isReadyForRecording = true
                        print("🚀 CameraManager: 快速录制准备完成！")
                    } else if !self._isReadyForRecording {
                        // 如果还没就绪，给一点额外时间
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            if self.captureSession.isRunning && movieOutput.connections.count > 0 {
                                self._isReadyForRecording = true
                                print("🎬 CameraManager: 延迟录制准备完成")
                            }
                        }
                    }
                }
            }
        }
        
        sessionQueue.async(execute: workItem)
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                
                DispatchQueue.main.async {
                    self.delegate?.cameraManagerDidStopSession()
                }
            }
        }
    }
    
    // MARK: - Session Configuration
    private func configureSession() {
        guard !isSessionConfigured else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // 设置会话预设
        configureSessionPreset()
        
        // 配置视频输入
        guard configureVideoInput() else {
            handleConfigurationError(CameraError.videoInputSetupFailed)
            return
        }
        
        // 配置音频输入
        guard configureAudioInput() else {
            handleConfigurationError(CameraError.audioInputSetupFailed)
            return
        }
        
        // 配置视频输出
        guard configureMovieOutput() else {
            handleConfigurationError(CameraError.outputSetupFailed)
            return
        }
        
        isSessionConfigured = true
        
        // 🆕 延迟标记录制就绪状态，确保所有组件完全初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?._isReadyForRecording = true
            print("✅ CameraManager: 录制系统已就绪")
        }
    }
    
    private func configureSessionPreset() {
        // 🎯 优先使用用户设置的视频质量
        let preset: AVCaptureSession.Preset
        
        if let userPresetString = UserDefaults.standard.string(forKey: "VideoQualityPreset") {
            let userPreset = AVCaptureSession.Preset(rawValue: userPresetString)
            // 检查设备是否支持用户选择的质量
            if captureSession.canSetSessionPreset(userPreset) {
                preset = userPreset
                print("📹 使用用户设置的视频质量: \(userPreset.displayName)")
            } else {
                // 用户设置的质量不被设备支持，回退到设备性能判断
                preset = getDeviceBasedPreset()
                print("⚠️ 用户设置的质量不支持，回退到设备性能判断: \(preset.displayName)")
            }
        } else {
            // 没有用户设置，使用设备性能判断
            preset = getDeviceBasedPreset()
            print("📱 使用基于设备性能的视频质量: \(preset.displayName)")
        }
        
        if captureSession.canSetSessionPreset(preset) {
            captureSession.sessionPreset = preset
        } else {
            // 最终降级处理
            captureSession.sessionPreset = .hd1920x1080
            print("🔄 降级到1080P")
        }
    }
    
    /// 根据设备性能获取预设（增强版本，支持动态调整）
    private func getDeviceBasedPreset() -> AVCaptureSession.Preset {
        // 检查当前性能状态
        let (canPerform, reason) = DeviceInfo.canPerformHighQualityRecording()
        
        if !canPerform {
            print("⚠️ 性能限制，降级录制质量: \(reason ?? "未知原因")")
            return .hd1280x720 // 强制降级到720P
        }
        
        // 根据设备性能和当前状态选择预设
        switch devicePerformance {
        case .ultra:
            return .hd4K3840x2160
        case .high:
            let recommendedQuality = performanceMonitor.getRecommendedRecordingQuality()
            return recommendedQuality == .high ? .hd4K3840x2160 : .hd1920x1080
        case .medium:
            return .hd1920x1080
        case .low:
            return .hd1280x720
        }
    }
    
    private func configureVideoInput() -> Bool {
        // 获取默认视频设备
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                       for: .video, 
                                                       position: .back) else {
            return false
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                videoDeviceInput = videoInput
                
                // 配置视频设备
                configureVideoDevice(videoDevice)
                
                return true
            }
        } catch {
            print("视频输入配置失败: \(error)")
        }
        
        return false
    }
    
    private func configureVideoDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // 设置帧率 - 先检查设备支持的帧率范围
            let preferredFrameRate: Double = devicePerformance == .low ? 30 : 60
            let actualFrameRate = getSupportedFrameRate(device: device, preferredRate: preferredFrameRate)
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(actualFrameRate))
            
            print("🎥 CameraManager: Setting frame rate to \(actualFrameRate) fps (preferred: \(preferredFrameRate))")
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            
            // 设置对焦模式
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // 设置曝光模式
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // 设置白平衡
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // 启用视频防抖
            if device.activeFormat.isVideoStabilizationModeSupported(.auto) {
                // 注意：视频防抖需要在连接上设置
            }
            
            device.unlockForConfiguration()
            
        } catch {
            print("视频设备配置失败: \(error)")
        }
    }
    
    /// 获取设备支持的帧率，如果不支持首选帧率则降级到安全值
    private func getSupportedFrameRate(device: AVCaptureDevice, preferredRate: Double) -> Double {
        // 获取当前格式支持的帧率范围
        let frameRateRanges = device.activeFormat.videoSupportedFrameRateRanges
        
        // 打印支持的帧率范围用于调试
        print("🎥 CameraManager: Supported frame rate ranges:")
        for range in frameRateRanges {
            print("   - \(range.minFrameRate) to \(range.maxFrameRate) fps")
        }
        
        // 检查首选帧率是否被支持
        for range in frameRateRanges {
            if preferredRate >= range.minFrameRate && preferredRate <= range.maxFrameRate {
                return preferredRate
            }
        }
        
        // 如果首选帧率不被支持，选择最高的支持帧率
        let maxSupportedRate = frameRateRanges.map { $0.maxFrameRate }.max() ?? 30.0
        print("⚠️ CameraManager: Preferred rate \(preferredRate) not supported, using \(maxSupportedRate)")
        return maxSupportedRate
    }
    
    private func configureAudioInput() -> Bool {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            return false
        }
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                audioDeviceInput = audioInput
                return true
            }
        } catch {
            print("音频输入配置失败: \(error)")
        }
        
        return false
    }
    
    private func configureMovieOutput() -> Bool {
        let movieOutput = AVCaptureMovieFileOutput()
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            
            // 配置视频连接
            if let connection = movieOutput.connection(with: .video) {
                // 设置视频方向 (使用iOS 17+的新API)
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90 // Portrait方向
                    }
                } else {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
                
                // 启用视频防抖
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            
            movieFileOutput = movieOutput
            return true
        }
        
        return false
    }
    
    private func handleConfigurationError(_ error: CameraError) {
        // 🔧 配置失败时重置录制就绪状态
        _isReadyForRecording = false
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.cameraManager(self!, didFailWithError: error)
        }
    }
    
    // 🆕 重置录制状态的方法（用于重新初始化）
    func resetRecordingState() {
        _isReadyForRecording = false
        print("🔄 CameraManager: 录制状态已重置")
        
        // 重新检查并准备录制系统
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performFastRecordingPreparation()
        }
    }
    
    // 🆕 动态调整录制质量（用于性能优化）
    func adjustRecordingQuality(to quality: VideoQuality) {
        print("🎚️ CameraManager: 动态调整录制质量到 \(quality.displayName)")
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 暂时标记为未就绪，防止在调整过程中开始录制
            self._isReadyForRecording = false
            
            // 重新配置会话预设以适应新的质量设置
            self.captureSession.beginConfiguration()
            
            // 根据新质量调整会话预设
            let newPreset = self.getSessionPresetForQuality(quality)
            if self.captureSession.canSetSessionPreset(newPreset) {
                self.captureSession.sessionPreset = newPreset
                print("✅ 会话预设已调整为: \(newPreset.rawValue)")
            }
            
            self.captureSession.commitConfiguration()
            
            // 快速重新准备录制
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.performFastRecordingPreparation()
            }
        }
    }
    
    // 🆕 根据VideoQuality获取对应的会话预设
    private func getSessionPresetForQuality(_ quality: VideoQuality) -> AVCaptureSession.Preset {
        switch quality {
        case .high:
            if DeviceInfo.performanceLevel == .ultra {
                return .hd4K3840x2160
            } else {
                return .hd1920x1080
            }
        case .medium:
            return .hd1280x720
        case .low:
            return .medium
        }
    }
}

// MARK: - Recording Management
extension CameraManager {
    
    func startRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.isRecording else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.alreadyRecording))
                }
                return
            }
            
            // 🆕 录制前性能检查
            let (canRecord, reason) = DeviceInfo.canPerformHighQualityRecording()
            if !canRecord {
                print("⚠️ 录制前性能检查失败: \(reason ?? "未知原因")")
                
                // 询问用户是否要降级录制
                DispatchQueue.main.async {
                    self.delegate?.cameraManager(self, didFailWithError: CameraError.performanceInsufficient(reason ?? "设备性能不足"))
                }
                return
            }
            
            guard let movieOutput = self.movieFileOutput else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.outputSetupFailed))
                }
                return
            }
            
            // 🆕 启动性能监控
            self.performanceMonitor.startMonitoring(delegate: self)
            self.currentRecordingQuality = self.performanceMonitor.getRecommendedRecordingQuality()
            self.qualityDowngradeWarningShown = false
            
            print("🎥 开始录制，初始质量: \(self.currentRecordingQuality.displayName)")
            
            // 生成输出文件URL
            let outputURL = self.generateOutputURL()
            
            // 开始录制
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            
            self.isRecording = true
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }
    }
    
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.isRecording else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.notRecording))
                }
                return
            }
            
            guard let movieOutput = self.movieFileOutput else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.outputSetupFailed))
                }
                return
            }
            
            // 🆕 停止性能监控
            self.performanceMonitor.stopMonitoring()
            print("🎥 录制结束，最终质量: \(self.currentRecordingQuality.displayName)")
            
            // 保存回调
            self.recordingCompletion = completion
            
            // 停止录制
            movieOutput.stopRecording()
        }
    }
    
    private func generateOutputURL() -> URL {
        let fileName = FileManagerHelper.generateUniqueFileName(withExtension: "mp4")
        return FileManagerHelper.videosDirectory.appendingPathComponent(fileName)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, 
                   didStartRecordingTo fileURL: URL, 
                   from connections: [AVCaptureConnection]) {
        print("开始录制到: \(fileURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, 
                   didFinishRecordingTo outputFileURL: URL, 
                   from connections: [AVCaptureConnection], 
                   error: Error?) {
        
        isRecording = false
        
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                self?.recordingCompletion?(.failure(error))
            } else {
                self?.recordingCompletion?(.success(outputFileURL))
            }
            
            self?.recordingCompletion = nil
        }
    }
}

// MARK: - Camera Switching
extension CameraManager {
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let videoInput = self.videoDeviceInput else { return }
            
            let currentDevice = videoInput.device
            let newPosition: AVCaptureDevice.Position = currentDevice.position == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: newPosition) else {
                return
            }
            
            do {
                let newVideoInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.captureSession.beginConfiguration()
                
                self.captureSession.removeInput(videoInput)
                
                if self.captureSession.canAddInput(newVideoInput) {
                    self.captureSession.addInput(newVideoInput)
                    self.videoDeviceInput = newVideoInput
                    
                    // 重新配置设备
                    self.configureVideoDevice(newDevice)
                } else {
                    // 如果添加失败，恢复原来的输入
                    self.captureSession.addInput(videoInput)
                }
                
                self.captureSession.commitConfiguration()
                
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.cameraManager(self, didFailWithError: error)
                }
            }
        }
    }
}

// MARK: - Focus and Exposure
extension CameraManager {
    
    func focusAt(point: CGPoint, in view: UIView) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let device = self.videoDeviceInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                
                // 转换坐标系
                let focusPoint = self.convertPointToDeviceCoordinates(point, in: view)
                
                // 设置对焦点
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }
                
                // 设置曝光点
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                }
                
                device.unlockForConfiguration()
                
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.cameraManager(self, didFailWithError: error)
                }
            }
        }
    }
    
    private func convertPointToDeviceCoordinates(_ point: CGPoint, in view: UIView) -> CGPoint {
        // 将视图坐标转换为设备坐标 (0,0) - (1,1)
        return CGPoint(x: point.y / view.bounds.height, y: 1.0 - point.x / view.bounds.width)
    }
}

// MARK: - Error Types
enum CameraError: LocalizedError {
    case videoInputSetupFailed
    case audioInputSetupFailed
    case outputSetupFailed
    case alreadyRecording
    case notRecording
    case permissionDenied
    case deviceNotAvailable
    case performanceInsufficient(String) // 🆕 性能不足错误
    case thermalStateWarning(ProcessInfo.ThermalState) // 🆕 温度警告
    case memoryPressureWarning(String) // 🆕 内存压力警告
    
    var errorDescription: String? {
        switch self {
        case .videoInputSetupFailed:
            return "无法设置视频输入设备"
        case .audioInputSetupFailed:
            return "无法设置音频输入设备"
        case .outputSetupFailed:
            return "无法设置输出设备"
        case .alreadyRecording:
            return "已经在录制中"
        case .notRecording:
            return "当前没有在录制"
        case .permissionDenied:
            return "相机或麦克风权限被拒绝"
        case .deviceNotAvailable:
            return "相机设备不可用"
        case .performanceInsufficient(let reason):
            return "设备性能不足：\(reason)"
        case .thermalStateWarning(let state):
            return "设备温度警告：\(state.displayName)"
        case .memoryPressureWarning(let message):
            return "内存压力警告：\(message)"
        }
    }
}

// MARK: - Camera Settings
extension CameraManager {
    
    /// 获取当前录制预设
    var currentRecordingPreset: AVCaptureSession.Preset {
        return captureSession.sessionPreset
    }
    
    /// 获取支持的录制质量
    var supportedRecordingQualities: [AVCaptureSession.Preset] {
        let allPresets: [AVCaptureSession.Preset] = [
            .hd4K3840x2160,
            .hd1920x1080,
            .hd1280x720,
            .vga640x480
        ]
        
        return allPresets.filter { captureSession.canSetSessionPreset($0) }
    }
    
    /// 设置录制质量
    func setRecordingQuality(_ preset: AVCaptureSession.Preset) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.captureSession.canSetSessionPreset(preset) {
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = preset
                self.captureSession.commitConfiguration()
                print("📹 动态更新视频质量为: \(preset.displayName)")
            } else {
                print("⚠️ 无法设置视频质量: \(preset.displayName)")
            }
        }
    }
    
    /// 从用户设置更新录制质量
    func updateQualityFromUserSettings() {
        guard let userPresetString = UserDefaults.standard.string(forKey: "VideoQualityPreset") else {
            return
        }
        
        let userPreset = AVCaptureSession.Preset(rawValue: userPresetString)
        setRecordingQuality(userPreset)
    }
    
    /// 是否支持前后摄像头切换
    var canSwitchCamera: Bool {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }
    
    /// 当前是否使用前置摄像头
    var isUsingFrontCamera: Bool {
        return videoDeviceInput?.device.position == .front
    }
}

// MARK: - AVCaptureSession.Preset Extension
extension AVCaptureSession.Preset {
    /// 获取视频质量的显示名称
    var displayName: String {
        switch self {
        case .hd4K3840x2160:
            return "4K (超高清)"
        case .hd1920x1080:
            return "1080P (高清)"
        case .hd1280x720:
            return "720P (标清)"
        case .vga640x480:
            return "480P (标清)"
        default:
            return rawValue
        }
    }
}

// MARK: - Performance Monitor Delegate
extension CameraManager: PerformanceMonitorDelegate {
    
    func performanceMonitor(_ monitor: PerformanceMonitor, didUpdateStatus status: DeviceInfo.PerformanceStatus) {
        // 检查是否需要降级录制质量
        let recommendedQuality = status.recommendedMaxQuality
        
        if recommendedQuality.rawValue != currentRecordingQuality.rawValue {
            print("🔄 性能监控建议调整录制质量: \(currentRecordingQuality.displayName) -> \(recommendedQuality.displayName)")
            
            // 动态调整录制预设
            sessionQueue.async { [weak self] in
                self?.adjustRecordingQualityBasedOnPerformance(recommendedQuality)
            }
        }
    }
    
    func performanceMonitor(_ monitor: PerformanceMonitor, didDetectMemoryPressure memoryInfo: DeviceInfo.MemoryInfo) {
        print("⚠️ 内存压力检测: \(memoryInfo.memoryPressure.displayName)")
        
        let message = "可用内存: \(String.formatFileSize(Int64(memoryInfo.availableMemory)))"
        delegate?.cameraManager(self, didFailWithError: CameraError.memoryPressureWarning(message))
        
        // 强制降级到最低质量
        if memoryInfo.memoryPressure == .critical {
            sessionQueue.async { [weak self] in
                self?.adjustRecordingQualityBasedOnPerformance(.low)
            }
        }
    }
    
    func performanceMonitor(_ monitor: PerformanceMonitor, didDetectThermalStateChange thermalState: ProcessInfo.ThermalState) {
        print("🌡️ 温度状态变化: \(thermalState.displayName)")
        
        switch thermalState {
        case .serious:
            if !qualityDowngradeWarningShown {
                delegate?.cameraManager(self, didFailWithError: CameraError.thermalStateWarning(thermalState))
                qualityDowngradeWarningShown = true
            }
            
            // 降级录制质量
            sessionQueue.async { [weak self] in
                self?.adjustRecordingQualityBasedOnPerformance(.medium)
            }
            
        case .critical:
            delegate?.cameraManager(self, didFailWithError: CameraError.thermalStateWarning(thermalState))
            
            // 强制停止录制或降级到最低质量
            if isRecording {
                print("🚨 设备过热，强制降级到最低质量")
                sessionQueue.async { [weak self] in
                    self?.adjustRecordingQualityBasedOnPerformance(.low)
                }
            }
            
        default:
            break
        }
    }
    
    func performanceMonitor(_ monitor: PerformanceMonitor, didActivateLowPowerMode isActive: Bool) {
        if isActive {
            print("🔋 低电量模式激活，降级录制质量")
            sessionQueue.async { [weak self] in
                self?.adjustRecordingQualityBasedOnPerformance(.low)
            }
        }
    }
    
    func performanceMonitor(_ monitor: PerformanceMonitor, didReceiveMemoryWarning: Void) {
        print("⚠️ 收到内存警告，立即降级录制质量")
        sessionQueue.async { [weak self] in
            self?.adjustRecordingQualityBasedOnPerformance(.low)
        }
    }
    
    /// 根据性能状态调整录制质量
    private func adjustRecordingQualityBasedOnPerformance(_ recommendedQuality: VideoQuality) {
        guard isRecording else { return }
        
        let newPreset: AVCaptureSession.Preset
        switch recommendedQuality {
        case .high:
            newPreset = .hd4K3840x2160
        case .medium:
            newPreset = .hd1920x1080
        case .low:
            newPreset = .hd1280x720
        }
        
        // 检查是否支持新预设
        if captureSession.canSetSessionPreset(newPreset) && captureSession.sessionPreset != newPreset {
            captureSession.beginConfiguration()
            captureSession.sessionPreset = newPreset
            captureSession.commitConfiguration()
            
            currentRecordingQuality = recommendedQuality
            print("✅ 动态调整录制质量为: \(newPreset.displayName)")
        }
    }
}

// MARK: - Zoom Control
extension CameraManager {
    
    /// 当前视频设备（公开访问）
    var currentVideoDevice: AVCaptureDevice? {
        return videoDeviceInput?.device
    }
    
    /// 当前缩放倍数
    var currentZoomFactor: CGFloat {
        return currentVideoDevice?.videoZoomFactor ?? 1.0
    }
    
    /// 最小缩放倍数
    var minZoomFactor: CGFloat {
        return currentVideoDevice?.minAvailableVideoZoomFactor ?? 1.0
    }
    
    /// 最大缩放倍数（限制为合理范围）
    var maxZoomFactor: CGFloat {
        guard let device = currentVideoDevice else { return 1.0 }
        // 限制最大10x，避免画质过差
        return min(device.maxAvailableVideoZoomFactor, 10.0)
    }
    
    /// 设置缩放倍数（录制中可调用）
    /// - Parameters:
    ///   - factor: 目标缩放倍数
    ///   - animated: 是否使用平滑动画
    func setZoomFactor(_ factor: CGFloat, animated: Bool = false) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentVideoDevice else { return }
            
            do {
                try device.lockForConfiguration()
                
                // 限制在有效范围内
                let clampedFactor = max(self.minZoomFactor, 
                                       min(self.maxZoomFactor, factor))
                
                if animated {
                    // 平滑动画缩放 (rate: 1.0-10.0，越大越快)
                    device.ramp(toVideoZoomFactor: clampedFactor, withRate: 4.0)
                } else {
                    // 立即缩放
                    device.videoZoomFactor = clampedFactor
                }
                
                device.unlockForConfiguration()
                
                print("📷 缩放到 \(String(format: "%.1f", clampedFactor))x")
                
            } catch {
                print("❌ 缩放失败: \(error)")
            }
        }
    }
    
    /// 重置到默认缩放
    /// - Parameter animated: 是否使用平滑动画
    func resetZoom(animated: Bool = true) {
        setZoomFactor(1.0, animated: animated)
    }
}