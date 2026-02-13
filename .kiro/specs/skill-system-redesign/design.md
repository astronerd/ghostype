# 设计文档：Skill 系统重构

## 概述

本次重构将 GHOSTYPE 的 Skill 系统从"硬编码枚举 + switch-case 路由"架构转变为"Agent 模式"架构。核心思想：每个 Skill 就是一个 Agent（prompt + tools），通过统一的执行管道运行。

关键设计决策：
- **SKILL.md 只包含语义内容**，与互联网通用 Skill 格式兼容
- **UI 元数据（emoji、颜色、快捷键）由程序内部 SkillMetadataStore 管理**
- **统一走 `POST /api/v1/skill/execute`**（客户端控制 prompt），润色/翻译保持走旧接口
- **ToolRegistry 模式**替代硬编码的输出分发逻辑

## 架构

```mermaid
graph TD
    subgraph "定义层"
        SKILL_MD["SKILL.md<br/>(name + description + prompt)"]
        META["SkillMetadataStore<br/>(emoji, color, hotkey)"]
    end

    subgraph "管理层"
        SM["SkillManager<br/>(加载/CRUD/快捷键)"]
        PARSER["SkillFileParser<br/>(解析/序列化)"]
        MIGRATION["SkillMigrationService<br/>(旧格式迁移)"]
    end

    subgraph "执行层"
        EXECUTOR["SkillExecutor<br/>(统一执行管道)"]
        TEMPLATE["TemplateEngine<br/>(变量替换)"]
    end

    subgraph "工具层"
        TR["ToolRegistry"]
        T1["insert_text"]
        T2["save_memo"]
        T3["floating_card"]
        T4["clipboard"]
    end

    subgraph "API 层"
        API_SKILL["POST /api/v1/skill/execute<br/>(客户端控制 prompt)"]
        API_LLM["POST /api/v1/llm/chat<br/>(服务端控制 prompt)"]
    end

    SKILL_MD --> PARSER
    PARSER --> SM
    META --> SM
    MIGRATION --> PARSER
    MIGRATION --> META

    SM --> EXECUTOR
    EXECUTOR --> TEMPLATE
    EXECUTOR --> API_SKILL
    EXECUTOR --> TR
    TR --> T1
    TR --> T2
    TR --> T3
    TR --> T4

    HK["HotkeyManager"] --> SM
    HK --> EXECUTOR
    AD["AppDelegate"] --> EXECUTOR


### 执行流程

```mermaid
sequenceDiagram
    participant User as 用户
    participant HK as HotkeyManager
    participant Speech as SpeechService
    participant AD as AppDelegate
    participant EX as SkillExecutor
    participant TPL as TemplateEngine
    participant API as GhostypeAPIClient
    participant TR as ToolRegistry

    User->>HK: 按住快捷键 + 修饰键
    HK->>Speech: 开始录音
    User->>HK: 松开快捷键
    HK->>Speech: 停止录音
    Speech->>AD: 语音文本
    AD->>EX: execute(skill, speechText, context)
    
    alt allowed_tools 仅含 save_memo
        EX->>TR: execute("save_memo", text)
        TR-->>AD: 保存完成
    else 需要 API 调用
        EX->>TPL: 替换 system_prompt 中的模板变量
        TPL-->>EX: 完整 prompt
        EX->>API: POST /api/v1/skill/execute
        API-->>EX: AI 结果
        EX->>TR: execute(primaryTool, result)
        TR-->>AD: 输出完成
    end
```

## 组件与接口

### 1. SkillModel（新数据模型）

替代当前包含 `SkillType` 枚举的 SkillModel。不再有类型概念，Skill 的行为完全由 `allowedTools` 和 `config` 决定。

```swift
struct SkillModel: Identifiable, Equatable {
    // 来自 SKILL.md（语义内容）
    let id: String                          // 目录名
    var name: String                        // 必填
    var description: String                 // 必填
    var systemPrompt: String                // Markdown body
    var allowedTools: [String]              // 默认 ["insert_text"]
    var config: [String: String]            // 可选配置参数
    
    // 来自 SkillMetadataStore（UI 元数据）
    var icon: String                        // emoji，默认 "✨"
    var colorHex: String                    // 颜色，默认 "#5AC8FA"
    var modifierKey: ModifierKeyBinding?    // 快捷键绑定
    var isBuiltin: Bool                     // 是否内置
}
```

### 2. SkillFileParser（新解析器）

只处理语义字段，不处理 UI 元数据。同时兼容旧格式（用于迁移）。

```swift
struct SkillFileParser {
    /// 解析结果：仅语义内容
    struct ParseResult: Equatable {
        let name: String
        let description: String
        let systemPrompt: String
        let allowedTools: [String]
        let config: [String: String]
        // 旧格式兼容字段（迁移用）
        let legacyFields: LegacyFields?
    }
    
