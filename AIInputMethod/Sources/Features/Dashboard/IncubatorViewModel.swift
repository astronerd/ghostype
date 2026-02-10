//
//  IncubatorViewModel.swift
//  AIInputMethod
//
//  Ghost Twin 孵化室 ViewModel
//  管理等级、经验值、校准挑战、闲置文案等状态
//  Validates: Requirements 6.3, 6.4, 7.1, 7.3, 7.5, 8.4, 10.1, 10.2, 10.3
//

import Foundation
import SwiftUI
import Combine

// MARK: - Notification Names

extension Notification.Name {
    /// LLM 调用成功后通知 Ghost Twin 刷新状态
    /// Validates: Requirements 7.6
    static let ghostTwinStatusShouldRefresh = Notification.Name("ghostTwinStatusShouldRefresh")
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

// MARK: - IncubatorViewModel

/// Ghost Twin 孵化室 ViewModel
/// 管理等级、经验值、校准挑战、闲置文案等状态
/// Validates: Requirements 6.3, 6.4, 7.1, 7.3, 7.5, 8.4, 10.1, 10.2, 10.3
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
    
    /// 当前校准挑战
    var currentChallenge: CalibrationChallenge?
    
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
    
    // MARK: - Models
    
    /// 点阵数据模型
    let matrixModel = GhostMatrixModel()
    
    // MARK: - Computed Properties
    
    /// Ghost 透明度，随等级线性递增
    /// Lv.1 = 0.1, Lv.2 = 0.2, ..., Lv.10 = 1.0
    /// Validates: Requirements 3.5, 6.3
    var ghostOpacity: Double { Double(level) * 0.1 }
    
    /// 同步率百分比
    var syncRate: Int { level * 10 }
    
    /// 当前等级进度 (0.0 ~ 1.0)
    var progressFraction: Double { Double(currentLevelXP) / 10_000.0 }
    
    /// 当前动效阶段
    /// Validates: Requirements 6.4
    var animationPhase: AnimationPhase {
        Self.animationPhase(forLevel: level)
    }
    
    // MARK: - Private Properties
    
    /// 闲置文案循环 Timer
    private var idleTextTimer: Timer?
    
    /// 打字机效果 Timer
    private var typewriterTimer: Timer?
    
    /// 当前打字机效果的完整文本
    private var fullIdleText: String = ""
    
    /// 当前打字机效果的字符索引
    private var typewriterIndex: Int = 0
    
    /// NotificationCenter 订阅（LLM 调用成功后刷新 status）
    /// Validates: Requirements 7.6
    private var statusRefreshCancellable: AnyCancellable?
    
    // MARK: - Static Helpers (for testability)
    
    /// 根据等级返回动效阶段
    /// - Parameter level: 等级 (1~10)
    /// - Returns: 对应的 AnimationPhase
    /// Validates: Requirements 6.4
    static func animationPhase(forLevel level: Int) -> AnimationPhase {
        switch level {
        case 1...3: return .glitch
        case 4...6: return .breathing
        case 7...9: return .awakening
        case 10: return .complete
        default:
            // 超出范围时的安全回退
            if level < 1 { return .glitch }
            return .complete
        }
    }
    
    /// 根据等级返回闲置文案分组索引
    /// - Parameter level: 等级 (1~10)
    /// - Returns: 分组索引 (0=懵懂, 1=有个性, 2=自信, 3=完全体)
    /// Validates: Requirements 10.2
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
    /// - Parameter level: 等级 (1~10)
    /// - Returns: 透明度 (0.1 ~ 1.0)
    /// Validates: Requirements 3.5, 6.3
    static func ghostOpacity(forLevel level: Int) -> Double {
        return Double(level) * 0.1
    }
    
    // MARK: - LLM Notification Observer
    
    /// 开始监听 LLM 调用成功通知，自动刷新 Ghost Twin status
    /// 在 Dashboard 生命周期内调用（IncubatorPage onAppear）
    /// Validates: Requirements 7.6
    func startObservingLLMNotifications() {
        // 避免重复订阅
        stopObservingLLMNotifications()
        
        statusRefreshCancellable = NotificationCenter.default
            .publisher(for: .ghostTwinStatusShouldRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                print("[IncubatorViewModel] 🔄 Received LLM success notification, refreshing Ghost Twin status")
                Task {
                    await self.fetchStatus()
                }
            }
        
        print("[IncubatorViewModel] ✅ Started observing LLM notifications")
    }
    
    /// 停止监听 LLM 调用成功通知
    /// 在 Dashboard 生命周期内调用（IncubatorPage onDisappear）
    func stopObservingLLMNotifications() {
        statusRefreshCancellable?.cancel()
        statusRefreshCancellable = nil
    }
    
    // MARK: - API Methods
    
    /// 获取 Ghost Twin 状态
    /// 成功时更新所有状态并写入缓存，失败时从缓存恢复
    /// Validates: Requirements 7.1, 7.3, 7.5
    func fetchStatus() async {
        do {
            let response = try await GhostypeAPIClient.shared.fetchGhostTwinStatus()
            
            // 更新状态
            level = response.level
            totalXP = response.total_xp
            currentLevelXP = response.current_level_xp
            personalityTags = response.personality_tags
            challengesRemaining = response.challenges_remaining_today
            
            // 写入缓存
            saveToCacheInternal()
            
            // 清除错误状态
            isError = false
            errorMessage = nil
            
        } catch {
            // API 失败，从缓存恢复
            loadFromCacheInternal()
            
            // 静默失败，不弹错误提示
            print("[IncubatorViewModel] ⚠️ fetchStatus failed: \(error.localizedDescription), using cached values")
        }
    }
    
