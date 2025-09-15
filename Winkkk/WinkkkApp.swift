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
        
        // 创建窗口
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // 设置根视图控制器
        let mainCameraVC = MainCameraViewController()
        let navigationController = UINavigationController(rootViewController: mainCameraVC)
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
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
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 配置主题
        ThemeManager.shared.configureTheme()
        
        // 创建窗口
        window = UIWindow(windowScene: windowScene)
        
        // 检查是否完成引导
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HasCompletedOnboarding")
        
        if hasCompletedOnboarding {
            // 已完成引导，直接进入主界面
            let mainCameraVC = MainCameraViewController()
            let navigationController = UINavigationController(rootViewController: mainCameraVC)
            window?.rootViewController = navigationController
        } else {
            // 未完成引导，显示引导页面
            let onboardingVC = OnboardingViewController()
            window?.rootViewController = onboardingVC
        }
        
        window?.makeKeyAndVisible()
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
