//
//  SkillPage.swift
//  AIInputMethod
//
//  Skill 管理页面 - 展示内置和自定义技能卡片
//

import SwiftUI
import AppKit

// MARK: - SkillPage

struct SkillPage: View {

    @State private var viewModel = SkillViewModel()

    private let cardColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: DS.Spacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Title
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.Skill.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text1)
                    Text(L.Skill.subtitle)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text2)
                }
                .padding(.bottom, DS.Spacing.sm)

                // Built-in Skills
                if !viewModel.builtinSkills.isEmpty {
                    skillSection(title: L.Skill.builtin, skills: viewModel.builtinSkills)
                }

                // Custom Skills
                skillSection(title: L.Skill.custom, skills: viewModel.customSkills, showAdd: true)

                // Error message
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

    // MARK: - Section

    @ViewBuilder
    private func skillSection(title: String, skills: [SkillModel], showAdd: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: title)

            LazyVGrid(columns: cardColumns, spacing: DS.Spacing.md) {
                ForEach(skills) { skill in
                    SkillCardView(
                        skill: skill,
                        viewModel: viewModel
                    )
                }

                if showAdd {
                    AddSkillCard {
                        viewModel.startCreate()
                    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header: icon + name + type badge
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: skill.icon)
                    .font(.system(size: 18))
                    .foregroundColor(skill.swiftUIColor)
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

            // Description
            Text(skill.description)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
                .lineLimit(2)

            // Key binding
            HStack(spacing: DS.Spacing.sm) {
                keyBindingButton

                Spacer()

                // Edit / Delete buttons (only on hover for custom skills)
                if isHovered && !skill.isBuiltin {
                    HStack(spacing: DS.Spacing.xs) {
                        Button(action: { viewModel.startEdit(skill) }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Colors.text2)
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.confirmDelete(id: skill.id) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Colors.statusError)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                .stroke(isHovered ? DS.Colors.text2.opacity(0.3) : DS.Colors.border, lineWidth: DS.Layout.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var keyBindingButton: some View {
        let isBinding = viewModel.isBindingKey && viewModel.bindingSkillId == skill.id

        Button(action: {
            if isBinding {
                viewModel.cancelKeyBinding()
            } else if skill.modifierKey != nil {
                // Long press to unbind, tap to rebind
                viewModel.startKeyBinding(skillId: skill.id)
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
        .onKeyPress(phases: .down) { press in
            guard isBinding else { return .ignored }
            let keyCode = keyCodeFromKeyEquivalent(press.key)
            let modifiers = press.modifiers
            if modifiers.contains(.shift) {
                viewModel.completeKeyBinding(keyCode: 56, displayName: "⇧", isSystemModifier: true)
                return .handled
            } else if modifiers.contains(.command) {
                viewModel.completeKeyBinding(keyCode: 55, displayName: "⌘", isSystemModifier: true)
                return .handled
            } else if modifiers.contains(.control) {
                viewModel.completeKeyBinding(keyCode: 59, displayName: "⌃", isSystemModifier: true)
                return .handled
            } else if keyCode > 0 {
                let display = String(press.key.character).uppercased()
                viewModel.completeKeyBinding(keyCode: keyCode, displayName: display, isSystemModifier: false)
                return .handled
            }
            return .ignored
        }
        .contextMenu {
            if skill.modifierKey != nil {
                Button(action: { viewModel.unbindKey(skillId: skill.id) }) {
                    Label(L.Skill.unboundKey, systemImage: "xmark.circle")
                }
            }
        }
    }

    private func keyCodeFromKeyEquivalent(_ key: KeyEquivalent) -> UInt16 {
        // Basic mapping for common keys
        let char = key.character
        let mapping: [Character: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
            "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
            ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, " ": 49,
        ]
        return mapping[char] ?? 0
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

// MARK: - Create Sheet

struct SkillCreateSheet: View {
    @Bindable var viewModel: SkillViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L.Skill.createSkill)
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text1)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                fieldRow(label: L.Skill.skillName) {
                    TextField(L.Skill.namePlaceholder, text: $viewModel.newName)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(label: L.Skill.skillDescription) {
                    TextField(L.Skill.descPlaceholder, text: $viewModel.newDescription)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(label: L.Skill.skillIcon) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: viewModel.newIcon)
                            .font(.system(size: 16))
                            .foregroundColor(DS.Colors.text1)
                            .frame(width: 28, height: 28)
                            .background(DS.Colors.highlight)
                            .cornerRadius(DS.Layout.cornerRadius)

                        TextField("SF Symbol", text: $viewModel.newIcon)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                    }
                }

                fieldRow(label: L.Skill.promptTemplate) {
                    TextEditor(text: $viewModel.newPrompt)
                        .font(DS.Typography.body)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                .stroke(DS.Colors.border, lineWidth: 1)
                        )
                }
            }

            HStack {
                Spacer()
                Button(L.Common.cancel) { viewModel.cancelCreate() }
                    .buttonStyle(.bordered)
                Button(L.Common.save) { viewModel.confirmCreate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 440)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L.Skill.editSkill)
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text1)

            if let skill = viewModel.editingSkill {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    fieldRow(label: L.Skill.skillName) {
                        TextField(L.Skill.namePlaceholder, text: Binding(
                            get: { viewModel.editingSkill?.name ?? "" },
                            set: { viewModel.editingSkill?.name = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(label: L.Skill.skillDescription) {
                        TextField(L.Skill.descPlaceholder, text: Binding(
                            get: { viewModel.editingSkill?.description ?? "" },
                            set: { viewModel.editingSkill?.description = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(label: L.Skill.skillIcon) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: viewModel.editingSkill?.icon ?? "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(DS.Colors.text1)
                                .frame(width: 28, height: 28)
                                .background(DS.Colors.highlight)
                                .cornerRadius(DS.Layout.cornerRadius)

                            TextField("SF Symbol", text: Binding(
                                get: { viewModel.editingSkill?.icon ?? "" },
                                set: { viewModel.editingSkill?.icon = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                        }
                    }

                    if skill.isEditable {
                        fieldRow(label: L.Skill.promptTemplate) {
                            TextEditor(text: Binding(
                                get: { viewModel.editingSkill?.promptTemplate ?? "" },
                                set: { viewModel.editingSkill?.promptTemplate = $0 }
                            ))
                            .font(DS.Typography.body)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                    .stroke(DS.Colors.border, lineWidth: 1)
                            )
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(L.Common.cancel) { viewModel.cancelEdit() }
                    .buttonStyle(.bordered)
                Button(L.Common.save) { viewModel.saveEdit() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 440)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
            content()
        }
    }
}
