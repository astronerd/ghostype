# Ghost Twin 系统重构 — 技术设计

## 概述

本文档描述五个模块的技术实现方案。模块 A 是基础设施改造，B/C/D/E 在其之上实现。

---

## 模块 A：Skill Context 声明式架构

### A1. SKILL.md frontmatter 新增 `context_requires`

在 YAML frontmatter 中新增可选字段：

```yaml
---
name: "Ghost Calibration"
description: "..."
allowed_tools:
  - provide_text
context_requires:
  - ghost_profile
  - user_language
  - calibration_records
config: {}
is_internal: true
---
```

### A2. SkillFileParser 改动

`context_requires` 是一个字符串数组，与 `allowed_tools` 解析方式相同。

```swift
// SkillFileParser.swift — parseYAMLAdvanced
// 在 knownArrayFields 中添加：
let knownArrayFields: Set<String> = ["allowed_tools", "context_requires"]
```

`ParseResult` 新增字段：

```swift
struct ParseResult: Equatable {
    // ... 现有字段 ...
    let contextRequires: [String]   // 新增
}
```

解析时：
```swift
let contextRequires = parsed.arrayFields["context_requires"] ?? []
```

`print()` 序列化时，如果 `contextRequires` 非空则输出。

### A3. SkillModel 新增字段

```swift
struct SkillModel {
    // ... 现有字段 ...
    var contextRequires: [String]   // 新增，默认 []
}
```

SkillManager.loadAllSkills() 中传入：
```swift
let skill = SkillModel(
    // ...
    contextRequires: parseResult.contextRequires,
    // ...
)
```

### A4. Context Provider 注册表

在 SkillExecutor 中新增 provider 注册表，替代现有的 hardcode 逻辑：

```swift
class SkillExecutor {
    /// Context provider 注册表：key → 数据提供闭包
    private var contextProviders: [String: () -> String] = [:]

    init(...) {
        // ... 现有初始化 ...
        registerDefaultProviders()
    }

    private func registerDefaultProviders() {
        // ghost_profile: 人格档案全文 + 等级
        contextProviders["ghost_profile"] = {
            let profile = GhostTwinProfileStore().load()
            guard !profile.profileText.isEmpty else { return "" }
            return """
            ## 用户人格档案
            - 等级: Lv.\(profile.level)
            - 档案全文:
            \(profile.profileText)
            """
        }

        // user_language: 用户当前语言设置
        contextProviders["user_language"] = {
            let lang = LocalizationManager.shared.currentLanguage
            return lang.displayName  // "简体中文" 或 "English"
        }

        // calibration_records: 校准记录（未消费的）
        contextProviders["calibration_records"] = {
            let records = CalibrationRecordStore().unconsumed()
            guard !records.isEmpty else { return "无校准记录" }
            return records.map { record in
                var line = "- \(record.scenario)"
                if let custom = record.customAnswer, !custom.isEmpty {
                    line += " → 自定义: \(custom)"
                } else {
                    line += " → 选项\(record.selectedOption)"
                }
                if let analysis = record.analysis, !analysis.isEmpty {
                    line += "\n  分析: \(analysis)"
                }
                return line
            }.joined(separator: "\n")
        }

        // asr_corpus: 未消费的 ASR 语料
        contextProviders["asr_corpus"] = {
            let corpus = ASRCorpusStore().unconsumed()
            guard !corpus.isEmpty else { return "无新增语料" }
            return corpus.map { "- \($0.text)" }.joined(separator: "\n")
        }
    }
}
```

### A5. execute() 方法改造

替换现有的 hardcode ghost_profile 逻辑：

```swift
// 现有代码（删除）：
// var runtimeContext: [String: String] = [:]
// let profile = GhostTwinProfileStore().load()
// if !profile.profileText.isEmpty { ... }
// runtimeContext["ghost_profile"] = personalityContext

// 新代码：
var runtimeContext: [String: String] = [:]
for key in skill.contextRequires {
    if let provider = contextProviders[key] {
        runtimeContext[key] = provider()
    } else {
        FileLogger.log("[SkillExecutor] ⚠️ Unknown context key: \(key)")
    }
}
```

