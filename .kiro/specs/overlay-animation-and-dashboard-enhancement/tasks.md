# Implementation Plan: Overlay Animation and Dashboard Enhancement

## Overview

本实现计划将 GhosTYPE 的跑道圆动画系统和 Dashboard 功能分为三个主要模块：
1. **跑道圆动画系统** - 在现有 OverlayView 基础上增量添加：状态机、光晕环、Badge、上屏动画
2. **Dashboard 随心记页面** - Flomo 风格瀑布流卡片
3. **Dashboard 偏好设置增强** - 新增设置项

技术栈：SwiftUI, macOS 13+, Core Animation

## ⚠️ 重要原则

**保持现有 OverlayView 结构不变！** 所有动画效果都是在现有基础上增量添加，不要：
- 修改现有的 Capsule 形状
- 修改现有的布局结构（HStack、padding、frame）
- 修改现有的 GhostIconView 和 textArea
- 修改现有的颜色和阴影

现有结构（必须保持）：
```swift
// OverlayView.swift - 不要修改这些核心结构
HStack(spacing: spacing) {
    GhostIconView(isRecording: speechService.isRecording)  // 保持
    textArea                                                // 保持
}
.padding(...)
.frame(width: capsuleWidth)
.background(
    Capsule()
        .fill(Color(white: 0.10))
        .shadow(...)
)
```

## Tasks

- [x] 1. 跑道圆动画状态和颜色
  - [x] 1.1 添加动画状态枚举到 OverlayView
    - 直接在 `AIInputMethod/Sources/UI/OverlayView.swift` 中添加
    - 添加 OverlayPhase 枚举（recording, processing, result, committing）
    - 添加 @State var phase: OverlayPhase? 属性
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.6, 1.7_

  - [x] 1.2 添加模式颜色常量
    - 在 OverlayView.swift 中添加 ModeColors 枚举
    - 定义模式颜色：蓝色(默认)、绿色(润色)、紫色(翻译)、橙色(随心记)
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 2. 光晕环效果
  - [x] 2.1 创建 GlowRingView 组件
    - 在 OverlayView.swift 中添加 GlowRingView struct
    - 实现围绕 Capsule 旋转的光晕效果
    - 支持颜色参数和旋转控制
    - _Requirements: 2.3, 2.5, 3.3, 7.5_

  - [x] 2.2 集成光晕环到现有 OverlayView
    - 在现有 .background(Capsule()...) 外层包裹 ZStack
    - 添加 GlowRingView 作为底层
    - 根据 InputMode 设置光晕颜色
    - _Requirements: 2.5, 4.4_

- [x] 3. 结果 Badge 组件
  - [x] 3.1 创建 ResultBadgeView 组件
    - 在 OverlayView.swift 中添加 ResultBadgeView struct
    - 显示"已润色"/"已翻译"/"已保存"文字
    - 根据模式设置颜色
    - 实现淡入动画
    - _Requirements: 4.5, 4.6, 4.7, 4.8_

  - [x] 3.2 集成 Badge 到现有 OverlayView
    - 在 HStack 末尾添加 Badge（条件显示）
    - 只在 result 状态时显示
    - _Requirements: 4.2, 4.5_

- [x] 4. Checkpoint - 基础动画组件完成
  - 确保光晕环和 Badge 正常显示
  - 验证颜色根据模式正确切换
  - 确保现有跑道圆样式未被修改

- [x] 5. 上屏和保存动画
  - [x] 5.1 实现向上漂移动画
    - 添加 @State var commitOffset 和 commitOpacity
    - 在 committing 状态时触发向上移动 + 淡出
    - 400ms easeOut 动画
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 5.2 实现随心记"已保存"提示
    - 🔥 **立即要做的功能**
    - 在 memo 模式保存完成后显示"已保存" Badge
    - Badge 显示 1 秒后淡出
    - 只有随心记模式有此提示
    - _Requirements: 6.1, 6.7_

  - [x] 5.3 实现随心记飞向菜单栏动画（可选）
    - 在 committing(.memoSaved) 状态时触发
    - 整个跑道圆缩小并飞向菜单栏位置
    - 500ms easeInOut 动画
    - _Requirements: 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 6. AI 处理中动画
  - [x] 6.1 实现 processing 状态视觉效果
    - 在 AI 润色/翻译处理时显示
    - 光晕环加速旋转
    - 可选：跑道圆轻微脉冲动画
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 7. Checkpoint - 跑道圆动画系统完成
  - 测试完整的录音 → 处理 → 结果 → 上屏流程
  - 测试随心记"已保存"提示
  - 确保所有测试通过，如有问题请询问用户

