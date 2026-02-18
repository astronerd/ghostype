//
//  IncubatorViewModel.swift
//  AIInputMethod
//
//  Ghost Twin 孵化室 ViewModel
//  管理等级、经验值、校准挑战、闲置文案等状态
//  端上迁移：替换服务端 API 为本地校准逻辑
//  Validates: Requirements 5.3, 5.4, 5.5, 6.2, 6.3, 6.4, 6.5, 6.6, 7.1, 7.2, 7.5, 7.6, 7.7, 11.6, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10
//

import Foundation
import SwiftUI
import Combine

// MARK: - Notification Names

extension Notification.Name {
    /// LLM 调用成功后通知 Ghost Twin 刷新状态
    /// Validates: Requirements 7.6
    static let ghostTwinStatusShouldRefresh = Notification.Name("ghostTwinStatusShouldRefresh")

    /// 语音 XP 导致升级，通知触发构筑和升级仪式
    static let ghostTwinDidLevelUp = Notification.Name("ghostTwinDidLevelUp")
}

// MARK: - Animation Phase

/// Ghost 动效阶段，根据等级演进
/// Validates: Requirements 6.4
enum AnimationPhase: String, CaseIterable {
    /// Lv.1~3：高频 glitch 闪烁，模拟信号不稳定
    case glitch
    /// Lv.4~6：低频正弦呼吸，平滑波动
    case breathing
    /// Lv.7~9：稳定呼吸 + 微弱辉光溢出
    case awakening
    /// Lv.10：常亮 100% + 强力 Bloom 光效
    case complete
}

// MARK: - Ghost Twin Cache Keys

/// UserDefaults 缓存键
enum GhostTwinCacheKey: String {
    case level = "ghostTwin.level"
    case totalXP = "ghostTwin.totalXP"
    case currentLevelXP = "ghostTwin.currentLevelXP"
    case personalityTags = "ghostTwin.personalityTags"
    case challengesRemaining = "ghostTwin.challengesRemaining"
    case activationOrder = "ghostTwin.activationOrder"
}

// MARK: - CalibrationAnalysisResponse

/// LLM 校准分析响应
struct CalibrationAnalysisResponse: Decodable {
    let profileDiff: ProfileDiff
    let ghostResponse: String
    let analysis: String

    struct ProfileDiff: Codable {
        let layer: String
        let changes: [String: String]
        let newTags: [String]
    }
}

// MARK: - IncubatorViewModel

/// Ghost Twin 孵化室 ViewModel
/// 管理等级、经验值、校准挑战、闲置文案等状态
/// 端上迁移：所有校准逻辑本地驱动，LLM 仅作代理
@Observable
@MainActor
class IncubatorViewModel {
    
    // MARK: - State
    
    /// 当前等级 (1~10)
    var level: Int = 1
    
    /// 总经验值
    var totalXP: Int = 0
    
    /// 当前等级内的经验值 (0~9999)
    var currentLevelXP: Int = 0
    
    /// 已捕捉的人格特征标签
    var personalityTags: [String] = []
    
    /// 今日剩余校准挑战次数
    var challengesRemaining: Int = 0
    
    /// 当前校准挑战（本地类型）
    var currentChallenge: LocalCalibrationChallenge?
    
    /// 是否正在加载校准挑战
    var isLoadingChallenge: Bool = false
    
    /// 是否正在提交答案
    var isSubmittingAnswer: Bool = false
    
    /// Ghost 的反馈语
    var ghostResponse: String?
    
    /// 是否显示热敏纸条
    var showReceiptSlip: Bool = false
    
    /// 闲置文案当前显示文本
    var idleText: String = ""
    
    /// 是否正在打字机效果中
    var isTypingIdle: Bool = false
    
    /// 是否正在升级
    var isLevelingUp: Bool = false
    
    /// 升级仪式阶段 (0=无, 1=全屏闪烁, 2=背景熄灭, 3=Ghost 亮度提升)
    /// Validates: Requirements 6.1, 6.2
    var levelUpPhase: Int = 0
    
