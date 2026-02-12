import Foundation
import AppKit

// MARK: - Skill Manager

/// Skill 管理器：加载、保存、CRUD、按键绑定查询
@Observable
class SkillManager {
    static let shared = SkillManager()

    /// 所有已加载的 Skill（内置 + 自定义）
    private(set) var skills: [SkillModel] = []

    /// 按键绑定映射 [keyCode: SkillModel.id]
    private(set) var keyBindings: [UInt16: String] = [:]

    /// 存储目录
    let storageDirectory: URL

    // MARK: - Init

    init(storageDirectory: URL? = nil) {
        if let dir = storageDirectory {
            self.storageDirectory = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageDirectory = appSupport.appendingPathComponent("GHOSTYPE/skills")
        }
    }

    // MARK: - Load

    /// 从磁盘加载所有 Skill
    func loadAllSkills() {
        let fm = FileManager.default
        skills = []
        keyBindings = [:]

        guard let entries = try? fm.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            FileLogger.log("[SkillManager] No skills directory found at \(storageDirectory.path)")
            return
        }

        for entry in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let skillFile = entry.appendingPathComponent("SKILL.md")
            guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
                FileLogger.log("[SkillManager] Failed to read \(skillFile.path)")
                continue
            }

            do {
                let skill = try SkillFileParser.parse(content)
                skills.append(skill)
                if let binding = skill.modifierKey {
                    keyBindings[binding.keyCode] = skill.id
                }
            } catch {
                FileLogger.log("[SkillManager] Failed to parse \(skillFile.path): \(error)")
            }
        }

        FileLogger.log("[SkillManager] Loaded \(skills.count) skills")
    }

    // MARK: - CRUD

    /// 创建新 Skill
    func createSkill(_ skill: SkillModel) throws {
        let folderURL = storageDirectory.appendingPathComponent(skill.id)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let content = SkillFileParser.print(skill)
        let fileURL = folderURL.appendingPathComponent("SKILL.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        skills.append(skill)
        if let binding = skill.modifierKey {
            keyBindings[binding.keyCode] = skill.id
        }
    }

    /// 更新已有 Skill
    func updateSkill(_ skill: SkillModel) throws {
        guard let index = skills.firstIndex(where: { $0.id == skill.id }) else {
            throw SkillManagerError.skillNotFound(skill.id)
        }

        let oldSkill = skills[index]

        // 更新文件
        let folderURL = storageDirectory.appendingPathComponent(skill.id)
        let content = SkillFileParser.print(skill)
        let fileURL = folderURL.appendingPathComponent("SKILL.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // 更新内存
        if let oldBinding = oldSkill.modifierKey {
            keyBindings.removeValue(forKey: oldBinding.keyCode)
        }
        skills[index] = skill
        if let newBinding = skill.modifierKey {
            keyBindings[newBinding.keyCode] = skill.id
        }
    }

    /// 删除 Skill（内置 Skill 不可删除）
    func deleteSkill(id: String) throws {
        guard let index = skills.firstIndex(where: { $0.id == id }) else {
            throw SkillManagerError.skillNotFound(id)
        }

        let skill = skills[index]
        if skill.isBuiltin {
            throw SkillManagerError.cannotDeleteBuiltin(skill.name)
        }

        // 删除文件夹
        let folderURL = storageDirectory.appendingPathComponent(id)
        try FileManager.default.removeItem(at: folderURL)

        // 清理内存
        if let binding = skill.modifierKey {
            keyBindings.removeValue(forKey: binding.keyCode)
        }
        skills.remove(at: index)
    }

    // MARK: - Key Binding Queries

    /// 通过 keyCode 查找 Skill
    func skillForKeyCode(_ keyCode: UInt16) -> SkillModel? {
        guard let skillId = keyBindings[keyCode] else { return nil }
        return skills.first(where: { $0.id == skillId })
    }

    /// 通过系统修饰键查找 Skill
    func skillForModifiers(_ modifiers: NSEvent.ModifierFlags) -> SkillModel? {
        // 遍历所有绑定了系统修饰键的 Skill
        for skill in skills {
            guard let binding = skill.modifierKey, binding.isSystemModifier else { continue }
            let modifierFlag = modifierFlagForKeyCode(binding.keyCode)
            if modifiers.contains(modifierFlag) {
                return skill
            }
        }
        return nil
    }

    /// 重新绑定按键
    func rebindKey(skillId: String, newBinding: ModifierKeyBinding?) throws {
        guard var skill = skills.first(where: { $0.id == skillId }) else {
            throw SkillManagerError.skillNotFound(skillId)
        }

        skill.modifierKey = newBinding
        try updateSkill(skill)
    }

    /// 检测按键冲突
    func hasKeyConflict(_ binding: ModifierKeyBinding, excludingSkillId: String? = nil) -> SkillModel? {
        for skill in skills {
            if skill.id == excludingSkillId { continue }
            guard let existingBinding = skill.modifierKey else { continue }
            if existingBinding.keyCode == binding.keyCode {
                return skill
            }
        }
        return nil
    }

    // MARK: - Builtin Skills

    /// 确保内置 Skill 存在（首次启动时创建）
    func ensureBuiltinSkills() {
        let fm = FileManager.default

        if !fm.fileExists(atPath: storageDirectory.path) {
            try? fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }

        let builtins = Self.defaultBuiltinSkills()
        for skill in builtins {
            let folderURL = storageDirectory.appendingPathComponent(skill.id)
            let fileURL = folderURL.appendingPathComponent("SKILL.md")
            if !fm.fileExists(atPath: fileURL.path) {
                try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
                let content = SkillFileParser.print(skill)
                try? content.write(to: fileURL, atomically: true, encoding: .utf8)
                FileLogger.log("[SkillManager] Created builtin skill: \(skill.name)")
            }
        }
    }

    /// 默认内置 Skill 定义
    static func defaultBuiltinSkills() -> [SkillModel] {
        return [
            SkillModel(
                id: SkillModel.builtinMemoId,
                name: "随心记",
                description: "将语音直接记录为笔记",
                icon: "note.text",
                modifierKey: ModifierKeyBinding(keyCode: 56, isSystemModifier: true, displayName: "⇧"),
                promptTemplate: "将用户的语音输入直接保存到笔记本。支持配置是否先润色再保存。",
                behaviorConfig: ["polish_before_save": "false"],
                isBuiltin: true,
                isEditable: false,
                skillType: .memo
            ),
            SkillModel(
                id: SkillModel.builtinGhostCommandId,
                name: "Ghost Command",
                description: "说出指令，AI 直接生成内容",
                icon: "terminal",
                modifierKey: ModifierKeyBinding(keyCode: 55, isSystemModifier: true, displayName: "⌘"),
                promptTemplate: "你是一个万能助手。用户会用语音告诉你一个任务，请直接完成任务并输出结果。不要解释你在做什么，直接给出结果。",
                behaviorConfig: [:],
                isBuiltin: true,
                isEditable: false,
                skillType: .ghostCommand
            ),
            SkillModel(
                id: SkillModel.builtinGhostTwinId,
                name: "Ghost Twin",
                description: "以你的口吻和语言习惯回复",
                icon: "person.2",
                modifierKey: nil,
                promptTemplate: "使用用户的人格档案，以用户的口吻和语言习惯生成回复。",
                behaviorConfig: [:],
                isBuiltin: true,
                isEditable: false,
                skillType: .ghostTwin
            ),
            SkillModel(
                id: SkillModel.builtinTranslateId,
                name: "翻译",
                description: "语音翻译",
                icon: "globe",
                modifierKey: nil,
                promptTemplate: "翻译用户的语音输入。根据配置的目标语言进行翻译。",
                behaviorConfig: ["translate_language": TranslateLanguage.chineseEnglish.rawValue],
                isBuiltin: true,
                isEditable: false,
                skillType: .translate
            ),
        ]
    }

    // MARK: - Helpers

    /// keyCode → NSEvent.ModifierFlags 映射
    private func modifierFlagForKeyCode(_ keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 55, 54: return .command
        case 56, 60: return .shift
        case 58, 61: return .option
        case 59, 62: return .control
        case 63: return .function
        default: return []
        }
    }
}

// MARK: - Errors

enum SkillManagerError: LocalizedError {
    case skillNotFound(String)
    case cannotDeleteBuiltin(String)

    var errorDescription: String? {
        switch self {
        case .skillNotFound(let id):
            return "Skill not found: \(id)"
        case .cannotDeleteBuiltin(let name):
            return "Cannot delete builtin skill: \(name)"
        }
    }
}
