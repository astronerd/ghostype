import Foundation

// MARK: - Translate Language

/// 翻译语言枚举（已废弃，新代码请使用 SkillModel.config["source_language"/"target_language"]）
/// 保留用于 AppSettings、PreferencesViewModel 向后兼容
enum TranslateLanguage: String, CaseIterable {
    case chineseEnglish = "chineseEnglish"
    case chineseJapanese = "chineseJapanese"
    case chineseKorean = "chineseKorean"
    case chineseFrench = "chineseFrench"
    case chineseGerman = "chineseGerman"
    case chineseSpanish = "chineseSpanish"
    case chineseRussian = "chineseRussian"
    case englishJapanese = "englishJapanese"
    case englishKorean = "englishKorean"
    case auto = "auto"

    // MARK: - Migration

    private static let migrationMap: [String: String] = [
        "中英互译": "chineseEnglish",
        "中日互译": "chineseJapanese",
        "自动检测": "auto"
    ]

    static func migrate(oldValue: String) -> TranslateLanguage? {
        if let language = TranslateLanguage(rawValue: oldValue) {
            return language
        }
        if let newRawValue = migrationMap[oldValue] {
            return TranslateLanguage(rawValue: newRawValue)
        }
        return nil
    }

    // MARK: - Properties

    var displayName: String {
        switch self {
        case .chineseEnglish: return L.Translate.chineseEnglish
        case .chineseJapanese: return L.Translate.chineseJapanese
        case .chineseKorean: return L.Translate.chineseKorean
        case .chineseFrench: return L.Translate.chineseFrench
        case .chineseGerman: return L.Translate.chineseGerman
        case .chineseSpanish: return L.Translate.chineseSpanish
        case .chineseRussian: return L.Translate.chineseRussian
        case .englishJapanese: return L.Translate.englishJapanese
        case .englishKorean: return L.Translate.englishKorean
        case .auto: return L.Translate.auto
        }
    }

    var prompt: String {
        switch self {
        case .chineseEnglish:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成英文；如果是英文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .chineseJapanese:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成日文；如果是日文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .chineseKorean:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成韩文；如果是韩文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .chineseFrench:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成法文；如果是法文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .chineseGerman:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成德文；如果是德文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .chineseSpanish:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成西班牙文；如果是西班牙文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .chineseRussian:
            return "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成俄文；如果是俄文，翻译成中文。只输出翻译结果，不要有任何解释。"
        case .englishJapanese:
            return "You are a professional translator. Translate the user's text. If it's English, translate to Japanese; if it's Japanese, translate to English. Output only the translation, no explanation."
        case .englishKorean:
            return "You are a professional translator. Translate the user's text. If it's English, translate to Korean; if it's Korean, translate to English. Output only the translation, no explanation."
        case .auto:
            return "你是一个专业的翻译员。自动检测源语言，翻译成中文（如果源语言是中文则翻译成英文）。只输出翻译结果，不要有任何解释。"
        }
    }
}
