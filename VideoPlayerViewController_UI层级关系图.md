# VideoPlayerViewController 完整UI层级关系图

## 📋 文档说明

本文档详细描述了VideoPlayerViewController和ScreenshotDetailSheet的完整UI层级结构，包括所有视图组件、布局关系、交互层级和数据流向。

---

## 🎨 完整UI层级关系图

### 📱 主界面: VideoPlayerViewController

```
🎬 VideoPlayerViewController
│
├── Layer 0: 背景层
│   └── 🌈 gradientBackgroundView
│       └── GradientBackgroundView (渐变背景)
│
├── Layer 1: 视频播放层
│   └── 🎥 playerContainerView (53.3%高度)
│       ├── backgroundColor: .black
│       ├── cornerRadius: ThemeManager.standardCornerRadius
│       └── AVPlayerLayer (视频播放层)
│
└── Layer 2: 控制面板层
    └── 🔳 unifiedControlPanelView (底部统一容器)
        ├── BlurEffectView(style: .regular, intensity: 0.92)
        ├── cornerRadius: ThemeManager.largeCornerRadius
        ├── maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        │
        └── 📦 controlPanelBlurView.contentView
            │
            ├── Layer 2.1: 模式切换器 (顶部)
            │   └── 🔄 captureModeSwitcher
            │       ├── BlurEffectView(style: .regular, intensity: 0.9)
            │       └── containerView
            │           ├── stillImageButton [普通截图]
            │           │   ├── 背景发光效果 (选中时)
            │           │   ├── 边框高亮 (选中时)
            │           │   └── 呼吸动画 (选中时)
            │           ├── separatorView (分隔线)
            │           └── livePhotoButton [实况照片]
            │               ├── 背景发光效果 (选中时)
            │               ├── 边框高亮 (选中时)
            │               └── 呼吸动画 (选中时)
            │
            ├── Layer 2.2: 时间轴系统 (中心区域)
            │   └── 🎞️ timelineView
            │       └── scrollView (UIScrollView)
            │           ├── showsHorizontalScrollIndicator: false
            │           ├── bounces: true
            │           ├── alwaysBounceHorizontal: true
            │           ├── delegate: self
            │           ├── 🎯 内容尺寸系统:
            │           │   ├── leftPadding: bounds.width/2 (让开头到中心)
            │           │   ├── rightPadding: bounds.width/2 (让结尾到中心)
            │           │   ├── baseContentWidth: TimelineView.bounds.width
            │           │   ├── currentContentWidth: 动态计算
            │           │   └── totalWidth: leftPadding + videoContent + rightPadding
            │           │
            │           └── contentView
            │               ├── 📏 timeScaleView (时间刻度层 - 20%高度)
            │               │   ├── backgroundColor: .clear
            │               │   ├── 🔑 动态约束:
            │               │   │   ├── timeScaleLeadingConstraint
            │               │   │   └── timeScaleWidthConstraint
            │               │   ├── 🎯 智能刻度生成:
            │               │   │   ├── 可见范围优化 (±10px缓冲)
            │               │   │   ├── 更新频率限制 (0.1s间隔)
            │               │   │   ├── 范围变化阈值 (10%屏幕宽度)
            │               │   │   └── 时间精度自适应
            │               │   ├── CALayer[] (刻度线)
            │               │   │   ├── backgroundColor: ThemeManager.timelineTickColor
            │               │   │   ├── 主刻度: 12pt高
            │               │   │   └── 副刻度: 8pt高
            │               │   └── CATextLayer[] (时间标签)
            │               │       ├── foregroundColor: ThemeManager.timelineTickColor
            │               │       ├── font: .systemFont(11pt, .medium)
            │               │       ├── alignmentMode: .center
            │               │       └── contentsScale: UIScreen.main.scale
            │               │
            │               ├── 🖼️ thumbnailContainerView (缩略图层 - 60%高度)
            │               │   ├── backgroundColor: UIColor.black.withAlphaComponent(0.3)
            │               │   ├── cornerRadius: 8
            │               │   ├── masksToBounds: true
            │               │   ├── 🔑 动态约束:
            │               │   │   ├── thumbnailContainerLeadingConstraint
            │               │   │   └── thumbnailContainerWidthConstraint
            │               │   └── UIImageView[] (视频帧缩略图)
            │               │       ├── 🎯 动态数量计算:
            │               │       │   ├── 理想宽度: 55-90px (基于缩放)
            │               │       │   ├── 4x+缩放: 55px → 高密度
            │               │       │   ├── 2-4x缩放: 线性插值 80-55px
            │               │       │   ├── 1-2x缩放: 线性插值 90-80px
            │               │       │   └── 智能上限: 300-800张 (基于时长)
            │               │       ├── 🎯 动态高质量分辨率:
            │               │       │   ├── baseTarget: displaySize × screenScale
            │               │       │   ├── qualityMultiplier: 1.2-2.0 (基于缩放)
            │               │       │   ├── 最大: 320×240px
            │               │       │   └── 帧对齐: requestedTimeToleranceAfter/Before = .zero
            │               │       ├── contentMode: .scaleAspectFill
            │               │       ├── clipsToBounds: true
            │               │       ├── layer.magnificationFilter: .linear
            │               │       ├── layer.minificationFilter: .trilinear
            │               │       └── allowsEdgeAntialiasing: true
            │               │
            │               ├── 🛤️ trackView (播放轨道层 - 20%高度)
            │               │   ├── backgroundColor: .clear (透明但可点击)
            │               │   ├── layer.cornerRadius: 2
            │               │   ├── width: TimelineView.bounds.width
            │               │   └── 点击跳转功能
            │               │
            │               ├── ⚪ playheadIndicator (截图瞄准器)
            │               │   ├── zPosition: 1000
            │               │   ├── backgroundColor: .white
            │               │   ├── cornerRadius: 1.5
            │               │   ├── width: 2pt
            │               │   ├── 🎯 增强视觉效果:
            │               │   │   ├── shadowColor: .black
            │               │   │   ├── shadowOffset: (0, 2)
            │               │   │   ├── shadowRadius: 4
            │               │   │   ├── shadowOpacity: 0.8
            │               │   │   ├── borderWidth: 1.0
            │               │   │   ├── borderColor: white.withAlphaComponent(0.9)
            │               │   │   └── masksToBounds: false
            │               │   ├── 🎯 脉冲动画:
            │               │   │   ├── keyPath: "transform.scale"
            │               │   │   ├── fromValue: 1.0 → toValue: 1.05
            │               │   │   ├── duration: 1.5s
            │               │   │   ├── repeatCount: .infinity
            │               │   │   ├── autoreverses: true
            │               │   │   └── timingFunction: .easeInEaseOut
            │               │   ├── 🎯 拖拽交互:
            │               │   │   ├── 开始: transform.scale(1.2, 1.0)
            │               │   │   └── 结束: .identity
            │               │   └── centerX约束 → 屏幕中心 (由VideoPlayerViewController管理)
            │               │
            │               ├── 🟡 livePhotoRangeView (Live Photo范围指示器)
            │               │   ├── backgroundColor: systemRed.withAlphaComponent(0.3)
            │               │   ├── borderWidth: 1
            │               │   ├── borderColor: systemRed.withAlphaComponent(0.6)
            │               │   ├── cornerRadius: 4
            │               │   ├── isHidden: true (默认，Live Photo模式启用)
            │               │   ├── 🎯 智能居中算法:
            │               │   │   ├── 理想时长: 3.0秒
            │               │   │   ├── keyPhotoOffset: 1.5秒
            │               │   │   ├── 居中逻辑: 以白色竖线为中心
            │               │   │   ├── 边界检测: 
            │               │   │   │   ├── 左边界: leftPadding
            │               │   │   │   └── 右边界: leftPadding + videoWidth
            │               │   │   ├── 智能调整:
            │               │   │   │   ├── 超出左边界 → 左对齐
            │               │   │   │   ├── 超出右边界 → 右对齐
            │               │   │   │   └── 可完美居中 → 居中
            │               │   │   └── 实时更新: 滚动/缩放/播放时
            │               │   └── UILabel (时长标签)
            │               │       ├── text: "3.0s" / "2.5s" / 动态格式
            │               │       ├── textColor: .white
            │               │       ├── font: .systemFont(10pt, .bold)
            │               │       └── textAlignment: .center
            │               │
            │               └── 🚫 隐藏的传统组件 (保持兼容性)
            │                   ├── progressView (isHidden: true)
            │                   │   ├── backgroundColor: ThemeManager.buttonPrimary
            │                   │   └── cornerRadius: 2
            │                   └── thumbView (isHidden: true)
            │                       ├── backgroundColor: .white
            │                       ├── cornerRadius: 12
            │                       ├── size: 24×24pt
            │                       └── borderColor: ThemeManager.buttonPrimary
            │
            ├── Layer 2.3: 播放控制 (左侧)
            │   └── ⏯️ playPauseButton
            │       ├── size: 50x50pt
            │       ├── backgroundColor: ThemeManager.buttonPrimary.withAlphaComponent(0.8)
            │       ├── cornerRadius: 25
            │       └── 触摸动画效果
            │
            ├── Layer 2.4: 时间显示 (底部)
            │   ├── 🕐 currentTimeLabel (左下)
            │   │   ├── font: monospacedDigitSystemFont
            │   │   ├── textColor: .white
            │   │   └── text: "00:00"
            │   │
            │   └── 🕑 totalTimeLabel (右下)
            │       ├── font: monospacedDigitSystemFont
            │       ├── textColor: white.withAlphaComponent(0.7)
            │       └── text: "00:00"
            │
            ├── Layer 2.5: 截图按钮 (中下) - 最高交互优先级
            │   └── 📷 screenshotButton
            │       ├── zPosition: 1000
            │       ├── size: 180x48pt
            │       ├── backgroundColor: ThemeManager.success
            │       ├── cornerRadius: ThemeManager.largeCornerRadius
            │       ├── title: "截取当前画面"
            │       ├── image: "camera.fill"
            │       ├── 阴影效果 (shadowColor: success, shadowRadius: 8)
            │       ├── 边框高亮 (borderColor: white, borderWidth: 2)
            │       ├── isExclusiveTouch: true
            │       └── 触摸动画效果
            │
            └── Layer 2.6: 截图预览栏 (底部) - 最高视觉层级
                └── 📸 screenshotPreviewBar
                    ├── zPosition: 1500
                    ├── backgroundColor: .clear (透明，统一容器提供毛玻璃)
                    ├── 动态高度: 0-150pt
                    ├── isUserInteractionEnabled: true
                    │
                    ├── headerView (头部信息区域 - 30pt高度)
                    │   ├── backgroundColor: .clear
                    │   ├── hintLabel (左对齐)
                    │   │   ├── text: "已截X张: 模式 (最多Y张)"
                    │   │   ├── font: ThemeManager.captionFont
                    │   │   ├── textColor: white.withAlphaComponent(0.8)
                    │   │   └── 接近上限时变orange
                    │   │
                    │   └── clearButton (右对齐)
                    │       ├── title: "🗑"
                    │       ├── backgroundColor: systemRed.withAlphaComponent(0.1)
                    │       ├── size: 30x28pt
                    │       └── cornerRadius: ThemeManager.smallCornerRadius
                    │
                    └── scrollView (截图滚动区域 - 60pt高度，最高优先级)
                        ├── showsHorizontalScrollIndicator: false
                        ├── alwaysBounceHorizontal: true
                        ├── decelerationRate: .fast
                        ├── clipsToBounds: false (让删除按钮超出显示)
                        ├── heightConstraint.priority: 1000 (绝对不压缩)
                        │
                        └── stackView (水平堆叠)
                            ├── axis: .horizontal
                            ├── spacing: 8pt
                            ├── alignment: .center
                            ├── distribution: .fill (支持不同宽度)
                            ├── clipsToBounds: false (让删除按钮超出边界)
                            ├── leading/trailing padding: 12pt
                            │
                            └── ScreenshotThumbnailView[] (动态尺寸缩略图)
                                ├── 🎯 动态宽度算法:
                                │   ├── aspectRatio > 1.5 (横向长图): min(90, 60*ratio)
                                │   ├── aspectRatio < 0.7 (竖向长图): 60/ratio
                                │   └── else (接近正方形): 60pt
                                ├── 🎯 动态高度算法:
                                │   ├── 基于宽度和长宽比计算
                                │   └── 范围: 40-60pt
                                ├── UIImageView (截图图片)
                                ├── deleteButton (删除按钮，可超出边界)
                                ├── 点击手势 → ScreenshotDetailSheet
                                ├── 长按手势 → 多选模式
                                └── 🆕 弹跳动画 (仅新增截图)
```

