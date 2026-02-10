# Ghost Twin API 需求文档

> **文档版本**: v1.0
> **输出时间**: 客户端 UI 开发完成后、联调前
> **适用范围**: GHOSTYPE（鬼才打字）Ghost Twin 孵化室后端接口

---

## ⚠️ 安全声明

> **所有 Prompt 内容和人格档案（Personality Profile）完整数据仅存在于服务端，客户端永远不接触。**
>
> - 客户端仅通过 API 获取人格档案的**摘要信息**（如特征标签列表 `personality_tags`），不获取完整档案内容
> - 所有 LLM 调用（校准挑战生成、人格档案更新、阶段性总结）均在服务端执行
> - 客户端不包含任何 Prompt 模板，仅负责展示题目和提交答案
> - 人格档案的完整内容仅在服务端用于 Prompt 构建，永远不传输到客户端（隐私保护 + 核心技术保护）

---

## 1. 端点定义

### 1.1 GET /api/v1/ghost-twin/status

获取用户 Ghost Twin 的当前状态，包括等级、经验值、人格特征标签等。

**认证**: 需要 `Authorization: Bearer <JWT>` + `X-Device-Id` Header

**请求**: 无请求体

**响应 JSON Schema**:

```json
{
  "type": "object",
  "required": ["level", "total_xp", "current_level_xp", "personality_tags", "challenges_remaining_today", "personality_profile_version"],
  "properties": {
    "level": {
      "type": "integer",
      "minimum": 1,
      "maximum": 10,
      "description": "当前等级 (1~10)"
    },
    "total_xp": {
      "type": "integer",
      "minimum": 0,
      "description": "总经验值（打字 XP + 校准 XP 累计）"
    },
    "current_level_xp": {
      "type": "integer",
      "minimum": 0,
      "maximum": 9999,
      "description": "当前等级内的经验值 (0~9999)，达到 10000 时升级"
    },
    "personality_tags": {
      "type": "array",
      "items": { "type": "string" },
      "description": "已捕捉的人格特征标签列表，如 [\"直接\", \"效率至上\", \"冷幽默\"]"
    },
    "challenges_remaining_today": {
      "type": "integer",
      "minimum": 0,
      "maximum": 3,
      "description": "今日剩余校准挑战次数（每日上限 3 次）"
    },
    "personality_profile_version": {
      "type": "integer",
      "minimum": 0,
      "description": "人格档案版本号，每次更新递增"
    }
  }
}
```

**响应示例**:

```json
{
  "level": 3,
  "total_xp": 25800,
  "current_level_xp": 5800,
  "personality_tags": ["直接", "效率至上", "冷幽默"],
  "challenges_remaining_today": 2,
  "personality_profile_version": 12
}
```

**错误响应**:

| HTTP 状态码 | 错误码 | 说明 |
|-------------|--------|------|
| 401 | `UNAUTHORIZED` | JWT 无效或过期 |
| 500 | `INTERNAL_ERROR` | 服务器内部错误 |

---

### 1.2 GET /api/v1/ghost-twin/challenge

获取当日校准挑战。服务端基于用户当前等级和人格档案版本，调用 LLM 生成情境问答题。

**认证**: 需要 `Authorization: Bearer <JWT>` + `X-Device-Id` Header

**请求**: 无请求体

**服务端逻辑**:
1. 检查用户今日剩余挑战次数，若为 0 则返回 429
2. 根据用户当前等级和人格档案完整度，选择挑战类型：
   - Lv.1~3（形层校准）：优先 `reverse_turing`（找鬼游戏）
   - Lv.4~6（神层校准）：优先 `dilemma`（灵魂拷问）
   - Lv.7~10（法层校准）：优先 `prediction`（预判赌局）
3. 调用 LLM（使用「校准挑战生成 Prompt」，见第 3.1 节）生成题目
4. 返回生成的挑战

**响应 JSON Schema**:

