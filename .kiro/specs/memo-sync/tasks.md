# 实现任务：Quick Memo 同步到笔记应用

## 模块 A：基础架构与数据模型

### Task A1: 数据模型与枚举定义
- [x] 创建 `Sources/Features/MemoSync/MemoSyncModels.swift`
- [x] 定义 `SyncServiceType` 枚举（obsidian, appleNotes, notion, bear）
- [x] 定义 `GroupingMode` 枚举（perNote, perDay, perWeek）
- [x] 定义 `SyncAdapterConfig` 结构体（groupingMode, titleTemplate, obsidianVaultBookmark, appleNotesFolderName, notionDatabaseId, bearDefaultTag）
- [x] 定义 `MemoSyncPayload` 结构体（content, timestamp, memoId）
- [x] 定义 `SyncResult` 枚举（success, failure(SyncError)）
- [x] 定义 `SyncError` 枚举（pathNotFound, noWritePermission, bookmarkExpired, appleScriptError, notionUnauthorized, notionDatabaseNotFound, notionRateLimited, notionApiError, bearNotInstalled, networkError, unknown）
- [x] 编译验证

### Task A2: MemoSyncService 协议
- [x] 创建 `Sources/Features/MemoSync/MemoSyncService.swift`
- [x] 定义 `MemoSyncService` 协议：`serviceName`、`sync(memo:config:) async -> SyncResult`、`validateConnection(config:) async -> SyncResult`
- [ ] 编译验证

### Task A3: SyncConfigStore 配置管理
- [x] 创建 `Sources/Features/MemoSync/SyncConfigStore.swift`
- [x] 实现 `config(for:)` / `save(config:for:)` — UserDefaults + Codable
- [x] 实现 `isEnabled(_:)` / `setEnabled(_:for:)` — 启用/禁用
- [x] 实现 `enabledSince(_:)` — 记录启用时间点（用于过滤历史数据）
- [x] UserDefaults key 格式：`memoSync.config.{serviceType}`、`memoSync.enabled.{serviceType}`、`memoSync.enabledSince.{serviceType}`
- [ ] 编译验证

### Task A4: TitleTemplateEngine 标题模板引擎
- [x] 创建 `Sources/Features/MemoSync/TitleTemplateEngine.swift`
- [x] 实现 `resolve(template:date:groupingMode:) -> String`
- [x] 支持变量：`{date}` → yyyy-MM-dd、`{time}` → HH:mm、`{weekNumber}` → 周数、`{year}` → 年份
- [x] 默认模板 "GHOSTYPE Memo {date}"
- [ ] 编译验证

### Task A5: MemoContentFormatter 内容格式化器
- [x] 创建 `Sources/Features/MemoSync/MemoContentFormatter.swift`
- [x] 实现 `format(content:timestamp:target:) -> String`
- [x] Obsidian/Bear (Markdown)：`**HH:mm**\n\n{content}\n\n`
- [x] Notion：返回结构化数据（paragraph block with bold timestamp）
- [x] Apple Notes：`HH:mm\n{content}\n\n`
- [x] 时间戳格式固定 HH:mm，不受 locale 影响
- [x] 编译验证

---

## 模块 B：同步适配器

### Task B1: ObsidianAdapter
- [x] 创建 `Sources/Features/MemoSync/Adapters/ObsidianAdapter.swift`
- [x] 实现 `sync(memo:config:)` — 根据 GroupingMode 决定文件名，写入/追加 Markdown
- [x] 实现 `validateConnection(config:)` — 检查 bookmark 有效性和目录可写
- [x] security-scoped bookmark：写入前 `startAccessingSecurityScopedResource()`，写入后 `stopAccessingSecurityScopedResource()`
- [x] 按天/按周模式：通过文件名匹配已有文件，找到则追加，找不到则新建
- [x] 错误处理：pathNotFound、noWritePermission、bookmarkExpired
- [ ] 编译验证

