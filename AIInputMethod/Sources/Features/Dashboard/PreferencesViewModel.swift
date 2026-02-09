import SwiftUI
import AppKit
import ServiceManagement

// MARK: - PreferencesViewModel

/// 偏好设置视图模型
@Observable
class PreferencesViewModel {
    
    // MARK: - Permission Manager
    var permissionManager = PermissionManager()
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let soundFeedback = "soundFeedback"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
    }
    
    // MARK: - Properties
    
    /// 开机自启动
    var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }
    
    /// 声音反馈
    var soundFeedback: Bool {
        didSet {
            UserDefaults.standard.set(soundFeedback, forKey: Keys.soundFeedback)
        }
    }
    
    /// 快捷键显示文本
    var hotkeyDisplay: String {
        get { AppSettings.shared.hotkeyDisplay }
        set { AppSettings.shared.hotkeyDisplay = newValue }
    }
    
    /// 快捷键修饰键
    var hotkeyModifiers: NSEvent.ModifierFlags {
        get { AppSettings.shared.hotkeyModifiers }
        set { AppSettings.shared.hotkeyModifiers = newValue }
    }
    
    /// 快捷键键码
    var hotkeyKeyCode: UInt16 {
        get { AppSettings.shared.hotkeyKeyCode }
        set { AppSettings.shared.hotkeyKeyCode = newValue }
    }
    
    /// AI 引擎状态
    var aiEngineStatus: AIEngineStatus = .checking
    
    /// 自动模式
    var autoStartOnFocus: Bool {
        get { AppSettings.shared.autoStartOnFocus }
        set { AppSettings.shared.autoStartOnFocus = newValue }
    }
    
    /// 翻译模式修饰键
    var translateModifier: NSEvent.ModifierFlags {
        get { AppSettings.shared.translateModifier }
        set { AppSettings.shared.translateModifier = newValue }
    }
    
    /// 随心记模式修饰键
    var memoModifier: NSEvent.ModifierFlags {
        get { AppSettings.shared.memoModifier }
        set { AppSettings.shared.memoModifier = newValue }
    }
    
    /// AI 润色开关 - 使用存储属性以支持 @Observable 追踪
    var enableAIPolish: Bool {
        didSet {
            AppSettings.shared.enableAIPolish = enableAIPolish
        }
    }
    
    /// 自动润色阈值 - 使用存储属性以支持 @Observable 追踪
    var polishThreshold: Int {
        didSet {
            AppSettings.shared.polishThreshold = polishThreshold
        }
    }
    
    /// 润色 Prompt
    var polishPrompt: String {
        get { AppSettings.shared.polishPrompt }
        set { 
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AppSettings.shared.polishPrompt = newValue 
            }
        }
    }
    
    /// 翻译语言选项
    var translateLanguage: GeminiService.TranslateLanguage {
        get { AppSettings.shared.translateLanguage }
        set { AppSettings.shared.translateLanguage = newValue }
    }
    
    // MARK: - 通讯录热词
    
    /// 是否启用通讯录热词
    var enableContactsHotwords: Bool {
        didSet {
            AppSettings.shared.enableContactsHotwords = enableContactsHotwords
            if enableContactsHotwords {
                requestContactsAccessIfNeeded()
            }
        }
    }
    
    /// 通讯录授权状态
    var contactsAuthStatus: ContactsAuthStatus = .unknown
    
    /// 热词数量
    var hotwordsCount: Int = 0
    
    // MARK: - 自动回车
    
    /// 是否启用自动回车
    var enableAutoEnter: Bool {
        didSet {
            AppSettings.shared.enableAutoEnter = enableAutoEnter
            // 当用户打开此功能时，触发权限请求
            if enableAutoEnter {
                requestAppleScriptPermission()
            }
        }
    }
    
    /// AppleScript 自动化权限状态
    var isAppleScriptAuthorized: Bool = false
    
    // MARK: - 语言设置
    
    /// 应用语言
    var appLanguage: AppLanguage {
        didSet {
            AppSettings.shared.appLanguage = appLanguage
        }
    }
    
    /// 请求 AppleScript 自动化权限（用户点击授权按钮时调用）
    func requestAppleScriptPermission() {
        // 执行一个 osascript 命令来触发系统权限弹窗
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"System Events\" to key code 36"]
            try? process.run()
            process.waitUntilExit()
            
            // 授权后标记为已授权
            DispatchQueue.main.async {
                self.isAppleScriptAuthorized = true
            }
        }
    }
    
    /// 自动回车应用列表
    var autoEnterApps: [AutoEnterApp] = []
    
    // MARK: - Initialization
    
    init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        self.soundFeedback = UserDefaults.standard.bool(forKey: Keys.soundFeedback)
        // 从 AppSettings 加载初始值
        self.enableAIPolish = AppSettings.shared.enableAIPolish
        self.polishThreshold = AppSettings.shared.polishThreshold
        self.enableContactsHotwords = AppSettings.shared.enableContactsHotwords
        self.enableAutoEnter = AppSettings.shared.enableAutoEnter
        self.appLanguage = AppSettings.shared.appLanguage
        
        checkAIEngineStatus()
        loadContactsStatus()
        loadAutoEnterApps()
    }
    
    // MARK: - Methods
    
    /// 检查 AI 引擎状态
    func checkAIEngineStatus() {
        aiEngineStatus = .checking
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.aiEngineStatus = .online
        }
    }
    
    /// 更新快捷键
    func updateHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, display: String) {
        hotkeyModifiers = modifiers
        hotkeyKeyCode = keyCode
        hotkeyDisplay = display
        
        UserDefaults.standard.set(modifiers.rawValue, forKey: Keys.hotkeyModifiers)
        UserDefaults.standard.set(keyCode, forKey: Keys.hotkeyKeyCode)
    }
    
    /// 设置开机自启动
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[Preferences] Failed to set launch at login: \(error)")
            }
        }
    }
    
    /// 重置所有设置
    func resetToDefaults() {
        launchAtLogin = false
        soundFeedback = true
        hotkeyModifiers = .option
        hotkeyKeyCode = 49
        hotkeyDisplay = "⌥ Space"
        autoStartOnFocus = false
        translateModifier = .shift
        memoModifier = .command
        translateLanguage = .chineseEnglish
        enableAIPolish = false
        polishThreshold = 20
        enableContactsHotwords = false
        enableAutoEnter = false
        
        AppSettings.shared.hotkeyModifiers = hotkeyModifiers
        AppSettings.shared.hotkeyKeyCode = hotkeyKeyCode
        AppSettings.shared.hotkeyDisplay = hotkeyDisplay
        AppSettings.shared.autoStartOnFocus = autoStartOnFocus
        AppSettings.shared.translateModifier = translateModifier
        AppSettings.shared.memoModifier = memoModifier
        AppSettings.shared.translateLanguage = translateLanguage
        AppSettings.shared.autoEnterApps = []
        
        loadAutoEnterApps()
    }
    
    // MARK: - Contacts Hotwords
    
    func loadContactsStatus() {
        let status = ContactsManager.shared.authorizationStatus
        switch status {
        case .authorized:
            contactsAuthStatus = .authorized
            refreshHotwords()
        case .denied:
            contactsAuthStatus = .denied
        case .restricted:
            contactsAuthStatus = .restricted
        case .notDetermined:
            contactsAuthStatus = .notDetermined
        @unknown default:
            contactsAuthStatus = .unknown
        }
    }
    
    func requestContactsAccessIfNeeded() {
        guard contactsAuthStatus == .notDetermined else { return }
        
        ContactsManager.shared.requestAccess { [weak self] granted, _ in
            self?.contactsAuthStatus = granted ? .authorized : .denied
            if granted {
                self?.refreshHotwords()
            }
        }
    }
    
    func refreshHotwords() {
        ContactsManager.shared.fetchContactNames { [weak self] names in
            self?.hotwordsCount = names.count
        }
    }
    
    // MARK: - Auto Enter Apps
    
    func loadAutoEnterApps() {
        let bundleIds = AppSettings.shared.autoEnterApps
        autoEnterApps = bundleIds.compactMap { bundleId in
            if let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let appName = FileManager.default.displayName(atPath: appPath.path)
                let icon = NSWorkspace.shared.icon(forFile: appPath.path)
                return AutoEnterApp(bundleId: bundleId, name: appName, icon: icon)
            }
            return AutoEnterApp(bundleId: bundleId, name: bundleId, icon: nil)
        }
    }
    
    func addAutoEnterApp(bundleId: String) {
        AppSettings.shared.addAutoEnterApp(bundleId)
        loadAutoEnterApps()
    }
    
    func removeAutoEnterApp(bundleId: String) {
        AppSettings.shared.removeAutoEnterApp(bundleId)
        loadAutoEnterApps()
    }
    
    func addCurrentFrontmostApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else { return }
        
        // 不添加自己
        if bundleId == Bundle.main.bundleIdentifier { return }
        
        addAutoEnterApp(bundleId: bundleId)
    }
}

