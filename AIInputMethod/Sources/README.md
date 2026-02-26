# GHOSTYPE 源码结构

## 概述

GHOSTYPE（鬼才打字）是一款 macOS 语音输入应用，支持语音识别、AI 润色、翻译等功能。

## 技术栈

- **语言**：Swift 5.9+
- **UI 框架**：SwiftUI
- **最低系统**：macOS 14+ (Sonoma)
- **数据持久化**：CoreData + UserDefaults
- **语音识别**：豆包语音识别 API
- **AI 润色**：豆包 LLM / MiniMax LLM

## 目录结构

```
Sources/
├── README.md                    # 本文档
├── AIInputMethodApp.swift       # App 入口 + AppDelegate
├── Features/                    # 功能模块
│   ├── AI/                      # LLM 服务
│   │   └── README.md
│   ├── Dashboard/               # Dashboard 状态和 ViewModel
│   │   └── README.md
│   ├── Settings/                # 设置和本地化
│   │   └── README.md
│   ├── Speech/                  # 语音识别
│   │   └── README.md
│   ├── Hotkey/                  # 快捷键
│   │   └── README.md
│   ├── Accessibility/           # 光标管理
│   │   └── README.md
│   ├── Permissions/             # 权限管理
│   │   └── README.md
│   └── Contacts/                # 通讯录
├── UI/                          # SwiftUI 视图
│   └── README.md
└── Resources/                   # 资源文件
```

## 核心链路

```
用户按住快捷键 → HotkeyManager 捕获
       ↓
DoubaoSpeechService 录音 + 语音识别
       ↓
AppDelegate.processWithMode() 分发
       ↓
┌─────────────────────────────────────┐
│ polish → DoubaoLLMService.polishWithProfile()
│ translate → DoubaoLLMService.translate()
│ memo → 直接保存到 CoreData
└─────────────────────────────────────┘
       ↓
insertTextAtCursor() 粘贴上屏
       ↓
saveUsageRecord() 记录到 CoreData
```

## 模块依赖关系

```
AIInputMethodApp (AppDelegate)
    │
    ├── HotkeyManager ──────────────┐
    │       │                       │
    │       ↓                       │
    ├── DoubaoSpeechService         │
    │       │                       │
    │       ↓                       │
    ├── DoubaoLLMService ←──────────┤
    │       │                       │
    │       ↓                       │
    ├── CursorManager               │
    │       │                       │
    │       ↓                       │
    └── PersistenceController       │
                                    │
    AppSettings ←───────────────────┘
```

## 单例列表

| 类名 | 访问方式 | 职责 |
|------|----------|------|
| AppSettings | `.shared` | 全局设置 |
| DoubaoLLMService | `.shared` | LLM 服务 |
| MiniMaxService | `.shared` | 备用 LLM |
| PersistenceController | `.shared` | CoreData |
| DeviceIdManager | `.shared` | 设备 ID |
| DashboardWindowController | `.shared` | 窗口管理 |
| LocalizationManager | `.shared` | 多语言 |
| ContactsManager | `.shared` | 通讯录 |

## 已知问题

### 🔴 严重
1. **API Key 硬编码**：DoubaoLLMService、MiniMaxService、DoubaoSpeechService
2. **God Class**：AppDelegate 500+ 行，职责过多

### 🟠 中等
3. **数据流混乱**：ViewModel 和 AppSettings 双向 didSet
4. **魔法数字散落**：HotkeyManager、DoubaoSpeechService、StatsCalculator
5. **本地化不完整**：多个页面硬编码中文

### 🟡 轻微
6. **组件重复**：BentoCard 和 MinimalBentoCard
7. **命名不一致**：RecordCategory.all 不是真正的分类

## 重构计划

详见 `.kiro/specs/refactoring/` 目录：
- `requirements.md` - 重构需求
- `design.md` - 重构设计
- `tasks.md` - 重构任务

## 本地化规范

详见 `.kiro/steering/localization.md`

## 开发指南

详见 `.kiro/steering/refactoring-guide.md`
