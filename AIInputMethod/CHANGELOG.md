# GhosTYPE 开发记录

## 2026-02-06 重大更新

### 一、Dashboard Console 完整实现

完成了 `.kiro/specs/dashboard-console` 规格的所有任务，实现了完整的 Dashboard 控制台界面。

#### 1. 核心架构
- **DashboardState** (`Sources/Features/Dashboard/DashboardState.swift`)
  - 状态机：Onboarding / Normal 两种状态
  - 导航项管理
  - UserDefaults 持久化

- **NavItem** (`Sources/Features/Dashboard/NavItem.swift`)
  - 概览 (overview)
  - 历史库 (library)  
  - 偏好设置 (preferences)

#### 2. 数据层
- **CoreData 模型** (`Sources/Features/Dashboard/DashboardModel.xcdatamodeld`)
  - UsageRecord: 使用记录实体
  - QuotaRecord: 额度记录实体

- **DeviceIdManager** (`Sources/Features/Dashboard/DeviceIdManager.swift`)
  - UUID 生成
  - Keychain 存储
  - truncatedId 显示

- **QuotaManager** (`Sources/Features/Dashboard/QuotaManager.swift`)
  - 额度追踪
  - 百分比计算

- **PersistenceController** (`Sources/Features/Dashboard/PersistenceController.swift`)
  - CoreData 栈管理

- **StatsCalculator** (`Sources/Features/Dashboard/StatsCalculator.swift`)
  - 今日统计
  - 应用分布
  - 最近笔记查询

- **LibraryViewModel** (`Sources/Features/Dashboard/LibraryViewModel.swift`)
  - 搜索过滤
  - 分类筛选

#### 3. UI 组件
- **DashboardWindowController** (`Sources/Features/Dashboard/DashboardWindowController.swift`)
  - NSWindow 管理 (900x600 最小尺寸)
  - show/hide/toggle
  - 窗口位置持久化

- **DashboardView** (`Sources/UI/Dashboard/DashboardView.swift`)
  - 双栏布局：Sidebar (220pt) + Content
  - 状态切换动画
  - 权限提醒 Banner

- **SidebarView** (`Sources/UI/Dashboard/SidebarView.swift`)
  - 毛玻璃效果
  - 导航项列表
  - 底部设备ID + 额度条

- **OnboardingContentView** (`Sources/UI/Dashboard/OnboardingContentView.swift`)
  - 步骤指示器
  - 复用现有 Onboarding 组件

#### 4. 页面
- **OverviewPage** (`Sources/UI/Dashboard/Pages/OverviewPage.swift`)
  - Bento Grid 布局
  - 今日战报卡片
  - 能量环 (EnergyRingView)
  - 应用分布饼图 (PieChartView)
  - 最近笔记

- **LibraryPage** (`Sources/UI/Dashboard/Pages/LibraryPage.swift`)
  - 搜索框
  - 分类 Tabs
  - 记录列表 (RecordListItem)
  - 详情面板 (RecordDetailPanel)
  - 拖拽导出 .txt

- **PreferencesPage** (`Sources/UI/Dashboard/Pages/PreferencesPage.swift`)
  - 通用设置（开机自启、声音反馈）
  - 快捷键配置（复用 HotkeyRecorderView）
  - AI 引擎状态显示

- **PreferencesViewModel** (`Sources/Features/Dashboard/PreferencesViewModel.swift`)
  - UserDefaults 绑定
  - SMAppService 开机自启

#### 5. 组件
- **BentoCard** - 便当盒卡片，hover 缩放动画
- **EnergyRingView** - 圆环进度，>90% 警告色
- **PieChartView** - Swift Charts 饼图
- **RecordListItem** - 记录列表项，拖拽导出
- **RecordDetailPanel** - 记录详情面板

---

### 二、AI 处理功能（核心新功能）

实现了不同快捷键触发不同 AI 处理效果。

#### 1. InputMode 枚举 (`Sources/Features/AI/InputMode.swift`)
```swift
enum InputMode {
    case polish    // 默认：AI 润色后上屏
    case translate // Shift + 主键：翻译后上屏
    case memo      // Cmd + 主键：随心记，不上屏
}
```

