import Foundation

// MARK: - API Request Model

/// GHOSTYPE API 请求体
/// 用于 POST /api/v1/llm/chat
struct GhostypeRequest: Codable {
    let mode: String              // "polish" | "translate"
    let message: String
    var profile: String?          // 仅 polish 模式
    var custom_prompt: String?    // 仅 profile == "custom" 时
    var enable_in_sentence: Bool?
    var enable_trigger: Bool?
    var trigger_word: String?
    var translate_language: String? // 仅 translate 模式
}

// MARK: - API Response Models

/// GHOSTYPE API 成功响应
/// HTTP 200 时返回
struct GhostypeResponse: Codable {
    let text: String
    let usage: Usage

    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

/// GHOSTYPE API 错误响应
/// HTTP 4xx/5xx 时返回
struct GhostypeErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let code: String
        let message: String
    }
}

// MARK: - User Profile Response Model

/// 用户配置响应
/// GET /api/v1/user/profile 返回
struct ProfileResponse: Codable {
    let subscription: SubscriptionInfo
    let usage: UsageInfo

    struct SubscriptionInfo: Codable {
        let plan: String              // "free" | "pro"
        let status: String?           // "active" | "canceled" | nil
        let is_lifetime_vip: Bool
        let current_period_end: String?
    }

    struct UsageInfo: Codable {
        let used: Int                 // 本周已用字符数
        let limit: Int                // 字符上限（-1 表示无限）
        let reset_at: String          // 下次重置时间
    }
}

// MARK: - Usage Report Models

/// 用量上报请求体
/// POST /api/v1/usage/report
struct UsageReportRequest: Codable {
    let characters: Int
}

/// 用量上报响应
/// 返回最新的 used 和 limit，可直接刷新能量环
struct UsageReportResponse: Codable {
    let used: Int
    let limit: Int
}

// MARK: - Error Enum

/// GHOSTYPE API 错误类型
enum GhostypeError: LocalizedError {
    case unauthorized(String)
    case quotaExceeded(String)
    case invalidRequest(String)
    case serverError(code: String, message: String)
    case timeout
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return "认证失败: \(message)"
        case .quotaExceeded(let message):
            return "额度超限: \(message)"
        case .invalidRequest(let message):
            return "请求无效: \(message)"
        case .serverError(let code, let message):
            return "服务器错误 [\(code)]: \(message)"
        case .timeout:
            return "请求超时"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - Skill Execute Request

/// Skill 执行请求体
/// 用于 POST /api/v1/skill/execute
struct SkillExecuteRequest: Codable {
    let system_prompt: String
    let message: String
    let context: ContextInfo

    struct ContextInfo: Codable {
        let type: String            // "direct_output" | "rewrite" | "explain" | "no_input"
        let selected_text: String?
    }
}

