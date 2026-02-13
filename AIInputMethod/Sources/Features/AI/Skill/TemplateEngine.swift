import Foundation

/// 模板引擎：替换 system_prompt 中的 {{config.xxx}} 占位符
struct TemplateEngine {
    /// 匹配 {{config.xxx}} 格式的占位符
    private static let pattern = try! NSRegularExpression(
        pattern: #"\{\{config\.([a-zA-Z_][a-zA-Z0-9_]*)\}\}"#
    )

    /// 替换模板中的 {{config.xxx}} 占位符
    /// - Parameters:
    ///   - template: 包含占位符的模板字符串
    ///   - config: 键值对配置参数
    /// - Returns: 替换后的字符串；未定义的占位符保留原文
    static func resolve(template: String, config: [String: String]) -> String {
        let nsTemplate = template as NSString
        let range = NSRange(location: 0, length: nsTemplate.length)
        let matches = Self.pattern.matches(in: template, range: range)

        // 从后往前替换，避免偏移量变化
        var result = template
        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template),
                  let fullRange = Range(match.range(at: 0), in: template) else {
                continue
            }
            let key = String(template[keyRange])
            if let value = config[key] {
                result.replaceSubrange(fullRange, with: value)
            }
            // 未定义的 key → 保留原文，不做任何操作
        }
        return result
    }
}
