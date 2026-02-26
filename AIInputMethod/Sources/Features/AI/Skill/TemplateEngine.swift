import Foundation

/// 模板引擎：替换 system_prompt 中的 {{config.xxx}} 和 {{context.xxx}} 占位符
struct TemplateEngine {
    /// 匹配 {{config.xxx}} 格式的占位符
    private static let configPattern = try! NSRegularExpression(
        pattern: #"\{\{config\.([a-zA-Z_][a-zA-Z0-9_]*)\}\}"#
    )

    /// 匹配 {{context.xxx}} 格式的占位符
    private static let contextPattern = try! NSRegularExpression(
        pattern: #"\{\{context\.([a-zA-Z_][a-zA-Z0-9_]*)\}\}"#
    )

    /// 替换模板中的 {{config.xxx}} 占位符（向后兼容）
    /// - Parameters:
    ///   - template: 包含占位符的模板字符串
    ///   - config: 键值对配置参数
    /// - Returns: 替换后的字符串；未定义的占位符保留原文
    static func resolve(template: String, config: [String: String]) -> String {
        return resolve(template: template, config: config, context: [:])
    }

    /// 替换模板中的 {{config.xxx}} 和 {{context.xxx}} 占位符
    /// - Parameters:
    ///   - template: 包含占位符的模板字符串
    ///   - config: 来自 SKILL.md frontmatter 的静态配置
    ///   - context: 运行时动态数据（用户档案、选中文本等）
    /// - Returns: 替换后的字符串；未定义的占位符保留原文
    static func resolve(template: String, config: [String: String], context: [String: String]) -> String {
        var result = template

        // 替换 {{config.xxx}}
        result = replaceMatches(in: result, pattern: configPattern, values: config)

        // 替换 {{context.xxx}}
        result = replaceMatches(in: result, pattern: contextPattern, values: context)

        return result
    }

    // MARK: - Private

    private static func replaceMatches(
        in template: String,
        pattern: NSRegularExpression,
        values: [String: String]
    ) -> String {
        let nsTemplate = template as NSString
        let range = NSRange(location: 0, length: nsTemplate.length)
        let matches = pattern.matches(in: template, range: range)

        var result = template
        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template),
                  let fullRange = Range(match.range(at: 0), in: template) else {
                continue
            }
            let key = String(template[keyRange])
            if let value = values[key] {
                result.replaceSubrange(fullRange, with: value)
            }
        }
        return result
    }
}
