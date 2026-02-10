# Ghost Twin 孵化室 — 设计文档

## Overview

孵化室（The Incubator）是 GHOSTYPE Dashboard 中的新页面模块，以赛博朋克 CRT 点阵屏为核心视觉，展示用户 Ghost Twin 的成长过程。

核心设计决策：
- **客户端轻量化**：等级计算、人格档案管理、校准 Prompt 全部由服务端负责，客户端仅做展示和交互
- **Canvas 高性能渲染**：19,200 个像素点使用 SwiftUI Canvas + `.drawingGroup()` 渲染，避免创建 19,200 个 SwiftUI View
- **双层 Canvas 辉光**：底层模糊 Canvas 做光晕 + 上层锐利 Canvas，实现 CRT Bloom 效果
- **本地缓存兜底**：API 不可用时使用 UserDefaults 缓存的最后已知状态，保证页面始终可显示
- **独立 API 链路**：Ghost Twin 的 3 个 API 端点独立于现有 `/api/v1/llm/chat`，校准系统有自己的 LLM 调用链

## Architecture

```mermaid
graph TB
    subgraph UI Layer
        IP[IncubatorPage]
        DM[DotMatrixView<br/>Canvas 160×120]
        CRT[CRTEffectsView<br/>扫描线+暗角]
        RS[ReceiptSlipView<br/>热敏纸条]
        LI[LevelInfoBar<br/>等级+进度条]
        GS[GhostStatusText<br/>闲置文案]
    end

    subgraph ViewModel Layer
        VM[IncubatorViewModel<br/>@Observable]
    end

    subgraph Model Layer
        GMM[GhostMatrixModel<br/>像素状态管理]
        GTM[GhostTwinModels<br/>API 数据模型]
    end

    subgraph Service Layer
        API[GhostypeAPIClient<br/>扩展 Ghost Twin 端点]
        Cache[UserDefaults<br/>本地缓存]
    end

    IP --> VM
    IP --> DM
    IP --> CRT
    IP --> RS
    IP --> LI
    IP --> GS
    VM --> GMM
    VM --> GTM
    VM --> API
    VM --> Cache
```

### 文件结构

```
Sources/
├── Features/
│   └── Dashboard/
│       ├── IncubatorViewModel.swift      # ViewModel + 状态管理
│       └── GhostMatrixModel.swift        # 点阵数据模型 + 洗牌算法
├── UI/
│   └── Dashboard/
│       └── Pages/
│           ├── IncubatorPage.swift        # 主页面布局
│           └── Incubator/
│               ├── DotMatrixView.swift    # Canvas 点阵渲染
│               ├── CRTEffectsView.swift   # CRT 滤镜覆盖层
│               ├── ReceiptSlipView.swift  # 热敏纸条 UI
│               ├── LevelInfoBar.swift     # 等级信息栏
│               └── GhostStatusText.swift  # 闲置文案 + 打字机效果
├── Features/
│   └── AI/
│       ├── GhostypeAPIClient.swift       # 扩展 3 个 Ghost Twin 端点
│       └── GhostypeModels.swift          # 扩展 Ghost Twin 数据模型
├── Features/
│   └── Settings/
│       ├── Strings.swift                 # 新增 Incubator protocol
│       ├── Strings+Chinese.swift         # 中文翻译
│       └── Strings+English.swift         # 英文翻译
└── Resources/
    └── ghost_logo_160x120.png            # Ghost Logo 位图（黑白 PNG）
```

## Components and Interfaces

### 1. NavItem 扩展

```swift
// NavItem.swift 新增
enum NavItem: String, CaseIterable, Identifiable {
    case account
    case overview
    case incubator  // 新增
    case memo
    case library
    case aiPolish
    case preferences
    
    var icon: String {
        // ...
        case .incubator: return "flask.fill"
    }
    
    var title: String {
        case .incubator: return L.Nav.incubator
    }
    
    static var groups: [[NavItem]] {
        [
            [.account, .overview, .incubator],  // 第一组新增 incubator
            [.memo, .library],
            [.aiPolish, .preferences]
        ]
    }
    
    var requiresAuth: Bool {
        case .incubator: return true
    }
    
    /// 徽章文字（nil 表示无徽章）
    var badge: String? {
        switch self {
        case .incubator: return "LAB"
        default: return nil
        }
    }
}
```

### 2. SidebarNavItem 徽章支持

在现有 `SidebarNavItem` 的 `HStack` 中，`Spacer()` 之后添加徽章视图：

```swift
if let badge = item.badge {
    Text(badge)
        .font(DS.Typography.mono(8, weight: .medium))
        .foregroundColor(DS.Colors.text2)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(DS.Colors.highlight)
        .cornerRadius(2)
}
```

