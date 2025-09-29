//
//  PerformanceMonitor.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  设备性能监控器 - 实时监控设备状态并动态调整录制质量
//

import Foundation
import UIKit
import AVFoundation

/// 性能监控器 - 防止设备过载导致应用崩溃
class PerformanceMonitor: NSObject {
    
    // MARK: - Singleton
    static let shared = PerformanceMonitor()
    private override init() {
        super.init()
        setupMonitoring()
    }
    
    // MARK: - Properties
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    private var performanceDelegate: PerformanceMonitorDelegate?
    
    /// 当前性能状态
    private(set) var currentStatus: DeviceInfo.PerformanceStatus?
    
    /// 性能历史记录（用于趋势分析）
    private var performanceHistory: [PerformanceSnapshot] = []
    private let maxHistoryCount = 30 // 保留最近30次采样
    
    /// 监控配置
    struct MonitoringConfig {
        let monitoringInterval: TimeInterval = 2.0 // 每2秒检查一次
        let memoryWarningThreshold: UInt64 = 300_000_000 // 300MB
        let memoryCriticalThreshold: UInt64 = 150_000_000 // 150MB
        let temperatureWarningDelay: TimeInterval = 10.0 // 温度警告延迟
    }
    private let config = MonitoringConfig()
    
    // MARK: - Public Methods
    
    /// 开始性能监控
    func startMonitoring(delegate: PerformanceMonitorDelegate? = nil) {
        guard !isMonitoring else { 
            print("⚠️ 性能监控已在运行中")
            return 
        }
        
        self.performanceDelegate = delegate
        isMonitoring = true
        
        print("🔍 开始设备性能监控")
        
        // 立即进行一次检测
        performPerformanceCheck()
        
        // 启动定时器进行定期检测
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: config.monitoringInterval, repeats: true) { [weak self] _ in
            self?.performPerformanceCheck()
        }
        