```json
{
  "type": "object",
  "required": ["id", "type", "scenario", "options", "xp_reward"],
  "properties": {
    "id": {
      "type": "string",
      "description": "挑战唯一 ID (UUID)"
    },
    "type": {
      "type": "string",
      "enum": ["dilemma", "reverse_turing", "prediction"],
      "description": "挑战类型：dilemma=灵魂拷问, reverse_turing=找鬼游戏, prediction=预判赌局"
    },
    "scenario": {
      "type": "string",
      "description": "场景描述文本"
    },
    "options": {
      "type": "array",
      "items": { "type": "string" },
      "minItems": 2,
      "maxItems": 3,
      "description": "2~3 个选项文本"
    },
    "xp_reward": {
      "type": "integer",
      "description": "该类型挑战的 XP 奖励（dilemma=500, reverse_turing=300, prediction=200）"
    }
  }
}
```

**响应示例（灵魂拷问 / Dilemma）**:

```json
{
  "id": "ch_a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "dilemma",
  "scenario": "你的好朋友在群里发了一条明显错误的观点，还@了你让你表态。群里有 50 多人在看。你会怎么做？",
  "options": [
    "直接指出错误，附上论据",
    "私聊告诉他，群里给个模糊回应",
    "假装没看到，过几个小时再说"
  ],
  "xp_reward": 500
}
```

**响应示例（找鬼游戏 / Reverse Turing）**:

```json
{
  "id": "ch_b2c3d4e5-f6a7-8901-bcde-f12345678901",
  "type": "reverse_turing",
  "scenario": "以下三段回复都是对「周末要不要一起吃饭」的回应，哪一段最像你会说的话？",
  "options": [
    "行啊，吃啥？你定地方我来",
    "周末看情况吧，到时候再说~",
    "可以啊！好久没聚了，我来找个好地方"
  ],
  "xp_reward": 300
}
```

**响应示例（预判赌局 / Prediction）**:

```json
{
  "id": "ch_c3d4e5f6-a7b8-9012-cdef-123456789012",
  "type": "prediction",
  "scenario": "你正在写一封重要的工作邮件，开头是「关于上次会议讨论的方案，我认为……」，你最可能接下来写什么？",
  "options": [
    "我们应该直接采用方案 A，理由如下",
    "有几个点需要再讨论一下",
    "整体方向没问题，但细节上我有一些建议"
  ],
  "xp_reward": 200
}
```

**错误响应**:

| HTTP 状态码 | 错误码 | 说明 |
|-------------|--------|------|
| 401 | `UNAUTHORIZED` | JWT 无效或过期 |
| 429 | `DAILY_LIMIT_REACHED` | 今日校准挑战次数已用完 |
| 500 | `INTERNAL_ERROR` | 服务器内部错误（含 LLM 调用失败） |

---

### 1.3 POST /api/v1/ghost-twin/challenge/answer

提交校准挑战的答案。服务端处理答案后更新人格档案并返回 XP 奖励。

**认证**: 需要 `Authorization: Bearer <JWT>` + `X-Device-Id` Header

**请求 JSON Schema**:

```json
{
  "type": "object",
  "required": ["challenge_id", "selected_option"],
  "properties": {
    "challenge_id": {
      "type": "string",
      "description": "挑战 ID，来自 GET /challenge 响应的 id 字段"
    },
    "selected_option": {
      "type": "integer",
      "minimum": 0,
      "maximum": 2,
      "description": "用户选择的选项索引（0-based）"
    }
  }
}
```

**请求示例**:

```json
{
  "challenge_id": "ch_a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "selected_option": 0
}
```

**服务端逻辑**:
1. 验证 `challenge_id` 有效且属于当前用户
2. 验证 `selected_option` 在该挑战的选项范围内
3. 根据挑战类型计算 XP 奖励（dilemma=500, reverse_turing=300, prediction=200）
4. 累加 XP 到用户总经验值，检查是否触发升级
5. 调用 LLM（使用「人格档案增量更新 Prompt」，见第 3.2 节）更新人格档案
6. 如果触发升级，额外调用 LLM（使用「人格档案阶段性总结 Prompt」，见第 3.3 节）
7. 生成 Ghost 的俏皮反馈语（可在增量更新 Prompt 中一并生成）
8. 递减用户今日剩余挑战次数
9. 返回结果

