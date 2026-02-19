import Foundation
import AppKit
import Combine

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
    private var pendingSkill: SkillModel?
    private var waitingForFinalResult = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - ASR Corpus & Profile

    private let corpusStore = ASRCorpusStore()
    private let profileStore = GhostTwinProfileStore()

    // MARK: - Init

    init(speechService: DoubaoSpeechService,
         skillExecutor: SkillExecutor,
         toolRegistry: ToolRegistry,
         textInserter: TextInsertionService,
         overlayManager: OverlayWindowManager,
         hotkeyManager: HotkeyManager) {
        self.speechService = speechService
        self.skillExecutor = skillExecutor
        self.toolRegistry = toolRegistry
        self.textInserter = textInserter
        self.overlayManager = overlayManager
        self.hotkeyManager = hotkeyManager
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

            if self.waitingForFinalResult, let skill = self.pendingSkill {
                FileLogger.log("[Speech] Processing immediately after final result")
                self.waitingForFinalResult = false
                self.pendingSkill = nil
                self.processWithSkill(skill, speechText: text)
            } else if self.waitingForFinalResult {
                FileLogger.log("[Speech] Processing immediately after final result (default polish)")
                self.waitingForFinalResult = false
                self.pendingSkill = nil
                self.processWithSkill(nil, speechText: text)
            }
        }

        speechService.onPartialResult = { text in
            FileLogger.log("[Speech] Partial result: \(text)")
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

            print("[Hotkey] ========== DOWN ==========")
            let skill = self.hotkeyManager.currentSkill
            let skillName = skill?.name ?? "润色"
            print("[Hotkey] Starting recording, skill: \(skillName)")
            self.currentSkill = skill
            self.currentRawText = ""
            self.waitingForFinalResult = false
            self.pendingSkill = nil
            self.overlayManager.showNearCursor()
            self.speechService.startRecording()
            OverlayStateManager.shared.setRecording(skill: skill)
        }

        hotkeyManager.onSkillChanged = { [weak self] skill in
            guard let self = self else { return }
            let skillName = skill?.name ?? "润色"
            print("[Hotkey] Skill changed to: \(skillName)")
            self.currentSkill = skill
            OverlayStateManager.shared.setRecording(skill: skill)
        }

        hotkeyManager.onHotkeyUp = { [weak self] skill in
            guard let self = self else { return }
            print("[Hotkey] ========== UP ==========")
            let skillName = skill?.name ?? "润色"
            print("[Hotkey] Stopping recording, final skill: \(skillName)")
            self.speechService.stopRecording()
            OverlayStateManager.shared.setProcessing(skill: skill)

            if !self.currentRawText.isEmpty {
                FileLogger.log("[Hotkey] Final result already available, processing now")
                self.processWithSkill(skill, speechText: self.currentRawText)
            } else {
                FileLogger.log("[Hotkey] Waiting for final result...")
                self.waitingForFinalResult = true
                self.pendingSkill = skill

                DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.speechTimeoutSeconds) { [weak self] in
                    guard let self = self, self.waitingForFinalResult else { return }
                    FileLogger.log("[Hotkey] ⚠️ Timeout waiting for final result")
                    self.waitingForFinalResult = false
                    let pendingSkill = self.pendingSkill
                    self.pendingSkill = nil
                    self.processWithSkill(pendingSkill, speechText: self.currentRawText)
                }
            }
        }
    }

    // MARK: - AI Processing (Skill-based)

    func processWithSkill(_ skill: SkillModel?, speechText: String) {
        let text = speechText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            FileLogger.log("[Process] Empty text, skipping")
            overlayManager.hide()
            return
        }

        guard let skill = skill else {
            FileLogger.log("[Process] No skill (default polish)")
            processWithMode(.polish)
            return
        }

        let skillName = skill.name
        FileLogger.log("[Process] Processing with skill: \(skillName)")
        FileLogger.log("[Process] Raw text: \(text)")

        Task { @MainActor in
            await self.skillExecutor.execute(
                skill: skill,
                speechText: text,
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
        textInserter.saveUsageRecord(
            content: text,
            category: categoryForSkill(skill),
            originalContent: rawASR.isEmpty ? nil : rawASR,
            skillId: skill.id,
            skillName: skill.localizedName
        )
        Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
        NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
        OverlayStateManager.shared.setCommitting(type: .textInput)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
            self.overlayManager.hide()
        }
    }

    func categoryForSkill(_ skill: SkillModel) -> RecordCategory {
        switch skill.id {
        case SkillModel.builtinTranslateId: return .translate
        case SkillModel.builtinMemoId: return .memo
        default: return .polish
        }
    }

    // MARK: - AI Processing (Legacy modes)

    func processWithMode(_ mode: InputMode) {
        let text = currentRawText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            FileLogger.log("[Process] Empty text, skipping")
            overlayManager.hide()
            return
        }

        FileLogger.log("[Process] Processing with mode: \(mode.displayName)")
        FileLogger.log("[Process] AI Polish enabled: \(AppSettings.shared.enableAIPolish)")

        switch mode {
        case .polish:
            if AppSettings.shared.enableAIPolish {
                processPolish(text)
            } else {
                FileLogger.log("[Process] AI Polish OFF, inserting raw text")
                insertTextAtCursor(text)
                textInserter.saveUsageRecord(
                    content: text, category: .polish, originalContent: text,
                    skillId: SkillModel.builtinGhostCommandId, skillName: L.Overlay.defaultSkillName
                )
                Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
                OverlayStateManager.shared.setCommitting(type: .textInput)
                DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
                    self.overlayManager.hide()
                }
            }
        case .translate:
            processTranslate(text)
        case .memo:
            processMemo(text)
        }
    }

    private func processPolish(_ text: String) {
        print("[Polish] Starting AI polish with GhostypeAPI...")

        let settings = AppSettings.shared
        let polishThreshold = settings.polishThreshold
        if text.count < polishThreshold {
            print("[Polish] Text too short (\(text.count) < \(polishThreshold)), skipping AI")
            insertTextAtCursor(text)
            textInserter.saveUsageRecord(
                content: text, category: .polish, originalContent: text,
                skillId: SkillModel.builtinGhostCommandId, skillName: L.Overlay.defaultSkillName
            )
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
                self.textInserter.saveUsageRecord(
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

            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
                self.overlayManager.hide()
            }
        }
    }

    private func processTranslate(_ text: String) {
        print("[Translate] Starting AI translate with GhostypeAPI...")

        let settings = AppSettings.shared

        Task { @MainActor in
            do {
                let translatedText = try await GhostypeAPIClient.shared.translate(
                    text: text,
                    language: settings.translateLanguage.rawValue
                )
                print("[Translate] Success: \(translatedText)")
                self.insertTextAtCursor(translatedText)
                self.textInserter.saveUsageRecord(
                    content: translatedText, category: .translate, originalContent: text,
                    skillId: SkillModel.builtinTranslateId, skillName: L.Skill.builtinTranslateName
                )
                Task { await QuotaManager.shared.reportAndRefresh(characters: translatedText.count) }
                NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
            } catch {
                print("[Translate] Error: \(error.localizedDescription)")
                FileLogger.log("[Translate] API error, falling back to original text")
                self.insertTextAtCursor(text)
            }

            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.commitDismissDelay) {
                self.overlayManager.hide()
            }
        }
    }

    private func processMemo(_ text: String) {
        FileLogger.log("[Memo] Saving memo directly...")

        textInserter.saveUsageRecord(
            content: text, category: .memo, originalContent: text,
            skillId: SkillModel.builtinMemoId, skillName: L.Skill.builtinMemoName
        )
        FileLogger.log("[Memo] Saved to notes")
        Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }

        OverlayStateManager.shared.setCommitting(type: .memoSaved)

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.memoDismissDelay) {
            self.overlayManager.hide()
        }
    }

    // MARK: - Text Insertion (with noInput detection)

    private func insertTextAtCursor(_ text: String) {
        guard !text.isEmpty else { return }
        let context = ContextDetector().detect()
        if case .noInput = context {
            overlayManager.hide()
        }
        textInserter.insert(text)
    }

    // MARK: - ToolOutputHandler

    func handleTextOutput(context: ToolContext) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.insertAndRecord(context.text, skill: context.skill, originalText: self.currentRawText)
        }
    }

    func handleMemoSave(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textInserter.saveUsageRecord(
                content: text, category: .memo, originalContent: self.currentRawText.isEmpty ? text : self.currentRawText,
                skillId: SkillModel.builtinMemoId, skillName: L.Skill.builtinMemoName
            )
            FileLogger.log("[Memo] Saved via ToolRegistry")
            Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
            OverlayStateManager.shared.setCommitting(type: .memoSaved)
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Overlay.memoDismissDelay) {
                self.overlayManager.hide()
            }
        }
    }
}
