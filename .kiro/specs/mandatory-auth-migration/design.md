# 设计文档：强制登录与鉴权迁移

## 概述

本设计将 GHOSTYPE macOS 客户端从「JWT 可选 + Device-Id 回退」模式迁移到「JWT 必填 + 强制登录」模式。改动集中在 4 个核心模块：GhostypeAPIClient（请求拦截）、AuthManager（401 弹窗）、AppDelegate（登录状态守卫）、Dashboard（未登录 UI 置灰）。

改动范围刻意最小化——不改 API 路径、不改请求/响应体结构、不改 Device-Id 生成逻辑，只改鉴权流程和 UI 状态联动。

## 架构

```mermaid
graph TD
    subgraph "App 启动"
        A[AppDelegate.applicationDidFinishLaunching] --> B{Keychain 有 JWT?}
        B -->|有| C[isVoiceInputEnabled = true]
        B -->|无| D[isVoiceInputEnabled = false]
    end

    subgraph "快捷键触发"
        E[HotkeyManager.onHotkeyDown] --> F{isVoiceInputEnabled?}
        F -->|true| G[正常录音流程]
        F -->|false| H[Overlay 显示「请先登录」]
    end

    subgraph "API 请求"
        I[GhostypeAPIClient.buildRequest] --> J{getToken() != nil?}
        J -->|有 JWT| K[添加 Authorization Header → 发送请求]
        J -->|无 JWT| L[抛出 .unauthorized 错误]
        K --> M{响应状态码}
        M -->|200| N[正常返回]
        M -->|401| O[AuthManager.handleUnauthorized → 弹窗]
    end

    subgraph "登录状态变更"
        P[userDidLogin 通知] --> Q[isVoiceInputEnabled = true]
        Q --> R[刷新 ASR 凭证 + 额度]
        S[userDidLogout 通知] --> T[isVoiceInputEnabled = false]
        T --> U[Dashboard 页面置灰]
    end
```

## 组件与接口

### 1. GhostypeAPIClient 改动

当前 `buildRequest()` 在有 JWT 时添加 Authorization Header，无 JWT 时静默跳过。改造后：

```swift
// 改造前
func buildRequest(url: URL, method: String, timeout: TimeInterval) -> URLRequest {
    // ... 有 JWT 时添加 Header，无 JWT 时跳过
}

// 改造后
func buildRequest(url: URL, method: String, timeout: TimeInterval) throws -> URLRequest {
    guard let token = AuthManager.shared.getToken() else {
        throw GhostypeError.unauthorized("未登录，请先登录后再使用")
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(DeviceIdManager.shared.deviceId, forHTTPHeaderField: "X-Device-Id")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
}
```

`baseURL` 生产环境从 `https://ghostype.com` 改为 `https://www.ghostype.one`。

所有调用 `buildRequest()` 的地方（`polish()`、`translate()`、`fetchProfile()`）需要加 `try`。

### 2. AuthManager 改动

#### 2.1 handleUnauthorized() 增加弹窗

当前 `handleUnauthorized()` 只清除 JWT 和重置状态。改造后增加 NSAlert 弹窗：

```swift
func handleUnauthorized() {
    KeychainHelper.delete(key: Keys.jwtToken)
    isLoggedIn = false
    userId = nil
    userEmail = nil

    // 发送登出通知（触发 AppDelegate 禁用语音输入）
    NotificationCenter.default.post(name: .userDidLogout, object: nil)

    // 弹窗提示
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = L.Auth.sessionExpiredTitle   // "登录已过期"
        alert.informativeText = L.Auth.sessionExpiredDesc // "请重新登录后继续使用"
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.Auth.reLogin)        // "重新登录"
        alert.addButton(withTitle: L.Auth.later)          // "稍后"

        if alert.runModal() == .alertFirstButtonReturn {
            self.openLogin()
        }
    }
}
```

#### 2.2 logout() 增加通知

当前 `logout()` 已发送 `userDidLogout` 通知，无需额外改动。

### 3. AppDelegate 改动

#### 3.1 新增 isVoiceInputEnabled 状态

```swift
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isVoiceInputEnabled: Bool = false
    // ...
}
```

#### 3.2 启动时检查登录状态

在 `applicationDidFinishLaunching` 中，根据 `AuthManager.shared.isLoggedIn` 设置初始状态：

```swift
isVoiceInputEnabled = AuthManager.shared.isLoggedIn
```

#### 3.3 监听登录/登出通知

在 `startApp()` 中订阅通知：

```swift
NotificationCenter.default.publisher(for: .userDidLogin)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] _ in
        self?.isVoiceInputEnabled = true
        // 重新获取 ASR 凭证
        Task { try? await self?.speechService.fetchCredentials() }
        // 刷新额度
        Task { await QuotaManager.shared.refresh() }
    }
    .store(in: &cancellables)

NotificationCenter.default.publisher(for: .userDidLogout)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] _ in
        self?.isVoiceInputEnabled = false
    }
    .store(in: &cancellables)
```

#### 3.4 快捷键回调守卫

在 `hotkeyManager.onHotkeyDown` 回调开头加守卫：

```swift
hotkeyManager.onHotkeyDown = { [weak self] in
    guard let self = self else { return }
    guard self.isVoiceInputEnabled else {
        // 显示登录提示
        self.showOverlayNearCursor()
        OverlayStateManager.shared.setLoginRequired()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideOverlay()
        }
        return
    }
    // ... 原有录音逻辑
}
```

### 4. OverlayStateManager 改动

新增 `loginRequired` phase：

