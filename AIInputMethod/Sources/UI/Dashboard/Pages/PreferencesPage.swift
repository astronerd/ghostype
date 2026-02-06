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
                Text("偏好设置")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.bottom, DS.Spacing.sm)
                
                generalSettingsSection
                permissionsSection
                hotkeySettingsSection
                modeModifiersSection
                aiPolishSection
                translateLanguageSection
                contactsHotwordsSection
                autoEnterSection
                promptEditorSection
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
        MinimalSettingsSection(title: "通用", icon: "gearshape") {
            VStack(spacing: 0) {
                MinimalToggleRow(
                    title: "开机自启动",
                    subtitle: "登录时自动启动 GhosTYPE",
                    icon: "power",
                    isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.launchAtLogin = $0 }
                    )
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                MinimalToggleRow(
                    title: "声音反馈",
                    subtitle: "录音开始和结束时播放提示音",
                    icon: "speaker.wave.2",
                    isOn: Binding(
                        get: { viewModel.soundFeedback },
                        set: { viewModel.soundFeedback = $0 }
                    )
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                MinimalNavigationRow(
                    title: "输入模式",
                    subtitle: viewModel.autoStartOnFocus ? "自动模式" : "手动模式",
                    icon: viewModel.autoStartOnFocus ? "text.cursor" : "hand.tap"
                ) {
                    viewModel.autoStartOnFocus.toggle()
                }
            }
        }
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        MinimalSettingsSection(title: "权限管理", icon: "lock.shield") {
            VStack(spacing: 0) {
                permissionRow(
                    title: "辅助功能",
                    subtitle: "监听快捷键并插入文字",
                    icon: "hand.raised",
                    isGranted: viewModel.permissionManager.isAccessibilityTrusted,
                    onRequest: {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        _ = AXIsProcessTrustedWithOptions(options)
                    }
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                permissionRow(
                    title: "麦克风",
                    subtitle: "录制语音进行识别",
                    icon: "mic",
                    isGranted: viewModel.permissionManager.isMicrophoneGranted,
                    onRequest: {
                        viewModel.permissionManager.requestMicrophoneAccess()
                    }
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.permissionManager.checkAccessibilityStatus()
                        viewModel.permissionManager.checkMicrophoneStatus()
                    }) {
                        Label("刷新状态", systemImage: "arrow.clockwise")
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
                Button("授权") { onRequest() }
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
        MinimalSettingsSection(title: "快捷键", icon: "keyboard") {
            VStack(spacing: DS.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("触发快捷键")
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                        
                        Text("按住快捷键说话，松开完成输入")
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
                    
                    Text(isRecordingHotkey ? "按下新的快捷键组合..." : "点击上方按钮修改快捷键")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                    
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }
        }
    }

    // MARK: - Mode Modifiers Section
    
    private var modeModifiersSection: some View {
        MinimalSettingsSection(title: "模式修饰键", icon: "keyboard.badge.ellipsis") {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("翻译模式")
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                        Text("按住主触发键 + 此修饰键进入翻译模式")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
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
                    .frame(width: 100)
                }
                .padding(DS.Spacing.lg)
                
                MinimalDivider()
                    .padding(.horizontal, DS.Spacing.lg)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("随心记模式")
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                        Text("按住主触发键 + 此修饰键进入随心记模式")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
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
                    .frame(width: 100)
                }
                .padding(DS.Spacing.lg)
            }
        }
    }

    // MARK: - AI Polish Section
    
    private var aiPolishSection: some View {
        MinimalSettingsSection(title: "AI 润色", icon: "wand.and.stars") {
            VStack(spacing: 0) {
                MinimalToggleRow(
                    title: "启用 AI 润色",
                    subtitle: "关闭后直接输出原始转录文本",
                    icon: "wand.and.stars",
                    isOn: Binding(
                        get: { viewModel.enableAIPolish },
                        set: { viewModel.enableAIPolish = $0 }
                    )
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.icon)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动润色阈值")
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                        Text("低于此字数的文本不进行 AI 润色")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                    }
                    Spacer()
                    HStack(spacing: DS.Spacing.md) {
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.polishThreshold) },
                                set: { viewModel.polishThreshold = Int($0) }
                            ),
                            in: 0...200,
                            step: 1
                        )
                        .frame(width: 100)
                        Text("\(viewModel.polishThreshold) 字")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
                .disabled(!viewModel.enableAIPolish)
            }
        }
    }

    // MARK: - Translate Language Section
    
    private var translateLanguageSection: some View {
        MinimalSettingsSection(title: "翻译设置", icon: "globe") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("翻译语言")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    Text("选择翻译模式的目标语言")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
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
                .frame(width: 120)
            }
            .padding(DS.Spacing.lg)
        }
    }

    // MARK: - Contacts Hotwords Section
    
    private var contactsHotwordsSection: some View {
        MinimalSettingsSection(title: "通讯录热词", icon: "person.crop.circle") {
            VStack(spacing: 0) {
                MinimalToggleRow(
                    title: "启用通讯录热词",
                    subtitle: "使用通讯录联系人姓名提高识别准确率",
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
                            Text("授权状态")
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text1)
                            Text(viewModel.contactsAuthStatus.displayText)
                                .font(DS.Typography.caption)
                                .foregroundColor(viewModel.contactsAuthStatus.color)
                        }
                        
                        Spacer()
                        
                        if viewModel.contactsAuthStatus == .authorized {
                            Text("\(viewModel.hotwordsCount) 个热词")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                            
                            Button(action: { viewModel.refreshHotwords() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                    .foregroundColor(DS.Colors.icon)
                            }
                            .buttonStyle(.plain)
                        } else if viewModel.contactsAuthStatus == .notDetermined {
                            Button("授权访问") { viewModel.requestContactsAccessIfNeeded() }
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text1)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.highlight)
                                .cornerRadius(DS.Layout.cornerRadius)
                                .buttonStyle(.plain)
                        } else if viewModel.contactsAuthStatus == .denied {
                            Button("打开设置") {
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
        MinimalSettingsSection(title: "自动发送", icon: "return") {
            VStack(spacing: 0) {
                MinimalToggleRow(
                    title: "启用自动发送",
                    subtitle: "上字后自动按回车发送消息",
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
                            Text("自动化权限")
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text1)
                            Text("允许控制 System Events")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                        }
                        
                        Spacer()
                        
                        if viewModel.isAppleScriptAuthorized {
                            StatusDot(status: .success, size: 8)
                        } else {
                            Button("授权") { viewModel.requestAppleScriptPermission() }
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
                            Text("启用的应用")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                            
                            Spacer()
                            
                            Button(action: { showingAppPicker = true }) {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("添加应用")
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
                            Text("暂无应用，点击上方按钮添加")
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
            AppPickerSheet(viewModel: viewModel, isPresented: $showingAppPicker)
        }
    }

    // MARK: - Prompt Editor Section
    
    private var promptEditorSection: some View {
        MinimalSettingsSection(title: "自定义 Prompt", icon: "text.quote") {
            PromptEditorView(
                title: "润色 Prompt",
                prompt: Binding(
                    get: { viewModel.polishPrompt },
                    set: { viewModel.polishPrompt = $0 }
                ),
                defaultPrompt: AppSettings.defaultPolishPrompt
            )
            .padding(DS.Spacing.lg)
        }
    }
    
    // MARK: - AI Engine Section
    
    private var aiEngineSection: some View {
        MinimalSettingsSection(title: "AI 引擎", icon: "cpu") {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("豆包语音识别")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    
                    Text("Doubao Speech-to-Text API")
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
                    
                    Text(viewModel.aiEngineStatus.displayText)
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
                    
                    Text("恢复默认设置")
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

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    var viewModel: PreferencesViewModel
    @Binding var isPresented: Bool
    @State private var runningApps: [RunningAppInfo] = []
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择应用")
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text1)
                Spacer()
                Button("完成") { isPresented = false }
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                    .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)
            
            MinimalDivider()
            
            if runningApps.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 36))
                        .foregroundColor(DS.Colors.text3)
                    Text("没有可添加的应用")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(runningApps) { app in
                    HStack(spacing: DS.Spacing.md) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 28, height: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text1)
                            Text(app.bundleId)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                        }
                        
                        Spacer()
                        
                        if viewModel.autoEnterApps.contains(where: { $0.bundleId == app.bundleId }) {
                            StatusDot(status: .success, size: 8)
                        } else {
                            Button("添加") { viewModel.addAutoEnterApp(bundleId: app.bundleId) }
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text1)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.highlight)
                                .cornerRadius(DS.Layout.cornerRadius)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 400, height: 350)
        .background(DS.Colors.bg1)
        .onAppear { loadRunningApps() }
    }
    
    private func loadRunningApps() {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                let icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
                return RunningAppInfo(bundleId: bundleId, name: name, icon: icon)
            }
        runningApps = apps.sorted { $0.name < $1.name }
    }
}

struct RunningAppInfo: Identifiable {
    let id = UUID()
    let bundleId: String
    let name: String
    let icon: NSImage
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
