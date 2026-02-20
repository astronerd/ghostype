# Ghost Twin 系统重构 — 需求文档

## 背景

Ghost Twin 是 GHOSTYPE 的核心功能：通过用户的语音输入语料和校准答题，逐步构建一个数字分身的人格档案。当前实现存在冷启动体验差、上下文链路断裂、skill 系统 hardcode 等问题。本次重构旨在从架构层面解决这些问题。

## 问题清单（来源：ghosttwin流程问题.md）

| # | 问题 | 严重程度 |
|---|------|---------|
| ❶ | 新用户无引导，不知道怎么开始 | 高 |
| ❷ | 冷启动要说 10000 字才能触发首次构筑，之前是空壳 | 高 |
| ❸ | 构筑时 previousReport 传 nil，增量构筑失效 | 中 |
| ❹ | 出题 prompt 太简陋 | 已修复 |
| ❺ | 校准分析输出标签而非完整人格描述 | 高 |
| ❻ | 校准的 analysis 推理过程被丢弃 | 中 |
| ❼ | 标签和 profileText 割裂，不升级时档案不更新 | 中 |
| ❽ | 构筑时校准记录没有按等级过滤，重复消费 | 低 |
| ❾ | SkillExecutor hardcode ghost_profile，不符合声明式架构 | 中 |
| ❿ | 所有 LLM 输出固定中文，不跟随用户语言设置 | 中 |

---

## 模块 A：Skill Context 声明式架构

### 用户故事

作为 skill 开发者，我希望在 SKILL.md 的 frontmatter 中声明 skill 需要的上下文变量（如 `context_requires: [ghost_profile, user_language]`），SkillExecutor 根据声明自动从对应的 provider 加载数据注入 system prompt，而不是在代码里 hardcode。

### 验收标准

- AC-A1: SKILL.md frontmatter 支持 `context_requires` 字段，值为字符串数组
- AC-A2: SkillExecutor 维护一个 context provider 注册表（`[String: () -> String]`），每个 key 对应一个数据源
- AC-A3: 执行 skill 时，SkillExecutor 只加载该 skill 声明的 context 变量，不加载未声明的
- AC-A4: 去掉 SkillExecutor 中 hardcode 的 ghost_profile 逻辑，改为通过 provider 注册表提供
- AC-A5: system prompt 中的 `{{context.xxx}}` 模板变量由 TemplateEngine 替换（已有能力，无需改动）
- AC-A6: 未声明 `context_requires` 的 skill 不注入任何 context（向后兼容）

### 内置 context providers

| key | 数据源 | 说明 |
|-----|--------|------|
| `ghost_profile` | GhostTwinProfileStore | 人格档案全文 + 等级信息 |
| `user_language` | LocalizationManager.currentLanguage | 用户当前语言设置（如 "zh-CN"、"en"） |
| `calibration_records` | CalibrationRecordStore | 校准记录（按需过滤） |
| `asr_corpus` | ASRCorpusStore | 未消费的 ASR 语料 |

### 全局影响

`user_language` 是全局 context，不仅用于 Ghost Twin 相关 skill，也用于：
- 内置润色 skill（builtin-ghost-twin）：输出语言跟随用户设置
- 内置笔记 skill（builtin-memo）：笔记语言跟随用户设置
- 用户自建 skill：如果声明了 `context_requires: [user_language]`，同样生效
- Skill 生成器（builtin-prompt-generator）：生成的 skill 描述和 prompt 语言跟随用户设置

---

## 模块 B：冷启动改造

### 用户故事

作为新用户，我希望只需说 2000 字就能激活 Ghost Twin 的首次构筑，而不是等到 10000 字，这样我能更快看到 Ghost Twin 的价值。

### 验收标准

