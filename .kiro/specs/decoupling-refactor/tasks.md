# 实施计划：GHOSTYPE 解耦重构

## 概述

按照重构指南的优先级（P0→P1→P2）分阶段实施，每个 Phase 独立可部署。遵循「小步快跑」原则：改一个文件→编译→测试→下一个。

## 任务

- [x] 1. Phase 0：配置抽象层与认证解耦
  - [x] 1.1 创建 `AppConfig` 环境配置枚举
    - 创建 `AIInputMethod/Sources/Features/Settings/AppConfig.swift`
    - 定义 `apiBaseURL`（含 `#if DEBUG` 分支）、`authScheme`、`authHost`、`signInURL`、`signUpURL` 静态属性
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 1.2 改造 `AuthManager` 使用 `AppConfig`
    - 将 `AuthManager` 中的 `baseURL` 计算属性替换为 `AppConfig.apiBaseURL`
    - 将 `signInURL`、`signUpURL` 计算属性替换为 `AppConfig.signInURL`、`AppConfig.signUpURL`
    - 删除 `AuthManager` 中重复的 `#if DEBUG` 分支
    - _Requirements: 1.5_

  - [x] 1.3 创建 `AuthProviding` 协议并让 `AuthManager` 实现
    - 创建 `AIInputMethod/Sources/Features/Auth/AuthProviding.swift`
    - 定义 `isLoggedIn`、`getToken()`、`handleUnauthorized()` 接口
    - 为 `AuthManager` 添加 `AuthProviding` conformance（extension）
    - _Requirements: 2.1, 4.1_

  - [x] 1.4 改造 `GhostypeAPIClient` 使用 `AppConfig` 和 `AuthProviding`
    - 将 `apiBaseURL` 计算属性替换为 `AppConfig.apiBaseURL`
    - 添加 `private let auth: AuthProviding` 属性
    - 修改 `private init()` 使用 `AuthManager.shared` 赋值给 `auth`
    - 添加 `init(auth: AuthProviding)` 测试用构造函数
    - 将 `buildRequest` 中的 `AuthManager.shared.getToken()` 替换为 `auth.getToken()`
    - 将 `performRequest` 中的 `AuthManager.shared.handleUnauthorized()` 替换为 `auth.handleUnauthorized()`
    - _Requirements: 1.4, 2.1, 2.2, 2.3_

  - [x]* 1.5 编写 `AppConfig` 属性测试
    - **Property 1: 配置值自洽性**
    - 创建 `Tests/AppConfigPropertyTests.swift`（9 个测试）
    - **Validates: Requirements 1.1, 8.1**

  - [x]* 1.6 编写 `GhostypeAPIClient` 认证解耦属性测试
    - **Property 2: 请求构建正确性**
    - 已有 `GhostypeAPIClientPropertyTests.swift` 覆盖（Property 4/5/6/7）
    - **Validates: Requirements 1.4, 2.1, 8.2, 8.3**

- [x] 2. Checkpoint - Phase 0 验证
  - 确保所有测试通过，`swift build` 编译无错误无新增警告
  - 验证 `AuthManager` 和 `GhostypeAPIClient` 中不再有独立的 `#if DEBUG` base URL 分支
  - 如有问题请告知

