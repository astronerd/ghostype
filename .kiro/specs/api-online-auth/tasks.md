# 实现计划：API 调用线上化及用户鉴权

## 概述

按照「先鉴权基础设施 → 再 API 客户端 → 再枚举迁移 → 最后接入调用链路」的顺序，逐步将客户端从直接调用 Gemini API 迁移到调用 GHOSTYPE 后端 API。每个阶段完成后通过 checkpoint 验证。

## Tasks

- [ ] 1. 完善 AuthManager 鉴权流程
  - [x] 1.1 补全 AuthManager 的方法实现
    - 在 `AIInputMethod/Sources/Features/Auth/AuthManager.swift` 中实现以下方法：
    - `init()`: 从 Keychain 检查已有 JWT，恢复 isLoggedIn 状态
    - `openLogin()`: 调用 `NSWorkspace.shared.open()` 打开 signInURL
    - `openSignUp()`: 调用 `NSWorkspace.shared.open()` 打开 signUpURL
    - `handleAuthURL(_ url: URL)`: 校验 scheme=="ghostype" && host=="auth"，提取 token 参数，存入 Keychain，设置 isLoggedIn=true，发送 userDidLogin 通知
    - `logout()`: 删除 Keychain JWT，设置 isLoggedIn=false，发送 userDidLogout 通知
    - `getToken() -> String?`: 从 Keychain 读取 JWT
    - `handleUnauthorized()`: 清除 JWT 并回退到未登录状态
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [~] 1.2 在 AppDelegate 中注册 URL Scheme 回调
    - 在 `AIInputMethodApp.swift` 的 AppDelegate 中添加 `application(_:open:)` 方法
    - 将 scheme 为 "ghostype"、host 为 "auth" 的 URL 路由到 `AuthManager.shared.handleAuthURL()`
    - _Requirements: 1.2, 1.6_

  - [~] 1.3 编写 AuthManager 属性测试
    - **Property 1: Auth URL 解析与状态转换**
    - **Property 2: 无效 URL 不改变认证状态**
    - **Property 3: 登录登出往返一致性**
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.6**

- [ ] 2. 创建 GhostypeAPIClient 和数据模型
  - [~] 2.1 创建 API 数据模型文件
    - 新建 `AIInputMethod/Sources/Features/AI/GhostypeModels.swift`
    - 实现 `GhostypeRequest`、`GhostypeResponse`、`GhostypeErrorResponse`、`ProfileResponse`、`GhostypeError` 枚举
    - 数据模型严格按照 `API_CLIENT_GUIDE copy.md` 中的 JSON 结构定义
    - _Requirements: 4.1, 5.1, 7.1_

  - [~] 2.2 创建 GhostypeAPIClient 核心实现
    - 新建 `AIInputMethod/Sources/Features/AI/GhostypeAPIClient.swift`
    - 实现 `buildRequest(url:method:timeout:)`: 构建 URLRequest，添加 Content-Type、X-Device-Id Header，有 JWT 时添加 Authorization Header
    - 实现 `performRequest<T>(_:retryOn500:)`: 执行请求，处理 200/401/429/400/500/502/504 状态码，500/502 自动重试一次
    - 实现 `polish(text:profile:customPrompt:enableInSentence:enableTrigger:triggerWord:) async throws -> String`
    - 实现 `translate(text:language:) async throws -> String`
    - 实现 `fetchProfile() async throws -> ProfileResponse`
    - LLM 请求超时 30 秒，profile 请求超时 10 秒
    - _Requirements: 2.1, 2.2, 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 10.1, 10.2, 10.3_

  - [~] 2.3 编写 GhostypeAPIClient 属性测试
    - **Property 4: 请求 Header 与登录状态一致**
    - **Property 5: 润色请求体结构正确性**
    - **Property 6: 翻译请求体结构正确性**
    - **Property 7: API 响应解析一致性（round-trip）**
    - **Validates: Requirements 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2**

