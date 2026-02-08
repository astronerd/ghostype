import Foundation

// MARK: - Prompt Builder

/// Prompt 构建服务
/// 根据配置动态拼接 Block 1/2/3，生成最终的系统 Prompt
/// Requirements: 7.1, 7.2, 7.3, 7.4
class PromptBuilder {
    
    // MARK: - Build Prompt
    
    /// 构建完整的系统 Prompt
    /// - Parameters:
    ///   - profile: 润色配置文件
    ///   - customPrompt: 自定义 Prompt（仅当 profile 为 .custom 时使用）
    ///   - enableInSentencePatterns: 是否启用句内模式识别（Block 2）
    ///   - enableTriggerCommands: 是否启用句尾唤醒指令（Block 3）
    ///   - triggerWord: 唤醒词（用于替换 Block 3 中的 {{trigger_word}}）
    /// - Returns: 拼接后的完整系统 Prompt
    ///
    /// **Prompt 拼接规则：**
    /// - Block 1（基础润色）：始终包含，根据 Profile 选择对应的 Prompt
    /// - Block 2（句内模式识别）：仅当 enableInSentencePatterns 为 true 时追加
    /// - Block 3（句尾唤醒指令）：仅当 enableTriggerCommands 为 true 时追加，并替换 {{trigger_word}}
    static func buildPrompt(
        profile: PolishProfile,
        customPrompt: String?,
        enableInSentencePatterns: Bool,
        enableTriggerCommands: Bool,
        triggerWord: String
    ) -> String {
        var prompt = ""
        
        // Block 1: 基础润色 (Requirements 7.1)
        // 始终包含 Block 1，根据当前 Profile 选择
        if profile == .custom, let custom = customPrompt, !custom.isEmpty {
            prompt += custom
        } else {
            prompt += profile.prompt
        }
        
        // Block 2: 句内模式识别 (Requirements 7.2)
        // 仅当 enableInSentencePatterns 为 true 时追加
        if enableInSentencePatterns {
            prompt += "\n\n" + PromptTemplates.block2
        }
        
        // Block 3: 句尾唤醒指令 (Requirements 7.3, 7.4)
        // 仅当 enableTriggerCommands 为 true 时追加
        // 将 {{trigger_word}} 替换为实际唤醒词
        if enableTriggerCommands {
            let block3 = PromptTemplates.block3
                .replacingOccurrences(of: "{{trigger_word}}", with: triggerWord)
            prompt += "\n\n" + block3
        }
        
        return prompt
    }
}
