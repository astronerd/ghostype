//
//  SkillPage.swift
//  AIInputMethod
//
//  Skill management page
//

import SwiftUI
import AppKit

// MARK: - KeyCode Display Name Helper

private func displayNameForKeyCode(_ keyCode: UInt16) -> String {
    let mapping: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
        37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        25: "9", 26: "7", 28: "8", 29: "0",
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";",
        42: "\\", 43: ",", 44: "/", 47: ".", 50: "`",
        36: "\u{21A9}", 48: "\u{21E5}", 49: "Space", 51: "\u{232B}", 53: "\u{238B}",
        71: "Clear", 76: "\u{2305}",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 118: "F4",
        120: "F2", 122: "F1",
        123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
        54: "\u{2318}R", 55: "\u{2318}", 56: "\u{21E7}", 57: "\u{21EA}",
        58: "\u{2325}", 59: "\u{2303}", 60: "\u{21E7}R", 61: "\u{2325}R",
        62: "\u{2303}R", 63: "Fn",
        65: "KP.", 67: "KP*", 69: "KP+", 75: "KP/",
        78: "KP-", 81: "KP=",
        82: "KP0", 83: "KP1", 84: "KP2", 85: "KP3",
        86: "KP4", 87: "KP5", 88: "KP6", 89: "KP7",
        91: "KP8", 92: "KP9",
    ]
    return mapping[keyCode] ?? "Key\(keyCode)"
}

private let systemModifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

// MARK: - SkillPage

struct SkillPage: View {

    @State private var viewModel = SkillViewModel()

    private let cardColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: DS.Spacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.Skill.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text1)
                    Text(L.Skill.subtitle)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text2)
                }
                .padding(.bottom, DS.Spacing.sm)

                if !viewModel.builtinSkills.isEmpty {
                    skillSection(title: L.Skill.builtin, skills: viewModel.builtinSkills)
                }

                skillSection(title: L.Skill.custom, skills: viewModel.customSkills, showAdd: true)

                // macOS 系统快捷键冲突提示
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Colors.text3)
                        .padding(.top, 1)
                    Text(L.Skill.hotkeyConflictNote)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.bg2.opacity(0.5))
                .cornerRadius(DS.Layout.cornerRadius)

                if let error = viewModel.errorMessage {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(DS.Colors.statusWarning)
                        Text(error)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.statusWarning)
                        Spacer()
                        Button(action: { viewModel.errorMessage = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(DS.Colors.text2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.bg2)
                    .cornerRadius(DS.Layout.cornerRadius)
                }

                Spacer(minLength: DS.Spacing.xl)
            }
            .padding(.top, 21)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
        .sheet(isPresented: Binding(
            get: { viewModel.isCreating },
            set: { if !$0 { viewModel.cancelCreate() } }
        )) {
            SkillCreateSheet(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isEditing },
            set: { if !$0 { viewModel.cancelEdit() } }
        )) {
            if viewModel.editingSkill != nil {
                SkillEditSheet(viewModel: viewModel)
            }
        }
        .alert(L.Skill.confirmDelete, isPresented: Binding(
            get: { viewModel.showDeleteConfirm },
            set: { if !$0 { viewModel.cancelDelete() } }
        )) {
            Button(L.Common.cancel, role: .cancel) { viewModel.cancelDelete() }
            Button(L.Common.delete, role: .destructive) { viewModel.executeDelete() }
        } message: {
            Text(L.Skill.confirmDeleteMsg)
        }
    }

    @ViewBuilder
    private func skillSection(title: String, skills: [SkillModel], showAdd: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: title)

            LazyVGrid(columns: cardColumns, spacing: DS.Spacing.md) {
                ForEach(skills) { skill in
                    SkillCardView(skill: skill, viewModel: viewModel)
                }

                if showAdd {
                    AddSkillCard { viewModel.startCreate() }
                }
            }
        }
    }
}

// MARK: - Skill Card