### 3. IncubatorViewModel

```swift
@Observable
class IncubatorViewModel {
    // MARK: - State
    var level: Int = 1
    var totalXP: Int = 0
    var currentLevelXP: Int = 0
    var personalityTags: [String] = []
    var challengesRemaining: Int = 0
    
    var currentChallenge: CalibrationChallenge?
    var isLoadingChallenge: Bool = false
    var isSubmittingAnswer: Bool = false
    var ghostResponse: String?
    var showReceiptSlip: Bool = false
    
    var idleText: String = ""
    var isTypingIdle: Bool = false
    
    var isLevelingUp: Bool = false
    var isError: Bool = false
    var errorMessage: String?
    
    // MARK: - Models
    let matrixModel = GhostMatrixModel()
    
    // MARK: - Computed
    var ghostOpacity: Double { Double(level) * 0.1 }
    var syncRate: Int { level * 10 }
    var progressFraction: Double { Double(currentLevelXP) / 10_000.0 }
    
    // MARK: - API Methods
    func fetchStatus() async { ... }
    func fetchChallenge() async { ... }
    func submitAnswer(challengeId: String, selectedOption: Int) async { ... }
    
    // MARK: - Idle Text
    func startIdleTextCycle() { ... }
    func stopIdleTextCycle() { ... }
}
```

### 4. GhostMatrixModel

```swift
class GhostMatrixModel {
    static let cols = 160
    static let rows = 120
    static let totalPixels = cols * rows  // 19,200
    
    /// Ghost Logo 掩码：true = Logo 像素
    private(set) var ghostMask: [Bool]  // 长度 19,200
    
    /// 当前级别的点亮序列（Fisher-Yates 洗牌后的索引数组）
    private(set) var activationOrder: [Int]
    
    /// 从 160×120 黑白 PNG 加载 ghostMask
    func loadMask(from imageName: String) { ... }
    
    /// Fisher-Yates 洗牌生成新的 activationOrder
    func shuffleActivationOrder(seed: UInt64?) { ... }
    
    /// 根据当前字数计算需要点亮的像素索引集合
    /// pixelCount = wordCount * 19200 / 10000（约每字 2 个像素）
    func getActivePixels(wordCount: Int) -> Set<Int> {
        let count = min(wordCount * Self.totalPixels / 10_000, Self.totalPixels)
        return Set(activationOrder.prefix(count))
    }
    
    /// 判断某个像素索引是否属于 Ghost Logo
    func isGhostPixel(_ index: Int) -> Bool {
        ghostMask[index]
    }
    
    /// 持久化 activationOrder 到 UserDefaults
    func saveActivationOrder() { ... }
    func loadActivationOrder() -> Bool { ... }
}
```

### 5. DotMatrixView（Canvas 渲染）

```swift
struct DotMatrixView: View {
    let activePixels: Set<Int>
    let ghostMask: [Bool]
    let ghostOpacity: Double
    let level: Int
    
    var body: some View {
        ZStack {
            // 底层：模糊光晕（仅绘制已激活像素）
            Canvas { context, size in
                drawPixels(context: context, size: size)
            }
            .blur(radius: 1.5)
            .blendMode(.screen)
            
            // 上层：锐利像素
            Canvas { context, size in
                drawPixels(context: context, size: size)
            }
        }
        .frame(width: 640, height: 480)
        .drawingGroup()
    }
    
    private func drawPixels(context: GraphicsContext, size: CGSize) {
        let pixelSize: CGFloat = 4
        let gap: CGFloat = 0.5
        let cornerRadius: CGFloat = 0.75
        
        for row in 0..<120 {
            for col in 0..<160 {
                let index = row * 160 + col
                let x = CGFloat(col) * pixelSize
                let y = CGFloat(row) * pixelSize
                let rect = CGRect(x: x + gap/2, y: y + gap/2, 
                                  width: pixelSize - gap, height: pixelSize - gap)
                let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
                
                let color: Color
                if activePixels.contains(index) {
                    if ghostMask[index] {
                        // Ghost Logo 像素：高亮绿色
                        color = Color.green.opacity(ghostOpacity)
                    } else {
                        // 背景像素：暗绿色
                        color = Color.green.opacity(0.25)
                    }
                } else {
                    // 未激活：极暗底噪
                    color = Color.gray.opacity(0.04)
                }
                
                context.fill(path, with: .color(color))
            }
        }
    }
}
```

### 6. CRTEffectsView

