import SwiftUI
import AppKit

// MARK: - PreferencesPage

/// 偏好设置页面
struct PreferencesPage: View {
    
    // MARK: - Properties
    
    @State private var viewModel = PreferencesViewModel()
    @State private var isRecordingHotkey = false
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("偏好设置")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 8)
                
                generalSettingsSection
                hotkeySettingsSection
                modeModifiersSection
                aiPolishSection
                translateLanguageSection
                promptEditorSection
                aiEngineSection
                resetSection
                
                Spacer(minLength: 20)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - General Settings Section
    
    private var generalSettingsSection: some View {
        SettingsSection(title: "通用", icon: "gearshape") {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "开机自启动",
                    subtitle: "登录时自动启动 GhosTYPE",
                    icon: "power",
                    isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.launchAtLogin = $0 }
                    )
                )
                
                Divider()
                    .padding(.leading, 52)
                
                SettingsToggleRow(
                    title: "声音反馈",
                    subtitle: "录音开始和结束时播放提示音",
                    icon: "speaker.wave.2",
                    isOn: Binding(
                        get: { viewModel.soundFeedback },
                        set: { viewModel.soundFeedback = $0 }
                    )
                )
                
                Divider()
                    .padding(.leading, 52)
                
                SettingsNavigationRow(
                    title: "输入模式",
                    subtitle: viewModel.autoStartOnFocus ? "自动模式" : "手动模式",
                    icon: viewModel.autoStartOnFocus ? "text.cursor" : "hand.tap"
                ) {
                    viewModel.autoStartOnFocus.toggle()
                }
            }
        }
    }
    
    // MARK: - Hotkey Settings Section
    
    private var hotkeySettingsSection: some View {
        SettingsSection(title: "快捷键", icon: "keyboard") {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("触发快捷键")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("按住快捷键说话，松开完成输入")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HotkeyRecorderView(
                        isRecording: $isRecordingHotkey,
                        hotkeyDisplay: Binding(
                            get: { viewModel.hotkeyDisplay },
                            set: { viewModel.hotkeyDisplay = $0 }
                        ),
                        onRecorded: { modifiers, keyCode, display in
                            viewModel.updateHotkey(modifiers: modifiers, keyCode: keyCode, display: display)
                        }
                    )
                    .frame(width: 140, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(isRecordingHotkey ? "按下新的快捷键组合..." : "点击上方按钮修改快捷键")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - Mode Modifiers Section
    
    private var modeModifiersSection: some View {
        SettingsSection(title: "模式修饰键", icon: "keyboard.badge.ellipsis") {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("翻译模式")
                            .font(.system(size: 14, weight: .medium))
                        Text("按住主触发键 + 此修饰键进入翻译模式")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ModifierKeyPicker(
                        title: "",
                        selectedModifier: Binding(
                            get: { viewModel.translateModifier },
                            set: { viewModel.translateModifier = $0 }
                        ),
                        excludedModifier: viewModel.memoModifier
                    )
                }
                .padding(16)
                
                Divider()
                    .padding(.leading, 16)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("随心记模式")
                            .font(.system(size: 14, weight: .medium))
                        Text("按住主触发键 + 此修饰键进入随心记模式")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ModifierKeyPicker(
                        title: "",
                        selectedModifier: Binding(
                            get: { viewModel.memoModifier },
                            set: { viewModel.memoModifier = $0 }
                        ),
                        excludedModifier: viewModel.translateModifier
                    )
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - AI Polish Section
    
    private var aiPolishSection: some View {
        SettingsSection(title: "AI 润色", icon: "wand.and.stars") {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "启用 AI 润色",
                    subtitle: "关闭后直接输出原始转录文本",
                    icon: "wand.and.stars",
                    isOn: Binding(
                        get: { viewModel.enableAIPolish },
                        set: { viewModel.enableAIPolish = $0 }
                    )
                )
                
                Divider()
                    .padding(.leading, 52)
                
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "textformat.size")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动润色阈值")
                            .font(.system(size: 14, weight: .medium))
                        Text("低于此字数的文本不进行 AI 润色")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.polishThreshold) },
                                set: { viewModel.polishThreshold = Int($0) }
                            ),
                            in: 0...200,
                            step: 1
                        )
                        .frame(width: 120)
                        Text("\(viewModel.polishThreshold) 字")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
                .disabled(!viewModel.enableAIPolish)
            }
        }
    }
    
    // MARK: - Translate Language Section
    
    private var translateLanguageSection: some View {
        SettingsSection(title: "翻译设置", icon: "globe") {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("翻译语言")
                        .font(.system(size: 14, weight: .medium))
                    Text("选择翻译模式的目标语言")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: Binding(
                    get: { viewModel.translateLanguage },
                    set: { viewModel.translateLanguage = $0 }
                )) {
                    ForEach(DoubaoLLMService.TranslateLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            .padding(16)
        }
    }
    
    // MARK: - Prompt Editor Section
    
    private var promptEditorSection: some View {
        SettingsSection(title: "自定义 Prompt", icon: "text.quote") {
            VStack(spacing: 0) {
                PromptEditorView(
                    title: "润色 Prompt",
                    prompt: Binding(
                        get: { viewModel.polishPrompt },
                        set: { viewModel.polishPrompt = $0 }
                    ),
                    defaultPrompt: AppSettings.defaultPolishPrompt
                )
                .padding(16)
            }
        }
    }
    
    // MARK: - AI Engine Section
    
    private var aiEngineSection: some View {
        SettingsSection(title: "AI 引擎", icon: "cpu") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("豆包语音识别")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Doubao Speech-to-Text API")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    if viewModel.aiEngineStatus == .checking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: viewModel.aiEngineStatus.icon)
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.aiEngineStatus.color)
                    }
                    
                    Text(viewModel.aiEngineStatus.displayText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(viewModel.aiEngineStatus.color)
                }
                
                Button(action: {
                    viewModel.checkAIEngineStatus()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(16)
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        HStack {
            Spacer()
            
            Button(action: {
                viewModel.resetToDefaults()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                    
                    Text("恢复默认设置")
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Navigation Row

struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
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
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ModifierKeyPicker

struct ModifierKeyPicker: View {
    var title: String
    @Binding var selectedModifier: NSEvent.ModifierFlags
    var excludedModifier: NSEvent.ModifierFlags?
    
    private let availableModifiers: [(NSEvent.ModifierFlags, String)] = [
        (.shift, "⇧ Shift"),
        (.command, "⌘ Command"),
        (.control, "⌃ Control"),
        (.option, "⌥ Option")
    ]
    
    var body: some View {
        Menu {
            ForEach(availableModifiers, id: \.0.rawValue) { modifier, label in
                Button(action: {
                    if modifier != excludedModifier {
                        selectedModifier = modifier
                    }
                }) {
                    HStack {
                        Text(label)
                        if modifier == selectedModifier {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(modifier == excludedModifier)
            }
        } label: {
            HStack(spacing: 6) {
                Text(displayText(for: selectedModifier))
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }
    
    private func displayText(for modifier: NSEvent.ModifierFlags) -> String {
        for (mod, label) in availableModifiers {
            if mod == modifier {
                return label
            }
        }
        return "未知"
    }
}

// MARK: - PromptEditorView

struct PromptEditorView: View {
    var title: String
    @Binding var prompt: String
    var defaultPrompt: String
    
    @State private var isExpanded = false
    @State private var showEmptyError = false
    
    private var isEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $prompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEmpty && showEmptyError ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if isEmpty && showEmptyError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Prompt 不能为空")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.red)
                }
                
                HStack {
                    Button(action: {
                        prompt = defaultPrompt
                        showEmptyError = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("恢复默认")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(prompt == defaultPrompt ? .secondary.opacity(0.5) : .accentColor)
                    .disabled(prompt == defaultPrompt)
                    
                    Spacer()
                    
                    Text("\(prompt.count) 字符")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
        }
        .onChange(of: prompt) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showEmptyError = true
            } else {
                showEmptyError = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PreferencesPage_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesPage()
            .frame(width: 600, height: 700)
    }
}
#endif
