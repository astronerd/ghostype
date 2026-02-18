# 实现计划：校准系统修正（Calibration Fix）

## 概述

修正 Ghost Twin 校准系统的前置条件缺失、ChallengeType 移除、JSON 命名规范化三个问题。LLMJsonParser 全局添加 convertFromSnakeCase，所有 Swift Decodable 属性统一 camelCase。

## 任务

- [ ] 1. 移除 ChallengeType 枚举及相关引用
  - [ ] 1.1 从 `GhostypeModels.swift` 中删除 `ChallengeType` 枚举
    - 删除整个 `ChallengeType` enum 定义（包括 `xpReward` 计算属性）
    - _Requirements: 2.1_
  - [ ] 1.2 修改 `LocalCalibrationChallenge`，移除 `type` 字段
    - 从 `CalibrationRecord.swift` 中的 `LocalCalibrationChallenge` 移除 `let type: ChallengeType`
    - 保持 `targetField`（camelCase），无需 CodingKeys，由 convertFromSnakeCase 自动映射
    - _Requirements: 2.1, 4.4_
  - [ ] 1.3 修改 `CalibrationRecord`，移除 `type` 字段
    - 从 `CalibrationRecord` 结构体中移除 `let type: ChallengeType`
    - _Requirements: 2.3_
  - [ ] 1.4 修改 `GhostTwinXP`，移除 `xpReward(for:)` 方法，添加统一常量
    - 删除 `static func xpReward(for type: ChallengeType) -> Int`
    - 添加 `static let calibrationXPReward = 300`
    - _Requirements: 2.2_
  - [ ] 1.5 修改 `IncubatorViewModel`，更新 XP 计算和 CalibrationAnalysisResponse 属性引用
    - `submitAnswer()` 中将 `GhostTwinXP.xpReward(for: challenge.type)` 改为 `GhostTwinXP.calibrationXPReward`
    - `CalibrationRecord` 构造处移除 `type` 参数
    - `CalibrationAnalysisResponse` 属性名改为 camelCase：`profile_diff`→`profileDiff`、`ghost_response`→`ghostResponse`，嵌套 `ProfileDiff` 的 `new_tags`→`newTags`
    - 更新所有引用这些属性的代码（如 `analysis.profile_diff` → `analysis.profileDiff`）
    - _Requirements: 2.1, 2.2, 4.3_
  - [ ] 1.6 修改 `MessageBuilder`，移除所有 `ChallengeType` 引用
    - `buildAnalysisUserMessage` 中移除 `challenge.type.rawValue` 引用
    - `buildChallengeUserMessage` 和 `buildProfilingUserMessage` 中 `record.type.rawValue` 引用改为移除类型信息
    - _Requirements: 2.1_

- [ ] 2. 添加校准前置条件检查
  - [ ] 2.1 在 `IncubatorViewModel` 中添加 `hasCompletedProfiling` 计算属性
    - 添加 `var hasCompletedProfiling: Bool` 计算属性，检查 `profile.profileText` 非空且非纯空白
    - _Requirements: 1.1_
  - [ ] 2.2 在 `startCalibration()` 中添加防御性检查
    - 在现有 `guard !isLoadingChallenge` 之后添加 `guard hasCompletedProfiling` 检查
    - 不满足时记录日志并直接返回
    - _Requirements: 1.4_
  - [ ] 2.3 修改 `IncubatorPage.swift` 的 `rpgDialogLayer`，增加 profiling 条件
    - 校准提示的显示条件从 `challengesRemaining > 0` 改为 `viewModel.hasCompletedProfiling && challengesRemaining > 0`
    - _Requirements: 1.2, 1.3_

- [ ] 3. 更新 SKILL.md 输出格式
  - [ ] 3.1 修改 `internal-ghost-calibration/SKILL.md`
    - 出题模式输出格式移除 `type` 字段
    - 确认所有字段使用 snake_case（target_field、scenario、options）
    - _Requirements: 2.4, 3.1, 3.2_

- [ ] 4. LLMJsonParser 全局 convertFromSnakeCase
  - [ ] 4.1 修改 `LLMJsonParser.swift`，在 parse 方法的 JSONDecoder 上添加 `decoder.keyDecodingStrategy = .convertFromSnakeCase`
    - _Requirements: 4.1, 4.2_

- [ ] 5. 检查点 - 确保编译通过
  - 确保所有修改后代码编译通过，检查是否有遗漏的 ChallengeType 引用
  - 检查 CalibrationAnalysisResponse 属性引用是否全部更新为 camelCase
  - 如有问题请询问用户

- [ ] 6. 更新测试文件
  - [ ] 6.1 更新现有测试中的 TestChallengeType 和相关 test model copies
    - 更新 `CalibrationRecordPropertyTests.swift`：移除 TestChallengeType，更新 TestCalibrationRecord
    - 更新 `CalibrationRecordStorePropertyTests.swift`：同上
    - 更新 `MessageBuilderPropertyTests.swift`：移除 TestChallengeType，更新 TestLocalCalibrationChallenge 和 TestCalibrationRecord
    - 更新 `FlowStatePropertyTests.swift`：移除 TestChallengeType，更新 TestLocalCalibrationChallenge
    - 更新 `CustomAnswerRecordPropertyTests.swift`：移除 TestChallengeType，更新 TestCalibrationRecord
    - 更新 `GhostTwinModelsPropertyTests.swift`：移除 TestChallengeType 相关测试
    - 更新 `GhostTwinE2ETests.swift`：移除 TestChallengeType，更新 TestCalibrationAnalysisResponse 属性名为 camelCase（profileDiff、ghostResponse、newTags），更新所有相关测试逻辑
    - 更新 `LLMJsonParserPropertyTests.swift`：确认 convertFromSnakeCase 不影响现有测试（SimplePayload 等测试结构体已经是 camelCase 或无下划线）
    - _Requirements: 2.1, 2.3, 4.3_
  - [ ]* 6.2 编写 hasCompletedProfiling 属性测试
    - **Property 1: hasCompletedProfiling 对空/非空 profileText 的正确性**
    - 生成 100+ 随机字符串，验证空/纯空白返回 false，含非空白字符返回 true
    - **Validates: Requirements 1.1**
  - [ ]* 6.3 编写 LocalCalibrationChallenge 解析属性测试
    - **Property 2: LocalCalibrationChallenge 解析一致性**
    - 生成 100+ 随机 snake_case JSON，通过配置了 convertFromSnakeCase 的 JSONDecoder 解析验证
    - **Validates: Requirements 4.4, 4.5**
  - [ ]* 6.4 编写 CalibrationRecord 往返属性测试（更新现有测试）
    - **Property 3: CalibrationRecord 往返一致性**
    - 更新现有 CalibrationRecordPropertyTests 中的往返测试，移除 type 字段
    - **Validates: Requirements 2.3**

- [ ] 7. 最终检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

## 备注

- 标记 `*` 的任务为可选测试任务，可跳过以加快 MVP
- 每个任务引用了具体的需求编号以便追溯
- 测试文件需要创建 test-local model copies（项目现有模式，test target 无法 import executable target）
- 旧版 calibration_records.json 向后兼容，无需数据迁移
- 属性测试验证通用正确性，单元测试验证具体示例和边界情况
