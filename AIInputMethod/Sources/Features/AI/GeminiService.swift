import Foundation

// MARK: - Gemini AI Service

/// Google Gemini 2.5 Flash-Lite AI 服务
/// 使用 OpenAI 兼容 API
/// 参考: https://ai.google.dev/gemini-api/docs/openai
class GeminiService {
    
    // MARK: - Singleton
    
    static let shared = GeminiService()
    
    // MARK: - Configuration
    
    /// API 配置 - OpenAI 兼容格式
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
    private let model = "gemini-2.5-flash"
    
    /// API Key（从环境变量读取，支持 setenv 动态设置）
    private var apiKey: String {
        if let ptr = getenv("GEMINI_API_KEY") {
            return String(cString: ptr)
        }
        return ""
    }
    
    // MARK: - 翻译语言选项
    
    enum TranslateLanguage: String, CaseIterable {
        case chineseEnglish = "中英互译"
        case chineseJapanese = "中日互译"
        case auto = "自动检测"
        
        var displayName: String {
            return self.rawValue
        }
        
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
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 润色文本（简单路径，使用默认 polishPrompt）
    func polish(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt = AppSettings.shared.polishPrompt
        sendRequest(systemPrompt: systemPrompt, userMessage: text, completion: completion)
    }
    
    /// 使用配置文件进行润色（完整路径，支持 Block 2/3/Tone）
    func polishWithProfile(
        text: String,
        profile: PolishProfile,
        customPrompt: String?,
        enableInSentencePatterns: Bool,
        enableTriggerCommands: Bool,
        triggerWord: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 禁用润色时直接返回原文
        guard AppSettings.shared.enableAIPolish else {
            print("[Gemini] AI Polish disabled, returning original text")
            completion(.success(text))
            return
        }
        
        // 阈值判断：10 字以内不过 AI，直接返回原文
        let minThreshold = 10
        if text.count < minThreshold {
            print("[Gemini] Text too short (\(text.count) < \(minThreshold)), skipping AI")
            completion(.success(text))
            return
        }
        
        print("[Gemini] Processing: length=\(text.count), block2=\(enableInSentencePatterns), block3=\(enableTriggerCommands)")
        
        // 使用 PromptBuilder 构建动态 Prompt
        let systemPrompt = PromptBuilder.buildPrompt(
            profile: profile,
            customPrompt: customPrompt,
            enableInSentencePatterns: enableInSentencePatterns,
            enableTriggerCommands: enableTriggerCommands,
            triggerWord: triggerWord
        )
        
        sendRequest(systemPrompt: systemPrompt, userMessage: text, completion: completion)
    }
    
    /// 翻译文本
    func translate(text: String, language: TranslateLanguage = .chineseEnglish, completion: @escaping (Result<String, Error>) -> Void) {
        sendRequest(systemPrompt: language.prompt, userMessage: text, completion: completion)
    }
    
    /// 整理笔记（直接返回原文）
    func organizeMemo(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        completion(.success(text))
    }
    
    /// 使用自定义 Prompt 处理文本
    func processWithCustomPrompt(text: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendRequest(systemPrompt: prompt, userMessage: text, completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func sendRequest(systemPrompt: String, userMessage: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            completion(.failure(GeminiError.invalidAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(GeminiError.invalidURL))
            return
        }
        
        // OpenAI Chat Completions 格式
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "reasoning_effort": "none",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(GeminiError.serializationError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 30
        
        print("[Gemini] Sending request to \(baseURL)...")
        print("[Gemini] Model: \(model)")
        print("[Gemini] User message: \(userMessage.prefix(50))...")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Gemini] Network error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                print("[Gemini] No data received")
                DispatchQueue.main.async {
                    completion(.failure(GeminiError.noData))
                }
                return
            }
            
            // Debug: 打印原始响应
            if let rawString = String(data: data, encoding: .utf8) {
                print("[Gemini] Raw response: \(rawString.prefix(200))...")
            }
            
            // 解析响应 - OpenAI Chat Completions 格式
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 检查 error 字段
                    if let errorObj = json["error"] as? [String: Any],
                       let message = errorObj["message"] as? String {
                        print("[Gemini] API error: \(message)")
                        DispatchQueue.main.async {
                            completion(.failure(GeminiError.apiError(message)))
                        }
                        return
                    }
                    
                    // 提取文本内容 - OpenAI 格式: choices[0].message.content
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("[Gemini] ✅ Success: \(result.prefix(50))...")
                        DispatchQueue.main.async {
                            completion(.success(result))
                        }
                        return
                    }
                    
                    print("[Gemini] Unexpected response format: \(json)")
                    DispatchQueue.main.async {
                        completion(.failure(GeminiError.parseError))
                    }
                }
            } catch {
                print("[Gemini] JSON parse error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidAPIKey
    case invalidURL
    case serializationError
    case noData
    case parseError
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API Key 无效"
        case .invalidURL:
            return "URL 无效"
        case .serializationError:
            return "请求序列化失败"
        case .noData:
            return "未收到响应数据"
        case .parseError:
            return "响应解析失败"
        case .apiError(let message):
            return "API 错误: \(message)"
        }
    }
}