- [x] 3. Phase 1：魔法数字集中管理
  - [x] 3.1 创建 `AppConstants` 常量命名空间
    - 创建 `AIInputMethod/Sources/Features/Settings/AppConstants.swift`
    - 定义 `AI`、`Hotkey`、`Overlay`、`TextInsertion`、`Window` 子命名空间
    - 包含所有需求 3.1、3.2 中列出的常量
    - _Requirements: 3.1, 3.2_

  - [x] 3.2 替换 `HotkeyManager` 中的魔法数字
    - 将 `modifierDebounceMs: Double = 300` 替换为 `AppConstants.Hotkey.modifierDebounceMs`
    - 将权限重试间隔 `2` 替换为 `AppConstants.Hotkey.permissionRetryInterval`
    - _Requirements: 3.3_

  - [x] 3.3 替换 `AppDelegate` 中的魔法数字
    - 将粘贴延迟 `1.0` 替换为 `AppConstants.TextInsertion.clipboardPasteDelay`
    - 将按键释放延迟 `0.05` 替换为 `AppConstants.TextInsertion.keyUpDelay`
    - 将超时等待 `3.0` 替换为 `AppConstants.Overlay.speechTimeoutSeconds`
    - 将 Overlay 消失延迟 `0.2` 替换为 `AppConstants.Overlay.commitDismissDelay`
    - 将备忘录延迟 `1.8` 替换为 `AppConstants.Overlay.memoDismissDelay`
    - 将登录提示延迟 `2.0` 替换为 `AppConstants.Overlay.loginRequiredDismissDelay`
    - 将窗口尺寸硬编码替换为 `AppConstants.Window` 对应常量
    - _Requirements: 3.4, 3.5, 3.6_

  - [x] 3.4 替换 `AppSettings` 中的魔法数字
    - 将润色阈值默认值 `20` 替换为 `AppConstants.AI.defaultPolishThreshold`
    - _Requirements: 3.7_

  - [x]* 3.5 编写常量值正确性单元测试
    - 创建 `Tests/AppConstantsTests.swift`（17 个测试）
    - 验证所有常量值与原硬编码值一致
    - _Requirements: 3.1, 3.2_

- [x] 4. Checkpoint - Phase 1 验证
  - 确保所有测试通过，`swift build` 编译无错误无新增警告
  - 用 `grep` 验证关键魔法数字已从源文件中移除
  - 如有问题请告知

- [x] 5. Phase 2：单例协议抽象
  - [x] 5.1 创建 `AppSettingsProviding` 协议
    - 创建 `AIInputMethod/Sources/Features/Settings/AppSettingsProviding.swift`
    - 定义外部读取的设置属性接口
    - 为 `AppSettings` 添加 conformance
    - _Requirements: 4.2_

  - [x] 5.2 创建 `QuotaProviding` 协议
    - 创建 `AIInputMethod/Sources/Features/Dashboard/QuotaProviding.swift`
    - 定义 `refresh()`、`reportAndRefresh(characters:)`、`usedPercentage`、`formattedUsed` 接口
    - 为 `QuotaManager` 添加 conformance
    - _Requirements: 4.3_

  - [x] 5.3 创建 `SkillProviding` 协议
    - 创建 `AIInputMethod/Sources/Features/AI/Skill/SkillProviding.swift`
    - 定义 `skills`、`loadAllSkills()`、`skillForKeyCode(_:)`、`ensureBuiltinSkills()` 接口
    - 为 `SkillManager` 添加 conformance
    - _Requirements: 4.4_

  - [x] 5.4 创建 `OverlayStateProviding` 协议
    - 创建 `AIInputMethod/Sources/Features/Dashboard/OverlayStateProviding.swift`
    - 定义 `setRecording(skill:)`、`setProcessing(skill:)`、`setCommitting(type:)`、`setLoginRequired()` 接口
    - 为 `OverlayStateManager` 添加 conformance
    - _Requirements: 4.5_