    /// 获取当日校准挑战
    /// Validates: Requirements 8.4
    func fetchChallenge() async {
        guard !isLoadingChallenge else { return }
        
        isLoadingChallenge = true
        
        do {
            let challenge = try await GhostypeAPIClient.shared.fetchCalibrationChallenge()
            currentChallenge = challenge
            showReceiptSlip = true
            isError = false
            errorMessage = nil
        } catch {
            isError = true
            errorMessage = error.localizedDescription
            print("[IncubatorViewModel] ⚠️ fetchChallenge failed: \(error.localizedDescription)")
        }
        
        isLoadingChallenge = false
    }
    
    /// 提交校准答案
    /// - Parameters:
    ///   - challengeId: 挑战 ID
    ///   - selectedOption: 用户选择的选项索引 (0-based)
    /// Validates: Requirements 8.4
    func submitAnswer(challengeId: String, selectedOption: Int) async {
        guard !isSubmittingAnswer else { return }
        
        isSubmittingAnswer = true
        
        do {
            let response = try await GhostypeAPIClient.shared.submitCalibrationAnswer(
                challengeId: challengeId,
                selectedOption: selectedOption
            )
            
            // 检测是否升级
            let previousLevel = level
            
            // 更新状态
            totalXP = response.new_total_xp
            level = response.new_level
            currentLevelXP = totalXP - (level - 1) * 10_000
            personalityTags = response.personality_tags_updated
            ghostResponse = response.ghost_response
            
            // 减少剩余挑战次数
            if challengesRemaining > 0 {
                challengesRemaining -= 1
            }
            
            // 写入缓存
            saveToCacheInternal()
            
            // 检测升级
            if response.new_level > previousLevel {
                // 触发升级仪式动效
                Task {
                    await performLevelUpCeremony()
                }
            }
            
            // 隐藏热敏纸条
            showReceiptSlip = false
            currentChallenge = nil
            
            isError = false
            errorMessage = nil
            
        } catch {
            isError = true
            errorMessage = error.localizedDescription
            print("[IncubatorViewModel] ⚠️ submitAnswer failed: \(error.localizedDescription)")
        }
        
        isSubmittingAnswer = false
    }
    
    // MARK: - Level-Up Ceremony
    
    /// 执行升级仪式动效序列
    /// Phase 1: 全屏像素闪烁 (0.5s)
    /// Phase 2: 背景像素熄灭 (0.3s)
    /// Phase 3: Ghost 亮度提升 (0.5s)
    /// Phase 4: 重置并恢复正常状态
    /// Validates: Requirements 6.1, 6.2, 6.5
    func performLevelUpCeremony() async {
        isLevelingUp = true
        
        // Phase 1: Flash all pixels (全屏像素闪烁)
        levelUpPhase = 1
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Phase 2: Background pixels turn off (背景像素熄灭)
        levelUpPhase = 2
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        
        // Phase 3: Ghost brightness increases (Ghost 亮度提升)
        levelUpPhase = 3
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Phase 4: Reset and resume normal state
        // 升级后重置背景像素的点亮序列，保持 Ghost Logo 基础亮度
        // Validates: Requirements 6.5
        matrixModel.shuffleActivationOrder(seed: nil)
        matrixModel.saveActivationOrder()
        
        levelUpPhase = 0
        isLevelingUp = false
        
        print("[IncubatorViewModel] 🎉 Level-up ceremony completed (Lv.\(level))")
    }
    
    // MARK: - Idle Text Cycling
    
    /// 开始闲置文案循环
    /// 每 8~15 秒随机切换一条，使用打字机效果逐字显示
    /// Validates: Requirements 10.1, 10.2, 10.3
    func startIdleTextCycle() {
        // 先停止已有的 Timer
        stopIdleTextCycle()
        
        // 立即显示一条
        showNextIdleText()
        
        // 启动循环 Timer
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
    
    /// 将当前状态保存到 UserDefaults
    private func saveToCacheInternal() {
        let defaults = UserDefaults.standard
        defaults.set(level, forKey: GhostTwinCacheKey.level.rawValue)
        defaults.set(totalXP, forKey: GhostTwinCacheKey.totalXP.rawValue)
        defaults.set(currentLevelXP, forKey: GhostTwinCacheKey.currentLevelXP.rawValue)
        defaults.set(personalityTags, forKey: GhostTwinCacheKey.personalityTags.rawValue)
        defaults.set(challengesRemaining, forKey: GhostTwinCacheKey.challengesRemaining.rawValue)
        print("[IncubatorViewModel] 💾 Saved state to cache (Lv.\(level), XP: \(totalXP))")
    }
    
    /// 从 UserDefaults 加载状态
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
    
    /// 显示下一条闲置文案
    private func showNextIdleText() {
        let texts = L.Incubator.idleTexts(forLevel: level)
        guard !texts.isEmpty else { return }
        
        // 随机选取一条
        let text = texts.randomElement() ?? texts[0]
        
        // 开始打字机效果
        startTypewriterEffect(text: text)
    }
    
    /// 开始打字机效果
    /// - Parameter text: 要逐字显示的完整文本
    private func startTypewriterEffect(text: String) {
        // 停止之前的打字机效果
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        
        fullIdleText = text
        typewriterIndex = 0
        idleText = ""
        isTypingIdle = true
        
        // 每 0.05 秒显示一个字符
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
                    // 打字机效果完成
                    timer.invalidate()
                    self.typewriterTimer = nil
                    self.isTypingIdle = false
                }
            }
        }
    }
    
    /// 安排下一次闲置文案切换
    private func scheduleNextIdleText() {
        // 随机 8~15 秒
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