    struct LegacyFields {
        let skillType: String?
        let icon: String?
        let colorHex: String?
        let modifierKeyCode: UInt16?
        let modifierKeyIsSystem: Bool?
        let modifierKeyDisplay: String?
        let isBuiltin: Bool?
        let isEditable: Bool?
        let behaviorConfig: [String: String]
    }
    
    /// 解析 SKILL.md 内容
    static func parse(_ content: String) throws -> ParseResult
    
    /// 序列化为 SKILL.md 格式（仅语义字段）
    static func print(_ result: ParseResult) -> String
}
```

### 3. SkillMetadataStore（新组件）

管理 Skill 的 UI 元数据，与 SKILL.md 完全解耦。

```swift
struct SkillMetadata: Codable, Equatable {
    var icon: String                        // emoji
    var colorHex: String                    // hex color
    var modifierKey: ModifierKeyBinding?    // 快捷键
    var isBuiltin: Bool                     // 是否内置
}

@Observable
class SkillMetadataStore {
    /// 存储路径：~/Library/Application Support/GHOSTYPE/skill_metadata.json
    private var metadata: [String: SkillMetadata] = [:]
    
    /// 获取元数据，不存在则返回默认值
    func get(skillId: String) -> SkillMetadata
    
    /// 更新元数据
    func update(skillId: String, metadata: SkillMetadata)
    
    /// 删除元数据
    func remove(skillId: String)
    
    /// 从磁盘加载
    func load()
    
    /// 保存到磁盘
    func save()
    
    /// 导入旧格式的 UI 元数据（迁移用）
    func importLegacy(skillId: String, legacy: SkillFileParser.LegacyFields)
}
```

### 4. SkillExecutor（替代 SkillRouter）

统一执行管道，不再有 switch-case。

```swift
class SkillExecutor {
    let apiClient: GhostypeAPIClient
    let contextDetector: ContextDetector
    let toolRegistry: ToolRegistry
    let templateEngine: TemplateEngine
    
    /// 统一执行入口
    func execute(
        skill: SkillModel,
        speechText: String,
        context: ContextBehavior? = nil,
        onDirectOutput: @escaping (String) -> Void,
        onRewrite: @escaping (String) -> Void,
        onFloatingCard: @escaping (String, String, SkillModel) -> Void,
        onError: @escaping (Error, ContextBehavior) -> Void
    ) async {
        let behavior = context ?? contextDetector.detect()
        
        // 1. save_memo 特殊路径：不调 API
        if skill.allowedTools == ["save_memo"] {
            onDirectOutput(speechText)
            return
        }
        
        // 2. 模板变量替换
        let resolvedPrompt = templateEngine.resolve(
            template: skill.systemPrompt,
            config: skill.config
        )
        
        // 3. 构建完整 prompt（拼入上下文信息）
        let fullPrompt = buildPrompt(
            systemPrompt: resolvedPrompt,
            behavior: behavior
        )
        
        // 4. 调用 API
        let endpoint = skill.config["api_endpoint"]
        let userMessage = buildUserMessage(
            speechText: speechText,
            behavior: behavior
        )
        
        do {
            let result = try await apiClient.executeSkill(
                systemPrompt: fullPrompt,
                message: userMessage,
                context: behavior,
                endpoint: endpoint
            )
            
            // 5. 根据 allowed_tools + context 分发结果
            dispatchResult(result, behavior: behavior, skill: skill,
                          speechText: speechText,
                          onDirectOutput: onDirectOutput,
                          onRewrite: onRewrite,
                          onFloatingCard: onFloatingCard)
        } catch {
            handleError(error, behavior: behavior, speechText: speechText,
                       onDirectOutput: onDirectOutput, onRewrite: onRewrite,
                       onFloatingCard: onFloatingCard, onError: onError,
                       skill: skill)
        }
    }
}
```

### 5. TemplateEngine（模板变量替换）

```swift
struct TemplateEngine {
    /// 替换 {{config.xxx}} 占位符
    /// 未定义的占位符保留原文
    func resolve(template: String, config: [String: String]) -> String
}
```

### 6. ToolRegistry（工具注册表）

```swift
/// Tool 执行上下文
struct ToolContext {
    let text: String
    let skill: SkillModel
    let speechText: String
    let behavior: ContextBehavior
}

