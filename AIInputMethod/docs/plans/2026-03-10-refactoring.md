# GHOSTYPE 全量重构计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 消除 God Class、双向绑定、状态混乱、单例滥用、魔法数字等架构问题，在不改变任何对外行为的前提下提升代码可维护性。

**Architecture:** 分 4 个 Phase 小步执行，每 Phase 独立可回滚。Phase 1 零风险（纯 bug fix）→ Phase 2 低风险（Extract Method/Class）→ Phase 3 中风险（状态机重构）→ Phase 4 高风险（AppDelegate 拆解）。

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, CoreData, Combine, CGEvent tap, AVFoundation

**重构原则（每步必须遵守）：**
- 每改一个文件：`swift build` 验证编译通过
- 每完成一个 Task：`swift test` 验证测试通过
- 每完成一个 Phase：手动测试完整语音输入流程
- 不改变对外 API 接口（方法签名、通知名称、UserDefaults key）

---

## 项目结构速查

```
Sources/
├── AIInputMethodApp.swift          ← AppDelegate (316行, God Class)
├── Features/
│   ├── AI/
│   │   ├── GhostypeAPIClient.swift (287行)
│   │   └── Skill/
│   │       ├── SkillExecutor.swift  (310行)
│   │       ├── SkillManager.swift   (250行)
│   │       ├── SkillModel.swift
│   │       ├── TemplateEngine.swift
│   │       └── ToolRegistry.swift   (74行)
│   ├── Accessibility/
│   │   ├── ContextDetector.swift   (168行)
│   │   └── FocusObserver.swift     (118行)
│   ├── Auth/AuthManager.swift      (163行)
│   ├── Dashboard/
│   │   ├── PersistenceController.swift
│   │   ├── QuotaManager.swift
│   │   └── DashboardWindowController.swift
│   ├── HID/HIDMappingManager.swift (250行)
│   ├── Hotkey/HotkeyManager.swift  (400行)
│   ├── MenuBar/MenuBarManager.swift(151行)
│   ├── Permissions/PermissionManager.swift (99行)
│   ├── Settings/
│   │   ├── AppConfig.swift         (32行)
│   │   ├── AppSettings.swift       (497行)
│   │   └── Strings.swift
│   └── VoiceInput/
│       ├── OverlayWindowManager.swift (92行)
│       ├── TextInsertionService.swift (243行)
│       └── VoiceInputCoordinator.swift(498行)
└── Speech/DoubaoSpeechService.swift   (730行)
```

## 核心链路

```
用户按快捷键
  → HotkeyManager (CGEvent tap)
    → VoiceInputCoordinator.handlePushToTalkHotkeyDown()
      → [后台] ContextDetector.detectWithDebugInfo() → savedContext
      → DoubaoSpeechService.startRecording()
        → AVAudioEngine tap → audioBuffer → WebSocket → Doubao ASR
      → [ASR onFinalResult] VoiceInputCoordinator.processWithSkill()
        → SkillExecutor.execute()
          → TemplateEngine.resolve()
          → GhostypeAPIClient.executeSkill()
          → ToolRegistry.execute("provide_text")
            → VoiceInputCoordinator.handleTextOutput()
              → TextInsertionService.insert()
                → 剪贴板备份 → Cmd+V → 恢复
                → saveUsageRecord() → CoreData
                → [可选] MemoSyncManager.syncMemo()
              → QuotaManager.reportAndRefresh()
```

## 问题清单（按严重程度）

### 🔴 P0 — 会造成 Bug

| ID | 问题 | 文件:行号 | 影响 |
|----|------|---------|------|
| B1 | MenuBarManager 每次创建新 PermissionManager 实例，不用共享实例 | MenuBarManager.swift:136 | 权限状态不同步 |
| B2 | HID 同步只订阅 hotkeyKeyCode，不订阅 hotkeyModifiers | AIInputMethodApp.swift:237-251 | 改修饰键后 HID 不更新 |
| B3 | VoiceInputCoordinator 状态机用 3 个 Bool 管理，无原子性 | VoiceInputCoordinator.swift:22-29 | 快速切换时丢字/重复处理 |