**响应 JSON Schema**:

```json
{
  "type": "object",
  "required": ["xp_earned", "new_total_xp", "new_level", "ghost_response", "personality_tags_updated"],
  "properties": {
    "xp_earned": {
      "type": "integer",
      "description": "本次获得的 XP"
    },
    "new_total_xp": {
      "type": "integer",
      "description": "更新后的总 XP"
    },
    "new_level": {
      "type": "integer",
      "minimum": 1,
      "maximum": 10,
      "description": "更新后的等级"
    },
    "ghost_response": {
      "type": "string",
      "description": "Ghost 的俏皮反馈语，如「哈哈，我就知道你会选这个！」"
    },
    "personality_tags_updated": {
      "type": "array",
      "items": { "type": "string" },
      "description": "更新后的人格特征标签列表"
    }
  }
}
```

**响应示例**:

```json
{
  "xp_earned": 500,
  "new_total_xp": 26300,
  "new_level": 3,
  "ghost_response": "果然选了硬刚……你这性格，我越来越懂了 😏",
  "personality_tags_updated": ["直接", "效率至上", "冷幽默", "不怕冲突"]
}
```

**响应示例（触发升级）**:

```json
{
  "xp_earned": 500,
  "new_total_xp": 30200,
  "new_level": 4,
  "ghost_response": "🎉 升级了！我感觉自己……看得更清楚了。你的价值观，让我来好好研究研究。",
  "personality_tags_updated": ["直接", "效率至上", "冷幽默", "不怕冲突", "逻辑优先"]
}
```

**错误响应**:

| HTTP 状态码 | 错误码 | 说明 |
|-------------|--------|------|
| 400 | `INVALID_CHALLENGE` | challenge_id 无效或不属于当前用户 |
| 400 | `INVALID_OPTION` | selected_option 超出选项范围 |
| 401 | `UNAUTHORIZED` | JWT 无效或过期 |
| 429 | `DAILY_LIMIT_REACHED` | 今日校准挑战次数已用完 |
| 500 | `INTERNAL_ERROR` | 服务器内部错误 |

---

## 2. 数据模型

### 2.1 GhostTwinProfile（人格档案）

> ⚠️ **此模型仅存在于服务端数据库，客户端永远不接触完整档案内容。**

人格档案采用「神形法」三层架构，随等级渐进式生成：

```json
{
  "type": "object",
  "required": ["user_id", "version", "form_layer", "spirit_layer", "method_layer", "summary", "updated_at", "created_at"],
  "properties": {
    "user_id": {
      "type": "string",
      "description": "用户唯一 ID"
    },
    "version": {
      "type": "integer",
      "minimum": 0,
      "description": "档案版本号，每次增量更新 +1"
    },
    "form_layer": {
      "type": "object",
      "description": "「形」层 — 语言 DNA（Lv.1~3 解锁）",
      "properties": {
        "verbal_habits": {
          "type": "array",
          "items": { "type": "string" },
          "description": "口癖列表，如 [\"嗯……\", \"就是说\", \"你懂的\"]"
        },
        "sentence_patterns": {
          "type": "array",
          "items": { "type": "string" },
          "description": "常用句式，如 [\"先说结论再解释\", \"喜欢用反问\"]"
        },
        "punctuation_style": {
          "type": "string",
          "description": "标点习惯，如 \"少用感叹号，偏好省略号\""
        },
        "avg_sentence_length": {
          "type": "string",
          "enum": ["short", "medium", "long"],
          "description": "句长偏好"
        }
      }
    },
    "spirit_layer": {
      "type": "object",
      "description": "「神」层 — 价值观与决策逻辑（Lv.4~6 解锁）",
      "properties": {
        "core_values": {
          "type": "array",
          "items": { "type": "string" },
          "description": "核心价值观，如 [\"效率\", \"真诚\", \"独立思考\"]"
        },
        "decision_tendency": {
          "type": "string",
          "description": "决策倾向，如 \"理性分析优先，但会考虑他人感受\""
        },
        "social_strategy": {
          "type": "string",
          "description": "社交策略，如 \"直接但不失礼貌，避免无意义的客套\""
        }
      }
    },
    "method_layer": {
      "type": "object",
      "description": "「法」层 — 情境规则（Lv.7~10 解锁）",
      "properties": {
        "context_rules": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "context": { "type": "string", "description": "情境描述，如 \"与上级沟通\"" },
              "style": { "type": "string", "description": "该情境下的语体风格" }
            }
          },
          "description": "不同情境下的语体切换规则"
        },
        "audience_adaptations": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "audience": { "type": "string", "description": "对象类型，如 \"朋友\"、\"客户\"" },
              "tone_shift": { "type": "string", "description": "语气调整描述" }
            }
          },
          "description": "面向不同对象的语气调整规则"
        }
      }
    },
    "summary": {
      "type": "string",
      "description": "阶段性总结文本（每次升级时由 LLM 生成）"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time",
      "description": "最后更新时间"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "创建时间"
    }
  }
}
```

