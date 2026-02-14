# Implementation Plan: Ghost Twin 端上迁移

## Overview

将 Ghost Twin 校准系统从服务端迁移到客户端，按照数据模型 → 纯函数 → 持久化 → 内部技能 → 流程串联 → UI 适配 → 清理旧代码的顺序实现。每个阶段都有对应的测试任务，确保增量验证。

## Tasks

- [x] 1. 数据模型与纯函数
  - [x] 1.1 创建 GhostTwinProfile 简化模型
    - 新建 `Sources/Features/Dashboard/GhostTwinProfile.swift`
    - 实现 `GhostTwinProfile` struct（version, level, totalXP, personalityTags, profileText, createdAt, updatedAt）
    - 实现 `GhostTwinProfile.initial` 静态属性
    - 使用 `Codable` + `Equatable`，dateEncodingStrategy = .iso8601
    - _Requirements: 1.1, 1.5, 1.6_

  - [x] 1.2 Write property test for GhostTwinProfile round-trip
    - **Property 1: Profile round-trip consistency**
    - **Validates: Requirements 1.7**

  - [x] 1.3 创建 CalibrationRecord 模型
    - 新建 `Sources/Features/Dashboard/CalibrationRecord.swift`
    - 实现 `CalibrationRecord` struct（id, type, scenario, options, selectedOption, customAnswer, xpEarned, ghostResponse, profileDiff, createdAt）
    - 实现 `LocalCalibrationChallenge` struct（type, scenario, options, targetField）
    - 复用现有 `ChallengeType` 枚举（已在 GhostypeModels.swift 中定义）
    - _Requirements: 2.1, 13.6, 13.7_

  - [x] 1.4 Write property test for CalibrationRecord round-trip
    - **Property 2: CalibrationRecord round-trip consistency**
    - **Validates: Requirements 2.4**

  - [x] 1.5 创建 GhostTwinXP 纯函数
    - 新建 `Sources/Features/Dashboard/GhostTwinXP.swift`
    - 实现 `calculateLevel(totalXP:)` — `min(totalXP / 10000 + 1, 10)`
    - 实现 `currentLevelXP(totalXP:)` — 未满级 `totalXP % 10000`，满级 `totalXP - 90000`
    - 实现 `checkLevelUp(oldXP:newXP:)` — 返回 (leveledUp, oldLevel, newLevel)
    - 实现 `xpReward(for:)` — dilemma=500, reverseTuring=300, prediction=200
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 1.6 Write property tests for GhostTwinXP
    - **Property 4: Level calculation formula**
    - **Property 5: Current level XP formula**
    - **Property 6: Level-up detection**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4**

  - [x] 1.7 创建 LLMJsonParser 工具
    - 新建 `Sources/Features/Dashboard/LLMJsonParser.swift`
    - 实现 `parse<T: Decodable>(_ raw: String) throws -> T`
    - 实现 `stripMarkdownCodeBlock(_ text: String) -> String`
    - 实现 `LLMParseError` 枚举（invalidEncoding, invalidJSON）
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 1.8 Write property test for LLMJsonParser
    - **Property 12: LLM JSON parsing equivalence**
    - **Validates: Requirements 10.1, 10.2, 10.4**