### 🟠 P1 — 架构问题（必须修复）

| ID | 问题 | 文件:行号 | 影响 |
|----|------|---------|------|
| A1 | AppDelegate 316行，9个职责 | AIInputMethodApp.swift:55-316 | 启动脆弱，难以维护 |
| A2 | TextInsertionService 同时做剪贴板+按键+CoreData | TextInsertionService.swift | 不可测试，竞态风险 |
| A3 | AIPolishViewModel didSet 与 AppSettings 双向绑定 | AppSettings.swift + AIPolishViewModel | 状态不一致 |
| A4 | VoiceInputCoordinator 内部创建不可注入的 Store | VoiceInputCoordinator.swift:33-34 | 无法单元测试 |

### 🟡 P2 — 轻微问题

| ID | 问题 | 文件 | 影响 |
|----|------|------|------|
| C1 | SkillExecutor context cache 所有 key 用同一 TTL | SkillExecutor.swift:24 | 刚校准后 30s 不生效 |
| C2 | PermissionManager.startPolling() 重试无上限 | PermissionManager.swift:81 | 权限永不授权时无限轮询 |
| C3 | DoubaoSpeechService 凭证缓存无过期机制 | DoubaoSpeechService.swift:52-60 | token 失效后无感知 |
| C4 | 注释中英文混杂 | 全局 | 阅读体验 |

---

## Phase 1：零风险 Bug 修复（可随时回滚）

> 预计时间：1 小时
> 风险：极低（改 1-3 行）
> 验证：`swift build` + 手动点菜单权限项

---

### Task 1.1：修复 MenuBarManager 使用共享 PermissionManager

**问题**：`PermissionManager().requestMicrophoneAccess()` 创建了新实例，与 AppDelegate 中的 permissionManager 状态不同步。

**文件：**
- Modify: `Sources/Features/MenuBar/MenuBarManager.swift`
- Modify: `Sources/AIInputMethodApp.swift`（注入依赖）

**Step 1：读取 MenuBarManager 构造器**

```bash
grep -n "init\|permissionManager\|PermissionManager" \
  Sources/Features/MenuBar/MenuBarManager.swift
```

**Step 2：在 MenuBarManager 中添加 permissionManager 属性**

找到 `MenuBarManager` 的属性声明区（约行 14-18），添加：

```swift
weak var permissionManager: PermissionManager?
```

**Step 3：修改 requestMic() 方法（约行 134-138）**

将：
```swift
@objc private func requestMic() {
    PermissionManager().requestMicrophoneAccess()
}
```
改为：
```swift
@objc private func requestMic() {
    permissionManager?.requestMicrophoneAccess()
}
```

**Step 4：在 AppDelegate.startApp() 中注入**

找到 `menuBarManager` 初始化之后（约行 207），添加：
```swift
menuBarManager.permissionManager = permissionManager
```

**Step 5：验证编译**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
```
期望：`Build complete!`

**Step 6：提交**
```bash
git add Sources/Features/MenuBar/MenuBarManager.swift Sources/AIInputMethodApp.swift
git commit -m "fix: MenuBarManager use shared PermissionManager instead of new instance

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 1.2：修复 HID 同步同时订阅 hotkeyModifiers

**问题**：AppDelegate 只监听 `hotkeyKeyCode` 变化来同步 HID，修改修饰键时 HID 不更新。

**文件：**
- Modify: `Sources/AIInputMethodApp.swift:237-251`

**Step 1：读取当前订阅代码**

```bash
sed -n '230,260p' Sources/AIInputMethodApp.swift
```

**Step 2：找到当前订阅（约行 237-251）**

