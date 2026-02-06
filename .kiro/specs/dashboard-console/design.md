# Design Document: Dashboard Console

## Overview

GhosTYPE Dashboard Console 是一个 macOS 原生 SwiftUI 应用的主控制台界面。采用状态机驱动的架构，将 Onboarding 流程无缝集成到主界面中。核心设计理念：

1. **状态机驱动**: DashboardState 管理 Onboarding 和 Normal 两种状态，控制 UI 展示逻辑
2. **双栏布局**: 固定宽度 Sidebar + 自适应 Content 区域
3. **Glassmorphism 风格**: 使用 NSVisualEffectView 实现毛玻璃材质
4. **Bento Grid**: 便当盒风格卡片布局展示数据
5. **本地优先**: CoreData 持久化，完全离线运行

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      DashboardWindow                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   DashboardView                           │   │
│  │  ┌─────────────┬────────────────────────────────────┐    │   │
│  │  │   Sidebar   │         ContentArea                 │    │   │
│  │  │             │                                     │    │   │
│  │  │  NavItems   │   [OnboardingView]                  │    │   │
│  │  │  - 概览     │        OR                           │    │   │
│  │  │  - 历史库   │   [OverviewPage]                    │    │   │
│  │  │  - 偏好设置 │   [LibraryPage]                     │    │   │
│  │  │             │   [PreferencesPage]                 │    │   │
│  │  │  ─────────  │                                     │    │   │
│  │  │  DeviceInfo │                                     │    │   │
│  │  │  QuotaBar   │                                     │    │   │
│  │  └─────────────┴────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

State Machine:
┌─────────────────┐    onboarding complete    ┌─────────────────┐
│ Onboarding_State│ ─────────────────────────▶│  Normal_State   │
│                 │                            │                 │
│ - Step 1: Hotkey│                            │ - Overview      │
│ - Step 2: Mode  │                            │ - Library       │
│ - Step 3: Perms │                            │ - Preferences   │
└─────────────────┘                            └─────────────────┘
```

### 技术栈

- **UI Framework**: SwiftUI (macOS 13+)
- **Window Management**: NSWindow + NSHostingView
- **Visual Effects**: NSVisualEffectView (.sidebar, .contentBackground)
- **Data Persistence**: CoreData + UserDefaults + Keychain
- **Charts**: Swift Charts (macOS 13+)
- **State Management**: @Observable (macOS 14+) 或 ObservableObject

## Components and Interfaces

### 1. DashboardState (状态机)

```swift
enum DashboardPhase {
    case onboarding(OnboardingStep)
    case normal
}

enum OnboardingStep: Int, CaseIterable {
    case hotkey = 0
    case inputMode = 1
    case permissions = 2
}

@Observable
class DashboardState {
    var phase: DashboardPhase = .onboarding(.hotkey)
    var selectedNavItem: NavItem = .overview
    var isOnboardingComplete: Bool { get }
    
    func completeOnboarding()
    func transitionToNormal()
    func advanceOnboardingStep()
}
```

### 2. DashboardWindow (窗口控制器)

```swift
class DashboardWindowController {
    var window: NSWindow?
    
    func show()
    func hide()
    func toggle()
    func saveWindowFrame()
    func restoreWindowFrame()
}
```

### 3. Sidebar 组件

```swift
enum NavItem: String, CaseIterable, Identifiable {
    case overview = "概览"
    case library = "历史库"
    case preferences = "偏好设置"
    
    var icon: String { ... }  // SF Symbol name
    var id: String { rawValue }
}

struct SidebarView: View {
    @Binding var selectedItem: NavItem
    var isEnabled: Bool
    var deviceId: String
    var quotaPercentage: Double
}
```

### 4. Content Pages

```swift
// 概览页
struct OverviewPage: View {
    var todayStats: TodayStats
    var quotaInfo: QuotaInfo
    var appDistribution: [AppUsage]
    var recentNotes: [UsageRecord]
}

// 历史库页
struct LibraryPage: View {
    @State var searchText: String
    @State var selectedCategory: RecordCategory?
    var records: [UsageRecord]
    var onExport: (UsageRecord) -> URL
}

// 偏好设置页
struct PreferencesPage: View {
    @Binding var launchAtLogin: Bool
    @Binding var soundFeedback: Bool
    @Binding var hotkey: HotkeyConfig
    var aiEngineStatus: AIEngineStatus
}
```

### 5. Bento Card 组件

```swift
struct BentoCard<Content: View>: View {
    var title: String
    var icon: String
    var content: () -> Content
    
    // 16pt corner radius, subtle shadow, hover scale effect
}

struct EnergyRingView: View {
    var usedPercentage: Double  // 0.0 - 1.0
    var warningThreshold: Double = 0.9
}

struct PieChartView: View {
    var data: [AppUsage]
}
```

### 6. Device ID Manager

```swift
class DeviceIdManager {
    static let shared = DeviceIdManager()
    
    var deviceId: String { get }  // Lazy generation + Keychain storage
    
    func generateNewId() -> String
    func resetId()
    func truncatedId(length: Int = 8) -> String
}
```

### 7. Quota Manager

```swift
@Observable
class QuotaManager {
    var usedSeconds: Int
    var resetDate: Date
    