/// Tool 处理器类型
typealias ToolHandler = (ToolContext) -> Void

class ToolRegistry {
    private var handlers: [String: ToolHandler] = [:]
    
    func register(name: String, handler: @escaping ToolHandler)
    func execute(name: String, context: ToolContext) throws
    
    /// 注册内置 Tool
    func registerBuiltins(
        insertText: @escaping (String) -> Void,
        saveMemo: @escaping (String) -> Void,
        showFloatingCard: @escaping (String, String, SkillModel) -> Void,
        copyToClipboard: @escaping (String) -> Void
    )
}
```

### 7. GhostypeAPIClient 扩展

```swift
extension GhostypeAPIClient {
    /// 通用 Skill 执行
    /// 调用 POST /api/v1/skill/execute
    func executeSkill(
        systemPrompt: String,
        message: String,
        context: ContextBehavior,
        endpoint: String? = nil  // 默认 /api/v1/skill/execute
    ) async throws -> String
}
```

### 8. SkillManager（重构）

核心变化：合并 SkillFileParser 的语义内容和 SkillMetadataStore 的 UI 元数据。

```swift
@Observable
class SkillManager {
    static let shared = SkillManager()
    
    private(set) var skills: [SkillModel] = []
    private(set) var keyBindings: [UInt16: String] = [:]
    
    let storageDirectory: URL
    let metadataStore: SkillMetadataStore
    
    func loadAllSkills()    // 解析 SKILL.md + 合并元数据
    func createSkill(_ skill: SkillModel) throws
    func updateSkill(_ skill: SkillModel) throws
    func deleteSkill(id: String) throws
    
    // 快捷键相关方法保持不变
    func skillForKeyCode(_ keyCode: UInt16) -> SkillModel?
    func skillForModifiers(_ modifiers: NSEvent.ModifierFlags) -> SkillModel?
    func rebindKey(skillId: String, newBinding: ModifierKeyBinding?) throws
    func updateColor(skillId: String, colorHex: String) throws
    func updateIcon(skillId: String, icon: String) throws
}
```

### 9. SkillMigrationService（重构）

处理旧格式 SKILL.md → 新格式的迁移。

```swift
struct SkillMigrationService {
    /// 检测并迁移旧格式 SKILL.md
    /// 1. 解析旧格式，提取 legacyFields
    /// 2. UI 元数据写入 SkillMetadataStore
    /// 3. 语义字段映射（skillType → allowed_tools/config）
    /// 4. 重写 SKILL.md 为新格式
    static func migrateIfNeeded(
        storageDirectory: URL,
        metadataStore: SkillMetadataStore
    )
    
    /// 将旧 skillType 映射到新的 allowed_tools + config
    static func mapSkillType(
        _ skillType: String,
        behaviorConfig: [String: String]
    ) -> (allowedTools: [String], config: [String: String])
}
```

## 数据模型

### 新 SKILL.md 格式

最简格式（只需 name + description + body）：

```markdown
---
name: "代码审查专家"
description: "审查代码并给出改进建议"
---

你是一个代码审查专家。用户会给你一段代码，请指出问题并给出改进建议。
输出格式：先列出问题，再给出修改后的代码。
```

完整格式（含可选字段）：

```markdown
---
name: "翻译"
description: "语音翻译"
allowed_tools:
  - insert_text
config:
  source_language: "中文"
  target_language: "英文"
---

你是一个专业的翻译员。请将用户的文本从{{config.source_language}}翻译成{{config.target_language}}。
只输出翻译结果，不要有任何解释。
```

### 内置 Skill 定义（新格式）

**builtin-memo/SKILL.md**：
```markdown
---
name: "随心记"
description: "将语音直接记录为笔记"
allowed_tools:
  - save_memo
---

将用户的语音输入直接保存到笔记本。
```

**builtin-ghost-command/SKILL.md**：
```markdown
---
name: "Ghost Command"
description: "说出指令，AI 直接生成内容"
---

你是一个万能助手。用户会用语音告诉你一个任务，请直接完成任务并输出结果。不要解释你在做什么，直接给出结果。
```

**builtin-ghost-twin/SKILL.md**：
```markdown
---
name: "Ghost Twin"
description: "以你的口吻和语言习惯回复"
config:
  api_endpoint: "/api/v1/ghost-twin/chat"
---

使用用户的人格档案，以用户的口吻和语言习惯生成回复。
```

**builtin-translate/SKILL.md**：
```markdown
---
name: "翻译"
description: "语音翻译"
config:
  source_language: "中文"
  target_language: "英文"
---

