import SwiftUI
import AppKit

// MARK: - OverlayStateManager 单例

class OverlayStateManager: ObservableObject {
    static let shared = OverlayStateManager()
    @Published var phase: OverlayPhase?
    private init() {}
    
    func setRecording(mode: InputMode) {
        DispatchQueue.main.async { self.phase = .recording(mode) }
    }
    func setProcessing(mode: InputMode) {
        DispatchQueue.main.async { self.phase = .processing(mode) }
    }
    func setResult(mode: InputMode, text: String) {
        DispatchQueue.main.async { self.phase = .result(OverlayPhase.ResultInfo(mode: mode, text: text)) }
    }
    func setCommitting(type: OverlayPhase.CommitType) {
        DispatchQueue.main.async { self.phase = .committing(type) }
    }
    func setLoginRequired() {
        DispatchQueue.main.async { self.phase = .loginRequired }
    }
    func hide() {
        DispatchQueue.main.async { self.phase = nil }
    }
}

// MARK: - 动画状态枚举

enum OverlayPhase: Equatable {
    case recording(InputMode)
    case processing(InputMode)
    case result(ResultInfo)
    case committing(CommitType)
    case loginRequired
    
    struct ResultInfo: Equatable {
        let mode: InputMode
        let text: String
    }
    enum CommitType: Equatable {
        case textInput
        case memoSaved
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 模式颜色

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

// MARK: - 动画常量

enum OverlayAnimationConstants {
    static let commitDriftDuration: Double = 0.3
    static let commitDriftDistance: CGFloat = 20
    static var commitCurve: Animation { .easeOut(duration: commitDriftDuration) }
}

// MARK: - 光晕配置

struct GlowConfig {
    var glowRadius: CGFloat = 4.0
    var glowBaseOpacity: Double = 0.25
    var breathingScale: CGFloat = 1.05
    var breathingOpacityMultiplier: Double = 1.0
    var breathingDuration: Double = 1.3
    var orbitDuration: Double = 2.8
    var orbitLineLength: CGFloat = 0.27
    var orbitLineWidth: CGFloat = 2.0
    var orbitEdgeOffset: CGFloat = 0.0
    var orbitBlurRadius: CGFloat = 1.0
    
    static func load() -> GlowConfig {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("GHOSTYPE")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configPath = configDir.appendingPathComponent("OverlayConfig.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return GlowConfig()
        }
        var config = GlowConfig()
        if let v = json["glowRadius"] as? Double { config.glowRadius = CGFloat(v) }
        if let v = json["glowBaseOpacity"] as? Double { config.glowBaseOpacity = v }
        if let v = json["breathingScale"] as? Double { config.breathingScale = CGFloat(v) }
        if let v = json["breathingOpacityMultiplier"] as? Double { config.breathingOpacityMultiplier = v }
        if let v = json["breathingDuration"] as? Double { config.breathingDuration = v }
        if let v = json["orbitDuration"] as? Double { config.orbitDuration = v }
        if let v = json["orbitLineLength"] as? Double { config.orbitLineLength = CGFloat(v) }
        if let v = json["orbitLineWidth"] as? Double { config.orbitLineWidth = CGFloat(v) }
        if let v = json["orbitEdgeOffset"] as? Double { config.orbitEdgeOffset = CGFloat(v) }
        if let v = json["orbitBlurRadius"] as? Double { config.orbitBlurRadius = CGFloat(v) }
        return config
    }
}

// MARK: - 结果 Badge

enum ResultBadge {
    case polished, translated, saved
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

struct ResultBadgeView: View {
    var badge: ResultBadge
    var isVisible: Bool
    var body: some View {
        Text(badge.text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(badge.color))
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .animation(.easeOut(duration: 0.2), value: isVisible)
    }
}

// MARK: - 透明窗口

class TransparentWindowView: NSView {
    override func viewDidMoveToWindow() {
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.hasShadow = false
        super.viewDidMoveToWindow()
    }
}

struct TransparentWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { TransparentWindowView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - 毛玻璃效果

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 主视图

struct OverlayView: View {
    @ObservedObject var speechService: DoubaoSpeechService
    @ObservedObject private var stateManager = OverlayStateManager.shared
    
