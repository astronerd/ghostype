# Hotkey 模块

## 概述

Hotkey 模块负责全局快捷键监听，实现"按住说话，松开插入"的交互模式。

## 文件结构

```
Features/Hotkey/
├── README.md           # 本文档
└── HotkeyManager.swift # 快捷键管理器
```

## 文件说明

### HotkeyManager.swift
全局快捷键管理器，使用 CGEventTap 实现。

**核心功能**：
- 监听全局键盘事件
- 支持单独修饰键作为快捷键（如只按 Option）
- 支持修饰键+普通键组合（如 Option+Space）
- 动态模式切换（润色/翻译/随心记）
- 模式粘连（500ms 延迟）

**回调**：
- `onHotkeyDown` - 快捷键按下
- `onHotkeyUp` - 快捷键松开，传入最终模式
- `onModeChanged` - 模式切换

**关键方法**：
- `start()` - 启动事件监听
- `stop()` - 停止事件监听

**配置参数**：
- `stickyDelayMs = 500` - 模式粘连延迟
- `modifierDebounceMs = 300` - 修饰键防抖延迟

**⚠️ 问题**：魔法数字应集中管理

## 单独修饰键触发逻辑

类似 Karabiner-Elements 的 `to_if_alone` 机制：

```
按下修饰键
    ↓
等待 300ms (debounce)
    ↓
┌─────────────────────────────────────┐
│ 300ms 内松开 → 不触发（太快，可能误触）
│ 300ms 内按其他键 → 不触发（是组合键）
│ 300ms 后仍按着 → 触发录音
└─────────────────────────────────────┘
```

## 模式切换逻辑

```
主快捷键按下（开始录音）
    ↓
检测额外修饰键：
├── + Shift → 翻译模式
├── + Command → 随心记模式
└── 无额外修饰键 → 润色模式
    ↓
录音中可动态切换模式
    ↓
松开快捷键时，使用最终模式
```

## 模式粘连

防止用户在松开主快捷键前不小心先松开了模式修饰键：

```
用户按 Option（开始录音）
    ↓
用户按 Shift（切换到翻译模式）
    ↓
用户松开 Shift（模式变回润色）
    ↓
500ms 内松开 Option → 仍使用翻译模式
500ms 后松开 Option → 使用润色模式
```

## 事件处理流程

```
CGEventTap 捕获事件
    ↓
判断快捷键类型：
├── 单独修饰键 → handleModifierOnlyHotkey()
└── 修饰键+普通键 → handleModifierPlusKeyHotkey()
    ↓
处理 keyDown/keyUp/flagsChanged 事件
    ↓
触发回调
```

## 依赖

- `AppSettings` - 读取快捷键配置
- `AXIsProcessTrusted()` - 检查辅助功能权限

## 权限要求

- **辅助功能权限**：用于 CGEventTap
- **输入监控权限**：用于监听键盘事件

## 待重构项

1. **集中魔法数字**：`stickyDelayMs`、`modifierDebounceMs` 移到 Constants
2. **日志优化**：使用统一的 Logger
