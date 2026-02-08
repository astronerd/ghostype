# GHOSTYPE 重构设计文档

## 一、当前架构分析

### 1.1 核心链路

```
用户按住快捷键 → HotkeyManager 捕获
       ↓
DoubaoSpeechService 录音 + 语音识别
       ↓
AppDelegate.processWithMode() 分发
       ↓
┌─────────────────────────────────────┐
│ polish → DoubaoLLMService.polishWithProfile()
│ translate → DoubaoLLMService.translate()
│ memo → 直接保存到 CoreData
└─────────────────────────────────────┘
       ↓
insertTextAtCursor() 粘贴上屏
       ↓
saveUsageRecord() 记录到 CoreData
```

### 1.2 当前架构层级

```
AIInputMethod/
├── Sources/
│   ├── AIInputMethodApp.swift          # App 入口 + AppDelegate (God Class)
│   ├── Features/
│   │   ├── AI/                         # LLM 服务层
│   │   │   ├── DoubaoLLMService.swift
│   │   │   ├── MiniMaxService.swift
│   │   │   ├── PromptBuilder.swift
│   │   │   └── ...
│   │   ├── Dashboard/                  # ViewModel + 数据层
│   │   ├── Settings/                   # 设置 + 本地化
│   │   ├── Hotkey/                     # 快捷键
│   │   ├── Speech/                     # 语音识别
│   │   ├── Accessibility/              # 光标管理
│   │   └── Permissions/                # 权限管理
│   └── UI/
│       ├── Dashboard/                  # Dashboard UI
│       └── ...                         # 其他窗口
```

---

## 二、目标架构

### 2.1 服务层拆分

```
AppDelegate (精简版，< 150 行)
    │
    ├── 生命周期管理
    ├── 服务组装
    └── 权限检查
    
独立服务：
    ├── VoiceInputCoordinator    # 录音 + AI 处理协调
    ├── TextInsertionService     # 文本上屏
    ├── MenuBarManager           # 菜单栏管理
    └── OverlayWindowManager     # 浮窗管理
```

### 2.2 LLM 服务层

```
LLMServiceProtocol (协议)
    │
    └── BaseLLMService (抽象基类)
            │
            ├── DoubaoLLMService (豆包实现)
            └── MiniMaxService (MiniMax实现)
```

### 2.3 配置管理

```
SecretsManager              # Keychain 存储敏感信息
    │
    ├── KeychainSecretsManager (生产环境)
    └── EnvironmentSecretsManager (开发环境)

Constants                   # 集中魔法数字
    │
    ├── Hotkey
    ├── Audio
    └── Stats
```

### 2.4 数据流

```
用户操作 
    ↓
ViewModel.updateXxx() 
    ↓
AppSettings.setXxx() + save()
    ↓
NotificationCenter.post()
    ↓
UI 刷新
```

---

## 三、详细设计

### 3.1 SecretsManager

**文件**: `Features/Settings/SecretsManager.swift`

```swift
protocol SecretsManagerProtocol {
    func getAPIKey(for service: ServiceType) -> String?
    func setAPIKey(_ key: String, for service: ServiceType)
    func deleteAPIKey(for service: ServiceType)
}

enum ServiceType: String {
    case doubaoLLM = "com.ghostype.doubao-llm"
    case doubaoSpeech = "com.ghostype.doubao-speech"
    case minimax = "com.ghostype.minimax"
}

class KeychainSecretsManager: SecretsManagerProtocol {
    // 使用 Security.framework Keychain API
    // 存储格式: service = ServiceType.rawValue
}

class EnvironmentSecretsManager: SecretsManagerProtocol {
    // 从环境变量读取: GHOSTYPE_DOUBAO_LLM_KEY 等
    // 用于开发环境
}
```

**使用方式**:
```swift
// 在 LLM 服务中
let apiKey = SecretsManager.shared.getAPIKey(for: .doubaoLLM) ?? ""
```

### 3.2 Constants

**文件**: `Features/Settings/Constants.swift`

