# Permissions 模块

## 概述

Permissions 模块负责管理应用所需的系统权限。

## 文件结构

```
Features/Permissions/
├── README.md               # 本文档
└── PermissionManager.swift # 权限管理器
```

## 文件说明

### PermissionManager.swift
权限管理器，使用 `ObservableObject`。

**管理的权限**：
- `isAccessibilityTrusted` - 辅助功能权限
- `isInputMonitoringGranted` - 输入监控权限
- `isMicrophoneGranted` - 麦克风权限

**关键方法**：
- `checkAccessibilityStatus()` - 检查辅助功能权限
- `checkInputMonitoringStatus()` - 检查输入监控权限
- `checkMicrophoneStatus()` - 检查麦克风权限
- `promptForAccessibility()` - 弹出辅助功能权限请求
- `requestInputMonitoring()` - 请求输入监控权限
- `requestMicrophoneAccess()` - 请求麦克风权限

## 权限说明

### 辅助功能权限 (Accessibility)
**用途**：
- 获取光标位置
- 在其他应用中插入文本
- 监听全局键盘事件

**检查方式**：
```swift
AXIsProcessTrustedWithOptions(options as CFDictionary)
```

**请求方式**：
```swift
// 弹出系统设置
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
AXIsProcessTrustedWithOptions(options as CFDictionary)
```

### 输入监控权限 (Input Monitoring)
**用途**：
- CGEventTap 监听键盘事件

**检查方式**：
```swift
CGPreflightListenEventAccess()
```

**请求方式**：
```swift
CGRequestListenEventAccess()
```

### 麦克风权限 (Microphone)
**用途**：
- 录音进行语音识别

**检查方式**：
```swift
AVCaptureDevice.authorizationStatus(for: .audio)
```

**请求方式**：
```swift
AVCaptureDevice.requestAccess(for: .audio) { granted in ... }
```

## 权限状态

```swift
enum AuthorizationStatus {
    case notDetermined  // 未决定（首次）
    case authorized     // 已授权
    case denied         // 已拒绝
    case restricted     // 受限（家长控制等）
}
```

## 权限引导流程

```
应用启动
    ↓
检查所有权限状态
    ↓
如果有未授权的权限：
├── 显示 Onboarding 引导
├── 逐个请求权限
└── 引导用户到系统设置
    ↓
所有权限就绪 → 进入正常模式
```

## 系统设置路径

- **辅助功能**：系统设置 → 隐私与安全性 → 辅助功能
- **输入监控**：系统设置 → 隐私与安全性 → 输入监控
- **麦克风**：系统设置 → 隐私与安全性 → 麦克风

## 打开系统设置

```swift
// 打开辅助功能设置
NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)

// 打开麦克风设置
NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
```

## 待重构项

1. **权限状态缓存**：避免频繁检查
2. **权限变更监听**：监听系统权限变更通知