- [x] 8. Dashboard 导航更新
  - [x] 8.1 更新 NavItem 枚举
    - 修改 `AIInputMethod/Sources/Features/Dashboard/NavItem.swift`
    - 添加 .memo case（随心记）
    - 更新图标和标题
    - _Requirements: 12.1_

  - [x] 8.2 更新 DashboardView 路由
    - 修改 `AIInputMethod/Sources/UI/Dashboard/DashboardView.swift`
    - 添加 MemoPage 路由
    - _Requirements: 12.1_

- [x] 9. 随心记页面 (MemoPage)
  - [x] 9.1 创建 MemoPage 主视图
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/MemoPage.swift`
    - 实现页面头部（标题、笔记数量、搜索框）
    - 实现瀑布流 LazyVGrid 布局（3列）
    - _Requirements: 12.2, 12.8_

  - [x] 9.2 创建 MemoCard 便签卡片组件
    - 实现 Flomo 风格卡片
    - 多种暖色背景（浅黄、淡橙、浅粉等）
    - 圆角 + 阴影效果
    - 显示内容、时间戳
    - _Requirements: 12.3, 12.4, 12.5_

  - [x] 9.3 实现卡片点击展开功能
    - 点击卡片展开显示完整内容
    - 支持编辑功能
    - _Requirements: 12.6_

  - [x] 9.4 实现无限滚动加载
    - 滚动到底部时加载更多
    - _Requirements: 12.7_

- [x] 10. Checkpoint - 随心记页面完成
  - 测试瀑布流布局
  - 测试搜索和滚动加载
  - 确保所有测试通过，如有问题请询问用户

- [x] 11. Dashboard 概览页增强
  - [x] 11.1 完善今日战报卡片
    - 修改 `AIInputMethod/Sources/UI/Dashboard/Pages/OverviewPage.swift`
    - 确保字符数和节省时间计算正确
    - _Requirements: 9.1, 9.2, 9.3, 9.5_

  - [x] 11.2 完善能量环卡片
    - 确保百分比计算正确
    - 实现警告色（>80%黄色，>95%红色）
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 11.3 完善应用分布饼图
    - 实现 Top 5 + "其他" 分组逻辑
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 12. Dashboard 偏好设置增强
  - [x] 12.1 添加开机自启动设置
    - 修改 `AIInputMethod/Sources/UI/Dashboard/Pages/PreferencesPage.swift`
    - 使用 SMAppService 实现 Login Items 注册
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [x] 12.2 添加主触发键自定义
    - 复用现有的快捷键录制逻辑
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

  - [x] 12.3 添加模式修饰键设置
    - 创建 ModifierKeyPicker 组件
    - 添加翻译模式修饰键选择
    - 添加随心记模式修饰键选择
    - 实现冲突检测（不允许相同修饰键）
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_

  - [x] 12.4 添加 AI 润色设置
    - 添加 AI 润色开关
    - 添加自动润色阈值设置（Stepper，默认 20 字符）
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6_

  - [x] 12.5 添加自定义 Prompt 编辑器
    - 创建 PromptEditorView 组件
    - 实现可展开的多行文本编辑器
    - 添加"恢复默认"按钮
    - 实现非空验证
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6_

- [x] 13. AppSettings 扩展
  - [x] 13.1 添加新设置项到 AppSettings
    - 修改 `AIInputMethod/Sources/Features/Settings/AppSettings.swift`
    - 添加 polishThreshold 属性（默认 20）
    - 添加 enableAIPolish 属性
    - 添加 polishPrompt 属性
    - 确保所有新设置项持久化到 UserDefaults
    - _Requirements: 17.6, 13.4, 16.4_

- [x] 14. Final Checkpoint - 全部功能完成
  - 运行所有单元测试
  - 测试完整的用户流程
  - 确保所有测试通过，如有问题请询问用户

## Notes

- **🔥 优先级最高**: Task 5.2 随心记"已保存"提示
- 所有动画组件直接添加到现有 OverlayView.swift 中，不创建新文件夹
- 保持现有跑道圆的 Capsule 形状、颜色、阴影不变
- 光晕环是在现有背景外层添加的效果层
- Badge 是在现有 HStack 内部添加的条件显示元素
