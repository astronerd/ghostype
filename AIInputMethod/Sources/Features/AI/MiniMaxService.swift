import Foundation

// MARK: - MiniMax AI Service

/// MiniMax 2.1 AI 服务
/// 提供文本润色和翻译功能
class MiniMaxService {
    
    // MARK: - Singleton
    
    static let shared = MiniMaxService()
    
    // MARK: - Configuration
    
    /// API 配置 - 使用 Anthropic 兼容 API
    private let baseURL = "https://api.minimax.io/anthropic/v1/messages"
    private let model = "MiniMax-M2.1"
    
    /// 获取解密后的 API Key
    private var apiKey: String {
        // 使用简单的 Base64 编码存储
        let encoded = "c2stYXBpLTI4bUtpWTVIYzUxZDVWVjJCRGdzQWFLSkZNTlFUNkFBNDdKZVNiRFE0d1o3SDBIX0pWeEdDUlRaV2RoUW92OHQzcXE5MU14UDBoZ3JFWFhmOHk1Y2VNeldhYjFCaGdHVDNmMTQ0UlRrYzdROW9RX3EzZ1ZlRlBJ"
        guard let data = Data(base64Encoded: encoded),
              let key = String(data: data, encoding: .utf8) else {
            return ""
        }
        return key
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 润色文本
    func polish(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt = AppSettings.shared.polishPrompt
        sendRequest(systemPrompt: systemPrompt, userMessage: text, completion: completion)
    }
    
    /// 翻译文本
    func translate(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt = "你是一个专业的翻译员。请翻译用户的文本。如果是中文，翻译成英文；如果是英文，翻译成中文。只输出翻译结果，不要有任何解释。"
        sendRequest(systemPrompt: systemPrompt, userMessage: text, completion: completion)
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
            completion(.failure(MiniMaxError.invalidAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(MiniMaxError.invalidURL))
            return
        }
        
        // 构建请求体 - Anthropic 兼容格式
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userMessage
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(MiniMaxError.serializationError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 30
        
        print("[MiniMax] Sending request to \(baseURL)...")
        print("[MiniMax] User message: \(userMessage.prefix(50))...")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[MiniMax] Network error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                print("[MiniMax] No data received")
                DispatchQueue.main.async {
                    completion(.failure(MiniMaxError.noData))
                }
                return
            }
            
            // Debug: 打印原始响应
            if let rawString = String(data: data, encoding: .utf8) {
                print("[MiniMax] Raw response: \(rawString.prefix(200))...")
            }
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 检查 base_resp 错误
                    if let baseResp = json["base_resp"] as? [String: Any],
                       let statusCode = baseResp["status_code"] as? Int,
                       statusCode != 0,
                       let statusMsg = baseResp["status_msg"] as? String {
                        print("[MiniMax] API error: \(statusMsg)")
                        DispatchQueue.main.async {
                            completion(.failure(MiniMaxError.apiError(statusMsg)))
                        }
                        return
                    }
                    
                    // 检查 error 字段
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        print("[MiniMax] API error: \(message)")
                        DispatchQueue.main.async {
                            completion(.failure(MiniMaxError.apiError(message)))
                        }
                        return
                    }
                    
                    // 提取文本内容 - Anthropic 格式
                    if let content = json["content"] as? [[String: Any]] {
                        var resultText = ""
                        for block in content {
                            if let type = block["type"] as? String, type == "text",
                               let text = block["text"] as? String {
                                resultText += text
                            }
                        }
                        
                        if !resultText.isEmpty {
                            print("[MiniMax] ✅ Success: \(resultText)")
                            DispatchQueue.main.async {
                                completion(.success(resultText))
                            }
                            return
                        }
                    }
                    
                    print("[MiniMax] Unexpected response format: \(json)")
                    DispatchQueue.main.async {
                        completion(.failure(MiniMaxError.parseError))
                    }
                }
            } catch {
                print("[MiniMax] JSON parse error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
}

// MARK: - Errors

enum MiniMaxError: LocalizedError {
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
