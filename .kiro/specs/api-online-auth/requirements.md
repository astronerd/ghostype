# 需求文档

## 简介

GHOSTYPE（鬼才打字）macOS 桌面应用当前直接从客户端调用 Google Gemini API 进行文本润色和翻译。本次重构将所有 LLM 处理迁移至 GHOSTYPE 后端服务器，客户端改为调用后端 API（`POST /api/v1/llm/chat`）。同时实现基于 Clerk 的用户鉴权（JWT 通过浏览器重定向 → `ghostype://auth` URL Scheme 获取），从服务器获取用户配置和额度信息（`GET /api/v1/user/profile`），并处理服务端额度管理（替换本地 CoreData 额度追踪）。

## 术语表

- **Ghostype_API_Client**: 替代 GeminiService 的新 API 客户端单例，负责与 GHOSTYPE 后端通信，发送润色/翻译请求。
- **Auth_Manager**: 用户认证管理器单例，负责 Clerk 登录流程、JWT 存储、登录状态管理。
- **Keychain_Helper**: 已有的 Keychain 安全存储工具，用于存取 JWT Token。
- **Device_ID_Manager**: 已有的设备标识管理器，生成并缓存 UUID v4 设备 ID。
- **Quota_Manager**: 额度管理器，重构后从服务器获取字符额度数据（替代本地 CoreData 秒数额度）。
- **Profile_Response**: 服务器返回的用户配置响应，包含订阅信息（plan、status、is_lifetime_vip）和用量数据（used、limit、reset_at）。
- **Polish_Profile**: 润色风格枚举，rawValue 从中文迁移为英文（standard、professional、casual、concise、creative）以匹配 API 参数。
- **Translate_Language**: 翻译语言枚举，rawValue 从中文迁移为英文（chineseEnglish、chineseJapanese、auto）以匹配 API 参数。
- **App_Delegate**: 应用主委托，协调录音、AI 处理、文本上屏的核心流程。
- **Base_URL**: API 基础地址，生产环境 `https://ghostype.com`，调试环境 `http://localhost:3000`。

## 需求

### 需求 1：Clerk 用户鉴权

**用户故事：** 作为用户，我希望通过浏览器登录 Clerk 账号，以获得账户级别的额度管理和 Pro 订阅权益。

#### 验收标准

1. WHEN 用户触发登录，THE Auth_Manager SHALL 打开系统浏览器访问 `{Base_URL}/sign-in?redirect_url=ghostype://auth`
2. WHEN 系统浏览器重定向到 `ghostype://auth?token={jwt}`，THE Auth_Manager SHALL 提取 token 参数并存入 Keychain
3. WHEN 收到有效 JWT token，THE Auth_Manager SHALL 将 `isLoggedIn` 设为 true 并发送 `userDidLogin` 通知
4. WHEN 用户触发登出，THE Auth_Manager SHALL 删除 Keychain 中的 JWT 并将 `isLoggedIn` 设为 false
5. WHEN 应用启动时，THE Auth_Manager SHALL 检查 Keychain 中是否存在 JWT 并恢复登录状态
6. IF 重定向 URL 缺少 token 参数或 scheme/host 不匹配，THEN THE Auth_Manager SHALL 忽略该回调

### 需求 2：Base URL 环境配置

**用户故事：** 作为开发者，我希望 API 基础地址根据编译环境自动切换，以便在开发和生产环境间无缝切换。

#### 验收标准

1. WHILE 编译配置为 DEBUG，THE Ghostype_API_Client SHALL 使用 `http://localhost:3000` 作为 Base_URL
2. WHILE 编译配置为 RELEASE，THE Ghostype_API_Client SHALL 使用 `https://ghostype.com` 作为 Base_URL

### 需求 3：请求鉴权 Header

**用户故事：** 作为用户，我希望应用自动在每个 API 请求中携带正确的鉴权信息，以确保服务端能识别我的身份和订阅状态。

