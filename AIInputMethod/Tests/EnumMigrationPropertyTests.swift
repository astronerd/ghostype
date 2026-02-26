import XCTest
import Foundation

// MARK: - Test Copies of Enum Migration Logic
// Since the test target cannot import the executable target,
// we duplicate the migration logic here for testing.

// MARK: - TestPolishProfile (Test Copy)

/// Exact copy of PolishProfile from PolishProfile.swift
private enum TestPolishProfile: String, CaseIterable {
    case standard = "standard"
    case professional = "professional"
    case casual = "casual"
    case concise = "concise"
    case creative = "creative"

    /// 旧中文 rawValue → 新英文 rawValue 的迁移映射
    private static let migrationMap: [String: String] = [
        "默认": "standard",
        "专业": "professional",
        "活泼": "casual",
        "简洁": "concise",
        "创意": "creative"
    ]

    /// 迁移旧中文 rawValue 为对应的 TestPolishProfile
    static func migrate(oldValue: String) -> TestPolishProfile? {
        // 先尝试直接用新英文 rawValue 初始化（已迁移的值）
        if let profile = TestPolishProfile(rawValue: oldValue) {
            return profile
        }
        // 再尝试从旧中文 rawValue 映射
        if let newRawValue = migrationMap[oldValue] {
            return TestPolishProfile(rawValue: newRawValue)
        }
        return nil
    }
}

// MARK: - TestTranslateLanguage (Test Copy)

/// Exact copy of TranslateLanguage from TranslateLanguage.swift
private enum TestTranslateLanguage: String, CaseIterable {
    case chineseEnglish = "chineseEnglish"
    case chineseJapanese = "chineseJapanese"
    case auto = "auto"

    /// 旧中文 rawValue → 新英文 rawValue 的迁移映射
    private static let migrationMap: [String: String] = [
        "中英互译": "chineseEnglish",
        "中日互译": "chineseJapanese",
        "自动检测": "auto"
    ]

    /// 迁移旧中文 rawValue 为对应的 TestTranslateLanguage
    static func migrate(oldValue: String) -> TestTranslateLanguage? {
        // 先尝试直接用新英文 rawValue 初始化（已迁移的值）
        if let language = TestTranslateLanguage(rawValue: oldValue) {
            return language
        }
        // 再尝试从旧中文 rawValue 映射
        if let newRawValue = migrationMap[oldValue] {
            return TestTranslateLanguage(rawValue: newRawValue)
        }
        return nil
    }
}

// MARK: - Migration Test Data

private struct EnumMigrationTestData {

    /// All old Chinese rawValues for PolishProfile with their expected English enum cases
    static let polishMigrationPairs: [(oldChinese: String, expectedCase: TestPolishProfile, expectedRawValue: String)] = [
        ("默认", .standard, "standard"),
        ("专业", .professional, "professional"),
        ("活泼", .casual, "casual"),
        ("简洁", .concise, "concise"),
        ("创意", .creative, "creative")
    ]

    /// All old Chinese rawValues for TranslateLanguage with their expected English enum cases
    static let translateMigrationPairs: [(oldChinese: String, expectedCase: TestTranslateLanguage, expectedRawValue: String)] = [
        ("中英互译", .chineseEnglish, "chineseEnglish"),
        ("中日互译", .chineseJapanese, "chineseJapanese"),
        ("自动检测", .auto, "auto")
    ]

    /// All valid English rawValues for PolishProfile (already-migrated values)
    static let polishEnglishRawValues: [String] = [
        "standard", "professional", "casual", "concise", "creative"
    ]

    /// All valid English rawValues for TranslateLanguage (already-migrated values)
    static let translateEnglishRawValues: [String] = [
        "chineseEnglish", "chineseJapanese", "auto"
    ]

    /// Generate random invalid/unknown values that should return nil
    static func randomInvalidPolishValue() -> String {
        let invalids = [
            "unknown", "默", "标准", "Standard", "STANDARD",
            "pro", "Professional", "casual_mode", "简",
            "", "  ", "default", "fancy", "normal",
            "创", "活", "专", "concise_mode", "creative_writing"
        ]
        return invalids.randomElement()!
    }

    /// Generate random invalid/unknown values for TranslateLanguage
    static func randomInvalidTranslateValue() -> String {
        let invalids = [
            "unknown", "中英", "english", "Chinese", "AUTO",
            "chinese_english", "ChineseEnglish", "ja", "en",
            "", "  ", "translate", "中", "互译",
            "japanese", "chinese", "detect", "自动"
        ]
        return invalids.randomElement()!
    }

