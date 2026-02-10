# Implementation Plan: Ghost Twin 孵化室

## Overview

按增量方式实现孵化室功能：先搭建导航和数据模型，再实现 Canvas 渲染和 CRT 效果，然后接入 API 和校准系统，最后完成本地化和 API 文档输出。每个步骤都在前一步基础上构建，确保无孤立代码。

## Tasks

- [x] 1. 本地化字符串和导航项
  - [x] 1.1 添加 Incubator 本地化字符串
    - 在 `Strings.swift` 新增 `IncubatorStrings` protocol 和 `L.Incubator` / `L.Nav.incubator` 访问器
    - 在 `Strings+Chinese.swift` 新增 `ChineseIncubator` 实现
    - 在 `Strings+English.swift` 新增 `EnglishIncubator` 实现
    - 包含 title、level、syncRate、wordsProgress、levelUp、ghostStatus、incoming、noMoreSignals 以及闲置文案数组
    - _Requirements: 9.1, 9.2, 9.3, 10.4_

  - [x] 1.2 扩展 NavItem 枚举
    - 在 `NavItem.swift` 新增 `.incubator` case
    - 设置 icon = `flask.fill`，title = `L.Nav.incubator`，requiresAuth = true
    - 新增 `badge: String?` 计算属性，`.incubator` 返回 "LAB"，其余返回 nil
    - 调整 `groups` 为 `[[.account, .overview, .incubator], [.memo, .library], [.aiPolish, .preferences]]`
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 1.3 SidebarNavItem 添加徽章支持
    - 在 `SidebarView.swift` 的 `SidebarNavItem` 中，Spacer 后添加 badge 视图
    - 使用 `DS.Typography.mono(8, weight: .medium)`，`DS.Colors.text2` 文字色，`DS.Colors.highlight` 背景色，圆角 2px
    - _Requirements: 1.4, 1.5_

  - [x] 1.4 DashboardView 路由 IncubatorPage
    - 在 `DashboardView.swift` 的 `normalContentView` switch 中添加 `.incubator` case → `IncubatorPage()`
    - 创建空的 `IncubatorPage.swift` 占位（显示 "Incubator" 文字即可）
    - _Requirements: 1.6_

  - [x] 1.5 NavItem 单元测试
    - 验证 `.incubator` 的 icon、title、requiresAuth、badge 值
    - 验证 NavItem.groups 中 `.incubator` 位于第一组第三位
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Checkpoint - 确保编译通过
  - 确保所有修改编译通过，侧边栏显示孵化室入口和 LAB 徽章，点击可导航到占位页面。如有问题请告知。

- [x] 3. GhostMatrixModel 数据模型
  - [x] 3.1 实现 GhostMatrixModel
    - 创建 `AIInputMethod/Sources/Features/Dashboard/GhostMatrixModel.swift`
    - 实现 160×120 ghostMask（Bool 数组，从 PNG 位图加载）
    - 实现 Fisher-Yates shuffle 生成 activationOrder
    - 实现 `getActivePixels(wordCount:) -> Set<Int>`
    - 实现 activationOrder 的 UserDefaults 持久化（save/load）
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 3.2 Property test: Fisher-Yates shuffle 有效排列
    - **Property 1: Fisher-Yates shuffle produces valid permutation**
    - **Validates: Requirements 5.2**

  - [x] 3.3 Property test: getActivePixels 正确性
    - **Property 2: getActivePixels returns correct count with valid indices**
    - **Validates: Requirements 5.3**

  - [x] 3.4 Property test: activationOrder 持久化 round-trip
    - **Property 3: activationOrder round-trip persistence**
    - **Validates: Requirements 5.4**

- [x] 4. Ghost Twin API 数据模型和端点
  - [x] 4.1 定义 Ghost Twin 数据模型
    - 在 `GhostypeModels.swift` 新增 `GhostTwinStatusResponse`、`CalibrationChallenge`、`CalibrationAnswerResponse`
    - 包含 `ChallengeType` 枚举（dilemma/reverseTuring/prediction）
    - _Requirements: 7.1, 8.2, 8.3, 8.5_

  - [x] 4.2 扩展 GhostypeAPIClient
    - 在 `GhostypeAPIClient.swift` 新增 3 个方法：`fetchGhostTwinStatus()`、`fetchCalibrationChallenge()`、`submitCalibrationAnswer(challengeId:selectedOption:)`
    - 复用现有 `buildRequest` 和 `performRequest` 基础设施
    - _Requirements: 7.1, 8.2, 8.4_

  - [x] 4.3 Property test: API 模型序列化 round-trip
    - **Property 6: API model serialization round-trip**
    - **Validates: Requirements 7.1, 8.2, 8.5**

- [x] 5. IncubatorViewModel
  - [x] 5.1 实现 IncubatorViewModel
    - 创建 `AIInputMethod/Sources/Features/Dashboard/IncubatorViewModel.swift`
    - @Observable 类，管理 level、totalXP、currentLevelXP、personalityTags、challengesRemaining 等状态
    - 实现 `fetchStatus()` 调用 API + 缓存回退逻辑
    - 实现 `fetchChallenge()` 和 `submitAnswer()` 方法
    - 实现 ghostOpacity 计算（level * 0.1）
    - 实现动效阶段选择（AnimationPhase enum: glitch/breathing/awakening/complete）
    - 实现闲置文案循环（Timer + 等级分组选择 + 打字机效果状态）
    - 实现 UserDefaults 缓存读写
    - _Requirements: 6.3, 6.4, 7.1, 7.3, 7.5, 8.4, 10.1, 10.2, 10.3_

  - [x] 5.2 Property test: ghostOpacity 线性映射
    - **Property 4: ghostOpacity linear mapping**
    - **Validates: Requirements 3.5, 6.3**

  - [x] 5.3 Property test: 动效阶段选择
    - **Property 5: Animation phase selection by level range**
    - **Validates: Requirements 6.4**

  - [x] 5.4 Property test: 缓存回退
    - **Property 7: Cache fallback on API failure**
    - **Validates: Requirements 7.5**

  - [x] 5.5 Property test: 闲置文案分组
    - **Property 8: Idle text level group selection**
    - **Validates: Requirements 10.2**

