# Implementation Plan: 强制登录与鉴权迁移

## Overview

将 GHOSTYPE macOS 客户端从「JWT 可选 + Device-Id 回退」迁移到「JWT 必填 + 强制登录」模式。按依赖顺序改动：本地化字符串 → API 客户端 → AuthManager → AppDelegate 状态守卫 → Overlay → Dashboard UI。

## Tasks

- [x] 1. 添加本地化字符串
  - [x] 1.1 在 Strings.swift 中为 `L.Auth` 添加新的 key：`sessionExpiredTitle`、`sessionExpiredDesc`、`reLogin`、`later`、`loginRequired`
    - 在 `AuthStrings` protocol 中添加对应属性
    - _Requirements: 4.3, 4.4, 3.3_
  - [x] 1.2 在 Strings+Chinese.swift 中添加中文翻译
    - `sessionExpiredTitle` → "登录已过期"
    - `sessionExpiredDesc` → "请重新登录后继续使用"
    - `reLogin` → "重新登录"
    - `later` → "稍后"
    - `loginRequired` → "请先登录"
    - _Requirements: 4.3, 4.4, 3.3_
  - [x] 1.3 在 Strings+English.swift 中添加英文翻译
    - `sessionExpiredTitle` → "Session Expired"
    - `sessionExpiredDesc` → "Please sign in again to continue"
    - `reLogin` → "Sign In Again"
    - `later` → "Later"
    - `loginRequired` → "Please Sign In"
    - _Requirements: 4.3, 4.4, 3.3_

- [x] 2. 修改 GhostypeAPIClient：JWT 必填 + URL 更新
  - [x] 2.1 更新 `GhostypeAPIClient.baseURL` 生产环境值
    - 将 `#else return "https://ghostype.com"` 改为 `#else return "https://www.ghostype.one"`
    - _Requirements: 1.1, 1.3_
  - [x] 2.2 修改 `buildRequest()` 为 throwing 方法
    - 签名改为 `func buildRequest(url: URL, method: String, timeout: TimeInterval) throws -> URLRequest`
    - 无 JWT 时 `throw GhostypeError.unauthorized(L.Auth.loginRequired)`
    - 有 JWT 时必须添加 `Authorization: Bearer {jwt}` Header
    - 保留 `X-Device-Id` 和 `Content-Type` Header
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - [x] 2.3 更新所有 `buildRequest()` 调用方添加 `try`
    - `polish()` 方法中的调用
    - `translate()` 方法中的调用
    - `fetchProfile()` 方法中的调用
    - _Requirements: 2.1_
  - [ ]* 2.4 为 buildRequest 编写属性测试
    - **Property 1: 已认证请求的 Header 完整性**
    - **Property 2: 无 JWT 时请求拦截**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**

- [x] 3. 修改 AuthManager：401 弹窗 + 登出通知
  - [x] 3.1 修改 `handleUnauthorized()` 方法
    - 清除 JWT 后发送 `userDidLogout` 通知
    - 在主线程弹出 NSAlert，标题用 `L.Auth.sessionExpiredTitle`，内容用 `L.Auth.sessionExpiredDesc`
    - 按钮文案用 `L.Auth.reLogin` 和 `L.Auth.later`
    - 点击「重新登录」调用 `openLogin()`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  - [ ]* 3.2 为 AuthManager 状态管理编写属性测试
    - **Property 3: Auth URL 回调 Token 提取**
    - **Property 4: 401/登出状态清理**
    - **Validates: Requirements 4.1, 4.2, 5.3, 7.1**

- [x] 4. Checkpoint - 确保编译通过
  - 确保所有修改编译通过，ask the user if questions arise.

- [x] 5. 修改 AppDelegate：登录状态守卫
  - [x] 5.1 在 AppDelegate 中添加 `isVoiceInputEnabled` 属性
    - 添加 `@Published var isVoiceInputEnabled: Bool = false`
    - 在 `applicationDidFinishLaunching` 中根据 `AuthManager.shared.isLoggedIn` 初始化
    - _Requirements: 6.1, 3.1, 3.2_
  - [x] 5.2 在 `startApp()` 中订阅登录/登出通知
    - 订阅 `userDidLogin`：设置 `isVoiceInputEnabled = true`，重新获取 ASR 凭证，刷新 QuotaManager
    - 订阅 `userDidLogout`：设置 `isVoiceInputEnabled = false`
    - _Requirements: 3.4, 3.5, 6.4, 6.5, 4.7, 8.2_
  - [x] 5.3 在 `setupHotkey()` 的 `onHotkeyDown` 回调中添加守卫
    - 检查 `isVoiceInputEnabled`，为 false 时显示 Overlay 登录提示并 return
    - _Requirements: 3.3, 6.2_

- [x] 6. 修改 Overlay：添加 loginRequired 状态
  - [x] 6.1 在 `OverlayPhase` 枚举中添加 `.loginRequired` case
    - 在 `OverlayStateManager` 中添加 `setLoginRequired()` 方法
    - _Requirements: 6.3_
  - [x] 6.2 在 OverlayView 中渲染 `.loginRequired` 状态
    - 显示 `L.Auth.loginRequired` 文案
    - 使用与其他状态一致的视觉风格
    - _Requirements: 6.3, 3.3_

- [x] 7. 修改 Dashboard：未登录状态 UI 置灰
  - [x] 7.1 在 NavItem 中添加 `requiresAuth` 计算属性
    - `account` 和 `preferences` 返回 false，其余返回 true
    - _Requirements: 7.3_
  - [x] 7.2 修改 SidebarView 按项控制 isEnabled
    - 观察 `AuthManager.shared.isLoggedIn`
    - 每个 SidebarNavItem 的 isEnabled 改为 `!item.requiresAuth || authManager.isLoggedIn`
    - 未登录时自动切换 selectedItem 到 `.account`
    - _Requirements: 7.3, 7.4, 7.5_
  - [x] 7.3 修改 DashboardView 传递按项 isEnabled 逻辑
    - 将 SidebarView 的全局 isEnabled 改为按项判断
    - 未登录时 content area 对需要登录的页面显示登录提示
    - _Requirements: 7.3, 7.6, 7.7_
  - [ ]* 7.4 为 NavItem.requiresAuth 编写属性测试
    - **Property 5: 导航项鉴权门控**
    - **Validates: Requirements 7.3**

- [x] 8. 更新 Onboarding 登录步骤
  - [x] 8.1 移除 Step0AuthView 中的「跳过」按钮
    - 未登录时不允许跳过登录步骤，必须登录后才能继续
    - 已登录时显示「下一步」按钮
    - _Requirements: 3.3_

- [x] 9. 更新 AccountPage 中的 deviceIdHint 文案
  - [x] 9.1 移除或更新 `L.Account.deviceIdHint` 文案
    - 旧文案暗示未登录也能使用，需要更新为说明登录是必须的
    - 更新中英文翻译
    - _Requirements: 7.5_

- [x] 10. Final checkpoint - 确保所有修改编译通过
  - 确保所有测试通过，ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- 改动范围刻意最小化：不改 API 路径、不改请求/响应体、不改 Device-Id 生成逻辑
- 所有 UI 文案必须使用 `L.xxx` 本地化模式，禁止硬编码
- 构建验证流程：`swift build -c release` → `bash bundle_app.sh` → `open GhosTYPE.app`
