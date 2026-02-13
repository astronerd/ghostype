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

// MARK: - Ghost Twin Status Response

/// Ghost Twin 状态响应
/// GET /api/v1/ghost-twin/status 返回
struct GhostTwinStatusResponse: Codable {
    let level: Int                          // 当前等级 1~10
    let total_xp: Int                       // 总经验值
    let current_level_xp: Int               // 当前等级内的经验值 (0~9999)
    let personality_tags: [String]          // 已捕捉的人格特征标签
    let challenges_remaining_today: Int     // 今日剩余校准挑战次数
    let personality_profile_version: Int    // 人格档案版本号
}

// MARK: - Calibration Challenge

/// 校准挑战类型
enum ChallengeType: String, Codable {
    case dilemma                            // 灵魂拷问，500 XP
    case reverseTuring = "reverse_turing"   // 找鬼游戏，300 XP
    case prediction                         // 预判赌局，200 XP
    
    /// 该类型挑战的 XP 奖励
    var xpReward: Int {
        switch self {
        case .dilemma: return 500
        case .reverseTuring: return 300
        case .prediction: return 200
        }
    }
}

/// 校准挑战
/// GET /api/v1/ghost-twin/challenge 返回
struct CalibrationChallenge: Codable, Identifiable {
    let id: String              // challenge_id
    let type: ChallengeType     // dilemma / reverse_turing / prediction
    let scenario: String        // 场景描述文本
    let options: [String]       // 2~3 个选项
    let xp_reward: Int          // 该类型的 XP 奖励
}

// MARK: - Calibration Answer Response

/// 校准答案响应
/// POST /api/v1/ghost-twin/challenge/answer 返回
struct CalibrationAnswerResponse: Codable {
    let xp_earned: Int                      // 本次获得的 XP
    let new_total_xp: Int                   // 新的总 XP
    let new_level: Int                      // 新的等级
    let ghost_response: String              // Ghost 的俏皮反馈语
    let personality_tags_updated: [String]  // 更新后的人格特征标签
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

