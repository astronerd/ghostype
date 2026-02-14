# 需求文档：Ghost Twin 端上迁移

## 简介

将 Ghost Twin 校准系统从服务端迁移到客户端（macOS），实现人格档案本地存储、校准逻辑本地驱动。服务端仅保留 LLM 代理角色（`POST /api/v1/skill/execute`），三个旧端点（`GET /ghost-twin/status`、`GET /ghost-twin/challenge`、`POST /ghost-twin/challenge/answer`）将被废弃。

## 术语表

- **Ghost_Twin_Profile（人格档案）**：用户的数字分身人格数据，包含「形」「神」「法」三层结构，以 JSON 文件存储在本地
- **Calibration_System（校准系统）**：通过情境问答收集用户人格特征的系统
- **Calibration_Record（校准记录）**：单次校准挑战的完整记录，包含题目、选项、用户选择、XP 奖励等
- **Profile_Diff（档案增量）**：单次校准后 LLM 返回的人格档案变更描述
- **Form_Layer（形层）**：语言 DNA 层，包含口癖、句式、标点习惯等
- **Spirit_Layer（神层）**：价值观层，包含核心价值观、决策倾向、社交策略
- **Method_Layer（法层）**：情境规则层，包含情境规则和对象适配
- **Profiling_Round（构筑轮次）**：升级时触发的人格深度分析，严格遵循「形神法三位一体」框架
- **ASR_Corpus（语音语料）**：用户语音输入的原始转写文本，标记 `consumedAtLevel` 表示已被哪个等级的构筑消费
- **Internal_Skill（内部技能）**：`isInternal = true` 的技能，不对用户展示，仅供系统内部调用
- **LLM_Proxy（LLM 代理）**：服务端 `/api/v1/skill/execute` 端点，纯透传 LLM 请求
- **XP（经验值）**：校准挑战获得的经验值，10,000 XP 升一级，最高 10 级
- **Challenge_Type（挑战类型）**：校准挑战的类型，包含 dilemma（灵魂拷问）、reverse_turing（找鬼游戏）、prediction（预判赌局）

## 需求

### 需求 1：人格档案数据模型与本地持久化

**用户故事：** 作为 GHOSTYPE 用户，我希望人格档案存储在本地设备上，以便保护我的隐私数据并支持离线查看。

#### 验收标准

1. THE Ghost_Twin_Profile SHALL 包含版本号（version）、等级（level）、总经验值（totalXP）、人格标签（personalityTags）、形层（formLayer）、神层（spiritLayer）、法层（methodLayer）、阶段性总结（summary）、创建时间（createdAt）和更新时间（updatedAt）字段
2. THE Form_Layer SHALL 包含口癖列表（verbalHabits）、常用句式（sentencePatterns）、标点习惯（punctuationStyle）和平均句长（avgSentenceLength）字段
3. THE Spirit_Layer SHALL 包含核心价值观（coreValues）、决策倾向（decisionTendency）和社交策略（socialStrategy）字段
4. THE Method_Layer SHALL 包含情境规则列表（contextRules）和对象适配列表（audienceAdaptations）字段
5. WHEN 用户首次使用 Ghost Twin 功能时，THE Calibration_System SHALL 创建一个初始空档案（version=0, level=1, totalXP=0，所有列表字段为空数组，字符串字段为空字符串）
6. THE Calibration_System SHALL 将 Ghost_Twin_Profile 以 JSON 文件格式持久化到本地磁盘
7. WHEN Ghost_Twin_Profile 被序列化为 JSON 再反序列化时，THE Calibration_System SHALL 产生与原始对象等价的结果（round-trip 一致性）

### 需求 2：校准记录本地存储

**用户故事：** 作为 GHOSTYPE 用户，我希望校准历史记录保存在本地，以便系统能利用历史数据生成更好的校准题目。

#### 验收标准

1. THE Calibration_Record SHALL 包含唯一标识（id）、挑战类型（type）、场景描述（scenario）、选项列表（options）、用户选择索引（selectedOption）、获得经验值（xpEarned）、Ghost 反馈语（ghostResponse）、档案增量（profileDiff）和创建时间（createdAt）字段
2. THE Calibration_System SHALL 在本地保留最近 20 条校准记录
3. WHEN 校准记录数量超过 20 条时，THE Calibration_System SHALL 丢弃最早的记录
4. WHEN Calibration_Record 被序列化为 JSON 再反序列化时，THE Calibration_System SHALL 产生与原始对象等价的结果（round-trip 一致性）

