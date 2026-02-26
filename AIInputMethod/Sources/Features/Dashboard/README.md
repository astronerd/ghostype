# Dashboard 模块

## 概述

Dashboard 模块负责应用的主界面状态管理、数据持久化和业务逻辑。包含 ViewModel 层和数据访问层。

## 文件结构

```
Features/Dashboard/
├── README.md                       # 本文档
├── DashboardState.swift            # Dashboard 状态机
├── DashboardWindowController.swift # 窗口控制器
├── AIPolishViewModel.swift         # AI 润色页 ViewModel
├── PreferencesViewModel.swift      # 偏好设置页 ViewModel
├── LibraryViewModel.swift          # 记录库页 ViewModel
├── StatsCalculator.swift           # 统计计算器
├── PersistenceController.swift     # CoreData 持久化控制器
├── DeviceIdManager.swift           # 设备 ID 管理
├── QuotaManager.swift              # 配额管理
├── NavItem.swift                   # 导航项枚举
├── RecordCategory.swift            # 记录分类枚举
├── UsageRecord+CoreDataClass.swift # CoreData 实体类
├── UsageRecord+CoreDataProperties.swift
├── QuotaRecord+CoreDataClass.swift
├── QuotaRecord+CoreDataProperties.swift
└── DashboardModel.xcdatamodeld/    # CoreData 模型
```

## 文件说明

### DashboardState.swift
Dashboard 状态机，使用 `@Observable` 宏。

**状态**：
- `.onboarding(step)` - 初次启动，显示引导流程
- `.normal` - 正常使用状态

**Onboarding 步骤**：
1. `hotkey` - 快捷键配置
2. `inputMode` - 输入模式选择
3. `permissions` - 权限申请

**关键方法**：
- `completeOnboarding()` - 完成引导
- `advanceOnboardingStep()` - 前进到下一步
- `goBackOnboardingStep()` - 返回上一步

### DashboardWindowController.swift
Dashboard 窗口控制器，单例模式。

**职责**：
- 窗口创建、显示、隐藏
- 窗口位置持久化
- Dock 图标显示/隐藏控制

**关键方法**：
- `show()` - 显示窗口
- `hide()` - 隐藏窗口
- `toggle()` - 切换显示状态

### AIPolishViewModel.swift
AI 润色功能视图模型，使用 `@Observable` 宏。

**管理的设置**：
- `enableAIPolish` - AI 润色开关
- `polishThreshold` - 自动润色阈值
- `defaultProfile` - 默认润色配置
- `appProfileMapping` - 应用专属配置映射
- `enableInSentencePatterns` - 句内模式识别开关
- `enableTriggerCommands` - 句尾唤醒指令开关
- `triggerWord` - 唤醒词

**⚠️ 问题**：使用 `didSet` 同步到 `AppSettings`，数据流混乱

### PreferencesViewModel.swift
偏好设置视图模型，使用 `@Observable` 宏。

**管理的设置**：
- 快捷键配置
- 开机自启动
- 声音反馈
- 翻译语言
- 通讯录热词
- 自动回车
- 语言设置

**⚠️ 问题**：使用 `didSet` 同步到 `AppSettings`，数据流混乱

### LibraryViewModel.swift
记录库视图模型，使用 `@Observable` 宏。

**职责**：
- 搜索和分类过滤
- 记录选择

**关键方法**：
- `filterByCategory(_:)` - 按分类过滤
- `filterBySearchText(_:)` - 按搜索文本过滤

### StatsCalculator.swift
统计计算器。

**职责**：
- 计算今日统计（字符数、节省时间）
- 计算应用分布（Top 5 + 其他）
- 查询最近笔记

**关键方法**：
- `calculateTodayStats()` - 今日统计
- `calculateAppDistribution()` - 应用分布
- `fetchRecentNotes()` - 最近笔记

**⚠️ 问题**：魔法数字 `typingSpeedPerSecond = 1.0` 应集中管理

### PersistenceController.swift
CoreData 持久化控制器，单例模式。

**职责**：
- CoreData 栈初始化
- 数据 CRUD 操作

### DeviceIdManager.swift
设备 ID 管理器，单例模式。

**职责**：
- 生成和存储设备唯一标识
- 用于多设备数据隔离

### QuotaManager.swift
配额管理器。

**职责**：
- 管理用户使用配额
- 配额检查和更新

## 数据流

```
UI 操作 
    ↓
ViewModel.property = newValue (didSet)
    ↓
AppSettings.property = newValue (didSet)
    ↓
UserDefaults.set()
```

**⚠️ 问题**：双向 `didSet` 可能导致循环更新

## 待重构项

1. **移除 ViewModel 中的 didSet**：改为显式方法调用
2. **统一数据流**：AppSettings 作为唯一数据源
3. **集中魔法数字**：`typingSpeedPerSecond` 等移到 Constants
