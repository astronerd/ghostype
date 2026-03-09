import Foundation

// MARK: - Hotkey Mode

/// 快捷键模式：singleKey（单键模式）或 comboKey（组合键模式）
/// 存储在 UserDefaults，key = "hotkeyMode"，默认值 singleKey
enum HotkeyMode: String, CaseIterable, Codable {
    /// 单键模式：一个全局快捷键触发录音，录音中按修饰键切换 Skill
    case singleKey = "singleKey"

    /// 组合键模式：每个 Skill 绑定独立的两键组合（key1 + key2），同时按住直接触发对应 Skill
    case comboKey = "comboKey"
}
