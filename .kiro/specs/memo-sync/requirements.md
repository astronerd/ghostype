# 需求文档：Quick Memo 同步到笔记应用

## 简介

GHOSTYPE 的 Quick Memo（快速笔记）功能允许用户通过语音快速记录灵感。本功能扩展 Quick Memo，支持将笔记自动同步到用户常用的第三方笔记应用（Obsidian、Apple Notes、Notion、Bear），让用户的语音笔记无缝融入现有知识管理工作流。

## 术语表

- **MemoSyncService**：笔记同步服务的统一协议，定义所有同步适配器的公共接口
- **SyncAdapter**：实现 MemoSyncService 协议的具体同步适配器，每个目标应用对应一个适配器
- **ObsidianAdapter**：Obsidian 同步适配器，通过文件系统写入 Markdown 文件到 Vault 目录
- **AppleNotesAdapter**：Apple Notes 同步适配器，通过 AppleScript 创建/追加笔记
- **NotionAdapter**：Notion 同步适配器，通过 Notion Internal Integration API 同步笔记
- **BearAdapter**：Bear 同步适配器，通过 x-callback-url scheme 创建/追加笔记
- **GroupingMode**：笔记分组模式，决定多条 Memo 如何组织到目标笔记中（按天、按周、每条单独）
- **TitleTemplate**：标题模板，支持变量替换（日期、时间等）的笔记标题格式
- **UsageRecord**：CoreData 中存储 Memo 的实体，category 为 "memo"
- **Internal_Integration**：Notion 的集成方式，用户在 Notion 开发者门户创建集成并获取 Token，无需 OAuth 流程
- **Vault_Directory**：Obsidian 的本地文件夹路径，所有笔记以 Markdown 文件形式存储于此

## 需求

### 需求 1：同步服务协议与适配器架构

**用户故事：** 作为开发者，我希望有一个统一的同步协议和适配器架构，以便可以方便地扩展支持更多笔记应用。

#### 验收标准

1. THE MemoSyncService 协议 SHALL 定义 `sync(memo:config:)` 异步方法，接收 Memo 内容和同步配置，返回同步结果
2. THE MemoSyncService 协议 SHALL 定义 `validateConnection()` 异步方法，用于验证目标服务的连接状态
3. THE MemoSyncService 协议 SHALL 定义 `serviceName` 属性，返回适配器对应的服务名称
4. WHEN 新增一个笔记应用支持时，THE 开发者 SHALL 仅需实现 MemoSyncService 协议即可完成接入

### 需求 2：Obsidian 同步适配器

**用户故事：** 作为 Obsidian 用户，我希望 Quick Memo 能自动同步到我的 Obsidian Vault，以便在 Obsidian 中管理语音笔记。

#### 验收标准

1. WHEN 用户配置了 Obsidian Vault 目录路径时，THE ObsidianAdapter SHALL 将 Memo 内容写入该目录下的 Markdown 文件
2. WHEN 分组模式为「每条单独」时，THE ObsidianAdapter SHALL 为每条 Memo 创建一个独立的 .md 文件
3. WHEN 分组模式为「按天」时，THE ObsidianAdapter SHALL 将同一天的 Memo 追加到同一个 .md 文件中
4. WHEN 分组模式为「按周」时，THE ObsidianAdapter SHALL 将同一周的 Memo 追加到同一个 .md 文件中
5. IF Vault 目录路径不存在或无写入权限，THEN THE ObsidianAdapter SHALL 返回包含具体原因的错误信息
6. THE ObsidianAdapter SHALL 使用 TitleTemplate 生成文件名，支持日期和时间变量替换
7. WHEN 向已有文件追加内容时，THE ObsidianAdapter SHALL 在新内容前添加时间戳分隔符

### 需求 3：Apple Notes 同步适配器

**用户故事：** 作为 Apple Notes 用户，我希望 Quick Memo 能自动同步到 Apple Notes，以便在 Apple 生态中统一管理笔记。

#### 验收标准

