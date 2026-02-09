# 设计文档：润色风格卡片 & 共享应用选择器

## 概述

本设计涵盖两个关联改造：

1. **AI 润色风格卡片化**：将下拉选择器替换为卡片式布局，支持 5 个预设风格 + 多个自定义风格，移除 `PolishProfile.custom` case
2. **共享应用选择器**：创建 `AppPickerSheet` 组件，扫描已安装应用（非运行中应用），提供搜索功能，同时服务于「应用专属配置」和「自动回车」

## 架构

### 改动范围

```
Features/AI/
├── PolishProfile.swift          ← 移除 .custom case
├── CustomProfile.swift          ← 新增：自定义风格数据模型
├── PromptBuilder.swift          ← 修改：支持 CustomProfile prompt
└── PromptTemplates.swift        ← 不变

Features/Dashboard/
├── AIPolishViewModel.swift      ← 重构：支持卡片选择 + 自定义风格 CRUD
└── PreferencesViewModel.swift   ← 修改：使用新 AppPickerSheet

Features/Settings/
├── AppSettings.swift            ← 新增：customProfiles、selectedProfileId 字段
├── Strings.swift                ← 新增本地化 key
├── Strings+Chinese.swift        ← 新增中文翻译
└── Strings+English.swift        ← 新增英文翻译

UI/Dashboard/Pages/
├── AIPolishPage.swift           ← 重构：卡片布局 + 自定义风格 UI
└── PreferencesPage.swift        ← 修改：使用新 AppPickerSheet

UI/Dashboard/Components/
└── AppPickerSheet.swift         ← 新增：共享应用选择器组件
```

### 数据流

```
用户选择风格卡片
    ↓
AIPolishViewModel.selectedProfileId = "standard" | UUID字符串
    ↓
AppSettings.shared.selectedProfileId (UserDefaults 持久化)
    ↓
AppDelegate.processPolish() 调用时
    ↓
AIPolishViewModel.getProfileForApp(bundleId:)
    ↓
PromptBuilder.buildPrompt(profile:, customPrompt:, ...)
    ↓
GeminiService.polishWithProfile(...)
```

## 组件与接口

### 1. CustomProfile 数据模型

```swift
// AIInputMethod/Sources/Features/AI/CustomProfile.swift

import Foundation

struct CustomProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var prompt: String
    
    init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }
}
```

### 2. PolishProfile 枚举（移除 .custom）

```swift
// 修改后的 PolishProfile.swift

enum PolishProfile: String, CaseIterable, Identifiable {
    case standard = "默认"
    case professional = "专业"
    case casual = "活泼"
    case concise = "简洁"
    case creative = "创意"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .standard: return "去口语化、修语法、保原意"
        case .professional: return "正式书面语，适合邮件、报告"
        case .casual: return "保留口语感，轻松社交风格"
        case .concise: return "精简压缩，提炼核心"
        case .creative: return "润色+美化，增加修辞"
        }
    }
    
    var icon: String {
        switch self {
        case .standard: return "text.badge.checkmark"
        case .professional: return "briefcase"
        case .casual: return "face.smiling"
        case .concise: return "scissors"
        case .creative: return "paintbrush"
        }
    }
    
    var prompt: String {
        return PromptTemplates.toneForProfile(self)
    }
}
```

### 3. AppSettings 新增字段

```swift
// AppSettings.swift 新增

/// 自定义润色风格列表（JSON 编码存储）
@Published var customProfiles: [CustomProfile]

/// 当前选中的配置 ID（预设 rawValue 或自定义 UUID 字符串）
@Published var selectedProfileId: String

// UserDefaults Keys 新增
static let customProfiles = "customProfiles"
static let selectedProfileId = "selectedProfileId"
```

废弃字段：
- `defaultProfile: String` → 替换为 `selectedProfileId`
- `customProfilePrompt: String` → 移除，自定义 prompt 存储在 CustomProfile 中

### 4. AIPolishViewModel 重构