```swift
AppSettings.shared.$hotkeyKeyCode
    .dropFirst()
    .sink { [weak self] newKeyCode in
        self?.hidMappingManager.syncTargetKeyCode(UInt32(newKeyCode))
    }
    .store(in: &cancellables)
```

替换为：
```swift
Publishers.CombineLatest(
    AppSettings.shared.$hotkeyKeyCode,
    AppSettings.shared.$hotkeyModifiers
)
.dropFirst()
.sink { [weak self] newKeyCode, _ in
    self?.hidMappingManager.syncTargetKeyCode(UInt32(newKeyCode))
}
.store(in: &cancellables)
```

**Step 3：验证编译**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

**Step 4：提交**
```bash
git add Sources/AIInputMethodApp.swift
git commit -m "fix: HID mapping sync on hotkeyModifiers change too

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 1.3：修复 PermissionManager 轮询无上限

**问题**：`startPolling()` 无最大重试次数，若权限永不授权则永远消耗资源。

**文件：**
- Modify: `Sources/Features/Permissions/PermissionManager.swift:81-91`

**Step 1：读取 startPolling 方法**

```bash
sed -n '78,95p' Sources/Features/Permissions/PermissionManager.swift
```

**Step 2：添加最大重试次数（最多轮询 150 次 = 5 分钟）**

找到 `startPolling()` 方法，修改为：
```swift
func startPolling() {
    var attempts = 0
    let maxAttempts = 150  // 最多轮询 5 分钟（150 × 2s）
    Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
        guard let self else { timer.invalidate(); return }
        attempts += 1
        self.refreshAll()
        let allGranted = self.isAccessibilityTrusted
            && self.isInputMonitoringGranted
            && self.isMicrophoneGranted
        if allGranted || attempts >= maxAttempts {
            timer.invalidate()
        }
    }
}
```

**Step 3：验证编译**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

**Step 4：提交**
```bash
git add Sources/Features/Permissions/PermissionManager.swift
git commit -m "fix: PermissionManager polling stops after 5 minutes max

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 1.4：分 key 设置 context cache TTL

**问题**：`SkillExecutor` 所有 context key 共用 30 秒 TTL，`calibration_records` 刚校准完 30 秒内不刷新。

**文件：**
- Modify: `Sources/Features/AI/Skill/SkillExecutor.swift`

**Step 1：读取当前 TTL 配置**

```bash
grep -n "TTL\|contextCache\|getCachedContext" Sources/Features/AI/Skill/SkillExecutor.swift
```

**Step 2：添加 per-key TTL 映射**

在 `contextCacheTTL` 属性附近添加：
```swift
private let contextCacheTTLByKey: [String: TimeInterval] = [
    "calibration_records": 5,   // 刚校准后 5s 内立即生效
    "asr_corpus": 10,            // 语料库 10s 刷新一次
    "ghost_profile": 60,         // 人格档案变化慢，60s
    "current_app": 2,            // 当前应用可能频繁切换
]
private let contextCacheDefaultTTL: TimeInterval = 30
```

**Step 3：修改 getCachedContext 使用 per-key TTL**

```swift
private func getCachedContext(key: String, provider: () -> String) -> String {
    let ttl = contextCacheTTLByKey[key] ?? contextCacheDefaultTTL
    if let cached = contextCache[key], cached.expiry > Date() {
        return cached.value
    }
    let value = provider()
    contextCache[key] = (value: value, expiry: Date().addingTimeInterval(ttl))
    return value
}
```

**Step 4：验证编译**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