    @State private var commitOffset: CGFloat = 0
    @State private var commitOpacity: Double = 1
    @State private var showGlow: Bool = true
    
    private let iconSize: CGFloat = 22
    private let horizontalPadding: CGFloat = 14
    private let verticalPadding: CGFloat = 10
    private let spacing: CGFloat = 10
    // 固定的 capsule 高度，不随内容变化
    private let fixedCapsuleHeight: CGFloat = 42
    
    private var screenWidth: CGFloat { NSScreen.main?.frame.width ?? 1440 }
    
    private var capsuleWidth: CGFloat {
        let minWidth = screenWidth * 0.10
        let maxWidth = screenWidth * 0.30
        let text = displayText
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        // 预留 Badge 空间（约 60pt）
        let badgeSpace: CGFloat = showBadge ? 70 : 0
        let contentWidth = iconSize + spacing + textWidth + horizontalPadding * 2 + badgeSpace
        return min(max(contentWidth, minWidth), maxWidth)
    }
    
    private var maxTextWidth: CGFloat { 
        let badgeSpace: CGFloat = showBadge ? 70 : 0
        return capsuleWidth - iconSize - spacing - horizontalPadding * 2 - badgeSpace
    }
    
    var body: some View {
        ZStack {
            if stateManager.phase != nil && showGlow {
                GlowRingView(
                    color: currentModeColor,
                    phase: stateManager.phase,
                    capsuleWidth: capsuleWidth,
                    capsuleHeight: fixedCapsuleHeight
                )
            }
            
            HStack(spacing: spacing) {
                GhostIconView(isRecording: speechService.isRecording)
                    .frame(width: iconSize, height: iconSize)
                textArea
                if let badge = currentResultBadge {
                    ResultBadgeView(badge: badge, isVisible: showBadge)
                        .fixedSize()
                }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(width: capsuleWidth, height: fixedCapsuleHeight)
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    Color.black.opacity(0.7)
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            )
        }
        .offset(y: commitOffset)
        .opacity(commitOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TransparentWindowBackground())
        .onChange(of: stateManager.phase) { oldValue, newValue in
            // 如果从 committing 切换到 recording，立即重置动画状态
            if case .recording = newValue {
                commitOffset = 0
                commitOpacity = 1
                showGlow = true
            }
            switch newValue {
            case .committing(.textInput), .committing(.memoSaved):
                animateCommit()
            default: break
            }
        }
    }
    
    private func animateCommit() {
        showGlow = false
        withAnimation(OverlayAnimationConstants.commitCurve) {
            commitOffset = -OverlayAnimationConstants.commitDriftDistance
            commitOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + OverlayAnimationConstants.commitDriftDuration) {
            stateManager.hide()
            commitOffset = 0
            commitOpacity = 1
            showGlow = true
        }
    }
    
    private var currentModeColor: Color {
        switch stateManager.phase {
        case .recording(let mode), .processing(let mode): return ModeColors.glowColor(for: mode)
        case .result(let info): return ModeColors.glowColor(for: info.mode)
        case .committing(.memoSaved): return ModeColors.memoOrange
        case .committing(.textInput), .loginRequired, .none: return ModeColors.defaultBlue
        }
    }
    
    private var currentResultBadge: ResultBadge? {
        switch stateManager.phase {
        case .result(let info): return ResultBadge.from(mode: info.mode)
        case .committing(.memoSaved): return .saved
        default: return nil
        }
    }
    
    private var showBadge: Bool {
        switch stateManager.phase {
        case .result, .committing(.memoSaved): return true
        default: return false
        }
    }
    
