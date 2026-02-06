# Design Document: Overlay Animation and Dashboard Enhancement

## Overview

本设计文档定义 GhosTYPE macOS 语音输入法的跑道圆动画系统增强和 Dashboard 功能补全的技术实现方案。

**⚠️ 重要原则：保持现有 OverlayView 结构不变，在其基础上增量添加动画效果。**

核心设计理念：

1. **增量式增强**: 在现有 OverlayView.swift 基础上添加动画状态和效果，不改变现有的 Capsule 形状、布局和样式
2. **状态驱动动画**: 通过 OverlayPhase 枚举管理动画状态（recording, processing, result, committing），在现有视图上叠加动画效果
3. **模式颜色系统**: 基于 InputMode 的颜色映射，为现有跑道圆添加周边光晕效果
4. **增量式 Dashboard 扩展**: 在现有 Dashboard 架构基础上，补全概览页数据卡片和偏好设置项

## 现有 OverlayView 结构（必须保持）

```swift
// 现有结构 - 不要修改
struct OverlayView: View {
    @ObservedObject var speechService: DoubaoSpeechService
    
    var body: some View {
        HStack(spacing: spacing) {
            GhostIconView(isRecording: speechService.isRecording)  // 保持
            textArea                                                // 保持
        }
        .padding(...)
        .frame(width: capsuleWidth)
        .background(
            Capsule()
                .fill(Color(white: 0.10))
                .shadow(...)
        )
        // ↑ 以上全部保持不变
        // ↓ 在此基础上添加新的动画层
    }
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           OverlayView (Enhanced)                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    OverlayAnimationState                             │    │
│  │                                                                      │    │
│  │  ┌───────────┐    ┌────────────┐    ┌────────────┐                  │    │
│  │  │ recording │───▶│ processing │───▶│   result   │                  │    │
│  │  └───────────┘    └────────────┘    └────────────┘                  │    │
│  │       ▲                                    │                         │    │
│  │       │              ┌────────────┐        │                         │    │
│  │       └──────────────│ committing │◀───────┘                         │    │
│  │                      └────────────┘                                  │    │
│  │                            │                                         │    │
│  │                            ▼                                         │    │
│  │                        (隐藏)                                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                   Visual States by Phase                             │    │
│  │                                                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ RECORDING 状态                                               │    │    │
│  │  │  ┌──────────────────────────────────────────────────────┐   │    │    │
│  │  │  │  [👻 小幽灵]  [流式文字区域~~~~~~~~~~~|]              │   │    │    │
│  │  │  │              跑道条形状 (Capsule)                     │   │    │    │
│  │  │  │  ~~~~~~~~~~~~ 光晕环旋转 (颜色=模式色) ~~~~~~~~~~~~   │   │    │    │
│  │  │  └──────────────────────────────────────────────────────┘   │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ PROCESSING 状态 (AI 处理中)                                  │    │    │
│  │  │           ┌─────────┐                                        │    │    │
│  │  │           │  ⚪️    │  圆球形状 (自转)                       │    │    │
│  │  │           │ 旋转中  │                                        │    │    │
│  │  │           └─────────┘                                        │    │    │
│  │  │  ~~~~~~~~~~~~ 光晕环旋转 (颜色=模式色) ~~~~~~~~~~~~          │    │    │
│  │  │  润色=绿色  翻译=紫色  随心记=橙色                           │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ RESULT 状态 (结果展示)                                       │    │    │
│  │  │  ┌──────────────────────────────────────────────────────┐   │    │    │
│  │  │  │  [👻 小幽灵]  [处理后文字]  [Badge: 已润色/已翻译]   │   │    │    │
│  │  │  │              跑道条形状 (Capsule)                     │   │    │    │
│  │  │  │  ~~~~~~~~~~~~ 光晕环静止 (颜色=模式色) ~~~~~~~~~~~~   │   │    │    │
│  │  │  └──────────────────────────────────────────────────────┘   │    │    │
│  │  │                                                              │    │    │
│  │  │  随心记特殊: [Badge: 已保存] → 缩成球 → 飞向菜单栏          │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ COMMITTING 状态 (上屏动画)                                   │    │    │
│  │  │  普通模式: 跑道条向上漂移 + 淡出                             │    │    │
│  │  │  随心记: 圆球沿贝塞尔曲线飞向菜单栏                          │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    Dashboard Enhancement (双栏布局)                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         DashboardView                                │    │
│  │  ┌─────────────┬────────────────────────────────────────────────┐   │    │
│  │  │   Sidebar   │              ContentArea                        │   │    │
│  │  │   (220pt)   │                                                 │   │    │
│  │  │             │   ┌─────────────────────────────────────────┐   │   │    │
│  │  │  NavItems   │   │         OverviewPage (Enhanced)         │   │   │    │
│  │  │  - 概览     │   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │   │    │
│  │  │  - 随心记   │   │  │TodayStats│ │EnergyRing│ │AppPieChart│ │   │   │    │
│  │  │  - 历史库   │   │  │(今日战报)│ │(能量环)  │ │(应用分布) │ │   │   │    │
│  │  │  - 偏好设置 │   │  └──────────┘ └──────────┘ └──────────┘ │   │   │    │
│  │  │             │   └─────────────────────────────────────────┘   │   │    │
│  │  │  ─────────  │                                                 │   │    │
│  │  │  DeviceInfo │   ┌─────────────────────────────────────────┐   │   │    │
│  │  │  QuotaBar   │   │         MemoPage (NEW - Flomo风格)      │   │   │    │
│  │  │             │   │  ┌────────┐ ┌────────┐ ┌────────┐       │   │   │    │
│  │  │             │   │  │ 便签1  │ │ 便签2  │ │ 便签3  │       │   │   │    │
│  │  │             │   │  │ ~~~~   │ │ ~~~~   │ │ ~~~~   │       │   │   │    │
│  │  │             │   │  │ 时间   │ │ 时间   │ │ 时间   │       │   │   │    │
│  │  │             │   │  └────────┘ └────────┘ └────────┘       │   │   │    │
│  │  │             │   │  ┌────────┐ ┌────────┐                  │   │   │    │
│  │  │             │   │  │ 便签4  │ │ 便签5  │  瀑布流卡片布局  │   │   │    │
│  │  │             │   │  └────────┘ └────────┘                  │   │   │    │
│  │  │             │   └─────────────────────────────────────────┘   │   │    │
│  │  │             │                                                 │   │    │
│  │  │             │   ┌─────────────────────────────────────────┐   │   │    │
│  │  │             │   │       PreferencesPage (Enhanced)        │   │   │    │
│  │  │             │   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │   │    │
│  │  │             │   │  │LaunchAt  │ │HotkeyConf│ │Modifier  │ │   │   │    │
│  │  │             │   │  │Login     │ │(主触发键)│ │Keys      │ │   │   │    │
│  │  │             │   │  └──────────┘ └──────────┘ └──────────┘ │   │   │    │
│  │  │             │   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │   │    │
│  │  │             │   │  │AIPolish  │ │Threshold │ │Prompt    │ │   │   │    │
│  │  │             │   │  │Toggle    │ │(润色阈值)│ │Editor    │ │   │   │    │
│  │  │             │   │  └──────────┘ └──────────┘ └──────────┘ │   │   │    │
│  │  │             │   └─────────────────────────────────────────┘   │   │    │
│  │  └─────────────┴────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 技术栈

- **UI Framework**: SwiftUI (macOS 13+)
- **Animation**: SwiftUI Animation, Core Animation (CADisplayLink for glow rotation)
- **State Management**: @Observable (macOS 14+) / ObservableObject
- **Data Persistence**: UserDefaults (AppSettings), CoreData (UsageRecord)
- **Launch at Login**: ServiceManagement framework (SMAppService)

## Components and Interfaces

### 1. OverlayAnimationState (动画状态机)

```swift
/// 跑道圆动画状态枚举
/// 注意：没有 idle 状态，因为用户按下按键时直接进入 recording
enum OverlayAnimationPhase: Equatable {
    case recording(InputMode)    // 录音中，携带当前模式
    case processing(InputMode)   // AI 处理中
    case result(ResultInfo)      // 结果展示
    case committing(CommitType)  // 上屏/保存动画中
    
