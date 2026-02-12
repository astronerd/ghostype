# Ghost Morph 服务端接口文档

## 背景

GHOSTYPE 客户端新增了 Ghost Morph（动态 Skill 系统）。Skill 包括 Ghost Command、Ghost Twin、翻译、自定义技能等。

核心设计原则：**客户端完全控制 prompt 构建**。因为客户端掌握上下文信息（是否有选中文字、是否在可编辑区域、人格档案等），服务端只负责透传给 LLM。

## 接口总览

| 接口 | 状态 | 说明 |
|------|------|------|
| `POST /api/v1/llm/chat` | 不变 | polish / translate，服务端控制 prompt |
| `POST /api/v1/skill/execute` | **新增** | Skill 执行，客户端控制 prompt |
| `POST /api/v1/usage/report` | 不变 | 用量上报 |
| `GET /api/v1/user/profile` | 不变 | 用户配置 |
| `GET /api/v1/ghost-twin/status` | 不变 | Ghost Twin 状态 |
| `GET /api/v1/ghost-twin/challenge` | 不变 | 校准挑战 |
| `POST /api/v1/ghost-twin/challenge/answer` | 不变 | 提交校准答案 |

---

## 新增接口

### `POST /api/v1/skill/execute`

通用 Skill 执行接口。客户端负责构建完整的 system_prompt，服务端只负责调用 LLM 并返回结果。

#### 为什么不复用 `/api/v1/llm/chat`

`/api/v1/llm/chat` 的 prompt 逻辑由服务端控制（根据 mode/profile 注入不同的 system prompt）。但 Skill 系统需要客户端控制 prompt，原因：

1. **上下文行为**：客户端检测到 4 种上下文（直接输出 / 改写选中文字 / 解释选中文字 / 无输入），需要把上下文信息拼入 prompt
2. **Ghost Twin 人格档案**：存储在客户端本地，不上传服务端，客户端自己拼入 system_prompt
3. **Custom Skill**：用户自定义的 prompt 模板，完全由客户端管理

#### 请求

```
POST /api/v1/skill/execute
Content-Type: application/json
Authorization: Bearer {jwt_token}
X-Device-Id: {device_id}
```

```json
{
  "system_prompt": "你是一个万能助手。用户会用语音告诉你一个任务，请直接完成任务并输出结果。不要解释你在做什么，直接给出结果。",
  "message": "帮我写一封请假邮件，说明天身体不舒服",
  "context": {
    "type": "direct_output",
    "selected_text": null
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| system_prompt | string | ✅ | 客户端构建的完整 system prompt |
| message | string | ✅ | 用户语音转写文本 |
| context | object | ✅ | 客户端上下文信息 |
| context.type | string | ✅ | 上下文类型，见下表 |
| context.selected_text | string? | ❌ | 用户选中的文字（rewrite/explain 时有值） |

**context.type 枚举值：**

| 值 | 含义 | 客户端行为 |
|----|------|-----------|
| `direct_output` | 可编辑区域，无选中文字 | AI 结果直接插入光标位置 |
| `rewrite` | 可编辑区域，有选中文字 | AI 结果替换选中文字 |
| `explain` | 不可编辑区域，有选中文字 | AI 结果显示在悬浮卡片 |
| `no_input` | 不可编辑区域，无选中文字 | AI 结果显示在悬浮卡片 |

> 注意：context 信息是给服务端做日志/分析用的，服务端不需要根据 context.type 改变 LLM 调用逻辑。prompt 构建完全由客户端完成。

#### 成功响应

```
HTTP 200
```

```json
{
  "text": "尊敬的领导，我明天身体不太舒服，需要请假一天休息，望批准。谢谢。",
  "usage": {
    "input_tokens": 89,
    "output_tokens": 34
  }
}
```

响应格式与 `/api/v1/llm/chat` 完全一致。

| 字段 | 类型 | 说明 |
|------|------|------|
| text | string | LLM 生成的文本 |
| usage.input_tokens | int | 输入 token 数 |
| usage.output_tokens | int | 输出 token 数 |

#### 错误响应

与现有接口统一格式：

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "错误描述"
  }
}
```

