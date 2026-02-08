//
//  OverlayTestWindow.swift
//  Overlay 动画测试窗口
//

import SwiftUI
import AppKit

// MARK: - Overlay 配置模型

struct OverlayConfig: Codable {
    var glowRadius: Double = 4.0
    var glowBaseOpacity: Double = 0.25
    
    var breathingScale: Double = 1.05
    var breathingOpacityMultiplier: Double = 1.0
    var breathingDuration: Double = 1.3
    
    // 轨道动画参数
    var orbitDuration: Double = 2.8        // 旋转一圈的时间（秒）
    var orbitLineLength: Double = 0.27     // 线段长度（占周长比例 0~1）
    var orbitLineWidth: Double = 2.0       // 线段宽度
    var orbitEdgeOffset: Double = 0.0      // 距离跑道圆边缘的距离
    var orbitBlurRadius: Double = 1.0      // 高斯模糊程度
    
    var commitDriftDistance: Double = 20.0
    var commitDriftDuration: Double = 0.3
    
    static var configFilePath: URL {
        { let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!; let configDir = appSupport.appendingPathComponent("GHOSTYPE"); try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true); return configDir }()
            .appendingPathComponent("OverlayConfig.json")
    }
    
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            try data.write(to: Self.configFilePath)
            print("[OverlayConfig] 配置已保存到: \(Self.configFilePath.path)")
        } catch {
            print("[OverlayConfig] 保存失败: \(error)")
        }
    }
    
    static func load() -> OverlayConfig {
        do {
            let data = try Data(contentsOf: configFilePath)
            let config = try JSONDecoder().decode(OverlayConfig.self, from: data)
            print("[OverlayConfig] 配置已加载")
            return config
        } catch {
            print("[OverlayConfig] 加载失败，使用默认配置")
            return OverlayConfig()
        }
    }
}

// MARK: - 测试窗口控制器

class OverlayTestWindowController: NSWindowController {
    static let shared = OverlayTestWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Overlay 动画测试"
        window.center()
        window.contentView = NSHostingView(rootView: OverlayTestView())
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 测试窗口主视图

struct OverlayTestView: View {
    @State private var config = OverlayConfig.load()
    @State private var currentMode: InputMode = .polish
    @State private var testText: String = "这是一段测试文字"
    @State private var currentGlowMode: TestGlowMode = .static
    
    @State private var commitOffset: CGFloat = 0
    @State private var commitOpacity: Double = 1
    @State private var showBadge: Bool = false
    @State private var showGlow: Bool = true
    @State private var breathScale: CGFloat = 1.0
    @State private var breathOpacity: Double = 0.25
    
    enum TestGlowMode { case breathing, orbiting, `static` }
    
    var body: some View {
        HStack(spacing: 0) {
            previewArea.frame(width: 450)
            Divider()
            ScrollView { controlPanel.padding(20) }.frame(maxWidth: .infinity)
        }
        .frame(minWidth: 900, minHeight: 700)
    }
    
    // MARK: - 预览区域
    
    private var previewArea: some View {
        VStack(spacing: 20) {
            Text("预览").font(.headline).padding(.top, 20)
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)).frame(width: 400, height: 200)
                overlayPreview
            }
            Spacer()
            VStack(spacing: 8) {
                Text("当前模式: \(currentMode.rawValue)").font(.system(size: 14, weight: .medium))
                Text("光晕模式: \(glowModeDescription)").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var overlayPreview: some View {
        let capsuleWidth: CGFloat = 280
        let capsuleHeight: CGFloat = 42
        
        return ZStack {
            if showGlow { glowLayer(capsuleWidth: capsuleWidth, capsuleHeight: capsuleHeight) }
            
            HStack(spacing: 10) {
                Circle().fill(Color.white.opacity(0.3)).frame(width: 22, height: 22)
                Text(testText).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.95)).lineLimit(1)
                Spacer()
                if showBadge {
                    Text(ResultBadge.from(mode: currentMode).text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(ResultBadge.from(mode: currentMode).color))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(width: capsuleWidth)
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    Color.black.opacity(0.3)
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            )
        }
        .offset(y: commitOffset)
        .opacity(commitOpacity)
    }
    