---

### 📋 弹出层: ScreenshotDetailSheet

```
📋 ScreenshotDetailSheet (modalPresentationStyle: .pageSheet)
│
├── Layer 0: 背景层
│   └── 🌈 gradientBackgroundView
│       └── GradientBackgroundView (渐变背景，与主界面一致)
│
├── Layer 1: 导航层
│   └── navigationBar (44pt高度)
│       ├── backgroundColor: .clear
│       ├── titleLabel (中心)
│       │   ├── text: "1 / 3"
│       │   ├── font: .systemFont(17pt, .semibold)
│       │   └── textColor: .white (白色文字)
│       ├── closeButton (左侧)
│       │   ├── title: "✕"
│       │   ├── size: 44x44pt
│       │   ├── font: .systemFont(18pt, .medium)
│       │   └── titleColor: .white
│       └── shareButton (右侧)
│           ├── image: "square.and.arrow.up"
│           ├── size: 44x44pt
│           └── tintColor: .white
│
└── Layer 2: 内容滚动层
    └── scrollView (水平分页滚动)
        ├── isPagingEnabled: true
        ├── showsHorizontalScrollIndicator: false
        ├── contentSize: 屏幕宽度 × 截图数量
        │
        └── stackView (水平布局)
            ├── axis: .horizontal
            ├── spacing: 0
            ├── distribution: .fillEqually
            │
            └── containerView[] (每个截图一个容器)
                ├── backgroundColor: .black
                ├── width: UIScreen.main.bounds.width
                │
                ├── 📸 普通截图分支:
                │   └── UIImageView
                │       ├── contentMode: .scaleAspectFit
                │       ├── image: screenshot.image
                │       └── 全屏约束
                │
                └── 🎬 Live Photo分支:
                    ├── PHLivePhotoView (主体)
                    │   ├── contentMode: .scaleAspectFit
                    │   ├── isMuted: false (启用音频)
                    │   ├── playbackGestureRecognizer: enabled (长按播放)
                    │   ├── delegate: self (监听播放状态)
                    │   ├── tag: 9999 (便于查找)
                    │   ├── 🎯 自动播放逻辑:
                    │   │   ├── viewDidAppear后1.5秒首次播放
                    │   │   ├── 3秒后备用播放机制
                    │   │   ├── 使用.full完整播放模式
                    │   │   └── PHLivePhotoViewDelegate回调监听
                    │   ├── 🎯 直接加载方式:
                    │   │   ├── 绕过LivePhotoMaker二次处理
                    │   │   ├── PHLivePhoto.request(withResourceFileURLs:)
                    │   │   ├── 使用原始文件保留元数据
                    │   │   └── 异步Task加载
                    │   └── 全屏约束
                    │
                    └── livePhotoIndicator (右上角标识)
                        ├── backgroundColor: black.withAlphaComponent(0.6)
                        ├── cornerRadius: 16
                        ├── size: 60x32pt
                        ├── position: topAnchor+16, trailingAnchor-16
                        ├── iconLabel ("LIVE")
                        │   ├── textColor: .white
                        │   ├── font: .systemFont(12pt, .semibold)
                        │   ├── leadingAnchor+8
                        │   └── centerYAnchor
                        └── circleView (圆形图标)
                            ├── backgroundColor: .clear
                            ├── borderColor: .white
                            ├── borderWidth: 1.5
                            ├── cornerRadius: 6
                            ├── size: 12x12pt
                            ├── trailingAnchor-8
                            └── centerYAnchor
```

