import SwiftUI
import AppKit

// MARK: - OnboardingContentView

/// Onboarding 内容视图
/// 复用现有 OnboardingWindow 的步骤视图，集成到 Dashboard 中
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.6
struct OnboardingContentView: View {
    
    // MARK: - Properties
    
    /// Dashboard 状态机
    @Environment(DashboardState.self) private var dashboardState
    
    /// 权限管理器
    @StateObject private var permissionManager = PermissionManager()
    
    /// 应用设置
    @ObservedObject private var settings = AppSettings.shared
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: 顶部步骤指示器
            // Requirement 2.2: THE Onboarding section SHALL display step indicators showing current progress (e.g., 1/3, 2/3, 3/3)
            stepIndicatorBar
                .padding(.top, 24)
                .padding(.horizontal, 32)
            
            // MARK: 步骤内容区域
            // Requirement 2.3: THE Onboarding section SHALL include: hotkey configuration step, input mode selection step, permissions request step
            stepContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - Step Indicator Bar
    
    /// 步骤指示器栏
    private var stepIndicatorBar: some View {
        HStack(spacing: 0) {
            // 左侧：应用名称
            Text("GhosTYPE")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // 中间：步骤指示器
            HStack(spacing: 16) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    OnboardingStepIndicator(
                        step: step,
                        currentStep: currentStep,
                        onTap: {
                            // 只允许点击已完成的步骤或当前步骤
                            if step.rawValue <= currentStep.rawValue {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dashboardState.goToOnboardingStep(step)
                                }
                            }
                        }
                    )
                }
            }
            
            Spacer()
            
            // 右侧：步骤进度文本
            // Requirement 2.2: step indicators showing current progress (e.g., 1/3, 2/3, 3/3)
            Text("\(currentStep.stepNumber)/\(OnboardingStep.totalSteps)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
    
    // MARK: - Step Content View
    
    /// 步骤内容视图
    /// 根据当前步骤显示对应的视图，带有切换动画
    @ViewBuilder
    private var stepContentView: some View {
        // Requirement 2.4: WHEN user completes all onboarding steps, THE Dashboard SHALL animate transition to Normal_State
        // Requirement 2.6: WHEN transitioning to Normal_State, THE Dashboard SHALL hide onboarding section with fade-out animation
        Group {
            switch currentStep {
            case .hotkey:
                // 步骤 1: 快捷键配置
                Step1HotkeyView(
                    settings: settings,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dashboardState.advanceOnboardingStep()
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .inputMode:
                // 步骤 2: 输入模式选择
                Step2AutoModeView(
                    settings: settings,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dashboardState.advanceOnboardingStep()
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dashboardState.goBackOnboardingStep()
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .permissions:
                // 步骤 3: 权限申请
                Step3PermissionsView(
                    permissionManager: permissionManager,
                    onComplete: {
                        // Requirement 2.4 & 2.6: 完成后带动画过渡到 Normal 状态
                        withAnimation(.easeInOut(duration: 0.4)) {
                            dashboardState.completeOnboarding()
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dashboardState.goBackOnboardingStep()
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    // MARK: - Computed Properties
    
    /// 当前 Onboarding 步骤
    private var currentStep: OnboardingStep {
        dashboardState.phase.currentOnboardingStep ?? .hotkey
    }
}

// MARK: - OnboardingStepIndicator

/// 单个步骤指示器组件
struct OnboardingStepIndicator: View {
    let step: OnboardingStep
    let currentStep: OnboardingStep
    let onTap: () -> Void
    
    /// 是否已完成
    private var isCompleted: Bool {
        step.rawValue < currentStep.rawValue
    }
    
    /// 是否为当前步骤
    private var isCurrent: Bool {
        step == currentStep
    }
    
    /// 是否可点击（已完成或当前步骤）
    private var isClickable: Bool {
        step.rawValue <= currentStep.rawValue
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // 步骤圆圈
                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 28, height: 28)
                    
                    if isCompleted {
                        // 已完成：显示勾选图标
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        // 未完成：显示步骤编号
                        Text("\(step.stepNumber)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isCurrent ? .white : .secondary)
                    }
                }
                
                // 步骤文字
                Text(step.displayText)
                    .font(.system(size: 13, weight: isCurrent ? .medium : .regular))
                    .foregroundColor(isCurrent ? .primary : .secondary)
                
                // 连接线（非最后一步）
                if step != .permissions {
                    Rectangle()
                        .fill(isCompleted ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isClickable)
    }
    
    /// 圆圈背景颜色
    private var circleColor: Color {
        if isCompleted || isCurrent {
            return .accentColor
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingContentView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建测试用的 DashboardState
        let state = DashboardState()
        state.resetOnboarding()
        
        return OnboardingContentView()
            .environment(state)
            .frame(width: 680, height: 600)
    }
}
#endif
