# DeepLabV3 人物分割测试页面使用指南

## 📋 功能概述

DeepLabV3TestViewController 是一个功能强大的人物分割测试页面，支持两种主要处理模式：

### 🖼️ 单图模式 (Single Image Mode)
- **功能**: 对单张图片进行人物分割
- **输入**: 从相册选择或拍摄单张照片
- **输出**: 原图、分割掩码、主体图、背景图

### 🎬 时光序列模式 (Time-lapse Mode)  
- **功能**: 从视频提取关键帧并生成时光序列合成图
- **输入**: 从相册选择视频文件
- **输出**: 5个关键帧的分割结果 + 时光序列叠加合成图

---

## 🚀 快速开始

### 1. 进入测试页面
```swift
// 在主界面或设置页面中添加跳转按钮
let testVC = DeepLabV3TestViewController()
navigationController?.pushViewController(testVC, animated: true)
```

### 2. 选择处理模式

#### 单图模式操作流程：
1. 点击 **"选择图片"** 按钮
2. 从相册选择图片或拍摄新照片
3. 点击 **"开始处理"** 按钮
4. 等待分割完成（约2-5秒）
5. 查看结果并保存到相册

#### 时光序列模式操作流程：
1. 点击 **"选择视频"** 按钮  
2. 从相册选择视频文件
3. 系统自动提取5个关键帧
4. 点击 **"批量处理"** 按钮
5. 等待所有帧处理完成（约10-25秒）
6. 点击 **"生成时光序列"** 按钮
7. 查看最终合成结果

---

## 🎯 核心功能详解

### 单图分割功能

**技术特点**：
- 使用 DeepLabV3 模型进行语义分割
- 支持多人物同时识别
- 高精度边缘检测
- 实时进度反馈

**输出结果**：
- **原图**: 用户选择的原始图像
- **分割掩码**: 黑白二值化掩码图
- **主体图**: 提取的人物主体（透明背景）
- **背景图**: 移除人物后的背景

### 视频时光序列功能

**核心算法**：
```swift
// 关键帧提取算法
func extractVideoFrames(from videoURL: URL, frameCount: Int) -> [UIImage]

// 时光序列合成算法  
func createTimeLapseComposite(from results: [DeepLabSegmentationResult]) -> UIImage
```

**处理流程**：
1. **视频解析**: 使用 AVAsset 解析视频时长和帧率
2. **关键帧提取**: 等间隔提取5个代表性帧
3. **批量分割**: 并行处理所有帧的人物分割
4. **时光合成**: 按透明度梯度叠加所有主体图像

**合成效果**：
- 第1帧：20% 透明度（最淡）
- 第2帧：35% 透明度
- 第3帧：50% 透明度  
- 第4帧：65% 透明度
- 第5帧：100% 透明度（最实）

---

## 🛠️ 技术实现细节

### 1. 核心组件架构

```swift
class DeepLabV3TestViewController: UIViewController {
    // 处理模式枚举
    enum ProcessingMode {
        case singleImage    // 单图模式
        case timeLapse     // 时光序列模式
    }
    
    // 核心属性
    var processingMode: ProcessingMode = .singleImage
    var selectedImage: UIImage?
    var selectedVideoURL: URL?
    var extractedFrames: [UIImage] = []
    var frameSegmentationResults: [DeepLabSegmentationResult] = []
    var timeLapseResult: UIImage?
}
```

### 2. UI 组件设计

**主要视图组件**：
- `imageSelectionView`: 图片/视频选择区域
- `videoControlsView`: 视频专用控制面板
- `processingView`: 处理进度显示区域
- `batchProgressView`: 批量处理进度条
- `resultsView`: 单图结果展示区域
- `timeLapseResultView`: 时光序列结果展示区域
- `actionButtonsView`: 操作按钮组

### 3. 关键算法实现

#### 视频帧提取算法
```swift
private func extractVideoFrames(from videoURL: URL, frameCount: Int) throws -> [UIImage] {
    let asset = AVAsset(url: videoURL)
    let duration = asset.duration
    let durationInSeconds = CMTimeGetSeconds(duration)
    
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceAfter = .zero
    generator.requestedTimeToleranceBefore = .zero
    
    var frames: [UIImage] = []
    let interval = durationInSeconds / Double(frameCount)
    
    for i in 0..<frameCount {
        let timeInSeconds = Double(i) * interval
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
        
        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)
        frames.append(uiImage)
    }
    
    return frames
}
```