---

## 🎯 关键层级特点

### 1. **Z-Index层级优先级**

```
ScreenshotDetailSheet (modal) → 最高层
screenshotPreviewBar (zPosition: 1500) → 应用内最高层
screenshotButton (zPosition: 1000) → 交互优先层
playheadIndicator (zPosition: 1000) → 视觉引导层
其他UI组件 → 默认层级
```

### 2. **交互响应链**

```
用户触摸
    ↓
手势识别器判断 (gestureRecognizer:shouldReceive:)
    ↓
按钮优先响应 (UIButton检测)
    ↓
时间轴手势响应 (Pan/Pinch)
    ↓
默认视图响应
```

### 3. **数据流向**

```
VideoPlayerViewController
    ↓ 截图数据
ScreenshotManager (单例)
    ↓ 数据同步
ScreenshotPreviewBar
    ↓ 点击事件
ScreenshotDetailSheet (弹出预览)
```

### 4. **动态布局系统**

- **时间轴**: 
  - 滚动容器架构 (leftPadding + 视频内容 + rightPadding)
  - 动态缩放: 0.5x - 8.0x
  - 智能刻度生成 (可见范围优化)
  - 时间精度自适应 (秒级/精细/帧级别)
- **缩略图**: 
  - 动态数量: 55-90px理想宽度 (基于缩放)
  - 智能上限: 300-800张 (基于时长)
  - 高质量分辨率: 动态计算 (1.2-2.0×质量倍率)
  - 帧对齐: 零容差时间精度