    /// 是否有错误
    var isError: Bool = false
    
    /// 错误信息
    var errorMessage: String?
    
    /// 本地人格档案
    var profile: GhostTwinProfile = .initial
    
    // MARK: - Models
    
    /// 点阵数据模型
    let matrixModel = GhostMatrixModel()
    
    // MARK: - Dependencies
    
    private let profileStore = GhostTwinProfileStore()
    private let recordStore = CalibrationRecordStore()
    private let corpusStore = ASRCorpusStore()
    private let recoveryManager = RecoveryManager()
    
    // MARK: - Computed Properties
    
    /// Ghost 透明度，随等级线性递增
    var ghostOpacity: Double { Double(level) * 0.1 }
    
    /// 同步率百分比
    var syncRate: Int { level * 10 }
    
    /// 当前等级进度 (0.0 ~ 1.0)
    var progressFraction: Double { Double(currentLevelXP) / 10_000.0 }
    
    /// 当前动效阶段
    var animationPhase: AnimationPhase {
        Self.animationPhase(forLevel: level)
    }
    
    /// 是否已完成首次 profiling
    var hasCompletedProfiling: Bool {
        !profile.profileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Private Properties
    
    private var idleTextTimer: Timer?
    private var typewriterTimer: Timer?
    private var fullIdleText: String = ""
    private var typewriterIndex: Int = 0
    private var statusRefreshCancellable: AnyCancellable?
    private var levelUpCancellable: AnyCancellable?

    // MARK: - Static Helpers (for testability)
    
    /// 根据等级返回动效阶段
    static func animationPhase(forLevel level: Int) -> AnimationPhase {
        switch level {
        case 1...3: return .glitch
        case 4...6: return .breathing
        case 7...9: return .awakening
        case 10: return .complete
        default:
            if level < 1 { return .glitch }
            return .complete
        }
    }
    
    /// 根据等级返回闲置文案分组索引
    static func idleTextGroup(forLevel level: Int) -> Int {
        switch level {
        case 1...3: return 0
        case 4...6: return 1
        case 7...9: return 2
        case 10: return 3
        default:
            if level < 1 { return 0 }
            return 3
        }
    }
    
    /// 根据等级计算 Ghost 透明度
    static func ghostOpacity(forLevel level: Int) -> Double {
        return Double(level) * 0.1
    }
    
    // MARK: - LLM Notification Observer
    
    /// 开始监听 LLM 调用成功通知，自动刷新本地数据
    func startObservingLLMNotifications() {
        stopObservingLLMNotifications()
        
        statusRefreshCancellable = NotificationCenter.default
            .publisher(for: .ghostTwinStatusShouldRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                print("[IncubatorViewModel] 🔄 Received LLM success notification, refreshing local data")
                self.loadLocalData()
            }
        
        levelUpCancellable = NotificationCenter.default
            .publisher(for: .ghostTwinDidLevelUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                let newLevel = notification.userInfo?["newLevel"] as? Int ?? self.level
                print("[IncubatorViewModel] 🎉 Speech level-up to Lv.\(newLevel), triggering ceremony + profiling")
                self.loadLocalData()
                Task {
                    await self.performLevelUpCeremony()
                }
                Task {
                    await self.triggerProfiling(atLevel: newLevel)
                }
            }
        
        print("[IncubatorViewModel] ✅ Started observing LLM notifications")
    }
    
    /// 停止监听 LLM 调用成功通知
    func stopObservingLLMNotifications() {
        statusRefreshCancellable?.cancel()
        statusRefreshCancellable = nil
        levelUpCancellable?.cancel()
        levelUpCancellable = nil
    }
    
    // MARK: - Local Data (replaces fetchStatus)
    
    /// 加载本地数据（替代 fetchStatus）
    /// Validates: Requirements 5.3, 11.6
    func loadLocalData() {
        profile = profileStore.load()
        level = profile.level
        totalXP = profile.totalXP
        currentLevelXP = GhostTwinXP.currentLevelXP(totalXP: profile.totalXP)
        personalityTags = profile.personalityTags
        challengesRemaining = recordStore.challengesRemainingToday()
        
        // Also update cache for backward compatibility
        saveToCacheInternal()
        
        isError = false
        errorMessage = nil
    }
    
    // MARK: - Start Calibration (replaces fetchChallenge)
    
    /// 发起校准挑战（替代 fetchChallenge）
    /// 1. 加载 internal-ghost-calibration 技能
    /// 2. 构建 user message
    /// 3. 调用 LLM via executeSkill
    /// 4. 解析 JSON 响应
    /// 5. 持久化中间状态
    /// Validates: Requirements 5.3, 5.4, 5.5, 12.4
    func startCalibration() async {
        guard !isLoadingChallenge else { return }
        guard hasCompletedProfiling else {
            FileLogger.log("[IncubatorViewModel] startCalibration blocked: profiling not completed")
            return
        }
        isLoadingChallenge = true
        
        do {
            // 1. Load calibration skill
            guard let skill = SkillManager.shared.skill(byId: SkillModel.internalGhostCalibrationId) else {
                throw NSError(domain: "IncubatorViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "校准技能未找到"])
            }
            
            // 2. Build user message
            let records = recordStore.loadAll()
            let userMessage = buildChallengeUserMessage(profile: profile, records: records)
            
            // 3. Call LLM via executeSkill
            let result = try await GhostypeAPIClient.shared.executeSkill(
                systemPrompt: skill.systemPrompt,
                message: userMessage,
                context: .noInput
            )
            
            // 4. Parse challenge
            FileLogger.log("[IncubatorViewModel] LLM raw response: \(result.prefix(500))")
            let challenge: LocalCalibrationChallenge = try LLMJsonParser.parse(result)
            
            // 5. Persist intermediate state
            let flowState = CalibrationFlowState(
                phase: .challenging,
                challenge: challenge,
                selectedOption: nil,
                customAnswer: nil,
                retryCount: 0,
                updatedAt: Date()
            )
            recoveryManager.saveCalibrationFlowState(flowState)
            
            // 6. Update UI
            currentChallenge = challenge
            showReceiptSlip = true
            isError = false
            errorMessage = nil
        } catch {
            isError = true
            errorMessage = "\(error.localizedDescription)"
            FileLogger.log("[IncubatorViewModel] startCalibration failed: \(error)")
        }
        
        isLoadingChallenge = false
    }

    // MARK: - Submit Answer (replaces submitAnswer(challengeId:selectedOption:))
    
    /// 提交校准答案（支持自定义答案）
    /// Validates: Requirements 6.2, 6.3, 6.4, 6.5, 6.6, 7.1, 7.2, 12.4, 12.8
    func submitAnswer(selectedOption: Int?, customAnswer: String?) async {
        guard !isSubmittingAnswer, let challenge = currentChallenge else { return }
        isSubmittingAnswer = true
        
        do {
            // 1. Save analyzing state
            let flowState = CalibrationFlowState(
                phase: .analyzing,
                challenge: challenge,
                selectedOption: selectedOption,
                customAnswer: customAnswer,
                retryCount: 0,
                updatedAt: Date()
            )
            recoveryManager.saveCalibrationFlowState(flowState)
            
            // 2. Load calibration skill
            guard let skill = SkillManager.shared.skill(byId: SkillModel.internalGhostCalibrationId) else {
                throw NSError(domain: "IncubatorViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "校准技能未找到"])
            }
            
            // 3. Build analysis message
            let records = recordStore.loadAll()
            let userMessage = buildAnalysisUserMessage(
                profile: profile,
                challenge: challenge,
                selectedOption: selectedOption,
                customAnswer: customAnswer,
                records: records
            )
            
            // 4. Call LLM
            let result = try await GhostypeAPIClient.shared.executeSkill(
                systemPrompt: skill.systemPrompt,
                message: userMessage,
                context: .noInput
            )
            
            // 5. Parse analysis response
            let analysis: CalibrationAnalysisResponse = try LLMJsonParser.parse(result)
            
            // 6. Merge tags
            let newTags = analysis.profileDiff.newTags
            var updatedTags = profile.personalityTags
            for tag in newTags {
                if !updatedTags.contains(tag) {
                    updatedTags.append(tag)
                }
            }
            
            // 7. Calculate XP
            let xpReward = GhostTwinXP.calibrationXPReward
            let oldXP = profile.totalXP
            let newXP = oldXP + xpReward
            let levelCheck = GhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: newXP)
            
            // 8. Update profile
            profile.personalityTags = updatedTags
            profile.totalXP = newXP
            profile.level = GhostTwinXP.calculateLevel(totalXP: newXP)
            profile.version += 1
            profile.updatedAt = Date()
            try profileStore.save(profile)
            
            // 9. Save calibration record
            let record = CalibrationRecord(
                id: UUID(),
                scenario: challenge.scenario,
                options: challenge.options,
                selectedOption: customAnswer != nil ? -1 : (selectedOption ?? 0),
                customAnswer: customAnswer,
                xpEarned: xpReward,
                ghostResponse: analysis.ghostResponse,
                profileDiff: String(data: try JSONEncoder().encode(analysis.profileDiff), encoding: .utf8),
                createdAt: Date()
            )
            recordStore.append(record)
            
            // 10. Update UI state
            level = profile.level
            totalXP = profile.totalXP
            currentLevelXP = GhostTwinXP.currentLevelXP(totalXP: newXP)
            personalityTags = profile.personalityTags
            ghostResponse = analysis.ghostResponse
            challengesRemaining = recordStore.challengesRemainingToday()
            
            // 11. Clear calibration flow state
            recoveryManager.clearCalibrationFlowState()
            
            // 12. Check level-up → trigger ceremony + profiling
            if levelCheck.leveledUp {
                Task {
                    await performLevelUpCeremony()
                }
                // Trigger profiling in background (non-blocking)
                Task {
                    await triggerProfiling(atLevel: levelCheck.newLevel)
                }
            }
            
            // 13. Hide receipt slip
            showReceiptSlip = false
            currentChallenge = nil
            
            // 14. Save cache
            saveToCacheInternal()
            
            isError = false
            errorMessage = nil
        } catch {
            isError = true
            errorMessage = error.localizedDescription
            // Don't clear flow state on error — allow retry (Req 12.8)
            showReceiptSlip = false
            currentChallenge = nil
            FileLogger.log("[IncubatorViewModel] submitAnswer failed: \(error)")
        }
        
        isSubmittingAnswer = false
    }

    // MARK: - Profiling (triggered on level-up)
    
    /// LLM 构筑结果的 JSON 摘要部分
    private struct ProfilingSummary: Decodable {
        let summary: String
        let refinedTags: [String]
    }
    
    /// 触发人格构筑（升级时调用，非阻塞）
    /// Validates: Requirements 7.1, 7.2, 7.5, 7.6, 7.7, 12.5, 12.7, 12.9
    private func triggerProfiling(atLevel level: Int) async {
        // Save profiling state
        let unconsumedCorpus = corpusStore.unconsumed()
        let corpusIds = unconsumedCorpus.map { $0.id }
        let profilingState = ProfilingFlowState(
            phase: .running,
            triggerLevel: level,
            corpusIds: corpusIds,
            retryCount: 0,
            maxRetries: 3,
            updatedAt: Date()
        )
        recoveryManager.saveProfilingFlowState(profilingState)
        
        do {
            guard let skill = SkillManager.shared.skill(byId: SkillModel.internalGhostProfilingId) else {
                throw NSError(domain: "IncubatorViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "构筑技能未找到"])
            }
            
            let records = recordStore.loadAll()
            let userMessage = buildProfilingUserMessage(
                profile: profile,
                previousReport: nil,
                corpus: unconsumedCorpus,
                records: records
            )
            
            let result = try await GhostypeAPIClient.shared.executeSkill(
                systemPrompt: skill.systemPrompt,
                message: userMessage,
                context: .noInput
            )
            
            // Parse profiling result — extract summary and refined_tags from the JSON at the end
            if let jsonStart = result.range(of: "{\"summary\""),
               let jsonEnd = result.range(of: "}", options: .backwards, range: jsonStart.lowerBound..<result.endIndex) {
                let jsonStr = String(result[jsonStart.lowerBound...jsonEnd.upperBound])
                if let data = jsonStr.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    if let summary = try? decoder.decode(ProfilingSummary.self, from: data) {
                        profile.personalityTags = summary.refinedTags
                        profile.profileText = result
                        profile.updatedAt = Date()
                        try profileStore.save(profile)
                        
                        // Mark corpus as consumed
                        corpusStore.markConsumed(ids: corpusIds, atLevel: level)
                        
                        // Update UI
                        personalityTags = profile.personalityTags
                    }
                }
            }
            
            // Clear profiling state
            recoveryManager.clearProfilingFlowState()
            
        } catch {
            // Increment retry count, keep state for recovery
            var state = profilingState
            state.retryCount += 1
            state.phase = .pending
            if state.retryCount >= state.maxRetries {
                recoveryManager.clearProfilingFlowState()
                FileLogger.log("[IncubatorViewModel] Profiling gave up after \(state.maxRetries) retries")
            } else {
                recoveryManager.saveProfilingFlowState(state)
                FileLogger.log("[IncubatorViewModel] Profiling failed, will retry (attempt \(state.retryCount)/\(state.maxRetries))")
            }
        }
    }
    
    // MARK: - Recovery (app launch)
    
    /// 启动时检查并恢复中断流程
    /// Validates: Requirements 12.3, 12.4, 12.5, 12.6, 12.7, 12.10
    func checkAndRecover() async {
        // Check calibration flow state
        if let calibState = recoveryManager.loadCalibrationFlowState() {
            switch calibState.phase {
            case .challenging:
                if let challenge = calibState.challenge {
                    currentChallenge = challenge
                    showReceiptSlip = true
                    FileLogger.log("[IncubatorViewModel] Recovered calibration at challenging phase")
                }
            case .analyzing:
                if let challenge = calibState.challenge {
                    // Re-submit the answer
                    currentChallenge = challenge
                    await submitAnswer(selectedOption: calibState.selectedOption, customAnswer: calibState.customAnswer)
                }
            case .idle:
                break
            }
        }
        
        // Check profiling flow state (non-blocking)
        if let profState = recoveryManager.loadProfilingFlowState() {
            if profState.phase == .pending, profState.retryCount < profState.maxRetries {
                if let triggerLevel = profState.triggerLevel {
                    Task {
                        await triggerProfiling(atLevel: triggerLevel)
                    }
                }
            }
        }
    }

    // MARK: - Level-Up Ceremony
    
    /// 执行升级仪式动效序列
    /// Validates: Requirements 6.1, 6.2, 6.5
    func performLevelUpCeremony() async {
        isLevelingUp = true
        
        // Phase 1: Flash all pixels
        levelUpPhase = 1
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Phase 2: Background pixels turn off
        levelUpPhase = 2
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Phase 3: Ghost brightness increases
        levelUpPhase = 3
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Phase 4: Reset and resume normal state
        matrixModel.shuffleActivationOrder(seed: nil)
        matrixModel.saveActivationOrder()
        
        levelUpPhase = 0
        isLevelingUp = false
        
        print("[IncubatorViewModel] 🎉 Level-up ceremony completed (Lv.\(level))")
    }
    
    // MARK: - Idle Text Cycling
    
    /// 开始闲置文案循环
    func startIdleTextCycle() {
        stopIdleTextCycle()
        showNextIdleText()
        scheduleNextIdleText()
    }
    
    /// 停止闲置文案循环
    func stopIdleTextCycle() {
        idleTextTimer?.invalidate()
        idleTextTimer = nil
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        isTypingIdle = false
    }
    
    // MARK: - Cache Methods
    
    /// 将当前状态保存到 UserDefaults 缓存
    func saveToCache() {
        saveToCacheInternal()
    }
    
    /// 从 UserDefaults 缓存加载状态
    func loadFromCache() {
        loadFromCacheInternal()
    }
    
    // MARK: - Private Cache Implementation
    
    private func saveToCacheInternal() {
        let defaults = UserDefaults.standard
        defaults.set(level, forKey: GhostTwinCacheKey.level.rawValue)
        defaults.set(totalXP, forKey: GhostTwinCacheKey.totalXP.rawValue)
        defaults.set(currentLevelXP, forKey: GhostTwinCacheKey.currentLevelXP.rawValue)
        defaults.set(personalityTags, forKey: GhostTwinCacheKey.personalityTags.rawValue)
        defaults.set(challengesRemaining, forKey: GhostTwinCacheKey.challengesRemaining.rawValue)
        print("[IncubatorViewModel] 💾 Saved state to cache (Lv.\(level), XP: \(totalXP))")
    }
    
    private func loadFromCacheInternal() {
        let defaults = UserDefaults.standard
        
        let cachedLevel = defaults.integer(forKey: GhostTwinCacheKey.level.rawValue)
        if cachedLevel > 0 {
            level = cachedLevel
        }
        
        totalXP = defaults.integer(forKey: GhostTwinCacheKey.totalXP.rawValue)
        currentLevelXP = defaults.integer(forKey: GhostTwinCacheKey.currentLevelXP.rawValue)
        
        if let tags = defaults.stringArray(forKey: GhostTwinCacheKey.personalityTags.rawValue) {
            personalityTags = tags
        }
        
        challengesRemaining = defaults.integer(forKey: GhostTwinCacheKey.challengesRemaining.rawValue)
        
        print("[IncubatorViewModel] ✅ Loaded state from cache (Lv.\(level), XP: \(totalXP))")
    }
    
    // MARK: - Private Idle Text Implementation
    
    private func showNextIdleText() {
        let texts = L.Incubator.idleTexts(forLevel: level)
        guard !texts.isEmpty else { return }
        
        let text = texts.randomElement() ?? texts[0]
        startTypewriterEffect(text: text)
    }
    
    private func startTypewriterEffect(text: String) {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        
        fullIdleText = text
        typewriterIndex = 0
        idleText = ""
        isTypingIdle = true
        
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if self.typewriterIndex < self.fullIdleText.count {
                    let index = self.fullIdleText.index(self.fullIdleText.startIndex, offsetBy: self.typewriterIndex)
                    self.idleText = String(self.fullIdleText[self.fullIdleText.startIndex...index])
                    self.typewriterIndex += 1
                } else {
                    timer.invalidate()
                    self.typewriterTimer = nil
                    self.isTypingIdle = false
                }
            }
        }
    }
    