**GhostTwinProfile 示例**:

```json
{
  "user_id": "usr_abc123",
  "version": 12,
  "form_layer": {
    "verbal_habits": ["嗯……", "就是说", "你懂的"],
    "sentence_patterns": ["先说结论再解释", "喜欢用反问"],
    "punctuation_style": "少用感叹号，偏好省略号",
    "avg_sentence_length": "medium"
  },
  "spirit_layer": {
    "core_values": ["效率", "真诚", "独立思考"],
    "decision_tendency": "理性分析优先，但会考虑他人感受",
    "social_strategy": "直接但不失礼貌，避免无意义的客套"
  },
  "method_layer": {
    "context_rules": [
      { "context": "与上级沟通", "style": "简洁专业，数据说话" },
      { "context": "朋友闲聊", "style": "随意放松，偶尔毒舌" }
    ],
    "audience_adaptations": [
      { "audience": "朋友", "tone_shift": "更随意，会用网络用语" },
      { "audience": "客户", "tone_shift": "更正式，注意措辞" }
    ]
  },
  "summary": "用户是一个注重效率、表达直接的人。语言风格偏简洁，喜欢先说结论。在社交中保持真诚但不过度热情，面对冲突倾向于理性沟通。",
  "updated_at": "2025-07-15T10:30:00Z",
  "created_at": "2025-06-01T08:00:00Z"
}
```

---

### 2.2 CalibrationChallenge（校准挑战）

服务端存储的校准挑战完整模型（含服务端专用字段）：

```json
{
  "type": "object",
  "required": ["id", "user_id", "type", "scenario", "options", "target_layer", "xp_reward", "status", "created_at"],
  "properties": {
    "id": {
      "type": "string",
      "description": "挑战唯一 ID (UUID)"
    },
    "user_id": {
      "type": "string",
      "description": "所属用户 ID"
    },
    "type": {
      "type": "string",
      "enum": ["dilemma", "reverse_turing", "prediction"],
      "description": "挑战类型"
    },
    "scenario": {
      "type": "string",
      "description": "场景描述文本（LLM 生成）"
    },
    "options": {
      "type": "array",
      "items": { "type": "string" },
      "minItems": 2,
      "maxItems": 3,
      "description": "选项文本列表"
    },
    "target_layer": {
      "type": "string",
      "enum": ["form", "spirit", "method"],
      "description": "⚠️ 仅服务端使用 — 该挑战校准的人格档案层级"
    },
    "xp_reward": {
      "type": "integer",
      "description": "XP 奖励值（dilemma=500, reverse_turing=300, prediction=200）"
    },
    "status": {
      "type": "string",
      "enum": ["pending", "answered", "expired"],
      "description": "挑战状态"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "创建时间"
    }
  }
}
```