### A6. 向后兼容

- `contextRequires` 为空的 skill → 不注入任何 context（与改造前行为一致，因为只有 ghost_profile 被 hardcode，而使用它的 skill 都会声明）
- 现有内置 skill 的 SKILL.md 需要补上 `context_requires` 声明

### A7. 内置 skill 需要更新的 SKILL.md

| Skill | 需要声明的 context |
|-------|-------------------|
| internal-ghost-calibration | `[ghost_profile, user_language]` |
| internal-ghost-profiling | `[ghost_profile, user_language, asr_corpus, calibration_records]` |
| internal-ghost-initial-profiling（新建） | `[user_language, asr_corpus]` |
| builtin-ghost-twin | `[ghost_profile, user_language]` |
| builtin-memo | `[user_language]` |
| builtin-ghost-command | `[user_language]` |
| builtin-translate | `[user_language]` |
| builtin-prompt-generator | `[user_language]` |

---

## 模块 B：冷启动改造

### B1. GhostTwinXP 计算调整

```swift
enum GhostTwinXP {
    static let xpForLevel0 = 2_000      // 新增：Lv.0 升级阈值
    static let xpPerLevel = 10_000      // Lv.1+ 不变
    static let maxLevel = 10

    /// 根据总 XP 计算等级 (0~10)
    static func calculateLevel(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return 0 }
        let remaining = totalXP - xpForLevel0
        return min(remaining / xpPerLevel + 1, maxLevel)
    }

    /// 当前等级内的 XP（每级从 0 开始）
    static func currentLevelXP(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return totalXP }
        let level = calculateLevel(totalXP: totalXP)
        if level >= maxLevel {
            return totalXP - xpForLevel0 - (maxLevel - 1) * xpPerLevel
        }
        return (totalXP - xpForLevel0) % xpPerLevel
    }

    /// 当前等级的升级所需 XP
    static func xpNeededForCurrentLevel(level: Int) -> Int {
        level == 0 ? xpForLevel0 : xpPerLevel
    }
}
```

### B2. 老用户兼容

现有用户 totalXP 的最小值是 0（新用户）。已有数据的用户 totalXP ≥ 0：
- totalXP < 2000 → Lv.0（理论上不存在，因为老用户至少是 Lv.1 = 10000 XP）
- totalXP ≥ 2000 → 正常计算

但有一个边界情况：老版本的 Lv.1 用户 totalXP 可能在 0~9999 之间。升级后：
- totalXP 0~1999 → 会被降到 Lv.0（不符合预期）
- totalXP 2000~9999 → Lv.1 不变（但 currentLevelXP 会变）

解决方案：在 `loadLocalData()` 中加迁移逻辑：
```swift
// 老用户迁移：如果 profile.level >= 1 但 totalXP < 2000，补齐到 2000
if profile.level >= 1 && profile.totalXP < GhostTwinXP.xpForLevel0 {
    profile.totalXP = GhostTwinXP.xpForLevel0
    try? profileStore.save(profile)
}
```

### B3. 简化版首次构筑 Skill

新建 `default_skills/internal-ghost-initial-profiling/SKILL.md`：

```yaml
---
name: "Ghost Initial Profiling"
description: "Ghost Twin 首次激活构筑，基于有限语料搭建人格框架"
allowed_tools:
  - provide_text
context_requires:
  - user_language
  - asr_corpus
config: {}
is_internal: true
---
```

Prompt 要点：
- 明确告知 LLM 数据量有限（约 2000 字语料），不要过度推断
- 搭建「形/神/法」三层框架，每层给出初步观察
- 对信息不足的维度标记 `[待验证]`
- 输出格式与正常 profiling 一致（纯文本报告 + 末尾 JSON summary）
- 语言跟随 `{{context.user_language}}`

### B4. IncubatorViewModel 改动

Lv.0 → Lv.1 升级时调用 `internal-ghost-initial-profiling` 而非 `internal-ghost-profiling`：

