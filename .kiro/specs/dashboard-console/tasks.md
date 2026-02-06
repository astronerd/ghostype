# Implementation Plan: Dashboard Console

## Overview

实现 GhosTYPE Dashboard Console，采用增量开发方式：先搭建核心架构和状态机，然后逐步实现各功能模块。使用 SwiftUI + CoreData，遵循现有代码风格。

## Tasks

- [ ] 1. 核心架构与状态机
  - [x] 1.1 创建 DashboardState 状态机
    - 创建 `AIInputMethod/Sources/Features/Dashboard/DashboardState.swift`
    - 实现 DashboardPhase 枚举 (onboarding/normal)
    - 实现 OnboardingStep 枚举 (hotkey/inputMode/permissions)
    - 实现状态转换方法 completeOnboarding(), advanceOnboardingStep()
    - 实现 UserDefaults 持久化
    - _Requirements: 1.1, 1.3, 1.4, 1.5_

  - [ ]* 1.2 编写 DashboardState 属性测试
    - **Property 1: State Machine Integrity**
    - **Property 3: State Persistence Round-Trip**
    - **Validates: Requirements 1.1, 1.3, 1.4, 1.5**

  - [x] 1.3 创建 NavItem 导航枚举
    - 创建 `AIInputMethod/Sources/Features/Dashboard/NavItem.swift`
    - 实现 overview/library/preferences 三个 case
    - 实现 icon 属性返回 SF Symbol 名称
    - 实现 title 属性返回中文标签
    - _Requirements: 4.1, 4.4_

  - [ ]* 1.4 编写 NavItem 属性测试
    - **Property 5: NavItem Icon Completeness**
    - **Validates: Requirements 4.4, 11.2**

- [x] 2. Checkpoint - 确保状态机测试通过
  - 运行测试，确认状态机逻辑正确
  - 如有问题请询问用户

- [ ] 3. 数据层实现
  - [x] 3.1 创建 CoreData 模型
    - 创建 `AIInputMethod/Sources/Features/Dashboard/DashboardModel.xcdatamodeld`
    - 定义 UsageRecord 实体 (id, content, category, sourceApp, sourceAppBundleId, timestamp, duration, deviceId)
    - 定义 QuotaRecord 实体 (deviceId, usedSeconds, resetDate, lastUpdated)
    - _Requirements: 10.1, 10.2, 9.2_

  - [x] 3.2 创建 DeviceIdManager
    - 创建 `AIInputMethod/Sources/Features/Dashboard/DeviceIdManager.swift`
    - 实现 UUID 生成
    - 实现 Keychain 存储/读取
    - 实现 truncatedId(length:) 方法
    - _Requirements: 8.1, 8.2, 8.4, 8.5_

  - [ ]* 3.3 编写 DeviceIdManager 属性测试
    - **Property 15: Device ID Format**
    - **Property 16: Device ID Keychain Round-Trip**
    - **Property 17: Device ID Stability**
    - **Property 18: Device ID Truncation**
    - **Validates: Requirements 8.1, 8.2, 8.4, 8.5**

  - [x] 3.4 创建 QuotaManager
    - 创建 `AIInputMethod/Sources/Features/Dashboard/QuotaManager.swift`
    - 实现 usedSeconds 追踪
    - 实现 recordUsage(seconds:) 方法
    - 实现 usedPercentage 计算
    - _Requirements: 9.1, 9.3_

  - [ ]* 3.5 编写 QuotaManager 属性测试
    - **Property 7: Quota Percentage Calculation**
    - **Property 20: Quota Usage Accumulation**
    - **Validates: Requirements 9.1, 9.3**

  - [x] 3.6 创建 RecordCategory 枚举
    - 创建 `AIInputMethod/Sources/Features/Dashboard/RecordCategory.swift`
    - 实现 all/polish/translate/memo 四个 case
    - _Requirements: 6.2_

- [x] 4. Checkpoint - 确保数据层测试通过
  - 运行测试，确认数据层逻辑正确
  - 如有问题请询问用户

