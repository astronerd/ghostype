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
