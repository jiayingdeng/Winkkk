# AI增强时光序列合成技术方案

## 📋 项目概述

### 目标
在时光序列处理中集成AI人物分割技术，实现更专业的多帧合成效果。

### 核心需求
1. ✅ 使用 DeepLabV3 提取每一帧的人物主体
2. ✅ 使用**最后一张图片作为完整背景**
3. ✅ 将提取的人物按照**原透明度公式**叠加到背景上
4. ✅ 对用户透明（不暴露具体使用的AI模型）
5. ✅ 准备可扩展架构，便于后续对比不同分割工具

---

## 🏗️ 技术架构设计

### 整体流程

```
视频输入
    ↓
提取关键帧 (3-10帧)
    ↓
场景类型判断
    ↓
┌─────────────────────────────────────────┐
│  运动轨迹场景 (sportMotion)              │
│  → AI增强轨迹叠加合成                    │
└─────────────────────────────────────────┘
    ↓
步骤1: 选择最后一帧作为背景
    ↓
步骤2: 批量AI分割所有帧的人物
    ↓
步骤3: 按原透明度公式叠加人物到背景
    ↓
步骤4: 生成最终合成图
```

---

## 💡 详细实现方案

### 方案1：可扩展的策略模式架构 ⭐

#### 1.1 分割策略枚举

```swift
/// 🎯 主体提取策略（内部使用，对用户透明）
private enum SubjectExtractionStrategy {
    case deepLabV3      // DeepLabV3 分割
    case subjectEngine  // SubjectExtractionEngine
    case mobileSAM      // MobileSAM 交互式分割
    case centerCrop     // 中心裁剪（降级方案）
    
    var displayName: String {
        switch self {
        case .deepLabV3: return "DeepLabV3"
        case .subjectEngine: return "SubjectEngine"
        case .mobileSAM: return "MobileSAM"
        case .centerCrop: return "中心裁剪"
        }
    }
}

// 当前使用的策略（可配置，便于对比测试）
private var currentExtractionStrategy: SubjectExtractionStrategy = .deepLabV3
```

#### 1.2 统一分割接口

```swift
/// 🔍 使用AI提取主体（统一接口）
private func extractSubjectUsingAI(
    from frame: UIImage,
    strategy: SubjectExtractionStrategy,
    completion: @escaping (UIImage?) -> Void
) {
    switch strategy {
    case .deepLabV3:
        extractUsingDeepLabV3(frame: frame, completion: completion)
        
    case .subjectEngine:
        extractUsingSubjectEngine(frame: frame, completion: completion)
        
    case .mobileSAM:
        extractUsingMobileSAM(frame: frame, completion: completion)
        
    case .centerCrop:
        // 降级方案：直接使用中心裁剪
        let result = extractCenterRegion(from: frame, percentage: 0.4)
        completion(result ?? frame)
    }
}
```

#### 1.3 DeepLabV3 分割实现

```swift
/// 🤖 使用 DeepLabV3 提取人物
private func extractUsingDeepLabV3(
    frame: UIImage,
    completion: @escaping (UIImage?) -> Void
) {
    DeepLabV3Manager.shared.segmentSubjects(from: frame) { result in
        switch result {
        case .success(let segmentationResult):
            // ✅ 成功：使用提取的主体（已移除背景）
            print("✅ DeepLabV3 分割成功，置信度: \(segmentationResult.confidence)%")
            completion(segmentationResult.extractedSubject)
            
        case .failure(let error):
            // ⚠️ 失败：降级使用原图
            print("⚠️ DeepLabV3 分割失败: \(error)，使用原图")
            completion(frame)
        }
    }
}
```

#### 1.4 AI增强叠加合成方法（核心）

```swift
/// 🌟 AI增强的轨迹叠加合成（人物分割版）
private func generateAIEnhancedTrajectoryComposite(
    from frames: [UIImage],
    sceneType: SceneType
) {
    guard !frames.isEmpty else { return }
    guard let lastFrame = frames.last else { return }
    
    print("🎯 开始AI增强合成，帧数: \(frames.count)")
    
    let startTime = Date()
    
    // 步骤1：使用最后一帧作为完整背景
    let backgroundImage = lastFrame
    let canvasSize = backgroundImage.size
    
    // 步骤2：批量提取所有帧的人物（使用DispatchGroup处理异步）
    let dispatchGroup = DispatchGroup()
    var extractedSubjects: [Int: UIImage] = [:]
    var successCount = 0
    var failureCount = 0
    
    for (index, frame) in frames.enumerated() {
        dispatchGroup.enter()
        
        extractSubjectUsingAI(from: frame, strategy: currentExtractionStrategy) { extractedSubject in
            if let subject = extractedSubject {
                extractedSubjects[index] = subject
                successCount += 1
            } else {
                extractedSubjects[index] = frame
                failureCount += 1
            }
            dispatchGroup.leave()
        }
    }
    
    // 步骤3：等待所有分割完成，然后开始合成
    dispatchGroup.notify(queue: .main) { [weak self] in
        guard let self = self else { return }
        
        // 创建画布并绘制背景
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0.0)
        backgroundImage.draw(in: CGRect(origin: .zero, size: canvasSize))
        
        // 步骤4：按照原透明度公式叠加每个提取的人物
        for (drawIndex, _) in frames.enumerated().reversed() {
            guard let extractedSubject = extractedSubjects[drawIndex] else { continue }
            
            let transparencyIndex = drawIndex
            let alpha = self.calculateAlphaForScene(
                index: transparencyIndex,
                totalFrames: frames.count,
                sceneType: sceneType
            )
            
            extractedSubject.draw(
                in: CGRect(origin: .zero, size: canvasSize),
                blendMode: .normal,
                alpha: alpha
            )
        }
        
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let processingTime = Date().timeIntervalSince(startTime)
        print("⏱️ AI增强合成完成！总耗时: \(String(format: "%.2f", processingTime))秒")
        
        self.resultImageView.image = compositeImage
        self.resultContainerView.isHidden = false
    }
}
```

