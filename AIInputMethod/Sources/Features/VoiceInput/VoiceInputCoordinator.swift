import Foundation
import AppKit
import Combine

// MARK: - Recording State Machine

/// 语音录音生命周期状态
private enum RecordingState {
    /// 空闲，未录音
    case idle
    /// 正在录音（快捷键按住中）
    case recording(skill: SkillModel?)
    /// 录音结束，等待 ASR 最终结果
    case waitingForResult(skill: SkillModel?, timeout: DispatchWorkItem)
    /// 正在处理 Skill（调用 LLM 中）
    case processing
}

// MARK: - Voice Input Coordinator

/// 语音输入协调器
/// 从 AppDelegate 提取的语音处理核心逻辑
/// 负责：录音状态管理、Skill 路由、AI 处理、文本插入
class VoiceInputCoordinator: ToolOutputHandler {

    // MARK: - Dependencies

    let speechService: DoubaoSpeechService
    let skillExecutor: SkillExecutor
    let toolRegistry: ToolRegistry
    let textInserter: TextInsertionService
    let overlayManager: OverlayWindowManager
    let hotkeyManager: HotkeyManager

    // MARK: - State

    var currentSkill: SkillModel? = nil
    var isVoiceInputEnabled: Bool = false
    private var currentRawText: String = ""
    private var recordingState: RecordingState = .idle
    private var savedContext: ContextBehavior?  // 按下快捷键时保存的上下文（用户还聚焦在目标输入框）
    private var cancellables = Set<AnyCancellable>()

    // MARK: - ASR Corpus & Profile

    private let corpusStore: ASRCorpusStore
    private let profileStore: GhostTwinProfileStore

    // MARK: - Init

    init(speechService: DoubaoSpeechService,
         skillExecutor: SkillExecutor,
         toolRegistry: ToolRegistry,
         textInserter: TextInsertionService,
         overlayManager: OverlayWindowManager,
         hotkeyManager: HotkeyManager,
         corpusStore: ASRCorpusStore = ASRCorpusStore(),
         profileStore: GhostTwinProfileStore = GhostTwinProfileStore()) {
        self.speechService = speechService
        self.skillExecutor = skillExecutor
        self.toolRegistry = toolRegistry
        self.textInserter = textInserter
        self.overlayManager = overlayManager
        self.hotkeyManager = hotkeyManager
        self.corpusStore = corpusStore
        self.profileStore = profileStore
    }

    // MARK: - Setup

    func setup() {
        // 注册内置 Tool（使用协议回调）
        toolRegistry.outputHandler = self
        toolRegistry.registerBuiltins()

        // 绑定 Hotkey 回调
        setupHotkey()

        // 绑定语音识别回调
        setupSpeechCallbacks()

        // 订阅登录/登出通知
        setupAuthNotifications()

        // 根据登录状态初始化
        isVoiceInputEnabled = AuthManager.shared.isLoggedIn
        print("[VIC] Voice input enabled: \(isVoiceInputEnabled)")
    }

    // MARK: - Auth Notifications

    func setupAuthNotifications() {
        NotificationCenter.default.publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isVoiceInputEnabled = true
                print("[VIC] ✅ User logged in, voice input enabled")
                Task { try? await self.speechService.fetchCredentials() }
                Task { await QuotaManager.shared.refresh() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isVoiceInputEnabled = false
                print("[VIC] ⚠️ User logged out, voice input disabled")
            }
            .store(in: &cancellables)

        print("[VIC] ✅ Auth notifications subscribed")
    }

    // MARK: - Speech Callbacks

    func setupSpeechCallbacks() {
        speechService.onFinalResult = { [weak self] text in
            guard let self = self else { return }
            FileLogger.log("[Speech] ✅ Final result: \(text)")
            self.currentRawText = text

            // 收集 ASR 语料用于 Ghost Twin 人格构筑 + 语音 XP
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                self.corpusStore.append(text: trimmed)
                self.awardSpeechXP(characterCount: trimmed.count)
            }

            // 状态机：仅在等待最终结果时触发处理
            if case .waitingForResult(let skill, let timeout) = self.recordingState {
                timeout.cancel()
                self.recordingState = .processing
                FileLogger.log("[Speech] Processing final result via PTT path")
                self.processWithSkill(skill, speechText: text)
            }
        }