    // MARK: - User Message Builders (delegates to MessageBuilder)
    
    /// 构建出题阶段的 user message
    private func buildChallengeUserMessage(profile: GhostTwinProfile, records: [CalibrationRecord]) -> String {
        MessageBuilder.buildChallengeUserMessage(profile: profile, records: records)
    }
    
    /// 构建分析阶段的 user message（支持自定义答案标注）
    private func buildAnalysisUserMessage(profile: GhostTwinProfile, challenge: LocalCalibrationChallenge, selectedOption: Int?, customAnswer: String?, records: [CalibrationRecord]) -> String {
        MessageBuilder.buildAnalysisUserMessage(profile: profile, challenge: challenge, selectedOption: selectedOption, customAnswer: customAnswer, records: records)
    }
    
    /// 构建构筑阶段的 user message
    private func buildProfilingUserMessage(profile: GhostTwinProfile, previousReport: String?, corpus: [ASRCorpusEntry], records: [CalibrationRecord]) -> String {
        MessageBuilder.buildProfilingUserMessage(profile: profile, previousReport: previousReport, corpus: corpus, records: records)
    }
    
    private func scheduleNextIdleText() {
        let interval = Double.random(in: 8...15)
        
        idleTextTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.showNextIdleText()
                self.scheduleNextIdleText()
            }
        }
    }
}
