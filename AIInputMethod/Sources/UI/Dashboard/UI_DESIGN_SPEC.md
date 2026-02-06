# GhosTYPE Dashboard UI 设计规范

> 版本: 2.0 | 更新日期: 2026-02-07

## 设计理念

**Radical Minimalist** - 极简主义设计，类似干净的阅读模式

核心原则：
- 温暖的米白色背景，模拟纸张质感
- 1px 浅灰色边框分隔区域，无阴影，扁平设计
- 最小化颜色使用，仅用 muted green/red 作为状态指示
- 其他元素保持单色/灰度
- 最多使用 5 种字号/字重组合

---

## 1. 窗口规格

| 属性 | 值 | 说明 |
|------|-----|------|
| 窗口尺寸 | 1000 × 700 px | 固定尺寸，不可调整 |
| 侧边栏宽度 | 200 px | 固定宽度 |
| 内容区域宽度 | 800 px | 自动填充剩余空间 |
| 窗口样式 | `.titled` `.closable` `.miniaturizable` | 无全屏按钮 |

---

## 2. 颜色系统

### 2.1 亮色模式

| 语义名称 | 颜色名 | Hex | RGB | 用途 |
|----------|--------|-----|-----|------|
| bg1 | Porcelain | #F7F7F4 | 247, 247, 244 | 主背景 |
| bg2 | Parchment | #F1F0ED | 241, 240, 237 | 卡片/侧边栏背景 |
| highlight | Alabaster Grey | #E3E4E0 | 227, 228, 224 | 选中/高亮背景 |
| border | Dust Grey | #CECDC9 | 206, 205, 201 | 边框/分隔线 |
| text1 | Carbon Black | #26251E | 38, 37, 30 | 主文字 |
| text2 | Grey Olive | #898883 | 137, 136, 131 | 次要文字 |
| text3 | Alabaster Grey | #B8BCBF | 184, 188, 191 | 辅助/禁用文字 |
| icon | Grey Olive | #898883 | 137, 136, 131 | 图标颜色 |

### 2.2 暗色模式

| 语义名称 | 颜色名 | Hex | RGB | 用途 |
|----------|--------|-----|-----|------|
| bg1 | Carbon Black | #1D2225 | 29, 34, 37 | 主背景 |
| bg2 | Jet Black | #262A2D | 38, 42, 45 | 卡片/侧边栏背景 |
| highlight | Carbon Black | #373C41 | 55, 60, 65 | 选中/高亮背景 |
| border | Dim Grey | #464B50 | 70, 75, 80 | 边框/分隔线 |
| text1 | Silver | #F0F0EE | 240, 240, 238 | 主文字 |
| text2 | Grey | #A0A5AA | 160, 165, 170 | 次要文字 |
| text3 | Dim Grey | #6E7378 | 110, 115, 120 | 辅助/禁用文字 |
| icon | Grey | #8C9196 | 140, 145, 150 | 图标颜色 |

### 2.3 状态颜色（通用）

| 状态 | 颜色 | Opacity | 用途 |
|------|------|---------|------|
| Success | Muted Green | 0.85 | 成功/已授权状态 |
| Warning | Muted Orange | 0.85 | 警告/额度不足 |
| Error | Muted Red | 0.85 | 错误/未授权状态 |

---

## 3. 间距系统

| Token | 值 | 用途 |
|-------|-----|------|
| xs | 4 px | 最小间距、元素内部微调 |
| sm | 8 px | 小间距、图标与文字间距 |
| md | 12 px | 中等间距、列表项内部 |
| lg | 16 px | 大间距、卡片内部 padding |
| xl | 24 px | 特大间距、页面 padding、卡片间距 |
| xxl | 32 px | 超大间距、页面顶部 padding |

### 3.1 统一间距规则

```
页面 padding:        24 px (xl)
卡片间距:            24 px (xl)
卡片内部 padding:    24 px (xl)
标题与内容间距:      24 px (xl)
侧边栏 padding:      16 px (lg) 水平, 24 px (xl) 垂直
```

---

## 4. 字体系统

| 名称 | 字号 | 字重 | 用途 |
|------|------|------|------|
| largeTitle | 24 pt | medium | 页面标题 |
| title | 16 pt | medium | 区块标题、侧边栏标题 |
| body | 13 pt | regular | 正文内容、列表项 |
| caption | 11 pt | regular | 辅助说明、标签 |
| sectionHeader | 10 pt | medium | 侧边栏分组标题（大写+字间距） |

### 4.1 特殊字体

| 用途 | 字号 | 字重 | 说明 |
|------|------|------|------|
| 大数字展示 | 32 pt | medium | 今日字数等统计数字 |
| 等宽文字 | 11-12 pt | regular | 设备 ID、快捷键显示 |

### 4.2 字体使用规则

