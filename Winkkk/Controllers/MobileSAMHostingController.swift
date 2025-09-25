//
//  MobileSAMHostingController.swift
//  将SwiftUI的MobileSAMView包装为UIViewController
//

import UIKit
import SwiftUI

class MobileSAMHostingController: UIHostingController<MobileSAMView> {
    
    init() {
        super.init(rootView: MobileSAMView())
        setupViewController()
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViewController() {
        title = "智能分割"
        
        // 设置导航栏样式
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissViewController)
        )
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置背景色
        view.backgroundColor = UIColor.systemBackground
        
        // 确保安全区域处理
        edgesForExtendedLayout = []
    }
}


