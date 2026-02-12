# Ghost Morph 服务端接口文档

## 背景

GHOSTYPE 客户端新增了 Ghost Morph（动态 Skill 系统），将原来硬编码的 InputMode（polish/translate/memo）替换为可扩展的 Skill 架构。Skill 的存储和管理完全在客户端本地完成，服务端只需要关注 API 调用。

## 对现有接口的影响

### 无需修改的接口

以下接口客户端调用方式完全不变，服务端无需任何改动：

| 接口 | 说明 |
|------|------|
| `POST /api/v1/llm/chat` (mode=polish) | 润色，不变 |
| `POST /api/v1/llm/chat` (mode=translate) | 翻译，不变 |
| `POST /api/v1/usage/report` | 用量上报，不变 |
| `GET /api/v1/user/profile` | 用户配置，不变 |
| `GET /api/v1/ghost-twin/status` | Ghost Twin 状态，不变 |
| `GET /api/v1/ghost-twin/challenge` | 校准挑战，不变 |
| `POST /api/v1/ghost-twin/challenge/answer` | 提交校准答案，不变 |

### 复用现有接口的新功能

以下功能通过现有 `/api/v1/llm/chat` 接口实现，服务端无需新增端点：

**Ghost Command（语音指令）**
- 客户端发送 `mode: "polish"`, `profile: "custom"`, `custom_prompt: "你是一个万能助手..."` 
- 服务端视角就是一个普通的 custom profile 润色请求，已支持

**Custom Skill（用户自定义技能）**
- 客户端发送 `mode: "polish"`, `profile: "custom"`, `custom_prompt: "{用户自定义的prompt}"`
- 同上，已支持

---

## 需要新增的接口

### `POST /api/v1/ghost-twin/chat`

Ghost Twin 对话：以用户的口吻和语言习惯生成回复。

#### 使用场景

用户按住快捷键说话，选择 "Call Ghost Twin" 技能后，客户端将语音转写文本发送到此端点。服务端需要读取该用户的 Ghost Twin 人格档案（personality profile），作为 system prompt 的一部分，让 LLM 以用户的口吻生成回复。

#### 请求

```
POST /api/v1/ghost-twin/chat
Content-Type: application/json
Authorization: Bearer {jwt_token}
X-Device-Id: {device_id}
```

```json
{
  "message": "帮我回一下老王，说今晚不去了"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| message | string | ✅ | 用户语音转写文本，可能包含指令和上下文 |

#### 成功响应

```
HTTP 200
```

```json
{
  "text": "老王，今晚累挂了，改天约，你们玩得开心。",
  "usage": {
    "input_tokens": 156,
    "output_tokens": 23
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| text | string | Ghost Twin 生成的回复文本 |
| usage.input_tokens | int | 输入 token 数 |
| usage.output_tokens | int | 输出 token 数 |

响应格式与 `/api/v1/llm/chat` 完全一致（复用 `GhostypeResponse` 结构）。

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
| 400 | INVALID_REQUEST | 请求体格式错误或 message 为空 |
| 500 | INTERNAL_ERROR | 服务器内部错误 |
| 502 | UPSTREAM_ERROR | LLM 上游错误 |
| 504 | UPSTREAM_TIMEOUT | LLM 上游超时 |

#### 服务端实现要点

1. **读取用户的 Ghost Twin 人格档案**
   - 从数据库获取该用户通过校准挑战积累的 personality profile
   - 包括：人格标签（personality_tags）、价值观偏好、语气风格等
   
2. **构建 system prompt**
   - 将人格档案注入 system prompt，指导 LLM 以用户的口吻回复
   - 参考 prompt 结构：
     ```
     你是用户的 Ghost Twin（数字分身）。
     以下是用户的人格档案：
     - 人格标签：{personality_tags}
     - 语气风格：{tone_style}
     - 价值观偏好：{values}
     
     请以用户的口吻和语言习惯，根据用户的指令生成回复。
     直接输出回复内容，不要解释。
     ```

3. **调用 LLM**
   - 将 system prompt + 用户 message 发送给 LLM
   - 返回生成的文本

4. **额度计费**
   - 与 `/api/v1/llm/chat` 共享额度池
   - 计入 usage 统计

5. **Ghost Twin 等级检查（可选）**
   - 如果用户 Ghost Twin 等级过低（如 Lv.1），人格档案可能很空
   - 可以返回一个通用风格的回复，或在 text 中提示用户继续校准

#### 与 `/api/v1/llm/chat` 的区别

| 维度 | `/api/v1/llm/chat` | `/api/v1/ghost-twin/chat` |
|------|--------------------|-----------------------------|
| system prompt | 由 mode/profile 决定 | 由用户人格档案决定 |
| 个性化 | 无（或 custom_prompt） | 基于校准数据深度个性化 |
| 数据依赖 | 无 | 需要读取 Ghost Twin 人格档案 |
| 响应格式 | `{ text, usage }` | `{ text, usage }`（相同） |

---

## 客户端超时配置

| 接口类型 | 超时时间 |
|---------|---------|
| LLM 类（chat/ghost-twin/chat） | 30 秒 |
| 配置类（profile/status/challenge） | 10 秒 |

## 客户端重试策略

- HTTP 500/502：自动重试 1 次
- 其他错误码：不重试，直接返回错误
