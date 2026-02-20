# 需求文档：校准系统修正（Calibration Fix）

## 简介

Ghost Twin 校准（Calibration）系统存在若干基础问题需要修正：
1. 校准前置条件缺失——系统在用户没有经过首次 profiling 的情况下就提供校准机会，这在业务上不合理
2. LLM 交互的 JSON 字段命名不一致——蛇形与驼峰混用，导致解析失败
3. ChallengeType 分类对出题和分析无实际意义——去掉 type 字段，统一 XP 奖励，简化链路

正确的业务流程：用户语音使用 → 积累 ASR 语料 → 触发首次 profiling → AI 生成人格档案初稿 → 系统开始提供校准机会 → 用户选择是否参与校准。

## 术语表

- **Calibration_System**：Ghost Twin 校准系统，负责生成校准挑战题并分析用户回答
- **IncubatorViewModel**：孵化室 ViewModel，管理校准挑战的发起、提交等状态
- **GhostTwinProfile**：Ghost Twin 人格档案，包含 profileText 字段记录构筑结果
- **Profiling**：人格构筑过程，AI 基于 ASR 语料分析用户人格特征并生成档案文本
- **LLMJsonParser**：LLM 返回 JSON 的解析器，负责剥离 markdown 代码块并解码
- **LocalCalibrationChallenge**：本地校准挑战数据结构，包含 targetField、scenario、options（Swift camelCase 属性名）
- **SKILL.md**：技能定义文件，定义 LLM 的 system prompt 和输出格式
- **snake_case**：蛇形命名法，单词间用下划线连接（如 target_field），LLM JSON 侧统一使用
- **camelCase**：驼峰命名法（如 targetField），Swift 属性侧统一使用
- **convertFromSnakeCase**：JSONDecoder 的 keyDecodingStrategy，自动将 JSON 的 snake_case 键映射到 Swift 的 camelCase 属性
- **profileText**：GhostTwinProfile 中的纯文本字段，存储人格档案全文；空字符串表示尚未经过 profiling

## 需求

### 需求 1：校准前置条件——首次 profiling 完成后才提供校准机会

**用户故事：** 作为 Ghost Twin 用户，我希望系统只在 AI 已经对我有了基础画像之后才向我提供校准机会，以确保校准是基于有意义的人格档案进行的。

#### 验收标准

1. WHEN IncubatorViewModel 加载本地数据时，THE Calibration_System SHALL 检查 GhostTwinProfile 的 profileText 是否为非空且非纯空白字符串，以此判断是否已完成首次 profiling
2. WHILE profileText 为空字符串或仅包含空白字符，THE IncubatorViewModel SHALL 不向用户展示校准入口（隐藏校准提示和校准按钮）
3. WHEN profileText 从空变为非空（即首次 profiling 完成），THE IncubatorViewModel SHALL 开始向用户展示校准机会
4. WHEN startCalibration 被调用但 profileText 为空或纯空白，THE Calibration_System SHALL 拒绝执行并记录日志，作为防御性检查

### 需求 2：移除 ChallengeType 分类，统一 XP 奖励

**用户故事：** 作为开发者，我希望移除对出题和分析无实际意义的 ChallengeType 分类，统一校准 XP 奖励值，以简化校准链路。

#### 验收标准

1. THE LocalCalibrationChallenge SHALL 移除 type 字段，仅保留 target_field、scenario、options 三个字段
2. THE Calibration_System SHALL 对所有校准挑战使用统一的 XP 奖励值（不再按类型区分）
3. WHEN CalibrationRecord 记录校准历史时，THE CalibrationRecord SHALL 移除 type 字段
4. THE SKILL.md SHALL 在出题模式的输出格式中不包含 type 字段

### 需求 3：SKILL.md 输出格式规范化

**用户故事：** 作为开发者，我希望 SKILL.md 的出题模式输出格式与 Swift 数据结构完全对齐，以确保 LLM 返回的 JSON 能被正确解析。

#### 验收标准

1. WHEN LLM 在出题模式下生成校准挑战，THE SKILL.md SHALL 要求所有 JSON 字段使用 snake_case 命名（target_field、scenario、options）
2. WHEN LLM 在出题模式下生成校准挑战，THE SKILL.md SHALL 要求输出 JSON 仅包含 target_field、scenario、options 三个字段

### 需求 4：LLMJsonParser 全局 convertFromSnakeCase 策略

**用户故事：** 作为开发者，我希望 LLMJsonParser 统一配置 convertFromSnakeCase 解码策略，所有 LLM 返回的 Decodable 结构体属性统一使用 Swift 标准的 camelCase 命名，由 JSONDecoder 自动完成 snake_case → camelCase 的映射。



参考：[Apple JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase](https://developer.apple.com/documentation/foundation/jsondecoder/keydecodingstrategy/convertfromsnakecase)、[Hacking with Swift](https://www.hackingwithswift.com/swift/4.1/key-decoding-strategies)、[Nil Coalescing](https://www.nilcoalescing.com/blog/AutoConvertJsonSnakeCaseToSwiftCamelCaseProperties)

#### 验收标准

1. THE LLMJsonParser SHALL 在 JSONDecoder 上配置 keyDecodingStrategy 为 .convertFromSnakeCase
2. WHEN LLM 返回 snake_case 字段的 JSON，THE LLMJsonParser SHALL 自动将 snake_case 字段映射到 Swift 的 camelCase 属性，无需任何 CodingKeys
3. THE CalibrationAnalysisResponse SHALL 将属性名从 snake_case（profile_diff、ghost_response）改为 camelCase（profileDiff、ghostResponse），嵌套的 ProfileDiff 的 new_tags 改为 newTags
4. THE LocalCalibrationChallenge SHALL 保持 camelCase 属性名（targetField、scenario、options），无需 CodingKeys，由 convertFromSnakeCase 自动映射 target_field
5. FOR ALL 有效的 LocalCalibrationChallenge 实例，通过 LLMJsonParser 解析 snake_case JSON 应成功且字段值正确

### 需求 5：JSON 命名规范统一

**用户故事：** 作为开发者，我希望建立清晰的命名约定：LLM 侧统一 snake_case，Swift 侧统一 camelCase，中间由 JSONDecoder 自动转换。

#### 验收标准

1. THE Calibration_System SHALL 确保所有 SKILL.md 中定义的 LLM 输出 JSON 字段均使用 snake_case 命名
2. THE Calibration_System SHALL 确保所有 Swift Decodable 结构体属性均使用 camelCase 命名
3. THE LLMJsonParser 的 convertFromSnakeCase 策略 SHALL 作为两者之间的唯一桥梁，不再需要手动 CodingKeys 或 snake_case 属性名
