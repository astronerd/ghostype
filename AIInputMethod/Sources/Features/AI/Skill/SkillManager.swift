import Foundation
import AppKit

// MARK: - Skill Manager

@Observable
class SkillManager {
    static let shared = SkillManager()

    private(set) var skills: [SkillModel] = []
    private(set) var keyBindings: [UInt16: String] = [:]

    let storageDirectory: URL
    let metadataStore: SkillMetadataStore

    // MARK: - Init

    init(storageDirectory: URL? = nil, metadataStore: SkillMetadataStore? = nil) {
        if let dir = storageDirectory {
            self.storageDirectory = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageDirectory = appSupport.appendingPathComponent("GHOSTYPE/skills")
        }
        self.metadataStore = metadataStore ?? SkillMetadataStore()
    }

    // MARK: - Load

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

            let directoryName = entry.lastPathComponent

            do {
                let parseResult = try SkillFileParser.parse(content, directoryName: directoryName)

                // Handle legacy migration: if SKILL.md contains legacy UI fields, import them
                if let legacy = parseResult.legacyFields {
                    metadataStore.importLegacy(skillId: directoryName, legacy: legacy)
                }

                let metadata = metadataStore.get(skillId: directoryName)

                let skill = SkillModel(
                    id: directoryName,
                    name: parseResult.name,
                    description: parseResult.description,
                    userPrompt: parseResult.userPrompt,
                    systemPrompt: parseResult.systemPrompt,
                    allowedTools: parseResult.allowedTools.isEmpty ? ["provide_text"] : parseResult.allowedTools,
                    config: parseResult.config,
                    icon: metadata.icon,
                    colorHex: metadata.colorHex,
                    modifierKey: metadata.modifierKey,
                    isBuiltin: metadata.isBuiltin,
                    isInternal: metadata.isInternal
                )

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

    func createSkill(_ skill: SkillModel) throws {
        let folderURL = storageDirectory.appendingPathComponent(skill.id)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        // Write SKILL.md with semantic fields only
        let parseResult = makeParseResult(from: skill)
        let content = SkillFileParser.print(parseResult)
        let fileURL = folderURL.appendingPathComponent("SKILL.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Save UI metadata to store
        let metadata = makeMetadata(from: skill)
        metadataStore.update(skillId: skill.id, metadata: metadata)

        skills.append(skill)
        if let binding = skill.modifierKey {
            keyBindings[binding.keyCode] = skill.id
        }
    }

    func updateSkill(_ skill: SkillModel) throws {
        guard let index = skills.firstIndex(where: { $0.id == skill.id }) else {
            throw SkillManagerError.skillNotFound(skill.id)
        }

        let oldSkill = skills[index]

        // Write SKILL.md with semantic fields only
        let folderURL = storageDirectory.appendingPathComponent(skill.id)
        let parseResult = makeParseResult(from: skill)
        let content = SkillFileParser.print(parseResult)
        let fileURL = folderURL.appendingPathComponent("SKILL.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Update UI metadata in store
        let metadata = makeMetadata(from: skill)
        metadataStore.update(skillId: skill.id, metadata: metadata)

        // Update in-memory state
        if let oldBinding = oldSkill.modifierKey {
            keyBindings.removeValue(forKey: oldBinding.keyCode)
        }
        skills[index] = skill
        if let newBinding = skill.modifierKey {
            keyBindings[newBinding.keyCode] = skill.id
        }
    }

    func deleteSkill(id: String) throws {
        guard let index = skills.firstIndex(where: { $0.id == id }) else {
            throw SkillManagerError.skillNotFound(id)
        }

        let skill = skills[index]
        if skill.isBuiltin {
            throw SkillManagerError.cannotDeleteBuiltin(skill.name)
        }

        let folderURL = storageDirectory.appendingPathComponent(id)
        try FileManager.default.removeItem(at: folderURL)

        // Remove metadata from store
        metadataStore.remove(skillId: id)

        if let binding = skill.modifierKey {
            keyBindings.removeValue(forKey: binding.keyCode)
        }
        skills.remove(at: index)
    }

    // MARK: - UI Metadata Updates

    func updateColor(skillId: String, colorHex: String) throws {
        guard let index = skills.firstIndex(where: { $0.id == skillId }) else {
            throw SkillManagerError.skillNotFound(skillId)
        }
        var meta = metadataStore.get(skillId: skillId)
        meta.colorHex = colorHex
        metadataStore.update(skillId: skillId, metadata: meta)
        skills[index].colorHex = colorHex
    }

    func updateIcon(skillId: String, icon: String) throws {
        guard let index = skills.firstIndex(where: { $0.id == skillId }) else {
            throw SkillManagerError.skillNotFound(skillId)
        }
        var meta = metadataStore.get(skillId: skillId)
        meta.icon = icon
        metadataStore.update(skillId: skillId, metadata: meta)
        skills[index].icon = icon
    }

    // MARK: - Key Binding Queries

    func skillForKeyCode(_ keyCode: UInt16) -> SkillModel? {
        guard let skillId = keyBindings[keyCode] else { return nil }
        return skills.first(where: { $0.id == skillId })
    }

    func skillForModifiers(_ modifiers: NSEvent.ModifierFlags) -> SkillModel? {
        for skill in skills {
            guard let binding = skill.modifierKey, binding.isSystemModifier else { continue }
            let modifierFlag = modifierFlagForKeyCode(binding.keyCode)
            if modifiers.contains(modifierFlag) {
                return skill
            }
        }
        return nil
    }

    func rebindKey(skillId: String, newBinding: ModifierKeyBinding?) throws {
        guard var skill = skills.first(where: { $0.id == skillId }) else {
            throw SkillManagerError.skillNotFound(skillId)
        }

        skill.modifierKey = newBinding
        try updateSkill(skill)
    }

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

    /// 内置 Skill 的 UI 元数据定义（icon、color、快捷键、标记）
    /// Prompt 内容全部来自 app bundle 中的 SKILL.md 文件，不在代码中硬编码
    private static let builtinMetadata: [(id: String, metadata: SkillMetadata)] = [
        (
            id: SkillModel.builtinMemoId,
            metadata: SkillMetadata(
                icon: "📝", colorHex: "#FF9500",
                modifierKey: ModifierKeyBinding(keyCode: 56, isSystemModifier: true, displayName: "⇧"),
                isBuiltin: true, isInternal: false
            )
        ),
        (
            id: SkillModel.builtinGhostCommandId,
            metadata: SkillMetadata(
                icon: "👻", colorHex: "#007AFF",
                modifierKey: ModifierKeyBinding(keyCode: 59, isSystemModifier: true, displayName: "⌃"),
                isBuiltin: true, isInternal: false
            )
        ),
        (
            id: SkillModel.builtinGhostTwinId,
            metadata: SkillMetadata(
                icon: "🪞", colorHex: "#FF2D55",
                modifierKey: nil,
                isBuiltin: true, isInternal: false
            )
        ),
        (
            id: SkillModel.builtinTranslateId,
            metadata: SkillMetadata(
                icon: "🌐", colorHex: "#AF52DE",
                modifierKey: nil,
                isBuiltin: true, isInternal: false
            )
        ),
        (
            id: SkillModel.builtinPromptGeneratorId,
            metadata: SkillMetadata(
                icon: "🧠", colorHex: "#8E8E93",
                modifierKey: nil,
                isBuiltin: true, isInternal: true
            )
        ),
        (
            id: SkillModel.internalGhostCalibrationId,
            metadata: SkillMetadata(
                icon: "🎯", colorHex: "#34C759",
                modifierKey: nil,
                isBuiltin: true, isInternal: true
            )
        ),
        (
            id: SkillModel.internalGhostProfilingId,
            metadata: SkillMetadata(
                icon: "🧬", colorHex: "#5856D6",
                modifierKey: nil,
                isBuiltin: true, isInternal: true
            )
        ),
    ]

    func ensureBuiltinSkills() {
        let fm = FileManager.default

        if !fm.fileExists(atPath: storageDirectory.path) {
            try? fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }

        // 从 app bundle 的 default_skills/ 目录读取 SKILL.md，复制到运行时目录
        guard let bundleSkillsURL = Bundle.main.resourceURL?.appendingPathComponent("default_skills") else {
            FileLogger.log("[SkillManager] ⚠️ default_skills not found in app bundle")
            return
        }

        for definition in Self.builtinMetadata {
            let bundleSkillFile = bundleSkillsURL
                .appendingPathComponent(definition.id)
                .appendingPathComponent("SKILL.md")

            guard let content = try? String(contentsOf: bundleSkillFile, encoding: .utf8) else {
                FileLogger.log("[SkillManager] ⚠️ Failed to read bundle SKILL.md for \(definition.id)")
                continue
            }

            // 复制 SKILL.md 到运行时目录（始终覆盖，确保代码更新能传播）
            let runtimeFolder = storageDirectory.appendingPathComponent(definition.id)
            let runtimeFile = runtimeFolder.appendingPathComponent("SKILL.md")
            try? fm.createDirectory(at: runtimeFolder, withIntermediateDirectories: true)
            try? content.write(to: runtimeFile, atomically: true, encoding: .utf8)
            FileLogger.log("[SkillManager] Synced builtin skill from bundle: \(definition.id)")

            // 写入 metadata（保留用户自定义的快捷键绑定）
            let existing = metadataStore.get(skillId: definition.id)
            var meta = definition.metadata
            meta.modifierKey = existing.modifierKey ?? definition.metadata.modifierKey
            metadataStore.update(skillId: definition.id, metadata: meta)
        }
    }

    // MARK: - Skill Lookup

    /// 根据 ID 查找 skill（包括 internal skills）
    func skill(byId id: String) -> SkillModel? {
        skills.first(where: { $0.id == id })
    }

    // MARK: - Private Helpers

    private func makeParseResult(from skill: SkillModel) -> SkillFileParser.ParseResult {
        SkillFileParser.ParseResult(
            name: skill.name,
            description: skill.description,
            userPrompt: skill.userPrompt,
            systemPrompt: skill.systemPrompt,
            allowedTools: skill.allowedTools,
            config: skill.config,
            legacyFields: nil
        )
    }

    private func makeMetadata(from skill: SkillModel) -> SkillMetadata {
        SkillMetadata(
            icon: skill.icon,
            colorHex: skill.colorHex,
            modifierKey: skill.modifierKey,
            isBuiltin: skill.isBuiltin,
            isInternal: skill.isInternal
        )
    }

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
        case .skillNotFound(let id): return "Skill not found: \(id)"
        case .cannotDeleteBuiltin(let name): return "Cannot delete builtin skill: \(name)"
        }
    }
}
