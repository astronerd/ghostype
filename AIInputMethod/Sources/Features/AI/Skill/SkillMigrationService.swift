import Foundation
import AppKit

// MARK: - Skill Migration Service

/// 从旧版 AppSettings 迁移到 Skill 系统
struct SkillMigrationService {

    private static let migrationKey = "skillMigrationCompleted"

    /// 如果需要，执行迁移（幂等）
    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else {
            FileLogger.log("[SkillMigration] Already migrated, skipping")
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

        // 迁移 Translate 修饰键绑定
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
                // 迁移翻译语言
                if let savedLanguage = defaults.string(forKey: "translateLanguage") {
                    translateSkill.behaviorConfig["translate_language"] = savedLanguage
                }
                try? skillManager.updateSkill(translateSkill)
                FileLogger.log("[SkillMigration] Migrated translate modifier: \(binding.displayName)")
            }
        }

        // 标记迁移完成
        defaults.set(true, forKey: migrationKey)
        FileLogger.log("[SkillMigration] Migration completed")
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