**Step 5：提交**
```bash
git add Sources/Features/AI/Skill/SkillExecutor.swift
git commit -m "fix: per-key TTL for context cache (calibration 5s, corpus 10s, profile 60s)

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 1.5：Phase 1 完整验证

**Step 1：运行所有测试**
```bash
swift test 2>&1 | tail -20
```
期望：`Test Suite 'All tests' passed`

**Step 2：手动测试**
```bash
bash ghostype.sh debug
```
测试清单：
- [ ] 菜单栏 → 权限状态显示正确
- [ ] 菜单栏 → 请求麦克风权限 → 弹出系统权限弹窗
- [ ] 在偏好设置更改快捷键 → HID 设置页同步更新
- [ ] 语音输入正常工作（说话 → 上屏）

---

## Phase 2：提取独立服务（低风险）

> 预计时间：3 小时
> 风险：低（Extract Class，不改逻辑）
> 验证：每个 Task 都 `swift build` + `swift test`

---

### Task 2.1：创建重构分支

```bash
git checkout -b refactor/phase-2
```

---

### Task 2.2：将 AppSettings 批量写入防抖

**问题**：每个属性的 `didSet { saveToUserDefaults() }` 导致批量修改时多次 IO。
**方案**：添加 `NSObject.cancelPreviousPerformRequests` 式防抖，100ms 内合并写入。

**文件：**
- Modify: `Sources/Features/Settings/AppSettings.swift`

**Step 1：在 AppSettings 中添加防抖标志**

在 `class AppSettings` 顶部属性区添加：
```swift
private var saveDebounceTimer: DispatchSourceTimer?
```

**Step 2：添加 debouncedSave() 方法**

在 `saveToUserDefaults()` 前添加：
```swift
private func debouncedSave() {
    saveDebounceTimer?.cancel()
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 0.1)
    timer.setEventHandler { [weak self] in
        self?.saveToUserDefaults()
        self?.saveDebounceTimer = nil
    }
    timer.resume()
    saveDebounceTimer = timer
}
```

**Step 3：所有 `didSet { saveToUserDefaults() }` 改为 `didSet { debouncedSave() }`**

```bash
# 查找所有需要修改的行
grep -n "didSet { saveToUserDefaults" Sources/Features/Settings/AppSettings.swift
```

用编辑器批量替换（注意 appLanguage 的 didSet 还有额外逻辑，不能简单替换，单独处理）：
- `appLanguage` 的 didSet 保持不变（需要立即同步 LocalizationManager）
- 其余所有 `saveToUserDefaults()` 改为 `debouncedSave()`

**Step 4：验证编译和测试**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
swift test 2>&1 | tail -5
```

**Step 5：提交**
```bash
git add Sources/Features/Settings/AppSettings.swift
git commit -m "refactor: debounce AppSettings UserDefaults writes (100ms coalescing)

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 2.3：提取 ClipboardService

**问题**：剪贴板的备份/写入/恢复逻辑与 TextInsertionService 的其他职责混在一起。

**文件：**
- Create: `Sources/Features/VoiceInput/ClipboardService.swift`
- Modify: `Sources/Features/VoiceInput/TextInsertionService.swift`

**Step 1：创建 ClipboardService.swift**

```swift
// Sources/Features/VoiceInput/ClipboardService.swift
import AppKit

/// 剪贴板备份/写入/恢复服务
/// 职责：仅负责剪贴板操作，不涉及按键模拟或业务逻辑
final class ClipboardService {
    private let pasteboard = NSPasteboard.general

    struct BackupToken {
        let items: [[NSPasteboard.PasteboardType: Data]]
        let changeCount: Int
    }

