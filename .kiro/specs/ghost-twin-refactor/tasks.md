# Ghost Twin 系统重构 — 任务清单

## 模块 A：Skill Context 声明式架构

- [x] A1. SkillFileParser.ParseResult 新增 `contextRequires: [String]` 字段
- [x] A2. SkillFileParser.parse() 解析 `context_requires` 数组（knownArrayFields 添加 "context_requires"）
- [x] A3. SkillFileParser.print() 序列化 `context_requires`（非空时输出）
- [x] A4. SkillModel 新增 `contextRequires: [String]` 属性，默认 `[]`
- [x] A5. SkillManager.loadAllSkills() 传入 `parseResult.contextRequires`
- [x] A6. SkillManager.makeParseResult() 传入 `skill.contextRequires`
- [x] A7. SkillExecutor 新增 `contextProviders: [String: () -> String]` 注册表
- [x] A8. SkillExecutor.registerDefaultProviders() 注册 ghost_profile、user_language、calibration_records、asr_corpus
- [x] A9. SkillExecutor.execute() 改造：删除 hardcode ghost_profile，改为遍历 skill.contextRequires 从 provider 取值
- [x] A10. 验证：未声明 context_requires 的 skill 不注入任何 context

## 模块 D：校准分析输出改造 + 废弃 personalityTags

- [x] D1. CalibrationAnalysisResponse.ProfileDiff 改造：删除 `changes: [String: String]` 和 `newTags: [String]`，新增 `description: String`
- [x] D2. GhostTwinProfile 删除 `personalityTags: [String]`，新增 `summary: String`
- [x] D3. GhostTwinProfile 添加自定义 `init(from:)` 兼容老数据（忽略 personalityTags，summary 默认空）
- [x] D4. GhostTwinProfile.initial 更新：level 改为 0，删除 personalityTags，添加 summary
- [x] D5. IncubatorViewModel 删除 `personalityTags` 属性，新增 `summary: String`
- [x] D6. IncubatorViewModel.loadLocalData() 改为读取 `profile.summary`
- [x] D7. IncubatorViewModel.submitAnswer() 删除 tag 合并逻辑（newTags 相关代码全部删除）
- [x] D8. IncubatorViewModel.triggerProfiling() 结果解析：ProfilingSummary 删除 refinedTags，只保留 summary；存入 profile.summary
- [x] D9. GhostTwinCacheKey 删除 `.personalityTags` case，cache 读写删除标签相关代码
- [x] D10. MessageBuilder.buildChallengeUserMessage() 删除标签拼接（`已捕捉标签: ...`）
- [x] D11. MessageBuilder.buildProfilingUserMessage() 删除标签拼接
- [x] D12. IncubatorPage.swift 状态芯片改为显示 `viewModel.summary`
- [x] D13. 更新 internal-ghost-calibration/SKILL.md 分析模式输出格式（profile_diff 改为 layer + description）
- [x] D14. 更新 internal-ghost-profiling/SKILL.md 输出格式（JSON 摘要只保留 summary，删除 refined_tags）
- [x] D15. 更新测试文件：GhostTwinE2ETests、IncubatorViewModelPropertyTests 等，同步删除 personalityTags 相关断言

## 模块 C：构筑上下文链路修复

