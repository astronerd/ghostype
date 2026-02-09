import Foundation

// MARK: - Prompt Builder

/// Prompt 构建服务
/// 按照 Caching 友好的架构拼接 Prompt：
/// - 静态部分在前（Role + Block 1 + Block 2 + Block 3）→ 可被 LLM 缓存
/// - 动态部分在后（Block 4 Tone）→ 每次请求不同
class PromptBuilder {
    
    // MARK: - Build Prompt
    
    /// 构建完整的系统 Prompt
    /// - Parameters:
    ///   - profile: 润色配置文件（预设风格）
    ///   - customPrompt: 自定义 Prompt（非空时作为 Block 4 Tone，覆盖 profile 的 Tone）
    ///   - enableInSentencePatterns: 是否启用句内模式识别（Block 2）
    ///   - enableTriggerCommands: 是否启用句尾唤醒指令（Block 3）
    ///   - triggerWord: 唤醒词（用于替换 Block 3 中的 {{trigger_word}}）
    /// - Returns: 拼接后的完整系统 Prompt
    ///
    /// **Prompt 拼接架构（Caching 友好）：**
    /// ```
    /// [🔒 Static Head - 可缓存]
    /// Role Definition（三人专家组）
    /// Block 1（核心润色 + 语言协议）
    /// Block 2（文内流式指令 + 判别协议）← 可选
    /// Block 3（万能唤醒协议）← 可选
    ///
    /// [🔓 Dynamic Tail - 每次不同]
    /// Block 4（Tone 语气配置）
    /// ```
    static func buildPrompt(
        profile: PolishProfile,
        customPrompt: String?,
        enableInSentencePatterns: Bool,
        enableTriggerCommands: Bool,
        triggerWord: String
    ) -> String {
        var prompt = ""
        
        // === 🔒 Static Head (可缓存) ===
        
        // Role Definition: 三人专家组
        prompt += PromptTemplates.roleDefinition
        
        // Block 1: 核心润色 + 语言协议（始终包含）
        prompt += "\n\n" + PromptTemplates.block1
        
        // Block 2: 文内流式指令 + 判别协议（可选）
        if enableInSentencePatterns {
            prompt += "\n\n" + PromptTemplates.block2
        }
        
        // Block 3: 万能唤醒协议（可选）
        if enableTriggerCommands {
            let block3 = PromptTemplates.block3
                .replacingOccurrences(of: "{{trigger_word}}", with: triggerWord)
            prompt += "\n\n" + block3
        }
        
        // === 🔓 Dynamic Tail (每次不同) ===
        
        // Block 4: Tone 语气配置
        if let custom = customPrompt, !custom.isEmpty {
            // 自定义模式：使用用户自定义 Prompt 作为 Tone
            prompt += "\n\n### Block 4: Tone Configuration\n" + custom
        } else {
            let tone = PromptTemplates.toneForProfile(profile)
            if !tone.isEmpty {
                prompt += "\n\n### Block 4: Tone Configuration\n" + tone
            }
        }
        
        return prompt
    }
}
