//
//  PreferencesPage.swift
//  AIInputMethod
//
//  偏好设置页面 - Radical Minimalist 极简风格
//

import SwiftUI
import AppKit

// MARK: - KeyCode Display Name Helper (for combo key recorder)

private func comboKeyDisplayName(_ keyCode: UInt16) -> String {
    let mapping: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
        37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        25: "9", 26: "7", 28: "8", 29: "0",
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";",
        42: "\\", 43: ",", 44: "/", 47: ".", 50: "`",
        36: "\u{21A9}", 48: "\u{21E5}", 49: "Space", 51: "\u{232B}", 53: "\u{238B}",
        54: "\u{2318}R", 55: "\u{2318}", 56: "\u{21E7}", 57: "\u{21EA}",
        58: "\u{2325}", 59: "\u{2303}", 60: "\u{21E7}R", 61: "\u{2325}R",
        62: "\u{2303}R", 63: "Fn",
    ]
    return mapping[keyCode] ?? "Key\(keyCode)"
}

// MARK: - PreferencesPage

struct PreferencesPage: View {
    
    @State private var viewModel = PreferencesViewModel()
    @State private var isRecordingHotkey = false
    @State private var comboKeyMonitor: Any?
    @State private var showingAppPicker = false
    @Environment(DashboardState.self) private var dashboardState
    