    struct ResultInfo: Equatable {
        let mode: InputMode
        let text: String
    }
    
    enum CommitType: Equatable {
        case textInput   // 普通上屏（向上漂移）
        case memoSaved   // 随心记保存（飞向菜单栏）
    }
}

/// 结果 Badge 类型
enum ResultBadge {
    case polished    // 已润色
    case translated  // 已翻译
    case saved       // 已保存 (随心记专用)
    
    var text: String {
        switch self {
        case .polished: return "已润色"
        case .translated: return "已翻译"
        case .saved: return "已保存"
        }
    }
    
    var color: Color {
        switch self {
        case .polished: return ModeColors.polishGreen
        case .translated: return ModeColors.translatePurple
        case .saved: return ModeColors.memoOrange
        }
    }
    
    static func from(mode: InputMode) -> ResultBadge {
        switch mode {
        case .polish: return .polished
        case .translate: return .translated
        case .memo: return .saved
        }
    }
}

/// 动画状态管理器
@Observable
class OverlayAnimationState {
    var phase: OverlayAnimationPhase?  // nil 表示隐藏状态
    var transcript: String = ""
    var processedText: String = ""
    
    // 动画控制
    var glowRotationAngle: Double = 0
    var sphereRotationAngle: Double = 0
    var commitOffset: CGPoint = .zero
    var commitOpacity: Double = 1.0
    