    /// 备份当前剪贴板内容，返回不透明 token
    func backup() -> BackupToken {
        let items = pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues:
                item.types.compactMap { type in
                    item.data(forType: type).map { (type, $0) }
                }
            )
        } ?? []
        return BackupToken(items: items, changeCount: pasteboard.changeCount)
    }

    /// 将文本写入剪贴板（标记为不记录历史）
    func write(_ text: String) -> Int {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"))
        return pasteboard.changeCount
    }

    /// 恢复剪贴板到 token 中的内容
    func restore(_ token: BackupToken) {
        pasteboard.clearContents()
        for item in token.items {
            let pbItem = NSPasteboardItem()
            for (type, data) in item {
                pbItem.setData(data, forType: type)
            }
            pasteboard.writeObjects([pbItem])
        }
    }

    /// 当前 changeCount
    var changeCount: Int { pasteboard.changeCount }
}
```

**Step 2：在 TextInsertionService 中使用 ClipboardService**

读取 TextInsertionService 完整内容，然后：
- 在 `TextInsertionService` 顶部添加 `private let clipboardService = ClipboardService()`
- 将原有的剪贴板操作（备份、写入、恢复逻辑）改为调用 `clipboardService` 的对应方法
- 保持所有时序和延迟不变

**Step 3：验证编译**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

**Step 4：手动测试**
```bash
bash ghostype.sh debug
```
- [ ] 语音输入 → 文字正确上屏
- [ ] 上屏后剪贴板内容恢复为原来的内容（在 TextEdit 中复制一段文字，再语音输入，确认剪贴板恢复）

**Step 5：提交**
```bash
git add Sources/Features/VoiceInput/ClipboardService.swift \
        Sources/Features/VoiceInput/TextInsertionService.swift
git commit -m "refactor: extract ClipboardService from TextInsertionService

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 2.4：将 saveUsageRecord 移出 TextInsertionService

**问题**：`TextInsertionService.saveUsageRecord()` 是业务逻辑，与文本插入无关。

**文件：**
- Modify: `Sources/Features/VoiceInput/TextInsertionService.swift`
- Modify: `Sources/Features/VoiceInput/VoiceInputCoordinator.swift`

**Step 1：在 VoiceInputCoordinator 中找到调用 textInserter.insert() 的地方**

```bash
grep -n "textInserter\|saveUsageRecord\|insert(" \
  Sources/Features/VoiceInput/VoiceInputCoordinator.swift | head -20
```

**Step 2：将 saveUsageRecord 逻辑从 TextInsertionService 移至 VoiceInputCoordinator**

在 VoiceInputCoordinator 的文本插入完成回调后，直接调用持久化逻辑（原来 TextInsertionService.saveUsageRecord 的代码）。

注意：`saveUsageRecord` 需要的参数（content、originalContent、category、skill、sourceApp 等）本来就在 VoiceInputCoordinator 的上下文中。

**Step 3：从 TextInsertionService 中删除 saveUsageRecord 方法（约行 177-209）**

**Step 4：验证编译和测试**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
swift test 2>&1 | tail -5
```

**Step 5：提交**
```bash
git add Sources/Features/VoiceInput/TextInsertionService.swift \
        Sources/Features/VoiceInput/VoiceInputCoordinator.swift
git commit -m "refactor: move saveUsageRecord from TextInsertionService to VoiceInputCoordinator

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 2.5：Phase 2 验证与合并

**Step 1：完整测试**
```bash
swift test 2>&1 | tail -20
bash ghostype.sh debug
```

手动测试清单：
- [ ] 语音输入 → 润色 → 上屏
- [ ] 语音输入 → 翻译 → 上屏
- [ ] 语音输入 → 备忘录
- [ ] Skill 执行（自定义 Skill）
- [ ] 剪贴板内容在上屏后正确恢复
- [ ] Dashboard 记录正确保存

**Step 2：合并到 main**
```bash
git checkout main
git merge refactor/phase-2 --no-ff -m "refactor: Phase 2 - Extract ClipboardService, debounce AppSettings saves"
```

---

## Phase 3：状态机重构（中风险）

> 预计时间：3 小时
> 风险：中（改核心状态逻辑）
> 验证：测试所有快速操作边界条件

---

### Task 3.1：创建分支

```bash
git checkout -b refactor/phase-3
```

---

### Task 3.2：VoiceInputCoordinator 引入状态机

**问题**：3 个布尔变量（`waitingForFinalResult`、`isVoiceInputEnabled` + `pendingSkill`）管理录音状态，无原子性，快速按下/松开时可能丢字。