1. WHEN 用户启用 Apple Notes 同步时，THE AppleNotesAdapter SHALL 通过 AppleScript 在 Apple Notes 中创建或追加笔记
2. WHEN 分组模式为「每条单独」时，THE AppleNotesAdapter SHALL 为每条 Memo 创建一个独立的笔记
3. WHEN 分组模式为「按天」或「按周」时，THE AppleNotesAdapter SHALL 将 Memo 追加到对应时间段的已有笔记中
4. IF AppleScript 执行失败，THEN THE AppleNotesAdapter SHALL 返回包含 AppleScript 错误描述的错误信息
5. THE AppleNotesAdapter SHALL 支持用户指定目标文件夹名称，默认为 "GHOSTYPE"

### 需求 4：Notion 同步适配器

**用户故事：** 作为 Notion 用户，我希望 Quick Memo 能自动同步到 Notion，以便在 Notion 中集中管理知识。

#### 验收标准

1. WHEN 用户配置了 Notion Internal Integration Token 和目标数据库 ID 时，THE NotionAdapter SHALL 通过 Notion API 将 Memo 同步到指定数据库
2. WHEN 分组模式为「每条单独」时，THE NotionAdapter SHALL 为每条 Memo 创建一个独立的 Notion Page
3. WHEN 分组模式为「按天」或「按周」时，THE NotionAdapter SHALL 查找对应时间段的已有 Page 并追加内容块
4. IF Notion API 返回 401 错误，THEN THE NotionAdapter SHALL 返回 Token 无效或过期的错误提示
5. IF Notion API 返回 404 错误，THEN THE NotionAdapter SHALL 返回数据库未找到或未授权 Integration 访问的错误提示
6. THE NotionAdapter SHALL 将 Token 存储在 macOS Keychain 中，禁止明文存储

### 需求 5：Bear 同步适配器

**用户故事：** 作为 Bear 用户，我希望 Quick Memo 能自动同步到 Bear，以便在 Bear 中管理语音笔记。

#### 验收标准

1. WHEN 用户启用 Bear 同步时，THE BearAdapter SHALL 通过 x-callback-url scheme 在 Bear 中创建或追加笔记
2. WHEN 分组模式为「每条单独」时，THE BearAdapter SHALL 调用 `bear://x-callback-url/create` 创建独立笔记
3. WHEN 分组模式为「按天」或「按周」时，THE BearAdapter SHALL 调用 `bear://x-callback-url/add-text` 向已有笔记追加内容
4. IF Bear 应用未安装，THEN THE BearAdapter SHALL 返回应用未安装的错误提示
5. THE BearAdapter SHALL 支持用户指定默认标签，同步的笔记自动添加该标签

### 需求 6：同步配置管理

**用户故事：** 作为用户，我希望能灵活配置同步行为（分组方式、标题格式、内容模板），以便适配我的笔记管理习惯。

#### 验收标准

1. THE 同步配置 SHALL 支持三种分组模式：按天（一天一个笔记）、按周（一周一个笔记）、每条单独（每条 Memo 一个笔记）
2. THE 同步配置 SHALL 支持标题模板，包含以下变量：`{date}`（日期）、`{time}`（时间）、`{weekNumber}`（周数）、`{year}`（年份）
3. WHEN 用户未自定义标题模板时，THE 同步配置 SHALL 使用默认模板 "GHOSTYPE Memo {date}"
4. THE 同步配置 SHALL 为每个笔记应用独立存储，允许不同应用使用不同的分组模式和标题模板
5. THE 同步配置 SHALL 通过 UserDefaults 持久化存储，支持升级场景下的数据保留

### 需求 7：同步触发与执行

**用户故事：** 作为用户，我希望 Memo 保存后能自动同步到已配置的笔记应用，无需手动操作。

#### 验收标准

1. WHEN 一条 Memo 通过 `handleMemoSave` 或 `saveUsageRecord(category: .memo)` 保存成功后，THE 同步服务 SHALL 自动触发已启用的同步适配器执行同步
2. WHILE 同步正在执行时，THE 同步服务 SHALL 在后台线程异步执行，不阻塞语音输入主流程
3. IF 同步执行失败，THEN THE 同步服务 SHALL 记录错误日志（通过 FileLogger），不影响 Memo 本地保存
4. WHEN 同步成功完成时，THE 同步服务 SHALL 通过 FileLogger 记录同步结果（目标服务名称和 Memo 摘要）
5. THE 同步服务 SHALL 支持同时启用多个同步适配器，并行执行同步