- **预览栏**: 
  - 动态高度: 0-150pt
  - 缩略图动态尺寸: 40-90pt宽 × 40-60pt高 (基于长宽比)
  - clipsToBounds: false (删除按钮可超出)
- **Live Photo指示器**: 
  - 智能居中算法 (以白色竖线为中心)
  - 边界检测和自动调整
  - 动态时长标签 (3.0s / 2.5s / 0.5s)

---

## 📐 关键尺寸规格

### VideoPlayerViewController 主要组件尺寸

| 组件 | 尺寸 | 说明 |
|------|------|------|
| playerContainerView | 屏幕宽度 × 53.3%高度 | 视频播放区域 |
| captureModeSwitcher | 200×36pt | 模式切换器 |
| timelineView | 屏幕宽度 × 120pt | 时间轴总高度 |
| playPauseButton | 50×50pt | 播放/暂停按钮 |
| screenshotButton | 180×48pt | 截图按钮 |
| screenshotPreviewBar | 屏幕宽度 × 0-150pt | 动态高度预览栏 |

### ScreenshotDetailSheet 主要组件尺寸

| 组件 | 尺寸 | 说明 |
|------|------|------|
| navigationBar | 屏幕宽度 × 44pt | 导航栏 |
| closeButton | 44×44pt | 关闭按钮 |
| shareButton | 44×44pt | 分享按钮 |
| livePhotoIndicator | 60×32pt | Live Photo标识 |
| containerView | 屏幕宽度 × 屏幕高度 | 单个截图容器 |

