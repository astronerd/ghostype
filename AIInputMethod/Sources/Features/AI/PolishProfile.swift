import Foundation

// MARK: - Polish Profile

/// 润色配置文件枚举
/// 定义 5 种预设润色风格，每种风格对应 Block 4 的不同 Tone 配置
/// Block 1（核心润色规则）是统一的，不随 Profile 变化
/// 自定义风格使用 CustomProfile 结构体单独管理
enum PolishProfile: String, CaseIterable, Identifiable {
    /// 默认：去口语化、修语法、保原意
    case standard = "默认"
    
    /// 专业：正式书面语，适合邮件、报告
    case professional = "专业"
    
    /// 活泼：保留口语感，轻松社交风格
    case casual = "活泼"
    
    /// 简洁：精简压缩，提炼核心
    case concise = "简洁"
    
    /// 创意：润色+美化，增加修辞
    case creative = "创意"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Properties
    
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
    
    /// Block 4 Tone Prompt - 语气配置
    /// 注意：这只是 Tone 部分，完整 Prompt 由 PromptBuilder 拼接
    /// （Role + Block 1 + Block 2 + Block 3 + Tone）
    var prompt: String {
        return PromptTemplates.toneForProfile(self)
    }
}
