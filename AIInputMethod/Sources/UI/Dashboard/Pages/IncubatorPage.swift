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
    
    /// 是否正在显示 ghost_response 反馈语
    @State private var showGhostResponse: Bool = false
    
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
        VStack(spacing: DS.Spacing.md) {
            
            Spacer()
            
            // 等级信息栏 - CRT 上方
            // Validates: Requirements 2.5
            LevelInfoBar(
                level: viewModel.level,
                progressFraction: viewModel.progressFraction,
                syncRate: viewModel.syncRate
            )
            
            // 校准提示 - CRT 上方
            // Validates: Requirements 8a.1, 8a.6
            calibrationPromptView
            
            // CRT 容器 - 中央点阵屏（含 ReceiptSlip 覆盖层）
            // Validates: Requirements 2.2, 2.3, 2.4, 8a.2
            ZStack {
                // 纯黑背景
                Color.black
                
                // 点阵屏渲染层
                DotMatrixView(
                    activePixels: effectiveActivePixels,
                    ghostMask: viewModel.matrixModel.ghostMask,
                    ghostOpacity: effectiveGhostOpacity,
                    level: viewModel.level
                )
                
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
                
                // 热敏纸条覆盖层 - 从顶部滑入
                // Validates: Requirements 8a.2, 8a.3, 8a.4, 8a.5
                if viewModel.showReceiptSlip, let challenge = viewModel.currentChallenge {
                    VStack {
                        ReceiptSlipView(
                            challenge: challenge,
                            onSelectOption: { selectedIndex in
                                handleOptionSelected(
                                    challengeId: challenge.id,
                                    selectedOption: selectedIndex
                                )
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.showReceiptSlip = false
                                    viewModel.currentChallenge = nil
                                }
                            }
                        )
                        .padding(DS.Spacing.lg)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Ghost 反馈语覆盖层
                // Validates: Requirements 8a.5
                if showGhostResponse, let response = viewModel.ghostResponse {
                    VStack {
                        Spacer()
                        
                        Text(response)
                            .font(DS.Typography.mono(14, weight: .medium))
                            .foregroundColor(.green)
                            .padding(DS.Spacing.md)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(DS.Layout.cornerRadius)
                            .shadow(color: .green.opacity(0.3), radius: 8)
                        
                        Spacer()
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: 640, height: 480)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
            .animation(.easeInOut(duration: 0.3), value: viewModel.levelUpPhase)
            .animation(.easeInOut(duration: 0.3), value: viewModel.showReceiptSlip)
            .animation(.easeInOut(duration: 0.3), value: showGhostResponse)
            
            // Ghost 闲置文案 - CRT 下方
            // Validates: Requirements 2.6
            GhostStatusText(
                text: viewModel.idleText,
                isTyping: viewModel.isTypingIdle
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
        .onAppear {
            Task {
                await viewModel.fetchStatus()
            }
            viewModel.startIdleTextCycle()
            // 🔥 监听 LLM 调用成功通知，自动刷新 Ghost Twin status
            // Validates: Requirements 7.6
            viewModel.startObservingLLMNotifications()
            // 启动闪烁动画
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isBlinkingIncoming = true
            }
        }
        .onDisappear {
            viewModel.stopIdleTextCycle()
            viewModel.stopObservingLLMNotifications()
        }
    }
    
    // MARK: - Calibration Prompt View
    
    /// 校准提示视图
    /// - challengesRemaining > 0: 显示闪烁的 ">> INCOMING..." 可点击提示
    /// - challengesRemaining == 0: 显示 ">> NO MORE SIGNALS TODAY" 不可点击
    /// Validates: Requirements 8a.1, 8a.6
    @ViewBuilder
    private var calibrationPromptView: some View {
        if viewModel.challengesRemaining > 0 {
            Button(action: {
                Task {
                    await viewModel.fetchChallenge()
                }
            }) {
                HStack(spacing: DS.Spacing.xs) {
                    if viewModel.isLoadingChallenge {
                        ProgressIndicator()
                            .frame(width: 12, height: 12)
                    }
                    
                    Text(L.Incubator.incoming)
                        .font(DS.Typography.mono(13, weight: .medium))
                        .foregroundColor(.green)
                        .opacity(isBlinkingIncoming ? 1.0 : 0.3)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoadingChallenge || viewModel.showReceiptSlip)
        } else {
            Text(L.Incubator.noMoreSignals)
                .font(DS.Typography.mono(13, weight: .medium))
                .foregroundColor(DS.Colors.text3)
        }
    }
    
    // MARK: - Calibration Interaction
    
    /// 处理用户选择校准选项
    /// 提交答案 → 收回纸条 → 显示 ghost_response → 更新 XP
    /// Validates: Requirements 8a.5
    private func handleOptionSelected(challengeId: String, selectedOption: Int) {
        Task {
            await viewModel.submitAnswer(challengeId: challengeId, selectedOption: selectedOption)
            
            if viewModel.ghostResponse != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showGhostResponse = true
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    showGhostResponse = false
                }
                
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
