import SwiftUI
import Carbon
import AppKit

// 用户设置
class AppSettings: ObservableObject {
    @Published var hotkeyModifiers: NSEvent.ModifierFlags = .option
    @Published var hotkeyKeyCode: UInt16 = 49 // Space
    @Published var hotkeyDisplay: String = "⌥ Space"
    @Published var autoStartOnFocus: Bool = false
    
    static let shared = AppSettings()
}

struct OnboardingWindow: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings = AppSettings.shared
    @State private var currentStep = 0
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .windowBackgroundColor).opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部应用名称
                HStack {
                    Text("GhosTYPE")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(currentStep + 1) / 3")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // 内容区域
                Group {
                    switch currentStep {
                    case 0:
                        Step1HotkeyView(settings: settings, onNext: { withAnimation(.easeInOut(duration: 0.3)) { currentStep = 1 } })
                    case 1:
                        Step2AutoModeView(settings: settings, onNext: { withAnimation(.easeInOut(duration: 0.3)) { currentStep = 2 } }, onBack: { withAnimation(.easeInOut(duration: 0.3)) { currentStep = 0 } })
                    default:
                        Step3PermissionsView(permissionManager: permissionManager, onComplete: onComplete, onBack: { withAnimation(.easeInOut(duration: 0.3)) { currentStep = 1 } })
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(width: 420, height: 480)
    }
}

// MARK: - Step 1: 快捷键设置
struct Step1HotkeyView: View {
    @ObservedObject var settings: AppSettings
    var onNext: () -> Void
    
    @State private var isRecording = false
    @State private var iconScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 图标区域
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.15), .blue.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "keyboard")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.blue)
                    .scaleEffect(iconScale)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    iconScale = 1.05
                }
            }
            
            Text("设置快捷键")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 24)
            
            Text("按住快捷键说话，松开完成输入")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            // 快捷键录入
            VStack(spacing: 8) {
                HotkeyRecorderView(
                    isRecording: $isRecording,
                    hotkeyDisplay: $settings.hotkeyDisplay,
                    onRecorded: { modifiers, keyCode, display in
                        settings.hotkeyModifiers = modifiers
                        settings.hotkeyKeyCode = keyCode
                        settings.hotkeyDisplay = display
                    }
                )
                .frame(width: 180, height: 44)
                
                Text(isRecording ? "按下快捷键组合..." : "点击修改")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.top, 32)
            
            Spacer()
            
            // 底部按钮
            Button(action: onNext) {
                Text("下一步")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal, 48)
            .padding(.bottom, 32)
        }
    }
}

// 快捷键录入视图
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var hotkeyDisplay: String
    var onRecorded: (NSEvent.ModifierFlags, UInt16, String) -> Void
    
    func makeNSView(context: Context) -> HotkeyTextField {
        let textField = HotkeyTextField()
        textField.hotkeyCallback = { modifiers, keyCode in
            let display = formatHotkey(modifiers: modifiers, keyCode: keyCode)
            DispatchQueue.main.async {
                self.hotkeyDisplay = display
                self.isRecording = false
                self.onRecorded(modifiers, keyCode, display)
            }
        }
        textField.onFocusChange = { focused in
            DispatchQueue.main.async {
                self.isRecording = focused
            }
        }
        return textField
    }
    
    func updateNSView(_ nsView: HotkeyTextField, context: Context) {
        nsView.stringValue = isRecording ? "..." : hotkeyDisplay
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject {}
    
    private func formatHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.function) { parts.append("fn") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined(separator: " ")
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete",
            53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z",
            7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E",
            15: "R", 16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12",
            59: "Control", 62: "Control(R)", 58: "Option", 61: "Option(R)",
            56: "Shift", 60: "Shift(R)", 55: "Command", 54: "Command(R)", 63: "Fn"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}

