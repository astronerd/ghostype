# Accessibility 模块

## 概述

Accessibility 模块负责与 macOS 辅助功能 API 交互，实现光标位置获取和文本插入。

## 文件结构

```
Features/Accessibility/
├── README.md            # 本文档
├── CursorManager.swift  # 光标管理器
└── FocusObserver.swift  # 焦点观察器
```

## 文件说明

### CursorManager.swift
光标管理器，负责获取光标位置和插入文本。

**职责**：
- 获取当前光标位置（用于浮窗定位）
- 在光标位置插入文本

**关键方法**：
- `getCursorBounds(for:)` - 获取光标边界，多重回退策略
- `insertText(_:into:)` - 在指定元素插入文本

**光标位置获取策略**（按优先级）：
1. 从传入的 AXUIElement 获取
2. 从系统焦点元素获取
3. 回退到鼠标位置

**获取方法**：
1. `kAXBoundsForRangeParameterizedAttribute` - 最精确
2. `AXInsertionPointLineNumber` + 元素位置 - 备选
3. 鼠标位置 - 最后回退

### FocusObserver.swift
焦点观察器，监听系统焦点变化。

**职责**：
- 监听当前焦点应用
- 监听当前焦点元素
- 用于自动模式（聚焦输入框时自动录音）

## AX API 使用

### 获取焦点元素
```swift
let systemWide = AXUIElementCreateSystemWide()
var focusedElement: AnyObject?
AXUIElementCopyAttributeValue(
    systemWide, 
    kAXFocusedUIElementAttribute as CFString, 
    &focusedElement
)
```

### 获取光标位置
```swift
// 获取选中范围
AXUIElementCopyAttributeValue(
    element, 
    kAXSelectedTextRangeAttribute as CFString, 
    &rangeValue
)

// 获取范围对应的边界
AXUIElementCopyParameterizedAttributeValue(
    element,
    kAXBoundsForRangeParameterizedAttribute as CFString,
    range,
    &boundsValue
)
```

### 插入文本
```swift
AXUIElementSetAttributeValue(
    element, 
    kAXSelectedTextAttribute as CFString, 
    text as AnyObject
)
```

## 坐标系统

macOS 有两种坐标系统：
- **Cocoa 坐标**：原点在左下角
- **AX 坐标**：原点在左上角

转换公式：
```swift
axY = screenHeight - cocoaY
```

## 权限要求

- **辅助功能权限**：必须，否则无法访问 AX API

## 常见问题

1. **获取不到光标位置**
   - 某些应用不支持 AX API
   - 回退到鼠标位置

2. **坐标不准确**
   - 检查坐标系转换
   - 验证是否在屏幕范围内

3. **插入文本失败**
   - 检查辅助功能权限
   - 某些应用可能不支持

## 待重构项

1. **提取 TextInsertionService**：从 AppDelegate 迁移文本插入逻辑
2. **统一错误处理**：AX API 错误应有统一处理
