import Foundation

// MARK: - GhostypeAPIClient

/// GHOSTYPE 后端 API 客户端
/// 替代 GeminiService，统一处理润色/翻译/用户配置请求
class GhostypeAPIClient {

    static let shared = GhostypeAPIClient()

    // MARK: - Configuration

    /// API base URL（从 AppConfig 统一读取）
    var apiBaseURL: String { AppConfig.apiBaseURL }

    /// LLM 聊天请求超时（秒）
    private let llmTimeout: TimeInterval = 30

    /// 用户配置查询请求超时（秒）
    private let profileTimeout: TimeInterval = 10

    /// 认证服务（通过协议抽象，支持测试替身）
    private let auth: AuthProviding

    /// 生产用初始化（保持向后兼容）
    private init() {
        self.auth = AuthManager.shared
    }

    /// 测试用初始化（依赖注入）
    init(auth: AuthProviding) {
        self.auth = auth
    }

    // MARK: - Public API

    /// 润色文本
    /// - Parameters:
    ///   - text: 用户语音转写文本
    ///   - profile: 润色风格（standard/professional/casual/concise/creative/custom）
    ///   - customPrompt: 自定义语气提示（仅 profile 为 "custom" 时生效）
    ///   - enableInSentence: 启用句内指令识别
    ///   - enableTrigger: 启用唤醒词协议
    ///   - triggerWord: 唤醒词
    /// - Returns: 润色后的文本
    func polish(
        text: String,
        profile: String,
        customPrompt: String?,
        enableInSentence: Bool,
        enableTrigger: Bool,
        triggerWord: String
    ) async throws -> String {
        let body = GhostypeRequest(
            mode: "polish",
            message: text,
            profile: profile,
            custom_prompt: profile == "custom" ? customPrompt : nil,
            enable_in_sentence: enableInSentence,
            enable_trigger: enableTrigger,
            trigger_word: enableTrigger ? triggerWord : nil
        )

        let url = URL(string: "\(apiBaseURL)/api/v1/llm/chat")!
        var request = try buildRequest(url: url, method: "POST", timeout: llmTimeout)
        request.httpBody = try JSONEncoder().encode(body)

        let response: GhostypeResponse = try await performRequest(request, retryOn500: true)
        return response.text
    }

    /// 翻译文本
    /// - Parameters:
    ///   - text: 用户语音转写文本
    ///   - language: 翻译语言（chineseEnglish/chineseJapanese/auto）
    /// - Returns: 翻译后的文本
    func translate(
        text: String,
        language: String
    ) async throws -> String {
        let body = GhostypeRequest(
            mode: "translate",
            message: text,
            translate_language: language
        )

        let url = URL(string: "\(apiBaseURL)/api/v1/llm/chat")!
        var request = try buildRequest(url: url, method: "POST", timeout: llmTimeout)
        request.httpBody = try JSONEncoder().encode(body)

        let response: GhostypeResponse = try await performRequest(request, retryOn500: true)
        return response.text
    }

    /// 上报用量（语音输入上屏后调用）
    /// - Parameter characters: 本次上屏的字符数
    /// - Returns: 最新的 used 和 limit，可直接刷新能量环
    func reportUsage(characters: Int) async throws -> UsageReportResponse {
        let url = URL(string: "\(apiBaseURL)/api/v1/usage/report")!
        var request = try buildRequest(url: url, method: "POST", timeout: profileTimeout)
        request.httpBody = try JSONEncoder().encode(UsageReportRequest(characters: characters))

        return try await performRequest(request, retryOn500: true)
    }

    /// 获取用户配置和额度信息
    /// - Returns: 用户配置响应
    func fetchProfile() async throws -> ProfileResponse {
        let url = URL(string: "\(apiBaseURL)/api/v1/user/profile")!
        let request = try buildRequest(url: url, method: "GET", timeout: profileTimeout)

        return try await performRequest(request, retryOn500: true)
    }