#### 时光序列合成算法
```swift
private func createTimeLapseComposite(from results: [DeepLabSegmentationResult]) throws -> UIImage {
    let baseImage = results.first!.originalImage
    let canvasSize = baseImage.size
    
    UIGraphicsBeginImageContextWithOptions(canvasSize, false, baseImage.scale)
    guard let context = UIGraphicsGetCurrentContext() else {
        throw TimeLapseError.contextCreationFailed
    }
    
    // 透明度梯度：0.2, 0.35, 0.5, 0.65, 1.0
    let alphaValues: [CGFloat] = [0.2, 0.35, 0.5, 0.65, 1.0]
    
    // 从最淡到最实依次叠加
    for (index, result) in results.enumerated().reversed() {
        let alpha = alphaValues[min(index, alphaValues.count - 1)]
        
        context.saveGState()
        context.setAlpha(alpha)
        
        if let cgImage = result.subjectImage.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: canvasSize))
        }
        
        context.restoreGState()
    }
    
    let compositeImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return compositeImage
}
```

---

## 📊 性能优化策略

### 1. 异步处理
- 所有图像处理操作在后台线程执行
- UI更新严格在主线程进行
- 使用 `DispatchQueue.global(qos: .userInitiated)` 提高响应性

### 2. 内存管理
- 及时释放大尺寸图像资源
- 使用弱引用避免循环引用
- 合理控制并发处理数量

### 3. 批量处理优化
```swift
DeepLabV3Manager.shared.segmentMultipleFrames(
    extractedFrames,
    progressCallback: { current, total in
        // 实时进度反馈
        let progress = Float(current) / Float(total)
        self?.batchProgressBar.progress = progress
    },
    frameCompletion: { index, result in
        // 单帧完成回调
    },
    finalCompletion: { results in
        // 批量完成处理
    }
)
```

---

## ⚠️ 使用注意事项

### 1. 系统要求
- iOS 13.0 或更高版本
- 支持 Core ML 的设备
- 建议使用 A12 芯片或更新型号

### 2. 性能建议
- **单图模式**: 建议图片尺寸不超过 2048x2048
- **视频模式**: 建议视频时长不超过 60秒
- **内存使用**: 处理高分辨率内容时注意内存占用

### 3. 权限要求
```xml
<!-- Info.plist 中需要添加以下权限 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册来选择图片和视频</string>

<key>NSCameraUsageDescription</key>
<string>需要访问相机来拍摄照片</string>
```

### 4. 错误处理
- 自动检测并处理无效输入
- 提供详细的错误信息反馈
- 支持操作取消和重试机制

---

## 🎨 UI/UX 设计亮点

### 1. 直观的模式切换
- 自动识别输入类型（图片/视频）
- 动态调整UI布局和功能按钮
- 清晰的状态指示和进度反馈

### 2. 丰富的视觉反馈
- 实时进度动画
- 状态颜色编码（蓝色-处理中，绿色-成功，红色-错误）
- 平滑的视图切换动画

### 3. 便捷的结果操作
- 一键保存到相册
- 支持多种格式导出
- 快速分享功能

---

## 🔮 未来扩展方向

### 1. 功能增强
- [ ] 支持更多视频格式
- [ ] 自定义关键帧数量
- [ ] 高级合成效果选项
- [ ] 批量图片处理模式

### 2. 性能优化
- [ ] GPU 加速处理
- [ ] 智能缓存机制
- [ ] 后台处理支持

### 3. 用户体验
- [ ] 处理历史记录
- [ ] 自定义预设配置
- [ ] 社交分享集成

---

## 📞 技术支持

如果在使用过程中遇到问题，请检查：

1. **设备兼容性**: 确保设备支持 Core ML
2. **权限设置**: 检查相册和相机访问权限
3. **内存状态**: 关闭其他占用内存的应用
4. **输入格式**: 确保图片/视频格式受支持

---

*最后更新: 2025年9月25日*