    private var textArea: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 3) {
                Spacer(minLength: 0)
                Text(displayText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.head)
                if speechService.isRecording { CursorView() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 20)
                Rectangle().fill(Color.black)
            }
        )
    }
    
    private var displayText: String {
        // 处理中显示对应文案
        switch stateManager.phase {
        case .processing(let mode):
            switch mode {
            case .polish: return "正在润色…"
            case .translate: return "正在翻译…"
            case .memo: return "正在保存…"
            }
        case .loginRequired:
            return L.Auth.loginRequired
        default:
            break
        }
        
        let text = speechService.transcript
        if text.isEmpty || text == "正在听..." {
            return speechService.isRecording ? "正在聆听…" : "⌥ Space"
        }
        return text
    }
}

// MARK: - 闪烁光标

struct CursorView: View {
    @State private var visible = true
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - 光晕环组件

struct GlowRingView: View {
    var color: Color
    var phase: OverlayPhase?
    var capsuleWidth: CGFloat
    var capsuleHeight: CGFloat
    
    @State private var config = GlowConfig()
    @State private var breathScale: CGFloat = 1.0
    @State private var breathOpacity: Double = 0.25
    
    var body: some View {
        Group {
            switch phase {
            case .recording:
                breathingGlow
            case .processing:
                orbitingGlow
            case .result, .committing, .loginRequired, .none:
                staticGlow
            }
        }
        .animation(.easeInOut(duration: 0.2), value: color)
        .onAppear { config = GlowConfig.load() }
    }
    
    private var breathingGlow: some View {
        Capsule()
            .fill(color)
            .frame(width: capsuleWidth + config.glowRadius * 2, height: capsuleHeight + config.glowRadius * 2)
            .blur(radius: config.glowRadius)
            .opacity(breathOpacity)
            .scaleEffect(breathScale)
            .onAppear { startBreathing() }
    }
    
    private func startBreathing() {
        breathScale = 1.0
        breathOpacity = config.glowBaseOpacity
        withAnimation(.easeInOut(duration: config.breathingDuration).repeatForever(autoreverses: true)) {
            breathScale = config.breathingScale
            breathOpacity = config.glowBaseOpacity * config.breathingOpacityMultiplier
        }
    }
    
    private var orbitingGlow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let centerX = size.width / 2
                let centerY = size.height / 2
                let halfWidth = capsuleWidth / 2
                let halfHeight = capsuleHeight / 2
                let cornerRadius = halfHeight
                
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let progress1 = CGFloat((elapsed / config.orbitDuration).truncatingRemainder(dividingBy: 1.0))
                let progress2 = CGFloat(((elapsed / config.orbitDuration) + 0.5).truncatingRemainder(dividingBy: 1.0))
                
