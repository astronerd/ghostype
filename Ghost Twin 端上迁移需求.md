# Ghost Twin 校准系统 — 端上迁移需求

> 将 Ghost Twin 校准系统从服务端迁移到客户端（macOS），服务端仅保留 LLM 代理角色。

---

## 背景

当前 Ghost Twin 校准系统的全部逻辑（出题、分析答案、更新人格档案）都在服务端实现，人格档案存储在 Supabase `ghost_twin_profiles` 表中。

新的架构决策：**人格档案是用户的私有数据，应该存储在端上**。服务端只作为 LLM 代理（`/api/v1/skill/execute`），端上自己构建 prompt、解析 LLM 返回、管理档案。未来可能做云端同步，但主体在端上。

---

## 架构变更

### 旧架构（服务端驱动）

```
端上                              服务端
────                              ────
GET /ghost-twin/status      →     查 Supabase → 返回等级/标签
GET /ghost-twin/challenge   →     选题型 → 构建 prompt → 调 Gemini → 存 DB → 返回题目
POST /ghost-twin/challenge/answer → 调 Gemini 分析 → 更新档案 → 返回结果
```

### 新架构（端上驱动）

```
端上                                          服务端
────                                          ────
1. 本地管理人格档案（CoreData）
2. 本地选择挑战类型
3. 本地构建「出题 prompt」
4. POST /api/v1/skill/execute  →              纯透传 Gemini → 返回 JSON
5. 本地解析 LLM 返回的题目 JSON
6. 展示题目，用户选择
7. 本地构建「分析答案 prompt」
8. POST /api/v1/skill/execute  →              纯透传 Gemini → 返回 JSON
9. 本地解析 profile_diff，合并到档案
10. 本地计算 XP、等级、是否升级
11. 如果升级 → 构建「总结 prompt」
12. POST /api/v1/skill/execute →              纯透传 Gemini → 返回 JSON
13. 本地解析总结结果，更新档案
```

---

## 需要迁移到端上的功能模块

### 1. 人格档案数据模型 + 持久化

原服务端：`ghostype-web/src/lib/ghost-twin/types.ts`

端上需要实现：

```swift
// MARK: - 人格档案三层结构

struct GhostTwinProfile: Codable {
    var version: Int                    // 档案版本号，每次更新 +1
    var level: Int                      // 当前等级 1~10
    var totalXP: Int                    // 总经验值
    var personalityTags: [String]       // 人格特征标签
    var formLayer: FormLayer            // 「形」层 — 语言 DNA
    var spiritLayer: SpiritLayer        // 「神」层 — 价值观
    var methodLayer: MethodLayer        // 「法」层 — 情境规则
    var summary: String                 // 阶段性总结文本
    var updatedAt: Date
    var createdAt: Date
}

struct FormLayer: Codable {
    var verbalHabits: [String]          // 口癖列表
    var sentencePatterns: [String]      // 常用句式
    var punctuationStyle: String        // 标点习惯
    var avgSentenceLength: String       // short / medium / long
}

struct SpiritLayer: Codable {
    var coreValues: [String]            // 核心价值观
    var decisionTendency: String        // 决策倾向
    var socialStrategy: String          // 社交策略
}

struct MethodLayer: Codable {
    var contextRules: [ContextRule]     // 情境规则
    var audienceAdaptations: [AudienceAdaptation]  // 对象适配
}

struct ContextRule: Codable {
    var context: String                 // 情境描述
    var style: String                   // 该情境下的语体风格
}

struct AudienceAdaptation: Codable {
    var audience: String                // 对象类型
    var toneShift: String               // 语气调整
}
```

存储方式：CoreData 或 JSON 文件存本地。初始档案：

```swift
static let initial = GhostTwinProfile(
    version: 0, level: 1, totalXP: 0,
    personalityTags: [],
    formLayer: FormLayer(verbalHabits: [], sentencePatterns: [], punctuationStyle: "", avgSentenceLength: "medium"),
    spiritLayer: SpiritLayer(coreValues: [], decisionTendency: "", socialStrategy: ""),
    methodLayer: MethodLayer(contextRules: [], audienceAdaptations: []),
    summary: "",
    updatedAt: Date(), createdAt: Date()
)
```

### 2. XP 与等级计算

原服务端：`ghostype-web/src/lib/ghost-twin/xp.ts`

端上需要实现（纯函数）：

