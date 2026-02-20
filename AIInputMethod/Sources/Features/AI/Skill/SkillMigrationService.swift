import Foundation
import AppKit

// MARK: - Skill Migration Service

struct SkillMigrationService {

    private static let migrationKey = "skillMigrationCompleted"
    private static let skillFileMigrationKey = "skillFileMigrationV2Completed"

    // MARK: - Old AppSettings Migration

    /// 从旧版 AppSettings 迁移修饰键绑定到新 Skill 系统（幂等）
    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else {
            FileLogger.log("[SkillMigration] AppSettings migration already done, skipping")
            return
        }

        FileLogger.log("[SkillMigration] Starting migration from old AppSettings...")

        let skillManager = SkillManager.shared

        // 确保内置 Skill 文件已创建
        skillManager.ensureBuiltinSkills()
        skillManager.loadAllSkills()

        // 迁移 Memo 修饰键绑定
        if let rawValue = defaults.object(forKey: "memoModifier") as? UInt {
            let oldModifier = NSEvent.ModifierFlags(rawValue: rawValue)
            if let keyCode = keyCodeForModifier(oldModifier),
               var memoSkill = skillManager.skills.first(where: { $0.id == SkillModel.builtinMemoId }) {
                let binding = ModifierKeyBinding(
                    keyCode: keyCode,
                    isSystemModifier: true,
                    displayName: AppSettings.formatModifier(oldModifier)
                )
                memoSkill.modifierKey = binding
                try? skillManager.updateSkill(memoSkill)
                FileLogger.log("[SkillMigration] Migrated memo modifier: \(binding.displayName)")
            }
        }

        // 迁移 Translate 修饰键绑定 + 翻译语言
        if let rawValue = defaults.object(forKey: "translateModifier") as? UInt {
            let oldModifier = NSEvent.ModifierFlags(rawValue: rawValue)
            if let keyCode = keyCodeForModifier(oldModifier),
               var translateSkill = skillManager.skills.first(where: { $0.id == SkillModel.builtinTranslateId }) {
                let binding = ModifierKeyBinding(
                    keyCode: keyCode,
                    isSystemModifier: true,
                    displayName: AppSettings.formatModifier(oldModifier)
                )
                translateSkill.modifierKey = binding

                // 迁移翻译语言到 config
                if let savedLanguage = defaults.string(forKey: "translateLanguage") {
                    let (source, target) = mapTranslateLanguage(savedLanguage)
                    translateSkill.config["source_language"] = source
                    translateSkill.config["target_language"] = target
                }

                try? skillManager.updateSkill(translateSkill)
                FileLogger.log("[SkillMigration] Migrated translate modifier: \(binding.displayName)")
            }
        }

