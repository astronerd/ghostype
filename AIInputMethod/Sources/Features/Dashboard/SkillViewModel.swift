import Foundation
import AppKit

// MARK: - Skill ViewModel

/// Skill 管理页面的 ViewModel
@Observable
class SkillViewModel {

    var skills: [SkillModel] { SkillManager.shared.skills }

    var builtinSkills: [SkillModel] {
        skills.filter { $0.isBuiltin && !$0.isInternal }
    }

    var customSkills: [SkillModel] {
        skills.filter { !$0.isBuiltin && !$0.isInternal }
    }

    // MARK: - Edit State

    var isEditing = false
    var editingSkill: SkillModel?

    // MARK: - Create State

    var isCreating = false
    var isGenerating = false
    var newName = ""
    var newDescription = ""
    var newIcon = "✨"
    var newPrompt = ""
    var newColorHex = "#5AC8FA"

    // MARK: - Key Binding State

    var isBindingKey = false
    var bindingSkillId: String?

    // MARK: - Delete State

    var showDeleteConfirm = false
    var deletingSkillId: String?

    // MARK: - Error State

    var errorMessage: String?

    // MARK: - Actions

    func refresh() {
        SkillManager.shared.loadAllSkills()
    }

    func startCreate() {
        newName = ""
        newDescription = ""
        newIcon = "✨"
        newPrompt = ""
        newColorHex = "#5AC8FA"
        isCreating = true
    }

    func confirmCreate() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return }

        isGenerating = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // 用 AI 将用户指令生成为完整的 system prompt
                let systemPrompt: String
                if trimmedPrompt.isEmpty {
                    // 没有用户指令，用 description 作为 fallback
                    systemPrompt = trimmedDesc
                } else {
                    systemPrompt = try await SkillPromptGenerator.generate(
                        skillName: trimmedName,
                        skillDescription: trimmedDesc,
                        userPrompt: trimmedPrompt
                    )
                }

                let skill = SkillModel(
                    id: UUID().uuidString,
                    name: trimmedName,
                    description: trimmedDesc,
                    userPrompt: trimmedPrompt,
                    systemPrompt: systemPrompt,
                    allowedTools: ["provide_text"],
                    contextRequires: [],
                    config: [:],
                    icon: newIcon,
                    colorHex: newColorHex,
                    modifierKey: nil,
                    isBuiltin: false,
                    isInternal: false
                )

                try SkillManager.shared.createSkill(skill)
                isCreating = false
                isGenerating = false
                errorMessage = nil
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancelCreate() {
        isCreating = false
    }

    func startEdit(_ skill: SkillModel) {
        editingSkill = skill
        originalUserPrompt = skill.userPrompt
        isEditing = true
    }

    /// 编辑前保存的原始 userPrompt，用于判断是否需要重新生成
    var originalUserPrompt: String = ""

    func saveEdit() {
        guard var skill = editingSkill else { return }
        skill.name = skill.name.trimmingCharacters(in: .whitespacesAndNewlines)
        skill.description = skill.description.trimmingCharacters(in: .whitespacesAndNewlines)
        skill.userPrompt = skill.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let userPromptChanged = skill.userPrompt != originalUserPrompt
        let needsRegenerate = userPromptChanged && !skill.userPrompt.isEmpty && !skill.isBuiltin

        if needsRegenerate {
            isGenerating = true
            errorMessage = nil

            Task { @MainActor in
                do {
                    let newSystemPrompt = try await SkillPromptGenerator.generate(
                        skillName: skill.name,
                        skillDescription: skill.description,
                        userPrompt: skill.userPrompt
                    )
                    skill.systemPrompt = newSystemPrompt
                    try SkillManager.shared.updateSkill(skill)
                    isEditing = false
                    editingSkill = nil
                    isGenerating = false
                    errorMessage = nil
                } catch {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            do {
                try SkillManager.shared.updateSkill(skill)
                isEditing = false
                editingSkill = nil
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancelEdit() {
        isEditing = false
        editingSkill = nil
    }

    func confirmDelete(id: String) {
        deletingSkillId = id
        showDeleteConfirm = true
    }

    func executeDelete() {
        guard let id = deletingSkillId else { return }
        do {
            try SkillManager.shared.deleteSkill(id: id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        showDeleteConfirm = false
        deletingSkillId = nil
    }

    func cancelDelete() {
        showDeleteConfirm = false
        deletingSkillId = nil
    }

    // MARK: - Key Binding

    func startKeyBinding(skillId: String) {
        bindingSkillId = skillId
        isBindingKey = true
    }

    func completeKeyBinding(keyCode: UInt16, displayName: String, isSystemModifier: Bool) {
        guard let skillId = bindingSkillId else { return }
        let binding = ModifierKeyBinding(
            keyCode: keyCode,
            isSystemModifier: isSystemModifier,
            displayName: displayName
        )

        // Check conflict
        if let conflict = SkillManager.shared.hasKeyConflict(binding, excludingSkillId: skillId) {
            errorMessage = "\(L.Skill.keyConflict): \(conflict.name)"
            isBindingKey = false
            bindingSkillId = nil
            return
        }

        do {
            try SkillManager.shared.rebindKey(skillId: skillId, newBinding: binding)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isBindingKey = false
        bindingSkillId = nil
    }

    func unbindKey(skillId: String) {
        do {
            try SkillManager.shared.rebindKey(skillId: skillId, newBinding: nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelKeyBinding() {
        isBindingKey = false
        bindingSkillId = nil
    }

    // MARK: - Color

    func updateColor(skillId: String, colorHex: String) {
        do {
            try SkillManager.shared.updateColor(skillId: skillId, colorHex: colorHex)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Translate Config

    func updateTranslateConfig(skillId: String, sourceLanguage: String, targetLanguage: String) {
        guard var skill = SkillManager.shared.skills.first(where: { $0.id == skillId }) else { return }
        skill.config["source_language"] = sourceLanguage
        skill.config["target_language"] = targetLanguage
        do {
            try SkillManager.shared.updateSkill(skill)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
