import Foundation

// MARK: - Skill File Parser

struct SkillFileParser {

    // MARK: - Parse Result

    struct ParseResult: Equatable {
        let name: String
        let description: String
        let userPrompt: String
        let systemPrompt: String
        let allowedTools: [String]
        let config: [String: String]
        let legacyFields: LegacyFields?
    }

    struct LegacyFields: Equatable {
        let skillType: String?
        let icon: String?
        let colorHex: String?
        let modifierKeyCode: UInt16?
        let modifierKeyIsSystem: Bool?
        let modifierKeyDisplay: String?
        let isBuiltin: Bool?
        let isEditable: Bool?
        let behaviorConfig: [String: String]
    }

    // MARK: - Errors

    enum ParseError: LocalizedError {
        case missingFrontmatter
        case missingRequiredField(String)

        var errorDescription: String? {
            switch self {
            case .missingFrontmatter:
                return "SKILL.md missing YAML frontmatter (--- delimiters)"
            case .missingRequiredField(let field):
                return "SKILL.md missing required field: \(field)"
            }
        }
    }

    // MARK: - Parse

    /// Parse SKILL.md content into a ParseResult.
    /// Only `name` and `description` are required YAML frontmatter fields.
    /// The Markdown body becomes the system_prompt.
    /// The `directoryName` is used as the Skill's id (not from YAML).
    static func parse(_ content: String, directoryName: String) throws -> ParseResult {
        let (yaml, body) = try splitFrontmatter(content)
        let parsed = parseYAMLAdvanced(yaml)
        let fields = parsed.fields

        // Required fields
        guard let name = fields["name"] else {
            throw ParseError.missingRequiredField("name")
        }
        guard let description = fields["description"] else {
            throw ParseError.missingRequiredField("description")
        }

        // Optional: allowed_tools (string array)
        let allowedTools = parsed.arrayFields["allowed_tools"] ?? []

        // Optional: config (key-value pairs)
        let config = parsed.nestedFields["config"] ?? [:]

        // Optional: user_prompt (user's original instruction, for UI display)
        let userPrompt = fields["user_prompt"] ?? ""

        // System prompt from Markdown body
        let systemPrompt = body.trimmingCharacters(in: .whitespacesAndNewlines)

        // Legacy fields for backward compatibility
        let legacyFields = extractLegacyFields(fields: fields, nestedFields: parsed.nestedFields)

        return ParseResult(
            name: name,
            description: description,
            userPrompt: userPrompt,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools,
            config: config,
            legacyFields: legacyFields
        )
    }

    // MARK: - Print (Serialize)

