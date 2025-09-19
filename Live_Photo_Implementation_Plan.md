# Live Photo功能完整实现方案

## 📋 现状分析

### 🔍 当前问题
1. ✅ **已有基础设施**：`LivePhotoConfig`、技术文档、基本的时间轴支持
2. ❌ **缺失核心功能**：只截取静态帧，没有真正的Live Photo创建能力
3. ❌ **数据模型不完整**：`ScreenshotItem`缺少Live Photo相关字段
4. ❌ **预览界面不支持**：只能显示静态图片，无法播放Live Photo

### 🚨 核心问题
**Live Photo截图实际上只是静态图片，没有包含3秒视频数据！**

当前的实现中：
- `screenshotEngine.captureFrame()` 只提取单帧图像
- `ScreenshotItem` 只存储静态图片路径
- 预览界面只显示静态图片，无法播放Live Photo

---

## 🎯 完整实施步骤

## **阶段一：数据模型扩展** 🗄️

### 步骤1.1：扩展ScreenshotItem数据模型
需要添加的新字段：
```swift
@NSManaged public var livePhotoVideoPath: URL?     // Live Photo视频文件路径
@NSManaged public var livePhotoIdentifier: String?  // Live Photo配对标识符
@NSManaged public var livePhotoDuration: Double     // Live Photo持续时间
@NSManaged public var keyPhotoOffset: Double        // 封面帧偏移时间
```

### 步骤1.2：更新Core Data模型定义
- 修改 `WinkkkDataModel.swift` 添加新属性
- 创建数据库迁移策略
- 更新 `PersistenceController` 支持新字段

---

## **阶段二：Live Photo引擎开发** ⚙️

### 步骤2.1：创建视频片段提取器
```swift
// 新建：Winkkk/Managers/VideoSegmentExtractor.swift
class VideoSegmentExtractor {
    func extractSegment(from videoURL: URL, startTime: CMTime, duration: CMTime) async -> URL?
    func generateCoverFrame(from videoURL: URL, at time: CMTime) async -> UIImage?
}
```

### 步骤2.2：创建Live Photo组装器
```swift
// 新建：Winkkk/Managers/LivePhotoMaker.swift
class LivePhotoMaker {
    func createLivePhoto(videoURL: URL, imageURL: URL) async -> PHLivePhoto?
    private func addMetadata(to videoURL: URL, and imageURL: URL, identifier: String) -> Bool
}
```

### 步骤2.3：升级截图引擎
```swift
// 修改：Winkkk/Managers/ScreenshotEngine.swift
// 添加Live Photo截图方法：
func captureLivePhoto(from videoURL: URL, at time: CMTime, completion: @escaping (Result<ScreenshotItem, ScreenshotError>) -> Void)
```

---

## **阶段三：用户界面升级** 🎨

### 步骤3.1：升级预览界面
```swift
// 修改：Winkkk/Views/ScreenshotDetailSheet.swift
// 添加Live Photo播放支持：
- 检测截图类型（静态/Live Photo）
- Live Photo使用PHLivePhotoView
- 静态图片使用UIImageView
- 添加播放控制和状态指示
```

### 步骤3.2：升级缩略图视图
```swift
// 修改：Winkkk/Views/ScreenshotThumbnailView.swift
// 添加Live Photo标识：
- Live Photo图标覆盖层
- 动画预览效果
- 区分显示样式
```

### 步骤3.3：时间轴Live Photo范围优化
```swift
// 修改：Winkkk/Views/TimelineView.swift
// 完善Live Photo范围指示器：
- 实时显示3秒选择范围
- 封面帧位置指示
- 范围拖拽调整功能
```

---

## **阶段四：业务逻辑集成** 🔄

### 步骤4.1：修改截图流程
```swift
// 修改：Winkkk/Controllers/VideoPlayerViewController.swift
// screenshotButtonTapped方法：
- 检测当前模式（静态/Live Photo）
- Live Photo模式调用新的captureLivePhoto方法
- 静态模式保持现有captureFrame方法
```

