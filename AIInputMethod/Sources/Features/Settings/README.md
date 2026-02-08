# Settings 模块

## 概述

Settings 模块负责全局设置管理和多语言本地化。

## 文件结构

```
Features/Settings/
├── README.md               # 本文档
├── AppSettings.swift       # 全局应用设置
├── Localization.swift      # 语言枚举和管理器
├── Strings.swift           # 字符串 key 定义
├── Strings+Chinese.swift   # 中文翻译
├── Strings+English.swift   # 英文翻译
└── Logger.swift            # 日志工具
```

## 文件说明

### AppSettings.swift
全局应用设置，单例模式，使用 `ObservableObject`。

**设置分类**：

1. **快捷键设置**
   - `hotkeyModifiers` - 主触发键修饰符
   - `hotkeyKeyCode` - 主触发键 keyCode
   - `hotkeyDisplay` - 快捷键显示文本

2. **模式修饰键**
   - `translateModifier` - 翻译模式修饰键（默认 Shift）
   - `memoModifier` - 随心记模式修饰键（默认 Command）

3. **AI 功能**
   - `enableAIPolish` - AI 润色开关
   - `polishThreshold` - 自动润色阈值
   - `defaultProfile` - 默认润色配置
   - `appProfileMapping` - 应用专属配置映射
   - `customProfilePrompt` - 自定义 Prompt

4. **智能指令**
   - `enableInSentencePatterns` - 句内模式识别
   - `enableTriggerCommands` - 句尾唤醒指令
   - `triggerWord` - 唤醒词

5. **其他设置**
   - `translateLanguage` - 翻译语言
   - `autoStartOnFocus` - 自动模式
   - `launchAtLogin` - 开机自启动
   - `enableContactsHotwords` - 通讯录热词
   - `enableAutoEnter` - 自动回车
   - `autoEnterApps` - 自动回车应用列表
   - `appLanguage` - 应用语言

**持久化**：所有设置通过 `didSet` 自动保存到 `UserDefaults`

**⚠️ 问题**：`didSet` 自动保存可能与 ViewModel 的 `didSet` 产生循环

### Localization.swift
多语言管理。

**AppLanguage 枚举**：
- `.chinese` - 简体中文
- `.english` - English

**LocalizationManager**：
- 单例模式
- 管理当前语言设置
- 自动保存到 UserDefaults

### Strings.swift
字符串 key 定义，使用 `L.xxx` 访问。

**结构**：
```swift
enum L {
    enum Nav { ... }      // 导航
    enum Overview { ... } // 概览页
    enum Library { ... }  // 记录库页
    enum Memo { ... }     // 随心记页
    enum AIPolish { ... } // AI 润色页
    enum Prefs { ... }    // 偏好设置页
    enum Common { ... }   // 通用
    enum Profile { ... }  // 润色风格
    enum Auth { ... }     // 授权状态
}
```

**Protocol 定义**：
- `StringsTable` - 字符串表协议
- `NavStrings`, `OverviewStrings`, ... - 各分类协议

### Strings+Chinese.swift
中文翻译实现。

**结构**：
```swift
struct ChineseStrings: StringsTable {
    var nav: NavStrings { ChineseNav() }
    var overview: OverviewStrings { ChineseOverview() }
    // ...
}
```

### Strings+English.swift
英文翻译实现，结构同上。

### Logger.swift
日志工具。

**功能**：
- 文件日志记录
- 调试输出

## 本地化使用方式

```swift
// 使用本地化字符串
Text(L.Nav.overview)
Button(L.Common.save)

// 添加新字符串
// 1. Strings.swift 添加 key
// 2. Strings+Chinese.swift 添加中文
// 3. Strings+English.swift 添加英文
```

## 待重构项

1. **移除 AppSettings 的 didSet 保存**：改为显式 `save()` 方法
2. **添加设置变更通知**：使用 `NotificationCenter`
3. **创建 Constants.swift**：集中管理魔法数字
4. **创建 SecretsManager.swift**：安全存储敏感信息
