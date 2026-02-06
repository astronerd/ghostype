import SwiftUI
import AppKit

// MARK: - PreferencesPage

/// 偏好设置页面
/// 实现分组设置界面 (通用、快捷键、AI 引擎)
/// 复用现有 HotkeyRecorderView 组件
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.6
struct PreferencesPage: View {
    
    // MARK: - Properties
    
    @State private var viewModel = PreferencesViewModel()
    @State private var isRecordingHotkey = false
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                Text("偏好设置")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 8)
                
                // 通用设置组
                generalSettingsSection
                
                // 快捷键设置组
                hotkeySettingsSection
                
                // AI 引擎状态组
                aiEngineSection
                
                // 重置按钮
                resetSection
                
                Spacer(minLength: 20)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - General Settings Section
    
    /// 通用设置组
    /// Requirement 7.1: Launch at Login toggle
    /// Requirement 7.2: Sound Feedback toggle
    private var generalSettingsSection: some View {
        SettingsSection(title: "通用", icon: "gearshape") {
            VStack(spacing: 0) {
                // 开机自启动
                SettingsToggleRow(
                    title: "开机自启动",
                    subtitle: "登录时自动启动 GhosTYPE",
                    icon: "power",
                    isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.launchAtLogin = $0 }
                    )
                )
                
                Divider()
                    .padding(.leading, 52)
                
                // 声音反馈
                SettingsToggleRow(
                    title: "声音反馈",
                    subtitle: "录音开始和结束时播放提示音",
                    icon: "speaker.wave.2",
                    isOn: Binding(
                        get: { viewModel.soundFeedback },
                        set: { viewModel.soundFeedback = $0 }
                    )
                )
                
                Divider()
                    .padding(.leading, 52)
                
                // 输入模式
                SettingsNavigationRow(
                    title: "输入模式",
                    subtitle: viewModel.autoStartOnFocus ? "自动模式" : "手动模式",
                    icon: viewModel.autoStartOnFocus ? "text.cursor" : "hand.tap"
                ) {
                    // 切换输入模式
                    viewModel.autoStartOnFocus.toggle()
                }
            }
        }
    }
    
    // MARK: - Hotkey Settings Section
    
    /// 快捷键设置组
    /// Requirement 7.3: Display current hotkey configuration
    /// Requirement 7.6: Allow hotkey modification using HotkeyRecorderView
    private var hotkeySettingsSection: some View {
        SettingsSection(title: "快捷键", icon: "keyboard") {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("触发快捷键")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("按住快捷键说话，松开完成输入")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 快捷键录入器
                    HotkeyRecorderView(
                        isRecording: $isRecordingHotkey,
                        hotkeyDisplay: Binding(
                            get: { viewModel.hotkeyDisplay },
                            set: { viewModel.hotkeyDisplay = $0 }
                        ),
                        onRecorded: { modifiers, keyCode, display in
                            viewModel.updateHotkey(modifiers: modifiers, keyCode: keyCode, display: display)
                        }
                    )
                    .frame(width: 140, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // 提示文字
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(isRecordingHotkey ? "按下新的快捷键组合..." : "点击上方按钮修改快捷键")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - AI Engine Section
    
    /// AI 引擎状态组
    /// Requirement 7.4: Display AI engine connection status
    private var aiEngineSection: some View {
        SettingsSection(title: "AI 引擎", icon: "cpu") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("豆包语音识别")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Doubao Speech-to-Text API")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 状态指示器
                HStack(spacing: 6) {
                    if viewModel.aiEngineStatus == .checking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: viewModel.aiEngineStatus.icon)
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.aiEngineStatus.color)
                    }
                    
                    Text(viewModel.aiEngineStatus.displayText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(viewModel.aiEngineStatus.color)
                }
                
                // 刷新按钮
                Button(action: {
                    viewModel.checkAIEngineStatus()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(16)
        }
    }
    
    // MARK: - Reset Section
    
    /// 重置设置区域
    private var resetSection: some View {
        HStack {
            Spacer()
            
            Button(action: {
                viewModel.resetToDefaults()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                    
                    Text("恢复默认设置")
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Settings Section

/// 设置分组容器
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分组标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            // 内容卡片
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Toggle Row

/// 设置开关行
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 开关
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Navigation Row

/// 设置导航行（可点击）
struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
                }
                
                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct PreferencesPage_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesPage()
            .frame(width: 600, height: 700)
    }
}
#endif
