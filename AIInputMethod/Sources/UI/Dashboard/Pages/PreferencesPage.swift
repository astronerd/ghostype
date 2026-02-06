import SwiftUI
import AppKit

// MARK: - PreferencesPage

/// 偏好设置页面
struct PreferencesPage: View {
    
    // MARK: - Properties
    
    @State private var viewModel = PreferencesViewModel()
    @State private var isRecordingHotkey = false
    @State private var showingAppPicker = false
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("偏好设置")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 8)
                
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
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        SettingsSection(title: "权限管理", icon: "lock.shield") {
            VStack(spacing: 0) {
                // 辅助功能权限
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.permissionManager.isAccessibilityTrusted ? Color.green.opacity(0.15) : Color.orange.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.permissionManager.isAccessibilityTrusted ? .green : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("辅助功能")
                            .font(.system(size: 14, weight: .medium))
                        Text("监听快捷键并插入文字")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.permissionManager.isAccessibilityTrusted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    } else {
                        Button("授权") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.leading, 52)
                
                // 麦克风权限
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.permissionManager.isMicrophoneGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.permissionManager.isMicrophoneGranted ? .green : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("麦克风")
                            .font(.system(size: 14, weight: .medium))
                        Text("录制语音进行识别")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.permissionManager.isMicrophoneGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    } else {
                        Button("授权") {
                            viewModel.permissionManager.requestMicrophoneAccess()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.leading, 52)
                
                // 刷新按钮
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.permissionManager.checkAccessibilityStatus()
                        viewModel.permissionManager.checkMicrophoneStatus()
                    }) {
                        Label("刷新状态", systemImage: "arrow.clockwise")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 10)
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

    // MARK: - Contacts Hotwords Section
    
    private var contactsHotwordsSection: some View {
        SettingsSection(title: "通讯录热词", icon: "person.crop.circle") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cyan.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用通讯录热词")
                            .font(.system(size: 14, weight: .medium))
                        Text("使用通讯录联系人姓名提高识别准确率")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.enableContactsHotwords },
                        set: { viewModel.enableContactsHotwords = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if viewModel.enableContactsHotwords {
                    Divider()
                        .padding(.leading, 52)
                    
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("授权状态")
                                .font(.system(size: 14, weight: .medium))
                            Text(viewModel.contactsAuthStatus.displayText)
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.contactsAuthStatus.color)
                        }
                        
                        Spacer()
                        
                        if viewModel.contactsAuthStatus == .authorized {
                            Text("\(viewModel.hotwordsCount) 个热词")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                viewModel.refreshHotwords()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        } else if viewModel.contactsAuthStatus == .notDetermined {
                            Button("授权访问") {
                                viewModel.requestContactsAccessIfNeeded()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else if viewModel.contactsAuthStatus == .denied {
                            Button("打开设置") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts")!)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Auto Enter Section
    
    private var autoEnterSection: some View {
        SettingsSection(title: "自动发送", icon: "return") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "return")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用自动发送")
                            .font(.system(size: 14, weight: .medium))
                        Text("上字后自动按回车发送消息")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.enableAutoEnter },
                        set: { viewModel.enableAutoEnter = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if viewModel.enableAutoEnter {
                    Divider()
                        .padding(.leading, 52)
                    
                    // AppleScript 自动化权限检测
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.isAppleScriptAuthorized ? Color.green.opacity(0.15) : Color.orange.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "applescript")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(viewModel.isAppleScriptAuthorized ? .green : .orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自动化权限")
                                .font(.system(size: 14, weight: .medium))
                            Text("允许控制 System Events")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isAppleScriptAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.green)
                        } else {
                            Button("授权") {
                                viewModel.requestAppleScriptPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .padding(.leading, 52)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("启用的应用")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                showingAppPicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11))
                                    Text("添加应用")
                                        .font(.system(size: 12))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        if viewModel.autoEnterApps.isEmpty {
                            HStack {
                                Spacer()
                                Text("暂无应用，点击上方按钮添加")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            ForEach(viewModel.autoEnterApps) { app in
                                HStack(spacing: 10) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                    } else {
                                        Image(systemName: "app")
                                            .frame(width: 24, height: 24)
                                    }
                                    
                                    Text(app.name)
                                        .font(.system(size: 13))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.removeAutoEnterApp(bundleId: app.bundleId)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(viewModel: viewModel, isPresented: $showingAppPicker)
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


// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    var viewModel: PreferencesViewModel
    @Binding var isPresented: Bool
    @State private var runningApps: [RunningAppInfo] = []
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择应用")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    isPresented = false
                }
            }
            .padding()
            
            Divider()
            
            if runningApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("没有可添加的应用")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(runningApps) { app in
                    HStack(spacing: 12) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 14, weight: .medium))
                            Text(app.bundleId)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.autoEnterApps.contains(where: { $0.bundleId == app.bundleId }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("添加") {
                                viewModel.addAutoEnterApp(bundleId: app.bundleId)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 400, height: 350)
        .onAppear {
            loadRunningApps()
        }
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