### Task B2: AppleNotesAdapter
- [x] 创建 `Sources/Features/MemoSync/Adapters/AppleNotesAdapter.swift`
- [x] 实现 `sync(memo:config:)` — 通过 NSAppleScript 创建/追加笔记
- [x] 实现 `validateConnection(config:)` — 测试 AppleScript 执行权限
- [x] 按标题查找已有笔记，找到则追加，找不到则新建
- [x] 默认文件夹 "GHOSTYPE"，用户可通过 `appleNotesFolderName` 自定义
- [x] 内容格式：纯文本，时间戳单独一行
- [x] 错误处理：appleScriptError
- [ ] 编译验证

### Task B3: NotionAdapter + NotionRateLimiter
- [x] 创建 `Sources/Features/MemoSync/Adapters/NotionAdapter.swift`
- [x] 创建 `Sources/Features/MemoSync/Adapters/NotionRateLimiter.swift`
- [x] 实现 `sync(memo:config:)` — 通过 Notion API 创建 Page 或追加 Block
- [x] 实现 `validateConnection(config:)` — 用 Token 调用 API 验证连接
- [x] Token 通过 `KeychainHelper` 存取，key: `memoSync.notion.token`
- [x] NotionRateLimiter：Swift Actor，串行 FIFO 队列，429 按 Retry-After 重试
- [x] 按标题查找已有 Page（Search API），找到则追加 Block，找不到则新建 Page
- [x] 内容格式：paragraph block，时间戳为 bold text
- [x] 错误处理：notionUnauthorized(401)、notionDatabaseNotFound(404)、notionRateLimited(429)、notionApiError、networkError
- [ ] 编译验证

### Task B4: BearAdapter
- [x] 创建 `Sources/Features/MemoSync/Adapters/BearAdapter.swift`
- [x] 实现 `sync(memo:config:)` — 通过 x-callback-url 创建/追加笔记
- [x] 实现 `validateConnection(config:)` — 检测 Bear 是否安装（`NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`）
- [x] perNote → `bear://x-callback-url/create`，perDay/perWeek → `bear://x-callback-url/add-text`（通过标题匹配）
- [x] 支持 `bearDefaultTag` 默认标签
- [x] 内容格式：Markdown，与 Obsidian 一致
- [x] 错误处理：bearNotInstalled
- [ ] 编译验证

---

## 模块 C：同步管理器与触发集成

### Task C1: MemoSyncManager
- [x] 创建 `Sources/Features/MemoSync/MemoSyncManager.swift`
- [x] 实现 `syncMemo(content:timestamp:)` — 读取已启用适配器，并行分发同步
- [x] 实现 `enabledAdapters() -> [(MemoSyncService, SyncAdapterConfig)]`
- [x] 历史数据过滤：仅同步 timestamp > enabledSince 的 Memo
- [x] 后台线程异步执行，不阻塞主流程
- [x] FileLogger 记录同步结果（成功/失败/重试）
- [x] 同步失败不影响本地 CoreData 保存
- [ ] 编译验证

### Task C2: TextInsertionService 集成
- [x] 修改 `Sources/Features/VoiceInput/TextInsertionService.swift`
- [x] 在 `saveUsageRecord` 方法中，当 `category == .memo` 且 CoreData 保存成功后，调用 `MemoSyncManager.shared.syncMemo(content:timestamp:)`
- [ ] 编译验证
- [x] `grep` 验证磁盘文件已更新

---

## 模块 D：本地化文案

### Task D1: Strings.swift 添加 MemoSync section
- [x] 在 `Strings.swift` 中添加 `L.MemoSync` 枚举和所有静态属性
- [x] 添加 `MemoSyncStrings` protocol
- [x] 在 `StringsTable` protocol 中添加 `memoSync` 属性
- [x] 文案范围：设置页标题、各适配器名称、分组模式名称、连接状态、错误提示、Notion 教程步骤、按钮文案等
- [ ] 编译验证