    @ViewBuilder
    private func glowLayer(capsuleWidth: CGFloat, capsuleHeight: CGFloat) -> some View {
        switch currentGlowMode {
        case .breathing:
            Capsule()
                .fill(currentModeColor)
                .frame(width: capsuleWidth + config.glowRadius * 2, height: capsuleHeight + config.glowRadius * 2)
                .blur(radius: config.glowRadius)
                .opacity(breathOpacity)
                .scaleEffect(breathScale)
            
        case .orbiting:
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
            
        case .static:
            Capsule()
                .fill(currentModeColor)
                .frame(width: capsuleWidth + config.glowRadius * 2, height: capsuleHeight + config.glowRadius * 2)
                .blur(radius: config.glowRadius)
                .opacity(config.glowBaseOpacity * 0.6)
        }
    }
    
    private func drawSnakeLine(context: GraphicsContext, centerX: CGFloat, centerY: CGFloat,
                               halfWidth: CGFloat, halfHeight: CGFloat, cornerRadius: CGFloat,
                               headProgress: CGFloat, opacity: Double) {
        let numSegments = 20
        for i in 0..<(numSegments - 1) {
            let t1 = CGFloat(i) / CGFloat(numSegments)
            let t2 = CGFloat(i + 1) / CGFloat(numSegments)
            let progress1 = headProgress - t1 * CGFloat(config.orbitLineLength)
            let progress2 = headProgress - t2 * CGFloat(config.orbitLineLength)
            let norm1 = ((progress1.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
            let norm2 = ((progress2.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
            
            let point1 = pointOnCapsuleEdge(progress: norm1, halfWidth: halfWidth + CGFloat(config.orbitEdgeOffset),
                                           halfHeight: halfHeight + CGFloat(config.orbitEdgeOffset),
                                           cornerRadius: cornerRadius + CGFloat(config.orbitEdgeOffset))
            let point2 = pointOnCapsuleEdge(progress: norm2, halfWidth: halfWidth + CGFloat(config.orbitEdgeOffset),
                                           halfHeight: halfHeight + CGFloat(config.orbitEdgeOffset),
                                           cornerRadius: cornerRadius + CGFloat(config.orbitEdgeOffset))
            
            let segmentOpacity = opacity * (1.0 - Double(t1))
            var path = Path()
            path.move(to: CGPoint(x: centerX + point1.x, y: centerY + point1.y))
            path.addLine(to: CGPoint(x: centerX + point2.x, y: centerY + point2.y))
            
            context.drawLayer { ctx in
                ctx.addFilter(.blur(radius: config.orbitBlurRadius))
                ctx.stroke(path, with: .color(currentModeColor.opacity(segmentOpacity)),
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
    
    // MARK: - 控制面板
    
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            stateControlSection
            Divider()
            breathingSettingsSection
            Divider()
            orbitSettingsSection
            Divider()
            commitSettingsSection
            Divider()
            actionButtonsSection
        }
    }
    
    private var stateControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("状态控制").font(.headline)
            HStack {
                Text("模式:")
                Picker("", selection: $currentMode) {
                    Text("润色").tag(InputMode.polish)
                    Text("翻译").tag(InputMode.translate)
                    Text("随心记").tag(InputMode.memo)
                }.pickerStyle(.segmented).frame(width: 200)
            }
            HStack(spacing: 12) {
                Button("隐藏") { resetAll(); currentGlowMode = .static; showGlow = true }.buttonStyle(.bordered)
                Button("录音中") { resetAll(); currentGlowMode = .breathing; showGlow = true; startBreathing() }.buttonStyle(.borderedProminent)
                Button("处理中") { resetAll(); currentGlowMode = .orbiting; showGlow = true }.buttonStyle(.bordered).tint(.orange)
                Button("上屏") { triggerCommit() }.buttonStyle(.bordered).tint(.purple)
            }
            HStack {
                Text("测试文字:")
                TextField("", text: $testText).textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var breathingSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("呼吸动画（录音时）").font(.headline)
            sliderRow(title: "光晕半径", value: $config.glowRadius, range: 2...20, step: 1)
            sliderRow(title: "基础透明度", value: $config.glowBaseOpacity, range: 0.05...1.0, step: 0.05)
            sliderRow(title: "呼吸缩放", value: $config.breathingScale, range: 1.0...1.3, step: 0.01)
            sliderRow(title: "呼吸透明度倍数", value: $config.breathingOpacityMultiplier, range: 0.5...2.0, step: 0.1)
            sliderRow(title: "呼吸周期(秒)", value: $config.breathingDuration, range: 0.5...3.0, step: 0.1)
            Button("应用呼吸参数") { if currentGlowMode == .breathing { startBreathing() } }
                .buttonStyle(.bordered).disabled(currentGlowMode != .breathing)
        }
    }
    
    private var orbitSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("轨道动画（处理时）").font(.headline)
            sliderRow(title: "旋转周期(秒)", value: $config.orbitDuration, range: 0.5...5.0, step: 0.1)
            sliderRow(title: "线段长度", value: $config.orbitLineLength, range: 0.05...0.3, step: 0.01)
            sliderRow(title: "线段宽度", value: $config.orbitLineWidth, range: 2...20, step: 1)
            sliderRow(title: "距边缘距离", value: $config.orbitEdgeOffset, range: -10...20, step: 1)
            sliderRow(title: "高斯模糊", value: $config.orbitBlurRadius, range: 0...20, step: 1)
        }
    }
    
    private var commitSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("上屏动画").font(.headline)
            sliderRow(title: "漂移距离", value: $config.commitDriftDistance, range: 10...100, step: 5)
            sliderRow(title: "漂移时长(秒)", value: $config.commitDriftDuration, range: 0.1...1.0, step: 0.05)
        }
    }
    
    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(title).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: step).frame(width: 150)
            Text(String(format: "%.2f", value.wrappedValue)).font(.system(size: 12, design: .monospaced)).frame(width: 50, alignment: .trailing)
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button("保存配置") { config.save() }.buttonStyle(.borderedProminent)
            Button("加载配置") { config = OverlayConfig.load() }.buttonStyle(.bordered)
            Button("重置默认") { config = OverlayConfig() }.buttonStyle(.bordered).tint(.red)
            Spacer()
        }
    }
    
    private var glowModeDescription: String {
        switch currentGlowMode {
        case .breathing: return "呼吸"
        case .orbiting: return "轨道"
        case .static: return "静止"
        }
    }
    
    private var currentModeColor: Color {
        switch currentMode {
        case .polish: return ModeColors.polishGreen
        case .translate: return ModeColors.translatePurple
        case .memo: return ModeColors.memoOrange
        }
    }
    
    private func resetAll() {
        withAnimation(.none) {
            commitOffset = 0
            commitOpacity = 1
            showBadge = false
            breathScale = 1.0
            breathOpacity = config.glowBaseOpacity
        }
    }
    
    private func startBreathing() {
        breathScale = 1.0
        breathOpacity = config.glowBaseOpacity
        withAnimation(.easeInOut(duration: config.breathingDuration).repeatForever(autoreverses: true)) {
            breathScale = CGFloat(config.breathingScale)
            breathOpacity = config.glowBaseOpacity * config.breathingOpacityMultiplier
        }
    }
    
    private func triggerCommit() {
        showGlow = false
        withAnimation(.easeOut(duration: config.commitDriftDuration)) {
            commitOffset = -CGFloat(config.commitDriftDistance)
            commitOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + config.commitDriftDuration) {
            resetAll()
            showGlow = true
        }
    }
}

extension NSApplication {
    @objc func showOverlayTestWindow() {
        OverlayTestWindowController.shared.show()
    }
}