**文件：**
- Modify: `Sources/Features/VoiceInput/VoiceInputCoordinator.swift`

**Step 1：在文件顶部定义状态枚举（在 import 之后，class 之前）**

```swift
/// 语音输入状态机
private enum RecordingState {
    /// 空闲，未录音
    case idle
    /// 正在录音（快捷键按住中）
    case recording(skill: SkillModel)
    /// 录音结束，等待 ASR 最终结果
    case waitingForResult(skill: SkillModel, timeout: DispatchWorkItem)
    /// 正在处理 Skill（调用 LLM）
    case processing(skill: SkillModel)
}
```

**Step 2：替换旧状态变量**

删除：
```swift
private var waitingForFinalResult = false
private var pendingSkill: SkillModel? = nil
private var currentSkill: SkillModel? = nil
```

添加：
```swift
private var recordingState: RecordingState = .idle
```

**Step 3：重写 handlePushToTalkHotkeyDown()**

```swift
func handlePushToTalkHotkeyDown() {
    guard case .idle = recordingState else { return }  // 防止重入
    let skill = currentSkillForHotkey()  // 从 HotkeyManager 获取当前 Skill
    recordingState = .recording(skill: skill)
    overlayManager.show()
    // ... 其余逻辑不变
}
```

**Step 4：重写 handlePushToTalkHotkeyUp()**

```swift
func handlePushToTalkHotkeyUp(finalSkill: SkillModel?) {
    guard case .recording(let skill) = recordingState else { return }
    let effectiveSkill = finalSkill ?? skill
    speechService.stopRecording()

    if !currentRawText.isEmpty {
        recordingState = .processing(skill: effectiveSkill)
        processWithSkill(text: currentRawText, skill: effectiveSkill)
    } else {
        // 等待 ASR 最终结果
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, case .waitingForResult(let s, _) = self.recordingState else { return }
            self.recordingState = .idle
            self.overlayManager.hide()
        }
        recordingState = .waitingForResult(skill: effectiveSkill, timeout: timeout)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.Overlay.speechTimeoutSeconds,
            execute: timeout
        )
    }
}
```

**Step 5：重写 onFinalResult 回调**

```swift
speechService.onFinalResult = { [weak self] text in
    guard let self else { return }
    self.currentRawText = text
    switch self.recordingState {
    case .waitingForResult(let skill, let timeout):
        timeout.cancel()
        self.recordingState = .processing(skill: skill)
        self.processWithSkill(text: text, skill: skill)
    case .recording:
        // 快捷键还按着，先保存文本
        break
    default:
        break
    }
}
```

**Step 6：ESC 取消**

```swift
func cancelVoiceInput() {
    switch recordingState {
    case .recording:
        speechService.cancelRecording()
    case .waitingForResult(_, let timeout):
        timeout.cancel()
    default:
        break
    }
    recordingState = .idle
    currentRawText = ""
    overlayManager.hide()
}
```

**Step 7：处理完成后重置状态**

在 `dispatchResult()` / `handleTextOutput()` 完成后：
```swift
recordingState = .idle
currentRawText = ""
```

**Step 8：验证编译**
```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

**Step 9：边界测试（手动）**

- [ ] 正常语音输入
- [ ] 快速按下/松开（100ms 内）
- [ ] 按下后立即 ESC 取消
- [ ] 说话后 3 秒无结果超时自动关闭
- [ ] 连续多次语音输入
- [ ] 说话同时按修饰键切换 Skill

**Step 10：提交**
```bash
git add Sources/Features/VoiceInput/VoiceInputCoordinator.swift
git commit -m "refactor: replace boolean flags with RecordingState enum in VoiceInputCoordinator

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 3.3：让 VoiceInputCoordinator 的 Store 可注入

**问题**：`corpusStore` 和 `profileStore` 在类内部 `let` 声明，无法在测试中替换。

