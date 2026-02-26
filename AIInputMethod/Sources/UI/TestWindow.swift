import SwiftUI
import AppKit

// MARK: - Overlay 尺寸调试窗口

/// 预览区域完全复用 OverlayView 的布局逻辑，保证所见即所得
struct OverlaySizeTestView: View {
    @State private var sizeConfig = OverlaySizeConfig.load()
    @State private var testText: String = "这是一段测试文字用来预览宽度"
    @State private var showBadge: Bool = true
    @State private var currentMode: InputMode = .polish
    
    var body: some View {
        VStack(spacing: 0) {
            previewArea
            Divider()
            ScrollView {
                controlPanel.padding(16)
            }
        }
        .frame(minWidth: 520, minHeight: 620)
    }
    
    // MARK: - 预览区域（深色背景模拟桌面）
    
    private var previewArea: some View {
        VStack(spacing: 12) {
            Text("Overlay Preview").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 100)
                
                // 完全复用 OverlayView 的 capsule 布局
                overlayCapsule
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                Text("chars: \(displayText.count)")
                Text("width: \(Int(previewCapsuleWidth))")
                Text("min: \(Int(dynamicMinWidth))")
                Text("max: \(Int(dynamicMaxWidth))")
                Text("h: \(Int(sizeConfig.capsuleHeight))")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Capsule 布局（与 OverlayView 完全一致）
    
    /// 与 OverlayView.dynamicMinWidth 完全一致
    private var dynamicMinWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: sizeConfig.fontSize, weight: .medium)
        let listeningText = L.Overlay.listening
        let textWidth = (listeningText as NSString).size(withAttributes: [.font: font]).width
        return sizeConfig.iconSize + sizeConfig.spacing + textWidth + sizeConfig.horizontalPadding * 2 + sizeConfig.minWidthExtraPadding
    }
    
    /// 与 OverlayView.dynamicMaxWidth 完全一致
    private var dynamicMaxWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: sizeConfig.fontSize, weight: .medium)
        let sampleChar = String(repeating: "M", count: sizeConfig.maxCharacters)
        let textWidth = (sampleChar as NSString).size(withAttributes: [.font: font]).width
        return sizeConfig.iconSize + sizeConfig.spacing + textWidth + sizeConfig.horizontalPadding * 2 + sizeConfig.badgeSpace
    }
    
    /// 与 OverlayView.capsuleWidth 完全一致
    private var previewCapsuleWidth: CGFloat {
        let text = displayText
        let font = NSFont.systemFont(ofSize: sizeConfig.fontSize, weight: .medium)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let badgeSpace: CGFloat = showBadge ? sizeConfig.badgeSpace : 0
        let contentWidth = sizeConfig.iconSize + sizeConfig.spacing + textWidth + sizeConfig.horizontalPadding * 2 + badgeSpace
        return min(max(contentWidth, dynamicMinWidth), dynamicMaxWidth)
    }
    
    private var displayText: String {
        testText.isEmpty ? L.Overlay.listening : testText
    }
    
    /// 与 OverlayView.body 的 capsule 部分完全一致
    private var overlayCapsule: some View {
        HStack(spacing: sizeConfig.spacing) {
            // 图标 — 与 GhostIconView 同尺寸
            GhostIconView(isRecording: false)
                .frame(width: sizeConfig.iconSize, height: sizeConfig.iconSize)
            
            // 文字区域 — 与 OverlayView.textArea 完全一致
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    Spacer(minLength: 0)
                    Text(displayText)
                        .font(.system(size: sizeConfig.fontSize, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 20)
                    Rectangle().fill(Color.black)
                }
            )
            
            // Badge — 与 ResultBadgeView 完全一致
            if showBadge {
                ResultBadgeView(badge: ResultBadge.from(mode: currentMode), isVisible: true)
                    .fixedSize()
            }
        }
        .padding(.horizontal, sizeConfig.horizontalPadding)
        .frame(width: previewCapsuleWidth, height: sizeConfig.capsuleHeight)
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
    
    // MARK: - 控制面板
    
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 预览设置
            GroupBox("Preview Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text:").frame(width: 80, alignment: .leading)
                        TextField("", text: $testText).textFieldStyle(.roundedBorder)
                    }
                    HStack(spacing: 8) {
                        Text("Quick:").frame(width: 80, alignment: .leading)
                        Button("Empty") { testText = "" }.buttonStyle(.bordered).controlSize(.small)
                        Button("Short") { testText = "你好" }.buttonStyle(.bordered).controlSize(.small)
                        Button("Medium") { testText = "这是一段测试文字用来预览" }.buttonStyle(.bordered).controlSize(.small)
                        Button("Long") { testText = String(repeating: "测试文字", count: 10) }.buttonStyle(.bordered).controlSize(.small)
                    }
                    HStack {
                        Text("Mode:").frame(width: 80, alignment: .leading)
                        Picker("", selection: $currentMode) {
                            Text("Polish").tag(InputMode.polish)
                            Text("Translate").tag(InputMode.translate)
                            Text("Memo").tag(InputMode.memo)
                        }.pickerStyle(.segmented).frame(width: 240)
                    }
                    HStack {
                        Text("Badge:").frame(width: 80, alignment: .leading)
                        Toggle("Show", isOn: $showBadge)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // 尺寸参数
            GroupBox("Size Config") {
                VStack(spacing: 6) {
                    sizeSlider("Extra Padding", value: $sizeConfig.minWidthExtraPadding, range: 0...100)
                    intSlider("Max Chars", value: $sizeConfig.maxCharacters, range: 10...200)
                    sizeSlider("Height", value: $sizeConfig.capsuleHeight, range: 28...80)
                    sizeSlider("Icon Size", value: $sizeConfig.iconSize, range: 12...40)
                    sizeSlider("Spacing", value: $sizeConfig.spacing, range: 0...30)
                    sizeSlider("H Padding", value: $sizeConfig.horizontalPadding, range: 4...40)
                    sizeSlider("Badge Space", value: $sizeConfig.badgeSpace, range: 20...150)
                    sizeSlider("Font Size", value: $sizeConfig.fontSize, range: 10...24)
                }
                .padding(.vertical, 4)
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("Save") { sizeConfig.save() }.buttonStyle(.borderedProminent)
                Button("Reset") { sizeConfig = OverlaySizeConfig(); sizeConfig.save() }.buttonStyle(.bordered)
                Button("Reload") { sizeConfig = OverlaySizeConfig.load() }.buttonStyle(.bordered)
                Spacer()
            }
        }
    }
    
    // MARK: - Slider helpers
    
    private func sizeSlider(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).frame(width: 90, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.0f", value.wrappedValue))
                .font(.system(size: 11, design: .monospaced)).frame(width: 30)
        }
    }
    
    private func intSlider(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        let floatBinding = Binding<CGFloat>(
            get: { CGFloat(value.wrappedValue) },
            set: { value.wrappedValue = Int($0) }
        )
        return HStack {
            Text(label).font(.system(size: 11)).frame(width: 90, alignment: .leading)
            Slider(value: floatBinding, in: CGFloat(range.lowerBound)...CGFloat(range.upperBound), step: 1)
            Text("\(value.wrappedValue)")
                .font(.system(size: 11, design: .monospaced)).frame(width: 30)
        }
    }
}

// MARK: - Window Controller

class OverlaySizeTestWindowController: NSWindowController {
    static let shared = OverlaySizeTestWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Overlay Size Debug"
        window.center()
        window.contentView = NSHostingView(rootView: OverlaySizeTestView())
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