### 需求 8：同步设置界面

**用户故事：** 作为用户，我希望在 Dashboard 中有一个直观的同步设置页面，以便配置和管理各笔记应用的同步。

#### 验收标准

1. THE 同步设置页面 SHALL 在 Dashboard 中作为 Memo 页面的子设置或独立设置区域展示
2. THE 同步设置页面 SHALL 为每个支持的笔记应用显示一个配置卡片，包含启用开关、连接状态、配置入口
3. WHEN 用户点击某个笔记应用的配置卡片时，THE 同步设置页面 SHALL 展示该应用的详细配置项（路径/Token/文件夹等）
4. THE 同步设置页面 SHALL 提供「测试连接」按钮，调用 `validateConnection()` 验证配置是否正确
5. WHEN 连接测试成功时，THE 同步设置页面 SHALL 显示绿色成功状态
6. WHEN 连接测试失败时，THE 同步设置页面 SHALL 显示红色错误状态及具体错误原因
7. THE 同步设置页面 SHALL 遵循现有设计系统（DS.Colors、DS.Typography、DS.Spacing、DS.Layout）
8. THE 同步设置页面 SHALL 所有文案使用 `L.xxx` 本地化访问器，支持中英文切换

### 需求 9：Notion 配置引导教程

**用户故事：** 作为 Notion 用户，我希望有一个分步引导教程帮助我完成 Internal Integration 的配置，以便顺利设置同步。

#### 验收标准

1. WHEN 用户首次配置 Notion 同步时，THE 引导教程 SHALL 以分步向导形式展示配置流程
2. THE 引导教程 SHALL 包含以下步骤：打开 Notion 开发者门户、创建 Integration、复制 Token、粘贴到 GHOSTYPE、选择目标数据库
3. THE 引导教程 SHALL 为每个步骤提供截图或示意图说明
4. THE 引导教程 SHALL 提供「打开 Notion 开发者门户」的快捷链接按钮
5. WHEN 用户完成 Token 输入后，THE 引导教程 SHALL 自动执行连接测试并显示结果

### 需求 10：同步状态与错误反馈

**用户故事：** 作为用户，我希望能看到每条 Memo 的同步状态，以便了解同步是否成功。

#### 验收标准

1. WHEN 同步成功时，THE Overlay 状态提示 SHALL 显示同步成功的视觉反馈（在现有 "已保存" 提示基础上）
2. IF 同步失败，THEN THE 同步服务 SHALL 在下次应用启动时或用户手动触发时重试失败的同步任务
3. THE MemoPage SHALL 为已同步的 Memo 卡片显示同步状态图标（已同步/同步失败/未同步）

### 需求 11：单向同步策略与边界场景处理

**用户故事：** 作为用户，我希望同步行为简单可预测，不会因为删除或配置变更导致数据丢失或混乱。

#### 验收标准

1. THE 同步服务 SHALL 采用单向推送策略：Memo 保存时推送到目标应用，推送完成后不再维护与目标笔记的关联
2. WHEN 用户在 GHOSTYPE 中删除一条 Memo 时，THE 同步服务 SHALL NOT 删除已同步到目标应用中的对应内容
3. WHEN 用户在目标应用中删除了笔记时，THE 同步服务 SHALL NOT 感知或反向同步该变更
4. WHEN 按天或按周模式下同步时，THE 适配器 SHALL 根据当前分组模式和标题模板生成目标笔记标识（文件名/标题），找到匹配的已有笔记则追加内容，找不到则新建笔记
5. WHEN 用户在目标应用中删除了按天/按周的聚合笔记后再次记录 Memo 时，THE 适配器 SHALL 自动新建一个同名笔记，不报错
6. WHEN 用户切换分组模式（如从按天切到按周再切回按天）时，THE 同步服务 SHALL 按当前生效的模式生成目标笔记标识，不维护历史模式的映射关系
7. WHEN 用户切换标题模板后，THE 同步服务 SHALL 使用新模板生成目标笔记标识，旧模板创建的笔记保留在目标应用中不受影响
8. THE 同步服务 SHALL NOT 在本地维护「Memo ID → 目标笔记 ID」的映射表，每次同步均通过标题/文件名实时匹配