        speechService.onPartialResult = { [weak self] text in
            guard let self = self else { return }
            FileLogger.log("[Speech] Partial result: \(text)")
            // Push_To_Talk 模式不使用 partial results 显示（Overlay 显示录音状态）
        }
    }

    // MARK: - Speech XP

    /// 语音输入奖励 XP（1 字符 = 1 XP）
    /// 正常说话即可积累经验，无需校准
    private func awardSpeechXP(characterCount: Int) {
        let xp = GhostTwinXP.speechXP(characterCount: characterCount)
        guard xp > 0 else { return }

        var profile = profileStore.load()
        let oldXP = profile.totalXP
        let newXP = oldXP + xp
        let levelCheck = GhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: newXP)

        profile.totalXP = newXP
        profile.level = GhostTwinXP.calculateLevel(totalXP: newXP)
        profile.updatedAt = Date()

        do {
            try profileStore.save(profile)
            FileLogger.log("[VIC] 🎯 Speech XP +\(xp) (total: \(newXP), Lv.\(profile.level))")
        } catch {
            FileLogger.log("[VIC] ❌ Failed to save speech XP: \(error)")
            return
        }

        // 通知 UI 刷新（IncubatorViewModel 会 loadLocalData）
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
        }

        // 升级时通知触发构筑
        if levelCheck.leveledUp {
            FileLogger.log("[VIC] 🎉 Level up via speech! Lv.\(levelCheck.oldLevel) → Lv.\(levelCheck.newLevel)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .ghostTwinDidLevelUp,
                    object: nil,
                    userInfo: ["newLevel": levelCheck.newLevel]
                )
            }
        }
    }

    // MARK: - Hotkey

    func setupHotkey() {
        hotkeyManager.onHotkeyDown = { [weak self] in
            guard let self = self else { return }

            guard self.isVoiceInputEnabled else {
                print("[Hotkey] ⚠️ Voice input disabled (not logged in)")
                self.overlayManager.showNearCursor()
                OverlayStateManager.shared.setLoginRequired()
                DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.loginRequiredDismissDelay) {
                    self.overlayManager.hide()
                }
                return
            }

            self.handlePushToTalkHotkeyDown()
        }

        hotkeyManager.onSkillChanged = { [weak self] skill in
            guard let self = self else { return }
            // In combo mode, skill is determined by the combo key binding, not modifier switching
            guard AppSettings.shared.hotkeyMode == .singleKey else { return }
            let skillName = skill?.name ?? "润色"
            print("[Hotkey] Skill changed to: \(skillName)")
            self.currentSkill = skill
            OverlayStateManager.shared.setRecording(skill: skill)
        }

        hotkeyManager.onHotkeyUp = { [weak self] skill in
            guard let self = self else { return }
            self.handlePushToTalkHotkeyUp(skill: skill)
        }

        hotkeyManager.onEscCancel = { [weak self] in
            guard let self = self else { return }
            self.handleEscCancel()
        }
    }

    // MARK: - Push_To_Talk Hotkey Handlers

    /// Push_To_Talk 模式按下快捷键
    private func handlePushToTalkHotkeyDown() {
        print("[Hotkey] ========== DOWN ==========")
        let skill = hotkeyManager.currentSkill
        let skillName = skill?.name ?? "润色"
        print("[Hotkey] Starting recording, skill: \(skillName)")
        currentSkill = skill
        currentRawText = ""
        recordingState = .recording(skill: skill)

        // 在显示 Overlay 之前保存上下文（此时用户还聚焦在目标输入框）
        // AX 检测移到后台线程，避免阻塞热键响应路径 50-200ms
        overlayManager.showNearCursor()
        OverlayStateManager.shared.setRecording(skill: skill)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let detection = self.skillExecutor.contextDetector.detectWithDebugInfo()
            DispatchQueue.main.async {
                self.savedContext = detection.behavior
                FileLogger.log("[Hotkey] Saved context: \(detection.behavior), debugInfo:\n\(detection.debugInfo)")
                self.speechService.startRecording()
            }
        }
    }

    /// Push_To_Talk 模式松开快捷键
    private func handlePushToTalkHotkeyUp(skill: SkillModel?) {
        print("[Hotkey] ========== UP ==========")
        let skillName = skill?.name ?? "润色"
        print("[Hotkey] Stopping recording, final skill: \(skillName)")
        speechService.stopRecording()
        OverlayStateManager.shared.setProcessing(skill: skill)

        if !currentRawText.isEmpty {
            FileLogger.log("[Hotkey] Final result already available, processing now")
            recordingState = .processing
            processWithSkill(skill, speechText: currentRawText)
        } else {
            FileLogger.log("[Hotkey] Waiting for final result...")
            let timeout = DispatchWorkItem { [weak self] in
                guard let self = self,
                      case .waitingForResult(let pendingSkill, _) = self.recordingState else { return }
                FileLogger.log("[Hotkey] ⚠️ Timeout waiting for final result")
                self.recordingState = .processing
                self.processWithSkill(pendingSkill, speechText: self.currentRawText)
            }
            recordingState = .waitingForResult(skill: skill, timeout: timeout)
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.speechTimeoutSeconds, execute: timeout)
        }
    }

    // MARK: - ESC Cancel

    /// ESC 取消输入：停止录音 → 丢弃文本 → 隐藏 Overlay
    func handleEscCancel() {
        FileLogger.log("[VIC] ESC cancel triggered")

        speechService.stopRecording()

        // 取消等待超时
        if case .waitingForResult(_, let timeout) = recordingState {
            timeout.cancel()
        }

        currentRawText = ""
        recordingState = .idle

        OverlayStateManager.shared.hide()
        overlayManager.hide()
    }

    // MARK: - AI Processing (Skill-based)

    func processWithSkill(_ skill: SkillModel?, speechText: String) {
        let text = speechText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            FileLogger.log("[Process] Empty text, skipping")
            recordingState = .idle
            currentRawText = ""
            overlayManager.hide()
            return
        }

        guard let skill = skill else {
            FileLogger.log("[Process] No skill (default polish)")
            processPolish(text)
            return
        }

        let skillName = skill.name
        FileLogger.log("[Process] Processing with skill: \(skillName)")
        FileLogger.log("[Process] Raw text: \(text)")

        Task { @MainActor in
            await self.skillExecutor.execute(
                skill: skill,
                speechText: text,
                context: self.savedContext,
                onDirectOutput: { [weak self] result in
                    guard let self = self else { return }
                    self.insertAndRecord(result, skill: skill, originalText: text)
                },
                onRewrite: { [weak self] result in
                    guard let self = self else { return }
                    self.insertAndRecord(result, skill: skill, originalText: text)
                },
                onFloatingCard: { [weak self] result, speechText, skill, debugInfo in
                    guard let self = self else { return }
                    self.recordingState = .idle
                    self.currentRawText = ""
                    OverlayStateManager.shared.hide()
                    self.overlayManager.hide()
                    FloatingResultCardController.shared.show(
                        skill: skill,
                        speechText: speechText,
                        result: result,
                        debugInfo: debugInfo,
                        near: nil
                    )
                },
                onError: { [weak self] error, behavior in
                    guard let self = self else { return }
                    FileLogger.log("[Process] Skill error: \(error.localizedDescription)")
                    self.recordingState = .idle
                    self.currentRawText = ""
                    OverlayStateManager.shared.setCommitting(type: .textInput)
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
                        self.overlayManager.hide()
                    }
                }
            )
        }
    }

    /// 插入文本 + 保存记录 + 报告额度 + 隐藏 Overlay（公共逻辑）
    private func insertAndRecord(_ text: String, skill: SkillModel, originalText: String? = nil) {
        insertTextAtCursor(text)
        // 始终保存 ASR 原始文本，优先用传入的 originalText，否则用 currentRawText
        let rawASR = originalText ?? currentRawText
        saveUsageRecord(
            content: text,
            category: categoryForSkill(skill),
            originalContent: rawASR.isEmpty ? nil : rawASR,
            skillId: skill.id,
            skillName: skill.localizedName
        )
        recordingState = .idle
        currentRawText = ""
        Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
        NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
        OverlayStateManager.shared.setCommitting(type: .textInput)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
            self.overlayManager.hide()
        }
    }

    func saveUsageRecord(content: String, category: RecordCategory, originalContent: String? = nil, skillId: String? = nil, skillName: String? = nil) {
        let context = PersistenceController.shared.container.viewContext
        let record = UsageRecord(context: context)
        record.id = UUID()
        record.content = content
        record.originalContent = originalContent
        record.category = category.rawValue
        record.skillId = skillId
        record.skillName = skillName
        record.timestamp = Date()
        record.deviceId = DeviceIdManager.shared.deviceId

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            record.sourceApp = frontApp.localizedName ?? "Unknown"
            record.sourceAppBundleId = frontApp.bundleIdentifier ?? ""
        } else {
            record.sourceApp = "Unknown"
            record.sourceAppBundleId = ""
        }
        record.duration = 0

        do {
            try context.save()
            FileLogger.log("[Record] Saved: \(category.rawValue) skill=\(skillName ?? "nil") - \(content.prefix(30))...")
            if category == .memo {
                MemoSyncManager.shared.syncMemo(content: content, timestamp: record.timestamp ?? Date())
            }
        } catch {
            FileLogger.log("[Record] Save error: \(error)")
        }
    }

    func categoryForSkill(_ skill: SkillModel) -> RecordCategory {
        switch skill.id {
        case SkillModel.builtinTranslateId: return .translate
        case SkillModel.builtinMemoId: return .memo
        default: return .polish
        }
    }

    // MARK: - AI Processing (Polish fallback)

    private func processPolish(_ text: String) {
        print("[Polish] Starting AI polish with GhostypeAPI...")

        let settings = AppSettings.shared
        let polishThreshold = settings.polishThreshold
        if text.count < polishThreshold {
            print("[Polish] Text too short (\(text.count) < \(polishThreshold)), skipping AI")
            insertTextAtCursor(text)
            saveUsageRecord(
                content: text, category: .polish, originalContent: text,
                skillId: SkillModel.builtinGhostCommandId, skillName: L.Overlay.defaultSkillName
            )
            recordingState = .idle
            currentRawText = ""
            Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
                self.overlayManager.hide()
            }
            return
        }

        let currentBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        FileLogger.log("[Polish] Current app BundleID: \(currentBundleId ?? "nil")")

        let viewModel = AIPolishViewModel()
        let resolved = viewModel.resolveProfile(for: currentBundleId)
        FileLogger.log("[Polish] Using profile: \(resolved.profile.rawValue)")

        Task { @MainActor in
            do {
                let polishedText = try await GhostypeAPIClient.shared.polish(
                    text: text,
                    profile: resolved.profile.rawValue,
                    customPrompt: resolved.customPrompt,
                    enableInSentence: settings.enableInSentencePatterns,
                    enableTrigger: settings.enableTriggerCommands,
                    triggerWord: settings.triggerWord
                )
                print("[Polish] Success: \(polishedText)")
                self.insertTextAtCursor(polishedText)
                self.saveUsageRecord(
                    content: polishedText, category: .polish, originalContent: text,
                    skillId: SkillModel.builtinGhostCommandId, skillName: L.Overlay.defaultSkillName
                )
                Task { await QuotaManager.shared.reportAndRefresh(characters: polishedText.count) }
                NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
            } catch {
                print("[Polish] Error: \(error.localizedDescription)")
                FileLogger.log("[Polish] API error, falling back to original text")
                self.insertTextAtCursor(text)
            }

            self.recordingState = .idle
            self.currentRawText = ""
            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
                self.overlayManager.hide()
            }
        }
    }

    // MARK: - Punctuation

    static func applyPunctuationMode(_ text: String) -> String {
        let mode = AppSettings.shared.punctuationMode
        switch mode {
        case "noEnd":
            // 去掉末尾标点（中英文句号、问号、感叹号）
            var result = text
            while let last = result.last,
                  "。.！!？?".contains(last) {
                result.removeLast()
            }
            return result
        case "spaces":
            // 去掉所有标点，用空格分隔
            let punctuations = CharacterSet.punctuationCharacters.union(.symbols)
            let cleaned = text.unicodeScalars.map { punctuations.contains($0) ? " " : String($0) }.joined()
            return cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        default:
            return text
        }
    }

    // MARK: - Text Insertion

    func insertTextAtCursor(_ text: String) {
        let finalText = VoiceInputCoordinator.applyPunctuationMode(text)
        FileLogger.log("[Insert] Inserting text: \(finalText.prefix(50))...")

        textInserter.insert(finalText)
    }

    // MARK: - ToolOutputHandler

    func handleTextOutput(context: ToolContext) {
        insertTextAtCursor(context.text)
        saveUsageRecord(
            content: context.text,
            category: .polish,
            originalContent: context.speechText,
            skillId: context.skill.id,
            skillName: context.skill.localizedName
        )
        recordingState = .idle
        currentRawText = ""
        Task { await QuotaManager.shared.reportAndRefresh(characters: context.text.count) }
        NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
        OverlayStateManager.shared.setCommitting(type: .textInput)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
            self.overlayManager.hide()
        }
    }

    func handleMemoSave(text: String) {
        // Memo 保存通过 CoreData UsageRecord 记录，不再依赖 MemoStore
        saveUsageRecord(
            content: text, category: .memo, originalContent: nil,
            skillId: SkillModel.builtinMemoId, skillName: L.Skill.builtinMemoName
        )
        recordingState = .idle
        currentRawText = ""
        Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
        NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
        OverlayStateManager.shared.setCommitting(type: .memoSaved)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
            self.overlayManager.hide()
        }
    }
}