- [x] C1. CalibrationRecord 新增 `analysis: String?` 字段
- [x] C2. CalibrationRecord 新增 `consumedAtLevel: Int?` 字段（var，可变）
- [x] C3. CalibrationRecordStore 新增 `unconsumed() -> [CalibrationRecord]` 方法
- [x] C4. CalibrationRecordStore 新增 `markConsumed(ids:atLevel:)` 方法
- [x] C5. CalibrationRecordStore.save() 从 private 改为 internal（供 markConsumed 调用）
- [x] C6. IncubatorViewModel.submitAnswer() 保存 analysis 到 CalibrationRecord
- [x] C7. IncubatorViewModel.submitAnswer() 创建 CalibrationRecord 时传入 `consumedAtLevel: nil`
- [x] C8. IncubatorViewModel.triggerProfiling() 修复 previousReport：传 `profile.profileText`（非空时）
- [x] C9. IncubatorViewModel.triggerProfiling() 改用 `recordStore.unconsumed()` 替代 `recordStore.loadAll()`
- [x] C10. IncubatorViewModel.triggerProfiling() 构筑成功后调用 `recordStore.markConsumed(ids:atLevel:)`
- [x] C11. MessageBuilder.buildProfilingUserMessage() 增强校准记录输出：包含场景、用户选择/自定义答案、analysis、profileDiff
- [x] C12. MessageBuilder.buildChallengeUserMessage() 中 records 参数改为传完整信息（含 analysis）

## 模块 B：冷启动改造

- [x] B1. GhostTwinXP 新增 `xpForLevel0 = 2000` 常量
- [x] B2. GhostTwinXP.calculateLevel() 调整：totalXP < 2000 → Lv.0
- [x] B3. GhostTwinXP.currentLevelXP() 调整：Lv.0 时返回 totalXP
- [x] B4. GhostTwinXP 新增 `xpNeededForCurrentLevel(level:)` 方法
- [x] B5. IncubatorViewModel.loadLocalData() 添加老用户迁移：level >= 1 且 totalXP < 2000 时补齐到 2000
- [x] B6. SkillModel 新增 `internalGhostInitialProfilingId` 常量
- [x] B7. SkillManager.builtinMetadata 添加 internal-ghost-initial-profiling 条目
- [x] B8. 新建 `default_skills/internal-ghost-initial-profiling/SKILL.md`（简化版首次构筑 prompt）
- [x] B9. IncubatorViewModel.triggerProfiling() 添加分支：Lv.0→Lv.1 且 profileText 为空时使用 initial-profiling skill
- [x] B10. IncubatorPage UI：Lv.0 时显示引导文案（L.Incubator.coldStartGuide）
- [x] B11. Strings.swift / Strings+Chinese.swift / Strings+English.swift 添加 coldStartGuide 本地化文案
- [x] B12. AnimationPhase：确认 Lv.0 使用 .glitch（adjustanimationPhase(forLevel:) 的 case 范围改为 0...3）
- [x] B13. progressFraction 计算调整：使用 xpNeededForCurrentLevel 作为分母

## 模块 E：多语言适配（LLM 输出）

- [x] E1. 更新 internal-ghost-calibration/SKILL.md：添加 `context_requires: [ghost_profile, user_language]`，prompt 添加语言指令
- [x] E2. 更新 internal-ghost-profiling/SKILL.md：添加 `context_requires: [ghost_profile, user_language, asr_corpus, calibration_records]`，prompt 添加语言指令
- [x] E3. 更新 internal-ghost-initial-profiling/SKILL.md：确认已包含 `context_requires: [user_language, asr_corpus]` 和语言指令
- [x] E4. 更新 builtin-ghost-twin/SKILL.md：添加 `context_requires: [ghost_profile, user_language]`，prompt 添加语言指令
- [x] E5. 更新 builtin-memo/SKILL.md：添加 `context_requires: [user_language]`，prompt 添加语言指令
- [x] E6. 更新 builtin-ghost-command/SKILL.md：添加 `context_requires: [user_language]`，prompt 添加语言指令
- [x] E7. 更新 builtin-translate/SKILL.md：添加 `context_requires: [user_language]`，prompt 添加语言指令
- [x] E8. 更新 builtin-prompt-generator/SKILL.md：添加 `context_requires: [user_language]`，prompt 添加语言指令

## 收尾

- [x] F1. build release 验证编译通过
- [x] F2. build release --clean 验证新用户流程（Lv.0 → 说话 → 升级 → 首次构筑 → 校准）
- [ ] F3. build release 验证老用户升级兼容（已有 profile 数据不丢失）
