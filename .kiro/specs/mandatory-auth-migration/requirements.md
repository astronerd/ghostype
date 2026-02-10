# 需求文档：强制登录与鉴权迁移

## 简介

GHOSTYPE macOS 客户端需要配合服务端架构改造，将 JWT 鉴权从可选变为必填，移除匿名使用模式。核心变更包括：强制登录、401 处理从静默回退改为弹窗提示、额度计量从 device_id 迁移到 user_id、生产环境 URL 更新。

## 术语表

- **GhostypeAPIClient**: GHOSTYPE 后端 API 客户端单例，负责组装和发送所有 HTTP 请求
- **AuthManager**: 用户认证管理器单例，负责 Clerk 登录流程、JWT 存储、登录状态管理
- **HotkeyManager**: 全局快捷键管理器，监听用户按键触发语音输入
- **QuotaManager**: 额度管理器单例，从服务端获取字符额度数据
- **JWT**: JSON Web Token，Clerk 签发的用户认证令牌，存储在 Keychain 中
- **Keychain**: macOS 系统级安全存储，用于持久化 JWT
- **X-Device-Id**: HTTP Header，UUID v4 格式的设备标识符，仅用于设备绑定
- **Overlay**: 浮动窗口，显示录音/处理/完成状态
- **AppDelegate**: 应用主代理，协调各模块的生命周期和事件分发

## 需求

### 需求 1：生产环境 URL 更新

**用户故事：** 作为开发者，我希望客户端指向正确的生产环境域名，以便与改造后的服务端正常通信。

#### 验收标准

1. THE GhostypeAPIClient SHALL 在 Release 构建中使用 `https://www.ghostype.one` 作为 baseURL
2. THE AuthManager SHALL 在 Release 构建中使用 `https://www.ghostype.one` 作为 baseURL
3. THE GhostypeAPIClient SHALL 在 Debug 构建中保持使用 `http://localhost:3000` 作为 baseURL
4. THE AuthManager SHALL 在 Debug 构建中保持使用 `http://localhost:3000` 作为 baseURL

### 需求 2：JWT 必填与请求拦截

**用户故事：** 作为系统管理员，我希望所有 API 请求必须携带有效的 JWT，以便服务端能正确识别用户身份并执行鉴权。

#### 验收标准

1. WHEN GhostypeAPIClient 构建请求时，IF Keychain 中无 JWT，THEN THE GhostypeAPIClient SHALL 返回错误而非发送无鉴权请求
2. WHEN GhostypeAPIClient 构建请求时，IF Keychain 中有 JWT，THEN THE GhostypeAPIClient SHALL 在 HTTP Header 中添加 `Authorization: Bearer {jwt}`
3. THE GhostypeAPIClient SHALL 在所有请求中携带 `X-Device-Id` Header，值为 DeviceIdManager 提供的 UUID v4
4. THE GhostypeAPIClient SHALL 在所有请求中携带 `Content-Type: application/json` Header

### 需求 3：强制登录流程

**用户故事：** 作为用户，我希望在未登录时被引导完成登录，以便能正常使用语音输入功能。

#### 验收标准

1. WHEN App 启动时，THE AppDelegate SHALL 检查 Keychain 中是否存在 JWT
2. WHEN App 启动时 Keychain 中无 JWT，THEN THE AppDelegate SHALL 将语音输入功能标记为禁用状态
3. WHILE 用户处于未登录状态，WHEN 用户按下快捷键触发语音输入，THEN THE HotkeyManager 回调 SHALL 拒绝启动录音并通过 Overlay 显示「请先登录」提示
4. WHEN 用户成功登录（收到 `userDidLogin` 通知），THEN THE AppDelegate SHALL 恢复语音输入功能为启用状态
5. WHEN 用户成功登录，THEN THE AppDelegate SHALL 重新获取 ASR 凭证

### 需求 4：401 未授权处理

**用户故事：** 作为用户，我希望在登录过期时收到明确提示并能快速重新登录，以便尽快恢复使用。

#### 验收标准

1. WHEN GhostypeAPIClient 收到 HTTP 401 响应，THEN THE AuthManager SHALL 清除 Keychain 中的 JWT
2. WHEN GhostypeAPIClient 收到 HTTP 401 响应，THEN THE AuthManager SHALL 将 `isLoggedIn` 状态设为 false
3. WHEN GhostypeAPIClient 收到 HTTP 401 响应，THEN THE AuthManager SHALL 在主线程弹出 NSAlert 对话框，标题为「登录已过期」，内容为「请重新登录后继续使用」
4. THE NSAlert 对话框 SHALL 提供「重新登录」和「稍后」两个按钮
5. WHEN 用户点击「重新登录」按钮，THEN THE AuthManager SHALL 调用 `openLogin()` 打开系统浏览器进入 Clerk 登录页
6. WHEN 用户点击「稍后」按钮，THEN THE NSAlert 对话框 SHALL 关闭且不执行额外操作
7. WHEN AuthManager 处理 401 后，THEN THE AppDelegate SHALL 禁用语音输入功能，等待用户重新登录

### 需求 5：Clerk 生产环境配置

**用户故事：** 作为开发者，我希望客户端使用 Clerk 生产环境的配置，以便用户能通过正式域名完成登录。

#### 验收标准

1. THE AuthManager SHALL 在 Release 构建中使用 `https://www.ghostype.one/sign-in` 作为登录页 URL
2. THE AuthManager SHALL 在 Release 构建中使用 `https://www.ghostype.one/sign-up` 作为注册页 URL
3. WHEN 用户登录成功后浏览器重定向回客户端，THEN THE AuthManager SHALL 正确处理 `ghostype://auth?token={jwt}` 回调并将 JWT 存入 Keychain
4. THE AuthManager SHALL 在登录 URL 中附加 `redirect_url=ghostype://auth` 参数

### 需求 6：语音输入功能的登录状态守卫

**用户故事：** 作为用户，我希望在未登录时不会触发无效的 API 请求，以便获得清晰的状态反馈。

#### 验收标准

1. THE AppDelegate SHALL 维护一个 `isVoiceInputEnabled` 布尔状态，表示语音输入功能是否可用
2. WHEN `isVoiceInputEnabled` 为 false，WHEN 用户按下快捷键，THEN THE AppDelegate SHALL 阻止录音启动
3. WHEN `isVoiceInputEnabled` 为 false，THEN THE Overlay SHALL 显示登录提示信息而非录音状态
4. WHEN 用户从未登录变为已登录，THEN THE AppDelegate SHALL 将 `isVoiceInputEnabled` 设为 true
5. WHEN 用户从已登录变为未登录（401 或主动登出），THEN THE AppDelegate SHALL 将 `isVoiceInputEnabled` 设为 false

### 需求 7：额度计量迁移

**用户故事：** 作为用户，我希望额度按账号计算而非按设备计算，以便在多设备间共享额度。

#### 验收标准

1. THE QuotaManager SHALL 通过 `GET /api/v1/user/profile` 接口获取基于 user_id 的额度数据
2. WHEN 用户登录成功，THEN THE QuotaManager SHALL 刷新额度数据
3. WHEN 用户未登录，THEN THE QuotaManager SHALL 不发起额度查询请求
