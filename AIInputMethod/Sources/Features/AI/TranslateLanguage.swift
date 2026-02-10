import Foundation

// MARK: - Translate Language

/// 翻译语言枚举
/// 定义翻译模式的目标语言选项
///
/// rawValue 使用英文标识符，与 API 参数格式一致
/// UI 显示名称通过 `displayName` 属性获取（本地化）
enum TranslateLanguage: String, CaseIterable {
    /// 中英互译
    case chineseEnglish = "chineseEnglish"
    
    /// 中日互译
    case chineseJapanese = "chineseJapanese"
    
    /// 自动检测
    case auto = "auto"
    
    // MARK: - Migration
    
    /// 旧中文 rawValue → 新英文 rawValue 的迁移映射
    private static let migrationMap: [String: String] = [
        "中英互译": "chineseEnglish",
        "中日互译": "chineseJapanese",
        "自动检测": "auto"
    ]
    
    /// 迁移旧中文 rawValue 为对应的 TranslateLanguage
    /// - Parameter oldValue: 旧的中文 rawValue（如 "中英互译"、"中日互译" 等）
    /// - Returns: 对应的 TranslateLanguage，如果无法匹配则返回 nil
    static func migrate(oldValue: String) -> TranslateLanguage? {
        // 先尝试直接用新英文 rawValue 初始化（已迁移的值）
        if let language = TranslateLanguage(rawValue: oldValue) {
            return language
        }
        // 再尝试从旧中文 rawValue 映射
        if let newRawValue = migrationMap[oldValue] {
            return TranslateLanguage(rawValue: newRawValue)
        }
        return nil
    }
    
    // MARK: - Properties
    
    /// UI 显示名称（通过 L.xxx 本地化）
    var displayName: String {
        switch self {
        case .chineseEnglish:
            return L.Translate.chineseEnglish
        case .chineseJapanese:
            return L.Translate.chineseJapanese
        case .auto:
            return L.Translate.auto
        }
    }
    
    /// 翻译 Prompt（供本地翻译逻辑使用）
    var prompt: String {
        switch self {
        case .chineseEnglish:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成英文；如果是英文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .chineseJapanese:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成日文；如果是日文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .auto:
            return "你是一个专业的翻译员。自动检测源语言，翻译成中文（如果源语言是中文则翻译成英文）。只输出翻译结果，不要有任何解释。"
        }
    }
}
