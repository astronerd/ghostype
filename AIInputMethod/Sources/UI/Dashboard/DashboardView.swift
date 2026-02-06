import SwiftUI
import AppKit

// MARK: - Dashboard 主视图

/// Dashboard 主视图
/// 实现 HStack 双栏布局：固定宽度 Sidebar (220pt) + 自适应 Content 区域
/// 根据 DashboardState.phase 切换 Onboarding/Normal 内容
/// Requirements: 3.1, 3.2, 3.5
struct DashboardView: View {
    
    // MARK: - Properties
    
    /// Dashboard 状态机
    @State private var dashboardState = DashboardState()
    
    /// 权限管理器（用于检测权限状态）
    @State private var permissionManager = PermissionManager()
    
    /// 是否显示权限提醒 Banner
    @State private var showPermissionBanner = false
    
    /// Sidebar 固定宽度 (Requirement 3.1: 220pt)
    private let sidebarWidth: CGFloat = 220
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 权限提醒 Banner
            // Requirement 1.6: WHEN permissions are revoked after onboarding, THE Dashboard SHALL display a reminder banner
            if showPermissionBanner && dashboardState.phase == .normal {
                PermissionReminderBanner(
                    isAccessibilityGranted: permissionManager.isAccessibilityTrusted,
                    isMicrophoneGranted: permissionManager.isMicrophoneGranted,
                    onDismiss: { showPermissionBanner = false },
                    onOpenSettings: openPermissionSettings
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            HStack(spacing: 0) {
                // MARK: Sidebar (固定宽度 220pt)
                // Requirement 3.1: THE Dashboard SHALL display a Sidebar on the left side with fixed width of 220pt
                SidebarView(
                    selectedItem: $dashboardState.selectedNavItem,
                    isEnabled: dashboardState.isSidebarNavigationEnabled,
                    deviceId: DeviceIdManager.shared.truncatedId(),
                    quotaPercentage: QuotaManager.forTesting().usedPercentage
                )
                .frame(width: sidebarWidth)
                
                // 分隔线
                Divider()
                
                // MARK: Content Area (自适应宽度)
                // Requirement 3.2: THE Dashboard SHALL display a Content area on the right side that fills remaining space
                // Requirement 3.5: WHEN the window is resized, THE Content area SHALL adapt responsively while Sidebar maintains fixed width
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(dashboardState)
        .onAppear {
            checkPermissions()
        }
    }
    
    // MARK: - Permission Check
    
    /// 检查权限状态
    private func checkPermissions() {
        permissionManager.checkAccessibilityStatus()
        permissionManager.checkMicrophoneStatus()
        
        // 如果任一权限被撤销，显示提醒
        if !permissionManager.isAccessibilityTrusted || !permissionManager.isMicrophoneGranted {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPermissionBanner = true
            }
        }
    }
    
    /// 打开权限设置
    private func openPermissionSettings() {
        if !permissionManager.isAccessibilityTrusted {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else if !permissionManager.isMicrophoneGranted {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }
    
    // MARK: - Content Area
    
    /// 内容区域视图
    /// 根据 DashboardState.phase 切换显示 Onboarding 或 Normal 内容
    @ViewBuilder
    private var contentArea: some View {
        switch dashboardState.phase {
        case .onboarding:
            // Onboarding 状态：显示 Onboarding 内容
            // Requirement 2.1: WHILE in Onboarding_State, THE Dashboard SHALL display only the onboarding section in Content area
            // Requirement 2.6: WHEN transitioning to Normal_State, THE Dashboard SHALL hide onboarding section with fade-out animation
            OnboardingContentView()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            
        case .normal:
            // Normal 状态：根据选中的导航项显示对应页面
            normalContentView
                .transition(.opacity)
        }
    }
    
    /// Normal 状态下的内容视图
    @ViewBuilder
    private var normalContentView: some View {
        switch dashboardState.selectedNavItem {
        case .overview:
            OverviewPageWithData()
        case .memo:
            MemoPage()
        case .library:
            LibraryPageWithData()
        case .preferences:
            PreferencesPagePlaceholderView()
        }
    }
}

// MARK: - Sidebar Placeholder View

/// Sidebar 占位视图
/// 后续会替换为实际的 SidebarView (Task 5.5)
struct SidebarPlaceholderView: View {
    @Binding var selectedNavItem: NavItem
    var isEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题区域
            VStack(alignment: .leading, spacing: 4) {
                Text("GhosTYPE")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Dashboard")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // 导航项列表
            VStack(spacing: 4) {
                ForEach(NavItem.allCases) { item in
                    NavigationItemView(
                        item: item,
                        isSelected: selectedNavItem == item,
                        isEnabled: isEnabled
                    ) {
                        if isEnabled {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedNavItem = item
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // 底部设备信息区域
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.horizontal, 16)
                
                // 设备 ID
                HStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(DeviceIdManager.shared.truncatedId())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                
                // 额度进度条
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("本月额度")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("--")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // 进度条占位
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * 0.3, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        )
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Navigation Item View

/// 导航项视图
struct NavigationItemView: View {
    let item: NavItem
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 20)
                
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Visual Effect View

/// NSVisualEffectView 包装器，用于实现毛玻璃效果
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Placeholder Views

/// Onboarding 内容占位视图
/// 后续会替换为实际的 OnboardingContentView (Task 7.1)
struct OnboardingContentPlaceholderView: View {
    var dashboardState: DashboardState
    
    var body: some View {
        VStack(spacing: 24) {
            // 步骤指示器
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    StepIndicator(
                        step: step,
                        currentStep: dashboardState.phase.currentOnboardingStep ?? .hotkey
                    )
                }
            }
            .padding(.top, 32)
            
            Spacer()
            
            // 内容区域
            VStack(spacing: 16) {
                Image(systemName: stepIcon)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.blue)
                
                Text(stepTitle)
                    .font(.system(size: 24, weight: .semibold))
                
                Text(stepDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: 12) {
                if dashboardState.phase.currentOnboardingStep != .hotkey {
                    Button("上一步") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dashboardState.goBackOnboardingStep()
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 100)
                }
                
                Button(isLastStep ? "完成" : "下一步") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dashboardState.advanceOnboardingStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 100)
            }
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
    
    private var currentStep: OnboardingStep {
        dashboardState.phase.currentOnboardingStep ?? .hotkey
    }
    
    private var isLastStep: Bool {
        currentStep == .permissions
    }
    
    private var stepIcon: String {
        switch currentStep {
        case .hotkey: return "keyboard"
        case .inputMode: return "text.cursor"
        case .permissions: return "lock.shield"
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case .hotkey: return "设置快捷键"
        case .inputMode: return "选择输入模式"
        case .permissions: return "授权权限"
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case .hotkey: return "按住快捷键说话，松开完成输入"
        case .inputMode: return "选择手动模式或自动模式"
        case .permissions: return "需要辅助功能和麦克风权限才能正常工作"
        }
    }
}

/// 步骤指示器
struct StepIndicator: View {
    let step: OnboardingStep
    let currentStep: OnboardingStep
    
    private var isCompleted: Bool {
        step.rawValue < currentStep.rawValue
    }
    
    private var isCurrent: Bool {
        step == currentStep
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 步骤圆圈
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 28, height: 28)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
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
                    .frame(width: 40, height: 2)
            }
        }
    }
    
    private var circleColor: Color {
        if isCompleted {
            return .accentColor
        } else if isCurrent {
            return .accentColor
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

/// 概览页占位视图
/// 后续会替换为实际的 OverviewPage (Task 8.10)
struct OverviewPagePlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("概览")
                .font(.system(size: 20, weight: .semibold))
            
            Text("数据统计和使用情况将在这里显示")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
}

/// 历史库页占位视图
/// 后续会替换为实际的 LibraryPage (Task 10.8)
struct LibraryPagePlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("历史库")
                .font(.system(size: 20, weight: .semibold))
            
            Text("语音输入历史记录将在这里显示")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
}

/// 随心记页占位视图
/// 后续会替换为实际的 MemoPage (Task 9.1)
struct MemoPagePlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("随心记")
                .font(.system(size: 20, weight: .semibold))
            
            Text("语音便签将在这里显示")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
}

/// 偏好设置页包装视图
/// 使用实际的 PreferencesPage
struct PreferencesPagePlaceholderView: View {
    var body: some View {
        PreferencesPage()
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .frame(width: 1000, height: 700)
    }
}
#endif

// MARK: - Permission Reminder Banner

/// 权限提醒 Banner
/// Requirement 1.6: WHEN permissions are revoked after onboarding, THE Dashboard SHALL display a reminder banner
struct PermissionReminderBanner: View {
    let isAccessibilityGranted: Bool
    let isMicrophoneGranted: Bool
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            // 提示文字
            VStack(alignment: .leading, spacing: 2) {
                Text("权限需要更新")
                    .font(.system(size: 13, weight: .semibold))
                
                Text(permissionMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 打开设置按钮
            Button(action: onOpenSettings) {
                Text("打开设置")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.orange.opacity(0.1)
        )
        .overlay(
            Rectangle()
                .fill(Color.orange)
                .frame(height: 2),
            alignment: .bottom
        )
    }
    
    private var permissionMessage: String {
        var missing: [String] = []
        if !isAccessibilityGranted { missing.append("辅助功能") }
        if !isMicrophoneGranted { missing.append("麦克风") }
        return "缺少 \(missing.joined(separator: "、")) 权限，部分功能可能无法正常使用"
    }
}
