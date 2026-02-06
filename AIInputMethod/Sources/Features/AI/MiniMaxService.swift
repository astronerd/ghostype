import Foundation

// MARK: - MiniMax AI Service

/// MiniMax 2.1 AI 服务
/// 提供文本润色和翻译功能
class MiniMaxService {
    
    // MARK: - Singleton
    
    static let shared = MiniMaxService()
    
    // MARK: - Configuration
    
    /// API 配置 (加密存储)
    private let baseURL = "https://api.minimax.io/anthropic/v1/messages"
    private let model = "MiniMax-M2.1"
    
    /// 获取解密后的 API Key
    private var apiKey: String {
        // 使用简单的 Base64 编码存储，实际生产环境应使用 Keychain
        let encoded = "c2stYXBpLUdPT3E5emMzMEZpZ0lYX1BlbmJvaWo5bF9VQWtIT0lYV1dLTjRmN3JrWW82WDlTYk1UeDVEampWWV9lZTRBRUJHRDFkTDQxVU9vSEV2a0Y0amcweTAySW1XT2hENlBuMHkwRmZLZVk3X283NFUwY1I3TTJxMW8="
        guard let data = Data(base64Encoded: encoded),
              let key = String(data: data, encoding: .utf8) else {
            return ""
        }
        return key
    }
    
    // MARK: - Prompts
    
    /// 润色 Prompt
    private let polishSystemPrompt = """
    你是一个专业的速记员和文字编辑。请将用户的语音转录文本进行润色。

    规则：
    1. 去除口语中的赘词（如"那个"、"额"、"然后"、"就是"、"嗯"）
    2. 修正明显的语法错误和标点符号
    3. 保持原意，不要添加或删除实质内容
    4. 不要回复任何解释性文字，只输出润色后的文本
    5. 如果输入是英文，保持英文输出；如果是中文，保持中文输出

    直接输出润色后的文本，不要有任何前缀或后缀。
    """
    
    /// 翻译 Prompt
    private let translateSystemPrompt = """
    你是一个专业的翻译员。请翻译用户的文本。

    规则：
    1. 自动检测源语言
    2. 如果是中文，翻译成英文
    3. 如果是英文，翻译成中文
    4. 如果是其他语言，翻译成中文
    5. 只输出翻译结果，不要有任何解释或前缀
    6. 保持专业术语的准确性

    直接输出翻译后的文本。
    """
    
    /// 笔记整理 Prompt
    private let memoSystemPrompt = """
    你是一个专业的笔记整理助手。请将用户的语音备忘录整理成简洁的笔记。

    规则：
    1. 去除口语赘词
    2. 提取关键信息
    3. 如果内容较长，可以用简短的要点形式
    4. 保持原意，不要添加推测内容
    5. 只输出整理后的笔记内容

    直接输出整理后的笔记。
    """
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 处理文本
    /// - Parameters:
    ///   - text: 原始文本
    ///   - mode: 处理模式
    ///   - completion: 完成回调
    func process(text: String, mode: InputMode, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt: String
        switch mode {
        case .polish:
            systemPrompt = polishSystemPrompt
        case .translate:
            systemPrompt = translateSystemPrompt
        case .memo:
            systemPrompt = memoSystemPrompt
        }
        
        sendRequest(systemPrompt: systemPrompt, userMessage: text, completion: completion)
    }
    
    /// 润色文本
    func polish(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        process(text: text, mode: .polish, completion: completion)
    }
    
    /// 翻译文本
    func translate(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        process(text: text, mode: .translate, completion: completion)
    }
    
    /// 整理笔记
    func organizeMemo(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        process(text: text, mode: .memo, completion: completion)
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
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": userMessage
                        ]
                    ]
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
        request.httpBody = jsonData
        request.timeoutInterval = 30
        
        print("[MiniMax] Sending request...")
        
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
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 检查错误
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        print("[MiniMax] API error: \(message)")
                        DispatchQueue.main.async {
                            completion(.failure(MiniMaxError.apiError(message)))
                        }
                        return
                    }
                    
                    // 提取文本内容
                    if let content = json["content"] as? [[String: Any]] {
                        var resultText = ""
                        for block in content {
                            if let type = block["type"] as? String, type == "text",
                               let text = block["text"] as? String {
                                resultText += text
                            }
                        }
                        
                        if !resultText.isEmpty {
                            print("[MiniMax] Success: \(resultText.prefix(50))...")
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
