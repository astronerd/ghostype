# 需求文档：Skill 系统重构

## 简介

GHOSTYPE 当前的 Skill 系统存在根本性的架构问题：`SkillType` 枚举硬编码了所有 Skill 类型，`SkillRouter` 用 switch-case 分发到不同的 API 调用方法，每新增一个 Skill 类型都需要修改路由器和 API 客户端代码。本次重构参考 Claude Skills 的设计理念，将 Skill 重新定义为"Agent"——每个 Skill 本质上就是一个 prompt + 允许使用的工具列表，通过统一的执行管道运行，无需修改核心代码即可扩展新功能。

核心设计理念（对齐 Claude Skills + 互联网兼容）：
- SKILL.md 只包含语义内容：`name`（必填）、`description`（必填）、`allowed_tools`（可选）、`config`（可选），Markdown body = 系统提示词
- UI 元数据（emoji 图标、颜色、快捷键绑定）由 GHOSTYPE 程序内部管理，不写入 SKILL.md
- 这样 SKILL.md 格式与互联网上绝大多数 Skill 格式保持兼容
- 添加新功能 = 新建 SKILL.md + 可选地新增 Tool，执行引擎不需要改

服务端 API 现状：
- `POST /api/v1/llm/chat`：服务端控制 prompt（polish/translate），保持不变
- `POST /api/v1/skill/execute`：客户端控制 prompt（已有接口），接受 `system_prompt` + `message` + `context`
- 新架构下所有自定义 Skill 统一走 `/api/v1/skill/execute`

## 术语表

- **Skill**：一个可执行的 AI 能力单元，由 SKILL.md 文件定义，本质上是一个 Agent（prompt + tools）
- **SKILL.md**：Skill 的定义文件，使用 YAML frontmatter + Markdown body 格式，只包含语义内容，不包含 UI 元数据
- **SkillExecutor**：统一的 Skill 执行引擎，替代当前的 SkillRouter，所有 Skill 走同一个执行管道
- **SkillMetadata**：Skill 的 UI 元数据（emoji 图标、颜色、快捷键绑定），由程序内部管理，存储在 UserDefaults 或独立配置文件中
- **Tool**：Skill 执行后的输出动作，如 insert_text（插入文字）、save_memo（保存笔记）、floating_card（悬浮卡片）等
- **ToolRegistry**：工具注册表，管理所有可用 Tool 的注册和查找
- **GhostypeAPIClient**：GHOSTYPE 后端 API 客户端
- **SkillManager**：Skill 文件的加载、CRUD 和快捷键绑定管理器
- **SkillFileParser**：SKILL.md 文件的解析器和序列化器
- **ContextBehavior**：上下文行为检测结果（directOutput / rewrite / explain / noInput）

## 需求

### 需求 1：简化 SKILL.md 文件格式（对齐互联网通用格式）

**用户故事：** 作为 Skill 创建者，我希望 SKILL.md 格式极简且与互联网通用 Skill 格式兼容，只包含语义内容，不包含任何 UI 或应用特定的元数据。

#### 验收标准

1. THE SkillFileParser SHALL 仅要求 `name` 和 `description` 作为 YAML frontmatter 的必填字段
2. THE SkillFileParser SHALL 将 Markdown body 部分作为 Skill 的系统提示词（system_prompt）
3. THE SkillFileParser SHALL 支持以下可选 YAML 字段：`allowed_tools`、`config`
4. THE SKILL.md SHALL 不包含任何 UI 元数据（emoji 图标、颜色、快捷键绑定等），这些由程序内部管理
5. WHEN SKILL.md 中包含 `config` 字段时，THE SkillFileParser SHALL 将其解析为键值对配置参数
6. WHEN SKILL.md 中包含 `allowed_tools` 字段时，THE SkillFileParser SHALL 将其解析为字符串数组
7. THE SkillFileParser SHALL 使用 Skill 文件所在目录名作为 Skill 的唯一标识（id）
8. THE SkillFileParser SHALL 对 SKILL.md 执行解析后再序列化，产生的 SkillModel 与原始解析结果等价（round-trip 一致性）

### 需求 2：Skill UI 元数据管理

**用户故事：** 作为用户，我希望能在 GHOSTYPE 应用内为 Skill 设置 emoji 图标、颜色和快捷键，这些设置保存在程序内部，不污染 SKILL.md 文件。