    // MARK: - Internal Helpers

    /// 构建通用 URLRequest，添加公共 Header
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法（GET/POST）
    ///   - timeout: 超时时间（秒）
    /// - Returns: 配置好 Header 的 URLRequest
    func buildRequest(url: URL, method: String, timeout: TimeInterval) throws -> URLRequest {
        guard let token = auth.getToken() else {
            throw GhostypeError.unauthorized(L.Auth.loginRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout

        // 公共 Header
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DeviceIdManager.shared.deviceId, forHTTPHeaderField: "X-Device-Id")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    /// 执行请求并处理错误（含重试逻辑）
    /// - Parameters:
    ///   - request: 已配置的 URLRequest
    ///   - retryOn500: 是否对 500/502 状态码自动重试一次
    /// - Returns: 解码后的响应对象
    func performRequest<T: Decodable>(_ request: URLRequest, retryOn500: Bool) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw GhostypeError.timeout
        } catch {
            throw GhostypeError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GhostypeError.networkError(
                NSError(domain: "GhostypeAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
            )
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw GhostypeError.networkError(error)
            }

        case 401:
            // 清除 JWT，回退到 Device-Id 模式
            auth.handleUnauthorized()
            let errorResponse = try? JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            let message = errorResponse?.error.message ?? "Unauthorized"
            throw GhostypeError.unauthorized(message)

        case 429:
            let errorResponse = try? JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            let message = errorResponse?.error.message ?? "Quota exceeded"
            throw GhostypeError.quotaExceeded(message)

        case 400:
            let errorResponse = try? JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            let message = errorResponse?.error.message ?? "Invalid request"
            throw GhostypeError.invalidRequest(message)

        case 500, 502:
            // 自动重试一次
            if retryOn500 {
                return try await performRequest(request, retryOn500: false)
            }
            // 重试后仍然失败，返回最终错误
            let errorResponse = try? JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            let code = errorResponse?.error.code ?? (httpResponse.statusCode == 500 ? "INTERNAL_ERROR" : "UPSTREAM_ERROR")
            let message = errorResponse?.error.message ?? "Server error"
            throw GhostypeError.serverError(code: code, message: message)

        case 504:
            let errorResponse = try? JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            let message = errorResponse?.error.message ?? "Upstream timeout"
            throw GhostypeError.timeout

        default:
            let errorResponse = try? JSONDecoder().decode(GhostypeErrorResponse.self, from: data)
            let code = errorResponse?.error.code ?? "UNKNOWN_ERROR"
            let message = errorResponse?.error.message ?? "Unknown error (HTTP \(httpResponse.statusCode))"
            throw GhostypeError.serverError(code: code, message: message)
        }
    }
}

// MARK: - Ghost Twin API Extension

extension GhostypeAPIClient {

    /// 获取 Ghost Twin 状态
    /// GET /api/v1/ghost-twin/status
    /// - Returns: Ghost Twin 状态响应，包含等级、经验值、人格标签等
    func fetchGhostTwinStatus() async throws -> GhostTwinStatusResponse {
        let url = URL(string: "\(apiBaseURL)/api/v1/ghost-twin/status")!
        let request = try buildRequest(url: url, method: "GET", timeout: profileTimeout)

        return try await performRequest(request, retryOn500: true)
    }

    /// 获取当日校准挑战
    /// GET /api/v1/ghost-twin/challenge
    /// - Returns: 校准挑战，包含场景描述和选项
    func fetchCalibrationChallenge() async throws -> CalibrationChallenge {
        let url = URL(string: "\(apiBaseURL)/api/v1/ghost-twin/challenge")!
        let request = try buildRequest(url: url, method: "GET", timeout: profileTimeout)

        return try await performRequest(request, retryOn500: true)
    }

