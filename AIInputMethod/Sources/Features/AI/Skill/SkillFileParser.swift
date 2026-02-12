import Foundation

// MARK: - Skill File Parser

/// SKILL.md 文件解析器
/// 格式：YAML frontmatter（--- 分隔）+ markdown body
struct SkillFileParser {

    enum ParseError: LocalizedError {
        case missingFrontmatter
        case missingRequiredField(String)
        case invalidSkillType(String)

        var errorDescription: String? {
            switch self {
            case .missingFrontmatter:
                return "SKILL.md missing YAML frontmatter (--- delimiters)"
            case .missingRequiredField(let field):
                return "SKILL.md missing required field: \(field)"
            case .invalidSkillType(let value):
                return "Invalid skill_type: \(value)"
            }
        }
    }

    // MARK: - Parse

    /// 解析 SKILL.md 文件内容为 SkillModel
    static func parse(_ content: String) throws -> SkillModel {
        let (yaml, body) = try splitFrontmatter(content)
        let fields = parseYAML(yaml)

        // 必填字段
        guard let id = fields["id"] else {
            throw ParseError.missingRequiredField("id")
        }
        guard let name = fields["name"] else {
            throw ParseError.missingRequiredField("name")
        }
        guard let description = fields["description"] else {
            throw ParseError.missingRequiredField("description")
        }
        guard let icon = fields["icon"] else {
            throw ParseError.missingRequiredField("icon")
        }
        guard let skillTypeRaw = fields["skill_type"] else {
            throw ParseError.missingRequiredField("skill_type")
        }
        guard let skillType = SkillType(rawValue: skillTypeRaw) else {
            throw ParseError.invalidSkillType(skillTypeRaw)
        }
        guard let isBuiltinStr = fields["is_builtin"] else {
            throw ParseError.missingRequiredField("is_builtin")
        }
        guard let isEditableStr = fields["is_editable"] else {
            throw ParseError.missingRequiredField("is_editable")
        }

        // 可选：修饰键绑定
        var modifierKey: ModifierKeyBinding? = nil
        if let keyCodeStr = fields["modifier_key_code"],
           let keyCode = UInt16(keyCodeStr),
           let isSystemStr = fields["modifier_key_is_system"],
           let displayName = fields["modifier_key_display"] {
            modifierKey = ModifierKeyBinding(
                keyCode: keyCode,
                isSystemModifier: isSystemStr == "true",
                displayName: displayName
            )
        }

        // 可选：行为配置
        let behaviorConfig = parseBehaviorConfig(fields)

        return SkillModel(
            id: id,
            name: name,
            description: description,
            icon: icon,
            modifierKey: modifierKey,
            promptTemplate: body.trimmingCharacters(in: .whitespacesAndNewlines),
            behaviorConfig: behaviorConfig,
            isBuiltin: isBuiltinStr == "true",
            isEditable: isEditableStr == "true",
            skillType: skillType
        )
    }

    // MARK: - Print

    /// 将 SkillModel 序列化为 SKILL.md 文件内容
    static func print(_ skill: SkillModel) -> String {
        var lines: [String] = ["---"]

        lines.append("id: \"\(skill.id)\"")
        lines.append("name: \"\(escapeYAMLString(skill.name))\"")
        lines.append("description: \"\(escapeYAMLString(skill.description))\"")
        lines.append("icon: \"\(skill.icon)\"")

        if let binding = skill.modifierKey {
            lines.append("modifier_key_code: \(binding.keyCode)")
            lines.append("modifier_key_is_system: \(binding.isSystemModifier)")
            lines.append("modifier_key_display: \"\(escapeYAMLString(binding.displayName))\"")
        }

        lines.append("skill_type: \"\(skill.skillType.rawValue)\"")
        lines.append("is_builtin: \(skill.isBuiltin)")
        lines.append("is_editable: \(skill.isEditable)")

        if !skill.behaviorConfig.isEmpty {
            lines.append("behavior_config:")
            for (key, value) in skill.behaviorConfig.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(key): \"\(escapeYAMLString(value))\"")
            }
        }

        lines.append("---")
        lines.append("")

        if !skill.promptTemplate.isEmpty {
            lines.append(skill.promptTemplate)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    /// 分离 YAML frontmatter 和 markdown body
    private static func splitFrontmatter(_ content: String) throws -> (yaml: String, body: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            throw ParseError.missingFrontmatter
        }

        // 找第二个 ---
        let afterFirst = trimmed.dropFirst(3)
        guard let endRange = afterFirst.range(of: "\n---") else {
            throw ParseError.missingFrontmatter
        }

        let yaml = String(afterFirst[afterFirst.startIndex..<endRange.lowerBound])
        let bodyStart = afterFirst[endRange.upperBound...]
        let body = String(bodyStart)

        return (yaml, body)
    }

    /// 简易 YAML 解析（key: value 格式，支持 behavior_config 嵌套）
    private static func parseYAML(_ yaml: String) -> [String: String] {
        var fields: [String: String] = [:]
        var currentSection: String? = nil

        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 缩进行 = behavior_config 子项
            if line.hasPrefix("  ") && currentSection == "behavior_config" {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    fields["bc.\(key)"] = stripQuotes(value)
                }
                continue
            }

            currentSection = nil

            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if key == "behavior_config" && rawValue.isEmpty {
                currentSection = "behavior_config"
                continue
            }

            fields[key] = stripQuotes(rawValue)
        }

        return fields
    }

    /// 从 fields 中提取 behavior_config（bc. 前缀的 key）
    private static func parseBehaviorConfig(_ fields: [String: String]) -> [String: String] {
        var config: [String: String] = [:]
        for (key, value) in fields {
            if key.hasPrefix("bc.") {
                let configKey = String(key.dropFirst(3))
                config[configKey] = value
            }
        }
        return config
    }

    /// 去除引号
    private static func stripQuotes(_ value: String) -> String {
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            var inner = String(value.dropFirst().dropLast())
            inner = inner.replacingOccurrences(of: "\\\"", with: "\"")
            inner = inner.replacingOccurrences(of: "\\\\", with: "\\")
            return inner
        }
        return value
    }

    /// 转义 YAML 字符串中的特殊字符
    private static func escapeYAMLString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
