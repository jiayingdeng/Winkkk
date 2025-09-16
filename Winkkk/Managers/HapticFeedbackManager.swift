//
//  HapticFeedbackManager.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  触感反馈管理器 - 统一管理所有触感反馈
//

import UIKit
import CoreHaptics
import AudioToolbox

class HapticFeedbackManager {
    
    // MARK: - Singleton
    static let shared = HapticFeedbackManager()
    
    // MARK: - Properties
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // 触感反馈是否可用
    private var isHapticFeedbackEnabled: Bool {
        // 检查设备是否支持触感反馈
        let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        print("🔍 CHHapticEngine 硬件检查结果: \(supportsHaptics)")
        
        guard supportsHaptics else {
            print("⚠️ 设备不支持触感反馈（根据CHHapticEngine检查）")
            return false
        }
        
        print("✅ 设备支持触感反馈，触感反馈已启用")
        return true
    }
    
    // MARK: - Initialization
    private init() {
        print("🚀 开始初始化 HapticFeedbackManager...")
        setupFeedbackGenerators()
        print("🏁 HapticFeedbackManager 初始化完成")
    }
    
    // MARK: - Setup
    private func setupFeedbackGenerators() {
        guard isHapticFeedbackEnabled else {
            print("⚠️ 触感反馈不可用，跳过初始化")
            return
        }
        
        // 预准备所有反馈生成器
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
        
        print("✅ 触感反馈管理器初始化完成")
    }
    
    // MARK: - Public Methods
    
    /// 轻触反馈
    func lightImpact() {
        guard isHapticFeedbackEnabled else { return }
        
        impactLight.prepare()
        impactLight.impactOccurred()
        print("📳 轻触反馈已触发")
    }
    
    /// 中等强度反馈
    func mediumImpact() {
        guard isHapticFeedbackEnabled else { return }
        
        impactMedium.prepare()
        impactMedium.impactOccurred()
        print("📳 中等触感反馈已触发")
    }
    
    /// 重触反馈
    func heavyImpact() {
        guard isHapticFeedbackEnabled else { return }
        
        impactHeavy.prepare()
        impactHeavy.impactOccurred()
        print("📳 重触反馈已触发")
    }
    
    /// 选择反馈
    func selectionChanged() {
        guard isHapticFeedbackEnabled else { return }
        
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
        print("📳 选择反馈已触发")
    }
    
    /// 成功通知反馈
    func notificationSuccess() {
        guard isHapticFeedbackEnabled else { return }
        
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)
        print("📳 成功通知反馈已触发")
    }
    
    /// 警告通知反馈
    func notificationWarning() {
        guard isHapticFeedbackEnabled else { return }
        
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.warning)
        print("📳 警告通知反馈已触发")
    }
    
    /// 错误通知反馈
    func notificationError() {
        guard isHapticFeedbackEnabled else { return }
        
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.error)
        print("📳 错误通知反馈已触发")
    }
    
    /// 按钮点击反馈（推荐用于按钮交互）
    func buttonTap() {
        print("🎯 按钮点击反馈被调用")
        mediumImpact()
    }
    
    /// 开始录制反馈（推荐用于重要操作）
    func recordingStart() {
        print("🎯 开始录制反馈被调用")
        heavyImpact()
    }
    
    /// 停止录制反馈
    func recordingStop() {
        lightImpact()
    }
    
    /// 截图成功反馈
    func screenshotSuccess() {
        notificationSuccess()
    }
    
    /// 滑动交互反馈
    func sliderValueChanged() {
        lightImpact()
    }
    
    // MARK: - Debug Methods
    
    /// 测试所有触感反馈类型
    func testAllFeedbacks() {
        guard isHapticFeedbackEnabled else {
            print("⚠️ 触感反馈不可用，无法测试")
            return
        }
        
        print("🧪 开始测试触感反馈...")
        
        DispatchQueue.main.async { [weak self] in
            self?.lightImpact()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.mediumImpact()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.heavyImpact()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.selectionChanged()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.notificationSuccess()
                            print("✅ 触感反馈测试完成")
                        }
                    }
                }
            }
        }
    }
    
    /// 重新初始化触感反馈（用于设置变更后）
    func reinitialize() {
        setupFeedbackGenerators()
    }
    
    /// 简化的触感反馈（绕过硬件检查，直接使用UIImpactFeedbackGenerator）
    func simpleFeedback() {
        print("🧪 尝试简化触感反馈（绕过所有检查）")
        let simpleFeedback = UIImpactFeedbackGenerator(style: .medium)
        simpleFeedback.prepare()
        simpleFeedback.impactOccurred()
        print("📳 简化触感反馈已执行")
    }
    
    /// 超级彻底的触感反馈测试（多种方法同时尝试）
    func thoroughHapticTest() {
        print("🔬 开始超级彻底的触感反馈测试...")
        
        // 方法1：延迟执行
        DispatchQueue.main.async {
            print("🧪 测试1：延迟执行的中等强度反馈")
            let impact1 = UIImpactFeedbackGenerator(style: .medium)
            impact1.prepare()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                impact1.impactOccurred()
                print("📳 延迟中等强度反馈已执行")
            }
        }
        
        // 方法2：重度反馈（更明显）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🧪 测试2：重度反馈")
            let impact2 = UIImpactFeedbackGenerator(style: .heavy)
            impact2.prepare()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                impact2.impactOccurred()
                print("📳 重度反馈已执行")
            }
        }
        
        // 方法3：通知反馈（最强烈）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🧪 测试3：错误通知反馈（最强烈）")
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                notification.notificationOccurred(.error)
                print("📳 错误通知反馈已执行")
            }
        }
        
        // 方法4：连续多次重度反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("🧪 测试4：连续3次重度反馈")
            let impact3 = UIImpactFeedbackGenerator(style: .heavy)
            impact3.prepare()
            
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                    impact3.impactOccurred()
                    print("📳 第\(i+1)次重度反馈已执行")
                }
            }
        }
        
        print("🔬 超级彻底测试已安排完成，请留意接下来2.5秒内的触感反馈")
    }
    
    /// 最后的手段：使用系统级音频服务强制振动
    func forceSystemVibration() {
        print("🚨 最后手段：使用AudioServicesPlaySystemSound强制振动")
        
        // 方法1：系统振动
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        print("📳 系统振动已执行")
        
        // 方法2：延迟后再次振动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🚨 第二次系统振动")
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            print("📳 第二次系统振动已执行")
        }
        
        // 方法3：连续多次系统振动
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🚨 开始连续系统振动测试")
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                    print("📳 连续系统振动第\(i+1)次已执行")
                }
            }
        }
    }
}