```swift
private func triggerProfiling(atLevel level: Int) async {
    let skillId: String
    if level == 1 && profile.profileText.isEmpty {
        // 首次构筑（Lv.0 → Lv.1）
        skillId = SkillModel.internalGhostInitialProfilingId
    } else {
        skillId = SkillModel.internalGhostProfilingId
    }
    // ... 后续逻辑不变
}
```

### B5. UI 引导文案

Lv.0 时 IncubatorPage 显示引导文案（替代校准按钮区域）：

```swift
if viewModel.level == 0 {
    // 显示引导文案
    Text(L.Incubator.coldStartGuide)  // "说 2000 字即可激活你的 Ghost Twin"
}
```

### B6. SkillModel 新增 ID

```swift
extension SkillModel {
    static let internalGhostInitialProfilingId = "internal-ghost-initial-profiling"
}
```

SkillManager.builtinMetadata 中添加对应条目。

### B7. AnimationPhase 调整

Lv.0 使用 `.glitch` 阶段（与 Lv.1~3 相同），无需新增 phase。

---

## 模块 C：构筑上下文链路修复

### C1. previousReport 修复

`IncubatorViewModel.triggerProfiling()` 中：

```swift
// 现有代码（删除）：
// previousReport: nil

// 新代码：
let previousReport = profile.profileText.isEmpty ? nil : profile.profileText
```

### C2. CalibrationRecord 新增字段

```swift
struct CalibrationRecord: Codable, Identifiable, Equatable {
    // ... 现有字段 ...
    let analysis: String?           // 新增：LLM 分析推理过程
    var consumedAtLevel: Int?       // 新增：被哪个等级的构筑消费（nil = 未消费）
}
```

JSON 解码兼容：`analysis` 和 `consumedAtLevel` 都是 Optional，旧数据缺少这些字段时自动为 nil。但 `CalibrationRecord` 当前不使用 `init(from:)` 自定义解码，而是依赖 Codable 自动合成。Swift 的自动合成 Codable 对 Optional 字段在 JSON 中缺失时会自动赋 nil，所以无需额外处理。

### C3. CalibrationRecordStore 新增方法

```swift
extension CalibrationRecordStore {
    /// 返回未消费的校准记录
    func unconsumed() -> [CalibrationRecord] {
        loadAll().filter { $0.consumedAtLevel == nil }
    }

    /// 标记指定记录为已消费
    func markConsumed(ids: [UUID], atLevel: Int) {
        var records = loadAll()
        let idSet = Set(ids)
        for i in records.indices {
            if idSet.contains(records[i].id) {
                records[i].consumedAtLevel = atLevel
            }
        }
        try? save(records)
    }
}
```

注意：`save()` 当前是 private。需要改为 internal 或新增一个 internal 的 `saveAll()` 方法。

### C4. submitAnswer 保存 analysis

```swift
// IncubatorViewModel.submitAnswer() 中：
let record = CalibrationRecord(
    id: UUID(),
    scenario: challenge.scenario,
    options: challenge.options,
    selectedOption: customAnswer != nil ? -1 : (selectedOption ?? 0),
    customAnswer: customAnswer,
    xpEarned: xpReward,
    ghostResponse: analysis.ghostResponse,
    profileDiff: String(data: try JSONEncoder().encode(analysis.profileDiff), encoding: .utf8),
    analysis: analysis.analysis,           // 新增：保存分析过程
    consumedAtLevel: nil,                  // 新增：初始未消费
    createdAt: Date()
)
```

### C5. triggerProfiling 消费标记

```swift
private func triggerProfiling(atLevel level: Int) async {
    let unconsumedCorpus = corpusStore.unconsumed()
    let corpusIds = unconsumedCorpus.map { $0.id }
    let unconsumedRecords = recordStore.unconsumed()    // 改：只取未消费的
    let recordIds = unconsumedRecords.map { $0.id }

    // ... 调用 LLM ...

    // 构筑成功后：
    corpusStore.markConsumed(ids: corpusIds, atLevel: level)
    recordStore.markConsumed(ids: recordIds, atLevel: level)  // 新增
}
```

