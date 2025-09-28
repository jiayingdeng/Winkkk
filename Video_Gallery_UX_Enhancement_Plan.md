# 📋 视频图库UX增强实施计划

## 🎯 项目概述

为视频图库添加状态标签、筛选功能和用户引导，提升用户体验和视频管理效率。

## 🎨 设计方案

### 视频状态标签系统
- **位置**: 视频缩略图右上角
- **样式**: 半透明深色背景，白色图标文字，圆角矩形
- **状态类型**:
  - 📱✅ = App录制已导出
  - 📱⏳ = App录制待导出  
  - 📥 = 系统导入

### 筛选功能
- **位置**: 图库顶部
- **按钮**: [全部] [📱录制] [✅已导出] [📥导入]
- **交互**: 水平滚动，实时筛选，显示结果数量

### 长按详情功能
- **触发**: 长按视频缩略图
- **内容**: 来源、日期、时长、分辨率、文件大小、导出状态
- **操作**: [导出] [删除] 按钮

### 用户引导策略
- **首次引导**: 轻量级气泡提示 "💡 长按可查看详细信息"
- **微交互**: 轻触时短暂显示长按提示（补充引导）

## 🔧 技术实施计划

### Phase 1: 数据模型更新
**文件**: `Models/VideoItem.swift`, `Models/WinkkkDataModel.swift`

**任务**:
- [ ] 添加视频来源字段 (videoSource: app/imported)
- [ ] 添加导出状态字段 (exportStatus: exported/pending)
- [ ] 更新Core Data模型
- [ ] 添加数据迁移逻辑

### Phase 2: 视频状态标签
**文件**: `Views/VideoThumbnailCell.swift`, `Controllers/VideoGalleryViewController.swift`

**任务**:
- [ ] 在缩略图cell添加状态标签视图
- [ ] 实现标签样式和布局
- [ ] 根据数据设置标签内容
- [ ] 优化性能和缓存

### Phase 3: 长按详情功能
**文件**: `Controllers/VideoGalleryViewController.swift`, 新建详情弹窗

**任务**:
- [ ] 添加长按手势识别
- [ ] 创建详情弹窗视图
- [ ] 实现详情信息展示
- [ ] 添加导出/删除操作

### Phase 4: 筛选功能
**文件**: `Controllers/VideoGalleryViewController.swift`

**任务**:
- [ ] 创建筛选按钮栏UI
- [ ] 实现筛选逻辑
- [ ] 添加筛选状态管理
- [ ] 显示筛选结果数量

### Phase 5: 用户引导系统
**文件**: `Controllers/VideoGalleryViewController.swift`

**任务**:
- [ ] 实现首次使用检测
- [ ] 创建引导气泡视图
- [ ] 添加微交互提示
- [ ] 使用UserDefaults记录状态

### Phase 6: 集成和优化
**任务**:
- [ ] 更新录制流程标记视频来源
- [ ] 更新导出流程标记导出状态
- [ ] 性能优化和测试
- [ ] 无障碍支持适配

## 📁 涉及文件清单

### 主要修改文件
- `Winkkk/Controllers/VideoGalleryViewController.swift` - 主要逻辑实现
- `Winkkk/Views/VideoThumbnailCell.swift` - 缩略图单元格
- `Winkkk/Models/VideoItem.swift` - 数据模型扩展
- `Winkkk/Models/WinkkkDataModel.swift` - Core Data模型

### 可能新建文件
- `Winkkk/Views/VideoDetailPopupView.swift` - 详情弹窗视图
- `Winkkk/Views/VideoFilterBar.swift` - 筛选按钮栏组件

### 相关更新文件
- `Winkkk/Managers/VideoManager.swift` - 状态管理
- `Winkkk/Controllers/MainCameraViewController.swift` - 录制来源标记

## ⚙️ 技术要点

### 性能优化
- 标签信息缓存避免重复计算
- 筛选结果缓存提升响应速度
- 异步加载详情信息

### 用户体验
- 动画过渡流畅自然
- 触觉反馈增强交互
- 无障碍VoiceOver支持

### 数据一致性
- 录制时实时标记来源
- 导出时实时更新状态
- 数据库迁移平滑升级

## 📊 验收标准

### 功能验收
- [ ] 所有视频正确显示状态标签
- [ ] 筛选功能正常工作
- [ ] 长按详情信息完整准确
- [ ] 首次引导正常显示和消失
- [ ] 导出状态实时更新

### 性能验收
- [ ] 图库滚动流畅无卡顿
- [ ] 筛选响应时间 < 200ms
- [ ] 内存使用合理无泄漏

### 兼容性验收
- [ ] 支持iOS 13.0+
- [ ] 适配不同屏幕尺寸
- [ ] VoiceOver无障碍支持
- [ ] 深色模式适配

## 🔄 实施时间线

**预计总时间**: 2-3天

- **Day 1**: Phase 1-2 (数据模型 + 状态标签)
- **Day 2**: Phase 3-4 (详情弹窗 + 筛选功能) 
- **Day 3**: Phase 5-6 (用户引导 + 集成优化)

## 📝 备注

- 优先保证编译成功和基本功能
- 渐进式实施，每个阶段独立可测试
- 保持代码质量和注释完整性
- 及时更新TODO状态和进度跟踪

---
*文档创建时间: 2025年9月28日*
*最后更新: 待实施*