### 步骤4.2：更新截图管理器
```swift
// 修改：Winkkk/Managers/ScreenshotManager.swift
// 添加Live Photo支持：
- 区分处理不同类型截图
- Live Photo特殊的存储和清理逻辑
- 批量操作时的类型检查
```

### 步骤4.3：处理中心功能扩展
```swift
// 修改：Winkkk/Controllers/ScreenshotProcessingViewController.swift
// Live Photo专用处理选项：
- 播放Live Photo预览
- 设置封面帧
- 保存到系统相册（Live Photo格式）
- 分享Live Photo
```

---

## **阶段五：权限和保存功能** 📱

### 步骤5.1：权限管理
- 添加Photos框架权限请求
- Live Photo保存权限处理
- 优雅的权限拒绝降级方案

### 步骤5.2：系统集成
- PHLivePhoto保存到系统相册
- 分享功能支持Live Photo格式
- 壁纸设置功能集成

---

## **阶段六：测试和优化** 🧪

### 步骤6.1：功能测试
- Live Photo创建流程测试
- 不同视频格式兼容性测试
- 内存和性能优化测试

### 步骤6.2：用户体验优化
- 加载状态和进度指示
- 错误处理和用户提示
- 流畅的动画和交互效果

---

## 🎯 实施优先级建议

### **高优先级**（核心功能）：
1. **阶段二**：Live Photo引擎开发（最关键）
2. **阶段一**：数据模型扩展（基础支持）
3. **阶段四.1**：修改截图流程（用户可感知）

### **中优先级**（用户体验）：
4. **阶段三.1**：预览界面升级（播放功能）
5. **阶段四.2**：截图管理器更新（稳定性）

### **低优先级**（完善功能）：
6. **阶段三.2-3**：界面细节优化
7. **阶段五**：高级功能（保存、分享）
8. **阶段六**：测试和优化

## 📊 预估工作量

- **核心功能开发**：3-4天（阶段一+二+四.1）
- **界面升级**：2-3天（阶段三+四.2-3）  
- **完善和测试**：2-3天（阶段五+六）
- **总计**：7-10天

---

## 🔧 技术实现要点

### Live Photo文件结构
```
Live Photo文件结构：
├── 静态图片 (HEIC格式)    # 封面帧，用于静态显示
├── 短视频 (MOV格式)      # 3秒动态片段，包含音频
└── 元数据配对信息        # UUID + EXIF/QuickTime元数据
```

### 核心技术栈
```swift
import Photos          // PHLivePhoto处理和保存
import PhotosUI        // 实况照片UI组件
import AVFoundation    // 视频片段提取和处理
import CoreImage       // 图像处理和质量优化
import UIKit           // 用户界面和交互
```

### 文件结构扩展
```
Winkkk/
├── Managers/
│   ├── VideoSegmentExtractor.swift   # 视频片段提取器
│   ├── LivePhotoMaker.swift          # Live Photo组装器
│   └── ScreenshotEngine.swift        # 升级支持Live Photo
├── Models/
│   ├── ScreenshotItem.swift          # 扩展Live Photo字段
│   └── WinkkkDataModel.swift         # 更新Core Data模型
├── Views/
│   ├── ScreenshotDetailSheet.swift   # 添加PHLivePhotoView支持
│   └── ScreenshotThumbnailView.swift # Live Photo标识
└── Controllers/
    ├── VideoPlayerViewController.swift      # Live Photo截图流程
    └── ScreenshotProcessingViewController.swift # Live Photo处理选项
```

---

## 📝 实施注意事项

1. **数据迁移**：Core Data模型变更需要谨慎处理，确保现有数据不丢失
2. **内存管理**：Live Photo处理涉及大量内存操作，需要优化内存使用
3. **异步处理**：视频处理和Live Photo创建都是耗时操作，需要合理的异步处理
4. **错误处理**：各个环节都需要完善的错误处理和用户提示
5. **权限处理**：Photos框架权限需要在合适时机请求，提供清晰的说明

---

*文档创建时间：2024年12月20日*
*预计实施时间：7-10个工作日*