```swift
enum Constants {
    enum Hotkey {
        static let stickyDelayMs: Double = 500
        static let modifierDebounceMs: Double = 300
    }
    
    enum Audio {
        static let sendIntervalSeconds: Double = 0.2
        static let sampleRate: Double = 16000
        static let channels: Int = 1
    }
    
    enum Stats {
        static let typingSpeedPerSecond: Double = 1.0
    }
    
    enum UI {
        static let overlayCornerRadius: CGFloat = 12
        static let animationDuration: Double = 0.3
    }
}
```

### 3.3 VoiceInputCoordinator

**文件**: `Features/VoiceInput/VoiceInputCoordinator.swift`

```swift
@Observable
class VoiceInputCoordinator {
    // 依赖
    private let speechService: DoubaoSpeechService
    private let llmService: LLMServiceProtocol
    private let textInsertion: TextInsertionService
    
    // 状态
    var state: VoiceInputState = .idle
    var currentMode: InputMode = .polish
    var recognizedText: String = ""
    var processedText: String = ""
    
    // 回调
    var onStateChanged: ((VoiceInputState) -> Void)?
    var onTextRecognized: ((String) -> Void)?
    var onTextProcessed: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    // 方法
    func startRecording(mode: InputMode)
    func stopRecording()
    func cancelRecording()
    
    // 内部方法
    private func processRecognizedText(_ text: String)
    private func handlePolish(_ text: String)
    private func handleTranslate(_ text: String)
    private func handleMemo(_ text: String)
}

enum VoiceInputState {
    case idle
    case recording
    case processing
    case inserting
    case error(Error)
}
```

### 3.4 TextInsertionService

**文件**: `Features/Accessibility/TextInsertionService.swift`

```swift
class TextInsertionService {
    private let cursorManager: CursorManager
    
    func insertText(_ text: String, autoEnter: Bool = false) {
        // 1. 复制到剪贴板
        // 2. 模拟 Cmd+V
        // 3. 如果 autoEnter，发送回车
    }
    
    func sendEnterKey() {
        // 模拟回车键
    }
}
```

### 3.5 MenuBarManager

**文件**: `Features/MenuBar/MenuBarManager.swift`

```swift
class MenuBarManager {
    private var statusItem: NSStatusItem?
    private weak var delegate: MenuBarManagerDelegate?
    
    func setup()
    func updateIcon(for state: VoiceInputState)
    func showMenu()
}

protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidSelectOpenDashboard()
    func menuBarDidSelectQuit()
    // ...
}
```

### 3.6 OverlayWindowManager

**文件**: `Features/Overlay/OverlayWindowManager.swift`

```swift
class OverlayWindowManager {
    private var overlayWindow: NSWindow?
    private var overlayView: OverlayView?
    
    func setup()
    func show(state: OverlayState, at position: OverlayPosition)
    func hide()
    func updateState(_ state: OverlayState)
    
    private func positionAtBottom()
    private func positionAtCursor()
}

enum OverlayPosition {
    case bottom
    case cursor
}
```

### 3.7 LLMServiceProtocol

**文件**: `Features/AI/LLMServiceProtocol.swift`

```swift
protocol LLMServiceProtocol {
    func polish(
        text: String, 
        profile: PolishProfile, 
        completion: @escaping (Result<String, LLMError>) -> Void
    )
    
    func translate(
        text: String, 
        language: TranslateLanguage, 
        completion: @escaping (Result<String, LLMError>) -> Void
    )
}

enum LLMError: Error {
    case networkError(Error)
    case apiError(code: Int, message: String)
    case parseError(String)
    case noAPIKey
}
```

### 3.8 BaseLLMService

**文件**: `Features/AI/BaseLLMService.swift`

```swift
class BaseLLMService {
    let secretsManager: SecretsManagerProtocol
    let serviceType: ServiceType
    
    init(secretsManager: SecretsManagerProtocol, serviceType: ServiceType)
    
    // 通用方法
    func sendRequest(
        url: URL,
        headers: [String: String],
        body: Data,
        completion: @escaping (Result<Data, LLMError>) -> Void
    )
    
    func parseResponse<T: Decodable>(_ data: Data, as type: T.Type) -> Result<T, LLMError>
    
    // 子类实现
    var apiKey: String? { secretsManager.getAPIKey(for: serviceType) }
    var baseURL: URL { fatalError("Subclass must override") }
}
```

