//
//  OnboardingWindow.swift
//  AIInputMethod
//
//  Onboarding 引导界面 - Radical Minimalist 极简风格
//  基于 UI_DESIGN_SPEC.md 规范设计
//

import SwiftUI
import Carbon
import AppKit

// MARK: - OnboardingWindow

struct OnboardingWindow: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings = AppSettings.shared
    @State private var currentStep = 0
    var onComplete: () -> Void
    
    var body: some View {
        Group {
            switch currentStep {
            case 0:
                Step1HotkeyView(
                    settings: settings,
                    onNext: { withAnimation(.easeInOut(duration: 0.2)) { currentStep = 1 } }
                )
            case 1:
                Step2AutoModeView(
                    settings: settings,
                    onNext: { withAnimation(.easeInOut(duration: 0.2)) { currentStep = 2 } },
                    onBack: { withAnimation(.easeInOut(duration: 0.2)) { currentStep = 0 } }
                )
            default:
                Step3PermissionsView(
                    permissionManager: permissionManager,
                    onComplete: onComplete,
                    onBack: { withAnimation(.easeInOut(duration: 0.2)) { currentStep = 1 } }
                )
            }
        }
        .transition(.opacity)
        .frame(width: 480, height: 520)
        .background(DS.Colors.bg1)
    }
}

// MARK: - Step 1: 快捷键设置

struct Step1HotkeyView: View {
    @ObservedObject var settings: AppSettings
    var onNext: () -> Void
    
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo header
            VStack(spacing: DS.Spacing.sm) {
                GHOSTYPELogo()
                    .frame(width: 152, height: 21)
                
                Text("Your Type of Spirit.")
                    .font(DS.Typography.caption.italic())
                    .foregroundColor(DS.Colors.text2)
            }
            .padding(.top, DS.Spacing.xl)
            
            Spacer()
            
            // 图标
            Image(systemName: "keyboard")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(DS.Colors.text1)
            
            // 标题
            Text("设置快捷键")
                .font(DS.Typography.largeTitle)
                .foregroundColor(DS.Colors.text1)
                .padding(.top, DS.Spacing.xl)
            
            // 副标题
            Text("按住快捷键说话，松开完成输入")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
                .padding(.top, DS.Spacing.sm)
            
            // 快捷键录入
            VStack(spacing: DS.Spacing.sm) {
                HotkeyRecorderView(
                    isRecording: $isRecording,
                    hotkeyDisplay: $settings.hotkeyDisplay,
                    onRecorded: { modifiers, keyCode, display in
                        settings.hotkeyModifiers = modifiers
                        settings.hotkeyKeyCode = keyCode
                        settings.hotkeyDisplay = display
                    }
                )
                .frame(width: 120, height: 48)
                
                Text(isRecording ? "按下快捷键组合..." : "点击修改")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
            }
            .padding(.top, DS.Spacing.xxl)
            
            Spacer()
            
            // 底部按钮
            MinimalButton(title: "下一步", style: .primary, action: onNext)
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HotkeyRecorderView

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

// MARK: - HotkeyTextField

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
        backgroundColor = NSColor(DS.Colors.bg2)
        alignment = .center
        font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(DS.Colors.border).cgColor
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        layer?.borderColor = NSColor(DS.Colors.text1).cgColor
        onFocusChange?(true)
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        layer?.borderColor = NSColor(DS.Colors.border).cgColor
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
            // Logo header
            VStack(spacing: DS.Spacing.sm) {
                GHOSTYPELogo()
                    .frame(width: 152, height: 21)
                
                Text("Your Type of Spirit.")
                    .font(DS.Typography.caption.italic())
                    .foregroundColor(DS.Colors.text2)
            }
            .padding(.top, DS.Spacing.xl)
            
            Spacer()
            
            // 图标
            Image(systemName: settings.autoStartOnFocus ? "text.cursor" : "hand.tap")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(DS.Colors.text1)
            
            // 标题
            Text("输入模式")
                .font(DS.Typography.largeTitle)
                .foregroundColor(DS.Colors.text1)
                .padding(.top, DS.Spacing.xl)
            