#### 验收标准

1. THE Ghostype_API_Client SHALL 在每个请求中携带 `Content-Type: application/json` 和 `X-Device-Id` Header
2. WHILE 用户已登录，THE Ghostype_API_Client SHALL 在请求中额外携带 `Authorization: Bearer {jwt}` Header
3. WHILE 用户未登录，THE Ghostype_API_Client SHALL 仅携带 `X-Device-Id` Header，不携带 Authorization Header

### 需求 4：API 客户端替换（润色模式）

**用户故事：** 作为用户，我希望文本润色通过 GHOSTYPE 后端处理，以获得更稳定的服务和统一的额度管理。

#### 验收标准

1. WHEN 用户触发润色操作，THE Ghostype_API_Client SHALL 向 `{Base_URL}/api/v1/llm/chat` 发送 POST 请求，请求体包含 `mode: "polish"`、`message`、`profile`、`custom_prompt`（仅 profile 为 custom 时）、`enable_in_sentence`、`enable_trigger`、`trigger_word` 字段
2. WHEN 服务器返回 HTTP 200 且响应体包含 `text` 字段，THE Ghostype_API_Client SHALL 返回 `text` 字段的值作为润色结果
3. WHEN AI 润色功能被禁用（enableAIPolish 为 false），THE App_Delegate SHALL 直接返回原文，不调用 API
4. WHEN 输入文本长度小于润色阈值（polishThreshold），THE App_Delegate SHALL 直接返回原文，不调用 API

### 需求 5：API 客户端替换（翻译模式）

**用户故事：** 作为用户，我希望文本翻译通过 GHOSTYPE 后端处理，以获得一致的翻译质量。

#### 验收标准

1. WHEN 用户触发翻译操作，THE Ghostype_API_Client SHALL 向 `{Base_URL}/api/v1/llm/chat` 发送 POST 请求，请求体包含 `mode: "translate"`、`message`、`translate_language` 字段
2. WHEN 服务器返回 HTTP 200，THE Ghostype_API_Client SHALL 返回响应体中 `text` 字段的值作为翻译结果

### 需求 6：服务端错误处理

**用户故事：** 作为用户，我希望应用能妥善处理各种服务端错误，以获得清晰的错误提示和流畅的降级体验。

#### 验收标准

1. WHEN 服务器返回 HTTP 401（UNAUTHORIZED），THE Ghostype_API_Client SHALL 清除 Keychain 中的 JWT 并回退到 Device-Id 模式
2. WHEN 服务器返回 HTTP 429（QUOTA_EXCEEDED），THE Ghostype_API_Client SHALL 返回包含额度超限信息的错误
3. WHEN 服务器返回 HTTP 500（INTERNAL_ERROR）或 502（UPSTREAM_ERROR），THE Ghostype_API_Client SHALL 自动重试一次请求
4. WHEN 服务器返回 HTTP 504（UPSTREAM_TIMEOUT），THE Ghostype_API_Client SHALL 返回网络超时错误
5. WHEN 服务器返回 HTTP 400（INVALID_REQUEST），THE Ghostype_API_Client SHALL 返回参数错误信息
6. IF 重试后仍然失败，THEN THE Ghostype_API_Client SHALL 返回最终的错误信息
7. WHEN API 调用失败（任何错误），THE App_Delegate SHALL 回退到插入原始文本，保证用户输入不丢失

### 需求 7：用户配置与额度查询

**用户故事：** 作为用户，我希望在 Dashboard 中看到我的订阅状态和剩余额度，以了解当前的使用情况。

#### 验收标准

1. WHEN 需要获取用户配置时，THE Ghostype_API_Client SHALL 向 `{Base_URL}/api/v1/user/profile` 发送 GET 请求
2. WHEN 服务器返回 Profile_Response，THE Quota_Manager SHALL 使用 `usage.used` 和 `usage.limit` 更新本地额度显示
3. WHILE 用户为 Pro 订阅（usage.limit 为 -1），THE Quota_Manager SHALL 显示额度为无限制
4. WHILE 用户为 Free 用户，THE Quota_Manager SHALL 显示已用字符数和每周 6000 字符上限
5. THE Quota_Manager SHALL 使用 `usage.reset_at` 显示下次额度重置时间

