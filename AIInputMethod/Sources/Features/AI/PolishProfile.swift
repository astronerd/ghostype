import Foundation

// MARK: - Polish Profile

/// 润色配置文件枚举
/// 定义 5 种预设润色风格，每种风格对应 Block 4 的不同 Tone 配置
/// Block 1（核心润色规则）是统一的，不随 Profile 变化
/// 自定义风格使用 CustomProfile 结构体单独管理
///
/// rawValue 使用英文标识符，与 API 参数格式一致
/// UI 显示名称通过 `displayName` 属性获取（本地化）
enum PolishProfile: String, CaseIterable, Identifiable {
    /// 默认：去口语化、修语法、保原意
    case standard = "standard"
    
    /// 专业：正式书面语，适合邮件、报告
    case professional = "professional"
    
    /// 活泼：保留口语感，轻松社交风格
    case casual = "casual"
    
    /// 简洁：精简压缩，提炼核心
    case concise = "concise"
    
    /// 创意：润色+美化，增加修辞
    case creative = "creative"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Migration
    
    /// 旧中文 rawValue → 新英文 rawValue 的迁移映射
    private static let migrationMap: [String: String] = [
        "默认": "standard",
        "专业": "professional",
        "活泼": "casual",
        "简洁": "concise",
        "创意": "creative"
    ]
    
    /// 迁移旧中文 rawValue 为对应的 PolishProfile
    /// - Parameter oldValue: 旧的中文 rawValue（如 "默认"、"专业" 等）
    /// - Returns: 对应的 PolishProfile，如果无法匹配则返回 nil
    static func migrate(oldValue: String) -> PolishProfile? {
        // 先尝试直接用新英文 rawValue 初始化（已迁移的值）
        if let profile = PolishProfile(rawValue: oldValue) {
            return profile
        }
        // 再尝试从旧中文 rawValue 映射
        if let newRawValue = migrationMap[oldValue] {
            return PolishProfile(rawValue: newRawValue)
        }
        return nil
    }
    
    // MARK: - Properties
    
    /// UI 显示名称（中文）
    var displayName: String {
        switch self {
        case .standard:
            return "默认"
        case .professional:
            return "专业"
        case .casual:
            return "活泼"
        case .concise:
            return "简洁"
        case .creative:
            return "创意"
        }
    }
    
    /// 配置描述
    var description: String {
        switch self {
        case .standard:
            return "去口语化、修语法、保原意"
        case .professional:
            return "正式书面语，适合邮件、报告"
        case .casual:
            return "保留口语感，轻松社交风格"
        case .concise:
            return "精简压缩，提炼核心"
        case .creative:
            return "润色+美化，增加修辞"
        }
    }
    
    /// SF Symbol 图标名称
    var icon: String {
        switch self {
        case .standard: return "text.badge.checkmark"
        case .professional: return "briefcase"
        case .casual: return "face.smiling"
        case .concise: return "scissors"
        case .creative: return "paintbrush"
        }
    }
}
