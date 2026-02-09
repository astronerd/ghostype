# GHOSTYPE API 客户端接入文档

> macOS 桌面客户端接入 GHOSTYPE 服务端 API 的完整技术规范。

## Base URL

| 环境 | URL |
|------|-----|
| 生产 | `https://ghostype.com` |
| 开发 | `http://localhost:3000` |

---

## 1. 鉴权

每个请求必须携带以下 Header：

| Header | 必填 | 说明 |
|--------|------|------|
| `Content-Type` | ✅ | `application/json` |
| `X-Device-Id` | ✅ | UUID v4，首次启动生成，存 UserDefaults |
| `Authorization` | 登录后必填 | `Bearer {clerk_jwt_token}` |

```
Content-Type: application/json
X-Device-Id: 550e8400-e29b-41d4-a716-446655440000
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```

**鉴权优先级**：
- 有 JWT → 验证 JWT → 关联 user_id → 查订阅状态 → Pro 无限 / Free 限额
- 无 JWT → 仅用 Device-Id → Free 限额（6000 字符/周）
- JWT 过期/无效 → 回退到 Device-Id 模式

---

## 2. Clerk SDK 接入（端上实现）

### 2.1 整体流程

```
用户点击「登录」
    ↓
打开系统浏览器 → Clerk 登录页
    ↓
登录成功 → 重定向 ghostype://auth?token={jwt}
    ↓
客户端接收 JWT → 存入 Keychain
    ↓
后续所有请求携带 Authorization: Bearer {jwt}
```

### 2.2 注册 URL Scheme

Info.plist：

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>ghostype</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.ghostype.app</string>
  </dict>
</array>
```

### 2.3 触发登录

```swift
func openClerkLogin() {
    let loginURL = "https://ghostype.com/sign-in?redirect_url=ghostype://auth"
    NSWorkspace.shared.open(URL(string: loginURL)!)
}
```

### 2.4 接收回调

```swift
// SwiftUI: .onOpenURL { url in handleAuthURL(url) }
// AppDelegate: func application(_ application: NSApplication, open urls: [URL])

func handleAuthURL(_ url: URL) {
    guard url.scheme == "ghostype",
          url.host == "auth",
          let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
              .queryItems?.first(where: { $0.name == "token" })?.value
    else { return }
    
    KeychainHelper.save(key: "clerk_jwt", value: token)
    NotificationCenter.default.post(name: .userDidLogin, object: nil)
}
```

### 2.5 JWT 存储（Keychain）

```swift
struct KeychainHelper {
    private static let service = "com.ghostype.app"
    
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### 2.6 Token 过期处理

```swift
// 请求后检查响应
if httpResponse.statusCode == 401 {
    if KeychainHelper.get(key: "clerk_jwt") != nil {
        // JWT 过期，清除并回退到 Device-Id 模式
        KeychainHelper.delete(key: "clerk_jwt")
        // 提示用户：登录已过期，请重新登录
        // 当前请求会以 Free 额度继续工作（因为还有 X-Device-Id）
    }
}
```

### 2.7 Clerk Dashboard 配置

- 在 Clerk Dashboard → Paths → Redirect URLs 中添加 `ghostype://auth`
- JWT 模板需包含 `sub`（user_id）字段
- 建议开启 Long-lived sessions 减少重复登录

---

## 3. 接口：GET /api/v1/user/profile

获取当前用户的订阅状态和用量数据。macOS 客户端用此接口展示账户信息、剩余额度等。

### 3.1 请求

```
GET /api/v1/user/profile
```

| Header | 必填 | 说明 |
|--------|------|------|
| `X-Device-Id` | ✅ | UUID v4 |
| `Authorization` | 否 | `Bearer {clerk_jwt_token}`，有则返回订阅信息 |

无请求体。

### 3.2 响应 (200)

```json
{
  "subscription": {
    "plan": "pro",
    "status": "active",
    "is_lifetime_vip": false,
    "current_period_end": "2026-03-09T00:00:00Z"
  },
  "usage": {
    "used": 1234,
    "limit": 6000,
    "reset_at": "2026-02-16T00:00:00.000Z"
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `subscription.plan` | `"free" \| "pro"` | 当前计划 |
| `subscription.status` | string \| null | 订阅状态（active/canceled/...），未登录为 null |
| `subscription.is_lifetime_vip` | boolean | 是否挚友终身 VIP |
| `subscription.current_period_end` | string \| null | 当前订阅周期结束时间 |
| `usage.used` | number | 本周已用字符数 |
| `usage.limit` | number | 本周字符上限（Pro 用户返回 -1 表示无限） |
| `usage.reset_at` | string | 下次重置时间（下周一 00:00 UTC） |

**逻辑说明**：
- 无 JWT → `subscription.plan = "free"`，usage 按 device_id 查
- 有效 JWT + Pro → `subscription.plan = "pro"`，`usage.limit = -1`
- 有效 JWT + Free → `subscription.plan = "free"`，usage 按 device_id 查
- 无效/过期 JWT → 忽略 JWT，回退到 device_id 模式

### 3.3 curl 示例

```bash
# 未登录
curl -s http://localhost:3000/api/v1/user/profile \
  -H "X-Device-Id: 550e8400-e29b-41d4-a716-446655440000"

# 已登录
curl -s http://localhost:3000/api/v1/user/profile \
  -H "X-Device-Id: 550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer eyJhbGci..."
```

### 3.4 端上调用参考 (Swift)

```swift
struct ProfileResponse: Codable {
    let subscription: SubscriptionInfo
    let usage: UsageInfo
    