---

## 📁 文件修改清单

### 需要修改的文件

1. **TimeSequenceViewController.swift**
   - 添加策略枚举
   - 添加统一分割接口
   - 实现 DeepLabV3 分割方法
   - 创建 AI 增强合成方法
   - 修改场景合成调用逻辑

2. **确保依赖初始化**
   - 确保 `DeepLabV3Manager` 已初始化

---

## 🎯 关键技术点

### 1. 异步处理方案：DispatchGroup

```swift
let dispatchGroup = DispatchGroup()

for frame in frames {
    dispatchGroup.enter()
    extractSubjectUsingAI(frame) { result in
        // 处理结果
        dispatchGroup.leave()
    }
}

dispatchGroup.notify(queue: .main) {
    // 所有分割完成，开始合成
}
```

### 2. 透明度计算（保持原逻辑）

```swift
let alpha = calculateAlphaForScene(
    index: transparencyIndex,
    totalFrames: frames.count,
    sceneType: sceneType
)
```

### 3. 背景选择（使用最后一帧）

```swift
let backgroundImage = frames.last  // 最后一帧作为完整背景
```

### 4. 降级策略

- AI分割失败 → 使用原图
- 所有AI分割都失败 → 仍能生成合成图（使用原图叠加）

---

## ✅ 实施步骤（TODO List）

### Phase 1: 准备工作
- [ ] 创建技术方案文档
- [ ] 保存 Git 快照

### Phase 2: 添加基础架构
- [ ] 添加 `SubjectExtractionStrategy` 枚举
- [ ] 添加 `currentExtractionStrategy` 属性
- [ ] 确保 DeepLabV3Manager 初始化

### Phase 3: 实现分割接口
- [ ] 实现 `extractSubjectUsingAI` 统一接口
- [ ] 实现 `extractUsingDeepLabV3` 方法
- [ ] 添加占位方法（subjectEngine、mobileSAM）

### Phase 4: 创建AI增强合成方法
- [ ] 实现 `generateAIEnhancedTrajectoryComposite` 方法
- [ ] 处理异步分割逻辑（DispatchGroup）
- [ ] 实现背景绘制和人物叠加

### Phase 5: 集成到现有流程
- [ ] 修改 `generateCompositeImage` 方法
- [ ] 为 sportMotion 场景启用 AI 增强合成
- [ ] 保留旧方法作为备用

### Phase 6: 测试与验证
- [ ] 编译验证
- [ ] 运行时测试
- [ ] 性能验证

---

## 🎉 预期效果

### 用户体验
- ✅ 处理过程对用户透明，无需了解技术细节
- ✅ 自动提取人物主体，背景干净
- ✅ 保持原有透明度渐变效果
- ✅ 失败时自动降级，确保总能生成结果

### 技术优势
- ✅ 可扩展架构，便于切换不同AI模型
- ✅ 多级降级策略，鲁棒性强
- ✅ 保持原有逻辑，透明度计算不变
- ✅ 异步处理，不阻塞主线程

---

## 🔮 后续扩展

### 多方案对比准备

```swift
// 测试不同策略
currentExtractionStrategy = .deepLabV3      // 测试 DeepLabV3
currentExtractionStrategy = .subjectEngine  // 测试 SubjectEngine
currentExtractionStrategy = .mobileSAM      // 测试 MobileSAM

// 对比结果
performanceMetrics.forEach { $0.printReport() }
```

### 性能指标收集

```swift
struct SegmentationPerformanceMetrics {
    let strategy: SubjectExtractionStrategy
    let totalFrames: Int
    let successCount: Int
    let failureCount: Int
    let totalTime: TimeInterval
    let averageTimePerFrame: TimeInterval
    
    var successRate: Float {
        return Float(successCount) / Float(totalFrames)
    }
}
```

---

## 📝 注意事项

1. **对用户透明**：所有AI相关的技术细节对用户不可见
2. **降级策略**：确保任何情况下都能生成结果
3. **性能考虑**：使用 DispatchGroup 并发处理，提高效率
4. **保持兼容**：不影响其他场景类型的现有逻辑
5. **可扩展性**：架构设计便于后续添加新的分割工具

---

## 🚀 实施时间线

- **文档编写**: 10分钟 ✅
- **Git 快照**: 1分钟
- **代码实现**: 20-30分钟
- **测试验证**: 10分钟

**预计总时间**: 45分钟

---

*文档创建时间: 2025-10-09*
*最后更新: 2025-10-09*