struct SkillCardView: View {
    let skill: SkillModel
    @Bindable var viewModel: SkillViewModel
    @State private var isHovered = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Text(skill.icon)
                    .font(.system(size: 20))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.name)
                        .font(DS.Typography.title)
                        .foregroundColor(DS.Colors.text1)
                        .lineLimit(1)
                }

                Spacer()

                if skill.isBuiltin {
                    Text(L.Skill.builtin)
                        .font(DS.Typography.mono(8, weight: .medium))
                        .foregroundColor(DS.Colors.text2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DS.Colors.highlight)
                        .cornerRadius(2)
                }
            }

            Text(skill.description)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
                .lineLimit(2)

            HStack(spacing: DS.Spacing.sm) {
                keyBindingButton

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Button(action: { viewModel.startEdit(skill) }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colors.text2)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                            )
                    }
                    .buttonStyle(.plain)

                    if !skill.isBuiltin {
                        Button(action: { viewModel.confirmDelete(id: skill.id) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Colors.text2)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                        .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .opacity(isHovered ? 1 : 0.5)
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                .stroke(skill.swiftUIColor.opacity(isHovered ? 0.8 : 0.4), lineWidth: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onChange(of: viewModel.isBindingKey) { _, newValue in
            if newValue && viewModel.bindingSkillId == skill.id {
                startKeyMonitor()
            } else if !newValue || viewModel.bindingSkillId != skill.id {
                stopKeyMonitor()
            }
        }
        .onDisappear {
            stopKeyMonitor()
        }
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let kc = event.keyCode
            if event.type == .flagsChanged {
                guard systemModifierKeyCodes.contains(kc) else { return event }
                let display = displayNameForKeyCode(kc)
                viewModel.completeKeyBinding(keyCode: kc, displayName: display, isSystemModifier: true)
                return nil
            }
            let display = displayNameForKeyCode(kc)
            let isSysMod = systemModifierKeyCodes.contains(kc)
            viewModel.completeKeyBinding(keyCode: kc, displayName: display, isSystemModifier: isSysMod)
            return nil
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    @ViewBuilder
    private var keyBindingButton: some View {
        let isBinding = viewModel.isBindingKey && viewModel.bindingSkillId == skill.id

        Button(action: {
            if isBinding {
                viewModel.cancelKeyBinding()
            } else {
                viewModel.startKeyBinding(skillId: skill.id)
            }
        }) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "keyboard")
                    .font(.system(size: 10))

                if isBinding {
                    Text(L.Skill.pressKey)
                        .font(DS.Typography.caption)
                } else if let binding = skill.modifierKey {
                    Text(binding.displayName)
                        .font(DS.Typography.mono(11, weight: .medium))
                } else {
                    Text(L.Skill.unboundKey)
                        .font(DS.Typography.caption)
                }
            }
            .foregroundColor(isBinding ? DS.Colors.statusWarning : DS.Colors.text2)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(isBinding ? DS.Colors.statusWarning.opacity(0.1) : DS.Colors.highlight)
            .cornerRadius(DS.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if skill.modifierKey != nil {
                Button(action: { viewModel.unbindKey(skillId: skill.id) }) {
                    Label(L.Skill.unboundKey, systemImage: "xmark.circle")
                }
            }
        }
    }
}

// MARK: - Add Skill Card

struct AddSkillCard: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundColor(DS.Colors.text2)

                Text(L.Skill.addSkill)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 120)
            .background(DS.Colors.bg2.opacity(isHovered ? 1 : 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(DS.Colors.border)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Color Picker Row (shared between Create & Edit)

private struct ColorPickerRow: View {
    @Binding var colorHex: String
    @State private var hexInput: String = ""
    @State private var pickerColor: Color = .blue

    private let presetColors: [(name: String, hex: String)] = [
        ("蓝", "#007AFF"), ("绿", "#34C759"), ("橙", "#FF9500"),
        ("紫", "#AF52DE"), ("粉", "#FF2D55"), ("青", "#5AC8FA"),
        ("红", "#FF3B30"), ("黄", "#FFCC00"), ("靛", "#5856D6"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Preset circles
            HStack(spacing: DS.Spacing.sm) {
                ForEach(presetColors, id: \.hex) { preset in
                    let isSelected = colorHex.uppercased() == preset.hex.uppercased()
                    Circle()
                        .fill(Color(hex: preset.hex))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 0))
                        .overlay(Circle().stroke(DS.Colors.border, lineWidth: 1))
                        .onTapGesture {
                            colorHex = preset.hex
                            hexInput = preset.hex
                            pickerColor = Color(hex: preset.hex)
                        }
                }
            }

            // Hex input + native color picker
            HStack(spacing: DS.Spacing.sm) {
                TextField(L.Skill.hexPlaceholder, text: $hexInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit { applyHexInput() }
                    .onChange(of: hexInput) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        if trimmed.count == 7 && trimmed.hasPrefix("#") {
                            let hexChars = trimmed.dropFirst()
                            if hexChars.allSatisfy({ $0.isHexDigit }) {
                                colorHex = trimmed.uppercased()
                                pickerColor = Color(hex: trimmed)
                            }
                        }
                    }

                ColorPicker("", selection: $pickerColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                    .onChange(of: pickerColor) { _, newColor in
                        if let hex = newColor.toHex() {
                            colorHex = hex
                            hexInput = hex
                        }
                    }

                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(DS.Colors.border, lineWidth: 1))
            }
        }
        .onAppear {
            hexInput = colorHex
            pickerColor = Color(hex: colorHex)
        }
    }

    private func applyHexInput() {
        var trimmed = hexInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.hasPrefix("#") { trimmed = "#" + trimmed }
        trimmed = trimmed.uppercased()
        if trimmed.count == 7 {
            let hexChars = trimmed.dropFirst()
            if hexChars.allSatisfy({ $0.isHexDigit }) {
                colorHex = trimmed
                pickerColor = Color(hex: trimmed)
            }
        }
    }
}