    struct SubscriptionInfo: Codable {
        let plan: String
        let status: String?
        let is_lifetime_vip: Bool
        let current_period_end: String?
    }
    
    struct UsageInfo: Codable {
        let used: Int
        let limit: Int
        let reset_at: String
    }
}

extension GhostypeAPI {
    func fetchProfile() async throws -> ProfileResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/user/profile")!)
        request.httpMethod = "GET"
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        
        if let token = KeychainHelper.get(key: "clerk_jwt") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            let err = try JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            throw GhostypeError.serverError(code: err.error.code, message: err.error.message)
        }
        
        return try JSONDecoder().decode(ProfileResponse.self, from: data)
    }
}
```

---

## 4. 接口：POST /api/v1/llm/chat

### 4.1 润色模式 (Polish)

#### 请求体

```json
{
  "mode": "polish",
  "message": "用户语音转写文本",
  "profile": "standard",
  "custom_prompt": null,
  "enable_in_sentence": true,
  "enable_trigger": true,
  "trigger_word": "ghost"
}
```

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `mode` | string | ✅ | — | 固定 `"polish"` |
| `message` | string | ✅ | — | 语音转写文本，≤ 10000 字符 |
| `profile` | string | 否 | `"standard"` | 润色风格，见下表 |
| `custom_prompt` | string | 否 | `null` | 仅 `profile="custom"` 时生效，与预设 tone 互斥 |
| `enable_in_sentence` | boolean | 否 | `false` | 启用句内指令识别（Block 2） |
| `enable_trigger` | boolean | 否 | `false` | 启用唤醒词协议（Block 3） |
| `trigger_word` | string | 否 | `"ghost"` | 唤醒词，`enable_trigger=true` 时必填 |

#### Profile 枚举

| 值 | 说明 | 端上 UI |
|----|------|---------|
| `standard` | 自然清晰 | 「自然」 |
| `professional` | 正式商务 | 「专业」 |
| `casual` | 轻松社交，允许 emoji | 「社交」 |
| `concise` | 结构化列表 | 「逻辑」 |
| `creative` | 文学修辞 | 「文艺」 |
| `custom` | 用户自定义语气 | 「自定义」→ 弹出文本框 |

**custom_prompt 说明**：
- `profile = "custom"` 时，`custom_prompt` 完全替代预设 tone，两者互斥
- `custom_prompt` 存端上 UserDefaults（隐私数据），每次请求带过来
- 服务端用完即弃，不落库
- 示例：`"用东北话风格，带点幽默感"` / `"像村上春树一样写"`

#### curl 示例

```bash
# 标准润色
curl -X POST http://localhost:3000/api/v1/llm/chat \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: 550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer eyJhbGci..." \
  -d '{
    "mode": "polish",
    "message": "嗯那个我觉得这个项目还是挺好的就是有一些地方需要改一下",
    "profile": "professional",
    "enable_in_sentence": true
  }'

# 自定义语气
curl -X POST http://localhost:3000/api/v1/llm/chat \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: 550e8400-e29b-41d4-a716-446655440000" \
  -d '{
    "mode": "polish",
    "message": "今天去公园玩了感觉很开心",
    "profile": "custom",
    "custom_prompt": "用东北话风格，带点幽默感"
  }'

# 带唤醒词
curl -X POST http://localhost:3000/api/v1/llm/chat \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: 550e8400-e29b-41d4-a716-446655440000" \
  -d '{
    "mode": "polish",
    "message": "苹果香蕉橙子 ghost 转成列表",
    "profile": "standard",
    "enable_trigger": true,
    "trigger_word": "ghost"
  }'
