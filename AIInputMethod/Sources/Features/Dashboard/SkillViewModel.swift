import Foundation
import AppKit

// MARK: - Skill ViewModel

/// Skill 管理页面的 ViewModel
@Observable
class SkillViewModel {

    var skills: [SkillModel] { SkillManager.shared.skills }

    var builtinSkills: [SkillModel] {
        skills.filter { $0.isBuiltin }
    }

    var customSkills: [SkillModel] {
        skills.filter { !$0.isBuiltin }
    }

    // MARK: - Edit State

    var isEditing = false
    var editingSkill: SkillModel?

    // MARK: - Create State

    var isCreating = false
    var newName = ""
    var newDescription = ""
    var newIcon = "sparkles"
    var newPrompt = ""

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
        newIcon = "sparkles"
        newPrompt = ""
        isCreating = true
    }

    func confirmCreate() {
        let skill = SkillModel(
            id: UUID().uuidString,
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: newIcon,
            modifierKey: nil,
            promptTemplate: newPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            behaviorConfig: [:],
            isBuiltin: false,
            isEditable: true,
            skillType: .custom
        )

        do {
            try SkillManager.shared.createSkill(skill)
            isCreating = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelCreate() {
        isCreating = false
    }

    func startEdit(_ skill: SkillModel) {
        editingSkill = skill
        isEditing = true
    }

    func saveEdit() {
        guard var skill = editingSkill else { return }
        skill.name = skill.name.trimmingCharacters(in: .whitespacesAndNewlines)
        skill.description = skill.description.trimmingCharacters(in: .whitespacesAndNewlines)
        skill.promptTemplate = skill.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try SkillManager.shared.updateSkill(skill)
            isEditing = false
            editingSkill = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
}
