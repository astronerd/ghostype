# UI 模块

## 概述

UI 模块包含所有 SwiftUI 视图和窗口。

## 文件结构

```
UI/
├── README.md                    # 本文档
├── Dashboard/                   # Dashboard 主界面
│   ├── DashboardView.swift      # Dashboard 主视图
│   ├── SidebarView.swift        # 侧边栏
│   ├── DesignSystem.swift       # 设计系统（颜色、字体等）
│   ├── UI_DESIGN_SPEC.md        # UI 设计规范
│   ├── Pages/                   # 页面
│   │   ├── OverviewPage.swift   # 概览页
│   │   ├── LibraryPage.swift    # 记录库页
│   │   ├── MemoPage.swift       # 随心记页
│   │   ├── AIPolishPage.swift   # AI 润色页
│   │   └── PreferencesPage.swift # 偏好设置页
│   └── Components/              # 组件
│       ├── BentoCard.swift      # Bento 卡片
│       ├── EnergyRingView.swift # 能量环
│       ├── PieChartView.swift   # 饼图
│       ├── RecordListItem.swift # 记录列表项
│       └── RecordDetailPanel.swift # 记录详情面板
├── OverlayView.swift            # 浮窗视图
├── OnboardingWindow.swift       # 引导窗口
├── PermissionWindow.swift       # 权限窗口
├── OverlayTestWindow.swift      # 浮窗测试窗口
└── TestWindow.swift             # 测试窗口
```

## Dashboard 页面

### DashboardView.swift
Dashboard 主视图，包含侧边栏和内容区。

**结构**：
```
┌─────────────────────────────────────┐
│ Sidebar │        Content           │
│         │                          │
│ [Nav]   │   [Selected Page]        │
│         │                          │
└─────────────────────────────────────┘
```

### SidebarView.swift
侧边栏导航。

**导航项**：
- 概览 (Overview)
- 记录库 (Library)
- 随心记 (Memo)
- AI 润色 (AI Polish)
- 偏好设置 (Preferences)

### OverviewPage.swift
概览页，显示统计数据。

**内容**：
- 今日统计（字符数、节省时间）
- 应用分布饼图
- 最近笔记

**⚠️ 问题**：
- 定义了 `MinimalBentoCard`，与 `BentoCard` 重复
- 部分文案硬编码

### LibraryPage.swift
记录库页，显示所有使用记录。

**功能**：
- 分类过滤（全部/润色/翻译/随心记）
- 搜索
- 记录详情

**⚠️ 问题**：部分文案硬编码

### MemoPage.swift
随心记页，显示笔记列表。

**⚠️ 问题**：部分文案硬编码

### AIPolishPage.swift
AI 润色设置页。

**设置项**：
- AI 润色开关
- 自动润色阈值
- 润色配置文件
- 句内模式识别
- 句尾唤醒指令

**⚠️ 问题**：部分文案硬编码

### PreferencesPage.swift
偏好设置页。

**设置项**：
- 通用设置
- 快捷键
- 权限
- 翻译设置
- 通讯录热词
- 自动回车
- AI 引擎状态

**✅ 已本地化**

## 组件

### BentoCard.swift
Bento 风格卡片组件。

**⚠️ 问题**：与 `OverviewPage` 中的 `MinimalBentoCard` 功能重复

### EnergyRingView.swift
能量环视图，用于显示进度。

### PieChartView.swift
饼图视图，用于显示应用分布。

### RecordListItem.swift
记录列表项组件。

### RecordDetailPanel.swift
记录详情面板。

## 其他窗口

### OverlayView.swift
浮窗视图，显示录音状态和识别结果。

**状态**：
- 录音中
- 处理中
- 完成

### OnboardingWindow.swift
引导窗口，首次启动时显示。

**步骤**：
1. 快捷键配置
2. 输入模式选择
3. 权限申请

### PermissionWindow.swift
权限请求窗口。

## 设计系统

### DesignSystem.swift
定义全局设计常量。

**内容**：
- 颜色定义
- 字体定义
- 间距定义
- 圆角定义

## 本地化状态

| 页面 | 状态 |
|------|------|
| PreferencesPage | ✅ 已本地化 |
| OverviewPage | ❌ 待本地化 |
| LibraryPage | ❌ 待本地化 |
| MemoPage | ❌ 待本地化 |
| AIPolishPage | ❌ 待本地化 |
| SidebarView | ❌ 待本地化 |
| OnboardingWindow | ❌ 待本地化 |

## 待重构项

1. **完成本地化**：所有页面使用 `L.xxx` 访问字符串
2. **统一 BentoCard**：合并 `BentoCard` 和 `MinimalBentoCard`
3. **提取 OverlayWindowManager**：从 AppDelegate 迁移浮窗管理逻辑
4. **提取 MenuBarManager**：从 AppDelegate 迁移菜单栏管理逻辑