```

### 4.2 翻译模式 (Translate)

#### 请求体

```json
{
  "mode": "translate",
  "message": "用户语音转写文本",
  "translate_language": "chineseEnglish"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `mode` | string | ✅ | 固定 `"translate"` |
| `message` | string | ✅ | ≤ 10000 字符 |
| `translate_language` | string | ✅ | 见下表 |

| translate_language | 说明 |
|--------------------|------|
| `chineseEnglish` | 中英互译 |
| `chineseJapanese` | 中日互译 |
| `auto` | 自动检测源语言 |

---

## 5. 响应格式

### 成功 (200)

```json
{
  "text": "处理后的文本",
  "usage": {
    "input_tokens": 1118,
    "output_tokens": 8
  }
}
```

### 错误

```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Weekly quota exceeded (6000/6000)"
  }
}
```

| HTTP | code | 说明 | 端上处理 |
|------|------|------|----------|
| 400 | `INVALID_REQUEST` | 参数错误 | 检查请求体 |
| 401 | `UNAUTHORIZED` | Device-Id 缺失 / JWT 无效 | 清除 JWT，提示重新登录 |
| 429 | `QUOTA_EXCEEDED` | 额度用完 | 提示升级 Pro |
| 500 | `INTERNAL_ERROR` | 服务端异常 | 重试 1 次 |
| 502 | `UPSTREAM_ERROR` | Gemini API 错误 | 重试 1 次 |
| 504 | `UPSTREAM_TIMEOUT` | Gemini 超时 (30s) | 提示网络问题 |

---

## 6. 用量限制

| 用户类型 | 字符额度 | 周期 |
|----------|----------|------|
| Free | 6000 字符/周 | 每周一 00:00 UTC 重置 |
| Pro（已订阅） | 无限制 | — |

- 按 `message` 字段字符长度计算
- 未登录用户按 Device-Id 计额度
- 已登录用户按 user_id 计额度

---

## 7. 端上数据存储

| 数据 | 存储位置 | 说明 |
|------|----------|------|
| Device ID (UUID) | UserDefaults | 首次启动生成，永久保留 |
| Clerk JWT Token | **Keychain** | 安全存储，不要用 UserDefaults |
| 当前 Profile | UserDefaults | standard/professional/... |
| custom_prompt | UserDefaults | 用户自定义语气（隐私数据，不上传存储） |
| enable_in_sentence | UserDefaults | Block 2 开关 |
| enable_trigger | UserDefaults | Block 3 开关 |
| trigger_word | UserDefaults | 唤醒词 |
| translate_language | UserDefaults | 翻译语言偏好 |

---

## 8. 端上请求组装参考 (Swift)

```swift
struct GhostypeRequest: Codable {
    let mode: String
    let message: String
    var profile: String?
    var custom_prompt: String?
    var enable_in_sentence: Bool?
    var enable_trigger: Bool?
    var trigger_word: String?
    var translate_language: String?
}

struct GhostypeResponse: Codable {
    let text: String
    let usage: Usage
    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

struct GhostypeErrorResponse: Codable {
    let error: ErrorDetail
    struct ErrorDetail: Codable {
        let code: String
        let message: String
    }
}

class GhostypeAPI {
    static let shared = GhostypeAPI()
    
    private let baseURL = "https://ghostype.com"
    private let deviceId: String = {
        if let id = UserDefaults.standard.string(forKey: "device_id") {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "device_id")
        return id
    }()
    
    func polish(
        text: String,
        profile: String = "standard",
        customPrompt: String? = nil,
        enableInSentence: Bool = false,
        enableTrigger: Bool = false,
        triggerWord: String = "ghost"
    ) async throws -> String {
        let body = GhostypeRequest(
            mode: "polish",
            message: text,
            profile: profile,
            custom_prompt: profile == "custom" ? customPrompt : nil,
            enable_in_sentence: enableInSentence,
            enable_trigger: enableTrigger,
            trigger_word: enableTrigger ? triggerWord : nil
        )
        return try await call(body: body)
    }
    
    func translate(
        text: String,
        language: String = "chineseEnglish"
    ) async throws -> String {
        let body = GhostypeRequest(
            mode: "translate",
            message: text,
            translate_language: language
        )
        return try await call(body: body)
    }
    
    private func call(body: GhostypeRequest) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/llm/chat")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        
        // Clerk JWT
        if let token = KeychainHelper.get(key: "clerk_jwt") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(GhostypeResponse.self, from: data).text
        case 401:
            // JWT 过期，清除并回退
            if KeychainHelper.get(key: "clerk_jwt") != nil {
                KeychainHelper.delete(key: "clerk_jwt")
            }
            let err = try JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            throw GhostypeError.unauthorized(err.error.message)
        case 429:
            let err = try JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            throw GhostypeError.quotaExceeded(err.error.message)
        default:
            let err = try JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            throw GhostypeError.serverError(code: err.error.code, message: err.error.message)
        }
    }
}

enum GhostypeError: Error {
    case unauthorized(String)
    case quotaExceeded(String)
    case serverError(code: String, message: String)
}
```

---

## 9. 服务端鉴权行为

| 请求状态 | 服务端行为 |
|----------|-----------|
| 有效 JWT + Pro 订阅 | 跳过额度检查，无限使用 |
| 有效 JWT + Free | 6000 字符/周（按 user_id 计） |
| 无效/过期 JWT | 忽略 JWT，回退到 Device-Id 模式 |
| 无 JWT | Device-Id 模式，6000 字符/周（按 device_id 计） |

---

## 10. 架构备注：Prompt Caching

服务端已针对 Gemini 2.5 Flash implicit caching 优化：

```
system message (🔒 缓存，~1100 tokens，前缀稳定)
  ├── Role Definition
  ├── Block 1: Core Rules
  ├── Block 2: Inline Instructions (可选)
  └── Block 3: Trigger Protocol (可选)

user message (🔓 动态，每次不同)
  ├── Session Configuration: Tone (profile 或 custom_prompt)
  └── User Input (message)
```

- Gemini 自动缓存命中，input token 成本降低 75%
- 最低门槛 1024 tokens，当前 ~1100 tokens ✅
- **客户端无需关心 caching，这是服务端的事**