    // 当前模式（从 phase 提取）
    var currentMode: InputMode? {
        switch phase {
        case .recording(let mode): return mode
        case .processing(let mode): return mode
        case .result(let info): return info.mode
        case .committing: return nil
        case .none: return nil
        }
    }
    
    // 状态转换方法
    func startRecording(mode: InputMode) {
        phase = .recording(mode)
        startGlowRotation()
    }
    
    func startProcessing() {
        guard case .recording(let mode) = phase else { return }
        phase = .processing(mode)
        startSphereRotation()
    }
    
    func showResult(text: String) {
        guard case .processing(let mode) = phase else { return }
        processedText = text
        phase = .result(OverlayAnimationPhase.ResultInfo(mode: mode, text: text))
        stopGlowRotation()
    }
    
    func commitText() {
        guard case .result(let info) = phase else { return }
        if info.mode == .memo {
            phase = .committing(.memoSaved)
            animateFlyToMenuBar()
        } else {
            phase = .committing(.textInput)
            animateDriftUp()
        }
    }
    
    func hide() {
        phase = nil
        reset()
    }
    
    private func reset() {
        transcript = ""
        processedText = ""
        glowRotationAngle = 0
        sphereRotationAngle = 0
        commitOffset = .zero
        commitOpacity = 1.0
    }
}
```

### 2. GlowRingView (光晕环组件)

```swift
/// 围绕跑道圆旋转的光晕效果
struct GlowRingView: View {
    var color: Color
    var isRotating: Bool
    var rotationAngle: Double
    
    // 光晕参数
    private let glowRadius: CGFloat = 8
    private let rotationDuration: Double = 2.0  // 2秒一圈
}

/// 模式颜色映射
extension InputMode {
    var glowColor: Color {
        switch self {
        case .polish: return Color(hex: "#34C759")    // 绿色
        case .translate: return Color(hex: "#AF52DE") // 紫色
        case .memo: return Color(hex: "#FF9500")      // 橙色
        }
    }
    
    static var defaultGlowColor: Color {
        return Color(hex: "#007AFF")  // 蓝色
    }
}
```

### 3. MorphingOverlayShape (形变形状)

```swift
/// 支持跑道条和圆球之间形变的形状
struct MorphingOverlayShape: Shape {
    var morphProgress: CGFloat  // 0 = 跑道条, 1 = 圆球
    
    func path(in rect: CGRect) -> Path {
        // 使用 animatableData 实现平滑形变
    }
    
    var animatableData: CGFloat {
        get { morphProgress }
        set { morphProgress = newValue }
    }
}
```

### 4. Enhanced OverlayView

```swift
struct OverlayView: View {
    @ObservedObject var speechService: DoubaoSpeechService
    @State private var animationState = OverlayAnimationState()
    
    // 形变进度 (0 = capsule, 1 = sphere)
    @State private var morphProgress: CGFloat = 0
    
    // 光晕旋转
    @State private var glowRotation: Double = 0
    
    // 上屏动画
    @State private var commitOffset: CGFloat = 0
    @State private var commitOpacity: Double = 1
    