```swift
enum OverlayPhase: Equatable {
    case recording(InputMode)
    case processing(InputMode)
    case result(ResultInfo)
    case committing(CommitType)
    case loginRequired  // 新增
    // ...
}

// OverlayStateManager 新增方法
func setLoginRequired() {
    DispatchQueue.main.async { self.phase = .loginRequired }
}
```

OverlayView 中对 `.loginRequired` 渲染「请先登录」提示文案。

### 5. Dashboard 未登录状态

#### 5.1 NavItem 增加登录要求判断

```swift
extension NavItem {
    /// 该页面是否需要登录才能访问
    var requiresAuth: Bool {
        switch self {
        case .account, .preferences: return false
        case .overview, .memo, .library, .aiPolish: return true
        }
    }
}
```

#### 5.2 DashboardView 根据登录状态控制导航

DashboardView 观察 `AuthManager.shared.isLoggedIn`，将 `isEnabled` 传递给 SidebarView：

```swift
// SidebarView 的 isEnabled 改为根据登录状态 + 每个 NavItem 的 requiresAuth 判断
// 未登录时，requiresAuth == true 的项置灰不可点击
// 未登录时，自动切换到 AccountPage
```

#### 5.3 SidebarNavItem 按项禁用

当前 SidebarView 的 `isEnabled` 是全局的。改造后需要按项判断：

```swift
SidebarNavItem(
    item: item,
    isSelected: selectedItem == item,
    isEnabled: !item.requiresAuth || authManager.isLoggedIn
)
```

## 数据模型

无新增数据模型。现有模型不变：
- `GhostypeRequest` / `GhostypeResponse` — 不变
- `ProfileResponse` — 不变
- `GhostypeError` — 不变（已有 `.unauthorized` case）
- Keychain 存储 key `clerk_jwt` — 不变

## 正确性属性

*正确性属性是一种在系统所有有效执行中都应成立的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### Property 1: 已认证请求的 Header 完整性

*For any* 有效的 JWT token 和任意请求参数（URL、method、timeout），`buildRequest()` 生成的 URLRequest 必须同时包含：`Authorization: Bearer {jwt}`、`X-Device-Id: {uuid}`、`Content-Type: application/json` 三个 Header。

**Validates: Requirements 2.2, 2.3, 2.4**

### Property 2: 无 JWT 时请求拦截

*For any* 请求参数（URL、method、timeout），当 Keychain 中无 JWT 时，`buildRequest()` 必须抛出 `.unauthorized` 错误，不得生成 URLRequest。

**Validates: Requirements 2.1**

### Property 3: Auth URL 回调 Token 提取

*For any* 非空 JWT 字符串 token，调用 `handleAuthURL(URL(string: "ghostype://auth?token=\(token)")!)` 后，`getToken()` 返回的值必须等于原始 token，且 `isLoggedIn` 为 true。

**Validates: Requirements 5.3**

### Property 4: 401/登出状态清理

*For any* 已登录状态（Keychain 中有 JWT、isLoggedIn == true），调用 `handleUnauthorized()` 或 `logout()` 后，`getToken()` 必须返回 nil，且 `isLoggedIn` 必须为 false。

**Validates: Requirements 4.1, 4.2, 7.1**

### Property 5: 导航项鉴权门控

*For any* NavItem，当 `requiresAuth` 为 true 且用户未登录时，该导航项必须处于禁用状态；当 `requiresAuth` 为 false 时，无论登录状态如何，该导航项必须处于启用状态。AccountPage 和 PreferencesPage 的 `requiresAuth` 必须为 false。

**Validates: Requirements 7.3**

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| 无 JWT 时调用 API | `buildRequest()` 抛出 `.unauthorized`，调用方 catch 后不发送请求 |
| 401 响应 | 清除 JWT → 发送 `userDidLogout` 通知 → 弹窗提示重新登录 → 禁用语音输入 |
| 429 响应（额度超限） | 保持现有逻辑，抛出 `.quotaExceeded` |
| 500/502 响应 | 保持现有逻辑，自动重试一次 |
| 网络错误 | 保持现有逻辑，抛出 `.networkError` |
| ASR 凭证获取失败 | 保持现有逻辑，不崩溃，用户触发录音时提示 |
| handleAuthURL 收到无效 URL | 忽略，打印日志，不改变状态 |

## 测试策略

### 属性测试（Property-Based Testing）

使用 Swift 的 `swift-testing` 框架配合手动随机生成器进行属性测试。每个属性测试至少运行 100 次迭代。

每个测试用注释标注对应的设计属性：
```swift
// Feature: mandatory-auth-migration, Property 1: 已认证请求的 Header 完整性
```

### 单元测试

针对以下场景编写具体的单元测试：
- URL 配置正确性（需求 1.1-1.4）
- 启动时登录状态检查（需求 3.1, 3.2）
- 登录/登出通知触发状态变更（需求 3.4, 6.4, 6.5）
- 快捷键守卫逻辑（需求 3.3, 6.2）
- NavItem.requiresAuth 返回值（需求 7.3）
- QuotaManager 登录后刷新（需求 8.2）

### 测试方法

由于这是 macOS 桌面应用，部分测试（NSAlert 弹窗、Overlay 显示、浏览器跳转）无法自动化，需要手动验证。可自动化的核心逻辑集中在：
- `GhostypeAPIClient.buildRequest()` 的 Header 组装
- `AuthManager` 的状态管理（login/logout/handleUnauthorized）
- `NavItem.requiresAuth` 的返回值
- 登录/登出通知的状态联动
