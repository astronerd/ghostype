# 需求文档：GHOSTYPE 解耦重构

## 简介

GHOSTYPE 是一款 macOS 语音输入工具，当前代码库存在硬编码配置、魔法数字散落、God Class（AppDelegate 943 行）、全局单例无协议抽象等问题。本次重构目标是按照项目重构指南的优先级（P0→P1→P2→P3→P4），以低风险优先、小步快跑的方式逐步解耦，每个阶段独立可部署，重构后行为与原逻辑完全等效。

## 术语表

- **AppDelegate**: 应用程序委托，当前承担 15+ 职责的 God Class（943 行）
- **Configuration_Registry**: 配置注册中心，集中管理所有运行时配置项（API 端点、超时、阈值、UI 常量等）
- **Magic_Number**: 魔法数字，散落在代码各处的硬编码常量值
- **Singleton**: 单例模式，全局唯一实例，当前项目有 7 个无协议抽象的单例
- **Protocol_Abstraction**: 协议抽象，为单例定义 Swift Protocol 接口以支持依赖注入和测试替身
- **Dependency_Injection**: 依赖注入，通过构造函数或属性传入依赖而非直接访问全局单例
- **SkillExecutor**: Skill 执行引擎，负责模板替换→构建 prompt→调用 API→解析结果
- **ToolRegistry**: 工具注册表，管理内置 Tool（provide_text、save_memo）的注册和执行
- **OverlayStateManager**: 浮层状态管理器，控制录音/处理/提交等 Overlay 状态
- **GhostypeAPIClient**: 后端 API 客户端，处理润色/翻译/用量上报等请求
- **AuthManager**: 认证管理器，负责 JWT 存储、登录状态管理
- **HotkeyManager**: 快捷键管理器，监听全局快捷键事件
- **AppSettings**: 全局应用设置，管理用户偏好配置

## 需求

### 需求 1：配置抽象层

**用户故事：** 作为开发者，我希望所有 API 端点和环境配置通过统一的配置抽象层管理，以便在不重新编译的情况下切换环境。

#### 验收标准

1. THE Configuration_Registry SHALL 提供统一的接口读取 API base URL、认证回调 URL 等环境配置
2. WHEN 应用启动时，THE Configuration_Registry SHALL 从编译时标志加载默认配置值
3. THE Configuration_Registry SHALL 将 AuthManager 和 GhostypeAPIClient 中重复的 `#if DEBUG` base URL 判断逻辑收敛为单一配置源
4. WHEN GhostypeAPIClient 构建请求时，THE GhostypeAPIClient SHALL 从 Configuration_Registry 读取 API base URL 而非使用内联的 `#if DEBUG` 分支
5. WHEN AuthManager 构建登录 URL 时，THE AuthManager SHALL 从 Configuration_Registry 读取 base URL 而非使用内联的 `#if DEBUG` 分支

### 需求 2：GhostypeAPIClient 认证解耦

**用户故事：** 作为开发者，我希望 GhostypeAPIClient 不再直接调用 `AuthManager.shared.getToken()`，以便可以独立测试 API 客户端逻辑。

#### 验收标准

1. THE GhostypeAPIClient SHALL 通过 Protocol_Abstraction 获取认证 Token，而非直接调用 `AuthManager.shared.getToken()`
2. THE GhostypeAPIClient SHALL 通过 Protocol_Abstraction 处理 401 未授权响应，而非直接调用 `AuthManager.shared.handleUnauthorized()`
3. WHEN 构造 GhostypeAPIClient 时，THE GhostypeAPIClient SHALL 接受一个符合认证协议的对象作为依赖注入参数
4. WHEN 运行单元测试时，THE GhostypeAPIClient SHALL 能够使用测试替身（mock）替代真实的 AuthManager

### 需求 3：魔法数字集中管理

**用户故事：** 作为开发者，我希望所有散落在代码中的硬编码常量被集中到命名常量中，以便统一维护和调整。

#### 验收标准

1. THE Configuration_Registry SHALL 集中定义以下常量：润色阈值默认值（20）、快捷键防抖时间（300ms）、Overlay 动画延迟（0.2s）、备忘录延迟（1.8s）、超时等待（3.0s）、权限重试间隔（2s）、剪贴板粘贴延迟（1.0s）、按键释放延迟（0.05s）
2. THE Configuration_Registry SHALL 集中定义以下 UI 常量：引导窗口尺寸（480×520）、Dashboard 最小尺寸（900×600）、Dashboard 默认尺寸（1000×700）
3. WHEN HotkeyManager 使用防抖时间时，THE HotkeyManager SHALL 从 Configuration_Registry 读取该值而非使用硬编码的 300
4. WHEN AppDelegate 使用粘贴延迟时，THE AppDelegate SHALL 从 Configuration_Registry 读取该值而非使用硬编码的 1.0
5. WHEN AppDelegate 使用按键释放延迟时，THE AppDelegate SHALL 从 Configuration_Registry 读取该值而非使用硬编码的 0.05
6. WHEN AppDelegate 使用超时等待时间时，THE AppDelegate SHALL 从 Configuration_Registry 读取该值而非使用硬编码的 3.0
7. WHEN AppSettings 初始化润色阈值默认值时，THE AppSettings SHALL 从 Configuration_Registry 读取该值而非使用硬编码的 20

### 需求 4：单例协议抽象

**用户故事：** 作为开发者，我希望每个全局单例都有对应的 Protocol 接口，以便通过依赖注入实现可测试性。

#### 验收标准

