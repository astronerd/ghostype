import SwiftUI
import AppKit

// MARK: - App Settings

/// 全局应用设置
/// 支持用户自定义快捷键、Prompt、模式配置等
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - 快捷键设置
    
    /// 主触发键修饰符
    @Published var hotkeyModifiers: NSEvent.ModifierFlags {
        didSet { saveToUserDefaults() }
    }
    
    /// 主触发键 keyCode
    @Published var hotkeyKeyCode: UInt16 {
        didSet { saveToUserDefaults() }
    }
    
    /// 快捷键显示文本
    @Published var hotkeyDisplay: String {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - 模式修饰键设置
    
    /// 翻译模式修饰键 (默认 Shift)
    @Published var translateModifier: NSEvent.ModifierFlags {
        didSet { saveToUserDefaults() }
    }
    
    /// 随心记模式修饰键 (默认 Command)
    @Published var memoModifier: NSEvent.ModifierFlags {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - AI 功能开关
    
    /// 是否启用 AI 润色（关闭则直接粘贴原文）
    @Published var enableAIPolish: Bool {
        didSet { saveToUserDefaults() }
    }
    
    /// 自动润色长度阈值（默认 20 字符）
    @Published var polishThreshold: Int {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - AI Prompt 设置
    
    /// 润色 Prompt（只保留润色的自定义 Prompt）
    @Published var polishPrompt: String {
        didSet { saveToUserDefaults() }
    }
    
    /// 翻译语言选项（中英互译、中日互译）
    @Published var translateLanguage: DoubaoLLMService.TranslateLanguage {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - 其他设置
    
    /// 自动模式（聚焦输入框时自动录音）
    @Published var autoStartOnFocus: Bool {
        didSet { saveToUserDefaults() }
    }
    
    /// 开机自启动
    @Published var launchAtLogin: Bool {
        didSet { saveToUserDefaults() }
    }
    
    /// 录音开始提示音
    @Published var playStartSound: Bool {
        didSet { saveToUserDefaults() }
    }
    
    /// 上屏成功触觉反馈
    @Published var hapticFeedback: Bool {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - 通讯录热词设置
    
    /// 是否启用通讯录热词
    @Published var enableContactsHotwords: Bool {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - 自动回车设置
    
    /// 是否启用自动回车
    @Published var enableAutoEnter: Bool {
        didSet { saveToUserDefaults() }
    }
    
    /// 自动回车的应用 Bundle ID 列表
    @Published var autoEnterApps: [String] {
        didSet { saveToUserDefaults() }
    }
    
    // MARK: - 默认 Prompts
    
    static let defaultPolishPrompt = """
    你是一个专业的速记员和文字编辑。请将用户的语音转录文本进行润色。

    规则：
    1. 去除口语中的赘词（如"那个"、"额"、"然后"、"就是"、"嗯"）
    2. 修正明显的语法错误和标点符号
    3. 保持原意，不要添加或删除实质内容
    4. 不要回复任何解释性文字，只输出润色后的文本
    5. 如果输入是英文，保持英文输出；如果是中文，保持中文输出

    直接输出润色后的文本，不要有任何前缀或后缀。
    """
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyDisplay = "hotkeyDisplay"
        static let translateModifier = "translateModifier"
        static let memoModifier = "memoModifier"
        static let enableAIPolish = "enableAIPolish"
        static let polishThreshold = "polishThreshold"
        static let polishPrompt = "polishPrompt"
        static let translateLanguage = "translateLanguage"
        static let autoStartOnFocus = "autoStartOnFocus"
        static let launchAtLogin = "launchAtLogin"
        static let playStartSound = "playStartSound"
        static let hapticFeedback = "hapticFeedback"
        static let enableContactsHotwords = "enableContactsHotwords"
        static let enableAutoEnter = "enableAutoEnter"
        static let autoEnterApps = "autoEnterApps"
    }
    
    // MARK: - Initialization
    
    private init() {
        let defaults = UserDefaults.standard
        
        // 加载快捷键设置
        if let rawValue = defaults.object(forKey: Keys.hotkeyModifiers) as? UInt {
            hotkeyModifiers = NSEvent.ModifierFlags(rawValue: rawValue)
        } else {
            hotkeyModifiers = .option
        }
        
        let savedKeyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode))
        hotkeyKeyCode = savedKeyCode == 0 ? 58 : savedKeyCode
        
        hotkeyDisplay = defaults.string(forKey: Keys.hotkeyDisplay) ?? "Option"
        
        // 加载模式修饰键
        if let rawValue = defaults.object(forKey: Keys.translateModifier) as? UInt {
            translateModifier = NSEvent.ModifierFlags(rawValue: rawValue)
        } else {
            translateModifier = .shift
        }
        
        if let rawValue = defaults.object(forKey: Keys.memoModifier) as? UInt {
            memoModifier = NSEvent.ModifierFlags(rawValue: rawValue)
        } else {
            memoModifier = .command
        }
        
        // 加载 AI 功能开关（默认关闭）
        if defaults.object(forKey: Keys.enableAIPolish) != nil {
            enableAIPolish = defaults.bool(forKey: Keys.enableAIPolish)
        } else {
            enableAIPolish = false
        }
        
        // 加载润色阈值（默认 20 字符）
        let savedThreshold = defaults.integer(forKey: Keys.polishThreshold)
        polishThreshold = savedThreshold > 0 ? savedThreshold : 20
        
        // 加载润色 Prompt
        polishPrompt = defaults.string(forKey: Keys.polishPrompt) ?? Self.defaultPolishPrompt
        
        // 加载翻译语言选项
        if let savedLanguage = defaults.string(forKey: Keys.translateLanguage),
           let language = DoubaoLLMService.TranslateLanguage(rawValue: savedLanguage) {
            translateLanguage = language
        } else {
            translateLanguage = .chineseEnglish
        }
        
        // 加载其他设置
        autoStartOnFocus = defaults.bool(forKey: Keys.autoStartOnFocus)
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        playStartSound = defaults.bool(forKey: Keys.playStartSound)
        hapticFeedback = defaults.bool(forKey: Keys.hapticFeedback)
        
        // 加载通讯录热词设置（默认关闭）
        enableContactsHotwords = defaults.bool(forKey: Keys.enableContactsHotwords)
        
        // 加载自动回车设置（默认关闭）
        enableAutoEnter = defaults.bool(forKey: Keys.enableAutoEnter)
        autoEnterApps = defaults.stringArray(forKey: Keys.autoEnterApps) ?? []
    }
    
    // MARK: - Persistence
    
    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        
        defaults.set(hotkeyModifiers.rawValue, forKey: Keys.hotkeyModifiers)
        defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode)
        defaults.set(hotkeyDisplay, forKey: Keys.hotkeyDisplay)
        defaults.set(translateModifier.rawValue, forKey: Keys.translateModifier)
        defaults.set(memoModifier.rawValue, forKey: Keys.memoModifier)
        defaults.set(enableAIPolish, forKey: Keys.enableAIPolish)
        defaults.set(polishThreshold, forKey: Keys.polishThreshold)
        defaults.set(polishPrompt, forKey: Keys.polishPrompt)
        defaults.set(translateLanguage.rawValue, forKey: Keys.translateLanguage)
        defaults.set(autoStartOnFocus, forKey: Keys.autoStartOnFocus)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(playStartSound, forKey: Keys.playStartSound)
        defaults.set(hapticFeedback, forKey: Keys.hapticFeedback)
        defaults.set(enableContactsHotwords, forKey: Keys.enableContactsHotwords)
        defaults.set(enableAutoEnter, forKey: Keys.enableAutoEnter)
        defaults.set(autoEnterApps, forKey: Keys.autoEnterApps)
    }
    
    // MARK: - Reset
    
    /// 重置润色 Prompt 为默认值
    func resetPrompts() {
        polishPrompt = Self.defaultPolishPrompt
    }
    
    /// 重置快捷键为默认值
    func resetHotkeys() {
        hotkeyModifiers = .option
        hotkeyKeyCode = 58
        hotkeyDisplay = "Option"
        translateModifier = .shift
        memoModifier = .command
    }
    
    // MARK: - Helper Methods
    
    /// 根据修饰键获取输入模式
    func modeFromModifiers(_ modifiers: NSEvent.ModifierFlags) -> InputMode {
        if modifiers.contains(memoModifier) {
            return .memo
        }
        if modifiers.contains(translateModifier) {
            return .translate
        }
        return .polish
    }
    
    /// 格式化修饰键为显示字符串
    static func formatModifier(_ modifier: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifier.contains(.control) { parts.append("⌃") }
        if modifier.contains(.option) { parts.append("⌥") }
        if modifier.contains(.shift) { parts.append("⇧") }
        if modifier.contains(.command) { parts.append("⌘") }
        if modifier.contains(.function) { parts.append("fn") }
        return parts.joined()
    }
    
    // MARK: - Auto Enter Helpers
    
    /// 检查当前应用是否需要自动回车
    func shouldAutoEnter(for bundleId: String?) -> Bool {
        guard enableAutoEnter, let bundleId = bundleId else { return false }
        return autoEnterApps.contains(bundleId)
    }
    
    /// 添加自动回车应用
    func addAutoEnterApp(_ bundleId: String) {
        if !autoEnterApps.contains(bundleId) {
            autoEnterApps.append(bundleId)
        }
    }
    
    /// 移除自动回车应用
    func removeAutoEnterApp(_ bundleId: String) {
        autoEnterApps.removeAll { $0 == bundleId }
    }
}