- [ ] 5. Dashboard 窗口与主布局
  - [x] 5.1 创建 DashboardWindowController
    - 创建 `AIInputMethod/Sources/Features/Dashboard/DashboardWindowController.swift`
    - 实现 NSWindow 创建 (900x600 最小尺寸)
    - 实现 show()/hide()/toggle() 方法
    - 实现窗口位置持久化 (saveWindowFrame/restoreWindowFrame)
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 3.6_

  - [ ]* 5.2 编写窗口位置持久化属性测试
    - **Property 21: Window Frame Persistence Round-Trip**
    - **Validates: Requirements 12.2**

  - [x] 5.3 创建 DashboardView 主视图
    - 创建 `AIInputMethod/Sources/UI/Dashboard/DashboardView.swift`
    - 实现 HStack 双栏布局 (Sidebar 220pt + Content)
    - 根据 DashboardState.phase 切换 Onboarding/Normal 内容
    - _Requirements: 3.1, 3.2, 3.5_

  - [ ]* 5.4 编写布局响应式属性测试
    - **Property 22: Responsive Layout Invariant**
    - **Validates: Requirements 3.2, 3.5**

  - [x] 5.5 创建 SidebarView
    - 创建 `AIInputMethod/Sources/UI/Dashboard/SidebarView.swift`
    - 使用 NSVisualEffectView 包装实现毛玻璃效果
    - 实现导航项列表 (NavItem)
    - 实现选中高亮效果
    - 实现底部 DeviceID + QuotaBar 区域
    - 实现 isEnabled 控制 (Onboarding 时禁用)
    - _Requirements: 3.3, 4.1, 4.2, 4.3, 4.5, 4.6, 2.5_

  - [ ]* 5.6 编写 Sidebar 导航属性测试
    - **Property 2: Onboarding State Disables Navigation**
    - **Property 4: Navigation Selection Updates Content**
    - **Validates: Requirements 2.5, 4.2, 4.6**

- [x] 6. Checkpoint - 确保主布局测试通过
  - 运行测试，确认布局逻辑正确
  - 如有问题请询问用户

- [ ] 7. Onboarding 流程集成
  - [x] 7.1 创建 OnboardingContentView
    - 创建 `AIInputMethod/Sources/UI/Dashboard/OnboardingContentView.swift`
    - 复用现有 OnboardingWindow 的步骤视图 (Step1HotkeyView, Step2AutoModeView, Step3PermissionsView)
    - 实现步骤指示器 (1/3, 2/3, 3/3)
    - 实现步骤切换动画
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6_

  - [x] 7.2 集成 Onboarding 到 DashboardView
    - 在 DashboardView 中根据 phase 显示 OnboardingContentView
    - 实现完成后的 fade-out 过渡动画
    - _Requirements: 2.4, 2.6_

- [ ] 8. 概览页 (OverviewPage)
  - [x] 8.1 创建 BentoCard 组件
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Components/BentoCard.swift`
    - 实现 16pt 圆角、阴影
    - 实现 hover 时 1.02x 缩放动画 (200ms)
    - _Requirements: 5.6, 5.7_

  - [x] 8.2 创建 EnergyRingView 组件
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Components/EnergyRingView.swift`
    - 实现圆环进度显示
    - 实现颜色根据百分比变化 (>90% 警告色)
    - _Requirements: 5.3_

  - [x] 8.3 创建 TodayStats 计算逻辑
    - 创建 `AIInputMethod/Sources/Features/Dashboard/StatsCalculator.swift`
    - 实现今日字数统计
    - 实现节省时间估算 (假设打字速度 2字/秒)
    - _Requirements: 5.2_

  - [ ]* 8.4 编写 TodayStats 属性测试
    - **Property 6: Today Stats Calculation**
    - **Validates: Requirements 5.2**

  - [x] 8.5 创建 AppDistribution 计算逻辑
    - 在 StatsCalculator 中实现应用分布统计
    - 计算各应用使用占比
    - _Requirements: 5.4_

  - [ ]* 8.6 编写 AppDistribution 属性测试
    - **Property 8: App Distribution Sum**
    - **Validates: Requirements 5.4**

  - [x] 8.7 创建 PieChartView 组件
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Components/PieChartView.swift`
    - 使用 Swift Charts 实现饼图
    - _Requirements: 5.4_

  - [x] 8.8 创建 RecentNotesQuery 逻辑
    - 在 StatsCalculator 中实现最近笔记查询
    - 返回最多 3 条 memo 类型记录，按时间倒序
    - _Requirements: 5.5_

  - [ ]* 8.9 编写 RecentNotesQuery 属性测试
    - **Property 9: Recent Notes Query**
    - **Validates: Requirements 5.5**

  - [x] 8.10 组装 OverviewPage
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/OverviewPage.swift`
    - 实现 Bento Grid 布局 (今日战报、能量环、应用分布、最近笔记)
    - _Requirements: 5.1_