| HTTP 状态码 | code | 说明 |
|------------|------|------|
| 401 | UNAUTHORIZED | JWT 无效或过期 |
| 429 | QUOTA_EXCEEDED | 额度超限 |
| 400 | INVALID_REQUEST | 请求体格式错误、system_prompt 或 message 为空 |
| 500 | INTERNAL_ERROR | 服务器内部错误 |
| 502 | UPSTREAM_ERROR | LLM 上游错误 |
| 504 | UPSTREAM_TIMEOUT | LLM 上游超时 |

#### 服务端实现要点

1. **纯透传**：将 system_prompt 作为 system message，message 作为 user message，直接调用 LLM
2. **额度计费**：与 `/api/v1/llm/chat` 共享额度池，按 token 计费
3. **日志记录**：记录 context.type 用于后续分析（哪种场景用得多）
4. **安全校验**：
   - system_prompt 长度限制（建议 max 4000 字符）
   - message 长度限制（建议 max 2000 字符）
   - 基本的内容安全过滤（与现有接口一致）

---

## 客户端调用示例

### Ghost Command

```json
{
  "system_prompt": "你是一个万能助手。用户会用语音告诉你一个任务，请直接完成任务并输出结果。不要解释你在做什么，直接给出结果。",
  "message": "帮我写一封请假邮件",
  "context": { "type": "direct_output", "selected_text": null }
}
```

### Ghost Twin（客户端从本地读取人格档案拼入）

```json
{
  "system_prompt": "你是用户的 Ghost Twin（数字分身）。以下是用户的人格档案：\n- 人格标签：直接、幽默、技术宅\n- 语气风格：口语化，偶尔用网络用语\n- 价值观：效率优先，讨厌形式主义\n\n请以用户的口吻和语言习惯生成回复。直接输出回复内容，不要解释。",
  "message": "帮我回一下老王，说今晚不去了",
  "context": { "type": "direct_output", "selected_text": null }
}
```

### Custom Skill（用户自定义 prompt）

```json
{
  "system_prompt": "你是一个代码审查专家。用户会给你一段代码，请指出问题并给出改进建议。",
  "message": "看看这段代码有什么问题",
  "context": { "type": "explain", "selected_text": "func foo() { let x = 1; return x }" }
}
```

### Ghost Command + 选中文字改写

```json
{
  "system_prompt": "你是一个万能助手。用户会用语音告诉你一个任务，请直接完成任务并输出结果。不要解释你在做什么，直接给出结果。\n\n用户当前选中了以下文字，请基于选中内容和用户指令进行处理：\n---\n这是一段需要改写的文字\n---",
  "message": "把这段话改得更正式一点",
  "context": { "type": "rewrite", "selected_text": "这是一段需要改写的文字" }
}
```

---

## 超时与重试

| 接口类型 | 超时时间 | 重试策略 |
|---------|---------|---------|
| `/api/v1/skill/execute` | 30 秒 | 500/502 自动重试 1 次 |
| `/api/v1/llm/chat` | 30 秒 | 500/502 自动重试 1 次 |
| 配置类接口 | 10 秒 | 500/502 自动重试 1 次 |

## 与现有接口的关系

```
┌─────────────────────────────────────────────┐
│  服务端控制 prompt                            │
│  POST /api/v1/llm/chat                      │
│  - mode=polish  → 服务端注入润色 prompt        │
│  - mode=translate → 服务端注入翻译 prompt      │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  客户端控制 prompt                            │
│  POST /api/v1/skill/execute                 │
│  - Ghost Command → 客户端拼固定 prompt        │
│  - Ghost Twin → 客户端拼人格档案 prompt        │
│  - Custom Skill → 客户端拼用户自定义 prompt    │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  纯本地，不走网络                              │
│  - Memo（随心记）→ 直接存 CoreData            │
└─────────────────────────────────────────────┘
```
