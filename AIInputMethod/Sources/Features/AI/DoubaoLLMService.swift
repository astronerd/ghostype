//
//  DoubaoLLMService.swift
//  AIInputMethod
//
//  豆包大模型服务 - 用于润色和翻译
//  使用 doubao-seed-1-6-flash-250828 模型
//

import Foundation

// MARK: - DoubaoLLMService

/// 豆包大模型服务
/// 提供文本润色和翻译功能
class DoubaoLLMService {
    
    static let shared = DoubaoLLMService()
    
    // MARK: - Configuration
    
    /// API 基础 URL
    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    
    /// API Key
    private let apiKey = "3b108766-4683-4948-8d84-862b104a5a3e"
    
    /// 模型名称
    private let modelName = "doubao-seed-1-6-flash-250828"
    
    private init() {}
    
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
    
    // MARK: - Public Methods
    
    /// 润色文本
    /// - Parameters:
    ///   - text: 原始文本
    ///   - customPrompt: 自定义 Prompt（可选）
    ///   - completion: 完成回调
    func polish(text: String, customPrompt: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt = customPrompt ?? AppSettings.shared.polishPrompt
        
        sendRequest(systemPrompt: systemPrompt, userMessage: text, completion: completion)
    }
    
    /// 翻译文本
    /// - Parameters:
    ///   - text: 原始文本
    ///   - language: 翻译语言选项
    ///   - completion: 完成回调
    func translate(text: String, language: TranslateLanguage = .chineseEnglish, completion: @escaping (Result<String, Error>) -> Void) {
        sendRequest(systemPrompt: language.prompt, userMessage: text, completion: completion)
    }
    
    /// 整理随心记（直接返回原文，不做 AI 处理）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - completion: 完成回调
    func organizeMemo(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 随心记不需要 AI 处理，直接返回原文
        completion(.success(text))
    }
    
    // MARK: - Profile-based Polish
    
    /// 使用配置文件进行润色
    /// - Parameters:
    ///   - text: 原始文本
    ///   - profile: 润色配置文件
    ///   - customPrompt: 自定义 Prompt（仅当 profile 为 .custom 时使用）
    ///   - enableInSentencePatterns: 是否启用句内模式识别（Block 2）
    ///   - enableTriggerCommands: 是否启用句尾唤醒指令（Block 3）
    ///   - triggerWord: 唤醒词
    ///   - completion: 完成回调
    ///
    /// **阈值逻辑**:
    /// - polishThreshold 只控制 Block 1（基础润色）
    /// - 如果开启了 Block 2 或 Block 3，即使文本长度 < 阈值也要调用 AI 处理
    /// - 只有当 Block 2 和 Block 3 都关闭，且文本 < 阈值时，才跳过 AI 调用
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
            print("[DoubaoLLM] AI Polish disabled, returning original text")
            completion(.success(text))
            return
        }
        
        // 判断是否需要调用 AI
        // - 如果开启了 Block 2（句内转写）或 Block 3（句末指令），必须调用 AI
        // - 如果都没开启，则阈值控制是否调用 AI
        let needsSmartCommands = enableInSentencePatterns || enableTriggerCommands
        let meetsThreshold = text.count >= AppSettings.shared.polishThreshold
        
        if !needsSmartCommands && !meetsThreshold {
            // 没有开启智能指令，且文本太短，跳过 AI 调用
            print("[DoubaoLLM] Text too short (\(text.count) < \(AppSettings.shared.polishThreshold)) and no smart commands enabled, skipping")
            completion(.success(text))
            return
        }
        
        print("[DoubaoLLM] Processing: length=\(text.count), threshold=\(AppSettings.shared.polishThreshold), block2=\(enableInSentencePatterns), block3=\(enableTriggerCommands)")
        
        // 使用 PromptBuilder 构建动态 Prompt
        let systemPrompt = PromptBuilder.buildPrompt(
            profile: profile,
            customPrompt: customPrompt,
            enableInSentencePatterns: enableInSentencePatterns,
            enableTriggerCommands: enableTriggerCommands,
            triggerWord: triggerWord
        )
        
        // 调用 LLM 进行润色
        sendRequest(systemPrompt: systemPrompt, userMessage: text, completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func sendRequest(systemPrompt: String, userMessage: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: baseURL) else {
            completion(.failure(DoubaoError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0.7,
            "max_tokens": 2048
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[DoubaoLLM] Network error: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(DoubaoError.noData))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        print("[DoubaoLLM] Success: \(content.prefix(50))...")
                        completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        // 打印原始响应用于调试
                        if let responseStr = String(data: data, encoding: .utf8) {
                            print("[DoubaoLLM] Unexpected response: \(responseStr)")
                        }
                        completion(.failure(DoubaoError.parseError))
                    }
                } catch {
                    print("[DoubaoLLM] Parse error: \(error)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// MARK: - Errors

enum DoubaoError: Error, LocalizedError {
    case invalidURL
    case noData
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .noData: return "没有返回数据"
        case .parseError: return "解析响应失败"
        }
    }
}
