//
//  AIPolishPage.swift
//  AIInputMethod
//
//  AI 润色配置页面 - Radical Minimalist 极简风格
//  Requirements: 2.1, 2.2, 3.2, 3.3, 4.1, 4.2, 9.1, 9.2, 9.3, 9.4
//

import SwiftUI
import AppKit

// MARK: - AIPolishPage

struct AIPolishPage: View {
    
    @State private var viewModel = AIPolishViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // 页面标题
                Text("AI 润色")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.bottom, DS.Spacing.sm)
                
                // 基础设置区块
                basicSettingsSection
                
                // 润色配置区块 (Task 7.2)
                profileSettingsSection
                
                // 智能指令区块 (Task 7.3)
                smartCommandsSection
                
                Spacer(minLength: DS.Spacing.xl)
            }
            .padding(.top, 21)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
    }
    
    // MARK: - Basic Settings Section
    // Requirements: 2.1, 2.2, 9.1, 9.2, 9.3, 9.4
    
    private var basicSettingsSection: some View {
        MinimalSettingsSection(title: "基础设置", icon: "slider.horizontal.3") {
            VStack(spacing: 0) {
                // 启用 AI 润色开关 (Requirement 2.1)
                MinimalToggleRow(
                    title: "启用 AI 润色",
                    subtitle: "关闭后直接输出原始转录文本",
                    icon: "wand.and.stars",
                    isOn: Binding(
                        get: { viewModel.enableAIPolish },
                        set: { viewModel.enableAIPolish = $0 }
                    )
                )
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                // 自动润色阈值滑块 (Requirement 2.2)
                thresholdRow
            }
        }
    }
    
    // MARK: - Threshold Row
    
    private var thresholdRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "textformat.size")
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.icon)
                .frame(width: 28, height: 28)
                .background(DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("自动润色阈值")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                Text("低于此字数的文本不进行 AI 润色")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            HStack(spacing: DS.Spacing.md) {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.polishThreshold) },
                        set: { viewModel.polishThreshold = Int($0) }
                    ),
                    in: 0...200,
                    step: 1
                )
                .frame(width: 100)
                
                Text("\(viewModel.polishThreshold) 字")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
                    .monospacedDigit()
                    .frame(width: 45, alignment: .trailing)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
        .disabled(!viewModel.enableAIPolish)
    }
    
    // MARK: - Profile Settings Section
    // Requirements: 3.2, 3.3, 4.1, 4.2
    
    private var profileSettingsSection: some View {
        MinimalSettingsSection(title: "润色配置", icon: "doc.text") {
            VStack(spacing: 0) {
                // 默认配置下拉选择器 (Requirement 3.2)
                defaultProfileRow
                
                // 自定义 Prompt 编辑区域 (Requirement 3.3)
                if viewModel.defaultProfile == .custom {
                    MinimalDivider()
                        .padding(.leading, 44)
                    
                    customPromptEditor
                }
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                // 应用专属配置列表 (Requirement 4.1)
                appProfileListSection
            }
        }
        .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
        .disabled(!viewModel.enableAIPolish)
    }
    
    // MARK: - Default Profile Row
    
    private var defaultProfileRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "slider.horizontal.below.rectangle")
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.icon)
                .frame(width: 28, height: 28)
                .background(DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("默认配置")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                Text(viewModel.defaultProfile.description)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            Picker("", selection: Binding(
                get: { viewModel.defaultProfile },
                set: { viewModel.defaultProfile = $0 }
            )) {
                ForEach(PolishProfile.allCases) { profile in
                    Text(profile.rawValue).tag(profile)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - Custom Prompt Editor
    
    private var customPromptEditor: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "text.quote")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("自定义 Prompt")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    Text("输入您的自定义润色指令")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
            }
            
            TextEditor(text: Binding(
                get: { viewModel.customProfilePrompt },
                set: { viewModel.customProfilePrompt = $0 }
            ))
            .font(DS.Typography.mono(11, weight: .regular))
            .frame(minHeight: 100, maxHeight: 150)
            .padding(DS.Spacing.sm)
            .background(DS.Colors.bg1)
            .cornerRadius(DS.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
            )
            
            HStack {
                Spacer()
                Text("\(viewModel.customProfilePrompt.count) 字符")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - App Profile List Section
    
    private var appProfileListSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: "app.badge")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("应用专属配置")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    Text("为不同应用设置不同的润色风格")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                // 添加应用按钮 (Requirement 4.2)
                Button(action: { showAppPicker() }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("添加应用")
                            .font(DS.Typography.caption)
                    }
                    .foregroundColor(DS.Colors.text1)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            
            // 应用专属配置列表 (Requirement 4.1)
            let configuredApps = viewModel.getConfiguredApps()
            if configuredApps.isEmpty {
                Text("暂无应用专属配置，点击上方按钮添加")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
            } else {
                ForEach(configuredApps) { appInfo in
                    appProfileRow(appInfo: appInfo)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - App Profile Row
    
    private func appProfileRow(appInfo: AppProfileInfo) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            if let icon = appInfo.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 14))
                    .frame(width: 24, height: 24)
            }
            
            Text(appInfo.name)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
            
            Spacer()
            
            Picker("", selection: Binding(
                get: { appInfo.profile },
                set: { newProfile in
                    viewModel.addAppMapping(bundleId: appInfo.bundleId, profile: newProfile)
                }
            )) {
                ForEach(PolishProfile.allCases) { profile in
                    Text(profile.rawValue).tag(profile)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            Button(action: { viewModel.removeAppMapping(bundleId: appInfo.bundleId) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.text3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
    
    // MARK: - Smart Commands Section
    // Requirements: 5.1, 6.1, 6.2, 9.5
    
    private var smartCommandsSection: some View {
        MinimalSettingsSection(title: "智能指令", icon: "command") {
            VStack(spacing: 0) {
                // 句内模式识别开关 (Requirement 5.1)
                inSentencePatternsRow
                
                // 句内模式示例说明 (Requirement 9.5)
                if viewModel.enableInSentencePatterns {
                    inSentencePatternsExamples
                }
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                // 句尾唤醒指令开关 (Requirement 6.1)
                triggerCommandsRow
                
                // 唤醒词输入框 (Requirement 6.2)
                if viewModel.enableTriggerCommands {
                    MinimalDivider()
                        .padding(.leading, 44)
                    
                    triggerWordRow
                    
                    // 句尾唤醒指令示例说明 (Requirement 9.5)
                    triggerCommandsExamples
                }
            }
        }
        .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
        .disabled(!viewModel.enableAIPolish)
    }
    
    // MARK: - In-Sentence Patterns Row
    
    private var inSentencePatternsRow: some View {
        MinimalToggleRow(
            title: "句内模式识别",
            subtitle: "自动处理拆字、换行、Emoji 等模式",
            icon: "text.magnifyingglass",
            isOn: Binding(
                get: { viewModel.enableInSentencePatterns },
                set: { viewModel.enableInSentencePatterns = $0 }
            )
        )
    }
    
    // MARK: - In-Sentence Patterns Examples
    
    private var inSentencePatternsExamples: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.text3)
                
                Text("示例")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                exampleRow(input: "耿直的耿", output: "耿")
                exampleRow(input: "找一个恶魔的emoji", output: "😈")
                exampleRow(input: "换行", output: "换行符")
                exampleRow(input: "版权符号", output: "©")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .padding(.leading, 44)
        .background(DS.Colors.highlight.opacity(0.5))
    }
    
    // MARK: - Trigger Commands Row
    
    private var triggerCommandsRow: some View {
        MinimalToggleRow(
            title: "句尾唤醒指令",
            subtitle: "通过唤醒词触发翻译、格式转换等操作",
            icon: "mic.badge.plus",
            isOn: Binding(
                get: { viewModel.enableTriggerCommands },
                set: { viewModel.enableTriggerCommands = $0 }
            )
        )
    }
    
    // MARK: - Trigger Word Row
    
    private var triggerWordRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "text.bubble")
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.icon)
                .frame(width: 28, height: 28)
                .background(DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("唤醒词")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                Text("在句尾说出唤醒词后跟指令")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            TextField("Ghost", text: Binding(
                get: { viewModel.triggerWord },
                set: { viewModel.triggerWord = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - Trigger Commands Examples
    
    private var triggerCommandsExamples: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.text3)
                
                Text("示例（使用唤醒词「\(viewModel.triggerWord)」）")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                exampleRow(
                    input: "今天天气真好 \(viewModel.triggerWord) 翻译成英文",
                    output: "The weather is really nice today"
                )
                exampleRow(
                    input: "这是一段文字 \(viewModel.triggerWord) 改成正式语气",
                    output: "此为一段文字"
                )
                exampleRow(
                    input: "会议在下周一 \(viewModel.triggerWord) 加上提醒",
                    output: "会议在下周一 ⏰"
                )
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .padding(.leading, 44)
        .background(DS.Colors.highlight.opacity(0.5))
    }
    
    // MARK: - Example Row Helper
    
    private func exampleRow(input: String, output: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("「\(input)」")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(DS.Colors.text3)
            
            Text(output)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text1)
        }
    }
    
    // MARK: - App Picker
    
    private func showAppPicker() {
        let panel = NSOpenPanel()
        panel.title = "选择应用"
        panel.message = "选择要添加专属配置的应用程序"
        panel.prompt = "选择"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        if panel.runModal() == .OK, let url = panel.url {
            // 获取应用的 Bundle ID
            if let bundle = Bundle(url: url),
               let bundleId = bundle.bundleIdentifier {
                // 添加应用映射，默认使用「默认」配置
                viewModel.addAppMapping(bundleId: bundleId, profile: .standard)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AIPolishPage_Previews: PreviewProvider {
    static var previews: some View {
        AIPolishPage()
            .frame(width: 600, height: 500)
    }
}
#endif
