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
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            
            // Content
            TabView(selection: $currentStep) {
                Step1HotkeyView(settings: settings, onNext: { currentStep = 1 })
                    .tag(0)
                
                Step2AutoModeView(settings: settings, onNext: { currentStep = 2 }, onBack: { currentStep = 0 })
                    .tag(1)
                
                Step3PermissionsView(permissionManager: permissionManager, onComplete: onComplete, onBack: { currentStep = 1 })
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 420, height: 480)
    }
}

// MARK: - Step 1: 快捷键设置
struct Step1HotkeyView: View {
    @ObservedObject var settings: AppSettings
    var onNext: () -> Void
    
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "keyboard")
                .font(.system(size: 56))
                .foregroundColor(.blue)
            
            Text("设置快捷键")
                .font(.title.bold())
            
            Text("按住快捷键说话，松开完成输入")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 快捷键录入按钮
            HotkeyRecorderView(
                isRecording: $isRecording,
                hotkeyDisplay: $settings.hotkeyDisplay,
                onRecorded: { modifiers, keyCode, display in
                    settings.hotkeyModifiers = modifiers
                    settings.hotkeyKeyCode = keyCode
                    settings.hotkeyDisplay = display
                }
            )
            .frame(width: 200, height: 50)
            
            Text("点击上方按钮，然后按下想要的快捷键组合")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onNext) {
                Text("下一步")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
    }
}

// 快捷键录入视图 - 使用 NSTextField 来捕获按键
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
        nsView.stringValue = isRecording ? "请按下快捷键..." : hotkeyDisplay
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
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
            // 修饰键本身
            59: "Control", 62: "Control(R)",
            58: "Option", 61: "Option(R)",
            56: "Shift", 60: "Shift(R)",
            55: "Command", 54: "Command(R)",
            63: "Fn"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}

// 自定义 NSTextField 用于捕获按键
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
        isBezeled = true
        bezelStyle = .roundedBezel
        alignment = .center
        font = .systemFont(ofSize: 16, weight: .medium)
        focusRingType = .exterior
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        onFocusChange?(true)
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        onFocusChange?(false)
        return super.resignFirstResponder()
    }
    
    override func keyDown(with event: NSEvent) {
        // 捕获所有按键，包括单键
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        let keyCode = event.keyCode
        
        hotkeyCallback?(modifiers, keyCode)
        window?.makeFirstResponder(nil) // 取消焦点
    }
    
    override func flagsChanged(with event: NSEvent) {
        // 捕获修饰键本身作为快捷键（如单独的 Control、Option）
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        
        // 修饰键的 keyCode
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        
        if modifierKeyCodes.contains(keyCode) {
            // 检查是按下还是松开（通过检查对应的 modifier flag）
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
                // 修饰键按下，记录为快捷键
                hotkeyCallback?([], keyCode)
                window?.makeFirstResponder(nil)
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
}

// MARK: - Step 2: 自动模式
struct Step2AutoModeView: View {
    @ObservedObject var settings: AppSettings
    var onNext: () -> Void
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: settings.autoStartOnFocus ? "text.cursor" : "hand.tap")
                .font(.system(size: 56))
                .foregroundColor(.purple)
            
            Text("输入模式")
                .font(.title.bold())
            
            Text("选择如何触发语音输入")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ModeOptionCard(
                    title: "手动模式",
                    description: "按住快捷键时录音",
                    icon: "hand.tap",
                    isSelected: !settings.autoStartOnFocus,
                    action: { settings.autoStartOnFocus = false }
                )
                
                ModeOptionCard(
                    title: "自动模式",
                    description: "聚焦输入框时自动开始录音",
                    icon: "text.cursor",
                    isSelected: settings.autoStartOnFocus,
                    action: { settings.autoStartOnFocus = true }
                )
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("上一步")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: onNext) {
                    Text("下一步")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
    }
}

struct ModeOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
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
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundColor(.green)
            
            Text("授权权限")
                .font(.title.bold())
            
            Text("需要以下权限才能正常工作")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "辅助功能",
                    description: "监听快捷键并插入文字",
                    isGranted: permissionManager.isAccessibilityTrusted,
                    action: {
                        // 触发系统弹窗
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        _ = AXIsProcessTrustedWithOptions(options)
                    }
                )
                
                PermissionRow(
                    icon: "mic.fill",
                    title: "麦克风",
                    description: "录制语音",
                    isGranted: permissionManager.isMicrophoneGranted,
                    action: {
                        permissionManager.requestMicrophoneAccess()
                    }
                )
            }
            .padding(.horizontal, 30)
            
            Button(action: {
                permissionManager.checkAccessibilityStatus()
                permissionManager.checkMicrophoneStatus()
            }) {
                Label("刷新状态", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("上一步")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: onComplete) {
                    Text(allGranted ? "开始使用" : "稍后设置")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
    }
    
    var allGranted: Bool {
        permissionManager.isAccessibilityTrusted && permissionManager.isMicrophoneGranted
    }
}