---

## 🎨 主题颜色规范

### 主色调

- **背景渐变**: GradientBackgroundView
- **毛玻璃**: BlurEffectView (intensity: 0.92)
- **详情页背景**: `#FCF0FF` (粉紫色)

### 功能色

- **成功/截图**: ThemeManager.success (绿色)
- **危险/删除**: systemRed
- **Live Photo指示**: systemRed.withAlphaComponent(0.3)
- **高亮边框**: white

### 透明度规范

- **标签文字**: 0.8
- **次要文字**: 0.7
- **背景遮罩**: 0.3-0.6
- **按钮背景**: 0.1-0.8

---

## 🔄 动画效果说明

### 1. 截图按钮动画
- 触摸时: 缩放至0.95
- 释放时: 弹回1.0
- 成功后: 绿色闪烁

### 2. 模式切换器动画
- 选中时: 背景发光效果
- 呼吸动画: 边框高亮脉冲

### 3. playheadIndicator动画
- 脉冲动画: CABasicAnimation
- 阴影效果: shadowOpacity 0.8

### 4. Live Photo自动播放
- 滑动到当前页面时自动播放
- 支持长按手势交互

---

## 🛠️ 技术实现要点

### 1. 时间轴滚动容器架构
- **三段式布局**: leftPadding + 视频内容 + rightPadding
- **首尾对齐**: padding = bounds.width / 2，让视频开头/结尾能到达屏幕中心
- **有效滚动范围**: 
  ```swift
  minScrollOffset = videoStartX - centerX  // 让开头到中心
  maxScrollOffset = videoEndX - centerX    // 让结尾到中心
  ```