> **注意**: 客户端 API 响应中不包含 `user_id`、`target_layer`、`status` 字段，这些仅用于服务端内部逻辑。

---

### 2.3 CalibrationAnswer（校准回答记录）

> ⚠️ **此模型仅存在于服务端数据库，用于记录用户的校准历史和人格档案变更。**

```json
{
  "type": "object",
  "required": ["id", "user_id", "challenge_id", "selected_option", "xp_earned", "profile_diff", "ghost_response", "created_at"],
  "properties": {
    "id": {
      "type": "string",
      "description": "回答记录唯一 ID (UUID)"
    },
    "user_id": {
      "type": "string",
      "description": "用户 ID"
    },
    "challenge_id": {
      "type": "string",
      "description": "对应的挑战 ID"
    },
    "selected_option": {
      "type": "integer",
      "description": "用户选择的选项索引（0-based）"
    },
    "xp_earned": {
      "type": "integer",
      "description": "本次获得的 XP"
    },
    "profile_diff": {
      "type": "object",
      "description": "⚠️ 仅服务端使用 — 本次回答导致的人格档案变更（JSON diff 格式）",
      "properties": {
        "layer": {
          "type": "string",
          "enum": ["form", "spirit", "method"],
          "description": "变更的层级"
        },
        "changes": {
          "type": "object",
          "description": "具体变更内容（由 LLM 增量更新 Prompt 生成）"
        },
        "new_tags": {
          "type": "array",
          "items": { "type": "string" },
          "description": "本次新增的人格特征标签"
        }
      }
    },
    "ghost_response": {
      "type": "string",
      "description": "Ghost 的反馈语（返回给客户端展示）"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "回答时间"
    }
  }
}
```

**CalibrationAnswer 示例**:

```json
{
  "id": "ans_d4e5f6a7-b8c9-0123-defg-456789012345",
  "user_id": "usr_abc123",
  "challenge_id": "ch_a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "selected_option": 0,
  "xp_earned": 500,
  "profile_diff": {
    "layer": "spirit",
    "changes": {
      "decision_tendency": "理性分析优先，面对冲突倾向于直接表达立场",
      "social_strategy": "直接但不失礼貌，在公开场合也敢于表达不同意见"
    },
    "new_tags": ["不怕冲突"]
  },
  "ghost_response": "果然选了硬刚……你这性格，我越来越懂了 😏",
  "created_at": "2025-07-15T10:35:00Z"
}
```

---

## 3. Prompt 初稿

> ⚠️ **以下所有 Prompt 仅在服务端执行，客户端永远不接触 Prompt 内容。**
>
> Prompt 中的 `{{变量}}` 由服务端在运行时注入，客户端不参与此过程。

### 3.1 校准挑战生成 Prompt

根据用户当前等级和人格档案，生成对应类型的情境问答题。

**输入变量**:
- `{{user_level}}`: 用户当前等级 (1~10)
- `{{challenge_type}}`: 挑战类型 (`dilemma` / `reverse_turing` / `prediction`)
- `{{personality_profile}}`: 用户当前人格档案完整 JSON
- `{{previous_challenges}}`: 最近 10 次挑战的摘要（避免重复出题）

**Prompt 模板**:

