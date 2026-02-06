import SwiftUI
import AppKit
import ServiceManagement

// MARK: - PreferencesViewModel

/// 偏好设置视图模型
@Observable
class PreferencesViewModel {
    
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
    var translateLanguage: DoubaoLLMService.TranslateLanguage {
        get { AppSettings.shared.translateLanguage }
        set { AppSettings.shared.translateLanguage = newValue }
    }
    
    // MARK: - Initialization
    
    init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        self.soundFeedback = UserDefaults.standard.bool(forKey: Keys.soundFeedback)
        // 从 AppSettings 加载初始值
        self.enableAIPolish = AppSettings.shared.enableAIPolish
        self.polishThreshold = AppSettings.shared.polishThreshold
        checkAIEngineStatus()
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
        
        AppSettings.shared.hotkeyModifiers = hotkeyModifiers
        AppSettings.shared.hotkeyKeyCode = hotkeyKeyCode
        AppSettings.shared.hotkeyDisplay = hotkeyDisplay
        AppSettings.shared.autoStartOnFocus = autoStartOnFocus
        AppSettings.shared.translateModifier = translateModifier
        AppSettings.shared.memoModifier = memoModifier
        AppSettings.shared.translateLanguage = translateLanguage
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