            // 副标题
            Text("选择如何触发语音输入")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
                .padding(.top, DS.Spacing.sm)
            
            // 选项卡片
            VStack(spacing: DS.Spacing.md) {
                MinimalModeCard(
                    icon: "hand.tap",
                    title: "手动模式",
                    subtitle: "按住快捷键时录音",
                    isSelected: !settings.autoStartOnFocus
                ) { settings.autoStartOnFocus = false }
                
                MinimalModeCard(
                    icon: "text.cursor",
                    title: "自动模式",
                    subtitle: "聚焦输入框时自动录音",
                    isSelected: settings.autoStartOnFocus
                ) { settings.autoStartOnFocus = true }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.xxl)
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: DS.Spacing.md) {
                MinimalButton(title: "上一步", style: .secondary, action: onBack)
                MinimalButton(title: "下一步", style: .primary, action: onNext)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - MinimalModeCard

struct MinimalModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                
                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                // 选中指示
                Circle()
                    .fill(isSelected ? DS.Colors.text1 : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? DS.Colors.text1 : DS.Colors.border, lineWidth: 1)
                    )
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.bg2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                    .stroke(isSelected ? DS.Colors.text1 : DS.Colors.border, lineWidth: DS.Layout.borderWidth)
            )
            .cornerRadius(DS.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: 权限

struct Step3PermissionsView: View {
    @ObservedObject var permissionManager: PermissionManager
    var onComplete: () -> Void
    var onBack: () -> Void
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var allGranted: Bool {
        permissionManager.isAccessibilityTrusted && permissionManager.isMicrophoneGranted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo header
            VStack(spacing: DS.Spacing.sm) {
                GHOSTYPELogo()
                    .frame(width: 152, height: 21)
                
                Text("Your Type of Spirit.")
                    .font(DS.Typography.caption.italic())
                    .foregroundColor(DS.Colors.text2)
            }
            .padding(.top, DS.Spacing.xl)
            
            Spacer()
            
            // 图标
            Image(systemName: allGranted ? "checkmark.shield" : "lock.shield")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(DS.Colors.text1)
            
            // 标题
            Text("授权权限")
                .font(DS.Typography.largeTitle)
                .foregroundColor(DS.Colors.text1)
                .padding(.top, DS.Spacing.xl)
            
            // 副标题
            Text("需要以下权限才能正常工作")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
                .padding(.top, DS.Spacing.sm)
            
            // 权限列表
            VStack(spacing: DS.Spacing.md) {
                MinimalPermissionCard(
                    icon: "hand.raised",
                    title: "辅助功能",
                    subtitle: "监听快捷键并插入文字",
                    isGranted: permissionManager.isAccessibilityTrusted
                ) {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                }
                
                MinimalPermissionCard(
                    icon: "mic",
                    title: "麦克风",
                    subtitle: "录制语音进行识别",
                    isGranted: permissionManager.isMicrophoneGranted
                ) {
                    permissionManager.requestMicrophoneAccess()
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.xxl)
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: DS.Spacing.md) {
                MinimalButton(title: "上一步", style: .secondary, action: onBack)
                MinimalButton(
                    title: "开始使用",
                    style: .primary,
                    isDisabled: !allGranted,
                    action: onComplete
                )
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            permissionManager.checkAccessibilityStatus()
            permissionManager.checkMicrophoneStatus()
        }
    }
}

// MARK: - MinimalPermissionCard

struct MinimalPermissionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                
                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                // 状态指示
                if isGranted {
                    StatusDot(status: .success, size: 8)
                } else {
                    Text("授权")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text1)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.bg2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
            )
            .cornerRadius(DS.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(isGranted)
    }
}

// MARK: - MinimalButton

struct MinimalButton: View {
    let title: String
    let style: ButtonStyle
    var isDisabled: Bool = false
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.body)
                .foregroundColor(style == .primary ? DS.Colors.bg1 : DS.Colors.text1)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(style == .primary ? DS.Colors.text1 : DS.Colors.bg2)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                        .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                )
                .cornerRadius(DS.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}