```
你是 GHOSTYPE 的校准系统，负责生成用于训练用户数字分身（Ghost Twin）的情境问答题。

## 当前用户信息
- 等级: Lv.{{user_level}}
- 人格档案版本: {{personality_profile.version}}
- 已捕捉特征: {{personality_profile 摘要}}

## 任务
生成一道「{{challenge_type}}」类型的校准挑战。

### 挑战类型说明

**如果 challenge_type == "dilemma"（灵魂拷问）：**
- 目标：校准「神」层（价值观、决策逻辑）
- 要求：设计一个价值观冲突场景，让用户在 2~3 个选项中做出选择
- 场景要贴近日常生活，避免极端假设
- 每个选项应代表不同的价值取向，没有明显的"正确答案"
- 选项文字简短有力，不超过 20 字

**如果 challenge_type == "reverse_turing"（找鬼游戏）：**
- 目标：校准「形」层（语言 DNA、表达习惯）
- 要求：给出一个日常对话场景，然后提供 3 段不同风格的回复文本
- 3 段回复应在语气、句式、用词上有明显差异
- 其中一段应尽量贴近用户已知的语言习惯（基于人格档案）
- 用户需要选出"最像自己会说的话"

**如果 challenge_type == "prediction"（预判赌局）：**
- 目标：校准「法」层（情境规则、语体切换）
- 要求：给出一个半完成的句子或场景，提供 2~3 个可能的续写
- 续写应体现不同的沟通策略和语体风格
- 场景应涉及特定的沟通对象或情境（如工作邮件、朋友聊天）

## 最近出过的题目（避免重复）
{{previous_challenges}}

## 输出格式
严格按以下 JSON 格式输出，不要添加任何额外文字：

{
  "scenario": "场景描述文本",
  "options": ["选项A", "选项B", "选项C"]
}
```

---

### 3.2 人格档案增量更新 Prompt

在用户完成校准回答后，对人格档案的对应层进行增量修正（而非全量重建）。

**输入变量**:
- `{{personality_profile}}`: 用户当前人格档案完整 JSON
- `{{challenge}}`: 本次校准挑战的完整信息（类型、场景、选项）
- `{{selected_option}}`: 用户选择的选项索引和文本
- `{{target_layer}}`: 本次校准的目标层级 (`form` / `spirit` / `method`)
- `{{calibration_history}}`: 最近 20 次校准记录摘要

**Prompt 模板**:

```
你是 GHOSTYPE 的人格档案分析师，负责根据用户的校准回答，对其数字分身的人格档案进行增量更新。

## 当前人格档案
{{personality_profile}}

## 本次校准信息
- 挑战类型: {{challenge.type}}
- 场景: {{challenge.scenario}}
- 选项: {{challenge.options}}
- 用户选择: 选项 {{selected_option.index}} —「{{selected_option.text}}」
- 目标层级: {{target_layer}}

## 最近校准历史
{{calibration_history}}

## 任务
1. 分析用户的选择反映了什么样的性格特征、价值观或表达偏好
2. 对人格档案的「{{target_layer}}」层进行增量修正
3. 如果发现新的人格特征标签，添加到标签列表
4. 生成一句 Ghost 的俏皮反馈语（15~30 字，体现 Ghost 对用户的了解）

## 增量更新原则
- 只修改与本次回答相关的字段，不要改动无关内容
- 如果新信息与已有档案矛盾，优先保留多次验证过的结论，但记录矛盾点
- 标签列表只增不减（除非有强烈证据表明之前的标签不准确）
- 保持档案的一致性和连贯性

## 输出格式
严格按以下 JSON 格式输出：

{
  "profile_diff": {
    "layer": "form|spirit|method",
    "changes": {
      "字段名": "新值（仅包含需要修改的字段）"
    },
    "new_tags": ["新增的特征标签（如果有）"]
  },
  "ghost_response": "Ghost 的俏皮反馈语",
  "analysis": "简短的分析说明（仅供服务端日志，不返回客户端）"
}
```

---

### 3.3 人格档案阶段性总结 Prompt

在用户升级时，整合该等级内所有校准数据，生成更精炼的档案版本。

**输入变量**:
- `{{personality_profile}}`: 用户当前人格档案完整 JSON
- `{{completed_level}}`: 刚完成的等级 (1~10)
- `{{new_level}}`: 升级后的等级
- `{{level_calibrations}}`: 该等级内所有校准记录（挑战 + 回答 + profile_diff）
- `{{total_calibration_count}}`: 历史总校准次数

**Prompt 模板**:

```
你是 GHOSTYPE 的人格档案总结师，负责在用户升级时对人格档案进行阶段性总结和精炼。

## 当前人格档案
{{personality_profile}}

## 升级信息
- 完成等级: Lv.{{completed_level}} → Lv.{{new_level}}
- 本等级校准次数: {{level_calibrations.length}}
- 历史总校准次数: {{total_calibration_count}}

## 本等级所有校准记录
{{level_calibrations}}

## 任务
1. 回顾本等级内所有校准数据，识别一致的模式和趋势
2. 整合零散的增量更新，生成更精炼、更准确的档案描述
3. 解决可能存在的矛盾点（以多数一致的行为模式为准）
4. 根据新等级解锁的层级，扩展对应层的描述深度：
   - Lv.1→2, 2→3: 深化「形」层（语言 DNA）
   - Lv.3→4: 初始化「神」层（价值观框架）
   - Lv.4→5, 5→6: 深化「神」层
   - Lv.6→7: 初始化「法」层（情境规则）
   - Lv.7→8, 8→9, 9→10: 深化「法」层
5. 更新 summary 字段，生成一段完整的人格画像描述

## 总结原则
- 精炼而非堆砌：合并相似的描述，去除冗余
- 保持层级清晰：形/神/法 三层各司其职
- 标签去重和归类：合并语义相近的标签
- 保留核心矛盾：如果用户确实有矛盾的行为模式，如实记录而非强行统一

## 输出格式
严格按以下 JSON 格式输出完整的更新后档案：

{
  "form_layer": { ... },
  "spirit_layer": { ... },
  "method_layer": { ... },
  "summary": "更新后的人格画像描述（100~200 字）",
  "version": {{personality_profile.version + 1}},
  "refined_tags": ["精炼后的完整标签列表"]
}
```

---

## 4. 等级与经验值规则

### 4.1 等级计算

| 等级 | 所需总 XP | 当前等级 XP 范围 | Ghost 透明度 | 解锁层级 |
|------|-----------|------------------|-------------|----------|
| Lv.1 | 0 | 0 ~ 9,999 | 10% | 形（Form） |
| Lv.2 | 10,000 | 0 ~ 9,999 | 20% | 形（Form） |
| Lv.3 | 20,000 | 0 ~ 9,999 | 30% | 形（Form） |
| Lv.4 | 30,000 | 0 ~ 9,999 | 40% | 神（Spirit） |
| Lv.5 | 40,000 | 0 ~ 9,999 | 50% | 神（Spirit） |
| Lv.6 | 50,000 | 0 ~ 9,999 | 60% | 神（Spirit） |
| Lv.7 | 60,000 | 0 ~ 9,999 | 70% | 法（Method） |
| Lv.8 | 70,000 | 0 ~ 9,999 | 80% | 法（Method） |
| Lv.9 | 80,000 | 0 ~ 9,999 | 90% | 法（Method） |
| Lv.10 | 90,000 | 0 ~ 9,999 | 100% | 法（Method） |

**服务端计算公式**:
```
level = min(total_xp / 10000 + 1, 10)
current_level_xp = total_xp % 10000  (当 level < 10 时)
current_level_xp = total_xp - 90000  (当 level == 10 时)
```

### 4.2 XP 来源

| 来源 | XP 计算 | 说明 |
|------|---------|------|
| 打字 XP | 1 字 = 1 XP | 用户通过 GHOSTYPE 发送文本时，复用 `POST /api/v1/llm/chat` 的字数统计自动累加 |
| 校准 XP — 灵魂拷问 | 500 XP / 次 | `dilemma` 类型挑战 |
| 校准 XP — 找鬼游戏 | 300 XP / 次 | `reverse_turing` 类型挑战 |
| 校准 XP — 预判赌局 | 200 XP / 次 | `prediction` 类型挑战 |

### 4.3 每日限制

- 校准挑战：每日 **3 次**（服务端控制，UTC 0:00 重置）
- 打字 XP：无每日上限

### 4.4 挑战类型与等级的对应关系

服务端根据用户等级自动选择挑战类型（非强制，可根据档案完整度调整）：

