# ASR 凭证云端化改造

## 背景

把豆包 ASR 的 `APP_ID` 和 `ACCESS_TOKEN` 从端上硬编码迁移到服务端下发，端上启动时从服务端拉取凭证，然后照常直连豆包 WebSocket。

## 服务端接口（已上线）

```
GET https://ghostype.com/api/v1/asr/credentials
```

请求 Header：
```
X-Device-Id: {UUID v4}   ← 必填，从 UserDefaults 读取
```

响应 200：
```json
{
  "app_id": "8920082845",
  "access_token": "QZvY722AgA_PwMmQbWjj6O3q85-G4Rj-"
}
```

响应 401（无 Device-Id）：
```json
{
  "error": { "code": "UNAUTHORIZED", "message": "Missing or invalid X-Device-Id" }
}
```

## 要改的文件

`Sources/Features/Speech/DoubaoSpeechService.swift`

## 改动内容

### 1. 删掉环境变量读取

删掉这段：
```swift
private var appId: String {
    if let ptr = getenv("DOUBAO_ASR_APP_ID") { return String(cString: ptr) }
    return ""
}
private var accessToken: String {
    if let ptr = getenv("DOUBAO_ASR_ACCESS_TOKEN") { return String(cString: ptr) }
    return ""
}
```

替换为从内存缓存读取：
```swift
private var appId: String = ""
private var accessToken: String = ""
```

### 2. 添加凭证拉取方法

```swift
func fetchCredentials() async throws {
    let baseURL = "https://ghostype.com"  // 或从配置读取
    let deviceId = UserDefaults.standard.string(forKey: "device_id") ?? ""
    
    var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/asr/credentials")!)
    request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = response as! HTTPURLResponse
    
    guard httpResponse.statusCode == 200 else {
        throw NSError(domain: "ASR", code: httpResponse.statusCode, 
                      userInfo: [NSLocalizedDescriptionKey: "Failed to fetch ASR credentials"])
    }
    
    struct Credentials: Codable {
        let app_id: String
        let access_token: String
    }
    
    let creds = try JSONDecoder().decode(Credentials.self, from: data)
    self.appId = creds.app_id
    self.accessToken = creds.access_token
}
```

### 3. 修改 hasCredentials()

不变，已经能用：
```swift
func hasCredentials() -> Bool {
    return !appId.isEmpty && !accessToken.isEmpty
}
```

### 4. 调用时机

在 App 启动时（AppDelegate 或 init 阶段）调一次：
```swift
Task {
    do {
        try await speechService.fetchCredentials()
    } catch {
        print("Failed to fetch ASR credentials: \(error)")
        // 降级：用户无法使用语音识别，UI 上提示网络问题
    }
}
```

### 5. 删掉 .env 中的 ASR 相关变量

`.env` 文件中删掉：
```
DOUBAO_ASR_APP_ID=...
DOUBAO_ASR_ACCESS_TOKEN=...
DOUBAO_ASR_SECRET_KEY=...
```

以及 AppDelegate 中 `setenv()` 设置这些变量的代码。

## 不要动的东西

- WebSocket 连接逻辑不变
- 音频采集逻辑不变
- 二进制协议构建不变
- gzip 压缩/解压不变
- 只改凭证来源，其他一概不动

## 测试

1. 删掉 .env 中的 ASR 凭证
2. 启动 app
3. 确认 `fetchCredentials()` 成功拉到凭证
4. 录音 → 语音识别正常工作
5. 断网情况下启动 → 应该提示网络问题，不 crash
