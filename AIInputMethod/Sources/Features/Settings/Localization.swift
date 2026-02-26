import Foundation
import SwiftUI

// MARK: - Supported Languages

/// 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh"
    case english = "en"
    // 未来可扩展：
    // case japanese = "ja"
    // case korean = "ko"
    // case spanish = "es"
    // case french = "fr"
    
    var id: String { rawValue }
    
    /// 语言显示名称（用本地语言显示）
    var displayName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
    
    /// 语言的英文名称
    var englishName: String {
        switch self {
        case .chinese: return "Chinese (Simplified)"
        case .english: return "English"
        }
    }
    
    /// 语言图标
    var icon: String {
        switch self {
        case .chinese: return "🇨🇳"
        case .english: return "🇺🇸"
        }
    }
    
    /// 根据系统语言获取默认语言
    static var systemDefault: AppLanguage {
        let preferredLanguages = Locale.preferredLanguages
        for lang in preferredLanguages {
            if lang.hasPrefix("zh") {
                return .chinese
            }
            if lang.hasPrefix("en") {
                return .english
            }
        }
        // 默认英文
        return .english
    }
}

// MARK: - Localization Manager

/// 多语言管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            objectWillChange.send()
        }
    }
    
    private init() {
        // 从 UserDefaults 加载，如果没有则使用系统默认
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            currentLanguage = AppLanguage.systemDefault
        }
    }
}