// 自定义 NSTextField
class HotkeyTextField: NSTextField {
    var hotkeyCallback: ((NSEvent.ModifierFlags, UInt16) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isEditable = false
        isSelectable = false
        isBezeled = false
        drawsBackground = true
        backgroundColor = NSColor.controlBackgroundColor
        alignment = .center
        font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 2
        onFocusChange?(true)
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        onFocusChange?(false)
        return super.resignFirstResponder()
    }
    
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        hotkeyCallback?(modifiers, event.keyCode)
        window?.makeFirstResponder(nil)
    }
    
    override func flagsChanged(with event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        
        if modifierKeyCodes.contains(keyCode) {
            let isPressed: Bool
            switch keyCode {
            case 55, 54: isPressed = modifiers.contains(.command)
            case 56, 60: isPressed = modifiers.contains(.shift)
            case 58, 61: isPressed = modifiers.contains(.option)
            case 59, 62: isPressed = modifiers.contains(.control)
            case 63: isPressed = modifiers.contains(.function)
            default: isPressed = false
            }
            if isPressed {
                hotkeyCallback?([], keyCode)
                window?.makeFirstResponder(nil)
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
}

// MARK: - Step 2: 输入模式
struct Step2AutoModeView: View {
    @ObservedObject var settings: AppSettings
    var onNext: () -> Void
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.15), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                
                Image(systemName: settings.autoStartOnFocus ? "text.cursor" : "hand.tap")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.purple)
            }
            
            Text("输入模式")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 24)
            
            Text("选择如何触发语音输入")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            // 选项卡片
            VStack(spacing: 10) {
                ModeCard(
                    icon: "hand.tap",
                    title: "手动模式",
                    subtitle: "按住快捷键时录音",
                    isSelected: !settings.autoStartOnFocus,
                    color: .blue
                ) { settings.autoStartOnFocus = false }
                
                ModeCard(
                    icon: "text.cursor",
                    title: "自动模式",
                    subtitle: "聚焦输入框时自动录音",
                    isSelected: settings.autoStartOnFocus,
                    color: .purple
                ) { settings.autoStartOnFocus = true }
            }
            .padding(.horizontal, 36)
            .padding(.top, 28)
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("上一步")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                
                Button(action: onNext) {
                    Text("下一步")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 32)
        }
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? color.opacity(0.15) : Color.gray.opacity(0.08))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? color : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: isSelected ? color.opacity(0.1) : .clear, radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: 权限
struct Step3PermissionsView: View {
    @ObservedObject var permissionManager: PermissionManager
    var onComplete: () -> Void
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.green.opacity(0.15), .green.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                
                Image(systemName: allGranted ? "checkmark.shield.fill" : "lock.shield")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.green)
            }
            
            Text("授权权限")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 24)
            
            Text("需要以下权限才能正常工作")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            // 权限列表
            VStack(spacing: 10) {
                PermissionCard(
                    icon: "hand.raised.fill",
                    title: "辅助功能",
                    subtitle: "监听快捷键并插入文字",
                    isGranted: permissionManager.isAccessibilityTrusted
                ) {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                }
                
                PermissionCard(
                    icon: "mic.fill",
                    title: "麦克风",
                    subtitle: "录制语音进行识别",
                    isGranted: permissionManager.isMicrophoneGranted
                ) {
                    permissionManager.requestMicrophoneAccess()
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 28)
            
            // 刷新按钮
            Button(action: {
                permissionManager.checkAccessibilityStatus()
                permissionManager.checkMicrophoneStatus()
            }) {
                Label("刷新状态", systemImage: "arrow.clockwise")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.top, 16)
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("上一步")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                
                Button(action: onComplete) {
                    Text(allGranted ? "开始使用" : "稍后设置")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(allGranted ? .green : .blue)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 32)
        }
    }
    
    var allGranted: Bool {
        permissionManager.isAccessibilityTrusted && permissionManager.isMicrophoneGranted
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isGranted ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                } else {
                    Text("授权")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isGranted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