- [~] 3. Checkpoint - 鉴权和 API 客户端基础验证
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. 枚举迁移与数据兼容
  - [~] 4.1 迁移 PolishProfile 枚举 rawValue
    - 修改 `AIInputMethod/Sources/Features/AI/PolishProfile.swift`
    - rawValue 从中文（"默认"/"专业"/"活泼"/"简洁"/"创意"）改为英文（"standard"/"professional"/"casual"/"concise"/"creative"）
    - 添加 `static func migrate(oldValue: String) -> PolishProfile?` 方法
    - 更新 `description` 和 `icon` 属性（逻辑不变，只是 case 名称对应调整）
    - _Requirements: 8.1, 8.2, 8.3_

  - [~] 4.2 迁移 TranslateLanguage 枚举
    - 新建 `AIInputMethod/Sources/Features/AI/TranslateLanguage.swift` 作为独立顶层枚举
    - rawValue 使用英文：chineseEnglish、chineseJapanese、auto
    - 添加 `static func migrate(oldValue: String) -> TranslateLanguage?` 方法
    - 添加 `displayName` 属性（通过 L.xxx 本地化）
    - 删除 `GeminiService.TranslateLanguage` 内嵌枚举
    - 更新 `AppSettings.swift` 中 `translateLanguage` 的类型引用从 `GeminiService.TranslateLanguage` 改为 `TranslateLanguage`
    - _Requirements: 9.1, 9.2, 9.3_

  - [~] 4.3 创建 MigrationService 并在启动时执行
    - 新建 `AIInputMethod/Sources/Features/Settings/MigrationService.swift`
    - 实现 `runIfNeeded()`: 检查 UserDefaults 中的 `defaultProfile`、`selectedProfileId`、`appProfileMapping`、`translateLanguage`，将旧中文值迁移为英文值
    - 使用 UserDefaults key `migration_v2_completed` 标记迁移已完成，避免重复执行
    - 在 `AppDelegate.applicationDidFinishLaunching` 中调用 `MigrationService.runIfNeeded()`（在 loadDotEnv 之后、startApp 之前）
    - _Requirements: 8.2, 9.2_

  - [~] 4.4 编写枚举迁移属性测试
    - **Property 9: PolishProfile 枚举迁移完整性**
    - **Property 10: TranslateLanguage 枚举迁移完整性**
    - **Validates: Requirements 8.2, 8.3, 9.2**

- [~] 5. Checkpoint - 枚举迁移验证
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. 重构 QuotaManager 使用服务端额度
  - [~] 6.1 重构 QuotaManager 为服务端字符额度
    - 修改 `AIInputMethod/Sources/Features/Dashboard/QuotaManager.swift`
    - 移除 CoreData 依赖（usedSeconds、resetDate、totalSeconds、PersistenceController 引用）
    - 新增属性：usedCharacters、limitCharacters、resetAt、plan、isLifetimeVip
    - 新增计算属性：isUnlimited（limit == -1）、usedPercentage、formattedUsed、formattedResetTime
    - 实现 `refresh() async`: 调用 `GhostypeAPIClient.shared.fetchProfile()` 并更新状态
    - 实现 `update(from response: ProfileResponse)`: 用 ProfileResponse 更新本地状态
    - 更新 `forTesting()` 工厂方法适配新属性
    - _Requirements: 7.2, 7.3, 7.4, 7.5_

  - [~] 6.2 更新 QuotaManager 的 UI 调用方
    - 更新 `OverviewPage.swift` 中的 `QuotaInfo.from()` 适配新的 QuotaManager 属性
    - 更新 `DashboardView.swift` 中的 `quotaPercentage` 引用
    - 更新 `SidebarView.swift` 中的额度显示（如有引用）
    - _Requirements: 7.2, 7.3, 7.4_

  - [~] 6.3 编写 QuotaManager 属性测试
    - **Property 8: QuotaManager 状态与 ProfileResponse 一致**
    - **Validates: Requirements 7.2, 7.3, 7.4, 7.5**