### Task D2: Strings+Chinese.swift 添加中文翻译
- [x] 实现 `ChineseMemoSyncStrings` 结构体
- [x] 在 `ChineseStrings` 中添加 `memoSync` 属性
- [ ] 编译验证

### Task D3: Strings+English.swift 添加英文翻译
- [x] 实现 `EnglishMemoSyncStrings` 结构体
- [x] 在 `EnglishStrings` 中添加 `memoSync` 属性
- [ ] 编译验证

---

## 模块 E：同步设置 UI

### Task E1: MemoSyncSettingsView 主设置页
- [x] 创建 `Sources/UI/Dashboard/Pages/MemoSync/MemoSyncSettingsView.swift`
- [x] 为每个笔记应用显示配置卡片：启用开关、连接状态指示、配置入口
- [x] 遵循 DS 设计系统（DS.Colors、DS.Typography、DS.Spacing、DS.Layout）
- [x] 所有文案使用 `L.MemoSync.xxx`
- [ ] 编译验证

### Task E2: ObsidianConfigView
- [x] 创建 `Sources/UI/Dashboard/Pages/MemoSync/ObsidianConfigView.swift`
- [x] NSOpenPanel 选择 Vault 目录（支持子目录）
- [x] 创建 security-scoped bookmark 并保存到 SyncAdapterConfig
- [x] 分组模式选择（按天/按周/每条单独）
- [x] 标题模板配置
- [x] 测试连接按钮
- [ ] 编译验证

### Task E3: AppleNotesConfigView
- [x] 创建 `Sources/UI/Dashboard/Pages/MemoSync/AppleNotesConfigView.swift`
- [x] 文件夹名称配置（默认 "GHOSTYPE"）
- [x] 分组模式选择
- [x] 标题模板配置
- [x] 测试连接按钮
- [x] 编译验证

### Task E4: NotionConfigView + NotionSetupWizard
- [x] 创建 `Sources/UI/Dashboard/Pages/MemoSync/NotionConfigView.swift`
- [x] 创建 `Sources/UI/Dashboard/Pages/MemoSync/NotionSetupWizard.swift`
- [x] 分步向导：打开开发者门户 → 创建 Integration → 复制 Token → 粘贴到 GHOSTYPE → 选择数据库
- [x] Token 输入后自动测试连接
- [x] Token 通过 KeychainHelper 存储
- [x] 数据库 ID 配置
- [x] 分组模式选择、标题模板配置
- [x] 「打开 Notion 开发者门户」快捷链接按钮
- [ ] 编译验证

### Task E5: BearConfigView
- [x] 创建 `Sources/UI/Dashboard/Pages/MemoSync/BearConfigView.swift`
- [x] 默认标签配置
- [ ] 分组模式选择
- [ ] 标题模板配置
- [x] 测试连接按钮（检测 Bear 是否安装）
- [ ] 编译验证

### Task E6: Dashboard 路由集成
- [x] 在 `NavItem` 中添加 `memoSync` case（或作为 Memo 页面的子入口）
- [x] 在 `DashboardView` 中添加路由到 `MemoSyncSettingsView`
- [ ] 编译验证

---

## 模块 F：同步状态反馈

### Task F1: MemoPage 同步状态图标
- [x] 修改 `MemoCard`，为已同步/同步失败/未同步的 Memo 显示状态图标
- [x] 需要在 MemoSyncManager 中维护最近同步结果的缓存（内存即可，不需要持久化）
- [ ] 编译验证

### Task F2: Overlay 同步成功提示
- [x] 修改 `OverlayView`，在 Memo 保存成功且同步成功时显示同步成功的视觉反馈
- [x] 在现有 "已保存" 提示基础上扩展
- [ ] 编译验证

---

## 模块 G：构建与验证

### Task G1: 完整构建验证
- [x] `bash ghostype.sh debug` 编译通过
- [x] 启动应用，进入 Dashboard 确认同步设置页面可访问
- [x] 确认 Memo 页面正常显示