- 最多使用 5 种字号/字重组合
- 标签文字统一使用 caption (11 pt)
- 正文内容统一使用 body (13 pt)
- 分组标题使用 sectionHeader + 大写 + 1.5pt 字间距

---

## 5. 布局规格

### 5.1 边框与圆角

| 属性 | 值 |
|------|-----|
| 边框宽度 | 1 px |
| 圆角半径 | 4 px |

### 5.2 侧边栏

| 属性 | 值 |
|------|-----|
| 宽度 | 200 px |
| 行高 | 32 px |
| 图标尺寸 | 13 px |
| 图标与文字间距 | 8 px |
| 水平 padding | 12 px |
| 分组标题样式 | 10pt, medium, 大写, 1.5pt 字间距 |

### 5.3 Bento Grid 卡片

| 卡片类型 | 高度 | 宽度 | 用途 |
|----------|------|------|------|
| 小卡片 | 200 px | 50% (自适应) | 输入字数统计、能量环 |
| 大卡片 | 320 px | 50% (自适应) | 应用分布、最近笔记 |

---

## 6. 组件规格

### 6.1 MinimalBentoCard

```
结构：
├── VStack (alignment: .leading, spacing: 12)
│   ├── Header
│   │   ├── Icon (12px, icon color)
│   │   └── Title (body font, text1)
│   └── Content
├── padding: 24 px
├── background: bg2
├── border: 1px border color
└── cornerRadius: 4 px
```

### 6.2 MinimalSettingsSection

```
结构：
├── Section Header
│   ├── Icon (12px, icon color)
│   └── Title (caption font, text2)
└── Content Card
    ├── background: bg2
    ├── border: 1px border color
    └── cornerRadius: 4 px
```

### 6.3 MinimalToggleRow

```
结构：
├── HStack (spacing: 12)
│   ├── Icon Container
│   │   ├── size: 28 × 28 px
│   │   ├── background: highlight
│   │   ├── cornerRadius: 4 px
│   │   └── Icon (14px, icon color)
│   ├── VStack
│   │   ├── Title (body font, text1)
│   │   └── Subtitle (caption font, text2)
│   └── Toggle (系统样式)
└── padding: horizontal 16, vertical 12
```

### 6.4 按钮样式

| 类型 | 尺寸 | 字体 | 边框 | 圆角 |
|------|------|------|------|------|
| 图标按钮 | 24 × 24 px | 11px icon | 1px border | 4px |
| 文字按钮 | auto × auto | caption | 无 | - |
| 带背景按钮 | auto × auto | caption | 无 | 4px |
| 快捷键框 | 80 × 40 px | 12pt mono | 1px border | 6px |
| 修饰键选择器 | 100 px 宽 | caption | 系统样式 | - |

### 6.5 分割线

```swift
MinimalDivider()
// 高度: 1 px
// 颜色: border color
// 可选: vertical = true 垂直分割线
```

### 6.6 状态指示点

```swift
StatusDot(status: .success, size: 8)
// 尺寸: 6-8 px
// 颜色: success/warning/error/neutral
```

---

## 7. 页面规格

### 7.1 概览页 (OverviewPage)

```
布局：
├── ScrollView
│   └── VStack (spacing: 24)
│       ├── Header
│       │   ├── 标题 "概览" (largeTitle)
│       │   └── 副标题 (body, text2)
│       └── Bento Grid
│           ├── Row 1 (spacing: 24)
│           │   ├── 输入字数统计 (200px height)
│           │   │   ├── 今日: [数字] 字 (32pt)
│           │   │   ├── 累积: [数字] 字
│           │   │   └── 节省时间: [时间]
│           │   └── 本月能量环 (200px height)
│           │       ├── EnergyRing (70×70)
│           │       └── 已用/剩余 统计
│           └── Row 2 (spacing: 24)
│               ├── 应用分布 (320px height)
│               │   └── PieChart + Legend
│               └── 最近笔记 (320px height)
│                   └── 最多 3 条笔记
└── padding: 24 px
```

### 7.2 随心记页 (MemoPage)

```
布局：
├── VStack (spacing: 0)
│   ├── Header (padding: 24)
│   │   ├── 标题 + 笔记数
│   │   └── 搜索框 (200px 宽)
│   ├── Divider
│   └── ScrollView
│       └── LazyVGrid (3 columns, spacing: 16)
│           └── MemoCard
│               ├── 内容文字 (body)
│               ├── 时间戳 (caption)
│               └── 操作按钮 (复制 + 删除)
└── padding: 24 px
```

### 7.3 偏好设置页 (PreferencesPage)