#### 验收标准

1. THE SkillMetadataStore SHALL 为每个 Skill 存储以下 UI 元数据：emoji 图标、颜色（hex）、快捷键绑定（keyCode + isSystemModifier + displayName）、是否为内置 Skill
2. THE SkillMetadataStore SHALL 使用 Skill 的目录名（id）作为元数据的关联键
3. WHEN 用户在 Dashboard 中修改 Skill 的图标、颜色或快捷键时，THE SkillMetadataStore SHALL 仅更新内部存储，不修改 SKILL.md 文件
4. WHEN 加载一个没有元数据记录的新 Skill 时，THE SkillMetadataStore SHALL 为其生成默认元数据（默认 emoji、默认颜色、无快捷键绑定）
5. THE SkillModel SHALL 合并 SKILL.md 的语义内容和 SkillMetadataStore 的 UI 元数据，提供完整的 Skill 信息

### 需求 3：统一执行管道（SkillExecutor）

**用户故事：** 作为开发者，我希望所有 Skill 走同一个执行管道，不再需要为每种 Skill 类型编写不同的 API 调用逻辑。

#### 验收标准

1. THE SkillExecutor SHALL 为所有 Skill 提供统一的 `execute(skill:speechText:context:)` 方法
2. WHEN 执行一个 Skill 时，THE SkillExecutor SHALL 使用 Skill 的 system_prompt 作为系统提示词，用户语音文本作为用户消息，调用 `POST /api/v1/skill/execute` 端点
3. WHEN API 返回结果后，THE SkillExecutor SHALL 根据 Skill 的 `allowed_tools` 列表中的第一个工具和当前 ContextBehavior 决定输出方式
4. WHEN Skill 的 `allowed_tools` 仅包含 `save_memo` 时，THE SkillExecutor SHALL 直接保存语音文本到 CoreData 而不调用 API
5. IF API 调用失败，THEN THE SkillExecutor SHALL 在 directOutput/rewrite 场景下回退插入原始语音文本，在 explain/noInput 场景下通过错误回调通知调用方
6. WHEN 执行 Skill 前，THE SkillExecutor SHALL 对 system_prompt 中的模板变量执行替换
7. WHEN ContextBehavior 为 rewrite 或 explain 时，THE SkillExecutor SHALL 将选中文字信息拼入 prompt

### 需求 4：Tool 工具系统

**用户故事：** 作为开发者，我希望 Skill 的输出处理通过可注册的 Tool 系统实现，方便未来扩展新的输出方式。

#### 验收标准

1. THE ToolRegistry SHALL 提供 `register(name:handler:)` 方法注册新的 Tool
2. THE ToolRegistry SHALL 提供 `execute(name:context:)` 方法执行指定名称的 Tool
3. WHEN 执行一个未注册的 Tool 名称时，THE ToolRegistry SHALL 返回描述性错误
4. THE ToolRegistry SHALL 在应用启动时注册以下内置 Tool：`insert_text`、`save_memo`、`floating_card`、`clipboard`
5. WHEN `insert_text` Tool 被执行时，THE Tool SHALL 将文本插入到当前光标位置
6. WHEN `save_memo` Tool 被执行时，THE Tool SHALL 将文本保存到 CoreData 笔记记录
7. WHEN `floating_card` Tool 被执行时，THE Tool SHALL 显示包含 AI 结果的悬浮卡片
8. WHEN `clipboard` Tool 被执行时，THE Tool SHALL 将文本复制到系统剪贴板

### 需求 5：消除 SkillType 枚举和 SkillRouter

**用户故事：** 作为开发者，我希望移除硬编码的 SkillType 枚举和 switch-case 路由，使新增 Skill 只需创建 SKILL.md 文件。

#### 验收标准

1. THE SkillModel SHALL 不再包含 `skillType` 枚举字段，改为通过 `allowed_tools` 和 `config` 描述 Skill 的行为
2. WHEN 添加一个新 Skill 时，THE SkillManager SHALL 仅需要在 skills 目录下创建新的 SKILL.md 文件，无需修改任何 Swift 源代码
3. THE SkillExecutor SHALL 替代 SkillRouter，成为唯一的 Skill 执行入口
4. WHEN AppDelegate 调用 `processWithSkill()` 时，THE AppDelegate SHALL 通过 SkillExecutor 执行 Skill，不再使用 SkillRouter