    // Debug 模式彩蛋：连点版本号 10 次激活
    @State private var versionTapCount = 0
    @State private var lastTapTime: Date = .distantPast
    @State private var showDebugToast = false
    
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
                hidMappingSection
                contactsHotwordsSection
                autoEnterSection
                updateSection
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
                // Hotkey mode segmented picker
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.icon)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { viewModel.hotkeyMode },
                        set: { viewModel.hotkeyMode = $0 }
                    )) {
                        Text(L.Prefs.hotkeyModeSingle).tag(HotkeyMode.singleKey)
                        Text(L.Prefs.hotkeyModeCombo).tag(HotkeyMode.comboKey)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                
                if viewModel.hotkeyMode == .singleKey {
                    // Single key mode: show existing hotkey recorder and hint
                    MinimalDivider().padding(.leading, 44)
                    
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
                } else {
                    // Combo key mode: show default combo key recorder + hint
                    MinimalDivider().padding(.leading, 44)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(L.Prefs.defaultComboKey)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text1)
                            
                            Text(L.Prefs.defaultComboKeyDesc)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                        }
                        
                        Spacer()
                        
                        // Two-key combo recorder
                        HStack(spacing: 4) {
                            comboRecorderBox(
                                label: defaultComboKey1Label,
                                isActive: viewModel.isRecordingDefaultCombo && viewModel.defaultComboStep == 1
                            ) {
                                if !viewModel.isRecordingDefaultCombo {
                                    viewModel.startDefaultComboRecording(forKey: 1)
                                    startDefaultComboMonitor()
                                }
                            }
                            
                            Text(L.Skill.comboKeyPlus)
                                .font(DS.Typography.mono(11, weight: .medium))
                                .foregroundColor(DS.Colors.text2)
                            
                            comboRecorderBox(
                                label: defaultComboKey2Label,
                                isActive: viewModel.isRecordingDefaultCombo && viewModel.defaultComboStep == 2
                            ) {
                                if !viewModel.isRecordingDefaultCombo {
                                    viewModel.startDefaultComboRecording(forKey: 2)
                                    startDefaultComboMonitor()
                                }
                            }
                        }
                        .contextMenu {
                            if viewModel.defaultComboKey1 != nil || viewModel.defaultComboKey2 != nil {
                                Button(action: { viewModel.clearDefaultComboHotkey() }) {
                                    Label(L.Skill.comboKeyClear, systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .onChange(of: viewModel.isRecordingDefaultCombo) { _, newValue in
                        if !newValue {
                            stopDefaultComboMonitor()
                        }
                    }
                    
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colors.accent)
                        
                        Text(L.Prefs.comboKeyHint)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.accent)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.md)
                }
            }
        }
    }

    // MARK: - HID Mapping Section
    
    private var hidMappingSection: some View {
        MinimalSettingsSection(title: L.Prefs.hidDevices, icon: "keyboard.badge.ellipsis") {
            VStack(spacing: 0) {
                // Header with add button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.Prefs.hidDevicesTitle)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                        Text(L.Prefs.hidDevicesDesc)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.openHIDDevicePicker() }) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text(L.Prefs.hidAddDevice)
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
                .padding(DS.Spacing.lg)
                
                // Mapping list
                if !viewModel.hidMappings.isEmpty {
                    MinimalDivider().padding(.leading, 44)
                    
                    ForEach(viewModel.hidMappings) { mapping in
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: mapping.isConnected ? "keyboard" : "keyboard.badge.ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(mapping.isConnected ? DS.Colors.icon : DS.Colors.text3)
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mapping.deviceName)
                                    .font(DS.Typography.body)
                                    .foregroundColor(DS.Colors.text1)
                                Text(mapping.sourceKeyName)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.text2)
                            }
                            
                            Spacer()
                            
                            if !mapping.isConnected {
                                Text(L.Prefs.hidDisconnected)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.text3)
                            }
                            
                            Button(action: { viewModel.removeHIDMapping(mapping) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10))
                                    .foregroundColor(DS.Colors.text3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showHIDDevicePicker) {
            hidDevicePickerSheet
        }
    }
    
    // MARK: - HID Device Picker Sheet
    
    private var hidDevicePickerSheet: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(L.Prefs.hidPickerTitle)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                Spacer()
                Button(action: { viewModel.closeHIDDevicePicker() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.text3)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)
            
            MinimalDivider()
            
            // Hint
            Text(L.Prefs.hidPickerHint)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
            
            // Device list
            if viewModel.hidConnectedDevices.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 28))
                        .foregroundColor(DS.Colors.text3)
                    Text(L.Prefs.hidNoDevices)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(DS.Spacing.lg)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(viewModel.hidConnectedDevices) { device in
                            hidDeviceRow(device)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .frame(maxHeight: 300)
            }
            
            // 蓝牙设备不支持提示
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.text3)
                Text(L.Prefs.hidBluetoothNotSupported)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.xs)
            
            Spacer(minLength: DS.Spacing.md)
        }
        .frame(width: 380, height: 320)
        .background(DS.Colors.bg1)
    }
    
    private func hidDeviceRow(_ device: HIDDeviceInfo) -> some View {
        let isSelected = viewModel.selectedHIDDevice?.id == device.id
        
        return Button(action: { viewModel.selectHIDDevice(device) }) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    // 活动指示灯
                    Circle()
                        .fill(device.isActive ? Color.green : DS.Colors.text3.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: device.isActive)
                    
                    Image(systemName: "keyboard")
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? DS.Colors.text1 : DS.Colors.icon)
                        .frame(width: 24)
                    
                    Text(device.name)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isSelected {
                        Text(L.Prefs.hidPressKey)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.statusWarning)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(isSelected ? DS.Colors.highlight : Color.clear)
                .cornerRadius(DS.Layout.cornerRadius)
            }
        }
        .buttonStyle(.plain)
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

    // MARK: - Update Section
    
    private var updateSection: some View {
        MinimalSettingsSection(title: L.Prefs.checkUpdate, icon: "arrow.triangle.2.circlepath") {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.Prefs.currentVersion)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .font(DS.Typography.caption)
                        .foregroundColor(dashboardState.isDebugModeEnabled ? DS.Colors.statusWarning : DS.Colors.text2)
                        .onTapGesture {
                            handleVersionTap()
                        }
                }
                
                Spacer()
                
                if showDebugToast {
                    Text(dashboardState.isDebugModeEnabled ? "🐛 Debug ON" : "Debug OFF")
                        .font(DS.Typography.mono(10, weight: .medium))
                        .foregroundColor(DS.Colors.text2)
                        .transition(.opacity)
                }
                
                Button(action: {
                    NotificationCenter.default.post(name: .checkForUpdates, object: nil)
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text(L.Prefs.checkUpdate)
                            .font(DS.Typography.caption)
                    }
                    .foregroundColor(DS.Colors.text1)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)
        }
    }
    
    private func handleVersionTap() {
        let now = Date()
        // 超过 3 秒重置计数
        if now.timeIntervalSince(lastTapTime) > 3.0 {
            versionTapCount = 0
        }
        lastTapTime = now
        versionTapCount += 1
        
        if versionTapCount >= 10 {
            versionTapCount = 0
            withAnimation(.easeInOut(duration: 0.2)) {
                dashboardState.isDebugModeEnabled.toggle()
                showDebugToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showDebugToast = false }
            }
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

    // MARK: - Default Combo Key Helpers

    private var defaultComboKey1Label: String {
        if viewModel.isRecordingDefaultCombo && viewModel.defaultComboStep == 1 {
            return L.Skill.comboKeyRecord
        }
        if let k1 = viewModel.defaultComboKey1 {
            return comboKeyDisplayName(k1)
        }
        return L.Skill.comboKeyEmpty
    }

    private var defaultComboKey2Label: String {
        if viewModel.isRecordingDefaultCombo && viewModel.defaultComboStep == 2 {
            return L.Skill.comboKeyRecord
        }
        if let k2 = viewModel.defaultComboKey2 {
            return comboKeyDisplayName(k2)
        }
        return L.Skill.comboKeyEmpty
    }

    @ViewBuilder
    private func comboRecorderBox(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DS.Typography.mono(10, weight: .medium))
                .foregroundColor(isActive ? DS.Colors.statusWarning : DS.Colors.text2)
                .frame(minWidth: 40)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.xs)
                .background(isActive ? DS.Colors.statusWarning.opacity(0.1) : DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
    }

    private func startDefaultComboMonitor() {
        stopDefaultComboMonitor()
        comboKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let kc = event.keyCode
            if kc == 53 { // ESC
                viewModel.cancelDefaultComboRecording()
                return nil
            }
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if event.type == .flagsChanged {
                guard modifierKeyCodes.contains(kc) else { return event }
            }
            let display = comboKeyDisplayName(kc)
            viewModel.recordDefaultComboKey(keyCode: kc, displayName: display)
            return nil
        }
    }

    private func stopDefaultComboMonitor() {
        if let monitor = comboKeyMonitor {
            NSEvent.removeMonitor(monitor)
            comboKeyMonitor = nil
        }
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