```swift
enum GhostTwinXP {
    static let xpPerLevel = 10_000
    static let maxLevel = 10
    
    /// XP 奖励映射
    static let xpRewards: [ChallengeType: Int] = [
        .dilemma: 500,
        .reverseTuring: 300,
        .prediction: 200
    ]
    
    /// 根据总 XP 计算等级 (1~10)
    static func calculateLevel(totalXP: Int) -> Int {
        min(totalXP / xpPerLevel + 1, maxLevel)
    }
    
    /// 当前等级内的 XP
    static func currentLevelXP(totalXP: Int) -> Int {
        let level = calculateLevel(totalXP: totalXP)
        if level >= maxLevel { return totalXP - (maxLevel - 1) * xpPerLevel }
        return totalXP % xpPerLevel
    }
    
    /// 检查是否升级
    static func checkLevelUp(oldXP: Int, newXP: Int) -> (leveledUp: Bool, oldLevel: Int, newLevel: Int) {
        let old = calculateLevel(totalXP: oldXP)
        let new = calculateLevel(totalXP: newXP)
        return (new > old, old, new)
    }
}
```

### 3. 挑战类型选择

原服务端：`ghostype-web/src/lib/ghost-twin/challenge-type.ts`

端上需要实现：

```swift
enum ChallengeType: String, Codable {
    case dilemma            // 灵魂拷问 → 校准「神」层
    case reverseTuring = "reverse_turing"  // 找鬼游戏 → 校准「形」层
    case prediction         // 预判赌局 → 校准「法」层
}

enum TargetLayer: String, Codable {
    case form, spirit, method
}

/// 根据等级选择挑战类型（可加随机权重）
func selectChallengeType(level: Int) -> (type: ChallengeType, targetLayer: TargetLayer) {
    if level >= 7 { return (.prediction, .method) }
    if level >= 4 { return (.dilemma, .spirit) }
    return (.reverseTuring, .form)
}
```

### 4. 校准挑战 Prompt 构建

原服务端：`ghostype-web/src/lib/ghost-twin/prompts.ts` → `buildChallengePrompt()`

端上需要实现：构建 system_prompt + user message，然后调 `/api/v1/skill/execute`。

Prompt 模板（直接从服务端搬过来）：

```
你是 GHOSTYPE 的校准系统，负责生成用于训练用户数字分身（Ghost Twin）的情境问答题。

## 当前用户信息
- 等级: Lv.{level}
- 人格档案版本: {version}
- 已捕捉特征: {tags}

## 任务
生成一道「{challengeType}」类型的校准挑战。

### 挑战类型说明
（同现有 prompt，三种类型的详细说明）

## 输出格式
严格按以下 JSON 格式输出，不要添加任何额外文字：
{
  "scenario": "场景描述文本",
  "options": ["选项A", "选项B", "选项C"]
}
```

User message 拼入最近挑战记录用于去重。

调用方式：

```swift
let result = try await api.executeSkill(
    systemPrompt: challengeSystemPrompt,
    message: challengeUserMessage,
    contextType: "no_input"
)
// 解析 result 为 { scenario: String, options: [String] }
```

### 5. 人格档案增量更新 Prompt 构建

原服务端：`prompts.ts` → `buildProfileUpdatePrompt()`

用户选择答案后，端上构建分析 prompt，调 skill/execute，拿到 profile_diff：

```
你是 GHOSTYPE 的人格档案分析师，负责根据用户的校准回答，对其数字分身的人格档案进行增量更新。

## 当前人格档案
{profile JSON}

## 本次挑战信息
- 类型: {type}
- 场景: {scenario}
- 选项: {options}
- 目标层级: {targetLayer}

## 用户选择
- 选项索引: {index}
- 选项内容: {text}

## 校准历史
{recent history}

## 输出格式
{
  "profile_diff": {
    "layer": "form|spirit|method",
    "changes": { ... },
    "new_tags": [...]
  },
  "ghost_response": "Ghost 的俏皮反馈语",
  "analysis": "分析说明"
}
```

端上拿到 `profile_diff` 后自己合并到本地档案：
- 合并 `changes` 到对应 layer
- 合并 `new_tags` 到 `personalityTags`（去重）
- `version += 1`
- 累加 XP，检查升级

### 6. 人格档案阶段性总结 Prompt 构建

原服务端：`prompts.ts` → `buildProfileSummaryPrompt()`

升级时触发，端上构建总结 prompt，调 skill/execute：

```
你是 GHOSTYPE 的人格档案总结师，负责在用户升级时对人格档案进行阶段性总结和精炼。

## 当前人格档案
{profile JSON}

## 升级信息
- 完成等级: Lv.{old} → Lv.{new}

## 本等级所有校准记录
{calibration history}

## 输出格式
{
  "form_layer": { ... },
  "spirit_layer": { ... },
  "method_layer": { ... },
  "summary": "人格画像描述（100~200 字）",
  "refined_tags": [...]
}
```

端上拿到结果后整体替换档案的三层 + summary + tags。

### 7. LLM JSON 解析工具

原服务端：`prompts.ts` → `parseLLMJson()`

端上需要实现：