        // 注册系统通知
        setupSystemNotifications()
    }
    
    /// 停止性能监控
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("🔍 停止设备性能监控")
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // 移除系统通知
        NotificationCenter.default.removeObserver(self)
        
        performanceDelegate = nil
    }
    
    /// 获取推荐的录制质量
    func getRecommendedRecordingQuality() -> VideoQuality {
        guard let status = currentStatus else {
            // 没有性能数据时，使用保守设置
            return DeviceInfo.performanceLevel == .low ? .low : .medium
        }
        
        return status.recommendedMaxQuality
    }
    
    /// 检查是否可以安全提升质量
    func canUpgradeQuality() -> Bool {
        guard let status = currentStatus else { return false }
        
        // 检查最近的性能趋势
        let recentSnapshots = performanceHistory.suffix(5) // 最近5次采样
        let averageMemory = recentSnapshots.map { $0.availableMemory }.reduce(0, +) / UInt64(max(recentSnapshots.count, 1))
        
        return status.canPerformHighQualityRecording && 
               averageMemory > 800_000_000 && // 平均可用内存大于800MB
               status.thermalState == .nominal
    }
    
    /// 是否需要立即降级
    func shouldDowngradeImmediately() -> Bool {
        guard let status = currentStatus else { return false }
        
        return status.memoryInfo.availableMemory < config.memoryCriticalThreshold ||
               status.thermalState == .critical ||
               (status.thermalState == .serious && hasTemperatureBeenHighRecently())
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // 启用电池状态监控
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    private func setupSystemNotifications() {
        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 监听低电量模式变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerModeChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        // 监听应用状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func performPerformanceCheck() {
        let status = DeviceInfo.getCurrentPerformanceStatus()
        let previousStatus = currentStatus
        currentStatus = status
        
        // 记录性能快照
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            availableMemory: status.memoryInfo.availableMemory,
            thermalState: status.thermalState,
            batteryLevel: status.batteryLevel,
            isLowPowerMode: status.isLowPowerMode
        )
        addPerformanceSnapshot(snapshot)
        
        // 分析性能变化
        analyzePerformanceChange(from: previousStatus, to: status)
        
        // 通知代理
        performanceDelegate?.performanceMonitor(self, didUpdateStatus: status)
    }
    
    private func addPerformanceSnapshot(_ snapshot: PerformanceSnapshot) {
        performanceHistory.append(snapshot)
        if performanceHistory.count > maxHistoryCount {
            performanceHistory.removeFirst()
        }
    }
    
    private func analyzePerformanceChange(from previous: DeviceInfo.PerformanceStatus?, to current: DeviceInfo.PerformanceStatus) {
        guard let previous = previous else { return }
        
        // 检测内存急剧下降
        let memoryDiff = Int64(current.memoryInfo.availableMemory) - Int64(previous.memoryInfo.availableMemory)
        if memoryDiff < -200_000_000 { // 内存下降超过200MB
            print("⚠️ 检测到内存急剧下降: \(String.formatFileSize(abs(memoryDiff)))")
            performanceDelegate?.performanceMonitor(self, didDetectMemoryPressure: current.memoryInfo)
        }
        
        // 检测温度上升
        if current.thermalState.rawValue > previous.thermalState.rawValue {
            print("🌡️ 设备温度上升: \(previous.thermalState) -> \(current.thermalState)")
            performanceDelegate?.performanceMonitor(self, didDetectThermalStateChange: current.thermalState)
        }
        
        // 检测低电量模式激活
        if !previous.isLowPowerMode && current.isLowPowerMode {
            print("🔋 低电量模式已激活")
            performanceDelegate?.performanceMonitor(self, didActivateLowPowerMode: true)
        }
    }
    
    private func hasTemperatureBeenHighRecently() -> Bool {
        let recentTime = Date().timeIntervalSince1970 - config.temperatureWarningDelay
        return performanceHistory.contains { snapshot in
            snapshot.timestamp.timeIntervalSince1970 > recentTime &&
            (snapshot.thermalState == .serious || snapshot.thermalState == .critical)
        }
    }
    
    // MARK: - System Notification Handlers
    
    @objc private func handleMemoryWarning() {
        print("⚠️ 收到系统内存警告")
        performanceDelegate?.performanceMonitor(self, didReceiveMemoryWarning: ())
        
        // 立即进行性能检测
        performPerformanceCheck()
    }
    
    @objc private func handlePowerModeChange() {
        print("🔋 低电量模式状态变化")
        // 延迟检测，等待系统状态稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performPerformanceCheck()
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("📱 应用进入后台，暂停性能监控")
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    @objc private func handleAppWillEnterForeground() {
        guard isMonitoring else { return }
        print("📱 应用回到前台，恢复性能监控")
        
        // 立即检测一次
        performPerformanceCheck()
        
        // 重新启动定时器
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: config.monitoringInterval, repeats: true) { [weak self] _ in
            self?.performPerformanceCheck()
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Performance Monitor Delegate
protocol PerformanceMonitorDelegate: AnyObject {
    func performanceMonitor(_ monitor: PerformanceMonitor, didUpdateStatus status: DeviceInfo.PerformanceStatus)
    func performanceMonitor(_ monitor: PerformanceMonitor, didDetectMemoryPressure memoryInfo: DeviceInfo.MemoryInfo)
    func performanceMonitor(_ monitor: PerformanceMonitor, didDetectThermalStateChange thermalState: ProcessInfo.ThermalState)
    func performanceMonitor(_ monitor: PerformanceMonitor, didActivateLowPowerMode isActive: Bool)
    func performanceMonitor(_ monitor: PerformanceMonitor, didReceiveMemoryWarning: Void)
}

// MARK: - Performance Snapshot
private struct PerformanceSnapshot {
    let timestamp: Date
    let availableMemory: UInt64
    let thermalState: ProcessInfo.ThermalState
    let batteryLevel: Float
    let isLowPowerMode: Bool
}

// MARK: - Extensions
extension ProcessInfo.ThermalState {
    var displayName: String {
        switch self {
        case .nominal: return "正常"
        case .fair: return "偏高"  
        case .serious: return "过高"
        case .critical: return "危险"
        @unknown default: return "未知"
        }
    }
}