### 需求 3：XP 与等级计算

**用户故事：** 作为 GHOSTYPE 用户，我希望完成校准挑战后获得经验值并升级，以便感受到 Ghost Twin 的成长。

#### 验收标准

1. THE Calibration_System SHALL 以 10,000 XP 为一个等级的经验值需求，最高等级为 10
2. WHEN 计算等级时，THE Calibration_System SHALL 使用公式 `min(totalXP / 10000 + 1, 10)` 得出等级值
3. WHEN 计算当前等级内经验值时，THE Calibration_System SHALL 对未满级用户返回 `totalXP % 10000`，对满级用户返回 `totalXP - 90000`
4. WHEN 新增 XP 导致等级变化时，THE Calibration_System SHALL 检测到升级事件并返回旧等级和新等级
5. THE Calibration_System SHALL 为 dilemma 类型奖励 500 XP、reverse_turing 类型奖励 300 XP、prediction 类型奖励 200 XP

### 需求 4：每日校准次数限制

**用户故事：** 作为 GHOSTYPE 用户，我希望每天有固定的校准次数，以便保持校准的节奏感和仪式感。

#### 验收标准

1. THE Calibration_System SHALL 限制每日校准挑战次数为 3 次
2. WHEN 计算今日已完成挑战数时，THE Calibration_System SHALL 从本地 Calibration_Record 的 createdAt 时间戳筛选当日（UTC 0:00 重置）的记录数量
3. WHEN 今日已完成 3 次校准时，THE Calibration_System SHALL 阻止发起新的校准挑战
4. WHEN 跨越 UTC 0:00 后，THE Calibration_System SHALL 重置每日计数，允许新的校准挑战

### 需求 5：AI 驱动的校准出题

**用户故事：** 作为 GHOSTYPE 用户，我希望 AI 能根据我当前的人格档案智能出题，以便每次校准都能填补档案中最薄弱的部分。

#### 验收标准

1. WHEN 用户发起校准挑战时，THE Calibration_System SHALL 将完整的人格档案模板和当前档案数据发送给 LLM，由 AI 分析档案空缺并决定出题方向
2. WHEN 构建出题 prompt 时，THE Calibration_System SHALL 包含当前等级、档案版本、已捕捉标签和最近校准记录（用于去重）
3. THE Calibration_System SHALL 通过 `internal-ghost-calibration` 内部技能调用 `/api/v1/skill/execute` 端点发送出题请求
4. WHEN LLM 返回出题结果时，THE Calibration_System SHALL 解析 JSON 响应得到 target_field、scenario 和 options 字段
5. IF LLM 返回的 JSON 格式无效，THEN THE Calibration_System SHALL 返回描述性错误信息

### 需求 6：校准答案分析与档案增量更新

**用户故事：** 作为 GHOSTYPE 用户，我希望每次校准回答后 AI 能分析我的选择并更新人格档案，以便 Ghost Twin 越来越像我。

#### 验收标准

1. WHEN 用户提交校准答案时，THE Calibration_System SHALL 构建分析 prompt，包含当前完整档案、本次挑战信息（类型、场景、选项、目标层级）、用户选择和校准历史
2. THE Calibration_System SHALL 通过 `internal-ghost-calibration` 内部技能调用 `/api/v1/skill/execute` 端点发送分析请求
3. WHEN LLM 返回分析结果时，THE Calibration_System SHALL 解析 JSON 响应得到 profile_diff（含 layer、changes、new_tags）、ghost_response 和 analysis 字段
4. WHEN 收到 profile_diff 时，THE Calibration_System SHALL 将 changes 合并到对应的 Form/Spirit/Method 层，将 new_tags 去重合并到 personalityTags，并将 version 加 1
5. WHEN 档案合并完成后，THE Calibration_System SHALL 累加对应挑战类型的 XP 奖励并检查是否触发升级
6. IF LLM 返回的 JSON 格式无效，THEN THE Calibration_System SHALL 返回描述性错误信息，保持档案不变

### 需求 7：升级触发人格构筑

**用户故事：** 作为 GHOSTYPE 用户，我希望每次升级时 AI 对我的人格档案进行深度分析和精炼，以便获得更准确的数字分身。

#### 验收标准