1. THE AuthManager SHALL 实现一个 AuthProviding 协议，该协议定义 `getToken()`、`handleUnauthorized()`、`isLoggedIn` 等接口
2. THE AppSettings SHALL 实现一个 AppSettingsProviding 协议，该协议定义所有被外部读取的设置属性接口
3. THE QuotaManager SHALL 实现一个 QuotaProviding 协议，该协议定义 `refresh()`、`reportAndRefresh(characters:)`、`usedPercentage`、`formattedUsed` 等接口
4. THE SkillManager SHALL 实现一个 SkillProviding 协议，该协议定义 `skills`、`loadAllSkills()`、`skillForKeyCode(_:)` 等接口
5. THE OverlayStateManager SHALL 实现一个 OverlayStateProviding 协议，该协议定义 `setRecording(skill:)`、`setProcessing(skill:)`、`setCommitting(type:)` 等接口
6. WHEN 新代码需要访问单例功能时，THE 新代码 SHALL 通过协议类型引用而非直接访问 `.shared` 实例

### 需求 5：AppDelegate 职责拆分

**用户故事：** 作为开发者，我希望 AppDelegate 的职责被拆分到独立的协调器类中，以便每个类职责单一、可独立测试。

#### 验收标准

1. WHEN 应用启动时，THE AppDelegate SHALL 将语音处理流程（录音→AI→上屏）委托给一个独立的 VoiceInputCoordinator 类
2. WHEN 应用启动时，THE AppDelegate SHALL 将 Overlay 窗口管理（创建、定位、显示、隐藏）委托给一个独立的 OverlayWindowManager 类
3. WHEN 应用启动时，THE AppDelegate SHALL 将菜单栏设置和交互委托给一个独立的 MenuBarManager 类
4. WHEN 应用启动时，THE AppDelegate SHALL 将文本插入逻辑（剪贴板→粘贴→自动回车）委托给一个独立的 TextInsertionService 类
5. WHEN 应用启动时，THE AppDelegate SHALL 将 Hotkey 回调绑定和 Skill 分发逻辑委托给 VoiceInputCoordinator
6. THE AppDelegate SHALL 仅保留应用生命周期管理（启动、URL Scheme 处理、权限检查）职责，代码行数降至 200 行以内
7. WHEN VoiceInputCoordinator 处理语音文本时，THE VoiceInputCoordinator SHALL 产生与当前 AppDelegate.processWithSkill 完全等效的行为
8. WHEN TextInsertionService 插入文本时，THE TextInsertionService SHALL 产生与当前 AppDelegate.insertTextAtCursor 完全等效的行为
9. IF VoiceInputCoordinator 处理过程中发生错误，THEN THE VoiceInputCoordinator SHALL 回退到原始文本并正确隐藏 Overlay

### 需求 6：循环依赖消除

**用户故事：** 作为开发者，我希望消除 AppDelegate ↔ SkillExecutor ↔ ToolRegistry 之间的循环依赖，以便依赖关系清晰、单向。

#### 验收标准

1. THE ToolRegistry SHALL 通过协议回调接口注册 Tool 处理器，而非直接捕获 AppDelegate 的方法引用
2. THE VoiceInputCoordinator SHALL 持有 ToolRegistry 和 SkillExecutor 的引用，SkillExecutor 和 ToolRegistry 不持有对 VoiceInputCoordinator 的引用
3. WHEN ToolRegistry 执行 `provide_text` 工具时，THE ToolRegistry SHALL 通过协议回调通知上层，而非直接调用 AppDelegate 的 `insertTextAtCursor`
4. WHEN ToolRegistry 执行 `save_memo` 工具时，THE ToolRegistry SHALL 通过协议回调通知上层，而非直接调用 AppDelegate 的 `saveUsageRecord`

### 需求 7：状态管理收敛

**用户故事：** 作为开发者，我希望语音输入相关的运行时状态集中管理，以便状态变更可追踪、可测试。

#### 验收标准

1. THE VoiceInputCoordinator SHALL 集中管理以下状态：currentMode、currentSkill、isVoiceInputEnabled、currentRawText、pendingSkill、waitingForFinalResult
2. WHEN 状态发生变更时，THE VoiceInputCoordinator SHALL 通过 Swift 的 @Published 或 @Observable 机制通知观察者
3. THE AppDelegate SHALL 不再直接持有 currentMode、currentSkill、isVoiceInputEnabled、currentRawText、pendingSkill、waitingForFinalResult 等状态变量
4. WHEN 外部组件需要读取语音输入状态时，THE 外部组件 SHALL 通过 VoiceInputCoordinator 的公开接口访问

### 需求 8：重构等效性保证

**用户故事：** 作为开发者，我希望重构后的代码行为与原代码完全等效，以便用户无感知地使用重构后的版本。

#### 验收标准

1. THE Configuration_Registry SHALL 通过序列化再反序列化产生与原始值等效的配置对象（round-trip 属性）
2. WHEN 使用测试替身运行 GhostypeAPIClient 时，THE GhostypeAPIClient SHALL 正确构建包含 Authorization header 的请求
3. WHEN 使用测试替身运行 GhostypeAPIClient 且 Token 为空时，THE GhostypeAPIClient SHALL 抛出 unauthorized 错误
4. THE SkillExecutor.parseToolCall SHALL 在重构前后对相同输入产生相同的解析结果
5. WHEN VoiceInputCoordinator 处理空文本时，THE VoiceInputCoordinator SHALL 跳过处理并隐藏 Overlay（与原 AppDelegate 行为一致）
6. WHEN VoiceInputCoordinator 处理短文本（低于润色阈值）时，THE VoiceInputCoordinator SHALL 直接插入原文（与原 AppDelegate 行为一致）