**文件：**
- Modify: `Sources/Features/VoiceInput/VoiceInputCoordinator.swift`
- Modify: `Sources/AIInputMethodApp.swift`（更新构造调用）

**Step 1：在 VoiceInputCoordinator 构造器中接收 Store**

将：
```swift
private let corpusStore = ASRCorpusStore()
private let profileStore = GhostTwinProfileStore()
```

改为构造器参数（带默认值，保持调用兼容性）：
```swift
private let corpusStore: ASRCorpusStore
private let profileStore: GhostTwinProfileStore

init(
    speechService: DoubaoSpeechService,
    skillExecutor: SkillExecutor,
    toolRegistry: ToolRegistry,
    textInserter: TextInsertionService,
    overlayManager: OverlayWindowManager,
    hotkeyManager: HotkeyManager,
    corpusStore: ASRCorpusStore = ASRCorpusStore(),
    profileStore: GhostTwinProfileStore = GhostTwinProfileStore()
) {
    self.corpusStore = corpusStore
    self.profileStore = profileStore
    // ... 其余原有初始化
}
```

**Step 2：验证编译**

AppDelegate 中的 `VoiceInputCoordinator(...)` 调用不需要修改（默认值兼容）。

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

**Step 3：提交**
```bash
git add Sources/Features/VoiceInput/VoiceInputCoordinator.swift
git commit -m "refactor: make ASRCorpusStore and GhostTwinProfileStore injectable in VoiceInputCoordinator

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 3.4：Phase 3 验证与合并

```bash
swift test 2>&1 | tail -20
bash ghostype.sh debug
```

全量手动测试清单：
- [ ] 语音输入 → 润色 → 上屏
- [ ] 语音输入 → 翻译 → 上屏
- [ ] 语音输入 → 备忘录
- [ ] 快速连续输入（3 次以上）
- [ ] ESC 取消
- [ ] 超时自动关闭（说话后静止 3 秒）
- [ ] 修饰键切换 Skill
- [ ] Dashboard 记录正确

```bash
git checkout main
git merge refactor/phase-3 --no-ff -m "refactor: Phase 3 - RecordingState enum, injectable stores"
```

---

## Phase 4：AppDelegate 拆解（高风险）

> 预计时间：4 小时
> 风险：高（改应用启动核心链路）
> 验证：最完整的手动测试，包含冷启动

---

### Task 4.1：创建分支

```bash
git checkout -b refactor/phase-4
```

---

### Task 4.2：提取 AppBootstrapper

**问题**：`AppDelegate.startApp()` 包含 15+ 步骤初始化，顺序错误会导致崩溃，难以理解和维护。

**文件：**
- Create: `Sources/Features/App/AppBootstrapper.swift`
- Modify: `Sources/AIInputMethodApp.swift`

**Step 1：创建 AppBootstrapper**

```swift
// Sources/Features/App/AppBootstrapper.swift
import Foundation
import Combine

/// 应用启动协调器
/// 职责：按正确顺序初始化所有核心服务
/// 分阶段：权限检查 → 核心服务 → UI 服务 → 功能注册
@MainActor
final class AppBootstrapper {
    private(set) var cancellables = Set<AnyCancellable>()

    func bootstrap(delegate: AppDelegate) {
        // Phase 1: 技能系统（无依赖）
        bootstrapSkillSystem(delegate: delegate)

        // Phase 2: UI 服务（依赖 skillManager）
        bootstrapUI(delegate: delegate)

        // Phase 3: 输入服务（依赖 UI）
        bootstrapInputServices(delegate: delegate)

        // Phase 4: 功能注册和观察者
        bootstrapObservers(delegate: delegate)
    }