#### 2. MiniMaxService (`Sources/Features/AI/MiniMaxService.swift`)
- 使用 MiniMax 2.1 模型
- API Key 使用 Base64 编码存储
- 三种 Prompt：
  - **润色**: 去除口语赘词，修正语法，保持原意
  - **翻译**: 中英互译，自动检测语言
  - **笔记整理**: 提取关键信息，简洁要点

#### 3. HotkeyManager 更新 (`Sources/Features/Hotkey/HotkeyManager.swift`)
- 支持动态修饰键检测
- 录音过程中可以切换模式（按下/松开 Shift/Cmd）
- 新增回调：
  - `onHotkeyUp: ((InputMode) -> Void)?` - 传入最终模式
  - `onModeChanged: ((InputMode) -> Void)?` - 模式变化通知

#### 4. AppDelegate 集成
- 根据模式调用不同 AI 处理
- 润色/翻译：处理后上屏
- 随心记：保存到 CoreData，不上屏
- 菜单栏显示模式说明

---

### 三、菜单栏集成

- 左键点击：打开 Dashboard
- 右键点击：显示菜单
- 菜单显示模式说明：
  - 🟢 默认: 润色上屏
  - 🟣 +Shift: 翻译上屏
  - 🟠 +Cmd: 随心记

---

### 四、文件结构

```
Sources/
├── AIInputMethodApp.swift          # 主入口，集成所有功能
├── Features/
│   ├── AI/
│   │   ├── InputMode.swift         # 输入模式枚举
│   │   └── MiniMaxService.swift    # MiniMax AI 服务
│   ├── Dashboard/
│   │   ├── DashboardModel.xcdatamodeld/
│   │   ├── DashboardState.swift
│   │   ├── DashboardWindowController.swift
│   │   ├── DeviceIdManager.swift
│   │   ├── LibraryViewModel.swift
│   │   ├── NavItem.swift
│   │   ├── PersistenceController.swift
│   │   ├── PreferencesViewModel.swift
│   │   ├── QuotaManager.swift
│   │   ├── QuotaRecord+CoreDataClass.swift
│   │   ├── QuotaRecord+CoreDataProperties.swift
│   │   ├── RecordCategory.swift
│   │   ├── StatsCalculator.swift
│   │   ├── UsageRecord+CoreDataClass.swift
│   │   └── UsageRecord+CoreDataProperties.swift
│   └── Hotkey/
│       └── HotkeyManager.swift     # 更新：支持动态模式切换
└── UI/
    └── Dashboard/
        ├── Components/
        │   ├── BentoCard.swift
        │   ├── EnergyRingView.swift
        │   ├── PieChartView.swift
        │   ├── RecordDetailPanel.swift
        │   └── RecordListItem.swift
        ├── Pages/
        │   ├── LibraryPage.swift
        │   ├── OverviewPage.swift
        │   └── PreferencesPage.swift
        ├── DashboardView.swift
        ├── OnboardingContentView.swift
        └── SidebarView.swift
```

---

### 五、待完成功能

1. **Overlay UI 模式变色** - 根据当前模式显示不同颜色（绿/紫/橙）
2. **随心记保存动画** - 保存成功后的视觉反馈
3. **额度管理系统** - 免费用户 60 分钟/月限制
4. **用户登录/注册** - Sign in with Apple / 微信扫码
5. **跑道变圆球动画** - AI 处理时的形变动画

---

### 六、使用方式

1. **默认润色**: 按住 `Option + Space`（或自定义快捷键）说话，松开后 AI 润色并上屏
2. **翻译模式**: 按住快捷键 + `Shift` 说话，松开后翻译并上屏
3. **随心记**: 按住快捷键 + `Cmd` 说话，松开后保存到笔记（不上屏）
4. **打开 Dashboard**: 点击菜单栏图标

---

### 七、技术栈

- SwiftUI + AppKit (macOS 13+)
- CoreData 本地存储
- MiniMax 2.1 API (AI 润色/翻译)
- 豆包 STT (语音识别)
- CGEvent 全局快捷键监听