```swift
struct CRTEffectsView: View {
    var body: some View {
        ZStack {
            // 扫描线
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 3) {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.black.opacity(0.15)))
                }
            }
            
            // 暗角（径向渐变）
            RadialGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                center: .center,
                startRadius: 200,
                endRadius: 400
            )
        }
        .allowsHitTesting(false)
    }
}
```

### 7. ReceiptSlipView

```swift
struct ReceiptSlipView: View {
    let challenge: CalibrationChallenge
    let onSelectOption: (Int) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // 场景描述
            Text(challenge.scenario)
                .font(DS.Typography.mono(12, weight: .regular))
                .foregroundColor(.black)
            
            // 选项按钮
            ForEach(Array(challenge.options.enumerated()), id: \.offset) { index, option in
                Button(action: { onSelectOption(index) }) {
                    Text("[\(Character(UnicodeScalar(65 + index)!))] \(option)")
                        .font(DS.Typography.mono(12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.sm)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.lg)
        .background(Color(red: 0.96, green: 0.94, blue: 0.90))  // 米白色热敏纸
        .cornerRadius(DS.Layout.cornerRadius)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

### 8. Ghost Twin API 端点（GhostypeAPIClient 扩展）

```swift
extension GhostypeAPIClient {
    /// GET /api/v1/ghost-twin/status
    func fetchGhostTwinStatus() async throws -> GhostTwinStatusResponse { ... }
    
    /// GET /api/v1/ghost-twin/challenge
    func fetchCalibrationChallenge() async throws -> CalibrationChallenge { ... }
    
    /// POST /api/v1/ghost-twin/challenge/answer
    func submitCalibrationAnswer(
        challengeId: String, 
        selectedOption: Int
    ) async throws -> CalibrationAnswerResponse { ... }
}
```

## Data Models

### API 响应模型

```swift
// MARK: - Ghost Twin Status
struct GhostTwinStatusResponse: Codable {
    let level: Int
    let total_xp: Int
    let current_level_xp: Int
    let personality_tags: [String]
    let challenges_remaining_today: Int
    let personality_profile_version: Int
}

// MARK: - Calibration Challenge
struct CalibrationChallenge: Codable, Identifiable {
    let id: String              // challenge_id
    let type: ChallengeType     // dilemma / reverse_turing / prediction
    let scenario: String        // 场景描述文本
    let options: [String]       // 2~3 个选项
    let xp_reward: Int          // 该类型的 XP 奖励
    
    enum ChallengeType: String, Codable {
        case dilemma            // 灵魂拷问，500 XP
        case reverseTuring = "reverse_turing"  // 找鬼游戏，300 XP
        case prediction         // 预判赌局，200 XP
    }
}