    /// Randomly pick one old Chinese PolishProfile value
    static func randomOldPolishChinese() -> (oldChinese: String, expectedCase: TestPolishProfile, expectedRawValue: String) {
        return polishMigrationPairs.randomElement()!
    }

    /// Randomly pick one old Chinese TranslateLanguage value
    static func randomOldTranslateChinese() -> (oldChinese: String, expectedCase: TestTranslateLanguage, expectedRawValue: String) {
        return translateMigrationPairs.randomElement()!
    }

    /// Randomly pick one already-migrated English PolishProfile value
    static func randomPolishEnglishRawValue() -> String {
        return polishEnglishRawValues.randomElement()!
    }

    /// Randomly pick one already-migrated English TranslateLanguage value
    static func randomTranslateEnglishRawValue() -> String {
        return translateEnglishRawValues.randomElement()!
    }
}

// MARK: - Property Tests

/// Property-based tests for enum migration (PolishProfile and TranslateLanguage)
/// Feature: api-online-auth
/// **Validates: Requirements 8.2, 8.3, 9.2**
final class EnumMigrationPropertyTests: XCTestCase {

    // MARK: - Property 9: PolishProfile 枚举迁移完整性

    /// Feature: api-online-auth, Property 9: PolishProfile 枚举迁移完整性
    /// For any old Chinese rawValue ("默认"、"专业"、"活泼"、"简洁"、"创意"),
    /// PolishProfile.migrate() should return the corresponding English enum value,
    /// and the migrated rawValue can be used directly for API requests.
    /// **Validates: Requirements 8.2, 8.3**
    func testProperty9_PolishProfileChineseMigration() {
        PropertyTest.verify(
            "Old Chinese PolishProfile rawValue migrates to correct English enum value",
            iterations: 100
        ) {
            // Randomly pick one old Chinese value
            let pair = EnumMigrationTestData.randomOldPolishChinese()

            // Migrate
            guard let migrated = TestPolishProfile.migrate(oldValue: pair.oldChinese) else {
                return false
            }

            // The migrated enum case should match the expected case
            guard migrated == pair.expectedCase else { return false }

            // The migrated rawValue should be the expected English string
            guard migrated.rawValue == pair.expectedRawValue else { return false }

            // The rawValue should be usable directly for API requests (non-empty, ASCII)
            guard !migrated.rawValue.isEmpty else { return false }
            guard migrated.rawValue.allSatisfy({ $0.isASCII }) else { return false }

            return true
        }
    }

    /// Already-migrated English rawValues should pass through correctly
    /// **Validates: Requirements 8.2, 8.3**
    func testProperty9_PolishProfileEnglishPassthrough() {
        PropertyTest.verify(
            "Already-migrated English PolishProfile rawValue passes through correctly",
            iterations: 100
        ) {
            // Randomly pick one English rawValue
            let englishRawValue = EnumMigrationTestData.randomPolishEnglishRawValue()

            // Migrate should return the same enum case
            guard let migrated = TestPolishProfile.migrate(oldValue: englishRawValue) else {
                return false
            }

            // The rawValue should be unchanged
            guard migrated.rawValue == englishRawValue else { return false }

            return true
        }
    }

    /// Invalid/unknown values should return nil
    /// **Validates: Requirements 8.2**
    func testProperty9_PolishProfileInvalidReturnsNil() {
        PropertyTest.verify(
            "Invalid PolishProfile value returns nil from migrate()",
            iterations: 100
        ) {
            let invalidValue = EnumMigrationTestData.randomInvalidPolishValue()

            let result = TestPolishProfile.migrate(oldValue: invalidValue)

            // Should return nil for unknown values
            guard result == nil else { return false }

            return true
        }
    }

    /// All 5 Chinese values should be covered (exhaustive check per iteration)
    /// **Validates: Requirements 8.2, 8.3**
    func testProperty9_PolishProfileAllChineseValuesCovered() {
        PropertyTest.verify(
            "All 5 old Chinese PolishProfile values migrate successfully",
            iterations: 100
        ) {
            // Each iteration verifies all 5 mappings
            for pair in EnumMigrationTestData.polishMigrationPairs {
                guard let migrated = TestPolishProfile.migrate(oldValue: pair.oldChinese) else {
                    return false
                }
                guard migrated == pair.expectedCase else { return false }
                guard migrated.rawValue == pair.expectedRawValue else { return false }
            }
            return true
        }
    }

