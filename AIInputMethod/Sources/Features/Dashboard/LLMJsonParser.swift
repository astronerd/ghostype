import Foundation

// MARK: - LLMJsonParser

/// 解析 LLM 返回的 JSON（自动剥离 markdown 代码块）
enum LLMJsonParser {
    /// 解析 LLM 返回文本为指定类型
    /// 自动处理 ```json ... ``` 包裹
    static func parse<T: Decodable>(_ raw: String) throws -> T {
        let cleaned = stripMarkdownCodeBlock(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw LLMParseError.invalidEncoding(preview: String(raw.prefix(100)))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LLMParseError.invalidJSON(
                preview: String(raw.prefix(200)),
                underlying: error
            )
        }
    }

    /// 剥离 markdown 代码块标记
    static func stripMarkdownCodeBlock(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(
                of: #"^```(?:json|JSON)?\s*\n?"#, with: "", options: .regularExpression
            )
            cleaned = cleaned.replacingOccurrences(
                of: #"\n?```\s*$"#, with: "", options: .regularExpression
            )
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - LLMParseError

enum LLMParseError: LocalizedError {
    case invalidEncoding(preview: String)
    case invalidJSON(preview: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding(let preview):
            return "无法编码为 UTF-8: \(preview)"
        case .invalidJSON(let preview, let error):
            return "JSON 解析失败: \(error.localizedDescription)\n原始文本: \(preview)"
        }
    }
}
