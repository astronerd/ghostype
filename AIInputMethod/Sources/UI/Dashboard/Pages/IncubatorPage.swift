//
//  IncubatorPage.swift
//  AIInputMethod
//
//  孵化室页面 - Ghost Twin 养成界面
//  屏中屏布局：CRT 点阵屏 + 等级信息栏 + 闲置文案
//  包含升级仪式动效（全屏闪烁 → 背景熄灭 → Ghost 亮度提升）
//  包含校准系统 UI（热敏纸条交互）
//
//  Validates: Requirements 2.1, 2.2, 2.3, 2.4, 6.1, 6.2, 6.5, 8a.1, 8a.5, 8a.6, 8.6
//

import SwiftUI

struct IncubatorPage: View {
    
    @State private var viewModel = IncubatorViewModel()
    
    /// ">> INCOMING..." 闪烁动画状态
    @State private var isBlinkingIncoming: Bool = false
    
    /// 🧪 Debug 测试面板开关
    @State private var showDebugPanel: Bool = false
    
    /// 是否正在显示 ghost_response 反馈语
    @State private var showGhostResponse: Bool = false
    
    // MARK: - CRT Frame Layout Constants
    // 含阴影图片裁掉全透明(alpha==0)后缩放，屏幕开口 320×240 @ (85,83)
    
    private static let crtFrameWidth: CGFloat = 530
    private static let crtFrameHeight: CGFloat = 482
    private static let screenWidth: CGFloat = 320
    private static let screenHeight: CGFloat = 240
    // 屏幕开口左上角在外壳图中的偏移
    private static let screenOffsetX: CGFloat = 85
    private static let screenOffsetY: CGFloat = 83
    
    // MARK: - Level-Up Computed Helpers
    
    /// 根据升级仪式阶段计算传递给 DotMatrixView 的 activePixels
    /// - Phase 0 (正常): 正常的 activePixels
    /// - Phase 1 (闪烁): 全部 19,200 像素点亮
    /// - Phase 2 (熄灭): 空集（背景像素全部熄灭）
    /// - Phase 3 (亮度提升): 仅 Ghost Logo 像素
    /// Validates: Requirements 6.2, 6.5
    private var effectiveActivePixels: Set<Int> {
        switch viewModel.levelUpPhase {
        case 1:
            // Phase 1: 全屏像素闪烁 - 点亮所有像素
            return Set(0..<GhostMatrixModel.totalPixels)
        case 2:
            // Phase 2: 背景像素熄灭 - 空集
            return Set()
        case 3:
            // Phase 3: Ghost 亮度提升 - 正常像素（新等级的 ghostOpacity 已更新）
            return viewModel.matrixModel.getActivePixels(wordCount: viewModel.currentLevelXP)
        default:
            // Phase 0: 正常状态
            return viewModel.matrixModel.getActivePixels(wordCount: viewModel.currentLevelXP)
        }
    }
    
    /// 根据升级仪式阶段计算传递给 DotMatrixView 的 ghostOpacity
    /// - Phase 1 (闪烁): 全亮 1.0
    /// - Phase 3 (亮度提升): 新等级的 ghostOpacity（已由 ViewModel 更新）
    /// Validates: Requirements 6.2
    private var effectiveGhostOpacity: Double {
        switch viewModel.levelUpPhase {
        case 1:
            // Phase 1: 全屏闪烁时全亮
            return 1.0
        default:
            return viewModel.ghostOpacity
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            
            // 页面标题
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L.Incubator.title)
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text1)
                
