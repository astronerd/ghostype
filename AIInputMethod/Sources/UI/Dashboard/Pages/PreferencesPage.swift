//
//  PreferencesPage.swift
//  AIInputMethod
//
//  偏好设置页面 - Radical Minimalist 极简风格
//

import SwiftUI
import AppKit

// MARK: - PreferencesPage

struct PreferencesPage: View {
    
    @State private var viewModel = PreferencesViewModel()
    @State private var isRecordingHotkey = false
    @State private var showingAppPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text(L.Prefs.title)
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.bottom, DS.Spacing.sm)
                
                generalSettingsSection
                languageSettingsSection
                permissionsSection
                hotkeySettingsSection
                contactsHotwordsSection
                autoEnterSection
                aiEngineSection
                resetSection
                
                Spacer(minLength: DS.Spacing.xl)
            }
            .padding(.top, 21)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
    }

    // MARK: - General Settings Section
    
    private var generalSettingsSection: some View {
        MinimalSettingsSection(title: L.Prefs.general, icon: "gearshape") {
            VStack(spacing: 0) {
                MinimalToggleRow(
                    title: L.Prefs.launchAtLogin,
                    subtitle: L.Prefs.launchAtLoginDesc,
                    icon: "power",
                    isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.launchAtLogin = $0 }
                    )
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                MinimalToggleRow(
                    title: L.Prefs.soundFeedback,
                    subtitle: L.Prefs.soundFeedbackDesc,
                    icon: "speaker.wave.2",
                    isOn: Binding(
                        get: { viewModel.soundFeedback },
                        set: { viewModel.soundFeedback = $0 }
                    )
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                MinimalNavigationRow(
                    title: L.Prefs.inputMode,
                    subtitle: viewModel.autoStartOnFocus ? L.Prefs.inputModeAuto : L.Prefs.inputModeManual,
                    icon: viewModel.autoStartOnFocus ? "text.cursor" : "hand.tap"
                ) {
                    viewModel.autoStartOnFocus.toggle()
                }
            }
        }
    }
    
    // MARK: - Language Settings Section
    
    private var languageSettingsSection: some View {
        MinimalSettingsSection(title: L.Prefs.language, icon: "globe") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Prefs.language)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    Text(L.Prefs.languageDesc)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                Picker("", selection: Binding(
                    get: { viewModel.appLanguage },
                    set: { viewModel.appLanguage = $0 }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        HStack {
                            Text(language.icon)
                            Text(language.displayName)
                        }
                        .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            .padding(DS.Spacing.lg)
        }
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        MinimalSettingsSection(title: L.Prefs.permissions, icon: "lock.shield") {
            VStack(spacing: 0) {
                permissionRow(
                    title: L.Prefs.accessibility,
                    subtitle: L.Prefs.accessibilityDesc,
                    icon: "hand.raised",
                    isGranted: viewModel.permissionManager.isAccessibilityTrusted,
                    onRequest: {
                        viewModel.permissionManager.promptForAccessibility()
                        viewModel.permissionManager.startPolling {
                            NotificationCenter.default.post(name: .permissionsDidChange, object: nil)
                        }
                    }
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                permissionRow(
                    title: L.Prefs.microphone,
                    subtitle: L.Prefs.microphoneDesc,
                    icon: "mic",
                    isGranted: viewModel.permissionManager.isMicrophoneGranted,
                    onRequest: {
                        viewModel.permissionManager.requestMicrophoneAccess()
                        viewModel.permissionManager.startPolling {
                            NotificationCenter.default.post(name: .permissionsDidChange, object: nil)
                        }
                    }
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.permissionManager.refreshAll()
                    }) {
                        Label(L.Prefs.refreshStatus, systemImage: "arrow.clockwise")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.md)
            }
        }
    }
    
    private func permissionRow(title: String, subtitle: String, icon: String, isGranted: Bool, onRequest: @escaping () -> Void) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.icon)
                .frame(width: 28, height: 28)
                .background(DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            if isGranted {
                StatusDot(status: .success, size: 8)
            } else {
                Button(L.Prefs.authorize) { onRequest() }
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Hotkey Settings Section
    
    private var hotkeySettingsSection: some View {
        MinimalSettingsSection(title: L.Prefs.hotkey, icon: "keyboard") {
            VStack(spacing: DS.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L.Prefs.hotkeyTrigger)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                        
                        Text(L.Prefs.hotkeyDesc)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
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
                    .frame(width: 80, height: 40)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Colors.text3)
                    
                    Text(isRecordingHotkey ? L.Prefs.hotkeyRecording : L.Prefs.hotkeyHint)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                    
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }
        }
    }

    // MARK: - Contacts Hotwords Section
    
    private var contactsHotwordsSection: some View {
        MinimalSettingsSection(title: L.Prefs.contactsHotwords, icon: "person.crop.circle") {
            VStack(spacing: 0) {
                MinimalToggleRow(
                    title: L.Prefs.contactsHotwordsEnable,
                    subtitle: L.Prefs.contactsHotwordsDesc,
                    icon: "person.crop.circle",
                    isOn: Binding(
                        get: { viewModel.enableContactsHotwords },
                        set: { viewModel.enableContactsHotwords = $0 }
                    )
                )
                
                if viewModel.enableContactsHotwords {
                    MinimalDivider()
                        .padding(.leading, 44)
                    
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(DS.Colors.icon)
                            .frame(width: 28, height: 28)
                            .background(DS.Colors.highlight)
                            .cornerRadius(DS.Layout.cornerRadius)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.Prefs.authStatus)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text1)
                            Text(viewModel.contactsAuthStatus.displayText)
                                .font(DS.Typography.caption)
                                .foregroundColor(viewModel.contactsAuthStatus.color)
                        }
                        
                        Spacer()
                        
                        if viewModel.contactsAuthStatus == .authorized {
                            Text("\(viewModel.hotwordsCount) \(L.Prefs.hotwordsCount)")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                            
                            Button(action: { viewModel.refreshHotwords() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                    .foregroundColor(DS.Colors.icon)
                            }
                            .buttonStyle(.plain)
                        } else if viewModel.contactsAuthStatus == .notDetermined {
                            Button(L.Prefs.authorizeAccess) { viewModel.requestContactsAccessIfNeeded() }
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text1)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.highlight)
                                .cornerRadius(DS.Layout.cornerRadius)
                                .buttonStyle(.plain)
                        } else if viewModel.contactsAuthStatus == .denied {
                            Button(L.Prefs.openSettings) {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts")!)
                            }
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text1)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(DS.Colors.highlight)
                            .cornerRadius(DS.Layout.cornerRadius)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                }
            }
        }
    }

    // MARK: - Auto Enter Section
    
    private var autoEnterSection: some View {
        MinimalSettingsSection(title: L.Prefs.autoSend, icon: "return") {
            VStack(spacing: 0) {
                MinimalToggleRow(
                    title: L.Prefs.autoSendEnable,
                    subtitle: L.Prefs.autoSendDesc,
                    icon: "return",
                    isOn: Binding(
                        get: { viewModel.enableAutoEnter },
                        set: { viewModel.enableAutoEnter = $0 }
                    )
                )
                
                if viewModel.enableAutoEnter {
                    MinimalDivider()
                        .padding(.leading, 44)
                    
                    HStack {
                        Image(systemName: "applescript")
                            .font(.system(size: 14))
                            .foregroundColor(DS.Colors.icon)
                            .frame(width: 28, height: 28)
                            .background(DS.Colors.highlight)
                            .cornerRadius(DS.Layout.cornerRadius)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.Prefs.automationPermission)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text1)
                            Text(L.Prefs.automationPermissionDesc)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                        }
                        
                        Spacer()
                        
                        if viewModel.isAppleScriptAuthorized {
                            StatusDot(status: .success, size: 8)
                        } else {
                            Button(L.Prefs.authorize) { viewModel.requestAppleScriptPermission() }
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text1)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.highlight)
                                .cornerRadius(DS.Layout.cornerRadius)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    
                    MinimalDivider()
                        .padding(.leading, 44)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack {
                            Text(L.Prefs.enabledApps)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                            
                            Spacer()
                            
                            Button(action: { showingAppPicker = true }) {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text(L.Prefs.addApp)
                                        .font(DS.Typography.caption)
                                }
                                .foregroundColor(DS.Colors.text1)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.highlight)
                                .cornerRadius(DS.Layout.cornerRadius)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if viewModel.autoEnterApps.isEmpty {
                            Text(L.Prefs.noAppsHint)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.sm)
                        } else {
                            ForEach(viewModel.autoEnterApps) { app in
                                HStack(spacing: DS.Spacing.sm) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: "app")
                                            .frame(width: 20, height: 20)
                                    }
                                    
                                    Text(app.name)
                                        .font(DS.Typography.body)
                                        .foregroundColor(DS.Colors.text1)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: Binding(
                                        get: { app.sendMethod },
                                        set: { newMethod in
                                            viewModel.updateSendMethod(bundleId: app.bundleId, method: newMethod)
                                        }
                                    )) {
                                        ForEach(SendMethod.allCases) { method in
                                            Text(method.displayName).tag(method)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 110)
                                    
                                    Button(action: { viewModel.removeAutoEnterApp(bundleId: app.bundleId) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundColor(DS.Colors.text3)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, DS.Spacing.xs)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                }
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                onSelect: { bundleId in
                    viewModel.addAutoEnterApp(bundleId: bundleId)
                },
                isPresented: $showingAppPicker
            )
        }
    }

    // MARK: - AI Engine Section
    
    private var aiEngineSection: some View {
        MinimalSettingsSection(title: L.Prefs.aiEngine, icon: "cpu") {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.Prefs.aiEngineName)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    
                    Text(L.Prefs.aiEngineApi)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                HStack(spacing: DS.Spacing.sm) {
                    if viewModel.aiEngineStatus == .checking {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        StatusDot(status: viewModel.aiEngineStatus == .online ? .success : .error, size: 8)
                    }
                    
                    Text(viewModel.aiEngineStatus.localizedText)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Button(action: { viewModel.checkAIEngineStatus() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Colors.icon)
                }
                .buttonStyle(.plain)
                .padding(.leading, DS.Spacing.sm)
            }
            .padding(DS.Spacing.lg)
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        HStack {
            Spacer()
            
            Button(action: { viewModel.resetToDefaults() }) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                    
                    Text(L.Prefs.reset)
                        .font(DS.Typography.caption)
                }
                .foregroundColor(DS.Colors.text2)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, DS.Spacing.sm)
    }
}

