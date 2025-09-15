//
//  CameraManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  相机管理器 - AVCaptureSession配置和视频录制逻辑
//

import AVFoundation
import UIKit

class CameraManager: NSObject {
    
    // MARK: - Properties
    weak var delegate: CameraManagerDelegate?
    
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var isSessionConfigured = false
    
    // 录制状态
    private var isRecording = false
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?
    
    // 设备性能配置
    private let devicePerformance = DeviceInfo.performanceLevel
    
    // MARK: - Public Properties
    var captureSession: AVCaptureSession {
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
            
        case (.notDetermined, .notDetermined):
            AVCaptureDevice.requestAccess(for: .video) { [weak self] cameraGranted in
                if cameraGranted {
                    self?.requestMicrophonePermission(completion: completion)
                } else {
                    completion(false)
                }
            }
            
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
                
                DispatchQueue.main.async {
                    self.delegate?.cameraManagerDidStartSession()
                }
            }
        }
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
    }
    
    private func configureSessionPreset() {
        // 根据设备性能设置不同的预设
        let preset: AVCaptureSession.Preset
        
        switch devicePerformance {
        case .high:
            preset = .hd4K3840x2160
        case .medium:
            preset = .hd1920x1080
        case .low:
            preset = .hd1280x720
        }
        
        if captureSession.canSetSessionPreset(preset) {
            captureSession.sessionPreset = preset
        } else {
            // 降级处理
            captureSession.sessionPreset = .hd1920x1080
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
            
            // 设置帧率
            let frameRate: Double = devicePerformance == .low ? 30 : 60
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            
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
                // 设置视频方向
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
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
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.cameraManager(self!, didFailWithError: error)
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
            
            guard let movieOutput = self.movieFileOutput else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.outputSetupFailed))
                }
                return
            }
            
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
        return CGPoint(x: point.y / view.bounds.height, x: 1.0 - point.x / view.bounds.width)
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
        }
    }
}

// MARK: - Camera Settings
extension CameraManager {
    
    /// 获取当前录制质量
    var currentRecordingQuality: AVCaptureSession.Preset {
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
            }
        }
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