    var body: some View {
        ZStack {
            // 光晕层
            GlowRingView(
                color: modeColor,
                isRotating: animationState.phase == .recording || 
                           animationState.phase == .processing,
                rotationAngle: glowRotation
            )
            
            // 主体形状层
            MorphingOverlayShape(morphProgress: morphProgress)
                .fill(Color(white: 0.10))
            
            // 内容层
            overlayContent
        }
        .offset(y: commitOffset)
        .opacity(commitOpacity)
    }
}
```

### 5. SavedBadgeView (已保存提示)

```swift
/// 随心记保存完成提示
struct SavedBadgeView: View {
    var isVisible: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("已保存")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
    }
}
```

### 6. MemoPage (随心记页面 - Flomo 风格)

```swift
/// 随心记页面 - Flomo 风格瀑布流卡片布局
struct MemoPage: View {
    @State private var memos: [UsageRecord] = []
    @State private var searchText: String = ""
    @State private var selectedMemo: UsageRecord?
    @State private var isLoading = false
    
    // 瀑布流列数
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部：标题 + 搜索
            memoHeader
            
            // 瀑布流卡片区
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredMemos, id: \.id) { memo in
                        MemoCard(memo: memo, isSelected: selectedMemo?.id == memo.id)
                            .onTapGesture { selectedMemo = memo }
                    }
                }
                .padding(24)
            }
        }
    }
    
    private var memoHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("随心记")
                    .font(.system(size: 28, weight: .bold))
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                    Text("\(memos.count) 条笔记")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 14))
            }
            
            Spacer()
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索笔记...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .frame(width: 200)
        }
        .padding(24)
    }
}

/// 单个便签卡片 - Flomo 风格
struct MemoCard: View {
    var memo: UsageRecord
    var isSelected: Bool
    
    // 便签颜色池
    private static let cardColors: [Color] = [
        Color(hex: "#FFF9C4"),  // 浅黄
        Color(hex: "#FFECB3"),  // 淡橙
        Color(hex: "#FFE0B2"),  // 浅橙
        Color(hex: "#F8BBD9"),  // 浅粉
        Color(hex: "#E1BEE7"),  // 淡紫
        Color(hex: "#C8E6C9"),  // 浅绿
        Color(hex: "#B3E5FC"),  // 浅蓝
    ]
    
    private var cardColor: Color {
        // 基于 memo id 的 hash 选择颜色，保证同一条笔记颜色一致
        let index = abs(memo.id.hashValue) % Self.cardColors.count
        return Self.cardColors[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 内容
            Text(memo.content)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.85))
                .lineLimit(nil)  // 不限制行数，自然换行
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 8)
            
            // 底部：时间戳
            HStack {
                Text(formatDate(memo.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.5))
                
                Spacer()
                
                // 更多操作按钮
                Menu {
                    Button("复制", action: { copyToClipboard(memo.content) })
                    Button("删除", role: .destructive, action: { deleteMemo(memo) })
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.black.opacity(0.4))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(16)
        .background(cardColor)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
```

### 7. Updated NavItem (新增随心记)

```swift
/// 导航项枚举 - 新增随心记
enum NavItem: String, CaseIterable, Identifiable {
    case overview = "概览"
    case memo = "随心记"      // NEW
    case library = "历史库"
    case preferences = "偏好设置"
    
    var icon: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .memo: return "note.text"           // NEW
        case .library: return "books.vertical"
        case .preferences: return "gearshape"
        }
    }
    
    var id: String { rawValue }
}
```

### 8. Enhanced PreferencesPage

```swift
struct PreferencesPage: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 通用设置
                generalSection
                
                // 快捷键设置
                hotkeySection
                
                // 模式修饰键设置
                modifierKeysSection
                
                // AI 润色设置
                aiPolishSection
                
                // Prompt 编辑器
                promptEditorSection
                
                // AI 引擎状态
                aiEngineSection
            }
            .padding(32)
        }
    }
}
```

### 8. ModifierKeyPicker (修饰键选择器)

```swift
/// 修饰键选择器组件
struct ModifierKeyPicker: View {
    var title: String
    @Binding var selectedModifier: NSEvent.ModifierFlags
    var excludedModifier: NSEvent.ModifierFlags?  // 排除已被其他模式使用的修饰键
    
    private let availableModifiers: [(NSEvent.ModifierFlags, String)] = [
        (.shift, "⇧ Shift"),
        (.command, "⌘ Command"),
        (.control, "⌃ Control"),
        (.option, "⌥ Option")
    ]
}
```

### 9. PolishThresholdSetting (润色阈值设置)

```swift
/// 自动润色长度阈值设置
struct PolishThresholdSetting: View {
    @Binding var threshold: Int
    