- AC-B1: 新增 Lv.0 阶段（0~1999 XP），2000 XP 升到 Lv.1
- AC-B2: Lv.1~Lv.10 的升级阈值保持不变（每级 10000 XP）
- AC-B3: Lv.0 期间，孵化室 UI 显示引导文案（如"说 2000 字即可激活你的 Ghost Twin"），通过 L.xxx 本地化
- AC-B4: Lv.0 → Lv.1 升级时触发简化版首次构筑（internal-ghost-initial-profiling skill）
- AC-B5: 简化版构筑的目标：基于有限语料搭建「形/神/法」框架，明确标出信息不足的空缺区域（如"[待验证] 冲突处理方式尚无足够数据"）
- AC-B6: 简化版构筑完成后，profileText 不为空，hasCompletedProfiling 为 true，校准按钮出现
- AC-B7: 已安装用户升级兼容：现有 Lv.1+ 用户不受影响，不会被降级到 Lv.0

### XP 计算调整

每个等级内的 XP 从 0 开始计数，升级后归零。Lv.0 的升级阈值为 2000，其余等级为 10000。

```
Lv.0:  currentLevelXP 0 → 2000 升级   (totalXP 0 ~ 1999)
Lv.1:  currentLevelXP 0 → 10000 升级  (totalXP 2000 ~ 11999)
Lv.2:  currentLevelXP 0 → 10000 升级  (totalXP 12000 ~ 21999)
...
Lv.9:  currentLevelXP 0 → 10000 升级  (totalXP 82000 ~ 91999)
Lv.10: 满级                           (totalXP 92000+)
```

GhostTwinXP 计算公式调整：
- `xpForLevel0 = 2000`
- `xpPerLevel = 10000`（Lv.1+ 不变）
- `calculateLevel(totalXP)`: totalXP < 2000 → Lv.0; 否则 min((totalXP - 2000) / 10000 + 1, 10)
- `currentLevelXP(totalXP)`: Lv.0 时返回 totalXP; 其余返回 (totalXP - 2000) % 10000
- `xpNeededForCurrentLevel(level)`: Lv.0 返回 2000，其余返回 10000

---

## 模块 C：构筑上下文链路修复

### 用户故事

作为 Ghost Twin 系统，我希望每次构筑都能看到上一轮的完整结果和本等级的所有校准数据，这样增量构筑才能真正生效。

### 验收标准

- AC-C1: triggerProfiling 传入 `previousReport = profile.profileText`（当前档案全文），不再传 nil
- AC-C2: CalibrationRecord 新增 `consumedAtLevel: Int?` 字段，记录该记录在哪个等级的构筑中被消费
- AC-C3: 构筑时只取 `consumedAtLevel == nil` 的校准记录（未消费的）
- AC-C4: 构筑完成后，将本次消费的校准记录标记 `consumedAtLevel = currentLevel`
- AC-C5: 校准完成后，完整保存 question + answer + analysis 到 CalibrationRecord（analysis 字段不再丢弃）
- AC-C6: 构筑的 user message 中包含每条校准记录的完整信息：scenario、用户选择/自定义答案、analysis 分析过程
- AC-C7: 已有校准记录（无 consumedAtLevel 字段）在升级时视为未消费，JSON 解码兼容

---

## 模块 D：校准分析输出改造 + 废弃 personalityTags

### 用户故事

作为 Ghost Twin 系统，我希望校准分析输出完整的人格增量描述文本而非标签，这样构筑时能获得更丰富的上下文。

### 验收标准