```swift
// 核心接口

@Observable
class AIPolishViewModel {
    // 选中的配置 ID
    var selectedProfileId: String
    
    // 自定义风格列表
    var customProfiles: [CustomProfile]
    
    // CRUD 方法
    func selectProfile(id: String)
    func addCustomProfile(name: String, prompt: String)
    func updateCustomProfile(id: UUID, name: String, prompt: String)
    func deleteCustomProfile(id: UUID)
    
    // 获取当前选中的 prompt（供 PromptBuilder 使用）
    func resolveProfile(for bundleId: String?) -> (profile: PolishProfile?, customPrompt: String?)
    
    // 应用专属配置（映射值改为 String ID）
    var appProfileMapping: [String: String]  // [BundleID: ProfileID]
    func addAppMapping(bundleId: String, profileId: String)
    func removeAppMapping(bundleId: String)
}
```

### 5. PromptBuilder 修改

```swift
// PromptBuilder.buildPrompt 签名不变，但调用方式改变

// 预设风格：
PromptBuilder.buildPrompt(
    profile: .standard,
    customPrompt: nil,
    ...
)

// 自定义风格：
PromptBuilder.buildPrompt(
    profile: .standard,  // 作为 fallback base
    customPrompt: customProfile.prompt,  // 自定义 prompt 作为 Tone
    ...
)
```

PromptBuilder 内部逻辑：当 `customPrompt` 非空时，使用它作为 Block 4 Tone；否则使用 `profile.prompt`。这与现有逻辑一致（原来 `.custom` case 就是这样处理的），只是不再依赖 `.custom` 枚举值。

### 6. AppPickerSheet 共享组件

```swift
// UI/Dashboard/Components/AppPickerSheet.swift

struct AppPickerSheet: View {
    let onSelect: (String) -> Void  // 回调 bundleId
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    @State private var installedApps: [InstalledAppInfo] = []
    
    var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct InstalledAppInfo: Identifiable {
    let id: String  // bundleId
    let name: String
    let icon: NSImage
    let bundleId: String
}
```

扫描逻辑：
1. 遍历 `/Applications`、`~/Applications`、`/System/Applications`
2. 使用 `FileManager` 查找 `.app` bundle
3. 读取 `Bundle(url:).bundleIdentifier` 和 `displayName`
4. 使用 `NSWorkspace.shared.icon(forFile:)` 获取图标
5. 跳过无法读取的应用，按名称排序

### 7. 风格卡片 UI 布局

```
┌─────────────────────────────────────────────────────┐
│ AI 润色风格                                          │
│                                                      │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌───┐ │
│ │ 默认 │ │ 专业 │ │ 活泼 │ │ 简洁 │ │ 创意 │ │ + │ │
│ │ ✓    │ │      │ │      │ │      │ │      │ │   │ │
│ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └───┘ │
│                                                      │
│ ┌──────────┐ ┌──────────┐                            │
│ │ 自定义1  │ │ 自定义2  │                            │
│ │ ✏️ 🗑   │ │ ✏️ 🗑   │                            │
│ └──────────┘ └──────────┘                            │
└─────────────────────────────────────────────────────┘
```

卡片使用 `LazyVGrid` 或 `FlowLayout` 水平排列，自动换行。选中卡片使用 `DS.Colors.accent` 边框高亮。

## 数据模型

### CustomProfile 存储格式