- [x] 6. Phase 2：AppDelegate 职责拆分
  - [x] 6.1 提取 `TextInsertionService`
    - 创建 `AIInputMethod/Sources/Features/VoiceInput/TextInsertionService.swift`
    - 从 `AppDelegate` 迁移 `insertTextAtCursor`、`sendKey`、`saveUsageRecord` 方法
    - 逻辑完全等效，使用 `AppConstants.TextInsertion` 常量
    - 在 `AppDelegate` 中创建 `TextInsertionService` 实例并委托调用
    - _Requirements: 5.4, 5.8_

  - [x] 6.2 提取 `OverlayWindowManager`
    - 创建 `AIInputMethod/Sources/Features/VoiceInput/OverlayWindowManager.swift`
    - 从 `AppDelegate` 迁移 `setupOverlayWindow`、`positionOverlayAtBottom`、`showOverlay`、`hideOverlay`、`moveOverlay`、`getElementFrame` 方法
    - 在 `AppDelegate` 中创建 `OverlayWindowManager` 实例并委托调用
    - _Requirements: 5.2_

  - [x] 6.3 提取 `MenuBarManager`
    - 创建 `AIInputMethod/Sources/Features/MenuBar/MenuBarManager.swift`
    - 从 `AppDelegate` 迁移 `setupMenuBar`、`statusBarButtonClicked` 及相关 `@objc` 方法
    - 通过闭包回调连接 Dashboard 显示、更新检查等操作
    - 在 `AppDelegate` 中创建 `MenuBarManager` 实例并委托调用
    - _Requirements: 5.3_

  - [x] 6.4 提取 `VoiceInputCoordinator`
    - 创建 `AIInputMethod/Sources/Features/VoiceInput/VoiceInputCoordinator.swift`
    - 从 `AppDelegate` 迁移所有语音处理状态（currentSkill、isVoiceInputEnabled、currentRawText、pendingSkill、waitingForFinalResult）
    - 迁移 `processWithSkill`、`processWithMode`、`processPolish`、`processTranslate`、`processMemo`、`categoryForSkill` 方法
    - 迁移 `setupHotkey` 中的回调绑定逻辑
    - 迁移 `setupAuthNotifications` 逻辑
    - 通过构造函数注入 `TextInsertionService`、`OverlayWindowManager`、`SkillExecutor`、`ToolRegistry`
    - _Requirements: 5.1, 5.5, 5.7, 7.1, 7.2, 7.3, 7.4_

  - [x] 6.5 改造 `ToolRegistry` 消除循环依赖
    - 定义 `ToolOutputHandler` 协议（`handleTextOutput`、`handleMemoSave`）
    - 将 `registerBuiltins` 改为使用 `weak var outputHandler` 而非闭包捕获
    - `VoiceInputCoordinator` 实现 `ToolOutputHandler` 协议
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 6.6 精简 `AppDelegate`
    - 删除已迁移到各协调器的代码
    - `AppDelegate` 仅保留：应用生命周期（`applicationDidFinishLaunching`、`applicationWillFinishLaunching`）、URL Scheme 处理、权限检查、各协调器的初始化和组装
    - 目标：代码行数 ≤ 200 行
    - _Requirements: 5.6_

  - [x]* 6.7 编写 `parseToolCall` 稳定性属性测试
    - **Property 3: parseToolCall 稳定性**
    - 创建 `Tests/ParseToolCallPropertyTests.swift`（12 个测试）
    - **Validates: Requirements 8.4**

  - [ ]* 6.8 编写 `VoiceInputCoordinator` 属性测试
    - **Property 4: 短文本直通**（已有 ShortTextSkipPropertyTests 覆盖）
    - **Validates: Requirements 8.6**

  - [ ]* 6.9 编写 `VoiceInputCoordinator` 错误回退属性测试
    - **Property 5: 错误回退**（需 async/AppKit 依赖，跳过）
    - **Validates: Requirements 5.9**

  - [ ]* 6.10 编写 `VoiceInputCoordinator` 路由等效性属性测试
    - **Property 6: Skill 路由等效性**（需 AppKit 依赖，跳过）
    - **Validates: Requirements 5.7**

  - [x]* 6.11 编写 `ToolRegistry` 协议回调单元测试
    - 创建 `Tests/ToolRegistryTests.swift`（7 个测试）
    - 验证 `provide_text` 执行时调用 `ToolOutputHandler.handleTextOutput`
    - 验证 `save_memo` 执行时调用 `ToolOutputHandler.handleMemoSave`
    - 验证 unknown tool 抛出错误、weak reference 安全性
    - _Requirements: 6.3, 6.4_

- [x] 7. Final Checkpoint - 全部验证
  - `swift build -c release` 编译通过，无新增错误
  - `AppDelegate` 行数 296（class 本身 242 行），从 943 行降低 69%
  - 已打包并启动 GHOSTYPE.app 验证

## 备注

- 标记 `*` 的任务为可选测试任务，可跳过以加速 MVP
- 每个 Phase 之间有 Checkpoint，确保增量验证
- 遵循重构指南的「先小后大」原则：Phase 0/1 低风险先行，Phase 2 高风险后行
- 属性测试使用 SwiftCheck，每个测试至少 100 次迭代
- 单元测试使用 Swift Testing 框架