    /// Serialize a ParseResult back to SKILL.md format (YAML frontmatter + Markdown body).
    /// Only outputs semantic fields: name, description, allowed_tools, config, and system prompt.
    /// Never outputs UI metadata fields (icon, color_hex, modifier_key_*, is_builtin, is_editable, skill_type, behavior_config).
    static func print(_ result: ParseResult) -> String {
        var lines: [String] = ["---"]

        // Required fields
        lines.append("name: \"\(escapeYAMLString(result.name))\"")
        lines.append("description: \"\(escapeYAMLString(result.description))\"")

        // Optional: user_prompt (user's original instruction)
        if !result.userPrompt.isEmpty {
            lines.append("user_prompt: \"\(escapeYAMLString(result.userPrompt))\"")
        }

        // Optional: allowed_tools (only if non-empty)
        if !result.allowedTools.isEmpty {
            lines.append("allowed_tools:")
            for tool in result.allowedTools {
                lines.append("  - \(tool)")
            }
        }

        // Optional: config (only if non-empty, sorted keys for deterministic output)
        if !result.config.isEmpty {
            lines.append("config:")
            for key in result.config.keys.sorted() {
                let value = result.config[key]!
                lines.append("  \(key): \"\(escapeYAMLString(value))\"")
            }
        }

        lines.append("---")

        // Body (systemPrompt) after closing --- with blank line separator
        if !result.systemPrompt.isEmpty {
            lines.append("")
            lines.append(result.systemPrompt)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private: Legacy Fields Extraction

    private static func extractLegacyFields(
        fields: [String: String],
        nestedFields: [String: [String: String]]
    ) -> LegacyFields? {
        let skillType = fields["skill_type"]
        let icon = fields["icon"]
        let colorHex = fields["color_hex"]
        let modifierKeyCode = fields["modifier_key_code"].flatMap { UInt16($0) }
        let modifierKeyIsSystem = fields["modifier_key_is_system"].map { $0 == "true" }
        let modifierKeyDisplay = fields["modifier_key_display"]
        let isBuiltin = fields["is_builtin"].map { $0 == "true" }
        let isEditable = fields["is_editable"].map { $0 == "true" }
        let behaviorConfig = nestedFields["behavior_config"] ?? [:]

        // Only create LegacyFields if at least one legacy field is present
        let hasLegacy = skillType != nil || icon != nil || colorHex != nil
            || modifierKeyCode != nil || modifierKeyIsSystem != nil
            || modifierKeyDisplay != nil || isBuiltin != nil
            || isEditable != nil || !behaviorConfig.isEmpty

        guard hasLegacy else { return nil }

        return LegacyFields(
            skillType: skillType,
            icon: icon,
            colorHex: colorHex,
            modifierKeyCode: modifierKeyCode,
            modifierKeyIsSystem: modifierKeyIsSystem,
            modifierKeyDisplay: modifierKeyDisplay,
            isBuiltin: isBuiltin,
            isEditable: isEditable,
            behaviorConfig: behaviorConfig
        )
    }

    // MARK: - Private: YAML Helpers

    /// Advanced YAML result supporting simple fields, arrays, and nested key-value sections.
    private struct YAMLParseResult {
        var fields: [String: String] = [:]
        var arrayFields: [String: [String]] = [:]
        var nestedFields: [String: [String: String]] = [:]
    }

    /// Parse YAML frontmatter supporting:
    /// - Simple key-value: `key: value` or `key: "value"`
    /// - Array fields: `key:\n  - item1\n  - item2`
    /// - Nested key-value: `key:\n  subkey: value`
    private static func parseYAMLAdvanced(_ yaml: String) -> YAMLParseResult {
        var result = YAMLParseResult()
        var currentKey: String? = nil
        var currentMode: String? = nil // "array" or "nested"

        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Check if this is an indented line (belongs to current section)
            let isIndented = line.hasPrefix("  ") || line.hasPrefix("\t")

            if isIndented, let key = currentKey {
                if currentMode == "array" {
                    // Array item: "  - value"
                    if trimmed.hasPrefix("- ") {
                        let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                        result.arrayFields[key, default: []].append(stripQuotes(value))
                    } else if trimmed.hasPrefix("-") {
                        let value = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                        result.arrayFields[key, default: []].append(stripQuotes(value))
                    }
                } else if currentMode == "nested" {
                    // Nested key-value: "  subkey: value"
                    if let colonIndex = trimmed.firstIndex(of: ":") {
                        let subKey = String(trimmed[trimmed.startIndex..<colonIndex])
                            .trimmingCharacters(in: .whitespaces)
                        let subValue = String(trimmed[trimmed.index(after: colonIndex)...])
                            .trimmingCharacters(in: .whitespaces)
                        result.nestedFields[key, default: [:]][subKey] = stripQuotes(subValue)
                    }
                }
                continue
            }

            // Top-level line: reset current section
            currentKey = nil
            currentMode = nil

            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex])
                .trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespaces)

            if rawValue.isEmpty {
                // This key has a block value (array or nested map) — we'll determine which
                // by looking at the next indented line. For now, set up as potential section.
                currentKey = key
                // Peek-ahead isn't easy line-by-line, so we use a heuristic:
                // known array fields vs known nested fields
                let knownArrayFields: Set<String> = ["allowed_tools"]
                let knownNestedFields: Set<String> = ["config", "behavior_config"]
                if knownArrayFields.contains(key) {
                    currentMode = "array"
                } else if knownNestedFields.contains(key) {
                    currentMode = "nested"
                } else {
                    // Default: try to detect from first indented line
                    // For now, treat unknown block keys as nested
                    currentMode = "nested"
                }
            } else {
                result.fields[key] = stripQuotes(rawValue)
            }
        }

        return result
    }

    /// Split content into YAML frontmatter and Markdown body.
    private static func splitFrontmatter(_ content: String) throws -> (yaml: String, body: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { throw ParseError.missingFrontmatter }

        let afterFirst = trimmed.dropFirst(3)
        guard let endRange = afterFirst.range(of: "\n---") else {
            throw ParseError.missingFrontmatter
        }

        let yaml = String(afterFirst[afterFirst.startIndex..<endRange.lowerBound])
        let bodyStart = afterFirst[endRange.upperBound...]
        let body = String(bodyStart)

        return (yaml, body)
    }

    /// Strip surrounding quotes from a YAML value.
    static func stripQuotes(_ value: String) -> String {
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            var inner = String(value.dropFirst().dropLast())
            inner = inner.replacingOccurrences(of: "\\\"", with: "\"")
            inner = inner.replacingOccurrences(of: "\\\\", with: "\\")
            return inner
        }
        return value
    }

    /// Escape special characters for YAML string output.
    static func escapeYAMLString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