```
布局：
├── ScrollView
│   └── VStack (spacing: 24)
│       ├── 页面标题 (largeTitle)
│       └── Settings Sections
│           ├── 通用
│           ├── 权限管理
│           ├── 快捷键
│           ├── 模式修饰键
│           ├── AI 润色
│           ├── 翻译设置
│           ├── 通讯录热词
│           ├── 自动发送
│           ├── 自定义 Prompt
│           ├── AI 引擎
│           └── 恢复默认设置
└── padding: 32 px
```

---

## 8. 交互规范

### 8.1 Hover 效果

| 元素 | 效果 |
|------|------|
| 按钮 | opacity: 0.5 → 1.0 |
| 侧边栏项 | background: transparent → highlight (0.5 opacity) |
| 卡片操作按钮 | opacity: 0.5 → 1.0 |

### 8.2 选中状态

| 元素 | 效果 |
|------|------|
| 侧边栏项 | background: highlight, text: text1 |
| 卡片 | border: text1 (而非 border color) |

### 8.3 禁用状态

| 元素 | 效果 |
|------|------|
| 整体区域 | opacity: 0.5 |
| 按钮 | 不可点击 |

### 8.4 动画

| 动画 | 参数 |
|------|------|
| 能量环进度 | easeInOut, 0.6s |
| 侧边栏切换 | easeInOut, 0.15s |
| 页面切换 | 无动画，即时切换 |

---

## 9. 计算逻辑

### 9.1 节省时间计算

```
节省时间 = 打字时间 - 说话时间
打字时间 = 字符数 / 打字速度 (1 字符/秒 = 60 字符/分钟)
说话时间 = 音频时长总和

示例：
- 输入 60 字，音频时长 10 秒
- 打字时间 = 60 / 1 = 60 秒
- 节省时间 = 60 - 10 = 50 秒
```

### 9.2 时间格式化

```
0 秒 → "0 分钟"
1-59 秒 → "X秒"
60 秒 → "1分钟"
90 秒 → "1分30秒"
```

---

## 10. 代码引用

设计系统定义: `AIInputMethod/Sources/UI/Dashboard/DesignSystem.swift`

```swift
// 颜色
DS.Colors.bg1           // 主背景
DS.Colors.bg2           // 卡片背景
DS.Colors.highlight     // 高亮背景
DS.Colors.border        // 边框
DS.Colors.text1         // 主文字
DS.Colors.text2         // 次要文字
DS.Colors.text3         // 辅助文字
DS.Colors.icon          // 图标
DS.Colors.statusSuccess // 成功状态
DS.Colors.statusWarning // 警告状态
DS.Colors.statusError   // 错误状态

// 间距
DS.Spacing.xs           // 4
DS.Spacing.sm           // 8
DS.Spacing.md           // 12
DS.Spacing.lg           // 16
DS.Spacing.xl           // 24
DS.Spacing.xxl          // 32

// 字体
DS.Typography.largeTitle        // 24pt medium
DS.Typography.title             // 16pt medium
DS.Typography.body              // 13pt regular
DS.Typography.caption           // 11pt regular
DS.Typography.sectionHeader     // 10pt medium
DS.Typography.ui(size, weight)  // 自定义
DS.Typography.mono(size, weight) // 等宽

// 布局
DS.Layout.sidebarWidth      // 200
DS.Layout.cornerRadius      // 4
DS.Layout.borderWidth       // 1
DS.Layout.sidebarRowHeight  // 32
```

---

## 11. 组件清单

| 组件名 | 文件位置 | 用途 |
|--------|----------|------|
| MinimalBentoCard | OverviewPage.swift | Bento 卡片容器 |
| MinimalSettingsSection | PreferencesPage.swift | 设置分组容器 |
| MinimalToggleRow | PreferencesPage.swift | 开关设置行 |
| MinimalNavigationRow | PreferencesPage.swift | 导航设置行 |
| MinimalDivider | DesignSystem.swift | 分割线 |
| StatusDot | DesignSystem.swift | 状态指示点 |
| SectionHeader | DesignSystem.swift | 分组标题 |
| EnergyRingView | Components/EnergyRingView.swift | 能量环 |
| PieChartView | Components/PieChartView.swift | 饼图 |
| MemoCard | MemoPage.swift | 笔记卡片 |
| SidebarNavItem | SidebarView.swift | 侧边栏导航项 |
| HotkeyRecorderView | PreferencesPage.swift | 快捷键录制 |
| ModifierKeyPicker | PreferencesPage.swift | 修饰键选择器 |

---

## 12. 设计检查清单

开发时请确认：

- [ ] 所有颜色来自 DS.Colors
- [ ] 所有间距来自 DS.Spacing
- [ ] 所有字体来自 DS.Typography
- [ ] 边框宽度统一为 1px
- [ ] 圆角统一为 4px
- [ ] 无阴影效果
- [ ] 无毛玻璃/模糊效果
- [ ] 状态色仅用于状态指示
- [ ] Hover 效果仅改变透明度
- [ ] 支持亮色/暗色模式自动切换