- **动态缩放**: 0.5x (全局概览) → 8.0x (帧级精度)
- **平滑动画**: UIView.animate (0.5s, easeInOut曲线)

### 2. 截图缩略图动态尺寸
```swift
// 基于长宽比计算动态尺寸
let aspectRatio = image.size.width / image.size.height
let dynamicWidth = max(40, min(90, 60 * aspectRatio))
let dynamicHeight = max(40, min(60, 60 / aspectRatio))
```

### 3. Live Photo智能居中
```swift
// 确保范围指示器始终在可见区域
let visibleRange = timelineScrollView.bounds
let rangeCenter = livePhotoRangeView.center.x
if rangeCenter < visibleRange.minX || rangeCenter > visibleRange.maxX {
    // 自动滚动到居中位置
}
```

### 4. 手势处理系统

#### 4.1 时间轴手势 (TimelineView)

**Pan手势 (拖拽滚动)**:
```swift
// Wink编辑器模式: 拖拽滚动时间轴，白色竖线固定
- began: 
  - isDragging = true
  - playheadIndicator.transform = scale(1.2, 1.0)  // 脉冲效果
  - HapticFeedbackManager.sliderValueChanged()
- changed:
  - newOffsetX = currentOffsetX - translation.x  // 反向滚动
  - clampedOffset = max(scrollRange.min, min(scrollRange.max, newOffsetX))
  - scrollView.setContentOffset(clampedOffset, animated: false)
  - 实时通知截取时间变化
  - 更新Live Photo范围指示器
- ended:
  - isDragging = false
  - playheadIndicator.transform = .identity
```

**Pinch手势 (缩放)**:
```swift
- began:
  - isZooming = true
  - HapticFeedbackManager.lightImpact()
- changed:
  - 记录缩放前中心点的时间
  - newScale = zoomScale × gesture.scale
  - clampedScale = max(0.5, min(8.0, newScale))
  - 更新内容尺寸 (updateContentSize)
  - 保持相同时间点在手势中心
  - 重新生成高质量缩略图
  - 更新时间精度 (秒级/精细/帧级别)
- ended:
  - isZooming = false
  - showZoomLevelIndicator()  // "4.0x - 帧级别"
  - HapticFeedbackManager.mediumImpact()
```

**同时识别**:
```swift
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                      shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
    return (gestureRecognizer == pinchGesture && other == panGesture) ||
           (gestureRecognizer == panGesture && other == pinchGesture)
}
```

#### 4.2 交互冲突解决 (三层检测)

```swift
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                      shouldReceive touch: UITouch) -> Bool {
    // 🚨 方法1: 响应链查找UIButton
    if let superview = self.superview {
        let touchPointInSuperview = touch.location(in: superview)
        if let hitView = superview.hitTest(touchPointInSuperview, with: nil) {
            var currentView: UIView? = hitView
            while currentView != nil {
                if currentView is UIButton { return false }  // 按钮优先
                currentView = currentView?.superview
            }
        }
    }
    
    // 🚨 方法2: 直接检查触摸视图
    if touch.view is UIButton { return false }
    
    // 🚨 方法3: 检查父视图链
    var parentView = touch.view?.superview
    while parentView != nil {
        if parentView is UIButton { return false }
        parentView = parentView?.superview
    }
    
    return true
}
```

---

## 🎯 高级特性详解

### 1. 时间精度自适应系统