- AC-D1: 校准分析模式的 `profile_diff` 输出改为：`{"layer": "form|spirit|method", "description": "完整的人格增量描述文本", "ghost_response": "Ghost 回应", "analysis": "分析推理过程"}`
- AC-D2: 废弃 `CalibrationAnalysisResponse.ProfileDiff.newTags` 字段
- AC-D3: 废弃 `GhostTwinProfile.personalityTags` 字段
- AC-D4: IncubatorViewModel 中删除所有 tag 合并逻辑
- AC-D5: IncubatorPage UI 状态芯片从显示标签改为显示 profiling summary（一句话人格画像，从 profileText 末尾 JSON 的 summary 字段提取）
- AC-D6: UserDefaults 缓存中删除 personalityTags 相关的读写
- AC-D7: MessageBuilder 中删除标签相关的拼接，校准出题/分析的 user message 只传 profileText
- AC-D8: SkillExecutor 的 ghost_profile context provider 只提供 profileText，不再拼接标签
- AC-D9: profiling skill 输出的 JSON 摘要中 `refined_tags` 字段也废弃，只保留 `summary`
- AC-D10: 校准分析的 analysis 字段存入 CalibrationRecord（与 AC-C5 联动）

---

## 模块 E：多语言适配（LLM 输出）

### 用户故事

作为英文用户，我希望 Ghost Twin 的校准题目、分析回应、人格档案、ghost_response 都是英文的，与我的应用语言设置一致。

### 验收标准

- AC-E1: `user_language` 作为全局 context provider 注册到 SkillExecutor
- AC-E2: 所有 Ghost Twin 相关 skill（calibration、profiling、initial-profiling）在 SKILL.md 中声明 `context_requires: [user_language]`
- AC-E3: skill 的 system prompt 中包含语言指令：`用户语言为 {{context.user_language}}，请使用该语言输出所有内容`
- AC-E4: 所有内置 skill（润色、笔记、翻译等）同样声明 `context_requires: [user_language]` 并在 prompt 中使用
- AC-E5: 用户自建 skill 的生成流程中，prompt generator 根据 user_language 生成对应语言的 skill 描述和 prompt

---

## 实现优先级与依赖关系

```
模块 A（Skill Context 架构）  ← 基础设施，其他模块依赖
  ↓
模块 D（校准输出改造 + 废弃 tags）+ 模块 C（构筑链路修复）  ← 紧密关联，一起做
  ↓
模块 B（冷启动改造）  ← 需要新 skill + XP 计算调整
  ↓
模块 E（多语言适配）  ← 依赖 A 的 user_language provider
```

---

## 涉及文件（预估）

### Skill 系统
- `Sources/Features/AI/Skill/SkillExecutor.swift` — context provider 注册表
- `Sources/Features/AI/Skill/SkillModel.swift` — 新增 contextRequires 字段
- `Sources/Features/AI/Skill/SkillManager.swift` — 解析 context_requires
- `Sources/Features/AI/Skill/TemplateEngine.swift` — 无需改动（已支持 {{context.xxx}}）

### Ghost Twin 数据层
- `Sources/Features/Dashboard/GhostTwinProfile.swift` — 废弃 personalityTags，新增 summary
- `Sources/Features/Dashboard/GhostTwinXP.swift` — Lv.0 计算逻辑
- `Sources/Features/Dashboard/CalibrationRecord.swift` — 新增 consumedAtLevel、analysis 字段
- `Sources/Features/Dashboard/IncubatorViewModel.swift` — 删除 tag 逻辑，修复 previousReport，消费标记
- `Sources/Features/Dashboard/MessageBuilder.swift` — 删除标签拼接，增加 analysis 传递

### Skill 定义
- `default_skills/internal-ghost-calibration/SKILL.md` — 输出格式调整，声明 context_requires
- `default_skills/internal-ghost-profiling/SKILL.md` — 废弃 refined_tags，声明 context_requires
- `default_skills/internal-ghost-initial-profiling/SKILL.md` — 新建，简化版首次构筑

### UI
- `Sources/UI/Dashboard/Pages/IncubatorPage.swift` — 状态芯片改为 summary，Lv.0 引导文案

### 本地化
- `Sources/Features/Settings/Strings.swift` — 新增 Lv.0 引导文案 key
- `Sources/Features/Settings/Strings+Chinese.swift` — 中文
- `Sources/Features/Settings/Strings+English.swift` — 英文
