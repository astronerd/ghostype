import Foundation

// MARK: - Skill Prompt Generator

/// 将用户的简单指令生成为完整的、符合 tool calling 格式的 system prompt
/// 使用 builtin-prompt-generator skill 的 systemPrompt 作为 meta prompt 模板
struct SkillPromptGenerator {

    /// 生成完整的 system prompt
    /// - Parameters:
    ///   - skillName: Skill 名称
    ///   - skillDescription: Skill 描述
    ///   - userPrompt: 用户写的简单指令
    /// - Returns: 完整的、符合 tool calling 格式的 system prompt
    static func generate(
        skillName: String,
        skillDescription: String,
        userPrompt: String
    ) async throws -> String {
        // 从 SkillManager 读取 prompt-generator skill
        guard let generatorSkill = SkillManager.shared.skill(byId: SkillModel.builtinPromptGeneratorId) else {
            FileLogger.log("[SkillPromptGenerator] prompt-generator skill not found, using fallback")
            throw PromptGeneratorError.skillNotFound
        }

        // 用 TemplateEngine 替换模板变量
        let config: [String: String] = [
            "skill_name": skillName,
            "skill_description": skillDescription,
            "user_prompt": userPrompt,
        ]
        let metaPrompt = TemplateEngine.resolve(template: generatorSkill.systemPrompt, config: config)

        let result = try await GhostypeAPIClient.shared.executeSkill(
            systemPrompt: metaPrompt,
            message: "请根据以上信息生成完整的 system prompt。只输出 prompt 本身，不要加任何解释或 markdown 代码块标记。",
            context: .noInput
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Errors

    enum PromptGeneratorError: LocalizedError {
        case skillNotFound

        var errorDescription: String? {
            switch self {
            case .skillNotFound:
                return "Prompt generator skill not found. Please restart the app."
            }
        }
    }
}