### 3.9 数据流重构

**AppSettings 改造**:
```swift
@Observable
class AppSettings {
    // 属性（移除 didSet）
    var selectedProfile: PolishProfile = .professional
    var autoEnter: Bool = false
    // ...
    
    // 显式保存方法
    func save() {
        UserDefaults.standard.set(...)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    // 更新方法
    func setSelectedProfile(_ profile: PolishProfile) {
        selectedProfile = profile
        save()
    }
}
```

**ViewModel 改造**:
```swift
@Observable
class AIPolishViewModel {
    private let settings: AppSettings
    
    // 移除 didSet，改为方法调用
    func updateProfile(_ profile: PolishProfile) {
        settings.setSelectedProfile(profile)
    }
}
```

---

## 四、文件结构变更

### 新增文件
```
Features/
├── Settings/
│   ├── SecretsManager.swift        # 新增
│   └── Constants.swift             # 新增
├── VoiceInput/
│   └── VoiceInputCoordinator.swift # 新增
├── MenuBar/
│   └── MenuBarManager.swift        # 新增
├── Overlay/
│   └── OverlayWindowManager.swift  # 新增
└── AI/
    ├── LLMServiceProtocol.swift    # 新增
    └── BaseLLMService.swift        # 新增
```

### 修改文件
```
AIInputMethodApp.swift              # 精简，仅保留生命周期
DoubaoLLMService.swift              # 继承 BaseLLMService
MiniMaxService.swift                # 继承 BaseLLMService
HotkeyManager.swift                 # 使用 Constants
DoubaoSpeechService.swift           # 使用 Constants, SecretsManager
StatsCalculator.swift               # 使用 Constants
AppSettings.swift                   # 移除 didSet，添加方法
AIPolishViewModel.swift             # 移除 didSet
PreferencesViewModel.swift          # 移除 didSet
OverviewPage.swift                  # 本地化 + 移除 MinimalBentoCard
LibraryPage.swift                   # 本地化
MemoPage.swift                      # 本地化
AIPolishPage.swift                  # 本地化
BentoCard.swift                     # 合并 MinimalBentoCard
```

---

## 五、迁移策略

### Phase 1: 安全与配置（低风险）
1. 创建 Constants.swift，逐个替换魔法数字
2. 创建 SecretsManager.swift，逐个替换硬编码密钥
3. 每步编译测试

### Phase 2: 拆分 AppDelegate（高风险）
1. 先提取最独立的 TextInsertionService
2. 再提取 OverlayWindowManager
3. 再提取 MenuBarManager
4. 最后提取 VoiceInputCoordinator（最复杂）
5. 每步完整功能测试

### Phase 3: 统一 LLM 服务（中风险）
1. 先定义 Protocol，不改现有代码
2. 创建 BaseLLMService
3. 逐个迁移服务类
4. 每步功能测试

### Phase 4: 数据流整理（中风险）
1. 先改 AppSettings，添加方法
2. 再改 ViewModel，移除 didSet
3. 测试设置页面

### Phase 5: 本地化（低风险）
1. 逐页添加字符串
2. 逐页替换硬编码
3. 测试语言切换

---

## 六、测试策略

### 单元测试
- SecretsManager: 存取密钥
- Constants: 值正确性
- TextInsertionService: 文本插入
- LLM 服务: 请求/响应解析

### 集成测试（手动）
- 完整录音→AI→上屏流程
- Dashboard 各页面
- 设置保存/读取
- 语言切换

### 回归测试检查点
- [ ] 按住快捷键开始录音
- [ ] 松开快捷键停止录音
- [ ] 语音识别结果正确
- [ ] AI 润色/翻译正常
- [ ] 文本正确上屏
- [ ] 浮窗显示/隐藏正常
- [ ] 菜单栏操作正常
- [ ] Dashboard 打开正常
- [ ] 设置保存/读取正常
- [ ] 语言切换正常