        // 标记迁移完成
        defaults.set(true, forKey: migrationKey)
        FileLogger.log("[SkillMigration] AppSettings migration completed")
    }

    // MARK: - Skill File Migration (旧格式 SKILL.md → 新格式)

    /// 遍历 skills 目录，检测并迁移旧格式 SKILL.md 到新格式。
    /// - 解析旧格式，提取 legacyFields
    /// - UI 元数据写入 SkillMetadataStore
    /// - 语义字段映射（skillType → allowed_tools/config）
    /// - 重写 SKILL.md 为新格式
    /// - 幂等：迁移后的文件不含 skill_type，再次运行不会重复迁移
    static func migrateSkillFiles(
        storageDirectory: URL,
        metadataStore: SkillMetadataStore
    ) {
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            FileLogger.log("[SkillMigration] No skills directory found at \(storageDirectory.path)")
            return
        }

        var migratedCount = 0

        for entry in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            let skillFile = entry.appendingPathComponent("SKILL.md")
            guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
                continue
            }

            let directoryName = entry.lastPathComponent

            do {
                let parseResult = try SkillFileParser.parse(content, directoryName: directoryName)

                // 只迁移包含旧格式字段且有 skillType 的文件
                guard let legacy = parseResult.legacyFields,
                      let skillType = legacy.skillType else {
                    continue
                }

                FileLogger.log("[SkillMigration] Migrating old format skill: \(directoryName) (type: \(skillType))")

                // 1. 提取 UI 元数据到 SkillMetadataStore
                metadataStore.importLegacy(skillId: directoryName, legacy: legacy)

                // 2. 映射语义字段
                let (allowedTools, config) = mapSkillType(skillType, behaviorConfig: legacy.behaviorConfig)

                // 合并：迁移映射的 config + 原有 parseResult 中已有的 config
                var mergedConfig = parseResult.config
                for (key, value) in config {
                    mergedConfig[key] = value
                }

                // 合并 allowedTools：优先使用映射结果，如果映射为空则保留原有
                let finalAllowedTools = allowedTools.isEmpty ? parseResult.allowedTools : allowedTools

                // 3. 构建新的 ParseResult（无 legacyFields）
                let newParseResult = SkillFileParser.ParseResult(
                    name: parseResult.name,
                    description: parseResult.description,
                    userPrompt: parseResult.userPrompt,
                    systemPrompt: parseResult.systemPrompt,
                    allowedTools: finalAllowedTools,
                    contextRequires: parseResult.contextRequires,
                    config: mergedConfig,
                    legacyFields: nil
                )

                // 4. 重写 SKILL.md 为新格式
                let newContent = SkillFileParser.print(newParseResult)
                try newContent.write(to: skillFile, atomically: true, encoding: .utf8)

                migratedCount += 1
                FileLogger.log("[SkillMigration] Migrated skill: \(directoryName)")

            } catch {
                FileLogger.log("[SkillMigration] ⚠️ Failed to migrate \(directoryName): \(error.localizedDescription)")
            }
        }

        // 保存元数据
        if migratedCount > 0 {
            metadataStore.save()
            FileLogger.log("[SkillMigration] Skill file migration completed, migrated \(migratedCount) skills")
        } else {
            FileLogger.log("[SkillMigration] No old format skills found, nothing to migrate")
        }
    }

    // MARK: - Skill Type Mapping

    /// 将旧 skillType 映射到新的 allowed_tools + config。
    ///
    /// 映射表：
    /// - polish    → ["provide_text"], 无额外 config
    /// - memo      → ["save_memo"], 无额外 config
    /// - translate → ["provide_text"], source_language + target_language（从 behaviorConfig 映射）
    /// - ghostCommand → ["provide_text"], 无额外 config
    /// - ghostTwin → ["provide_text"], api_endpoint = /api/v1/ghost-twin/chat
    /// - custom    → ["provide_text"], 无额外 config
    /// - 未知类型  → ["provide_text"], 无额外 config
    static func mapSkillType(
        _ skillType: String,
        behaviorConfig: [String: String]
    ) -> (allowedTools: [String], config: [String: String]) {
        switch skillType {
        case "polish":
            return (["provide_text"], [:])

        case "memo":
            return (["save_memo"], [:])

        case "translate":
            let translateLanguage = behaviorConfig["translate_language"] ?? "auto"
            let (source, target) = mapTranslateLanguage(translateLanguage)
            return (["provide_text"], ["source_language": source, "target_language": target])

        case "ghostCommand":
            return (["provide_text"], [:])

        case "ghostTwin":
            return (["provide_text"], ["api_endpoint": "/api/v1/ghost-twin/chat"])

        case "custom":
            return (["provide_text"], [:])

        default:
            FileLogger.log("[SkillMigration] Unknown skillType: \(skillType), defaulting to provide_text")
            return (["provide_text"], [:])
        }
    }

    // MARK: - Private Helpers

    /// 将旧的 translate_language 值映射为 source_language + target_language
    private static func mapTranslateLanguage(_ language: String) -> (source: String, target: String) {
        switch language {
        case "chineseEnglish":
            return ("中文", "英文")
        case "chineseJapanese":
            return ("中文", "日文")
        default:
            // "auto" 或其他未知值
            return ("自动检测", "英文")
        }
    }

    /// 修饰键 Flag → keyCode
    private static func keyCodeForModifier(_ modifier: NSEvent.ModifierFlags) -> UInt16? {
        if modifier.contains(.command) { return 55 }
        if modifier.contains(.shift) { return 56 }
        if modifier.contains(.option) { return 58 }
        if modifier.contains(.control) { return 59 }
        if modifier.contains(.function) { return 63 }
        return nil
    }
}