### C6. MessageBuilder.buildProfilingUserMessage 增强

校准记录部分改为传递完整信息：

```swift
// 现有代码：
// for record in records {
//     parts.append("- \(record.scenario) → 选项\(record.selectedOption)")
// }

// 新代码：
for record in records {
    parts.append("### 校准记录")
    parts.append("- 场景: \(record.scenario)")
    if let custom = record.customAnswer, !custom.isEmpty {
        parts.append("- 用户自定义答案: \(custom)")
    } else if record.selectedOption >= 0, record.selectedOption < record.options.count {
        parts.append("- 用户选择: \(record.options[record.selectedOption])")
    }
    if let analysis = record.analysis, !analysis.isEmpty {
        parts.append("- AI 分析: \(analysis)")
    }
    if let diff = record.profileDiff {
        parts.append("- 人格增量: \(diff)")
    }
    parts.append("")
}
```

### C7. IncubatorViewModel 中 profiling 调用的 user message

不再直接调用 `recordStore.loadAll()`，改为 `recordStore.unconsumed()`：

```swift
let records = recordStore.unconsumed()  // 改：只取未消费的
let userMessage = buildProfilingUserMessage(
    profile: profile,
    previousReport: profile.profileText.isEmpty ? nil : profile.profileText,  // 改：传实际值
    corpus: unconsumedCorpus,
    records: records
)
```

---

## 模块 D：校准分析输出改造 + 废弃 personalityTags

### D1. CalibrationAnalysisResponse 结构调整

```swift
// 现有结构（删除）：
// struct CalibrationAnalysisResponse: Decodable {
//     let profileDiff: ProfileDiff
//     let ghostResponse: String
//     let analysis: String
//     struct ProfileDiff: Codable {
//         let layer: String
//         let changes: [String: String]
//         let newTags: [String]
//     }
// }

// 新结构：
struct CalibrationAnalysisResponse: Decodable {
    let profileDiff: ProfileDiff
    let ghostResponse: String
    let analysis: String

    struct ProfileDiff: Codable {
        let layer: String
        let description: String     // 完整的人格增量描述文本
    }
}
```

### D2. SKILL.md 输出格式调整

`internal-ghost-calibration/SKILL.md` 分析模式的输出格式改为：

```json
{
  "profile_diff": {
    "layer": "form|spirit|method",
    "description": "完整的人格增量描述文本..."
  },
  "ghost_response": "Ghost 的回应",
  "analysis": "分析推理过程"
}
```

### D3. 废弃 personalityTags — 涉及文件清单

| 文件 | 改动 |
|------|------|
| `GhostTwinProfile.swift` | 删除 `personalityTags` 字段，新增 `summary: String`（从 profiling JSON 提取） |
| `IncubatorViewModel.swift` | 删除 `personalityTags` 属性、tag 合并逻辑、cache 读写 |
| `IncubatorPage.swift` | 状态芯片改为显示 `viewModel.summary` |
| `MessageBuilder.swift` | 删除标签拼接（`已捕捉标签: ...`） |
| `SkillExecutor.swift` | ghost_profile provider 不再拼接标签（模块 A 已处理） |
| `GhostTwinCacheKey` | 删除 `.personalityTags` case |
| 测试文件 | 同步更新 |

### D4. GhostTwinProfile 结构调整

```swift
struct GhostTwinProfile: Codable, Equatable {
    var version: Int
    var level: Int
    var totalXP: Int
    var summary: String         // 新增：一句话人格画像（替代 personalityTags）
    var profileText: String
    var createdAt: Date
    var updatedAt: Date

    static let initial = GhostTwinProfile(
        version: 0, level: 0,   // 注意：新用户从 Lv.0 开始
        totalXP: 0,
        summary: "",
        profileText: "",
        createdAt: Date(), updatedAt: Date()
    )
}
```