    var usedPercentage: Double { get }
    var remainingSeconds: Int { get }
    
    func recordUsage(seconds: Int)
    func checkAndResetIfNeeded()
}
```

## Data Models

### CoreData Entities

```swift
// UsageRecord Entity
@objc(UsageRecord)
class UsageRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var content: String
    @NSManaged var category: String        // "polish", "translate", "memo", "general"
    @NSManaged var sourceApp: String       // App display name
    @NSManaged var sourceAppBundleId: String
    @NSManaged var timestamp: Date
    @NSManaged var duration: Int32         // seconds
    @NSManaged var deviceId: String
}

// QuotaRecord Entity
@objc(QuotaRecord)
class QuotaRecord: NSManagedObject {
    @NSManaged var deviceId: String
    @NSManaged var usedSeconds: Int32
    @NSManaged var resetDate: Date
    @NSManaged var lastUpdated: Date
}
```

### Value Types

```swift
enum RecordCategory: String, CaseIterable {
    case all = "全部"
    case polish = "润色"
    case translate = "翻译"
    case memo = "随心记"
}

struct TodayStats {
    var characterCount: Int
    var estimatedTimeSaved: TimeInterval  // seconds
}

struct AppUsage: Identifiable {
    var id: String { bundleId }
    var bundleId: String
    var appName: String
    var usageCount: Int
    var percentage: Double
}

struct HotkeyConfig {
    var modifiers: NSEvent.ModifierFlags
    var keyCode: UInt16
    var displayString: String
}

enum AIEngineStatus {
    case online
    case offline
    case checking
}
```

### UserDefaults Keys

```swift
enum UserDefaultsKey: String {
    case isOnboardingComplete = "isOnboardingComplete"
    case launchAtLogin = "launchAtLogin"
    case soundFeedback = "soundFeedback"
    case hotkeyModifiers = "hotkeyModifiers"
    case hotkeyKeyCode = "hotkeyKeyCode"
    case windowFrame = "dashboardWindowFrame"
    case selectedNavItem = "selectedNavItem"
}
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing the acceptance criteria, the following redundancies were identified and consolidated:

- 2.5 and 4.6 are duplicates (sidebar disabled during onboarding) → consolidated into Property 2
- 9.2 and 10.4 are duplicates (quota data fields) → consolidated into example test
- 8.4 and 4.5 overlap (truncated device ID) → consolidated into Property 8

### Properties

**Property 1: State Machine Integrity**
*For any* DashboardState instance, the phase shall be either .onboarding(step) or .normal, and calling completeOnboarding() shall always transition to .normal state regardless of current onboarding step.
**Validates: Requirements 1.1, 1.3**

**Property 2: Onboarding State Disables Navigation**
*For any* DashboardState in Onboarding_State, the sidebar navigation isEnabled flag shall be false, and *for any* DashboardState in Normal_State, the isEnabled flag shall be true.
**Validates: Requirements 2.5, 4.6**

**Property 3: State Persistence Round-Trip**
*For any* DashboardState, saving the state to UserDefaults and then creating a new DashboardState instance shall restore to the same phase (onboarding complete → normal, onboarding incomplete → onboarding).
**Validates: Requirements 1.4, 1.5**

**Property 4: Navigation Selection Updates Content**
*For any* NavItem selection, the content area shall display the corresponding page view (overview → OverviewPage, library → LibraryPage, preferences → PreferencesPage).
**Validates: Requirements 4.2**

**Property 5: NavItem Icon Completeness**
*For any* NavItem case, the icon property shall return a non-empty string that is a valid SF Symbol name.
**Validates: Requirements 4.4, 11.2**

**Property 6: Today Stats Calculation**
*For any* set of UsageRecords with today's date, the TodayStats.characterCount shall equal the sum of all content.count values, and estimatedTimeSaved shall be calculated as characterCount / typingSpeedPerSecond.
**Validates: Requirements 5.2**

**Property 7: Quota Percentage Calculation**
*For any* QuotaManager with usedSeconds and totalSeconds (constant), usedPercentage shall equal usedSeconds / totalSeconds, bounded between 0.0 and 1.0.
**Validates: Requirements 5.3, 9.3**

**Property 8: App Distribution Sum**
*For any* non-empty list of AppUsage, the sum of all percentage values shall equal 1.0 (within floating point tolerance).
**Validates: Requirements 5.4**

**Property 9: Recent Notes Query**
*For any* set of UsageRecords with category "memo", querying recent notes shall return at most 3 records sorted by timestamp in descending order.
**Validates: Requirements 5.5**

**Property 10: Category Filter Correctness**
*For any* RecordCategory filter (except .all) and any set of UsageRecords, the filtered result shall contain only records where record.category equals the filter's rawValue.
**Validates: Requirements 6.3**

**Property 11: Search Filter Correctness**
*For any* non-empty search string and any set of UsageRecords, the filtered result shall contain only records where record.content contains the search string (case-insensitive).
**Validates: Requirements 6.4**