    // 各阶段函数将 AppDelegate 中对应代码移入这里
    // 每个阶段独立，便于测试
}
```

**Step 2：逐块将 startApp() 代码移入 AppBootstrapper**

按以下顺序迁移（每迁移一块就验证编译）：
1. Skill 系统初始化
2. 菜单栏初始化
3. Overlay 初始化
4. FocusObserver 初始化
5. HotkeyManager 初始化
6. HID 映射初始化
7. Combine 订阅注册

**Step 3：AppDelegate.startApp() 变为一行**

```swift
private func startApp() {
    AppBootstrapper().bootstrap(delegate: self)
}
```

**Step 4：验证编译和冷启动测试**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
bash ghostype.sh debug --clean  # 模拟全新安装
```

冷启动测试：
- [ ] 应用正常启动
- [ ] 菜单栏出现
- [ ] Onboarding 弹出（--clean 模式）
- [ ] 权限引导流程正常

**Step 5：提交**
```bash
git add Sources/Features/App/AppBootstrapper.swift Sources/AIInputMethodApp.swift
git commit -m "refactor: extract AppBootstrapper, decompose startApp() into phases

Generated with [Claude Code](https://claude.ai/code)
via [Happy](https://happy.engineering)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: Happy <yesreply@happy.engineering>"
```

---

### Task 4.3：Phase 4 完整验证

```bash
swift test 2>&1 | tail -20
bash ghostype.sh release --clean
```

完整测试矩阵：
- [ ] 全新安装 Onboarding 流程
- [ ] 登录 → 语音输入 → 上屏
- [ ] 登出 → 语音输入（应提示登录）
- [ ] 快捷键设置
- [ ] HID 设备映射
- [ ] Dashboard 打开/关闭
- [ ] 自动更新检查
- [ ] 应用退出（HID 清理）

```bash
git checkout main
git merge refactor/phase-4 --no-ff -m "refactor: Phase 4 - Extract AppBootstrapper"
```

---

## 追踪表

| Task | Phase | 状态 | 风险 | 预计时间 |
|------|-------|------|------|--------|
| 1.1 MenuBarManager PermissionManager | P1 | ⬜ | 极低 | 15min |
| 1.2 HID 同步 modifiers | P1 | ⬜ | 极低 | 10min |
| 1.3 PermissionManager 轮询上限 | P1 | ⬜ | 极低 | 15min |
| 1.4 Context cache per-key TTL | P1 | ⬜ | 极低 | 20min |
| 1.5 Phase 1 验证 | P1 | ⬜ | — | 15min |
| 2.1 创建分支 | P2 | ⬜ | — | 5min |
| 2.2 AppSettings 防抖 | P2 | ⬜ | 低 | 30min |
| 2.3 提取 ClipboardService | P2 | ⬜ | 低 | 45min |
| 2.4 saveUsageRecord 迁移 | P2 | ⬜ | 低 | 30min |
| 2.5 Phase 2 验证 | P2 | ⬜ | — | 20min |
| 3.1 创建分支 | P3 | ⬜ | — | 5min |
| 3.2 RecordingState 状态机 | P3 | ⬜ | 中 | 60min |
| 3.3 Store 可注入 | P3 | ⬜ | 低 | 20min |
| 3.4 Phase 3 验证 | P3 | ⬜ | — | 20min |
| 4.1 创建分支 | P4 | ⬜ | — | 5min |
| 4.2 AppBootstrapper | P4 | ⬜ | 高 | 90min |
| 4.3 Phase 4 验证 | P4 | ⬜ | — | 30min |

**总预计时间：约 7 小时**

---

## 不在本计划内（技术债记录）

以下问题已知但不在本次重构范围，记录供后续处理：

1. **AppSettings 双向绑定**（AIPolishViewModel ↔ AppSettings）：需要决策哪里是单一真相源，改动影响 Dashboard UI，需独立 PR
2. **CoreData 操作在主线程**：需要迁移到后台 context，影响范围广
3. **GhostTypeAPIClient 请求批处理**：性能优化，非结构问题
4. **Rate limiting 分布式**（后端）：后端独立 PR