// MARK: - Color → Hex helper

private extension Color {
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(components.redComponent * 255))
        let g = Int(round(components.greenComponent * 255))
        let b = Int(round(components.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Create Sheet

struct SkillCreateSheet: View {
    @Bindable var viewModel: SkillViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.md) {
                EmojiPickerButton(selectedEmoji: $viewModel.newIcon, size: 44)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.Skill.createSkill)
                        .font(DS.Typography.title)
                        .foregroundColor(DS.Colors.text1)
                    Text(L.Skill.descPlaceholder)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                Spacer()
            }
            .padding(DS.Spacing.xl)

            MinimalDivider()
                .padding(.horizontal, DS.Spacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    sheetField(label: L.Skill.skillName) {
                        TextField(L.Skill.namePlaceholder, text: $viewModel.newName)
                            .textFieldStyle(.roundedBorder)
                    }

                    sheetField(label: L.Skill.skillDescription) {
                        TextField(L.Skill.descPlaceholder, text: $viewModel.newDescription)
                            .textFieldStyle(.roundedBorder)
                    }

                    sheetField(label: L.Skill.skillColor) {
                        ColorPickerRow(colorHex: $viewModel.newColorHex)
                    }

                    sheetField(label: L.Skill.skillInstruction) {
                        TextEditor(text: $viewModel.newPrompt)
                            .font(DS.Typography.body)
                            .frame(minHeight: 100)
                            .padding(4)
                            .background(DS.Colors.bg2)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                    .stroke(DS.Colors.border, lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if viewModel.newPrompt.isEmpty {
                                    Text(L.Skill.instructionPlaceholder)
                                        .font(DS.Typography.body)
                                        .foregroundColor(DS.Colors.text2.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
                .padding(DS.Spacing.xl)
            }

            MinimalDivider()
                .padding(.horizontal, DS.Spacing.xl)

            HStack {
                Spacer()
                Button(L.Common.cancel) { viewModel.cancelCreate() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isGenerating)
                Button(L.Common.save) { viewModel.confirmCreate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.newName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGenerating)
            }
            .padding(DS.Spacing.xl)
        }
        .frame(width: 460, height: 520)
        .background(DS.Colors.bg1)
        .overlay {
            if viewModel.isGenerating {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: DS.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L.Skill.generatingPrompt)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                    }
                    .padding(DS.Spacing.xl)
                    .background(.ultraThinMaterial)
                    .cornerRadius(DS.Layout.cornerRadius)
                }
            }
        }
    }

    @ViewBuilder
    private func sheetField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
            content()
        }
    }
}

// MARK: - Edit Sheet

struct SkillEditSheet: View {
    @Bindable var viewModel: SkillViewModel

    private let languageOptions = [
        L.Skill.autoDetect, "中文", "英文", "日文", "韩文", "法文", "德文", "西班牙文", "俄文"
    ]

    private var isTranslateSkill: Bool {
        viewModel.editingSkill?.id == SkillModel.builtinTranslateId ||
        viewModel.editingSkill?.config["source_language"] != nil
    }

    private var isBuiltin: Bool {
        viewModel.editingSkill?.isBuiltin == true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.md) {
                EmojiPickerButton(
                    selectedEmoji: Binding(
                        get: { viewModel.editingSkill?.icon ?? "✨" },
                        set: { viewModel.editingSkill?.icon = $0 }
                    ),
                    size: 44
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Skill.editSkill)
                        .font(DS.Typography.title)
                        .foregroundColor(DS.Colors.text1)
                    if let skill = viewModel.editingSkill {
                        Text(skill.isBuiltin ? L.Skill.builtin : L.Skill.custom)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                    }
                }
                Spacer()