1. WHEN 检测到升级事件时，THE Calibration_System SHALL 触发一轮人格构筑（Profiling_Round）
2. THE Calibration_System SHALL 通过 `internal-ghost-profiling` 内部技能调用 `/api/v1/skill/execute` 端点发送构筑请求
3. WHEN 构建构筑 prompt 时，THE Calibration_System SHALL 严格遵循「形神法三位一体」框架（虚拟人格构筑prompt.md），进行完整分析，不做简化或省略
4. WHEN 构建构筑 prompt 时，THE Calibration_System SHALL 传入上一轮的构筑报告（作为"记忆"）、当前等级新增的 ASR 语料（仅未消费过的）和当前等级的校准答案
5. WHEN ASR 语料被构筑消费后，THE Calibration_System SHALL 将该语料标记为 `consumedAtLevel = 当前等级`，确保每条语料仅被消费一次
6. WHEN LLM 返回构筑结果时，THE Calibration_System SHALL 解析结果并整体替换档案的三层数据、summary 和 refined_tags
7. WHEN 构筑结果包含 [NEW]、[REVISED]、[REINFORCED] 标记时，THE Calibration_System SHALL 保留这些变更标记用于展示

### 需求 8：ASR 语料收集与管理

**用户故事：** 作为 GHOSTYPE 用户，我希望系统自动收集我的语音输入作为人格分析素材，以便 Ghost Twin 能从日常使用中学习我的说话风格。

#### 验收标准

1. WHEN 用户完成一次语音输入时，THE Calibration_System SHALL 将 ASR 原始转写文本存储到本地语料库
2. THE ASR_Corpus 的每条记录 SHALL 包含原始文本（text）、创建时间（createdAt）和消费等级标记（consumedAtLevel，可选）
3. WHEN consumedAtLevel 为空时，THE Calibration_System SHALL 视该语料为未消费状态，可用于下次构筑
4. WHEN 构筑轮次消费语料后，THE Calibration_System SHALL 将 consumedAtLevel 设置为当前等级值

### 需求 9：内部技能定义

**用户故事：** 作为开发者，我希望 Ghost Twin 的 LLM 调用通过内部技能系统实现，以便复用现有的技能执行管道。

#### 验收标准

1. THE Calibration_System SHALL 定义 `internal-ghost-calibration` 内部技能，用于校准出题和答案分析两个阶段
2. THE Calibration_System SHALL 定义 `internal-ghost-profiling` 内部技能，用于升级时的人格构筑
3. WHEN 执行内部技能时，THE Calibration_System SHALL 设置 `isInternal = true`，使该技能不在用户技能列表中展示
4. THE `internal-ghost-calibration` 技能 SHALL 支持两套 prompt 模板（出题模板和分析模板），由客户端根据阶段切换
5. THE `builtin-ghost-twin` 技能 SHALL 更新为从本地 Ghost_Twin_Profile 注入人格数据到 system prompt，替代原有的 `/api/v1/ghost-twin/chat` 端点调用

### 需求 10：LLM JSON 响应解析

**用户故事：** 作为开发者，我希望有一个可靠的工具函数来解析 LLM 返回的 JSON，以便处理 LLM 输出中常见的 markdown 代码块包裹问题。

#### 验收标准

1. WHEN LLM 返回的文本被 markdown 代码块（```json ... ```）包裹时，THE Calibration_System SHALL 自动剥离代码块标记后解析 JSON
2. WHEN LLM 返回的文本是纯 JSON 时，THE Calibration_System SHALL 直接解析 JSON
3. IF LLM 返回的文本无法解析为有效 JSON，THEN THE Calibration_System SHALL 抛出包含原始文本片段的描述性错误
4. FOR ALL 有效的 JSON 字符串（无论是否被 markdown 代码块包裹），THE Calibration_System SHALL 解析出与直接 JSON 解码等价的结果

### 需求 11：废弃旧服务端 API 调用

**用户故事：** 作为开发者，我希望移除客户端对旧 Ghost Twin 服务端 API 的依赖，以便完成端上迁移。

#### 验收标准