**TimeResolution枚举**:
```swift
enum TimeResolution {
    case seconds      // 1x-2x: 显示秒
    case halfSeconds  // 2x-4x: 显示0.5秒间隔
    case frames       // 4x+: 显示帧级别刻度
}
```

**自动切换逻辑**:
```swift
func updateTimeResolution() {
    if zoomScale <= 2.0 {
        currentTimeResolution = .seconds       // 1.0秒间隔
    } else if zoomScale <= 4.0 {
        currentTimeResolution = .halfSeconds   // 0.5秒间隔
    } else {
        currentTimeResolution = .frames        // 1/frameRate 间隔 (如 1/30s)
    }
    generateTimeScale()  // 重新生成刻度
}
```

**智能刻度生成**:
```swift
- 性能优化:
  - 更新频率限制: 0.1s最小间隔
  - 范围变化阈值: 10%屏幕宽度
  - 只绘制可见区域 ±10px缓冲
- 刻度类型:
  - 主刻度: 每秒标记，12pt高，显示时间文字
  - 副刻度: 半秒/帧标记，8pt高，无文字
- 坐标系统:
  - 使用timeToVideoContentCoordinate() 转换
  - 0秒 = x:0，duration = x:videoContentWidth
  - 时间刻度视图与视频内容区域完全对齐
```

### 2. 缩略图生成算法

**动态数量计算**:
```swift
func calculateOptimalThumbnailCount() -> Int {
    let videoContentWidth = getActualVideoWidth()
    
    // 理想宽度随缩放级别调整
    let idealThumbnailWidth: CGFloat = {
        if zoomScale >= 4.0 { return 55 }        // 高缩放: 密集
        else if zoomScale >= 2.0 {
            let factor = (zoomScale - 2.0) / 2.0
            return 80 - factor * 25              // 线性插值 80→55
        } else if zoomScale >= 1.0 {
            let factor = (zoomScale - 1.0) / 1.0
            return 90 - factor * 10              // 线性插值 90→80
        } else { return 90 }                     // 低缩放: 稀疏
    }()
    
    let optimalCount = Int(ceil(videoContentWidth / idealThumbnailWidth))
    
    // 智能上限 (基于视频时长)
    let dynamicMaxCount = duration < 30 ? 800 : 
                         duration < 60 ? 600 : 
                         duration < 120 ? 500 : 
                         duration < 300 ? 400 : 300
    
    return max(5, min(dynamicMaxCount, optimalCount))
}
```

**高质量分辨率计算**:
```swift
func calculateOptimalThumbnailSize(displayWidth: CGFloat, 
                                  displayHeight: CGFloat) -> CGSize {
    let screenScale = UIScreen.main.scale
    let baseTargetWidth = displayWidth * screenScale
    let baseTargetHeight = displayHeight * screenScale
    
    // 缩放级别越高，提供更高分辨率
    let qualityMultiplier: CGFloat = {
        if zoomScale >= 4.0 { return 2.0 }       // 超高清
        else if zoomScale >= 2.0 { return 1.5 }  // 高清
        else { return 1.2 }                      // 标清
    }()
    
    let finalWidth = min(baseTargetWidth * qualityMultiplier, 320)
    let finalHeight = min(baseTargetHeight * qualityMultiplier, 240)
    
    return CGSize(width: finalWidth, height: finalHeight)
}
```

**帧对齐策略**:
```swift
// 确保缩略图与视频帧精确对应
imageGenerator.requestedTimeToleranceAfter = .zero
imageGenerator.requestedTimeToleranceBefore = .zero

// 将缩略图时间对齐到视频帧边界
let frameDuration = 1.0 / frameRate
let frameNumber = round(targetTime / frameDuration)
var alignedTime = frameNumber * frameDuration

// 防止最后一帧超出视频时长
if alignedTime >= duration {
    alignedTime = max(0, duration - frameDuration)
}
```

### 3. Live Photo智能居中算法