### 需求 6：翻译 Skill 参数化

**用户故事：** 作为用户，我希望翻译功能是一个可配置源语言和目标语言的 Skill，而不是多个硬编码的语言对。

#### 验收标准

1. THE 翻译 Skill SHALL 通过 `config` 字段中的 `source_language` 和 `target_language` 参数配置语言对
2. WHEN 翻译 Skill 的 system_prompt 中包含 `{{config.source_language}}` 和 `{{config.target_language}}` 占位符时，THE SkillExecutor SHALL 用 config 中的实际值替换占位符
3. WHEN 用户在 Dashboard 中修改翻译语言设置时，THE SkillViewModel SHALL 更新 Skill 的 config 参数并持久化到 SKILL.md 文件
4. THE 翻译 Skill SHALL 不再依赖 `TranslateLanguage` 枚举中的硬编码 prompt，改为在 system_prompt 中定义翻译指令

### 需求 7：向后兼容与迁移

**用户故事：** 作为已有用户，我希望升级后我的自定义 Skill 文件能自动迁移到新格式，不丢失任何配置。

#### 验收标准

1. WHEN 加载一个包含旧格式字段（`skill_type`、`is_editable`、`behavior_config`、`icon`、`color_hex`、`modifier_key_*`）的 SKILL.md 时，THE SkillFileParser SHALL 成功解析并映射到新的数据模型
2. WHEN 旧格式 SKILL.md 中 `skill_type` 为 `translate` 时，THE 迁移服务 SHALL 将 `behavior_config.translate_language` 转换为 `config.source_language` 和 `config.target_language`
3. WHEN 旧格式 SKILL.md 中 `skill_type` 为 `memo` 时，THE 迁移服务 SHALL 将 `allowed_tools` 设置为 `["save_memo"]`
4. WHEN 旧格式 SKILL.md 中 `skill_type` 为 `ghostTwin` 时，THE 迁移服务 SHALL 在 config 中设置 `api_endpoint` 为 `/api/v1/ghost-twin/chat`
5. WHEN 旧格式 SKILL.md 中 `skill_type` 为 `custom` 时，THE 迁移服务 SHALL 将 `allowed_tools` 设置为 `["insert_text"]`
6. WHEN 旧格式 SKILL.md 中包含 UI 元数据（`icon`、`color_hex`、`modifier_key_*`）时，THE 迁移服务 SHALL 将这些字段提取到 SkillMetadataStore 中
7. THE 迁移服务 SHALL 在迁移完成后将旧格式 SKILL.md 文件重写为新格式（仅保留语义字段）
8. THE 迁移服务 SHALL 是幂等的，多次执行产生相同结果

### 需求 8：Prompt 模板变量替换

**用户故事：** 作为 Skill 创建者，我希望在 system_prompt 中使用变量占位符，让 Skill 在执行时动态填充配置参数。

#### 验收标准

1. WHEN system_prompt 中包含 `{{config.xxx}}` 格式的占位符时，THE SkillExecutor SHALL 用 Skill config 中对应 key 的值替换占位符
2. WHEN system_prompt 中包含未在 config 中定义的占位符时，THE SkillExecutor SHALL 保留占位符原文不做替换
3. THE SkillExecutor SHALL 在构建 API 请求前完成所有变量替换

### 需求 9：API 客户端适配

**用户故事：** 作为开发者，我希望 GhostypeAPIClient 支持调用 `/api/v1/skill/execute` 端点，为 SkillExecutor 提供统一的 API 调用能力。

#### 验收标准

1. THE GhostypeAPIClient SHALL 提供 `executeSkill(systemPrompt:message:context:)` 方法，调用 `POST /api/v1/skill/execute` 端点
2. WHEN 调用 `executeSkill` 方法时，THE GhostypeAPIClient SHALL 将 system_prompt、message 和 context（type + selected_text）组装为请求体
3. THE GhostypeAPIClient SHALL 保留现有的 `polish()`、`translate()` 方法不变，润色和翻译继续走 `/api/v1/llm/chat` 端点
4. WHEN Skill 的 config 中包含 `api_endpoint` 时，THE GhostypeAPIClient SHALL 使用指定的端点替代默认的 `/api/v1/skill/execute`
