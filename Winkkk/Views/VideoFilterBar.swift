//
//  VideoFilterBar.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  视频筛选按钮栏组件
//

import UIKit

// MARK: - VideoFilterBarDelegate
protocol VideoFilterBarDelegate: AnyObject {
    func videoFilterBar(_ filterBar: VideoFilterBar, didChangeFilters filters: VideoFilterOptions)
}

// MARK: - VideoFilterOptions
struct VideoFilterOptions {
    var showAppRecorded: Bool = true     // 📱 应用拍摄
    var showSystemImported: Bool = true  // 📥 系统导入
    
    var isShowingAll: Bool {
        return showAppRecorded && showSystemImported
    }
    
    mutating func reset() {
        showAppRecorded = true
        showSystemImported = true
    }
}

class VideoFilterBar: UIView {
    
    // MARK: - Properties
    weak var delegate: VideoFilterBarDelegate?
    private var filterOptions = VideoFilterOptions()
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return sv
    }()
    
    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fill
        sv.alignment = .center
        sv.spacing = 12
        return sv
    }()
    
    private lazy var allButton = createFilterButton(title: "全部", type: .all)
    private lazy var appRecordedButton = createFilterButton(title: "📱 应用拍摄", type: .appRecorded)
    private lazy var systemImportedButton = createFilterButton(title: "📥 系统导入", type: .systemImported)
    
    private lazy var resultCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.systemBlue
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    // MARK: - Button Types
    private enum FilterButtonType {
        case all
        case appRecorded
        case systemImported
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        updateButtonStates()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        updateButtonStates()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // 设置与主界面渐变背景协调的粉紫色背景
        // 使用ThemeManager渐变色的中间色调，半透明效果
        backgroundColor = UIColor(red: 242/255, green: 194/255, blue: 237/255, alpha: 0.85)
        
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        // 添加按钮到堆栈视图
        stackView.addArrangedSubview(allButton)
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(appRecordedButton)
        stackView.addArrangedSubview(systemImportedButton)
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(resultCountLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // ScrollView约束
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            scrollView.heightAnchor.constraint(equalToConstant: 44),
            
            // StackView约束
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // 结果数量标签约束
            resultCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            resultCountLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Button Creation
    private func createFilterButton(title: String, type: FilterButtonType) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        button.addTarget(self, action: #selector(filterButtonTapped(_:)), for: .touchUpInside)
        
        // 设置按钮类型标识
        switch type {
        case .all:
            button.tag = 0
        case .appRecorded:
            button.tag = 100
        case .systemImported:
            button.tag = 101
        }
        
        return button
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = UIColor.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return separator
    }
    
    // MARK: - Actions
    @objc private func filterButtonTapped(_ sender: UIButton) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        switch sender.tag {
        case 0: // 全部按钮
            selectAll()
            
        case 100: // 应用拍摄
            selectAppRecorded()
            
        case 101: // 系统导入
            selectSystemImported()
            
        default:
            break
        }
        
        updateButtonStates()
        delegate?.videoFilterBar(self, didChangeFilters: filterOptions)
    }
    
    // 单选模式方法
    private func selectAll() {
        filterOptions.showAppRecorded = true
        filterOptions.showSystemImported = true
    }
    
    private func selectAppRecorded() {
        filterOptions.showAppRecorded = true
        filterOptions.showSystemImported = false
    }
    
    private func selectSystemImported() {
        filterOptions.showAppRecorded = false
        filterOptions.showSystemImported = true
    }
    
    // MARK: - UI Updates
    private func updateButtonStates() {
        updateButtonAppearance(allButton, isSelected: filterOptions.isShowingAll)
        updateButtonAppearance(appRecordedButton, isSelected: filterOptions.showAppRecorded && !filterOptions.showSystemImported)
        updateButtonAppearance(systemImportedButton, isSelected: filterOptions.showSystemImported && !filterOptions.showAppRecorded)
    }
    
    private func updateButtonAppearance(_ button: UIButton, isSelected: Bool) {
        UIView.animate(withDuration: 0.2) {
            if isSelected {
                button.backgroundColor = UIColor.systemBlue
                button.setTitleColor(.white, for: .normal)
                button.layer.borderColor = UIColor.systemBlue.cgColor
            } else {
                button.backgroundColor = UIColor.clear
                button.setTitleColor(.systemBlue, for: .normal)
                button.layer.borderColor = UIColor.systemBlue.cgColor
            }
        }
    }
    
    // MARK: - Public Methods
    func updateResultCount(_ count: Int, total: Int) {
        if filterOptions.isShowingAll {
            resultCountLabel.isHidden = true
        } else {
            resultCountLabel.isHidden = false
            resultCountLabel.text = "\(count)/\(total)"
        }
    }
    
    // 新增：控制FilterBar的显示/隐藏
    func setVisible(_ visible: Bool, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.alpha = visible ? 1 : 0
                self.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: -20)
            }
        } else {
            alpha = visible ? 1 : 0
            transform = visible ? .identity : CGAffineTransform(translationX: 0, y: -20)
        }
    }
    
    func resetFilters() {
        filterOptions.reset()
        updateButtonStates()
        delegate?.videoFilterBar(self, didChangeFilters: filterOptions)
    }
    
    func getCurrentFilters() -> VideoFilterOptions {
        return filterOptions
    }
}

// MARK: - Animation Extensions
extension VideoFilterBar {
    func showWithAnimation() {
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    func hideWithAnimation(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -20)
        } completion: { _ in
            completion?()
        }
    }
}