// MARK: - MinimalSettingsSection

struct MinimalSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.icon)
                
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            VStack(spacing: 0) {
                content()
            }
            .background(DS.Colors.bg2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
        }
    }
}

// MARK: - MinimalToggleRow

struct MinimalToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.icon)
                .frame(width: 28, height: 28)
                .background(DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}

// MARK: - MinimalNavigationRow

struct MinimalNavigationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.text3)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
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
            HStack(spacing: DS.Spacing.xs) {
                Text(displayText(for: selectedModifier))
                    .font(DS.Typography.caption)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(DS.Colors.text1)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.highlight)
            .cornerRadius(DS.Layout.cornerRadius)
        }
        .menuStyle(.borderlessButton)
    }
    
    private func displayText(for modifier: NSEvent.ModifierFlags) -> String {
        for (mod, label) in availableModifiers {
            if mod == modifier { return label }
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
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                TextEditor(text: $prompt)
                    .font(DS.Typography.mono(11, weight: .regular))
                    .frame(minHeight: 100)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.bg1)
                    .cornerRadius(DS.Layout.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                            .stroke(isEmpty && showEmptyError ? DS.Colors.statusError : DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                    )
                
                if isEmpty && showEmptyError {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 10))
                        Text("Prompt 不能为空")
                            .font(DS.Typography.caption)
                    }
                    .foregroundColor(DS.Colors.statusError)
                }
                
                HStack {
                    Button(action: {
                        prompt = defaultPrompt
                        showEmptyError = false
                    }) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("恢复默认")
                                .font(DS.Typography.caption)
                        }
                        .foregroundColor(prompt == defaultPrompt ? DS.Colors.text3 : DS.Colors.text1)
                    }
                    .buttonStyle(.plain)
                    .disabled(prompt == defaultPrompt)
                    
                    Spacer()
                    
                    Text("\(prompt.count) 字符")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
            }
            .padding(.top, DS.Spacing.sm)
        } label: {
            Text(title)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
        }
        .onChange(of: prompt) { _, newValue in
            showEmptyError = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