UserDefaults key: `customProfiles`

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "邮件",
    "prompt": "使用正式的商务邮件语气..."
  },
  {
    "id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
    "name": "朋友圈",
    "prompt": "轻松活泼，适合社交媒体..."
  }
]
```

### selectedProfileId 存储格式

UserDefaults key: `selectedProfileId`

- 预设风格：`"默认"`, `"专业"`, `"活泼"`, `"简洁"`, `"创意"`
- 自定义风格：`"550e8400-e29b-41d4-a716-446655440000"` (UUID 字符串)

### appProfileMapping 存储格式变更

UserDefaults key: `appProfileMapping`

```json
{
  "com.apple.mail": "专业",
  "com.tencent.xinWeChat": "550e8400-e29b-41d4-a716-446655440000"
}
```

值从 PolishProfile rawValue 扩展为支持 UUID 字符串。



## 正确性属性

*正确性属性是系统在所有有效执行中都应保持为真的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### Property 1: 单选不变量
*For any* 风格列表（预设 + 自定义）和任意一次选择操作，选择后有且仅有一个风格处于选中状态。
**Validates: Requirements 1.3**

### Property 2: 创建自定义风格后可查询
*For any* 有效的名称和 Prompt 文本，创建 CustomProfile 后，自定义风格列表中应包含该风格，且其名称和 Prompt 与输入一致。
**Validates: Requirements 2.3**

### Property 3: 删除自定义风格后不可查询
*For any* 已存在的 CustomProfile，删除后，自定义风格列表中不再包含该风格的 ID。
**Validates: Requirements 2.6**

### Property 4: 删除选中的自定义风格回退为默认
*For any* 当前选中的 CustomProfile，删除该风格后，selectedProfileId 应回退为 PolishProfile.standard 的 rawValue（"默认"）。
**Validates: Requirements 2.7**

### Property 5: CustomProfile JSON 往返一致性
*For any* 有效的 CustomProfile 数组，JSON 编码后再解码应产生等价的数组（id、name、prompt 均相同）。
**Validates: Requirements 3.2, 3.3, 3.5**

### Property 6: 配置 ID 解析正确性
*For any* 预设风格，其 ID 应等于其 rawValue；*for any* CustomProfile，其 ID 应等于其 UUID 的字符串表示。给定一个 selectedProfileId，系统应能正确解析为对应的预设风格或自定义风格。
**Validates: Requirements 3.4**

### Property 7: PromptBuilder 使用正确的 Tone
*For any* 预设风格，PromptBuilder 构建的 Prompt 应包含 PromptTemplates 中对应的 Tone 文本；*for any* 非空的自定义 Prompt 字符串，PromptBuilder 构建的 Prompt 应包含该自定义字符串。
**Validates: Requirements 4.2, 4.3**

### Property 8: 应用名称搜索过滤
*For any* 应用列表和任意搜索关键词，过滤结果中的每个应用名称都应包含该关键词（不区分大小写），且原列表中所有名称包含该关键词的应用都应出现在结果中。
**Validates: Requirements 5.3, 5.5**

### Property 9: 应用配置映射存储
*For any* bundleId 和任意 profileId（预设 rawValue 或自定义 UUID 字符串），添加映射后，appProfileMapping 中该 bundleId 对应的值应等于 profileId。
**Validates: Requirements 6.3, 7.2**

### Property 10: 级联删除重置应用映射
*For any* 引用某 CustomProfile 的应用映射，当该 CustomProfile 被删除时，这些应用的映射应回退为 PolishProfile.standard 的 rawValue。
**Validates: Requirements 7.3**

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| CustomProfile JSON 解码失败 | 返回空数组，不崩溃 |
| selectedProfileId 指向已删除的自定义风格 | 回退为 "默认" |
| appProfileMapping 中的 profileId 无法解析 | 使用默认风格 |
| 应用目录扫描遇到权限错误 | 跳过该目录，继续扫描其他目录 |
| 单个 .app bundle 无法读取 bundleId | 跳过该应用 |
| 自定义风格名称为空 | 阻止创建，提示用户输入名称 |
| 自定义风格 Prompt 为空 | 阻止创建，提示用户输入 Prompt |

## 测试策略

### 双重测试方法

本功能采用单元测试 + 属性测试互补的策略：

- **单元测试**：验证具体示例、边界情况和错误条件
- **属性测试**：验证跨所有输入的通用属性

### 属性测试配置

- **库**：使用 Swift 的 [swift-testing](https://github.com/apple/swift-testing) 框架配合手动随机生成器（Swift 生态中 PBT 库有限，使用自定义生成器实现属性测试）
- **每个属性测试最少运行 100 次迭代**
- **每个测试用注释标注对应的设计属性**
- **标注格式**：`// Feature: polish-style-and-app-picker, Property N: {property_text}`

### 单元测试重点

- PolishProfile 枚举只有 5 个 case（无 .custom）
- CustomProfile 结构体字段完整性
- 空名称/空 Prompt 的创建拒绝
- AppPickerSheet 空搜索返回全部应用
- 应用目录扫描跳过无效 bundle

### 属性测试重点

- Property 5: CustomProfile JSON 往返一致性（核心序列化属性）
- Property 7: PromptBuilder Tone 正确性
- Property 8: 搜索过滤完整性和正确性
- Property 1: 单选不变量
- Property 4 + 10: 级联删除行为