```swift
/// 解析 LLM 返回的 JSON（自动 strip markdown 代码块）
func parseLLMJson<T: Decodable>(_ raw: String) throws -> T {
    var cleaned = raw
    // Strip ```json ... ```
    if cleaned.hasPrefix("```") {
        cleaned = cleaned.replacingOccurrences(of: #"^```(?:json)?\s*\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\n?```\s*$"#, with: "", options: .regularExpression)
    }
    let data = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)!
    return try JSONDecoder().decode(T.self, from: data)
}
```

### 8. 校准历史本地存储

原服务端：Supabase `calibration_challenges` + `calibration_answers` 表

端上需要存储：
- 最近 N 次挑战记录（用于 prompt 去重）
- 最近 N 次回答记录（用于分析 prompt 的校准历史）
- 每日已完成挑战数（用于每日 3 次限制）

```swift
struct CalibrationRecord: Codable, Identifiable {
    let id: UUID
    let type: ChallengeType
    let scenario: String
    let options: [String]
    let selectedOption: Int
    let xpEarned: Int
    let ghostResponse: String
    let profileDiff: ProfileDiff?
    let createdAt: Date
}

struct ProfileDiff: Codable {
    let layer: TargetLayer
    let changes: [String: String]   // 简化为 String 值
    let newTags: [String]
}
```

存储方式：CoreData 或 JSON 文件。只需保留最近 20 条，超出的可以丢弃。

### 9. 每日挑战限制

原服务端：`profile.ts` → `getChallengesRemainingToday()`

端上实现：

```swift
/// 每日 3 次限制，UTC 0:00 重置
func challengesRemainingToday(records: [CalibrationRecord]) -> Int {
    let calendar = Calendar(identifier: .gregorian)
    let todayStart = calendar.startOfDay(for: Date())  // 用 UTC
    let todayCount = records.filter { $0.createdAt >= todayStart }.count
    return max(3 - todayCount, 0)
}
```

---

## 端上完整校准流程

```
1. 用户进入孵化室页面
2. 读取本地 GhostTwinProfile（没有则创建初始档案）
3. 显示等级、XP、标签、Ghost 透明度
4. 检查今日剩余挑战次数

── 用户点击「开始校准」──

5. selectChallengeType(level) → 确定挑战类型
6. 构建出题 prompt（system_prompt + user_message）
7. 调 POST /api/v1/skill/execute
8. 解析返回的 JSON → { scenario, options }
9. 展示热敏纸条 UI

── 用户选择选项 ──

10. 构建分析 prompt（含档案、挑战、选择、历史）
11. 调 POST /api/v1/skill/execute
12. 解析返回的 JSON → { profile_diff, ghost_response }
13. 合并 profile_diff 到本地档案
14. 累加 XP，检查升级
15. 如果升级 → 构建总结 prompt → 调 skill/execute → 更新档案
16. 保存校准记录到本地
17. 展示 ghost_response + XP 动画
18. 更新 Ghost 透明度
```

---

## 服务端变更

### 保留
- `POST /api/v1/skill/execute` — 不变，端上所有 Ghost Twin LLM 调用都走这个

### 待废弃（端上迁移完成后删除）
- `GET /api/v1/ghost-twin/status`
- `GET /api/v1/ghost-twin/challenge`
- `POST /api/v1/ghost-twin/challenge/answer`
- `src/lib/ghost-twin/` 整个目录
- Supabase 表：`ghost_twin_profiles`、`calibration_challenges`、`calibration_answers`

### API_CLIENT_GUIDE.md 更新
- 移除 Ghost Twin 相关的 3 个端点文档
- 在 skill/execute 章节补充 Ghost Twin 校准的调用示例

---

## 端上数据存储汇总

| 数据 | 存储位置 | 说明 |
|------|----------|------|
| GhostTwinProfile | CoreData / JSON 文件 | 完整人格档案，端上唯一真相源 |
| CalibrationRecord[] | CoreData / JSON 文件 | 最近 20 条校准记录 |
| 今日挑战计数 | 从 CalibrationRecord 计算 | UTC 0:00 重置 |
| Ghost Logo 位图 | Bundle 资源 | 160×120 黑白 PNG |
| activationOrder | UserDefaults | 点阵洗牌序列 |

---

## 迁移顺序建议

1. 先实现端上数据模型 + 持久化（GhostTwinProfile、CalibrationRecord）
2. 实现 XP/等级计算纯函数
3. 实现挑战类型选择
4. 实现 3 个 Prompt 构建函数
5. 实现 LLM JSON 解析
6. 串联完整校准流程（出题 → 答题 → 更新档案）
7. 接入孵化室 UI（IncubatorViewModel 改为调本地逻辑 + skill/execute）
8. 测试通过后，删除服务端 Ghost Twin 代码