                drawSnakeLine(context: context, centerX: centerX, centerY: centerY,
                             halfWidth: halfWidth, halfHeight: halfHeight, cornerRadius: cornerRadius,
                             headProgress: progress1, opacity: config.glowBaseOpacity)
                drawSnakeLine(context: context, centerX: centerX, centerY: centerY,
                             halfWidth: halfWidth, halfHeight: halfHeight, cornerRadius: cornerRadius,
                             headProgress: progress2, opacity: config.glowBaseOpacity)
            }
        }
        .frame(width: capsuleWidth + 60, height: capsuleHeight + 60)
    }
    
    private func drawSnakeLine(context: GraphicsContext, centerX: CGFloat, centerY: CGFloat,
                               halfWidth: CGFloat, halfHeight: CGFloat, cornerRadius: CGFloat,
                               headProgress: CGFloat, opacity: Double) {
        let numSegments = 20
        for i in 0..<(numSegments - 1) {
            let t1 = CGFloat(i) / CGFloat(numSegments)
            let t2 = CGFloat(i + 1) / CGFloat(numSegments)
            let progress1 = headProgress - t1 * config.orbitLineLength
            let progress2 = headProgress - t2 * config.orbitLineLength
            let norm1 = ((progress1.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
            let norm2 = ((progress2.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
            
            let point1 = pointOnCapsuleEdge(progress: norm1, halfWidth: halfWidth + config.orbitEdgeOffset,
                                           halfHeight: halfHeight + config.orbitEdgeOffset,
                                           cornerRadius: cornerRadius + config.orbitEdgeOffset)
            let point2 = pointOnCapsuleEdge(progress: norm2, halfWidth: halfWidth + config.orbitEdgeOffset,
                                           halfHeight: halfHeight + config.orbitEdgeOffset,
                                           cornerRadius: cornerRadius + config.orbitEdgeOffset)
            
            let segmentOpacity = opacity * (1.0 - Double(t1))
            var path = Path()
            path.move(to: CGPoint(x: centerX + point1.x, y: centerY + point1.y))
            path.addLine(to: CGPoint(x: centerX + point2.x, y: centerY + point2.y))
            
            context.drawLayer { ctx in
                ctx.addFilter(.blur(radius: config.orbitBlurRadius))
                ctx.stroke(path, with: .color(color.opacity(segmentOpacity)),
                          style: StrokeStyle(lineWidth: config.orbitLineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
    
    private func pointOnCapsuleEdge(progress: CGFloat, halfWidth: CGFloat, halfHeight: CGFloat, cornerRadius: CGFloat) -> CGPoint {
        let straightLength = (halfWidth - cornerRadius) * 2
        let curveLength = CGFloat.pi * cornerRadius
        let totalLength = straightLength * 2 + curveLength * 2
        let distance = progress * totalLength
        
        if distance < straightLength {
            return CGPoint(x: -halfWidth + cornerRadius + distance, y: -halfHeight)
        }
        let afterTop = distance - straightLength
        if afterTop < curveLength {
            let angle = -CGFloat.pi / 2 + (afterTop / curveLength) * CGFloat.pi
            return CGPoint(x: halfWidth - cornerRadius + cos(angle) * cornerRadius, y: sin(angle) * cornerRadius)
        }
        let afterRight = afterTop - curveLength
        if afterRight < straightLength {
            return CGPoint(x: halfWidth - cornerRadius - afterRight, y: halfHeight)
        }
        let afterBottom = afterRight - straightLength
        let angle = CGFloat.pi / 2 + (afterBottom / curveLength) * CGFloat.pi
        return CGPoint(x: -halfWidth + cornerRadius + cos(angle) * cornerRadius, y: sin(angle) * cornerRadius)
    }
    
    private var staticGlow: some View {
        Capsule()
            .fill(color)
            .frame(width: capsuleWidth + config.glowRadius * 2, height: capsuleHeight + config.glowRadius * 2)
            .blur(radius: config.glowRadius)
            .opacity(config.glowBaseOpacity * 0.6)
    }
}

// MARK: - 小幽灵图标

struct GhostIconView: View {
    let isRecording: Bool
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        Image(nsImage: loadGhostIcon())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .colorInvert()
            .opacity(0.9)
            .offset(y: floatOffset)
            .onAppear { if isRecording { startAnimation() } }
            .onChange(of: isRecording) { _, rec in
                if rec { startAnimation() } else { stopAnimation() }
            }
    }
    
    private func startAnimation() {
        floatOffset = -1.5
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            floatOffset = 1.5
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.2)) { floatOffset = 0 }
    }
    
    private func loadGhostIcon() -> NSImage {
        if let path = Bundle.main.path(forResource: "GhostIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: path) { return image }
        let devPath = "/Users/gengdawei/ghostype/AIInputMethod/Sources/Resources/GhostIcon.png"
        if let image = NSImage(contentsOfFile: devPath) { return image }
        return NSImage(systemSymbolName: "waveform", accessibilityDescription: nil) ?? NSImage()
    }
}
