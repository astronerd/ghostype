import Foundation
import SwiftUI

// MARK: - Dashboard Phase

/// Dashboard 状态机的两种主要状态
/// - onboarding: 初次启动状态，显示权限申请和初始设置流程
/// - normal: 正常使用状态，显示完整功能模块
enum DashboardPhase: Equatable {
    case onboarding(OnboardingStep)
    case normal
    
    /// 判断是否处于 Onboarding 状态
    var isOnboarding: Bool {
        if case .onboarding = self {
            return true
        }
        return false
    }
    
    /// 获取当前 Onboarding 步骤（如果处于 Onboarding 状态）
    var currentOnboardingStep: OnboardingStep? {
        if case .onboarding(let step) = self {
            return step
        }
        return nil
    }
}

// MARK: - Onboarding Step

/// Onboarding 流程的三个步骤
/// - auth: 登录/注册
/// - hotkey: 快捷键配置
/// - permissions: 权限申请
enum OnboardingStep: Int, CaseIterable {
    case auth = 0
    case hotkey = 1
    case permissions = 2
    
    /// 步骤显示文本（用于步骤指示器）
    var displayText: String {
        switch self {
        case .auth: return "账号"
        case .hotkey: return "快捷键"
        case .permissions: return "权限"
        }
    }
    
    /// 步骤编号（从 1 开始，用于 UI 显示）
    var stepNumber: Int {
        return rawValue + 1
    }
    
    /// 总步骤数
    static var totalSteps: Int {
        return allCases.count
    }
    
    /// 获取下一个步骤（如果存在）
    var next: OnboardingStep? {
        return OnboardingStep(rawValue: rawValue + 1)
    }
    
    /// 获取上一个步骤（如果存在）
    var previous: OnboardingStep? {
        return OnboardingStep(rawValue: rawValue - 1)
    }
}

// MARK: - UserDefaults Keys

/// Dashboard 相关的 UserDefaults 键
enum DashboardUserDefaultsKey: String {
    case isOnboardingComplete = "dashboard.isOnboardingComplete"
    case currentOnboardingStep = "dashboard.currentOnboardingStep"
}

// MARK: - Dashboard State

/// Dashboard 状态机
/// 管理 Onboarding 和 Normal 两种状态，控制 UI 展示逻辑
/// 使用 @Observable 宏实现响应式状态管理（macOS 14+）
@Observable
class DashboardState {
    
    // MARK: - Properties
    
    /// 当前 Dashboard 阶段
    var phase: DashboardPhase
    
    /// 当前选中的导航项（Normal 状态下使用）
    var selectedNavItem: NavItem = .account
    
    /// UserDefaults 实例（支持依赖注入，便于测试）
    private let userDefaults: UserDefaults
    
    // MARK: - Computed Properties
    
    /// 是否已完成 Onboarding
    var isOnboardingComplete: Bool {
        return userDefaults.bool(forKey: DashboardUserDefaultsKey.isOnboardingComplete.rawValue)
    }
    
    /// Sidebar 导航是否启用（Onboarding 状态下禁用）
    var isSidebarNavigationEnabled: Bool {
        return !phase.isOnboarding
    }
    
    // MARK: - Initialization
    
    /// 初始化 Dashboard 状态
    /// - Parameter userDefaults: UserDefaults 实例，默认为 .standard
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // 从 UserDefaults 恢复状态
        // 检查两个 key：dashboard.isOnboardingComplete 和 hasCompletedOnboarding（AIInputMethodApp 用的）
        let dashboardOnboardingComplete = userDefaults.bool(forKey: DashboardUserDefaultsKey.isOnboardingComplete.rawValue)
        let appOnboardingComplete = userDefaults.bool(forKey: "hasCompletedOnboarding")
        
        if dashboardOnboardingComplete || appOnboardingComplete {
            // 已完成 Onboarding，进入 Normal 状态
            self.phase = .normal
            // 同步两个标记
            if !dashboardOnboardingComplete {
                userDefaults.set(true, forKey: DashboardUserDefaultsKey.isOnboardingComplete.rawValue)
            }
        } else {
            // 未完成 Onboarding，恢复到上次的步骤或从头开始
            let savedStep = userDefaults.integer(forKey: DashboardUserDefaultsKey.currentOnboardingStep.rawValue)
            let step = OnboardingStep(rawValue: savedStep) ?? .auth
            self.phase = .onboarding(step)
        }
    }
    
    // MARK: - State Transition Methods
    
    /// 完成 Onboarding 流程，转换到 Normal 状态
    func completeOnboarding() {
        // 标记 Onboarding 已完成
        userDefaults.set(true, forKey: DashboardUserDefaultsKey.isOnboardingComplete.rawValue)
        // 清除保存的步骤
        userDefaults.removeObject(forKey: DashboardUserDefaultsKey.currentOnboardingStep.rawValue)
        // 转换到 Normal 状态
        transitionToNormal()
    }
    
    /// 转换到 Normal 状态
    func transitionToNormal() {
        phase = .normal
    }
    
    /// 前进到下一个 Onboarding 步骤
    /// 如果已经是最后一步，则完成 Onboarding
    func advanceOnboardingStep() {
        guard case .onboarding(let currentStep) = phase else {
            return
        }
        
        if let nextStep = currentStep.next {
            // 还有下一步，前进
            phase = .onboarding(nextStep)
            // 保存当前步骤
            userDefaults.set(nextStep.rawValue, forKey: DashboardUserDefaultsKey.currentOnboardingStep.rawValue)
        } else {
            // 已经是最后一步，完成 Onboarding
            completeOnboarding()
        }
    }
    
    /// 返回上一个 Onboarding 步骤
    func goBackOnboardingStep() {
        guard case .onboarding(let currentStep) = phase else {
            return
        }
        
        if let previousStep = currentStep.previous {
            phase = .onboarding(previousStep)
            // 保存当前步骤
            userDefaults.set(previousStep.rawValue, forKey: DashboardUserDefaultsKey.currentOnboardingStep.rawValue)
        }
    }
    
    /// 跳转到指定的 Onboarding 步骤
    /// - Parameter step: 目标步骤
    func goToOnboardingStep(_ step: OnboardingStep) {
        guard phase.isOnboarding else {
            return
        }
        
        phase = .onboarding(step)
        userDefaults.set(step.rawValue, forKey: DashboardUserDefaultsKey.currentOnboardingStep.rawValue)
    }
    
    // MARK: - Reset Methods
    
    /// 重置 Onboarding 状态（用于测试或用户手动重置）
    func resetOnboarding() {
        userDefaults.set(false, forKey: DashboardUserDefaultsKey.isOnboardingComplete.rawValue)
        userDefaults.set(OnboardingStep.hotkey.rawValue, forKey: DashboardUserDefaultsKey.currentOnboardingStep.rawValue)
        phase = .onboarding(.auth)
    }
}

