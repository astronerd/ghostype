import Foundation

// MARK: - Migration Service

/// 数据迁移服务
/// 在应用启动时执行一次性迁移，将 UserDefaults 中的旧中文枚举值迁移为英文值
/// 以匹配新的 API 参数格式
///
/// 迁移项目：
/// - `defaultProfile`: PolishProfile rawValue（中文 → 英文）
/// - `selectedProfileId`: PolishProfile rawValue 或自定义 UUID（中文 → 英文）
/// - `appProfileMapping`: [BundleID: ProfileID] 字典中的值（中文 → 英文）
/// - `translateLanguage`: TranslateLanguage rawValue（中文 → 英文）
struct MigrationService {
    
    /// 迁移完成标记的 UserDefaults key
    private static let migrationCompletedKey = "migration_v2_completed"
    
    /// PolishProfile 中文 → 英文映射
    private static let polishMigrationMap: [String: String] = [
        "默认": "standard",
        "专业": "professional",
        "活泼": "casual",
        "简洁": "concise",
        "创意": "creative"
    ]
    
    /// TranslateLanguage 中文 → 英文映射
    private static let translateMigrationMap: [String: String] = [
        "中英互译": "chineseEnglish",
        "中日互译": "chineseJapanese",
        "自动检测": "auto"
    ]
    
    // MARK: - Public API
    
    /// 在应用启动时调用，检查并执行迁移（如果尚未完成）
    /// 迁移是幂等的：已经是英文值的不会被修改
    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        
        // 检查迁移是否已完成
        if defaults.bool(forKey: migrationCompletedKey) {
            print("[Migration] v2 migration already completed, skipping")
            return
        }
        
        print("[Migration] Starting v2 migration...")
        
        migratePolishProfile()
        migrateTranslateLanguage()
        migrateProfileMappings()
        
        // 标记迁移已完成
        defaults.set(true, forKey: migrationCompletedKey)
        print("[Migration] v2 migration completed")
    }
    
    // MARK: - Private Migration Methods
    
    /// 迁移 `defaultProfile` 和 `selectedProfileId` 中的 PolishProfile rawValue
    private static func migratePolishProfile() {
        let defaults = UserDefaults.standard
        
        // 迁移 defaultProfile
        if let oldValue = defaults.string(forKey: "defaultProfile"),
           let newValue = polishMigrationMap[oldValue] {
            defaults.set(newValue, forKey: "defaultProfile")
            print("[Migration] defaultProfile: \"\(oldValue)\" → \"\(newValue)\"")
        }
        
        // 迁移 selectedProfileId
        // 注意：selectedProfileId 可能是预设 rawValue 或自定义 UUID
        // 只有匹配旧中文值时才迁移，UUID 不受影响
        if let oldValue = defaults.string(forKey: "selectedProfileId"),
           let newValue = polishMigrationMap[oldValue] {
            defaults.set(newValue, forKey: "selectedProfileId")
            print("[Migration] selectedProfileId: \"\(oldValue)\" → \"\(newValue)\"")
        }
    }
    
    /// 迁移 `translateLanguage` 中的 TranslateLanguage rawValue
    private static func migrateTranslateLanguage() {
        let defaults = UserDefaults.standard
        
        if let oldValue = defaults.string(forKey: "translateLanguage"),
           let newValue = translateMigrationMap[oldValue] {
            defaults.set(newValue, forKey: "translateLanguage")
            print("[Migration] translateLanguage: \"\(oldValue)\" → \"\(newValue)\"")
        }
    }
    
    /// 迁移 `appProfileMapping` 字典中的 PolishProfile rawValue
    /// 字典结构为 [BundleID: ProfileID]，只迁移值（ProfileID）部分
    private static func migrateProfileMappings() {
        let defaults = UserDefaults.standard
        
        guard var mapping = defaults.dictionary(forKey: "appProfileMapping") as? [String: String] else {
            return
        }
        
        var migrated = false
        for (bundleId, profileId) in mapping {
            if let newValue = polishMigrationMap[profileId] {
                mapping[bundleId] = newValue
                print("[Migration] appProfileMapping[\"\(bundleId)\"]: \"\(profileId)\" → \"\(newValue)\"")
                migrated = true
            }
        }
        
        if migrated {
            defaults.set(mapping, forKey: "appProfileMapping")
            print("[Migration] appProfileMapping updated")
        }
    }
}