- [x] 2. Checkpoint - 确保所有数据模型和纯函数测试通过
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. 持久化层
  - [x] 3.1 实现 GhostTwinProfileStore
    - 在 `GhostTwinProfile.swift` 中添加 `GhostTwinProfileStore` class
    - 路径：`~/Library/Application Support/GHOSTYPE/ghost_twin/profile.json`
    - 实现 `load()` — 文件不存在时返回 `.initial`
    - 实现 `save(_ profile:)` — 自动创建目录
    - _Requirements: 1.5, 1.6_

  - [x] 3.2 实现 CalibrationRecordStore
    - 在 `CalibrationRecord.swift` 中添加 `CalibrationRecordStore` class
    - 路径：`~/Library/Application Support/GHOSTYPE/ghost_twin/calibration_records.json`
    - 实现 `loadAll()`, `append(_ record:)` — 超过 20 条丢弃最早的
    - 实现 `todayCount()` — UTC 0:00 重置
    - 实现 `challengesRemainingToday()` — `max(3 - todayCount(), 0)`
    - _Requirements: 2.2, 2.3, 4.1, 4.2, 4.3, 4.4_

  - [x] 3.3 Write property test for record store max-20 invariant
    - **Property 3: Record store max-20 invariant**
    - **Validates: Requirements 2.2, 2.3**

  - [x] 3.4 Write property test for daily challenge limit
    - **Property 7: Daily challenge limit**
    - **Validates: Requirements 4.1, 4.2, 4.3**

  - [x] 3.5 实现 ASRCorpusStore
    - 新建 `Sources/Features/Dashboard/ASRCorpusStore.swift`
    - 实现 `ASRCorpusEntry` struct（id, text, createdAt, consumedAtLevel）
    - 实现 `ASRCorpusStore` class — loadAll, append, unconsumed, markConsumed, save
    - 路径：`~/Library/Application Support/GHOSTYPE/ghost_twin/asr_corpus.json`
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x] 3.6 Write property test for corpus consumption
    - **Property 11: Corpus consumption state management**
    - **Validates: Requirements 7.5, 8.3, 8.4**

- [x] 4. Checkpoint - 确保持久化层测试通过
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. 流程状态机与恢复
  - [x] 5.1 创建 CalibrationFlowState
    - 新建 `Sources/Features/Dashboard/CalibrationFlowState.swift`
    - 实现 `CalibrationPhase` 枚举（idle, challenging, analyzing）
    - 实现 `CalibrationFlowState` struct（phase, challenge, selectedOption, customAnswer, retryCount, updatedAt）
    - _Requirements: 12.1, 12.4_

  - [x] 5.2 创建 ProfilingFlowState
    - 新建 `Sources/Features/Dashboard/ProfilingFlowState.swift`
    - 实现 `ProfilingPhase` 枚举（idle, pending, running）
    - 实现 `ProfilingFlowState` struct（phase, triggerLevel, corpusIds, retryCount, maxRetries, updatedAt）
    - _Requirements: 12.2, 12.5_

  - [x] 5.3 Write property test for flow state round-trip
    - **Property 13: Flow state round-trip consistency**
    - **Validates: Requirements 12.1, 12.2, 12.12**

  - [x] 5.4 实现 RecoveryManager
    - 新建 `Sources/Features/Dashboard/RecoveryManager.swift`
    - 实现 load/save/clear 方法 for CalibrationFlowState 和 ProfilingFlowState
    - 路径：`calibration_flow.json` 和 `profiling_flow.json`
    - 处理数据损坏：反序列化失败时丢弃并记录日志
    - _Requirements: 12.3, 12.6, 12.7, 12.11_

- [x] 6. 内部技能定义
  - [x] 6.1 创建 internal-ghost-calibration 技能
    - 新建 `default_skills/internal-ghost-calibration/SKILL.md`
    - system prompt 包含校准系统角色定义、出题模式和分析模式的输出格式
    - 在 `SkillModel.swift` 中添加 `internalGhostCalibrationId` 常量
    - 在 `SkillManager.ensureBuiltinSkills()` 中注册该技能（isInternal=true）
    - _Requirements: 9.1, 9.3, 9.4_

  - [x] 6.2 创建 internal-ghost-profiling 技能
    - 新建 `default_skills/internal-ghost-profiling/SKILL.md`
    - system prompt 包含完整的「形神法三位一体」框架（来自虚拟人格构筑prompt.md）
    - 在 `SkillModel.swift` 中添加 `internalGhostProfilingId` 常量
    - 在 `SkillManager.ensureBuiltinSkills()` 中注册该技能（isInternal=true）
    - _Requirements: 9.2, 9.3_

  - [x] 6.3 更新 builtin-ghost-twin 技能
    - 修改 `builtin-ghost-twin/SKILL.md`，移除 `api_endpoint: "/api/v1/ghost-twin/chat"` 配置
    - 在 `SkillExecutor` 中添加逻辑：当 skill.id == builtin-ghost-twin 时，从 GhostTwinProfileStore 加载档案，将 profileText + personalityTags 注入 system prompt
    - _Requirements: 9.5_