**核心逻辑**:
```swift
func updateLivePhotoRangePosition() {
    // 1. 获取白色竖线当前时间
    let currentTime = getCurrentCaptureTime()
    
    // 2. 计算理想时间范围 (3秒，关键帧偏移1.5秒)
    let keyPhotoOffset: Double = 1.5
    let livePhotoDuration: Double = 3.0
    let idealStartTime = currentTime - keyPhotoOffset
    let idealEndTime = idealStartTime + livePhotoDuration
    
    // 3. 边界约束
    let actualStartTime = max(0, idealStartTime)
    let actualEndTime = min(duration, idealEndTime)
    let actualDuration = actualEndTime - actualStartTime
    
    // 4. 计算显示宽度
    let idealRangeWidth = CGFloat(livePhotoDuration * timeToPixelRatio)
    let actualRangeWidth = CGFloat(actualDuration * timeToPixelRatio)
    
    // 5. 智能定位
    let playheadScreenX = scrollView.contentOffset.x + bounds.width / 2
    var centerBasedStartX = playheadScreenX - idealRangeWidth / 2
    
    // 6. 边界检测和调整
    if centerBasedStartX < leftPadding {
        rangeStartX = leftPadding  // 左对齐
    } else if centerBasedStartX + idealRangeWidth > leftPadding + videoWidth {
        rangeStartX = leftPadding + videoWidth - idealRangeWidth  // 右对齐
    } else {
        rangeStartX = centerBasedStartX  // 完美居中
    }
    
    // 7. 动态更新标签
    updateLivePhotoRangeLabel(actualDuration)  // "3.0s" / "2.5s" / "0.5s"
}
```

**触发时机**:
- 用户拖拽滚动时间轴
- 缩放时间轴
- 播放视频时
- 切换到Live Photo模式

---

## 📝 维护建议

### 1. 层级管理
- 保持 zPosition 值的一致性
- 避免过度使用高 zPosition
- 优先使用视图层级而非 zPosition

### 2. 性能优化
- 缩略图使用动态分辨率
- 及时释放不可见的 Live Photo 资源
- 避免频繁的布局计算

### 3. 可访问性
- 所有交互元素支持 VoiceOver
- 按钮尺寸符合最小点击区域要求 (44×44pt)
- 颜色对比度符合 WCAG 标准

---

## 📚 相关文档

- [三分屏布局优化说明.md](./三分屏布局优化说明.md)
- [VideoPlayerViewController组件关系图.md](./VideoPlayerViewController组件关系图.md)
- [Live_Photo_蓝色框动态缩放分析.md](./Live_Photo_蓝色框动态缩放分析.md)

---

**文档版本**: v2.0  
**创建日期**: 2025-10-01  
**最后更新**: 2025-10-01

---

## 📝 更新日志

### v2.0 (2025-10-01) - 重大更新
**新增内容**:
- ✨ 完整的时间轴滚动容器架构说明
- ✨ Live Photo智能居中算法详解
- ✨ 时间精度自适应系统 (秒级/精细/帧级别)
- ✨ 缩略图动态生成算法 (数量计算 + 高质量分辨率)
- ✨ 手势处理系统详解 (Pan/Pinch + 交互冲突解决)
- ✨ ScreenshotPreviewBar透明背景架构
- ✨ ScreenshotDetailSheet的GradientBackgroundView

**更新内容**:
- 🔄 时间轴系统层级结构 (60%缩略图 + 20%刻度 + 20%轨道)
- 🔄 动态约束系统 (thumbnailContainer + timeScale)
- 🔄 截图预览栏动态尺寸算法 (基于长宽比)
- 🔄 Live Photo自动播放机制 (viewDidAppear + 备用机制)

**技术细节**:
- 📐 三段式布局: leftPadding + 视频内容 + rightPadding
- 🎯 智能刻度生成: 可见范围优化 + 更新频率限制
- 🖼️ 高质量缩略图: 动态分辨率 (1.2-2.0× qualityMultiplier)
- 🎨 脉冲动画: playheadIndicator增强视觉反馈
- 🔄 帧对齐策略: requestedTimeToleranceAfter/Before = .zero

### v1.0 (2025-10-01) - 初始版本
- 📱 基础UI层级结构
- 🎯 关键尺寸规格
- 🎨 主题颜色规范
- 🔄 动画效果说明
