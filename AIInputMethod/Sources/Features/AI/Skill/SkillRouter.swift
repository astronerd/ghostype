import Foundation
import AppKit

// MARK: - Skill Router

/// Skill 路由器：根据 Skill 类型和上下文行为分发 AI 请求
class SkillRouter {

    let apiClient: GhostypeAPIClient
    let contextDetector: ContextDetector

    init(apiClient: GhostypeAPIClient = .shared, contextDetector: ContextDetector = ContextDetector()) {
        self.apiClient = apiClient
        self.contextDetector = contextDetector
    }

    /// 执行 Skill
    /// - Parameters:
    ///   - skill: 要执行的 Skill（nil = 默认润色）
    ///   - speechText: 用户语音文本
    ///   - onDirectOutput: 直接输出回调（插入文字）
    ///   - onRewrite: 改写回调（替换选中文字）
    ///   - onFloatingCard: 悬浮卡片回调（skill名称, 语音原文, AI结果, skill）
    ///   - onError: 错误回调
    func execute(
        skill: SkillModel,
        speechText: String,
        context: ContextBehavior? = nil,
        onDirectOutput: @escaping (String) -> Void,
        onRewrite: @escaping (String) -> Void,
        onFloatingCard: @escaping (String, String, SkillModel) -> Void,
        onError: @escaping (Error, ContextBehavior) -> Void
    ) async {
        let behavior = context ?? contextDetector.detect()

        // Memo 不调用 API，直接本地处理
        if skill.skillType == .memo {
            handleMemoLocally(speechText: speechText, skill: skill, behavior: behavior,
                              onDirectOutput: onDirectOutput, onFloatingCard: onFloatingCard)
            return
        }

        // 调用 API
        do {
            let result = try await routeToAPI(skill: skill, speechText: speechText, behavior: behavior)
            dispatchResult(result, behavior: behavior, skill: skill, speechText: speechText,
                           onDirectOutput: onDirectOutput, onRewrite: onRewrite, onFloatingCard: onFloatingCard)
        } catch {
            handleError(error, behavior: behavior, speechText: speechText,
                        onDirectOutput: onDirectOutput, onRewrite: onRewrite,
                        onFloatingCard: onFloatingCard, onError: onError, skill: skill)
        }
    }

    // MARK: - API Routing

    /// 根据 Skill 类型路由到不同 API
    private func routeToAPI(skill: SkillModel, speechText: String, behavior: ContextBehavior) async throws -> String {
        // 构建完整输入（rewrite/explain 时包含选中文字）
        let fullInput = buildInput(speechText: speechText, behavior: behavior)

        switch skill.skillType {
        case .polish:
            return try await routePolish(text: fullInput)

        case .translate:
            let language = skill.behaviorConfig["translate_language"] ?? TranslateLanguage.chineseEnglish.rawValue
            return try await apiClient.translate(text: fullInput, language: language)

        case .ghostCommand:
            return try await apiClient.ghostCommand(text: fullInput)

        case .ghostTwin:
            return try await apiClient.ghostTwinChat(text: fullInput)

        case .custom:
            return try await apiClient.polish(
                text: fullInput,
                profile: "custom",
                customPrompt: skill.promptTemplate,
                enableInSentence: false,
                enableTrigger: false,
                triggerWord: ""
            )

        case .memo:
            // 不应该走到这里，memo 在 execute() 中已处理
            return speechText
        }
    }

    /// 润色路由（保持与现有 processPolish 一致的逻辑）
    private func routePolish(text: String) async throws -> String {
        let settings = AppSettings.shared
        let currentBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let viewModel = AIPolishViewModel()
        let resolved = viewModel.resolveProfile(for: currentBundleId)

        return try await apiClient.polish(
            text: text,
            profile: resolved.profile.rawValue,
            customPrompt: resolved.customPrompt,
            enableInSentence: settings.enableInSentencePatterns,
            enableTrigger: settings.enableTriggerCommands,
            triggerWord: settings.triggerWord
        )
    }

    /// 构建完整输入文本
    private func buildInput(speechText: String, behavior: ContextBehavior) -> String {
        switch behavior {
        case .rewrite(let selectedText):
            return "用户语音：\(speechText)\n选中文字：\(selectedText)"
        case .explain(let selectedText):
            return "用户语音：\(speechText)\n选中文字：\(selectedText)"
        default:
            return speechText
        }
    }

    // MARK: - Result Dispatch

    /// 根据上下文行为分发结果
    private func dispatchResult(
        _ result: String,
        behavior: ContextBehavior,
        skill: SkillModel,
        speechText: String,
        onDirectOutput: @escaping (String) -> Void,
        onRewrite: @escaping (String) -> Void,
        onFloatingCard: @escaping (String, String, SkillModel) -> Void
    ) {
        switch behavior {
        case .directOutput:
            onDirectOutput(result)
        case .rewrite:
            onRewrite(result)
        case .explain, .noInput:
            onFloatingCard(result, speechText, skill)
        }
    }

    // MARK: - Memo

    /// Memo 本地处理（不调用 API）
    private func handleMemoLocally(
        speechText: String,
        skill: SkillModel,
        behavior: ContextBehavior,
        onDirectOutput: @escaping (String) -> Void,
        onFloatingCard: @escaping (String, String, SkillModel) -> Void
    ) {
        // Memo 始终保存到 CoreData，不区分上下文行为
        // 保存逻辑由 AppDelegate 的 onDirectOutput 回调处理
        onDirectOutput(speechText)
    }

    // MARK: - Error Handling

    /// 错误处理：Direct/Rewrite 回退原文，Explain/NoInput 显示错误
    private func handleError(
        _ error: Error,
        behavior: ContextBehavior,
        speechText: String,
        onDirectOutput: @escaping (String) -> Void,
        onRewrite: @escaping (String) -> Void,
        onFloatingCard: @escaping (String, String, SkillModel) -> Void,
        onError: @escaping (Error, ContextBehavior) -> Void,
        skill: SkillModel
    ) {
        FileLogger.log("[SkillRouter] Error: \(error.localizedDescription)")

        switch behavior {
        case .directOutput:
            // 回退插入原始语音文本
            onDirectOutput(speechText)
        case .rewrite:
            // 回退插入原始语音文本（不替换选中内容）
            onDirectOutput(speechText)
        case .explain, .noInput:
            // 在悬浮卡片中显示错误
            onError(error, behavior)
        }
    }
}
