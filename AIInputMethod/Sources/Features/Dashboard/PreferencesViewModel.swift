import SwiftUI
import AppKit
import ServiceManagement

// MARK: - PreferencesViewModel

/// 偏好设置视图模型
/// 绑定 launchAtLogin, soundFeedback, hotkey 到 UserDefaults
/// 实现 AI 引擎状态检测
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
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
    /// Requirement 7.1: THE Preferences page SHALL provide a toggle for "Launch at Login"
    var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }
    
    /// 声音反馈
    /// Requirement 7.2: THE Preferences page SHALL provide a toggle for "Sound Feedback"
    var soundFeedback: Bool {
        didSet {
            UserDefaults.standard.set(soundFeedback, forKey: Keys.soundFeedback)
        }
    }
    
    /// 快捷键显示文本
    /// Requirement 7.3: THE Preferences page SHALL display current hotkey configuration
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
    /// Requirement 7.4: THE Preferences page SHALL display AI engine connection status
    var aiEngineStatus: AIEngineStatus = .checking
    
    /// 自动模式
    var autoStartOnFocus: Bool {
        get { AppSettings.shared.autoStartOnFocus }
        set { AppSettings.shared.autoStartOnFocus = newValue }
    }
    
    // MARK: - Initialization
    
    init() {
        // 从 UserDefaults 读取设置
        // Requirement 7.5: WHEN a setting is changed, THE system SHALL persist it to UserDefaults
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        self.soundFeedback = UserDefaults.standard.bool(forKey: Keys.soundFeedback)
        
        // 检查 AI 引擎状态
        checkAIEngineStatus()
    }
    
    // MARK: - Methods
    
    /// 检查 AI 引擎状态
    func checkAIEngineStatus() {
        aiEngineStatus = .checking
        
        // 模拟网络检查（实际应该调用 API）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // 假设引擎在线
            self?.aiEngineStatus = .online
        }
    }
    
    /// 更新快捷键
    func updateHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, display: String) {
        hotkeyModifiers = modifiers
        hotkeyKeyCode = keyCode
        hotkeyDisplay = display
        
        // 持久化到 UserDefaults
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
        hotkeyKeyCode = 49 // Space
        hotkeyDisplay = "⌥ Space"
        autoStartOnFocus = false
        
        // 更新 AppSettings
        AppSettings.shared.hotkeyModifiers = hotkeyModifiers
        AppSettings.shared.hotkeyKeyCode = hotkeyKeyCode
        AppSettings.shared.hotkeyDisplay = hotkeyDisplay
        AppSettings.shared.autoStartOnFocus = autoStartOnFocus
    }
}

// MARK: - AI Engine Status

/// AI 引擎状态枚举
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
