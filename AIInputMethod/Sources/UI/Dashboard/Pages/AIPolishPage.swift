//
//  AIPolishPage.swift
//  AIInputMethod
//
//  AI 润色配置页面 - 风格卡片 + 共享应用选择器
//

import SwiftUI
import AppKit

// MARK: - AIPolishPage

struct AIPolishPage: View {
    
    @State private var viewModel = AIPolishViewModel()
    @State private var showingAppPicker = false
    @State private var showingCustomProfileEditor = false
    @State private var editingProfile: CustomProfile? = nil
    @State private var editorName = ""
    @State private var editorPrompt = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text(L.AIPolish.title)
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.bottom, DS.Spacing.sm)
                
                basicSettingsSection
                profileCardsSection
                appProfileSection
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
    
    // MARK: - Basic Settings
    
    private var basicSettingsSection: some View {
        MinimalSettingsSection(title: L.AIPolish.basicSettings, icon: "slider.horizontal.3") {
            MinimalToggleRow(
                title: L.AIPolish.enable,
                subtitle: L.AIPolish.enableDesc,
                icon: "wand.and.stars",
                isOn: Binding(
                    get: { viewModel.enableAIPolish },
                    set: { viewModel.enableAIPolish = $0 }
                )
            )
        }
    }
    
    // MARK: - Profile Cards Section (Task 9.1)
    
    private let cardColumns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 8)]
    
    private var profileCardsSection: some View {
        MinimalSettingsSection(title: L.AIPolish.styleSection, icon: "paintpalette") {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // 预设风格卡片
                LazyVGrid(columns: cardColumns, spacing: 8) {
                    ForEach(PolishProfile.allCases) { profile in
                        presetCard(profile: profile)
                    }
                    
                    // 自定义风格卡片
                    ForEach(viewModel.customProfiles) { custom in
                        customCard(profile: custom)
                    }
                    
                    // "+" 添加卡片
                    addCard
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }
        }
        .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
        .disabled(!viewModel.enableAIPolish)
        .sheet(isPresented: $showingCustomProfileEditor) {
            customProfileEditorSheet
        }
    }
    
    // MARK: - Preset Card
    
    private func presetCard(profile: PolishProfile) -> some View {
        let isSelected = viewModel.selectedProfileId == profile.rawValue
        
        return Button(action: { viewModel.selectProfile(id: profile.rawValue) }) {
            VStack(spacing: 6) {
                Image(systemName: profile.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? DS.Colors.text1 : DS.Colors.text2)
                
                Text(profile.rawValue)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text1)
                    .lineLimit(1)
                
                Text(profile.description)
                    .font(.system(size: 9))
                    .foregroundColor(DS.Colors.text3)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? DS.Colors.highlight : DS.Colors.bg1)
            .cornerRadius(DS.Layout.cornerRadius + 2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius + 2)
                    .stroke(isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: isSelected ? 1.5 : DS.Layout.borderWidth)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Custom Card
    
    private func customCard(profile: CustomProfile) -> some View {
        let isSelected = viewModel.selectedProfileId == profile.id.uuidString
        
        return Button(action: { viewModel.selectProfile(id: profile.id.uuidString) }) {
            VStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? DS.Colors.text1 : DS.Colors.text2)
                
                Text(profile.name)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text1)
                    .lineLimit(1)
                
                // 编辑/删除按钮
                HStack(spacing: 8) {
                    Button(action: { startEditing(profile) }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundColor(DS.Colors.text3)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.deleteCustomProfile(id: profile.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(DS.Colors.text3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? DS.Colors.highlight : DS.Colors.bg1)
            .cornerRadius(DS.Layout.cornerRadius + 2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius + 2)
                    .stroke(isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: isSelected ? 1.5 : DS.Layout.borderWidth)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Add Card
    
    private var addCard: some View {
        Button(action: { startCreating() }) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(DS.Colors.text3)
                
                Text(L.Common.custom)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(DS.Colors.bg1)
            .cornerRadius(DS.Layout.cornerRadius + 2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius + 2)
                    .stroke(DS.Colors.border, style: StrokeStyle(lineWidth: DS.Layout.borderWidth, dash: [4]))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Custom Profile Editor (Task 9.2)
    
    private func startCreating() {
        editingProfile = nil
        editorName = ""
        editorPrompt = ""
        showingCustomProfileEditor = true
    }
    
    private func startEditing(_ profile: CustomProfile) {
        editingProfile = profile
        editorName = profile.name
        editorPrompt = profile.prompt
        showingCustomProfileEditor = true
    }
    
    private var customProfileEditorSheet: some View {
        let isEditing = editingProfile != nil
        let canSave = !editorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !editorPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(isEditing ? L.AIPolish.editCustomStyle : L.AIPolish.createCustomStyle)
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text1)
                Spacer()
                Button(L.Common.cancel) { showingCustomProfileEditor = false }
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text2)
                    .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)
            
            MinimalDivider()
            
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // 名称
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.AIPolish.styleName)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    TextField(L.AIPolish.styleNamePlaceholder, text: $editorName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Prompt
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.AIPolish.promptLabel)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    TextEditor(text: $editorPrompt)
                        .font(DS.Typography.mono(11, weight: .regular))
                        .frame(minHeight: 120, maxHeight: 200)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.bg1)
                        .cornerRadius(DS.Layout.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                        )
                    HStack {
                        Spacer()
                        Text("\(editorPrompt.count) \(L.Common.characters)")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text3)
                    }
                }
                
                // 保存按钮
                HStack {
                    Spacer()
                    Button(action: {
                        let name = editorName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let prompt = editorPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let editing = editingProfile {
                            viewModel.updateCustomProfile(id: editing.id, name: name, prompt: prompt)
                        } else {
                            viewModel.addCustomProfile(name: name, prompt: prompt)
                        }
                        showingCustomProfileEditor = false
                    }) {
                        Text(L.Common.save)
                            .font(DS.Typography.body)
                            .foregroundColor(canSave ? DS.Colors.text1 : DS.Colors.text3)
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(canSave ? DS.Colors.highlight : DS.Colors.bg1)
                            .cornerRadius(DS.Layout.cornerRadius)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
            }
            .padding(DS.Spacing.lg)
            
            Spacer()
        }
        .frame(width: 420, height: 380)
        .background(DS.Colors.bg1)
    }
    
    // MARK: - App Profile Section
    
    private var appProfileSection: some View {
        MinimalSettingsSection(title: L.AIPolish.appProfile, icon: "app.badge") {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.AIPolish.appProfileDesc)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingAppPicker = true }) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text(L.Prefs.addApp)
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
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                
                let configuredApps = viewModel.getConfiguredApps()
                if configuredApps.isEmpty {
                    Text(L.AIPolish.noAppProfile)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.lg)
                } else {
                    ForEach(configuredApps) { appInfo in
                        appProfileRow(appInfo: appInfo)
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                }
                
                Spacer().frame(height: DS.Spacing.sm)
            }
        }
        .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
        .disabled(!viewModel.enableAIPolish)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                onSelect: { bundleId in
                    viewModel.addAppMapping(bundleId: bundleId, profileId: PolishProfile.standard.rawValue)
                },
                isPresented: $showingAppPicker
            )
        }
    }
    
    // MARK: - App Profile Row (Task 9.3)
    
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
                get: { appInfo.profileId },
                set: { newId in
                    viewModel.addAppMapping(bundleId: appInfo.bundleId, profileId: newId)
                }
            )) {
                ForEach(PolishProfile.allCases) { profile in
                    Text(profile.rawValue).tag(profile.rawValue)
                }
                if !viewModel.customProfiles.isEmpty {
                    Divider()
                    ForEach(viewModel.customProfiles) { custom in
                        Text(custom.name).tag(custom.id.uuidString)
                    }
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
    
    private var smartCommandsSection: some View {
        MinimalSettingsSection(title: L.AIPolish.smartCommands, icon: "command") {
            VStack(spacing: 0) {
                inSentencePatternsRow
                
                if viewModel.enableInSentencePatterns {
                    inSentencePatternsExamples
                }
                
                MinimalDivider()
                    .padding(.leading, 44)
                
                triggerCommandsRow
                
                if viewModel.enableTriggerCommands {
                    MinimalDivider()
                        .padding(.leading, 44)
                    triggerWordRow
                    triggerCommandsExamples
                }
            }
        }
        .opacity(viewModel.enableAIPolish ? 1.0 : 0.5)
        .disabled(!viewModel.enableAIPolish)
    }
    
    private var inSentencePatternsRow: some View {
        MinimalToggleRow(
            title: L.AIPolish.inSentence,
            subtitle: L.AIPolish.inSentenceDesc,
            icon: "text.magnifyingglass",
            isOn: Binding(
                get: { viewModel.enableInSentencePatterns },
                set: { viewModel.enableInSentencePatterns = $0 }
            )
        )
    }
    
    private var inSentencePatternsExamples: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.text3)
                Text(L.AIPolish.examples)
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
    
    private var triggerCommandsRow: some View {
        MinimalToggleRow(
            title: L.AIPolish.trigger,
            subtitle: L.AIPolish.triggerDesc,
            icon: "mic.badge.plus",
            isOn: Binding(
                get: { viewModel.enableTriggerCommands },
                set: { viewModel.enableTriggerCommands = $0 }
            )
        )
    }
    
    private var triggerWordRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "text.bubble")
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.icon)
                .frame(width: 28, height: 28)
                .background(DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.AIPolish.triggerWord)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                Text(L.AIPolish.triggerWordDesc)
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
}

#if DEBUG
struct AIPolishPage_Previews: PreviewProvider {
    static var previews: some View {
        AIPolishPage()
            .frame(width: 600, height: 700)
    }
}
#endif