// MARK: - AI Engine Status

enum AIEngineStatus {
    case online
    case offline
    case checking
    
    var displayText: String {
        switch self {
        case .online: return "在线"
        case .offline: return "离线"
        case .checking: return "检测中..."
        }
    }
    
    var localizedText: String {
        switch self {
        case .online: return L.Prefs.aiEngineOnline
        case .offline: return L.Prefs.aiEngineOffline
        case .checking: return L.Prefs.aiEngineChecking
        }
    }
    
    var color: Color {
        switch self {
        case .online: return .green
        case .offline: return .red
        case .checking: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .online: return "checkmark.circle.fill"
        case .offline: return "xmark.circle.fill"
        case .checking: return "arrow.clockwise"
        }
    }
}

// MARK: - Contacts Auth Status

enum ContactsAuthStatus {
    case unknown
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var displayText: String {
        switch self {
        case .unknown: return L.Auth.unknown
        case .notDetermined: return L.Auth.notDetermined
        case .authorized: return L.Auth.authorized
        case .denied: return L.Auth.denied
        case .restricted: return L.Auth.restricted
        }
    }
    
    var color: Color {
        switch self {
        case .authorized: return .green
        case .denied, .restricted: return .red
        default: return .orange
        }
    }
}

// MARK: - Auto Enter App

struct AutoEnterApp: Identifiable {
    let id = UUID()
    let bundleId: String
    let name: String
    let icon: NSImage?
}