你是一个专业的翻译员。请将用户的文本从{{config.source_language}}翻译成{{config.target_language}}。
如果源语言和目标语言相同方向无法确定，请自动检测并翻译。
只输出翻译结果，不要有任何解释。
```

### SkillMetadata 存储格式

存储在 `~/Library/Application Support/GHOSTYPE/skill_metadata.json`：

```json
{
  "builtin-memo": {
    "icon": "📝",
    "colorHex": "#FF9500",
    "modifierKey": {
      "keyCode": 56,
      "isSystemModifier": true,
      "displayName": "⇧"
    },
    "isBuiltin": true
  },
  "builtin-ghost-command": {
    "icon": "👻",
    "colorHex": "#007AFF",
    "modifierKey": {
      "keyCode": 59,
      "isSystemModifier": true,
      "displayName": "⌃"
    },
    "isBuiltin": true
  },
  "2CAC893D-E426-4617-A5FA-61321E2A5ACB": {
    "icon": "✨",
    "colorHex": "#5AC8FA",
    "modifierKey": {
      "keyCode": 7,
      "isSystemModifier": false,
      "displayName": "X"
    },
    "isBuiltin": false
  }
}
```

### API 请求模型

新增 `SkillExecuteRequest`，用于 `POST /api/v1/skill/execute`：

```swift
struct SkillExecuteRequest: Codable {
    let system_prompt: String
    let message: String
    let context: ContextInfo
    