                if let hex = viewModel.editingSkill?.colorHex {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(DS.Spacing.xl)

            MinimalDivider()
                .padding(.horizontal, DS.Spacing.xl)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Name (disabled for builtin)
                    sheetField(label: L.Skill.skillName) {
                        TextField(L.Skill.namePlaceholder, text: Binding(
                            get: { viewModel.editingSkill?.name ?? "" },
                            set: { viewModel.editingSkill?.name = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .disabled(isBuiltin)
                        .opacity(isBuiltin ? 0.6 : 1)
                    }

                    // Description (disabled for builtin)
                    sheetField(label: L.Skill.skillDescription) {
                        TextField(L.Skill.descPlaceholder, text: Binding(
                            get: { viewModel.editingSkill?.description ?? "" },
                            set: { viewModel.editingSkill?.description = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .disabled(isBuiltin)
                        .opacity(isBuiltin ? 0.6 : 1)
                    }

                    // Color (always editable)
                    sheetField(label: L.Skill.skillColor) {
                        ColorPickerRow(colorHex: Binding(
                            get: { viewModel.editingSkill?.colorHex ?? "#5AC8FA" },
                            set: { viewModel.editingSkill?.colorHex = $0 }
                        ))
                    }

                    // Translate language picker
                    if isTranslateSkill {
                        sheetField(label: L.Skill.translateLanguage) {
                            HStack(spacing: DS.Spacing.md) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L.Skill.sourceLang)
                                        .font(DS.Typography.caption)
                                        .foregroundColor(DS.Colors.text2)
                                    Picker("", selection: Binding(
                                        get: { viewModel.editingSkill?.config["source_language"] ?? L.Skill.autoDetect },
                                        set: { viewModel.editingSkill?.config["source_language"] = $0 }
                                    )) {
                                        ForEach(languageOptions, id: \.self) { lang in
                                            Text(lang).tag(lang)
                                        }
                                    }
                                    .frame(width: 130)
                                }

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(DS.Colors.text2)
                                    .padding(.top, DS.Spacing.lg)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L.Skill.targetLang)
                                        .font(DS.Typography.caption)
                                        .foregroundColor(DS.Colors.text2)
                                    Picker("", selection: Binding(
                                        get: { viewModel.editingSkill?.config["target_language"] ?? "英文" },
                                        set: { viewModel.editingSkill?.config["target_language"] = $0 }
                                    )) {
                                        ForEach(languageOptions, id: \.self) { lang in
                                            Text(lang).tag(lang)
                                        }
                                    }
                                    .frame(width: 130)
                                }
                            }
                        }
                    }

                    // Prompt (custom skills only)
                    if !isBuiltin {
                        sheetField(label: L.Skill.skillInstruction) {
                            TextEditor(text: Binding(
                                get: { viewModel.editingSkill?.userPrompt ?? "" },
                                set: { viewModel.editingSkill?.userPrompt = $0 }
                            ))
                            .font(DS.Typography.body)
                            .frame(minHeight: 100)
                            .padding(4)
                            .background(DS.Colors.bg2)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                    .stroke(DS.Colors.border, lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if (viewModel.editingSkill?.userPrompt ?? "").isEmpty {
                                    Text(L.Skill.instructionPlaceholder)
                                        .font(DS.Typography.body)
                                        .foregroundColor(DS.Colors.text2.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
                .padding(DS.Spacing.xl)
            }

            MinimalDivider()
                .padding(.horizontal, DS.Spacing.xl)

            HStack {
                Spacer()
                Button(L.Common.cancel) { viewModel.cancelEdit() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isGenerating)
                Button(L.Common.save) { viewModel.saveEdit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isGenerating)
            }
            .padding(DS.Spacing.xl)
        }
        .frame(width: 460, height: 520)
        .background(DS.Colors.bg1)
        .overlay {
            if viewModel.isGenerating {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: DS.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L.Skill.generatingPrompt)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                    }
                    .padding(DS.Spacing.xl)
                    .background(.ultraThinMaterial)
                    .cornerRadius(DS.Layout.cornerRadius)
                }
            }
        }
    }

    @ViewBuilder
    private func sheetField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
            content()
        }
    }
}