    var body: some View {
        HStack {
            Text("自动润色阈值")
            Spacer()
            Stepper(value: $threshold, in: 5...100, step: 5) {
                Text("\(threshold) 字符")
                    .monospacedDigit()
            }
        }
    }
}
```

### 10. PromptEditorView (Prompt 编辑器)

```swift
/// 自定义 Prompt 编辑器
struct PromptEditorView: View {
    @Binding var prompt: String
    var defaultPrompt: String
    var title: String
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(title, isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $prompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 120)
                    .border(Color.gray.opacity(0.3))
                
                HStack {
                    Button("恢复默认") {
                        prompt = defaultPrompt
                    }
                    .disabled(prompt == defaultPrompt)
                    
                    Spacer()
                    
                    Text("\(prompt.count) 字符")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

## Data Models

### AppSettings Extensions

```swift
extension AppSettings {
    // MARK: - 新增设置项
    
    /// 自动润色长度阈值（默认 20 字符）
    @Published var polishThreshold: Int {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - UserDefaults Keys (新增)
    
    private enum Keys {
        // ... 现有 keys ...
        static let polishThreshold = "polishThreshold"
    }
    
    // MARK: - 默认值
    
    static let defaultPolishThreshold = 20
}
```

### Animation Constants

```swift
/// 动画常量
enum OverlayAnimationConstants {
    // 时长
    static let morphDuration: Double = 0.3
    static let glowRotationDuration: Double = 2.0
    static let commitDriftDuration: Double = 0.4
    static let memoFlyDuration: Double = 0.5
    static let colorTransitionDuration: Double = 0.2
    
    // 距离
    static let commitDriftDistance: CGFloat = 50
    static let ghostFloatDistance: CGFloat = 3
    
    // 曲线
    static let morphCurve: Animation = .easeInOut(duration: morphDuration)
    static let commitCurve: Animation = .easeOut(duration: commitDriftDuration)
    static let memoFlyCurve: Animation = .easeInOut(duration: memoFlyDuration)
}
```

### Mode Colors

```swift
/// 模式颜色定义
enum ModeColors {
    static let defaultBlue = Color(hex: "#007AFF")
    static let polishGreen = Color(hex: "#34C759")
    static let translatePurple = Color(hex: "#AF52DE")
    static let memoOrange = Color(hex: "#FF9500")
    
    static func glowColor(for mode: InputMode?) -> Color {
        guard let mode = mode else { return defaultBlue }
        switch mode {
        case .polish: return polishGreen
        case .translate: return translatePurple
        case .memo: return memoOrange
        }
    }
}
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Animation State Machine Transitions

*For any* OverlayAnimationState instance and any valid state transition sequence (idle → recording → processing → result → committing → idle), calling the corresponding transition method shall result in the expected target state.

**Validates: Requirements 1.4, 1.5, 1.6, 1.7**

### Property 2: Saved Badge Mode Exclusivity

*For any* InputMode, the "已保存" badge visibility shall be true only when the mode is .memo and a save operation completes. For all other modes (.polish, .translate), the badge shall never be visible.

**Validates: Requirements 6.7**

### Property 3: Mode Color Mapping Consistency

*For any* InputMode value, the glowColor property shall return a consistent, non-nil Color value:
- .polish → green (#34C759)
- .translate → purple (#AF52DE)  
- .memo → orange (#FF9500)
- nil/default → blue (#007AFF)

**Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.6**

### Property 4: Today Stats Character Count Calculation

*For any* set of UsageRecords with today's date, the TodayStats.characterCount shall equal the sum of all record.content.count values. The estimatedTimeSaved shall equal characterCount / 60.0 (seconds).

**Validates: Requirements 9.2, 9.3**

### Property 5: Energy Ring Percentage Bounds

*For any* QuotaManager with usedSeconds >= 0 and totalSeconds > 0, the usedPercentage shall be bounded between 0.0 and 1.0 inclusive.

**Validates: Requirements 10.2, 10.3**

### Property 6: App Distribution Top 5 Grouping

*For any* non-empty list of AppUsage records, the pie chart data shall contain at most 6 entries (top 5 apps + "其他" group). The sum of all percentages shall equal 1.0 (within floating point tolerance).

**Validates: Requirements 11.4**

### Property 7: Memo Section Filtering

*For any* set of UsageRecords, the MemoStickySection shall display only records where category == "memo", sorted by timestamp descending, limited to 5 entries.

**Validates: Requirements 12.2, 12.3**

### Property 8: Settings Persistence Round-Trip

*For any* AppSettings property (launchAtLogin, enableAIPolish, polishThreshold, polishPrompt, translateModifier, memoModifier), saving to UserDefaults and reading back shall return the identical value.

**Validates: Requirements 13.4, 16.4, 17.6, 18.4**

### Property 9: Modifier Key Conflict Prevention

*For any* configuration of translateModifier and memoModifier, the two values shall never be equal. The UI shall prevent selecting a modifier that is already in use by the other mode.

**Validates: Requirements 15.5**

### Property 10: Polish Threshold Comparison

*For any* transcription text and polishThreshold value, AI polishing shall be applied if and only if:
1. enableAIPolish is true, AND
2. text.count >= polishThreshold

**Validates: Requirements 17.4, 17.5**

### Property 11: Hotkey Display Format

*For any* NSEvent.ModifierFlags value, the formatted display string shall contain the correct symbol(s):
- .control → "⌃"
- .option → "⌥"
- .shift → "⇧"
- .command → "⌘"

**Validates: Requirements 14.6**

### Property 12: Prompt Non-Empty Validation

*For any* prompt editor save operation, the system shall reject empty strings and maintain the previous valid value.

**Validates: Requirements 18.5, 18.6**

## Error Handling

### Animation Errors

| Error Condition | Handling Strategy |
|-----------------|-------------------|
| Invalid state transition | Log warning, maintain current state |
| Animation interrupted | Complete current animation before starting new one |
| Glow rotation timer failure | Fall back to static glow display |

### Settings Errors

| Error Condition | Handling Strategy |
|-----------------|-------------------|
| UserDefaults save failure | Retry once, log error if persistent |
| Invalid modifier key selection | Revert to previous valid selection |
| Empty prompt submission | Show error message, prevent save |
| Login Items registration failure | Show system preferences prompt |

### Resource Loading Errors

| Error Condition | Handling Strategy |
|-----------------|-------------------|
| GhostIcon.png not found | Fall back to SF Symbol "waveform" |
| Lottie animation load failure | Use SwiftUI native animation fallback |

## Testing Strategy

### Unit Tests

Unit tests focus on specific examples and edge cases:

1. **Animation State Machine Tests**
   - Initial state is .idle
   - OverlayAnimationPhase enum has exactly 5 cases
   - State transitions follow expected sequence

2. **Mode Color Tests**
   - Each InputMode returns correct hex color
   - Default color is blue when mode is nil

3. **Settings Tests**
   - Default polishThreshold is 20
   - Default prompts are non-empty
   - Modifier keys have valid defaults

4. **Edge Cases**
   - Empty usage records → TodayStats shows 0
   - Single app usage → No "其他" group in pie chart
   - Threshold at boundary values (5, 100)

### Property-Based Tests

Property tests verify universal properties across randomized inputs. Each test runs minimum 100 iterations.

| Property | Test Description |
|----------|------------------|
| Property 1 | Generate random state transition sequences, verify final state |
| Property 2 | Generate random InputMode values, verify badge visibility |
| Property 3 | Generate all InputMode cases, verify color mapping |
| Property 4 | Generate random UsageRecords, verify stats calculation |
| Property 5 | Generate random usedSeconds values, verify percentage bounds |
| Property 6 | Generate random AppUsage lists, verify grouping and sum |
| Property 7 | Generate random UsageRecords with mixed categories, verify filtering |
| Property 8 | Generate random settings values, verify persistence round-trip |
| Property 9 | Generate random modifier pairs, verify no conflicts |
| Property 10 | Generate random text lengths and thresholds, verify comparison |
| Property 11 | Generate random ModifierFlags combinations, verify format |
| Property 12 | Generate random strings including empty, verify validation |

### Test Configuration

```swift
// Property test configuration
import SwiftCheck  // or swift-testing with custom generators

// Minimum 100 iterations per property
let testConfig = CheckerArguments(maxTestCaseCount: 100)

// Tag format for traceability
// Feature: overlay-animation-and-dashboard-enhancement, Property N: [property description]
```

### Integration Tests

1. **Overlay Animation Flow**
   - Test complete recording → processing → result → commit flow
   - Test memo save animation triggers correctly

2. **Dashboard Data Flow**
   - Test OverviewPage loads data from StatsCalculator
   - Test PreferencesPage persists changes to AppSettings

3. **Settings Synchronization**
   - Test hotkey changes take effect immediately
   - Test modifier key changes update InputMode detection