// MARK: - Calibration Answer Response
struct CalibrationAnswerResponse: Codable {
    let xp_earned: Int
    let new_total_xp: Int
    let new_level: Int
    let ghost_response: String
    let personality_tags_updated: [String]
}
```

### 本地缓存模型

```swift
// UserDefaults keys for Ghost Twin
enum GhostTwinCacheKey: String {
    case level = "ghostTwin.level"
    case totalXP = "ghostTwin.totalXP"
    case currentLevelXP = "ghostTwin.currentLevelXP"
    case personalityTags = "ghostTwin.personalityTags"
    case challengesRemaining = "ghostTwin.challengesRemaining"
    case activationOrder = "ghostTwin.activationOrder"
}
```

### 闲置文案数据

闲置文案按等级分组，存储在本地化系统中（`L.Incubator.idleTexts`），返回 `[String]` 数组。ViewModel 每 8~15 秒随机选取一条，通过 Timer + 逐字显示实现打字机效果。



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Fisher-Yates shuffle produces valid permutation

*For any* call to `shuffleActivationOrder()`, the resulting `activationOrder` array shall be a valid permutation of `0..<19200`: it has exactly 19,200 elements, contains no duplicates, and every element is in the range `[0, 19199]`.

**Validates: Requirements 5.2**

### Property 2: getActivePixels returns correct count with valid indices

*For any* `wordCount` in `0...10000`, `getActivePixels(wordCount:)` shall return a `Set<Int>` where:
- The set size equals `min(wordCount * 19200 / 10000, 19200)`
- Every element in the set is in the range `[0, 19199]`

**Validates: Requirements 5.3**

### Property 3: activationOrder round-trip persistence

*For any* valid `activationOrder` array (a permutation of `0..<19200`), saving it to UserDefaults and then loading it back shall produce an identical array.

**Validates: Requirements 5.4**

### Property 4: ghostOpacity linear mapping

*For any* level in `1...10`, `ghostOpacity` shall equal `Double(level) * 0.1` (i.e., Lv.1 → 0.1, Lv.10 → 1.0).

**Validates: Requirements 3.5, 6.3**

### Property 5: Animation phase selection by level range

*For any* level in `1...10`, the animation phase shall be:
- Lv.1~3 → `.glitch` (幽灵态)
- Lv.4~6 → `.breathing` (呼吸态)
- Lv.7~9 → `.awakening` (觉醒态)
- Lv.10 → `.complete` (完全体)

**Validates: Requirements 6.4**

### Property 6: API model serialization round-trip

*For any* valid `GhostTwinStatusResponse`, `CalibrationChallenge`, or `CalibrationAnswerResponse` instance, encoding to JSON and then decoding back shall produce an equivalent object.

**Validates: Requirements 7.1, 8.2, 8.5**

### Property 7: Cache fallback on API failure

*For any* previously cached Ghost Twin state (level, totalXP, currentLevelXP, personalityTags), when the status API call fails, the ViewModel shall restore state from cache such that all displayed values match the cached values.

**Validates: Requirements 7.5**

### Property 8: Idle text level group selection

*For any* level in `1...10`, the idle text pool returned shall only contain texts belonging to the correct level group:
- Lv.1~3 → group 0 (懵懂)
- Lv.4~6 → group 1 (有个性)
- Lv.7~9 → group 2 (自信)
- Lv.10 → group 3 (完全体)

**Validates: Requirements 10.2**

## Error Handling

| 场景 | 处理策略 |
|------|----------|
| `GET /ghost-twin/status` 失败 | 使用 UserDefaults 缓存的最后已知值，页面正常显示，不弹错误提示 |
| `GET /ghost-twin/challenge` 失败 | 隐藏 ">> INCOMING..." 提示，不影响点阵屏主体显示 |
| `POST /ghost-twin/challenge/answer` 失败 | Receipt_Slip 保持显示，显示重试按钮，不丢失用户选择 |
| 401 Unauthorized | 复用现有 `AuthManager.handleUnauthorized()` 逻辑，弹出重新登录提示 |
| 429 Rate Limit | 显示 "服务繁忙，请稍后再试" |
| Ghost Logo PNG 加载失败 | 使用全空 ghostMask（所有像素为背景像素），页面仍可显示 |
| activationOrder 缓存损坏 | 重新生成新的随机序列 |
| 网络超时 | 使用缓存值，静默失败 |

错误处理遵循现有 `GhostypeError` 枚举模式，通过 `GhostypeAPIClient.performRequest` 统一处理 HTTP 状态码。

## Testing Strategy

### 属性测试（Property-Based Testing）

使用 [swift-testing](https://github.com/apple/swift-testing) + 手动随机生成器实现属性测试。每个属性测试运行至少 100 次迭代。

每个测试用 `// Feature: ghost-twin-incubator, Property N: ...` 注释标注对应的设计属性。

| Property | 测试目标 | 生成策略 |
|----------|----------|----------|
| 1 | `shuffleActivationOrder()` | 多次调用，验证排列有效性 |
| 2 | `getActivePixels(wordCount:)` | 随机 wordCount 0~10000 |
| 3 | activationOrder 持久化 | 随机排列 → save → load → 比较 |
| 4 | `ghostOpacity` | 随机 level 1~10 |
| 5 | 动效阶段选择 | 随机 level 1~10 |
| 6 | API 模型序列化 | 随机生成模型实例 → encode → decode |
| 7 | 缓存回退 | 随机状态 → 写入缓存 → 模拟 API 失败 → 验证 |
| 8 | 闲置文案分组 | 随机 level 1~10 |

### 单元测试（Unit Tests）

单元测试覆盖具体示例和边界情况：

- NavItem `.incubator` 的 icon、title、requiresAuth、badge 值验证
- NavItem.groups 中 `.incubator` 的位置验证
- `getActivePixels(wordCount: 0)` 返回空集
- `getActivePixels(wordCount: 10000)` 返回全部 19,200 个索引
- `ChallengeType` 枚举的 XP 奖励映射（dilemma=500, reverseTuring=300, prediction=200）
- `challengesRemaining == 0` 时 UI 状态为 "NO MORE SIGNALS TODAY"
- ghostMask 从 PNG 加载后长度为 19,200

### 测试文件

```
AIInputMethod/Tests/
├── GhostMatrixModelPropertyTests.swift   # Property 1, 2, 3
├── IncubatorViewModelPropertyTests.swift  # Property 4, 5, 7, 8
├── GhostTwinModelsPropertyTests.swift     # Property 6
└── IncubatorUnitTests.swift               # 单元测试
```