- [ ] 7. 接入调用链路：替换 GeminiService
  - [~] 7.1 修改 AppDelegate 润色流程
    - 修改 `AIInputMethodApp.swift` 中的 `processPolish()` 方法
    - 将 `GeminiService.shared.polishWithProfile(...)` 替换为 `GhostypeAPIClient.shared.polish(...)`
    - 使用 `Task { ... }` 包裹 async 调用
    - 保留阈值判断逻辑（polishThreshold）和 enableAIPolish 开关
    - profile 参数直接使用 `resolved.profile.rawValue`（已是英文）
    - 错误时回退插入原文
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 6.7_

  - [~] 7.2 修改 AppDelegate 翻译流程
    - 修改 `AIInputMethodApp.swift` 中的 `processTranslate()` 方法
    - 将 `GeminiService.shared.translate(...)` 替换为 `GhostypeAPIClient.shared.translate(...)`
    - language 参数使用 `settings.translateLanguage.rawValue`（已是英文）
    - 错误时回退插入原文
    - _Requirements: 5.1, 5.2, 6.7_

  - [~] 7.3 清理 GeminiService 中不再需要的代码
    - 移除 `GeminiService` 中的 `polish()`、`polishWithProfile()`、`translate()` 方法
    - 移除 Gemini API 相关配置（baseURL、model、apiKey）
    - 移除 `GeminiService.TranslateLanguage` 内嵌枚举（已迁移为独立枚举）
    - 如果 GeminiService 不再有其他用途，可以整个删除
    - 移除 `.env` 文件中的 `GEMINI_API_KEY`（不再需要客户端 API Key）
    - 移除 `AppDelegate.loadDotEnv()` 方法（不再需要加载 .env）
    - _Requirements: 4.1, 5.1_

  - [~] 7.4 编写短文本跳过属性测试
    - **Property 11: 短文本跳过 AI 处理**
    - **Validates: Requirements 4.4**

- [~] 8. Final checkpoint - 全流程验证
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. ASR 凭证云端迁移
  - [~] 9.1 修改 DoubaoSpeechService 使用缓存凭证 + 添加 fetchCredentials() 方法
    - 修改 `AIInputMethod/Sources/Features/Speech/DoubaoSpeechService.swift`
    - 新增 `ASRCredentialsResponse` 数据模型（`app_id`、`access_token`）
    - 新增 `cachedAppId` 和 `cachedAccessToken` 内存属性，初始为空字符串
    - 新增 `fetchCredentials() async throws` 方法：向 `{Base_URL}/api/v1/asr/credentials` 发送 GET 请求，携带 `X-Device-Id` Header，解析响应并缓存凭证
    - Base_URL 使用 `#if DEBUG` 模式（localhost:3000 / ghostype.com），与 GhostypeAPIClient 一致
    - 请求超时 10 秒
    - 移除原有的 `getenv("DOUBAO_ASR_APP_ID")` 和 `getenv("DOUBAO_ASR_ACCESS_TOKEN")` 读取逻辑
    - `appId` 和 `accessToken` 计算属性改为读取缓存值
    - `hasCredentials()` 逻辑不变（检查非空）
    - _Requirements: 11.1, 11.2, 11.3, 11.6_

  - [~] 9.2 在 AppDelegate 启动流程中集成 fetchCredentials() 调用
    - 修改 `AIInputMethod/Sources/AIInputMethodApp.swift` 的 `applicationDidFinishLaunching`
    - 在 `loadDotEnv()` 之后、用户可触发录音之前，使用 `Task { try await speechService.fetchCredentials() }` 获取凭证
    - 失败时仅记录日志，不崩溃（用户触发录音时会看到已有的"请先配置凭证"提示）
    - _Requirements: 11.1, 11.4, 11.5_

  - [~] 9.3 清理 .env 文件中的 ASR 环境变量
    - 从 `AIInputMethod/.env` 移除 `DOUBAO_ASR_APP_ID`、`DOUBAO_ASR_ACCESS_TOKEN`、`DOUBAO_ASR_SECRET_KEY`
    - 从 `AIInputMethod/.env.example` 移除同上三个变量
    - _Requirements: 11.7_

  - [~] 9.4 编写 ASR 凭证获取属性测试
    - **Property 12: ASR 凭证获取响应解析正确性**
    - **Property 13: ASR 凭证获取失败保持空状态**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

- [~] 10. Final checkpoint - ASR 凭证迁移验证
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- PromptBuilder 和 PromptTemplates 暂时保留（服务端也使用相同模板），但客户端不再直接使用它们构建 Prompt