- [x] 7. Checkpoint - 确保内部技能注册正确
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. IncubatorViewModel 重构与流程串联
  - [x] 8.1 实现 user message 构建方法
    - 在 `IncubatorViewModel` 中添加 `buildChallengeUserMessage` 私有方法
    - 在 `IncubatorViewModel` 中添加 `buildAnalysisUserMessage` 私有方法（支持自定义答案标注）
    - 在 `IncubatorViewModel` 中添加 `buildProfilingUserMessage` 私有方法
    - _Requirements: 5.1, 5.2, 6.1, 7.3, 7.4, 13.3, 13.4_

  - [x] 8.2 Write property tests for user message builders
    - **Property 8: Challenge user message contains required data**
    - **Property 9: Analysis user message contains profile and challenge data**
    - **Property 10: Profiling user message contains framework and data**
    - **Property 14: Custom answer user message annotation**
    - **Validates: Requirements 5.1, 5.2, 6.1, 7.3, 7.4, 13.3, 13.4**

  - [x] 8.3 重构 IncubatorViewModel 核心逻辑
    - 添加 profileStore, recordStore, corpusStore, recoveryManager 依赖
    - 实现 `loadLocalData()` 替代 `fetchStatus()`
    - 实现 `startCalibration()` — 加载技能 → 构建 user message → executeSkill → LLMJsonParser 解析 → 持久化中间状态
    - 实现 `submitAnswer(selectedOption:customAnswer:)` — 构建分析 message → executeSkill → 解析 diff → 合并 tags → 累加 XP → 检查升级 → 触发构筑 → 保存记录
    - 实现 `checkAndRecover()` — 启动时检查中间状态并恢复
    - 移除 `fetchStatus()`, `fetchChallenge()`, `submitAnswer(challengeId:selectedOption:)` 旧方法
    - _Requirements: 5.3, 5.4, 5.5, 6.2, 6.3, 6.4, 6.5, 6.6, 7.1, 7.2, 7.5, 7.6, 7.7, 11.6, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10_

  - [x] 8.4 集成 ASR 语料收集
    - 在语音输入完成的回调中（VoiceInputCoordinator 或 AppDelegate），调用 `ASRCorpusStore.append(text:)` 存储转写文本
    - _Requirements: 8.1_

- [x] 9. 自定义答案 UI
  - [x] 9.1 扩展 ReceiptSlipView 支持自定义输入
    - 在预设选项下方添加「以上都不是，我想自己说」按钮
    - 点击后展开文本输入框 + 提交按钮
    - 实现空白/纯空格验证，阻止提交
    - 添加 `onSubmitCustomAnswer: (String) -> Void` 回调
    - 将 challenge 类型从 `CalibrationChallenge` 改为 `LocalCalibrationChallenge`
    - _Requirements: 13.1, 13.2, 13.5_

  - [x] 9.2 Write property test for whitespace rejection
    - **Property 15: Whitespace custom answer rejection**
    - **Validates: Requirements 13.5**
    - **PBT Status: ✅ PASSED**

  - [x] 9.3 Write property test for custom answer record format
    - **Property 16: Custom answer record format**
    - **Validates: Requirements 13.6, 13.7**
    - **PBT Status: ✅ PASSED**

- [x] 10. Checkpoint - 确保校准流程端到端可用
  - 216 tests, 0 failures ✅

- [x] 11. 清理旧服务端 API
  - [x] 11.1 移除 GhostypeAPIClient 旧方法
    - 删除 `fetchGhostTwinStatus()`
    - 删除 `fetchCalibrationChallenge()`
    - 删除 `submitCalibrationAnswer()`
    - 删除 `ghostTwinChat()`
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [x] 11.2 移除 GhostypeModels 旧类型
    - 删除 `GhostTwinStatusResponse`
    - 删除 `CalibrationChallenge`（旧版服务端类型）
    - 删除 `CalibrationAnswerResponse`
    - 注意：保留 `ChallengeType` 枚举（本地逻辑仍在使用）
    - _Requirements: 11.5_

- [x] 12. Final checkpoint - 确保所有测试通过，编译无警告
  - 216 tests, 0 failures ✅ — all tasks complete

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- 所有 LLM 调用通过内部技能系统（SkillManager + executeSkill）实现，不新建独立的 prompt builder