    /// Migration is idempotent: migrating an already-migrated value returns the same result
    /// **Validates: Requirements 8.2**
    func testProperty9_PolishProfileMigrationIdempotent() {
        PropertyTest.verify(
            "PolishProfile migration is idempotent",
            iterations: 100
        ) {
            let pair = EnumMigrationTestData.randomOldPolishChinese()

            // First migration: Chinese → English
            guard let firstMigration = TestPolishProfile.migrate(oldValue: pair.oldChinese) else {
                return false
            }

            // Second migration: English → English (should pass through)
            guard let secondMigration = TestPolishProfile.migrate(oldValue: firstMigration.rawValue) else {
                return false
            }

            // Both should produce the same result
            guard firstMigration == secondMigration else { return false }
            guard firstMigration.rawValue == secondMigration.rawValue else { return false }

            return true
        }
    }

    // MARK: - Property 10: TranslateLanguage 枚举迁移完整性

    /// Feature: api-online-auth, Property 10: TranslateLanguage 枚举迁移完整性
    /// For any old Chinese rawValue ("中英互译"、"中日互译"、"自动检测"),
    /// TranslateLanguage.migrate() should return the corresponding English enum value.
    /// **Validates: Requirements 9.2**
    func testProperty10_TranslateLanguageChineseMigration() {
        PropertyTest.verify(
            "Old Chinese TranslateLanguage rawValue migrates to correct English enum value",
            iterations: 100
        ) {
            // Randomly pick one old Chinese value
            let pair = EnumMigrationTestData.randomOldTranslateChinese()

            // Migrate
            guard let migrated = TestTranslateLanguage.migrate(oldValue: pair.oldChinese) else {
                return false
            }

            // The migrated enum case should match the expected case
            guard migrated == pair.expectedCase else { return false }

            // The migrated rawValue should be the expected English string
            guard migrated.rawValue == pair.expectedRawValue else { return false }

            // The rawValue should be usable directly for API requests (non-empty, ASCII)
            guard !migrated.rawValue.isEmpty else { return false }
            guard migrated.rawValue.allSatisfy({ $0.isASCII }) else { return false }

            return true
        }
    }

    /// Already-migrated English rawValues should pass through correctly
    /// **Validates: Requirements 9.2**
    func testProperty10_TranslateLanguageEnglishPassthrough() {
        PropertyTest.verify(
            "Already-migrated English TranslateLanguage rawValue passes through correctly",
            iterations: 100
        ) {
            // Randomly pick one English rawValue
            let englishRawValue = EnumMigrationTestData.randomTranslateEnglishRawValue()

            // Migrate should return the same enum case
            guard let migrated = TestTranslateLanguage.migrate(oldValue: englishRawValue) else {
                return false
            }

            // The rawValue should be unchanged
            guard migrated.rawValue == englishRawValue else { return false }

            return true
        }
    }

    /// Invalid/unknown values should return nil
    /// **Validates: Requirements 9.2**
    func testProperty10_TranslateLanguageInvalidReturnsNil() {
        PropertyTest.verify(
            "Invalid TranslateLanguage value returns nil from migrate()",
            iterations: 100
        ) {
            let invalidValue = EnumMigrationTestData.randomInvalidTranslateValue()

            let result = TestTranslateLanguage.migrate(oldValue: invalidValue)

            // Should return nil for unknown values
            guard result == nil else { return false }

            return true
        }
    }

    /// All 3 Chinese values should be covered (exhaustive check per iteration)
    /// **Validates: Requirements 9.2**
    func testProperty10_TranslateLanguageAllChineseValuesCovered() {
        PropertyTest.verify(
            "All 3 old Chinese TranslateLanguage values migrate successfully",
            iterations: 100
        ) {
            // Each iteration verifies all 3 mappings
            for pair in EnumMigrationTestData.translateMigrationPairs {
                guard let migrated = TestTranslateLanguage.migrate(oldValue: pair.oldChinese) else {
                    return false
                }
                guard migrated == pair.expectedCase else { return false }
                guard migrated.rawValue == pair.expectedRawValue else { return false }
            }
            return true
        }
    }

    /// Migration is idempotent: migrating an already-migrated value returns the same result
    /// **Validates: Requirements 9.2**
    func testProperty10_TranslateLanguageMigrationIdempotent() {
        PropertyTest.verify(
            "TranslateLanguage migration is idempotent",
            iterations: 100
        ) {
            let pair = EnumMigrationTestData.randomOldTranslateChinese()

            // First migration: Chinese → English
            guard let firstMigration = TestTranslateLanguage.migrate(oldValue: pair.oldChinese) else {
                return false
            }

            // Second migration: English → English (should pass through)
            guard let secondMigration = TestTranslateLanguage.migrate(oldValue: firstMigration.rawValue) else {
                return false
            }

            // Both should produce the same result
            guard firstMigration == secondMigration else { return false }
            guard firstMigration.rawValue == secondMigration.rawValue else { return false }

            return true
        }
    }
}