- [x] 6. Checkpoint - 确保数据层和 ViewModel 测试通过
  - 确保所有属性测试和单元测试通过，如有问题请告知。

- [x] 7. 点阵屏 Canvas 渲染
  - [x] 7.1 实现 DotMatrixView
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/Incubator/DotMatrixView.swift`
    - 双层 Canvas 渲染：底层 blur + screen blend 做光晕，上层锐利像素
    - 4×4px 像素点，0.5px 间隙，0.75px 圆角
    - 三种像素状态：未激活（灰色 0.04）、已激活背景（绿色 0.25）、Ghost Logo（绿色 × ghostOpacity）
    - 使用 `.drawingGroup()` 优化性能
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 7.2 实现 CRTEffectsView
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/Incubator/CRTEffectsView.swift`
    - Canvas 扫描线（每 3px 一条，opacity 0.15）
    - RadialGradient 暗角效果
    - `.allowsHitTesting(false)`
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 8. 孵化室页面布局
  - [x] 8.1 实现 IncubatorPage 完整布局
    - 替换占位页面，实现完整的 IncubatorPage
    - 页面背景 DS.Colors.bg1，中央 CRT_Container（黑色背景，640×480 内部区域）
    - CRT_Container 带 DS.Colors.border 边框和 DS.Layout.cornerRadius 圆角
    - 叠加 DotMatrixView + CRTEffectsView
    - 接入 IncubatorViewModel
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 8.2 实现 LevelInfoBar
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/Incubator/LevelInfoBar.swift`
    - CRT_Container 上方显示等级（"Lv.3"）和进度条（当前字数 / 10,000）
    - _Requirements: 2.5_

  - [x] 8.3 实现 GhostStatusText
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/Incubator/GhostStatusText.swift`
    - CRT_Container 下方显示闲置文案，等宽字体，打字机逐字显示效果
    - 每 8~15 秒随机切换
    - _Requirements: 2.6, 10.1, 10.2, 10.3_

- [x] 9. 升级仪式动效
  - [x] 9.1 实现升级动效
    - 在 IncubatorViewModel 中添加升级检测逻辑
    - 实现升级仪式：全屏像素闪烁 → 背景像素熄灭 → Ghost 亮度提升
    - 升级后重置背景像素，保持 Ghost Logo 基础亮度
    - 实现等级动效演进（glitch → breathing → awakening → complete）
    - _Requirements: 6.1, 6.2, 6.4, 6.5_

- [x] 10. 校准系统 UI（热敏纸条）
  - [x] 10.1 实现 ReceiptSlipView
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/Incubator/ReceiptSlipView.swift`
    - 米白色背景，等宽字体，场景描述 + 2~3 个选项按钮
    - 从 CRT 上方滑入/滑出动画（`.transition(.move(edge: .top))`）
    - _Requirements: 8a.2, 8a.3, 8a.4_

  - [x] 10.2 集成校准交互流程
    - 在 IncubatorPage 中添加 ">> INCOMING..." 闪烁提示（challengesRemaining > 0 时显示）
    - 点击提示 → 调用 challenge API → 显示 ReceiptSlipView
    - 选择选项 → 提交答案 → 收回纸条 → 显示 ghost_response → 更新 XP
    - challengesRemaining == 0 时显示 ">> NO MORE SIGNALS TODAY"
    - _Requirements: 8a.1, 8a.5, 8a.6, 8.6_

- [x] 11. Checkpoint - 完整 UI 功能验证
  - 确保所有测试通过，孵化室页面完整可用。如有问题请告知。

- [x] 12. LLM 调用后刷新 Ghost Twin 状态
  - [x] 12.1 在 LLM 调用成功后触发 status 刷新
    - 在现有 LLM 调用成功回调中，添加 Ghost Twin status 刷新逻辑
    - 确保 IncubatorViewModel 在 Dashboard 生命周期内可被通知刷新
    - _Requirements: 7.6_

- [x] 13. 输出 API 需求文档
  - [x] 13.1 生成 GHOST_TWIN_API_SPEC.md
    - 在项目根目录创建 `GHOST_TWIN_API_SPEC.md`
    - 包含 3 个端点定义（status、challenge、answer）及 JSON Schema
    - 包含 3 类 Prompt 初稿（校准挑战生成、人格档案增量更新、阶段性总结）
    - 包含数据模型定义（GhostTwinProfile、CalibrationChallenge、CalibrationAnswer）
    - 明确标注所有 Prompt 和完整档案仅存在于服务端
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

- [x] 14. Final checkpoint - 全部完成
  - 确保所有测试通过，所有文件已创建。如有问题请告知。

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Ghost Logo 的 160×120 黑白 PNG 位图需要单独制作，放入 `Sources/Resources/ghost_logo_160x120.png`
- 服务端 API 在客户端开发期间不可用，使用 Mock 数据开发和测试
- Property tests 使用手动随机生成器 + 循环 100 次迭代的方式实现
