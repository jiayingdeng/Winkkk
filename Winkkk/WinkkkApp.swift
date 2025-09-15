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
        
        // 配置主题
        ThemeManager.shared.configureTheme()
        
        // 如果不支持Scene (iOS 12及以下)，创建窗口
        if #unavailable(iOS 13.0) {
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
        }
        
        return true
    }
    
    // MARK: - UISceneSession Lifecycle (iOS 13+)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - Scene Delegate (iOS 13+)
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
