---
inclusion: auto
---

# GHOSTYPE Skill 开发操作规范

本文档是 AI 助手在 GHOSTYPE 项目中开发 Skill 时必须遵守的操作规范。
基于 Anthropic Agent Skills 开放标准的核心原则，适配 GHOSTYPE 的架构。

参考来源：
- [Anthropic 官方 Agent Skills 工程博客](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- [微软 .NET Skills Executor 实现](https://devblogs.microsoft.com/foundry/dotnet-ai-skills-executor-azure-openai-mcp/)
- [Claude Skills 第一性原理深度分析](https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/)

---

## 〇、GHOSTYPE 与 Claude 官方的关键区别

GHOSTYPE 的 Skill 系统借鉴 Claude Agent Skills 的核心思想，但在以下方面做了适配：

| 维度 | Claude 官方 | GHOSTYPE |
|------|------------|----------|
| Skill 选择 | AI 自动判断（渐进式披露：先加载 name+description，匹配后再加载完整 SKILL.md） | 用户手动选择，无需 AI 判断，不使用渐进式披露 |
| Tool Calling | Claude 原生 Tool Use API（结构化 tool_use block） | Prompt 内 JSON 约定：`{"tool": "xxx", "content": "xxx"}` |
| System Prompt 加载 | 按需加载，skill 被选中时才注入 | SKILL.md 的 Markdown body 完整发送给 LLM，无分级加载 |
| UI 元数据 | 存在 SKILL.md frontmatter 中（name, description, allowed-tools 等） | UI 元数据（icon、color、快捷键）与语义内容物理分离，存储在 `SkillMetadataStore`（JSON） |
| Meta-Skill | 无（skill 由用户或 AI 直接创建） | 有 `builtin-prompt-generator`：一个生成 system prompt 的 meta skill，用于用户自建 skill |

这些区别是 GHOSTYPE 作为语音输入工具的产品特性决定的，不是偏差。核心原则（SKILL.md 唯一真相源、执行器零业务逻辑、模板变量注入）与 Claude 官方一致。

---

## 一、三条铁律

### 铁律 1：SKILL.md 是唯一真相源（Single Source of Truth）

所有 Skill 的 prompt 内容只存在于 `SKILL.md` 文件中。Swift 代码中不包含任何 prompt 文本。

- 内置 Skill 的 SKILL.md 存放在 `default_skills/{skill-id}/SKILL.md`
- 运行时 Skill 存放在 `~/Library/Application Support/GHOSTYPE/skills/{skill-id}/SKILL.md`
- `SkillManager.ensureBuiltinSkills()` 只负责将 `default_skills/` 目录下的文件复制到运行时目录，不生成内容
- 修改 Skill 的 prompt = 修改对应的 SKILL.md 文件，不改任何 Swift 代码

### 铁律 2：执行器零业务逻辑（Zero Business Logic in Executor）

`SkillExecutor` 是一个通用管道，对所有 Skill 一视同仁。它的职责是：

```
加载 SKILL.md → TemplateEngine 变量替换 → 发给 LLM → 解析 tool call JSON → ToolRegistry 分发
```

执行器不关心当前执行的是哪个 Skill。换一个 SKILL.md，行为就变了，执行器代码不变。

微软 .NET 实现的原话：「The orchestrator contains zero business logic. Swap the skill, and the same executor does completely different work.」

### 铁律 3：运行时数据通过模板变量注入（Context Injection via Templates）

当 Skill 需要运行时数据（用户档案、设备信息、选中文本等）时，通过 `TemplateEngine` 的 `{{context.xxx}}` 变量注入，不在执行器中按 skill ID 做特殊处理。

```
SKILL.md 中写：{{context.ghost_profile}}
TemplateEngine 在执行前替换为实际数据
执行器不知道也不关心这个变量的存在
```

---

## 二、禁止事项

### ❌ 绝对禁止

1. **在 Swift 代码中写 prompt 字符串**
   - 不允许在 `SkillManager`、`SkillExecutor` 或任何 Swift 文件中出现 prompt 内容
   - 所有 prompt 只存在于 SKILL.md 文件中

2. **在 SkillExecutor 中按 skill ID 做分支**
   - 不允许 `if skill.id == SkillModel.builtinXxxId` 这样的代码
   - 如果某个 Skill 需要特殊数据，通过模板变量解决，不通过执行器分支

3. **在执行器中硬编码用户消息格式**
   - 不允许在 `buildUserMessage` 中写死中文格式字符串
   - 用户消息的拼装格式应由 SKILL.md 的 config 或 frontmatter 字段控制

4. **在代码中覆盖写入 SKILL.md**
   - `ensureBuiltinSkills()` 不应该从代码生成 SKILL.md 内容再写入磁盘
   - 应该从 Bundle 资源复制文件，或直接读取 `default_skills/` 目录

### ⚠️ 避免

1. 在 SKILL.md 中写 UI 元数据（icon、color、快捷键）— 这些属于 `SkillMetadataStore`
2. 在 SKILL.md 的 config 中存储敏感信息（API Key 等）— config 会写入磁盘
3. 假设 LLM 一定返回 JSON — `parseToolCall` 必须有 fallback 到纯文本的逻辑

---

## 三、添加内置 Skill 的标准流程

当用户说「加一个新的内置 Skill」时，按以下步骤操作：

### 步骤 1：创建 SKILL.md 文件

在 `AIInputMethod/default_skills/{skill-id}/` 目录下创建 `SKILL.md`：

```markdown
---
name: "Skill 名称"
description: "一句话描述功能和适用场景"
allowed_tools:
  - provide_text
config:
  key1: "value1"
---

# Role
一句话定义角色。

# Constraints
1. 直接给出结果，不要解释过程
2. 不要输出客套话
3. [具体约束]

# Available Tools
- **provide_text**: 输出生成的文本内容

# Tool Calling Format
使用 JSON 格式调用工具：
{"tool": "provide_text", "content": "生成的内容"}

# Examples

## Example 1
**User:** "用户输入示例"
**Response:**
{"tool": "provide_text", "content": "期望输出"}
```

### 步骤 2：注册 Skill ID

在 `SkillModel.swift` 中添加静态 ID 常量：

```swift
static let builtinNewSkillId = "builtin-new-skill"
```

### 步骤 3：注册元数据

在 `SkillManager.ensureBuiltinSkills()` 的 `builtinDefinitions` 数组中添加条目。
注意：`parseResult` 中的 prompt 内容不在这里写，只注册元数据（icon、color、快捷键、isBuiltin、isInternal）。

### 步骤 4：注册本地化名称（如需要）

在 `Strings.swift` / `Strings+Chinese.swift` / `Strings+English.swift` 中添加 `L.Skill.builtinNewSkillName` 和 `L.Skill.builtinNewSkillDesc`。

### 步骤 5：如需新 Tool

1. 在 `ToolRegistry.registerBuiltins()` 中注册 handler
2. 在 `ToolOutputHandler` 协议中添加对应方法
3. 在 SKILL.md 的 `allowed_tools` 和 prompt 中声明

### 不需要做的事

- ❌ 不需要在 Swift 代码中写 prompt 字符串
- ❌ 不需要修改 `SkillExecutor`
- ❌ 不需要修改 `SkillFileParser`

---

## 四、执行器扩展规范

### 场景：Skill 需要运行时数据

例如 Ghost Twin 需要用户的人格档案。

**正确做法：扩展 TemplateEngine 的 context provider**

1. 在 SKILL.md 中使用 `{{context.ghost_profile}}` 占位符
2. 在 `TemplateEngine` 中注册 context provider，运行时解析 `{{context.xxx}}` 变量
3. 执行器调用 `TemplateEngine.resolve()` 时自动替换，无需感知具体 skill

**错误做法：在执行器中加 if 分支**

```swift
// ❌ 绝对不要这样做
if skill.id == SkillModel.builtinGhostTwinId {
    finalPrompt += personalityContext
}
```

### 场景：需要新的 Tool

1. 在 `ToolRegistry` 中注册
2. 在 `ToolOutputHandler` 协议中添加方法
3. 在 SKILL.md 中声明和说明
4. 不修改 `SkillExecutor`

### 场景：需要新的 frontmatter 字段

1. 在 `SkillFileParser` 中添加解析逻辑
2. 在 `SkillModel` 中添加对应属性
3. 在 `SkillManager` 的 `loadAllSkills()` 中传递该字段
4. 不修改 `SkillExecutor`（除非是通用管道行为，如 API endpoint 选择）

---

## 五、SKILL.md 文件格式

### Frontmatter 字段

| 字段 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `name` | ✅ | string | Skill 显示名称 |
| `description` | ✅ | string | 功能描述 |
| `user_prompt` | ❌ | string | 用户创建 skill 时的原始指令 |
| `allowed_tools` | ❌ | string[] | Tool 白名单，默认 `["provide_text"]` |
| `config` | ❌ | map | 模板变量，用于 `{{config.xxx}}` 替换 |

### Prompt 标准结构（6 段式）

```
# Role           — 一句话角色定位
# Constraints    — 3-5 条行为约束（编号列表）
# Available Tools — 可用工具及用途
# Tool Calling Format — JSON 调用格式示例
# Output Format  — 输出格式模板（可选）
# Examples       — 2-3 个 input/output 示例
```

### Prompt 编写原则

1. 零废话：AI 不输出客套话，直接给结果
2. 零解释：不解释过程，用户要的是结果
3. 格式一致：所有输出通过 tool call JSON 返回
4. 示例驱动：具体的 input/output 示例比长篇描述更有效
5. 约束明确：每条约束一个具体规则，用编号列表
6. 中文撰写（除非 skill 明确面向英文场景）

### 内置 Tool 清单

| Tool | 用途 |
|------|------|
| `provide_text` | 向用户提供文字输出（直接输入/浮窗/改写） |
| `save_memo` | 保存笔记到用户笔记本 |

### Tool Calling 协议

GHOSTYPE 使用 prompt 内 JSON tool calling（非 Claude 原生 tool use）：

```json
{"tool": "tool_name", "content": "输出内容"}
```

---

## 六、数据分离原则

| 存储位置 | 内容 | 格式 |
|---------|------|------|
| `SKILL.md` frontmatter | name, description, allowed_tools, config | YAML |
| `SKILL.md` body | system prompt（AI 执行指令） | Markdown |
| `SkillMetadataStore` | icon, colorHex, modifierKey, isBuiltin, isInternal | JSON |
| `TemplateEngine` context | 运行时数据（用户档案、选中文本等） | 代码注入 |

铁律：SKILL.md 只存语义内容，不存 UI 元数据。执行器只做管道，不存业务逻辑。

---

## 七、当前技术债务

以下是现有代码中违反本规范的地方，作为未来重构参考：

### 债务 1：Prompt 双写（严重）

- 位置：`SkillManager.ensureBuiltinSkills()`
- 问题：~300 行硬编码 prompt 字符串，每次启动覆盖 SKILL.md
- 影响：`default_skills/xxx/SKILL.md` 文件是假的，改了没用
- 修复方向：删除代码中的 prompt 字符串，改为从 `default_skills/` 复制文件到运行时目录

### 债务 2：执行器中的 Ghost Twin 特殊处理（中等）

- 位置：`SkillExecutor.execute()` 第 1.5 步
- 问题：`if skill.id == SkillModel.builtinGhostTwinId` 硬编码注入人格档案
- 修复方向：扩展 TemplateEngine 支持 `{{context.ghost_profile}}`，在 SKILL.md 中使用

### 债务 3：用户消息格式硬编码（轻微）

- 位置：`SkillExecutor.buildUserMessage()`
- 问题：中文格式字符串硬编码（"用户语音指令：" "当前选中的文本："）
- 修复方向：消息模板移入 SKILL.md 的 config 或新增 frontmatter 字段