**Property 12: Content Preview Truncation**
*For any* UsageRecord content, the preview shall be truncated to at most 2 lines (approximately 100 characters) with ellipsis if original content is longer.
**Validates: Requirements 6.5**

**Property 13: Export File Content**
*For any* UsageRecord, exporting to .txt file shall create a file containing exactly the record's content string.
**Validates: Requirements 6.6**

**Property 14: Settings Persistence Round-Trip**
*For any* preference setting (launchAtLogin, soundFeedback, hotkey), changing the value and reading from UserDefaults shall return the same value.
**Validates: Requirements 7.5**

**Property 15: Device ID Format**
*For any* generated Device_ID, it shall be a valid UUID string (36 characters, 8-4-4-4-12 format with hyphens).
**Validates: Requirements 8.1**

**Property 16: Device ID Keychain Round-Trip**
*For any* Device_ID, saving to Keychain and reading back shall return the identical string.
**Validates: Requirements 8.2**

**Property 17: Device ID Stability**
*For any* sequence of DeviceIdManager.deviceId reads (without reset), all returned values shall be identical.
**Validates: Requirements 8.5**

**Property 18: Device ID Truncation**
*For any* Device_ID, truncatedId(length: 8) shall return exactly the first 8 characters of the full ID.
**Validates: Requirements 8.4**

**Property 19: Usage Record Device Association**
*For any* newly created UsageRecord, its deviceId field shall equal DeviceIdManager.shared.deviceId.
**Validates: Requirements 8.3**

**Property 20: Quota Usage Accumulation**
*For any* sequence of recordUsage(seconds:) calls, the final usedSeconds shall equal the sum of all recorded seconds.
**Validates: Requirements 9.1**

**Property 21: Window Frame Persistence Round-Trip**
*For any* NSRect window frame, saving to UserDefaults and restoring shall return an equivalent frame (within floating point tolerance).
**Validates: Requirements 12.2**

**Property 22: Responsive Layout Invariant**
*For any* window width W >= 900, the sidebar width shall be exactly 220pt and the content area width shall be W - 220.
**Validates: Requirements 3.2, 3.5**

## Error Handling

### State Machine Errors

| Error Condition | Handling Strategy |
|-----------------|-------------------|
| Invalid state transition | Log warning, maintain current state |
| Corrupted UserDefaults state | Reset to onboarding state |
| Missing permissions after onboarding | Show permission reminder banner |

### Data Persistence Errors

| Error Condition | Handling Strategy |
|-----------------|-------------------|
| CoreData save failure | Retry with exponential backoff, show error toast |
| Keychain access denied | Fall back to UserDefaults for Device_ID (less secure) |
| Data migration failure | Keep old data format, log error for debugging |

### UI Errors

| Error Condition | Handling Strategy |
|-----------------|-------------------|
| Missing app icon for bundleId | Show generic app icon placeholder |
| Empty usage records | Show empty state with helpful message |
| Chart data calculation error | Show "数据加载中..." placeholder |

## Testing Strategy

### Unit Tests

Unit tests focus on specific examples and edge cases:

1. **State Machine Tests**
   - Initial state is onboarding for fresh instance
   - OnboardingStep enum has exactly 3 cases in correct order
   - NavItem enum has exactly 3 cases with correct labels
   - RecordCategory enum has exactly 4 cases

2. **Data Model Tests**
   - UsageRecord entity has all required fields
   - QuotaRecord entity has all required fields
   - Window minimum size is 900x600

3. **Edge Cases**
   - Empty usage records list
   - Device ID generation on first launch
   - Quota at exactly 0% and 100%

### Property-Based Tests

Property tests verify universal properties across randomized inputs. Each test runs minimum 100 iterations.

| Property | Test Description |
|----------|------------------|
| Property 1 | Generate random onboarding steps, verify completeOnboarding always reaches normal |
| Property 3 | Generate random states, verify persistence round-trip |
| Property 6 | Generate random UsageRecords, verify TodayStats calculation |
| Property 7 | Generate random usedSeconds values, verify percentage bounds |
| Property 8 | Generate random AppUsage lists, verify sum equals 1.0 |
| Property 9 | Generate random memo records, verify query returns ≤3 sorted |
| Property 10 | Generate random records and categories, verify filter correctness |
| Property 11 | Generate random records and search strings, verify search correctness |
| Property 14 | Generate random preference values, verify persistence round-trip |
| Property 15 | Generate multiple Device IDs, verify UUID format |
| Property 16 | Generate random UUIDs, verify Keychain round-trip |
| Property 17 | Read Device ID multiple times, verify stability |
| Property 18 | Generate random UUIDs, verify truncation length |
| Property 20 | Generate random usage sequences, verify accumulation |
| Property 21 | Generate random window frames, verify persistence round-trip |
| Property 22 | Generate random window widths ≥900, verify layout invariant |

### Test Configuration

```swift
// Property test configuration
import SwiftCheck  // or swift-testing with custom generators

// Minimum 100 iterations per property
let testConfig = CheckerArguments(maxTestCaseCount: 100)

// Tag format for traceability
// Feature: dashboard-console, Property N: [property description]
```