- [x] 9. Checkpoint - 确保概览页测试通过
  - 运行测试，确认概览页逻辑正确
  - 如有问题请询问用户

- [ ] 10. 历史库页 (LibraryPage)
  - [x] 10.1 创建 LibraryViewModel
    - 创建 `AIInputMethod/Sources/Features/Dashboard/LibraryViewModel.swift`
    - 实现 searchText 绑定
    - 实现 selectedCategory 绑定
    - 实现过滤逻辑 (分类 + 搜索)
    - _Requirements: 6.3, 6.4_

  - [ ]* 10.2 编写过滤逻辑属性测试
    - **Property 10: Category Filter Correctness**
    - **Property 11: Search Filter Correctness**
    - **Validates: Requirements 6.3, 6.4**

  - [x] 10.3 创建 RecordListItem 组件
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Components/RecordListItem.swift`
    - 显示应用图标、内容预览 (2行截断)、时间戳
    - 实现内容预览截断逻辑
    - _Requirements: 6.5_

  - [ ]* 10.4 编写内容预览截断属性测试
    - **Property 12: Content Preview Truncation**
    - **Validates: Requirements 6.5**

  - [x] 10.5 实现拖拽导出功能
    - 在 RecordListItem 中实现 onDrag
    - 创建 .txt 文件并返回 NSItemProvider
    - _Requirements: 6.6_

  - [ ]* 10.6 编写导出文件属性测试
    - **Property 13: Export File Content**
    - **Validates: Requirements 6.6**

  - [x] 10.7 创建 RecordDetailPanel
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Components/RecordDetailPanel.swift`
    - 显示完整内容
    - _Requirements: 6.7_

  - [x] 10.8 组装 LibraryPage
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/LibraryPage.swift`
    - 实现搜索框 + 分类 Tabs + 列表 + 详情面板布局
    - _Requirements: 6.1, 6.2_

- [x] 11. Checkpoint - 确保历史库页测试通过
  - 运行测试，确认历史库页逻辑正确
  - 如有问题请询问用户

- [ ] 12. 偏好设置页 (PreferencesPage)
  - [x] 12.1 创建 PreferencesViewModel
    - 创建 `AIInputMethod/Sources/Features/Dashboard/PreferencesViewModel.swift`
    - 绑定 launchAtLogin, soundFeedback, hotkey 到 UserDefaults
    - 实现 AI 引擎状态检测
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ]* 12.2 编写设置持久化属性测试
    - **Property 14: Settings Persistence Round-Trip**
    - **Validates: Requirements 7.5**

  - [x] 12.3 组装 PreferencesPage
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/PreferencesPage.swift`
    - 实现分组设置界面 (通用、快捷键、AI 引擎)
    - 复用现有 HotkeyRecorderView 组件
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.6_

- [ ] 13. 集成与入口
  - [x] 13.1 集成 Dashboard 到 AppDelegate
    - 修改 `AIInputMethod/Sources/AIInputMethodApp.swift`
    - 添加 DashboardWindowController 实例
    - 修改菜单栏点击行为，打开 Dashboard
    - 移除独立的 OnboardingWindowController 调用
    - _Requirements: 12.1, 12.5_

  - [x] 13.2 实现权限提醒 Banner
    - 在 Normal_State 下检测权限状态
    - 如权限被撤销，显示提醒 Banner
    - _Requirements: 1.6_

  - [ ]* 13.3 编写 UsageRecord 设备关联属性测试
    - **Property 19: Usage Record Device Association**
    - **Validates: Requirements 8.3**

- [x] 14. Final Checkpoint - 确保所有测试通过
  - 运行完整测试套件
  - 确认所有功能正常工作
  - 如有问题请询问用户

## Notes

- 任务标记 `*` 为可选测试任务，可跳过以加快 MVP 开发
- 每个属性测试需运行至少 100 次迭代
- 复用现有 OnboardingWindow 中的步骤视图组件
- 遵循现有代码风格 (参考 OverlayView.swift, OnboardingWindow.swift)