| 等级范围 | 优先挑战类型 | 校准目标层级 |
|----------|-------------|-------------|
| Lv.1 ~ 3 | `reverse_turing`（找鬼游戏） | 形（Form）— 语言 DNA |
| Lv.4 ~ 6 | `dilemma`（灵魂拷问） | 神（Spirit）— 价值观 |
| Lv.7 ~ 10 | `prediction`（预判赌局） | 法（Method）— 情境规则 |

---

## 5. 公共 Header 规范

所有 Ghost Twin API 请求需要携带以下 Header：

| Header | 值 | 说明 |
|--------|-----|------|
| `Authorization` | `Bearer <JWT>` | 用户认证令牌 |
| `X-Device-Id` | 设备唯一 ID | 设备标识 |
| `Content-Type` | `application/json` | 请求体格式（POST 请求） |

**认证失败处理**:
- 401 响应时，客户端清除本地 JWT，回退到设备 ID 模式
- 客户端弹出重新登录提示

---

## 6. 错误响应格式

所有错误响应统一使用以下格式：

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "人类可读的错误描述"
  }
}
```

**通用错误码**:

| HTTP 状态码 | 错误码 | 说明 |
|-------------|--------|------|
| 400 | `INVALID_REQUEST` | 请求参数无效 |
| 400 | `INVALID_CHALLENGE` | 挑战 ID 无效或不属于当前用户 |
| 400 | `INVALID_OPTION` | 选项索引超出范围 |
| 401 | `UNAUTHORIZED` | JWT 无效或过期 |
| 429 | `QUOTA_EXCEEDED` | 通用额度超限 |
| 429 | `DAILY_LIMIT_REACHED` | 今日校准挑战次数已用完 |
| 500 | `INTERNAL_ERROR` | 服务器内部错误 |
| 502 | `UPSTREAM_ERROR` | 上游服务（LLM）错误 |
| 504 | `UPSTREAM_TIMEOUT` | 上游服务（LLM）超时 |

---

## 附录 A：客户端数据模型（Swift）

以下为客户端已实现的数据模型，供服务端参考 API 响应格式：

```swift
// MARK: - Ghost Twin Status Response
struct GhostTwinStatusResponse: Codable {
    let level: Int                          // 当前等级 1~10
    let total_xp: Int                       // 总经验值
    let current_level_xp: Int               // 当前等级内的经验值 (0~9999)
    let personality_tags: [String]          // 已捕捉的人格特征标签
    let challenges_remaining_today: Int     // 今日剩余校准挑战次数
    let personality_profile_version: Int    // 人格档案版本号
}

// MARK: - Calibration Challenge
enum ChallengeType: String, Codable {
    case dilemma                            // 灵魂拷问，500 XP
    case reverseTuring = "reverse_turing"   // 找鬼游戏，300 XP
    case prediction                         // 预判赌局，200 XP
}

struct CalibrationChallenge: Codable, Identifiable {
    let id: String              // challenge_id
    let type: ChallengeType     // dilemma / reverse_turing / prediction
    let scenario: String        // 场景描述文本
    let options: [String]       // 2~3 个选项
    let xp_reward: Int          // 该类型的 XP 奖励
}

// MARK: - Calibration Answer Response
struct CalibrationAnswerResponse: Codable {
    let xp_earned: Int                      // 本次获得的 XP
    let new_total_xp: Int                   // 新的总 XP
    let new_level: Int                      // 新的等级
    let ghost_response: String              // Ghost 的俏皮反馈语
    let personality_tags_updated: [String]  // 更新后的人格特征标签
}
```

## 附录 B：客户端 API 调用端点

```
GET  /api/v1/ghost-twin/status           → GhostTwinStatusResponse
GET  /api/v1/ghost-twin/challenge        → CalibrationChallenge
POST /api/v1/ghost-twin/challenge/answer → CalibrationAnswerResponse
     Body: { "challenge_id": String, "selected_option": Int }
```