    /// 提交校准答案
    /// POST /api/v1/ghost-twin/challenge/answer
    /// - Parameters:
    ///   - challengeId: 挑战 ID
    ///   - selectedOption: 用户选择的选项索引（0-based）
    /// - Returns: 校准答案响应，包含获得的 XP、新等级、Ghost 反馈等
    func submitCalibrationAnswer(
        challengeId: String,
        selectedOption: Int
    ) async throws -> CalibrationAnswerResponse {
        let url = URL(string: "\(apiBaseURL)/api/v1/ghost-twin/challenge/answer")!
        var request = try buildRequest(url: url, method: "POST", timeout: profileTimeout)

        // 构建请求体
        let body: [String: Any] = [
            "challenge_id": challengeId,
            "selected_option": selectedOption
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await performRequest(request, retryOn500: true)
    }
}


// MARK: - Ghost Morph Skill API Extension

extension GhostypeAPIClient {

    /// Ghost Command：用户说出指令，AI 直接生成内容
    /// 使用固定 prompt，通过 /api/v1/llm/chat 端点
    func ghostCommand(text: String) async throws -> String {
        let body = GhostypeRequest(
            mode: "polish",
            message: text,
            profile: "custom",
            custom_prompt: "你是一个万能助手。用户会用语音告诉你一个任务，请直接完成任务并输出结果。不要解释你在做什么，直接给出结果。"
        )

        let url = URL(string: "\(apiBaseURL)/api/v1/llm/chat")!
        var request = try buildRequest(url: url, method: "POST", timeout: llmTimeout)
        request.httpBody = try JSONEncoder().encode(body)

        let response: GhostypeResponse = try await performRequest(request, retryOn500: true)
        return response.text
    }

    /// Ghost Twin Chat：以用户口吻和语言习惯回复
    /// 使用独立的 Ghost Twin 端点（不同于 /api/v1/llm/chat）
    func ghostTwinChat(text: String) async throws -> String {
        let url = URL(string: "\(apiBaseURL)/api/v1/ghost-twin/chat")!
        var request = try buildRequest(url: url, method: "POST", timeout: llmTimeout)

        let body: [String: Any] = ["message": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response: GhostypeResponse = try await performRequest(request, retryOn500: true)
        return response.text
    }
}

// MARK: - Skill Execute API Extension

extension GhostypeAPIClient {

    /// 通用 Skill 执行
    /// 调用 POST /api/v1/skill/execute（或 config 中指定的自定义端点）
    /// - Parameters:
    ///   - systemPrompt: Skill 的系统提示词（已完成模板变量替换）
    ///   - message: 用户语音文本
    ///   - context: 上下文行为（directOutput/rewrite/explain/noInput）
    ///   - endpoint: 自定义端点路径，默认 /api/v1/skill/execute
    /// - Returns: AI 生成的文本结果
    func executeSkill(
        systemPrompt: String,
        message: String,
        context: ContextBehavior,
        endpoint: String? = nil
    ) async throws -> String {
        let path = endpoint ?? "/api/v1/skill/execute"
        let url = URL(string: "\(apiBaseURL)\(path)")!

        let contextInfo = mapContextBehavior(context)
        let body = SkillExecuteRequest(
            system_prompt: systemPrompt,
            message: message,
            context: contextInfo
        )

        var request = try buildRequest(url: url, method: "POST", timeout: llmTimeout)
        request.httpBody = try JSONEncoder().encode(body)

        let response: GhostypeResponse = try await performRequest(request, retryOn500: true)
        return response.text
    }

    /// 将 ContextBehavior 枚举映射为 API 请求中的 ContextInfo
    private func mapContextBehavior(_ behavior: ContextBehavior) -> SkillExecuteRequest.ContextInfo {
        switch behavior {
        case .directOutput:
            return .init(type: "direct_output", selected_text: nil)
        case .rewrite(let selectedText):
            return .init(type: "rewrite", selected_text: selectedText)
        case .explain(let selectedText):
            return .init(type: "explain", selected_text: selectedText)
        case .noInput:
            return .init(type: "no_input", selected_text: nil)
        }
    }
}