### 需求 12：文件系统访问权限持久化（Obsidian）

**用户故事：** 作为 Obsidian 用户，我希望选择 Vault 目录后，应用重启仍然能写入该目录，无需每次重新授权。

#### 验收标准

1. WHEN 用户通过 NSOpenPanel 选择 Obsidian 目录时，THE 应用 SHALL 创建 security-scoped bookmark 并持久化存储
2. WHEN 应用启动时，THE ObsidianAdapter SHALL 通过 security-scoped bookmark 恢复对目录的访问权限
3. IF security-scoped bookmark 失效（如目录被移动或删除），THEN THE ObsidianAdapter SHALL 提示用户重新选择目录
4. THE 应用 SHALL 在同步写入前调用 `startAccessingSecurityScopedResource()`，写入完成后调用 `stopAccessingSecurityScopedResource()`

### 需求 13：Notion API 限流处理

**用户故事：** 作为 Notion 用户，我希望短时间内记录多条 Memo 时不会因为 API 限流导致同步失败。

#### 验收标准

1. THE NotionAdapter SHALL 对 API 请求进行串行排队，避免并发请求触发 Notion rate limit（3 requests/second）
2. IF Notion API 返回 429 (Too Many Requests) 错误，THEN THE NotionAdapter SHALL 按照响应头中的 Retry-After 值延迟后重试
3. WHEN 多条 Memo 在短时间内触发同步时，THE NotionAdapter SHALL 按 FIFO 顺序依次执行，不丢弃任何同步任务

### 需求 14：同步内容格式

**用户故事：** 作为用户，我希望同步到笔记应用的内容格式清晰可读，每条 Memo 有时间戳标记。

#### 验收标准

1. WHEN 向已有笔记追加内容时，THE 适配器 SHALL 在每条 Memo 前添加时间戳行，格式为 `HH:mm`（如 `14:32`）
2. THE 适配器 SHALL 在每条 Memo 之间添加空行分隔
3. FOR Obsidian，THE 内容格式 SHALL 使用 Markdown：时间戳为 `**HH:mm**`，内容为普通文本段落
4. FOR Notion，THE 内容格式 SHALL 使用 paragraph block，时间戳为 bold text
5. FOR Bear，THE 内容格式 SHALL 使用 Markdown，与 Obsidian 格式一致
6. FOR Apple Notes，THE 内容格式 SHALL 使用纯文本，时间戳单独一行

### 需求 15：历史数据同步策略

**用户故事：** 作为用户，我希望开启同步后只同步新记录的 Memo，不会把历史数据全部推送到笔记应用。

#### 验收标准

1. WHEN 用户首次启用某个笔记应用的同步时，THE 同步服务 SHALL 仅同步启用时间点之后新保存的 Memo
2. THE 同步服务 SHALL NOT 自动回溯同步启用前的历史 Memo

### 需求 16：多语言本地化

**用户故事：** 作为用户，我希望同步功能的所有界面文案都支持中英文切换，与应用整体语言设置一致。

#### 验收标准

1. THE 同步功能涉及的所有 UI 文案 SHALL 通过 `L.xxx` 本地化访问器获取，禁止在代码中硬编码中文或英文字符串
2. THE 新增文案 SHALL 遵循现有本地化规范：在 `Strings.swift` 添加 key 定义，在 `Strings+Chinese.swift` 和 `Strings+English.swift` 分别添加翻译
3. THE Notion 引导教程中的步骤说明文案 SHALL 使用 `L.xxx` 本地化访问器
4. THE 同步状态提示（成功/失败/未同步）SHALL 使用 `L.xxx` 本地化访问器
5. THE 错误提示信息（路径不存在、Token 无效、应用未安装等）SHALL 使用 `L.xxx` 本地化访问器
6. THE 同步内容中的时间戳格式 SHALL 不受本地化影响，统一使用 `HH:mm` 格式