    struct ContextInfo: Codable {
        let type: String            // "direct_output" | "rewrite" | "explain" | "no_input"
        let selected_text: String?
    }
}
```

响应复用现有的 `GhostypeResponse`（text + usage）。

### 旧格式 → 新格式映射表

| 旧 skillType | 新 allowed_tools | 新 config | 说明 |
|-------------|-----------------|-----------|------|
| polish | `["insert_text"]` | — | 润色保持走 `/api/v1/llm/chat` |
| memo | `["save_memo"]` | — | 不调 API |
| translate | `["insert_text"]` | `source_language`, `target_language` | 从 `behavior_config.translate_language` 映射 |
| ghostCommand | `["insert_text"]` | — | prompt 已在 body 中 |
| ghostTwin | `["insert_text"]` | `api_endpoint: /api/v1/ghost-twin/chat` | 独立端点 |
| custom | `["insert_text"]` | — | prompt 已在 body 中 |


## 正确性属性

*正确性属性是一种在系统所有有效执行中都应成立的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性是人类可读规范和机器可验证正确性保证之间的桥梁。*

### Property 1: SkillFileParser 解析-序列化 round-trip

*For any* 有效的 ParseResult（包含 name、description、systemPrompt、allowedTools、config），将其序列化为 SKILL.md 字符串再解析回来，应产生与原始 ParseResult 等价的结果。

**Validates: Requirements 1.2, 1.3, 1.5, 1.6, 1.8**

### Property 2: SkillFileParser 必填字段校验

*For any* SKILL.md 内容，如果 YAML frontmatter 中缺少 `name` 或 `description` 字段，解析应返回错误；如果两者都存在，解析应成功。

**Validates: Requirements 1.1**

### Property 3: SkillFileParser 序列化不包含 UI 元数据

*For any* 有效的 ParseResult，序列化输出的字符串不应包含 `icon`、`color_hex`、`modifier_key_code`、`modifier_key_is_system`、`modifier_key_display` 等 UI 元数据字段。

**Validates: Requirements 1.4**

### Property 4: SkillMetadataStore 存取 round-trip

*For any* skill ID 和任意 SkillMetadata（icon、colorHex、modifierKey、isBuiltin），存储后再读取应返回与原始值等价的 SkillMetadata。

**Validates: Requirements 2.1, 2.2**

### Property 5: SkillMetadataStore 未知 Skill 返回默认值

*For any* 不在 store 中的 skill ID，`get()` 应返回默认元数据（默认 emoji "✨"、默认颜色 "#5AC8FA"、无快捷键、isBuiltin = false）。

**Validates: Requirements 2.4**

### Property 6: TemplateEngine 变量替换

*For any* 模板字符串和 config 字典，所有 `{{config.xxx}}` 中 xxx 存在于 config 中的占位符应被替换为对应值，xxx 不存在于 config 中的占位符应保留原文不变。

**Validates: Requirements 8.1, 8.2, 6.2**

### Property 7: SkillExecutor 结果分发逻辑

*For any* Skill 和 ContextBehavior 组合，当 API 返回成功结果时：directOutput 场景调用 onDirectOutput，rewrite 场景调用 onRewrite，explain/noInput 场景调用 onFloatingCard。

**Validates: Requirements 3.3**

### Property 8: SkillExecutor 错误回退

*For any* Skill 和 API 错误，directOutput/rewrite 场景应回退插入原始语音文本，explain/noInput 场景应调用 onError 回调。

**Validates: Requirements 3.5**

### Property 9: ToolRegistry 未注册工具返回错误

*For any* 未注册的工具名称字符串，`execute()` 应抛出描述性错误。

**Validates: Requirements 4.3**

### Property 10: 迁移服务 skillType 映射正确性

*For any* 旧格式 SkillType（polish/memo/translate/ghostCommand/ghostTwin/custom），`mapSkillType()` 应返回正确的 `allowedTools` 和 `config` 映射。

**Validates: Requirements 7.1, 7.2**

### Property 11: 迁移服务 UI 元数据提取

*For any* 包含旧格式 UI 元数据（icon、color_hex、modifier_key_*）的 SKILL.md，迁移后 SkillMetadataStore 应包含这些值，且重写后的 SKILL.md 不应包含 UI 元数据字段。

**Validates: Requirements 7.6, 7.7**

### Property 12: 迁移服务幂等性

*For any* SKILL.md 文件（无论旧格式还是新格式），执行迁移两次应产生与执行一次相同的结果（SKILL.md 内容和 SkillMetadataStore 内容均相同）。

**Validates: Requirements 7.8**

### Property 13: API 请求构建正确性

*For any* Skill（含 system_prompt 和 config），`executeSkill()` 构建的请求体应包含正确的 system_prompt、message 和 context 字段；当 config 中包含 `api_endpoint` 时，请求应发送到指定端点。

**Validates: Requirements 9.2, 9.4**

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| SKILL.md 缺少必填字段 | SkillFileParser 抛出 `ParseError.missingRequiredField`，SkillManager 跳过该 Skill 并记录日志 |
| SKILL.md YAML 格式错误 | SkillFileParser 抛出 `ParseError.missingFrontmatter`，SkillManager 跳过并记录日志 |
| 未注册的 Tool 名称 | ToolRegistry 抛出 `ToolError.unknownTool(name)`，SkillExecutor 回退到 `insert_text` |
| API 调用超时 | GhostypeAPIClient 抛出 `GhostypeError.timeout`，SkillExecutor 按 ContextBehavior 回退 |
| API 返回 401 | GhostypeAPIClient 抛出 `GhostypeError.unauthorized`，清除 JWT |
| API 返回 429 | GhostypeAPIClient 抛出 `GhostypeError.quotaExceeded`，显示额度超限提示 |
| 元数据文件损坏 | SkillMetadataStore 重置为空字典，所有 Skill 使用默认元数据 |
| 迁移过程中文件写入失败 | 记录日志，保留旧格式文件，下次启动重试 |
| 模板变量引用不存在的 config key | 保留占位符原文，不报错 |

## 测试策略

### 测试框架

- 单元测试和属性测试：Swift Testing（`import Testing`）
- 属性测试库：[SwiftCheck](https://github.com/typelift/SwiftCheck) 或手动生成随机输入
- 由于 SwiftCheck 可能不兼容最新 Swift 版本，备选方案为使用 Swift Testing 的参数化测试 + 自定义随机生成器

### 属性测试配置

- 每个属性测试最少运行 100 次迭代
- 每个属性测试必须用注释引用设计文档中的属性编号
- 注释格式：`// Feature: skill-system-redesign, Property N: {property_text}`

### 双轨测试策略

**属性测试**（验证通用正确性）：
- SkillFileParser round-trip（Property 1）
- SkillFileParser 必填字段校验（Property 2）
- SkillFileParser 无 UI 元数据输出（Property 3）
- SkillMetadataStore round-trip（Property 4）
- SkillMetadataStore 默认值（Property 5）
- TemplateEngine 变量替换（Property 6）
- SkillExecutor 分发逻辑（Property 7）
- SkillExecutor 错误回退（Property 8）
- ToolRegistry 未注册工具错误（Property 9）
- 迁移 skillType 映射（Property 10）
- 迁移 UI 元数据提取（Property 11）
- 迁移幂等性（Property 12）
- API 请求构建（Property 13）

**单元测试**（验证具体示例和边界情况）：
- 内置 Skill 的 SKILL.md 解析（具体文件内容）
- 旧格式 translate 语言对映射的具体值
- save_memo Skill 不调用 API 的行为
- Ghost Twin 使用自定义端点的行为
- 空 system_prompt 的处理
- 空 config 的处理
- ToolRegistry 内置 Tool 注册验证