JSON 解码兼容：老数据有 `personalityTags` 但没有 `summary`。需要自定义 `init(from:)`：
```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    level = try container.decode(Int.self, forKey: .level)
    totalXP = try container.decode(Int.self, forKey: .totalXP)
    summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
    profileText = try container.decode(String.self, forKey: .profileText)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    // personalityTags 被忽略（老数据中存在但不再使用）
}
```

注意：这里需要 CodingKeys，但只是为了解码兼容，不是为了 snake_case 映射。JSONDecoder 仍然使用 `.convertFromSnakeCase`。

### D5. submitAnswer 简化

删除 tag 合并逻辑：

```swift
// 删除：
// let newTags = analysis.profileDiff.newTags
// var updatedTags = profile.personalityTags
// for tag in newTags { ... }
// profile.personalityTags = updatedTags

// 保留：只更新 XP 和 level
```

### D6. triggerProfiling 结果解析调整

profiling skill 输出的 JSON 摘要改为只有 `summary`：

```json
{"summary": "一句话人格画像描述"}
```

```swift
private struct ProfilingSummary: Decodable {
    let summary: String
    // 删除 refinedTags
}

// 解析后：
profile.summary = summary.summary
profile.profileText = result
```

### D7. IncubatorPage UI 调整

```swift
// 现有代码：
// statusChip(
//     label: L.Incubator.statusPersonality,
//     value: viewModel.personalityTags.isEmpty
//         ? L.Incubator.statusNone
//         : viewModel.personalityTags.prefix(2).joined(separator: ", ")
// )

// 新代码：
statusChip(
    label: L.Incubator.statusPersonality,
    value: viewModel.summary.isEmpty
        ? L.Incubator.statusNone
        : viewModel.summary
)
```

---

## 模块 E：多语言适配（LLM 输出）

### E1. user_language provider

已在模块 A4 中定义。返回 `LocalizationManager.shared.currentLanguage.displayName`（如 "简体中文"、"English"）。

### E2. SKILL.md 中的语言指令

所有需要多语言输出的 skill，在 system prompt 开头添加：

```markdown
用户语言为 {{context.user_language}}，请使用该语言输出所有内容（包括场景描述、选项、分析、回应等）。
```

### E3. 影响范围

Ghost Twin 相关 skill 的 prompt 中所有固定中文文案（如"请根据以上信息生成一道校准挑战题"）保留在 MessageBuilder 的 user message 中。这些是给 LLM 的指令，不是给用户看的，用中文没问题。LLM 的输出语言由 system prompt 中的 `{{context.user_language}}` 控制。

### E4. 非 Ghost Twin skill

内置 skill（润色、笔记、翻译、命令）的 SKILL.md 中同样添加 `context_requires: [user_language]` 和语言指令。这样英文用户使用润色功能时，LLM 会用英文回应。

---

## 数据迁移与兼容性总结

| 场景 | 处理方式 |
|------|---------|
| 老用户 profile 有 personalityTags 无 summary | 自定义 init(from:) 兼容，summary 默认空字符串 |
| 老用户 totalXP < 2000 且 level >= 1 | loadLocalData 迁移：补齐 totalXP 到 2000 |
| 老校准记录无 analysis/consumedAtLevel | Optional 字段，JSON 缺失时自动 nil |
| 老 SKILL.md 无 context_requires | 解析为空数组，不注入 context（向后兼容） |
| 新用户 | Lv.0 开始，2000 字激活，完整新流程 |

---

## 实现顺序

1. 模块 A：SkillFileParser → SkillModel → SkillExecutor provider 注册表
2. 模块 D：CalibrationAnalysisResponse 结构 → 废弃 tags → Profile 结构 → ViewModel → UI
3. 模块 C：CalibrationRecord 新字段 → Store 新方法 → previousReport → MessageBuilder → 消费标记
4. 模块 B：GhostTwinXP → 老用户迁移 → 新 skill → ViewModel 分支 → UI 引导
5. 模块 E：更新所有 SKILL.md 的 context_requires 和语言指令
