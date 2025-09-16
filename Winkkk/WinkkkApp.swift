//
//  WinkkkApp.swift
//  Winkkk
//
//  Created by tw1234 on 2025/9/15.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("🚨 AppDelegate: application(_:didFinishLaunchingWithOptions:) - START")
        
        // 配置主题
        do {
            ThemeManager.shared.configureTheme()
            print("✅ AppDelegate: Theme configured successfully")
        } catch {
            print("❌ AppDelegate: Theme configuration failed: \(error)")
        }
        
        // 只在不支持Scene的设备上 (iOS 12及以下) 创建窗口
        if #unavailable(iOS 13.0) {
            print("📱 AppDelegate: iOS 12 or below, setting up window manually")
            window = UIWindow(frame: UIScreen.main.bounds)
            
            // 检查是否完成引导
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HasCompletedOnboarding")
            
            if hasCompletedOnboarding {
                let mainCameraVC = MainCameraViewController()
                let navigationController = UINavigationController(rootViewController: mainCameraVC)
                window?.rootViewController = navigationController
            } else {
                let onboardingVC = OnboardingViewController()
                window?.rootViewController = onboardingVC
            }
            
            window?.makeKeyAndVisible()
        } else {
            print("📱 AppDelegate: iOS 13+, Scene system should handle window creation")
            print("📝 AppDelegate: Available scene configurations:")
            if let manifest = Bundle.main.infoDictionary?["UIApplicationSceneManifest"] as? [String: Any],
               let configurations = manifest["UISceneConfigurations"] as? [String: Any],
               let windowSceneConfigs = configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]] {
                for config in windowSceneConfigs {
                    print("   - Name: \(config["UISceneConfigurationName"] ?? "nil")")
                    print("   - Delegate: \(config["UISceneDelegateClassName"] ?? "nil")")
                }
            } else {
                print("❌ AppDelegate: No scene configurations found in Info.plist!")
            }
        }
        
        print("✅ AppDelegate: application(_:didFinishLaunchingWithOptions:) - COMPLETED")
        return true
    }
    
    // MARK: - UISceneSession Lifecycle (iOS 13+)
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🔗 AppDelegate: configurationForConnecting called")
        print("   Session role: \(connectingSceneSession.role)")
        print("   Connection options: \(options)")
        
        // 明确设置Scene配置
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        
        print("   Created config: \(config)")
        print("   Delegate class: \(String(describing: config.delegateClass))")
        print("   Scene class: \(String(describing: config.sceneClass))")
        
        return config
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        print("🗑️ AppDelegate: didDiscardSceneSessions called")
        print("   Discarded sessions count: \(sceneSessions.count)")
    }
}

// MARK: - Scene Delegate (iOS 13+)
@available(iOS 13.0, *)
@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🚀 SceneDelegate: scene(_:willConnectTo:) called")
        
        guard let windowScene = (scene as? UIWindowScene) else { 
            print("❌ SceneDelegate: windowScene is nil!")
            return 
        }
        
        print("✅ SceneDelegate: WindowScene created")
        
        // 配置主题
        do {
            ThemeManager.shared.configureTheme()
            print("✅ SceneDelegate: Theme configured")
        } catch {
            print("❌ SceneDelegate: Theme configuration failed: \(error)")
        }
        
        // 创建窗口
        window = UIWindow(windowScene: windowScene)
        print("✅ SceneDelegate: Window created")
        
        // 检查是否完成引导
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HasCompletedOnboarding")
        print("🔍 SceneDelegate: HasCompletedOnboarding = \(hasCompletedOnboarding)")
        
        if hasCompletedOnboarding {
            // 已完成引导，直接进入主界面
            print("📱 SceneDelegate: Loading MainCameraViewController")
            let mainCameraVC = MainCameraViewController()
            let navigationController = UINavigationController(rootViewController: mainCameraVC)
            window?.rootViewController = navigationController
        } else {
            // 未完成引导，显示引导页面
            print("📖 SceneDelegate: Loading OnboardingViewController")
            let onboardingVC = OnboardingViewController()
            window?.rootViewController = onboardingVC
        }
        
        window?.makeKeyAndVisible()
        print("✅ SceneDelegate: Window made key and visible")
        print("🎯 SceneDelegate: Root VC = \(window?.rootViewController?.description ?? "nil")")
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Save data here
        PersistenceController.shared.save()
    }
}