### 需求 8：枚举值迁移（PolishProfile）

**用户故事：** 作为开发者，我希望 PolishProfile 枚举的 rawValue 从中文改为英文，以匹配 API 参数格式，同时不影响现有用户的设置。

#### 验收标准

1. THE Polish_Profile SHALL 使用英文 rawValue：standard、professional、casual、concise、creative
2. WHEN 应用启动时检测到 UserDefaults 中存储的是旧中文 rawValue（默认、专业、活泼、简洁、创意），THE Polish_Profile SHALL 自动迁移为对应的英文 rawValue
3. WHEN 发送 API 请求时，THE Ghostype_API_Client SHALL 直接使用 Polish_Profile 的英文 rawValue 作为 `profile` 参数

### 需求 9：枚举值迁移（TranslateLanguage）

**用户故事：** 作为开发者，我希望 TranslateLanguage 枚举的 rawValue 从中文改为英文，以匹配 API 参数格式，同时不影响现有用户的设置。

#### 验收标准

1. THE Translate_Language SHALL 使用英文 rawValue：chineseEnglish、chineseJapanese、auto
2. WHEN 应用启动时检测到 UserDefaults 中存储的是旧中文 rawValue（中英互译、中日互译、自动检测），THE Translate_Language SHALL 自动迁移为对应的英文 rawValue
3. THE Translate_Language SHALL 从 GeminiService 的内嵌枚举迁移为独立的顶层枚举

### 需求 10：请求超时配置

**用户故事：** 作为用户，我希望 API 请求有合理的超时设置，以避免长时间等待无响应。

#### 验收标准

1. THE Ghostype_API_Client SHALL 为 LLM 聊天请求设置 30 秒超时
2. THE Ghostype_API_Client SHALL 为用户配置查询请求设置 10 秒超时
3. IF 请求超时，THEN THE Ghostype_API_Client SHALL 返回超时错误

### 需求 11：ASR 凭证云端迁移

**用户故事：** 作为用户，我希望语音识别凭证从服务器动态获取，而非硬编码在本地 .env 文件中，以提升安全性并支持凭证轮换。

#### 验收标准

1. WHEN 应用启动时，THE DoubaoSpeechService SHALL 调用 `GET {Base_URL}/api/v1/asr/credentials` 获取 ASR 凭证（app_id 和 access_token），请求携带 `X-Device-Id` Header
2. WHEN 服务器返回 HTTP 200 且响应体包含 `app_id` 和 `access_token` 字段，THE DoubaoSpeechService SHALL 将凭证缓存到内存属性中，供后续 WebSocket 连接使用
3. WHEN 凭证已成功获取并缓存，THE DoubaoSpeechService SHALL 使用缓存的凭证（而非环境变量）构建 WebSocket 请求 Header
4. IF 凭证获取失败（网络错误或服务器返回非 200），THEN THE DoubaoSpeechService SHALL 将凭证保持为空，用户触发录音时显示网络错误提示，应用不崩溃
5. WHEN 服务器返回 HTTP 401（缺少或无效 X-Device-Id），THE DoubaoSpeechService SHALL 记录错误日志并将凭证保持为空
6. THE DoubaoSpeechService SHALL 移除对 `DOUBAO_ASR_APP_ID` 和 `DOUBAO_ASR_ACCESS_TOKEN` 环境变量的读取逻辑
7. THE .env 和 .env.example 文件 SHALL 移除 `DOUBAO_ASR_APP_ID`、`DOUBAO_ASR_ACCESS_TOKEN`、`DOUBAO_ASR_SECRET_KEY` 三个环境变量