                Text(L.Incubator.subtitle)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text2)
            }
            .padding(.top, 21)
            .padding(.horizontal, 24)
            
            // Ghost Twin Status 信息栏（单行横排）
            ghostTwinStatusSection
                .padding(.horizontal, 24)
            
            // CRT 容器居中，下移 64px
            HStack {
                Spacer()
                crtContainer
                Spacer()
            }
            .padding(.top, 64)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
        .onAppear {
            viewModel.loadLocalData()
            Task {
                await viewModel.checkAndRecover()
            }
            viewModel.startIdleTextCycle()
            viewModel.startObservingLLMNotifications()
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isBlinkingIncoming = true
            }
        }
        .onDisappear {
            viewModel.stopIdleTextCycle()
            viewModel.stopObservingLLMNotifications()
        }
    }
    
    // MARK: - Ghost Twin Status Section
    
    private var ghostTwinStatusSection: some View {
        HStack(spacing: DS.Spacing.md) {
            // 标题图标
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "person.and.background.dotted")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.icon)
                Text("Ghost Twin")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Divider().frame(height: 14)
            
            statusChip(label: L.Incubator.statusLevel, value: "Lv.\(viewModel.level)")
            statusChip(label: L.Incubator.statusXP, value: "\(viewModel.currentLevelXP)/10k")
            statusChip(label: L.Incubator.statusSync, value: "\(viewModel.syncRate)%")
            statusChip(label: L.Incubator.statusChallenges, value: "\(viewModel.challengesRemaining)")
            statusChip(
                label: L.Incubator.statusPersonality,
                value: viewModel.personalityTags.isEmpty
                    ? L.Incubator.statusNone
                    : viewModel.personalityTags.prefix(2).joined(separator: ", ")
            )
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DS.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
    }
    
    private func statusChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DS.Colors.text2)
            Text(value)
                .font(DS.Typography.mono(11, weight: .medium))
                .foregroundColor(DS.Colors.text1)
        }
    }
    
    // MARK: - CRT Container
    
    private var crtContainer: some View {
            ZStack(alignment: .topLeading) {
                // 底层：屏幕开口处的黑色背景（比屏幕区域多 4px 以覆盖高光半透明边缘）
                Color.black
                    .frame(width: Self.screenWidth + 4, height: Self.screenHeight + 4)
                    .offset(x: Self.screenOffsetX - 2, y: Self.screenOffsetY - 2)
                
                // 点阵屏内容层 - 定位到屏幕开口位置
                ZStack {
                    // 点阵屏渲染层 (640×480 内部渲染，缩放到 320×240)
                    DotMatrixView(
                        activePixels: effectiveActivePixels,
                        ghostMask: viewModel.matrixModel.ghostMask,
                        ghostZone: viewModel.matrixModel.ghostZone,
                        ghostOpacity: effectiveGhostOpacity,
                        level: viewModel.level
                    )
                    .scaleEffect(0.5)
                    .frame(width: Self.screenWidth, height: Self.screenHeight)
                    
                    // RPG 对话框层 - 在 CRT 滤镜下方，覆盖像素
                    // 校准提示（INCOMING）或闲置文案
                    rpgDialogLayer
                    
                    // 等级信息栏 - CRT 屏幕内部顶部，RPG 像素风格
                    // Validates: Requirements 2.5
                    VStack {
                        LevelInfoBar(
                            level: viewModel.level,
                            progressFraction: viewModel.progressFraction,
                            syncRate: viewModel.syncRate
                        )
                        .padding(.horizontal, 6)
                        .padding(.top, 5)
                        
                        Spacer()
                    }
                    
                    // CRT 滤镜覆盖层（扫描线 + 暗角）
                    CRTEffectsView()
                    
                    // 升级仪式 Phase 1: 全屏像素闪烁覆盖层
                    // Validates: Requirements 6.1, 6.2
                    if viewModel.levelUpPhase == 1 {
                        Color.green
                            .opacity(0.3)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                    
                    // 校准挑战覆盖层 - 居中大窗口，盖住屏幕内容
                    // Validates: Requirements 8a.2, 8a.3, 8a.4, 8a.5
                    if viewModel.showReceiptSlip, let challenge = viewModel.currentChallenge {
                        ReceiptSlipView(
                            challenge: challenge,
                            onSelectOption: { selectedIndex in
                                handleOptionSelected(
                                    selectedOption: selectedIndex
                                )
                            },
                            onSubmitCustomAnswer: { customAnswer in
                                handleCustomAnswerSubmitted(
                                    customAnswer: customAnswer
                                )
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.showReceiptSlip = false
                                    viewModel.currentChallenge = nil
                                }
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 20)
                        .transition(.opacity)
                    }
                    
                    // (Ghost 反馈语现在复用底部 RPG 对话框，不再需要独立覆盖层)
                }
                .frame(width: Self.screenWidth + 4, height: Self.screenHeight + 4)
                .clipped()
                .offset(x: Self.screenOffsetX - 2, y: Self.screenOffsetY - 2)
                
                // 顶层：CRT 外壳图片遮罩（屏幕区域透明 + 高光半透明）
                CRTFrameImageView()
                    .frame(width: Self.crtFrameWidth, height: Self.crtFrameHeight)
                    .allowsHitTesting(false)
            }
            .frame(width: Self.crtFrameWidth, height: Self.crtFrameHeight)
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: viewModel.levelUpPhase)
            .animation(.easeInOut(duration: 0.3), value: viewModel.showReceiptSlip)
            .animation(.easeInOut(duration: 0.3), value: showGhostResponse)
    }
    
    // MARK: - Debug Section
    
    private var debugSection: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(showDebugPanel ? "🧪 Hide Debug" : "🧪 Debug") {
                    withAnimation { showDebugPanel.toggle() }
                }
                .font(.system(size: 9, design: .monospaced))
                .buttonStyle(.plain)
                .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, DS.Spacing.md)
            
            if showDebugPanel {
                debugTestPanel
            }
        }
    }
    
    // MARK: - RPG Dialog Layer (inside CRT screen)
    
    /// RPG 风格对话框层 - 显示在 CRT 屏幕内部底部
    /// 优先显示校准提示（INCOMING），否则显示闲置文案
    @ViewBuilder
    private var rpgDialogLayer: some View {
        if showGhostResponse, let response = viewModel.ghostResponse {
            // Ghost 反馈语：复用底部对话框，更亮的绿色
            RPGDialogView(
                text: response,
                textColor: Color(red: 0.4, green: 1.0, blue: 0.4)
            )
        } else if viewModel.challengesRemaining > 0 && !viewModel.showReceiptSlip {
            // 校准提示：明确的 "点击此处校准 Ghost"
            RPGDialogView(
                text: L.Incubator.tapToCalibrate,
                isInteractive: true,
                onTap: {
                    Task { await viewModel.startCalibration() }
                },
                isBlinking: isBlinkingIncoming,
                isDisabled: viewModel.isLoadingChallenge || viewModel.showReceiptSlip,
                isLoading: viewModel.isLoadingChallenge
            )
        } else if !viewModel.idleText.isEmpty && !viewModel.showReceiptSlip {
            // 闲置文案：打字机效果
            RPGDialogView(
                text: viewModel.idleText,
                isTyping: viewModel.isTypingIdle
            )
        }
    }
    
    // MARK: - Calibration Prompt View

    // MARK: - 🧪 Debug Test Panel
    @ViewBuilder
    private var debugTestPanel: some View {
        VStack(spacing: 6) {
            Divider()
            Text("🧪 DEBUG")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            HStack(spacing: 6) {
                // XP +500
                Button("XP +500") {
                    viewModel.currentLevelXP = min(viewModel.currentLevelXP + 500, 10000)
                    viewModel.totalXP += 500
                }
                // XP +2000
                Button("XP +2000") {
                    viewModel.currentLevelXP = min(viewModel.currentLevelXP + 2000, 10000)
                    viewModel.totalXP += 2000
                }
                // XP MAX (fill bar)
                Button("XP MAX") {
                    viewModel.currentLevelXP = 9999
                }
                // XP Reset
                Button("XP = 0") {
                    viewModel.currentLevelXP = 0
                }
            }
            .font(.system(size: 10, design: .monospaced))
            
            HStack(spacing: 6) {
                // Level Up
                Button("Level Up") {
                    if viewModel.level < 10 {
                        viewModel.level += 1
                        viewModel.currentLevelXP = 0
                        Task {
                            await viewModel.performLevelUpCeremony()
                        }
                    }
                }
                // Level Down
                Button("Level Down") {
                    if viewModel.level > 1 {
                        viewModel.level -= 1
                        viewModel.currentLevelXP = 0
                    }
                }
                // Set Level 10
                Button("Lv.10") {
                    viewModel.level = 10
                    viewModel.currentLevelXP = 9999
                }
                // Set Level 1
                Button("Lv.1") {
                    viewModel.level = 1
                    viewModel.currentLevelXP = 0
                }
            }
            .font(.system(size: 10, design: .monospaced))
            
            HStack(spacing: 6) {
                // Mock Challenge (show receipt slip)
                Button("Mock Challenge") {
                    viewModel.currentChallenge = LocalCalibrationChallenge(
                        type: .dilemma,
                        scenario: "Your friend posted something with obvious factual errors. What do you do?",
                        options: ["DM them privately", "Comment publicly", "Pretend you didn't see it"],
                        targetField: "spirit"
                    )
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.showReceiptSlip = true
                    }
                }
                // Fetch Real Challenge
                Button("Real Challenge") {
                    Task { await viewModel.startCalibration() }
                }
                // Ghost Response
                Button("Ghost Say") {
                    viewModel.ghostResponse = "Hehe... interesting choice 👻"
                    showGhostResponse = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        showGhostResponse = false
                        viewModel.ghostResponse = nil
                    }
                }
            }
            .font(.system(size: 10, design: .monospaced))
            
            HStack(spacing: 6) {
                // Level-Up Ceremony (without actually changing level)
                Button("Ceremony") {
                    Task { await viewModel.performLevelUpCeremony() }
                }
                // Refresh Local Data
                Button("Refresh Local") {
                    Task { viewModel.loadLocalData() }
                }
                // Shuffle Pixels
                Button("Shuffle Pixels") {
                    viewModel.matrixModel.shuffleActivationOrder(seed: nil)
                }
            }
            .font(.system(size: 10, design: .monospaced))
            
            // Status display
            Text("Lv.\(viewModel.level) | XP: \(viewModel.currentLevelXP)/10000 | Sync: \(viewModel.syncRate)% | Phase: \(viewModel.levelUpPhase) | Challenges: \(viewModel.challengesRemaining)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }
    
    
    /// 校准提示视图
    /// - challengesRemaining > 0: 显示闪烁的 ">> INCOMING..." 可点击提示
    /// - challengesRemaining == 0: 显示 ">> NO MORE SIGNALS TODAY" 不可点击
    // MARK: - Calibration Interaction
    
    /// 处理用户选择校准选项
    /// 提交答案 → 收回纸条 → 显示 ghost_response → 更新 XP
    /// Validates: Requirements 8a.5
    private func handleOptionSelected(selectedOption: Int) {
        Task {
            await viewModel.submitAnswer(selectedOption: selectedOption, customAnswer: nil)
            
            if viewModel.ghostResponse != nil {
                showGhostResponse = true
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                showGhostResponse = false
                viewModel.ghostResponse = nil
            }
        }
    }
    
    /// 处理用户提交自定义答案
    /// Validates: Requirements 13.1, 13.2, 13.5
    private func handleCustomAnswerSubmitted(customAnswer: String) {
        Task {
            await viewModel.submitAnswer(selectedOption: nil, customAnswer: customAnswer)
            
            if viewModel.ghostResponse != nil {
                showGhostResponse = true
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                showGhostResponse = false
                viewModel.ghostResponse = nil
            }
        }
    }
}

// MARK: - ProgressIndicator (macOS 原生小菊花)

private struct ProgressIndicator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.startAnimation(nil)
        return indicator
    }
    
    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}

// MARK: - CRT Frame Image View (SwiftUI Image)

private struct CRTFrameImageView: View {
    var body: some View {
        if let image = loadImage() {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
    
    private func loadImage() -> NSImage? {
        // 从 bundle 加载
        if let url = Bundle.main.url(forResource: "CRTFrame", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        // 开发时从源码目录加载
        let devPath = "/Users/gengdawei/输入法/AIInputMethod/Sources/Resources/CRTFrame.png"
        return NSImage(contentsOfFile: devPath)
    }
}