1. WHEN 端上迁移完成后，THE GhostypeAPIClient SHALL 移除 `fetchGhostTwinStatus()` 方法
2. WHEN 端上迁移完成后，THE GhostypeAPIClient SHALL 移除 `fetchCalibrationChallenge()` 方法
3. WHEN 端上迁移完成后，THE GhostypeAPIClient SHALL 移除 `submitCalibrationAnswer()` 方法
4. WHEN 端上迁移完成后，THE GhostypeAPIClient SHALL 移除 `ghostTwinChat()` 方法
5. WHEN 端上迁移完成后，THE GhostypeModels SHALL 移除 `GhostTwinStatusResponse`、`CalibrationChallenge`（旧版）和 `CalibrationAnswerResponse` 类型定义
6. THE IncubatorViewModel SHALL 更新为调用本地校准逻辑替代旧的服务端 API 调用

### 需求 12：流程鲁棒性与中断恢复

**用户故事：** 作为 GHOSTYPE 用户，我希望校准和构筑流程在遇到应用崩溃、断网、重启等异常情况时能自动恢复或安全降级，以便异常不会卡死系统、不会阻塞后续正常使用。

#### 验收标准

1. WHEN 一次校准流程（出题 → 答题 → 档案更新）正在进行中且应用被关闭时，THE Calibration_System SHALL 在本地持久化当前流程的中间状态（包含阶段标识、挑战数据、用户选择等）
2. WHEN 一次 Profiling_Round 正在进行中且应用被关闭时，THE Calibration_System SHALL 在本地持久化构筑请求的上下文（包含触发等级、待消费语料 ID 列表、构筑 prompt 参数等）
3. WHEN 应用启动时，THE Calibration_System SHALL 检查是否存在未完成的校准流程或构筑轮次的中间状态
4. WHEN 检测到未完成的校准流程时，THE Calibration_System SHALL 根据中间状态的阶段标识自动从中断点恢复执行（例如：已出题未答题则恢复到展示题目阶段，已答题未更新档案则重新发送分析请求）
5. WHEN 检测到未完成的 Profiling_Round 时，THE Calibration_System SHALL 使用持久化的上下文重新发起构筑请求
6. WHEN 中断恢复的 LLM 请求成功完成后，THE Calibration_System SHALL 清除对应的中间状态数据
7. IF 中断恢复的 LLM 请求连续失败 3 次，THEN THE Calibration_System SHALL 放弃该次恢复、清除中间状态，并在日志中记录失败原因
8. WHEN 校准流程中 LLM 请求因网络错误失败时，THE Calibration_System SHALL 保留当前中间状态并允许用户稍后重试，不丢弃已完成的步骤
9. WHEN 构筑轮次因网络错误失败时，THE Calibration_System SHALL 将该构筑标记为待重试（pending），在下次应用启动或网络恢复时自动重试
10. IF 存在待重试的 Profiling_Round，THEN THE Calibration_System SHALL 不阻塞用户发起新的校准挑战（校准和构筑相互独立）
11. IF 中间状态数据损坏或无法反序列化，THEN THE Calibration_System SHALL 丢弃该中间状态并记录错误日志，恢复到正常可用状态
12. WHEN 中间状态被序列化为 JSON 再反序列化时，THE Calibration_System SHALL 产生与原始对象等价的结果（round-trip 一致性）

### 需求 13：自定义答案输入

**用户故事：** 作为 GHOSTYPE 用户，我希望在校准挑战中能够手动输入自定义答案，以便在 AI 提供的选项都不符合我的真实想法时，表达更准确的自我。

#### 验收标准

1. WHEN 校准挑战展示选项时，THE Calibration_System SHALL 在预设选项之外提供一个「自定义输入」入口
2. WHEN 用户选择「自定义输入」入口时，THE Calibration_System SHALL 展示一个文本输入框，允许用户输入自由文本答案
3. WHEN 用户提交自定义答案时，THE Calibration_System SHALL 将自定义文本作为用户选择传入分析 prompt，替代预设选项索引
4. WHEN 构建包含自定义答案的分析 prompt 时，THE Calibration_System SHALL 在 prompt 中明确标注该答案为用户自定义输入（而非从预设选项中选择），以便 LLM 进行更精准的人格分析
5. WHEN 用户提交空白或纯空格的自定义答案时，THE Calibration_System SHALL 阻止提交并提示用户输入有效内容
6. WHEN 自定义答案被记录到 Calibration_Record 时，THE Calibration_System SHALL 将 selectedOption 设置为 -1，并新增 customAnswer 字段存储用户输入的文本
7. THE Calibration_Record SHALL 包含可选的 customAnswer（自定义答案文本）字段，WHEN customAnswer 存在时表示用户使用了自定义输入而非预设选项
