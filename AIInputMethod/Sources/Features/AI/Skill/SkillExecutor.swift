import Foundation

// MARK: - ToolCallResult

/// Parsed tool call from model's JSON response
struct ToolCallResult {
    let tool: String
    let content: String
}

// MARK: - SkillExecutor

/// 统一的 Skill 执行引擎
/// 执行管道：模板替换 → 构建 prompt → 调用 API → 解析 tool call JSON → 分发结果
class SkillExecutor {
    let apiClient: GhostypeAPIClient
    let contextDetector: ContextDetector
    let toolRegistry: ToolRegistry

    init(
        apiClient: GhostypeAPIClient = .shared,
        contextDetector: ContextDetector = ContextDetector(),
        toolRegistry: ToolRegistry
    ) {
        self.apiClient = apiClient
        self.contextDetector = contextDetector
        self.toolRegistry = toolRegistry
    }

    // MARK: - Public API

    /// 统一执行入口
    func execute(
        skill: SkillModel,
        speechText: String,
        context: ContextBehavior? = nil,
        onDirectOutput: @escaping (String) -> Void,
        onRewrite: @escaping (String) -> Void,
        onFloatingCard: @escaping (String, String, SkillModel, String) -> Void,
        onError: @escaping (Error, ContextBehavior) -> Void
    ) async {
        let detectionResult = contextDetector.detectWithDebugInfo()
        let behavior = context ?? detectionResult.behavior
        let debugInfo = detectionResult.debugInfo

        FileLogger.log("[SkillExecutor] execute skill=\(skill.name), behavior=\(behavior)")
        FileLogger.log("[SkillExecutor] debugInfo:\n\(debugInfo)")

        // 1. 构建运行时 context（通用逻辑，不按 skill ID 分支）
        var runtimeContext: [String: String] = [:]

        // Ghost Twin 人格档案：任何 SKILL.md 中使用 {{context.ghost_profile}} 都会被替换
        let profile = GhostTwinProfileStore().load()
        if !profile.profileText.isEmpty {
            let personalityContext = """
            ## 用户人格档案
            - 人格标签: \(profile.personalityTags.joined(separator: ", "))
            - 人格档案全文:
            \(profile.profileText)
            """
            runtimeContext["ghost_profile"] = personalityContext
        } else {
            runtimeContext["ghost_profile"] = ""
        }

        // 2. 模板变量替换（config + context）
        let finalPrompt = TemplateEngine.resolve(
            template: skill.systemPrompt,
            config: skill.config,
            context: runtimeContext
        )

        // 2. 构建用户消息（拼入上下文信息）
        let userMessage = buildUserMessage(speechText: speechText, behavior: behavior)

        // 3. 调用 API
        let endpoint = skill.config["api_endpoint"]

        do {
            let result = try await apiClient.executeSkill(
                systemPrompt: finalPrompt,
                message: userMessage,
                context: behavior,
                endpoint: endpoint
            )

            FileLogger.log("[SkillExecutor] API success, parsing tool call")

            // 4. 尝试解析 JSON tool call
            if let toolCall = parseToolCall(from: result) {
                // 5. 验证 tool 是否在 allowed_tools 白名单中
                let allowedTools = skill.allowedTools
                if !allowedTools.isEmpty && !allowedTools.contains(toolCall.tool) {
                    FileLogger.log("[SkillExecutor] Tool '\(toolCall.tool)' not in allowed_tools \(allowedTools), falling back to default")
                    dispatchResult(toolCall.content, behavior: behavior, skill: skill, speechText: speechText, debugInfo: debugInfo,
                                   onDirectOutput: onDirectOutput, onRewrite: onRewrite, onFloatingCard: onFloatingCard)
                    return
                }

                // 6. 通过 ToolRegistry 执行
                let toolContext = ToolContext(text: toolCall.content, skill: skill, speechText: speechText, behavior: behavior)
                do {
                    try toolRegistry.execute(name: toolCall.tool, context: toolContext)
                    FileLogger.log("[SkillExecutor] Tool '\(toolCall.tool)' executed successfully")
                } catch {
                    FileLogger.log("[SkillExecutor] Tool execution failed: \(error), falling back")
                    dispatchResult(toolCall.content, behavior: behavior, skill: skill, speechText: speechText, debugInfo: debugInfo,
                                   onDirectOutput: onDirectOutput, onRewrite: onRewrite, onFloatingCard: onFloatingCard)
                }
            } else {
                // 纯文本返回，走默认分发逻辑
                FileLogger.log("[SkillExecutor] No tool call JSON found, using default dispatch")
                dispatchResult(result, behavior: behavior, skill: skill, speechText: speechText, debugInfo: debugInfo,
                               onDirectOutput: onDirectOutput, onRewrite: onRewrite, onFloatingCard: onFloatingCard)
            }
        } catch {
            FileLogger.log("[SkillExecutor] API error: \(error.localizedDescription)")
            handleError(error, behavior: behavior, speechText: speechText,
                        onDirectOutput: onDirectOutput, onError: onError)
        }
    }

    // MARK: - Tool Call Parsing

    /// 从模型返回的文本中解析 JSON tool call
    func parseToolCall(from text: String) -> ToolCallResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let result = tryParseJSON(trimmed) {
            return result
        }

        if let jsonRange = findJSONObject(in: trimmed),
           let result = tryParseJSON(String(trimmed[jsonRange])) {
            return result
        }

        return nil
    }

    private func tryParseJSON(_ text: String) -> ToolCallResult? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = json["tool"] as? String,
              let content = json["content"] as? String else {
            return nil
        }
        return ToolCallResult(tool: tool, content: content)
    }

    private func findJSONObject(in text: String) -> Range<String.Index>? {
        guard let openBrace = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var index = openBrace

        while index < text.endIndex {
            let char = text[index]

            if escaped {
                escaped = false
            } else if char == "\\" && inString {
                escaped = true
            } else if char == "\"" {
                inString.toggle()
            } else if !inString {
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        let afterClose = text.index(after: index)
                        return openBrace..<afterClose
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    // MARK: - Private Helpers

    private func buildUserMessage(speechText: String, behavior: ContextBehavior) -> String {
        switch behavior {
        case .rewrite(let selectedText):
            return "用户语音指令：\(speechText)\n\n当前选中的文本：\(selectedText)"
        case .explain(let selectedText):
            return "用户语音指令：\(speechText)\n\n当前选中的文本：\(selectedText)"
        case .directOutput, .noInput:
            return speechText
        }
    }

    private func dispatchResult(
        _ result: String,
        behavior: ContextBehavior,
        skill: SkillModel,
        speechText: String,
        debugInfo: String,
        onDirectOutput: @escaping (String) -> Void,
        onRewrite: @escaping (String) -> Void,
        onFloatingCard: @escaping (String, String, SkillModel, String) -> Void
    ) {
        DispatchQueue.main.async {
            switch behavior {
            case .directOutput:
                onDirectOutput(result)
            case .rewrite:
                onRewrite(result)
            case .explain, .noInput:
                onFloatingCard(result, speechText, skill, debugInfo)
            }
        }
    }

    private func handleError(
        _ error: Error,
        behavior: ContextBehavior,
        speechText: String,
        onDirectOutput: @escaping (String) -> Void,
        onError: @escaping (Error, ContextBehavior) -> Void
    ) {
        DispatchQueue.main.async {
            switch behavior {
            case .directOutput, .rewrite:
                FileLogger.log("[SkillExecutor] fallback to original text")
                onDirectOutput(speechText)
            case .explain, .noInput:
                onError(error, behavior)
            }
        }
    }
}
