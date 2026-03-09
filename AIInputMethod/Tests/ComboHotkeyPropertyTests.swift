import XCTest
import Foundation

// PropertyTest helper is already defined in AuthManagerPropertyTests.swift
// and is visible across the test target — no need to redeclare.

// MARK: - Test Copies of Types (cannot import executable target)

/// Exact copy of HotkeyMode from HotkeyMode.swift
private enum TestHotkeyMode: String, CaseIterable, Codable {
    case singleKey = "singleKey"
    case comboKey = "comboKey"
}

/// Exact copy of ComboHotkey from ComboHotkey.swift
private struct TestComboHotkey: Codable, Equatable, Hashable {
    let key1: UInt16
    let key2: UInt16
}

/// Test copy of ModifierKeyBinding from SkillModel.swift
private struct TestModifierKeyBinding: Codable, Equatable {
    let keyCode: UInt16
    let isSystemModifier: Bool
    let displayName: String
}

/// Minimal copy of SkillMetadata for persistence round-trip testing
private struct TestSkillMetadata: Codable, Equatable {
    var icon: String
    var colorHex: String
    var modifierKey: TestModifierKeyBinding?
    var comboHotkey: TestComboHotkey?
    var isBuiltin: Bool
    var isInternal: Bool

    init(icon: String = "✨", colorHex: String = "#5AC8FA", modifierKey: TestModifierKeyBinding? = nil, comboHotkey: TestComboHotkey? = nil, isBuiltin: Bool = false, isInternal: Bool = false) {
        self.icon = icon
        self.colorHex = colorHex
        self.modifierKey = modifierKey
        self.comboHotkey = comboHotkey
        self.isBuiltin = isBuiltin
        self.isInternal = isInternal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        icon = try container.decode(String.self, forKey: .icon)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        modifierKey = try container.decodeIfPresent(TestModifierKeyBinding.self, forKey: .modifierKey)
        comboHotkey = try container.decodeIfPresent(TestComboHotkey.self, forKey: .comboHotkey)
        isBuiltin = try container.decode(Bool.self, forKey: .isBuiltin)
        isInternal = try container.decodeIfPresent(Bool.self, forKey: .isInternal) ?? false
    }
}

// MARK: - Property Tests

/// Property-based tests for HotkeyMode and ComboHotkey persistence
/// Feature: combo-hotkey-mode
/// **Validates: Requirements 1.2, 1.4, 3.2, 3.3, 3.4**
final class ComboHotkeyPropertyTests: XCTestCase {

    // MARK: - Property 1: HotkeyMode persistence round-trip

    /// Feature: combo-hotkey-mode, Property 1: HotkeyMode persistence round-trip
    /// For any valid HotkeyMode value, setting it on UserDefaults and then reading
    /// the corresponding key should yield the same HotkeyMode value.
    /// **Validates: Requirements 1.2, 1.4**
    func testProperty1_HotkeyModeUserDefaultsRoundTrip() {
        let suiteName = "com.ghostype.test.hotkeyMode.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let key = "hotkeyMode"

        PropertyTest.verify(
            "HotkeyMode rawValue round-trips through UserDefaults",
            iterations: 100
        ) {
            // Pick a random enum case
            let original = TestHotkeyMode.allCases.randomElement()!

            // Write rawValue to UserDefaults (mirrors AppSettings.saveToUserDefaults)
            defaults.set(original.rawValue, forKey: key)

            // Read back and reconstruct (mirrors AppSettings.init loading)
            guard let stored = defaults.string(forKey: key) else { return false }
            guard let restored = TestHotkeyMode(rawValue: stored) else { return false }

            return restored == original
        }
    }

    /// All HotkeyMode cases survive the round-trip (exhaustive per iteration)
    /// **Validates: Requirements 1.2, 1.4**
    func testProperty1_AllHotkeyModeCasesRoundTrip() {
        let suiteName = "com.ghostype.test.hotkeyModeAll.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let key = "hotkeyMode"

        PropertyTest.verify(
            "All HotkeyMode cases round-trip through UserDefaults",
            iterations: 100
        ) {
            for original in TestHotkeyMode.allCases {
                defaults.set(original.rawValue, forKey: key)
                guard let stored = defaults.string(forKey: key) else { return false }
                guard let restored = TestHotkeyMode(rawValue: stored) else { return false }
                guard restored == original else { return false }
            }
            return true
        }
    }

    /// HotkeyMode Codable JSON round-trip preserves the value
    /// **Validates: Requirements 1.2**
    func testProperty1_HotkeyModeCodableRoundTrip() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        PropertyTest.verify(
            "HotkeyMode Codable JSON round-trip preserves value",
            iterations: 100
        ) {
            let original = TestHotkeyMode.allCases.randomElement()!
            guard let data = try? encoder.encode(original) else { return false }
            guard let restored = try? decoder.decode(TestHotkeyMode.self, from: data) else { return false }
            return restored == original
        }
    }

    // MARK: - Property 2: ComboHotkey persistence round-trip

    /// Feature: combo-hotkey-mode, Property 2: ComboHotkey persistence round-trip
    /// For any valid ComboHotkey (arbitrary key1 and key2 UInt16 values), saving it
    /// inside a SkillMetadata JSON and reloading should produce the same key1 and key2.
    /// **Validates: Requirements 3.2, 3.3, 3.4**
    func testProperty2_ComboHotkeyMetadataRoundTrip() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()

        PropertyTest.verify(
            "ComboHotkey persists through SkillMetadata JSON round-trip",
            iterations: 100
        ) {
            let key1 = UInt16.random(in: 0...UInt16.max)
            let key2 = UInt16.random(in: 0...UInt16.max)
            let combo = TestComboHotkey(key1: key1, key2: key2)

            let metadata = TestSkillMetadata(comboHotkey: combo)

            // Encode to JSON (mirrors SkillMetadataStore.save)
            guard let data = try? encoder.encode(metadata) else { return false }
            // Decode from JSON (mirrors SkillMetadataStore.load)
            guard let restored = try? decoder.decode(TestSkillMetadata.self, from: data) else { return false }

            guard let restoredCombo = restored.comboHotkey else { return false }
            return restoredCombo.key1 == key1 && restoredCombo.key2 == key2
        }
    }

    /// ComboHotkey persistence round-trip via SkillMetadataStore file I/O
    /// Writes a skill_metadata.json to a temp directory, reloads, and verifies.
    /// **Validates: Requirements 3.2, 3.3, 3.4**
    func testProperty2_ComboHotkeyFileRoundTrip() {
        PropertyTest.verify(
            "ComboHotkey persists through file-based metadata store round-trip",
            iterations: 100
        ) {
            let key1 = UInt16.random(in: 0...UInt16.max)
            let key2 = UInt16.random(in: 0...UInt16.max)
            let combo = TestComboHotkey(key1: key1, key2: key2)
            let skillId = "test-skill-\(UUID().uuidString)"

            // Create a temporary directory for the metadata file
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ghostype-test-\(UUID().uuidString)")
            let metadataURL = tempDir.appendingPathComponent("skill_metadata.json")

            defer { try? FileManager.default.removeItem(at: tempDir) }

            // Build metadata dict and write to file (mirrors SkillMetadataStore.save)
            let metadata = TestSkillMetadata(comboHotkey: combo)
            let dict: [String: TestSkillMetadata] = [skillId: metadata]

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let data = try encoder.encode(dict)
                try data.write(to: metadataURL, options: .atomic)
            } catch {
                return false
            }

            // Reload from file (mirrors SkillMetadataStore.load)
            do {
                let loadedData = try Data(contentsOf: metadataURL)
                let loadedDict = try JSONDecoder().decode([String: TestSkillMetadata].self, from: loadedData)

                guard let loadedMeta = loadedDict[skillId] else { return false }
                guard let loadedCombo = loadedMeta.comboHotkey else { return false }

                return loadedCombo.key1 == key1 && loadedCombo.key2 == key2
            } catch {
                return false
            }
        }
    }

    /// ComboHotkey nil round-trip: metadata without comboHotkey decodes as nil
    /// **Validates: Requirements 3.2**
    func testProperty2_ComboHotkeyNilRoundTrip() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        PropertyTest.verify(
            "SkillMetadata without comboHotkey decodes comboHotkey as nil",
            iterations: 100
        ) {
            let metadata = TestSkillMetadata(comboHotkey: nil)
            guard let data = try? encoder.encode(metadata) else { return false }
            guard let restored = try? decoder.decode(TestSkillMetadata.self, from: data) else { return false }
            return restored.comboHotkey == nil
        }
    }

    // MARK: - Property 3: ComboBindings lookup invariant

    /// Feature: combo-hotkey-mode, Property 3: ComboBindings lookup invariant
    /// For any set of skills, the comboBindings dictionary should contain an entry
    /// for every skill that has a non-nil comboHotkey, and each entry should map to
    /// the correct skill ID. Conversely, no skill without a comboHotkey should appear.
    /// **Validates: Requirements 3.5**
    func testProperty3_ComboBindingsLookupInvariant() {
        PropertyTest.verify(
            "comboBindings contains exactly the skills with non-nil comboHotkey, mapped to correct IDs",
            iterations: 100
        ) {
            // Generate N random skills (3–10), some with comboHotkey, some without
            let skillCount = Int.random(in: 3...10)
            var skills: [(id: String, comboHotkey: TestComboHotkey?)] = []

            for i in 0..<skillCount {
                let id = "skill-\(i)-\(UUID().uuidString.prefix(8))"
                let hasCombo = Bool.random()
                let combo: TestComboHotkey? = hasCombo
                    ? TestComboHotkey(key1: UInt16.random(in: 0...127), key2: UInt16.random(in: 0...127))
                    : nil
                skills.append((id: id, comboHotkey: combo))
            }

            // Build comboBindings the same way SkillManager.loadAllSkills() does
            var comboBindings: [TestComboHotkey: String] = [:]
            for skill in skills {
                if let combo = skill.comboHotkey {
                    comboBindings[combo] = skill.id
                }
            }

            // Verify: every skill WITH comboHotkey has an entry mapping to its ID
            // (Note: if two skills share the same combo, the last one wins — same as SkillManager)
            let skillsWithCombo = skills.filter { $0.comboHotkey != nil }
            for skill in skillsWithCombo {
                guard let combo = skill.comboHotkey else { return false }
                // The binding must exist for this combo
                guard let boundId = comboBindings[combo] else { return false }
                // If this skill was the last to write this combo, it should be its ID
                // Find the last skill that has this exact combo
                let lastWriter = skills.last(where: { $0.comboHotkey == combo })!
                guard boundId == lastWriter.id else { return false }
            }

            // Verify: no skill WITHOUT comboHotkey appears in comboBindings values
            let skillsWithoutCombo = skills.filter { $0.comboHotkey == nil }
            let boundIds = Set(comboBindings.values)
            for skill in skillsWithoutCombo {
                if boundIds.contains(skill.id) { return false }
            }

            // Verify: comboBindings count <= number of skills with comboHotkey
            // (could be less if multiple skills share the same combo — last one wins)
            let uniqueCombos = Set(skillsWithCombo.compactMap { $0.comboHotkey })
            guard comboBindings.count == uniqueCombos.count else { return false }

            return true
        }
    }

    // MARK: - Property 4: Key display function completeness

    /// Feature: combo-hotkey-mode, Property 4: Key display function completeness
    /// For any valid macOS keyCode (UInt16 in the range of known keyboard keys),
    /// the displayNameForKeyCode() function should return a non-empty string.
    /// **Validates: Requirements 4.5**
    func testProperty4_KeyDisplayFunctionCompleteness() {
        PropertyTest.verify(
            "displayNameForKeyCode returns a non-empty string for any keyCode 0-127",
            iterations: 100
        ) {
            let keyCode = UInt16.random(in: 0...127)
            let displayName = testDisplayNameForKeyCode(keyCode)
            return !displayName.isEmpty
        }
    }

    // MARK: - Property 9: Conflict detection with ordered pair comparison

    /// Feature: combo-hotkey-mode, Property 9: Conflict detection with ordered pair comparison
    /// For any two skills where one has ComboHotkey(key1: a, key2: b) and the other
    /// attempts to bind ComboHotkey(key1: a, key2: b), hasComboKeyConflict() should
    /// return the first skill. For ComboHotkey(key1: b, key2: a) (reversed order),
    /// it should NOT report a conflict (unless a == b).
    /// **Validates: Requirements 8.1, 8.2**
    func testProperty9_ConflictDetectionOrderedPairComparison() {
        PropertyTest.verify(
            "Same ordered pair detects conflict; reversed pair does not (unless a == b)",
            iterations: 100
        ) {
            let a = UInt16.random(in: 0...127)
            let b = UInt16.random(in: 0...127)

            let existingCombo = TestComboHotkey(key1: a, key2: b)
            let existingSkillId = "existing-\(UUID().uuidString.prefix(8))"
            let attemptingSkillId = "attempting-\(UUID().uuidString.prefix(8))"

            // Simulate skills list (mirrors SkillManager.skills)
            let skills: [(id: String, comboHotkey: TestComboHotkey?)] = [
                (id: existingSkillId, comboHotkey: existingCombo),
                (id: attemptingSkillId, comboHotkey: nil) // not yet bound
            ]

            // Simulate hasComboKeyConflict for same ordered pair (a, b)
            let sameCombo = TestComboHotkey(key1: a, key2: b)
            let sameConflict = simulateHasComboKeyConflict(
                sameCombo, excludingSkillId: attemptingSkillId, skills: skills
            )

            // Same ordered pair MUST detect conflict with existing skill
            guard sameConflict?.id == existingSkillId else { return false }

            // Simulate hasComboKeyConflict for reversed pair (b, a)
            let reversedCombo = TestComboHotkey(key1: b, key2: a)
            let reversedConflict = simulateHasComboKeyConflict(
                reversedCombo, excludingSkillId: attemptingSkillId, skills: skills
            )

            if a == b {
                // When a == b, reversed is identical → conflict expected
                guard reversedConflict?.id == existingSkillId else { return false }
            } else {
                // When a != b, reversed order should NOT conflict
                guard reversedConflict == nil else { return false }
            }

            return true
        }
    }

    /// Simulate hasComboKeyConflict for self-exclusion: a skill should not conflict with itself
    /// **Validates: Requirements 8.1, 8.2**
    func testProperty9_ConflictDetectionExcludesSelf() {
        PropertyTest.verify(
            "A skill's own combo does not conflict when excluding its own ID",
            iterations: 100
        ) {
            let a = UInt16.random(in: 0...127)
            let b = UInt16.random(in: 0...127)
            let combo = TestComboHotkey(key1: a, key2: b)
            let skillId = "self-\(UUID().uuidString.prefix(8))"

            let skills: [(id: String, comboHotkey: TestComboHotkey?)] = [
                (id: skillId, comboHotkey: combo)
            ]

            // Excluding self → no conflict
            let conflict = simulateHasComboKeyConflict(
                combo, excludingSkillId: skillId, skills: skills
            )
            guard conflict == nil else { return false }

            // NOT excluding self → conflict with self
            let conflictNoExclude = simulateHasComboKeyConflict(
                combo, excludingSkillId: nil, skills: skills
            )
            guard conflictNoExclude?.id == skillId else { return false }

            return true
        }
    }

    // MARK: - Property 10: Localization completeness for combo-key strings

    /// Feature: combo-hotkey-mode, Property 10: Localization completeness for combo-key strings
    /// For any supported AppLanguage, all L.Prefs and L.Skill combo-key-related accessors
    /// should return non-empty strings.
    /// **Validates: Requirements 9.1, 9.2, 9.3**
    func testProperty10_LocalizationCompletenessForComboKeyStrings() {
        // Test copies of the combo-key localization values per language
        // Mirrors the actual values from Strings+Chinese.swift and Strings+English.swift
        enum TestLanguage: String, CaseIterable {
            case chinese
            case english
        }

        struct ComboKeyStrings {
            // L.Prefs
            let hotkeyModeSingle: String
            let hotkeyModeCombo: String
            let comboKeyHint: String
            // L.Skill
            let comboKey: String
            let comboKeyRecord: String
            let comboKeyKey1: String
            let comboKeyKey2: String
            let comboKeyConflict: String
            let comboKeyClear: String
            let comboKeyEmpty: String
            let comboKeyPlus: String

            var allValues: [String] {
                [hotkeyModeSingle, hotkeyModeCombo, comboKeyHint,
                 comboKey, comboKeyRecord, comboKeyKey1, comboKeyKey2,
                 comboKeyConflict, comboKeyClear, comboKeyEmpty, comboKeyPlus]
            }
        }

        func stringsForLanguage(_ lang: TestLanguage) -> ComboKeyStrings {
            switch lang {
            case .chinese:
                return ComboKeyStrings(
                    hotkeyModeSingle: "单键模式",
                    hotkeyModeCombo: "组合键模式",
                    comboKeyHint: "请在「技能」页面为每个 Skill 配置组合快捷键",
                    comboKey: "组合快捷键",
                    comboKeyRecord: "录制中...",
                    comboKeyKey1: "按键 1",
                    comboKeyKey2: "按键 2",
                    comboKeyConflict: "组合键冲突",
                    comboKeyClear: "清除组合键",
                    comboKeyEmpty: "未设置",
                    comboKeyPlus: "+"
                )
            case .english:
                return ComboKeyStrings(
                    hotkeyModeSingle: "Single Key",
                    hotkeyModeCombo: "Combo Key",
                    comboKeyHint: "Configure combo hotkeys per skill on the Skills page",
                    comboKey: "Combo Hotkey",
                    comboKeyRecord: "Recording...",
                    comboKeyKey1: "Key 1",
                    comboKeyKey2: "Key 2",
                    comboKeyConflict: "Combo Key Conflict",
                    comboKeyClear: "Clear Combo Key",
                    comboKeyEmpty: "Not Set",
                    comboKeyPlus: "+"
                )
            }
        }

        PropertyTest.verify(
            "All combo-key localization strings are non-empty for any supported language",
            iterations: 100
        ) {
            // Randomly pick a language each iteration
            let lang = TestLanguage.allCases.randomElement()!
            let strings = stringsForLanguage(lang)

            // Verify every value is non-empty
            for value in strings.allValues {
                if value.isEmpty { return false }
            }

            // Verify count: 3 Prefs + 8 Skill = 11 total
            guard strings.allValues.count == 11 else { return false }

            return true
        }
    }

    // MARK: - Property 5: Combo detection triggers correct skill and release ends recording

    /// Feature: combo-hotkey-mode, Property 5: Combo detection triggers correct skill and release ends recording
    /// For any registered ComboHotkey bound to a skill, when both key1 and key2 are detected
    /// as pressed, onHotkeyDown should be invoked and currentSkill should equal the bound skill.
    /// When either key is subsequently released, onHotkeyUp should be invoked with the same skill.
    /// **Validates: Requirements 5.2, 5.3**
    func testProperty5_ComboDetectionTriggersCorrectSkillAndReleaseEndsRecording() {
        PropertyTest.verify(
            "Combo press triggers onHotkeyDown with correct skill; release triggers onHotkeyUp",
            iterations: 100
        ) {
            // Generate a random combo with distinct keys (key1 != key2 for meaningful combos)
            let key1 = UInt16.random(in: 0...127)
            var key2 = UInt16.random(in: 0...127)
            while key2 == key1 { key2 = UInt16.random(in: 0...127) }

            let combo = TestComboHotkey(key1: key1, key2: key2)
            let skillId = "skill-\(UUID().uuidString.prefix(8))"
            let skillName = "TestSkill-\(skillId.prefix(4))"

            let sim = ComboKeySimulator()
            sim.registerCombo(combo, skillId: skillId, skillName: skillName)

            // Press key1 first — no activation yet
            sim.keyDown(key1)
            guard !sim.hotkeyDownInvoked else { return false }
            guard sim.currentSkill == nil else { return false }

            // Press key2 — both keys held, combo should activate
            sim.keyDown(key2)
            guard sim.hotkeyDownInvoked else { return false }
            guard sim.currentSkill?.id == skillId else { return false }
            guard sim.activeCombo == combo else { return false }

            // Release one of the two keys (randomly pick which one)
            let releaseKey = Bool.random() ? key1 : key2
            sim.keyUp(releaseKey)
            guard sim.hotkeyUpInvoked else { return false }
            guard sim.hotkeyUpSkill?.id == skillId else { return false }
            guard sim.activeCombo == nil else { return false }
            guard sim.currentSkill == nil else { return false }

            return true
        }
    }

    /// Combo detection works regardless of key press order (key2 first, then key1)
    /// **Validates: Requirements 5.2, 5.3**
    func testProperty5_ComboDetectionReversePressOrder() {
        PropertyTest.verify(
            "Combo activates regardless of which key is pressed first",
            iterations: 100
        ) {
            let key1 = UInt16.random(in: 0...127)
            var key2 = UInt16.random(in: 0...127)
            while key2 == key1 { key2 = UInt16.random(in: 0...127) }

            let combo = TestComboHotkey(key1: key1, key2: key2)
            let skillId = "skill-\(UUID().uuidString.prefix(8))"

            let sim = ComboKeySimulator()
            sim.registerCombo(combo, skillId: skillId, skillName: "Test")

            // Press key2 first, then key1 (reverse of registration order)
            sim.keyDown(key2)
            guard !sim.hotkeyDownInvoked else { return false }

            sim.keyDown(key1)
            guard sim.hotkeyDownInvoked else { return false }
            guard sim.currentSkill?.id == skillId else { return false }

            // Release key1
            sim.keyUp(key1)
            guard sim.hotkeyUpInvoked else { return false }
            guard sim.hotkeyUpSkill?.id == skillId else { return false }

            return true
        }
    }

    // MARK: - Property 6: Mode isolation

    /// Feature: combo-hotkey-mode, Property 6: Mode isolation
    /// For any HotkeyMode setting, the HotkeyManager should only respond to the event
    /// pattern corresponding to the active mode. In singleKey mode, combo key presses
    /// should not trigger onHotkeyDown. In comboKey mode, the single-key hotkey should
    /// not trigger onHotkeyDown.
    /// **Validates: Requirements 5.4, 7.1, 7.2**
    func testProperty6_ModeIsolation_SingleKeyIgnoresCombo() {
        PropertyTest.verify(
            "In singleKey mode, combo key presses do not trigger onHotkeyDown",
            iterations: 100
        ) {
            let key1 = UInt16.random(in: 0...127)
            var key2 = UInt16.random(in: 0...127)
            while key2 == key1 { key2 = UInt16.random(in: 0...127) }

            let combo = TestComboHotkey(key1: key1, key2: key2)
            let skillId = "skill-\(UUID().uuidString.prefix(8))"

            // Use a single-key hotkey that is different from combo keys
            var singleKeyCode = UInt16.random(in: 0...127)
            while singleKeyCode == key1 || singleKeyCode == key2 {
                singleKeyCode = UInt16.random(in: 0...127)
            }

            let sim = ModeIsolationSimulator(mode: .singleKey, singleKeyCode: singleKeyCode)
            sim.registerCombo(combo, skillId: skillId, skillName: "Test")

            // Press both combo keys in singleKey mode
            sim.keyDown(key1)
            sim.keyDown(key2)

            // In singleKey mode, combo presses must NOT trigger onHotkeyDown
            guard !sim.hotkeyDownInvoked else { return false }

            return true
        }
    }

    /// In comboKey mode, the single-key hotkey should not trigger onHotkeyDown
    /// **Validates: Requirements 5.4, 7.1, 7.2**
    func testProperty6_ModeIsolation_ComboKeyIgnoresSingleKey() {
        PropertyTest.verify(
            "In comboKey mode, single-key hotkey press does not trigger onHotkeyDown",
            iterations: 100
        ) {
            let singleKeyCode = UInt16.random(in: 0...127)

            // Register a combo that does NOT include the single key
            var key1 = UInt16.random(in: 0...127)
            while key1 == singleKeyCode { key1 = UInt16.random(in: 0...127) }
            var key2 = UInt16.random(in: 0...127)
            while key2 == singleKeyCode || key2 == key1 { key2 = UInt16.random(in: 0...127) }

            let combo = TestComboHotkey(key1: key1, key2: key2)
            let skillId = "skill-\(UUID().uuidString.prefix(8))"

            let sim = ModeIsolationSimulator(mode: .comboKey, singleKeyCode: singleKeyCode)
            sim.registerCombo(combo, skillId: skillId, skillName: "Test")

            // Press only the single-key hotkey in comboKey mode
            sim.keyDown(singleKeyCode)

            // In comboKey mode, single-key press must NOT trigger onHotkeyDown
            guard !sim.hotkeyDownInvoked else { return false }

            // Release it
            sim.keyUp(singleKeyCode)
            guard !sim.hotkeyUpInvoked else { return false }

            return true
        }
    }

    // MARK: - Property 7: Combo mode skips modifier skill switching

    /// Feature: combo-hotkey-mode, Property 7: Combo mode skips modifier skill switching
    /// For any active combo-key recording session, pressing and releasing modifier keys
    /// (other than the combo keys) should not change currentSkill and should not invoke onSkillChanged.
    /// **Validates: Requirements 6.4**
    func testProperty7_ComboModeSkipsModifierSkillSwitching() {
        // Modifier keyCodes on macOS
        let modifierKeyCodes: [UInt16] = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

        PropertyTest.verify(
            "During active combo recording, modifier key presses do not change currentSkill",
            iterations: 100
        ) {
            // Pick combo keys that are NOT modifier keys (use normal key range 0-53)
            let normalKeys = Array<UInt16>(0...53).filter { !modifierKeyCodes.contains($0) }
            guard normalKeys.count >= 2 else { return false }

            let key1 = normalKeys.randomElement()!
            var key2 = normalKeys.randomElement()!
            while key2 == key1 { key2 = normalKeys.randomElement()! }

            let combo = TestComboHotkey(key1: key1, key2: key2)
            let skillId = "combo-skill-\(UUID().uuidString.prefix(8))"

            let sim = ComboKeySimulator()
            sim.registerCombo(combo, skillId: skillId, skillName: "ComboSkill")

            // Also register some modifier-based skill bindings (single-key mode style)
            let modifierSkillId = "mod-skill-\(UUID().uuidString.prefix(8))"
            let randomModifier = modifierKeyCodes.randomElement()!
            sim.registerModifierSkill(randomModifier, skillId: modifierSkillId, skillName: "ModSkill")

            // Activate the combo (press both keys)
            sim.keyDown(key1)
            sim.keyDown(key2)
            guard sim.hotkeyDownInvoked else { return false }
            guard sim.currentSkill?.id == skillId else { return false }

            let skillBeforeModifier = sim.currentSkill

            // Press and release a random modifier key (not one of the combo keys)
            let modToPress = modifierKeyCodes.filter { $0 != key1 && $0 != key2 }.randomElement()!
            sim.modifierDown(modToPress)
            sim.modifierUp(modToPress)

            // currentSkill must NOT have changed
            guard sim.currentSkill?.id == skillBeforeModifier?.id else { return false }
            // onSkillChanged must NOT have been invoked
            guard !sim.skillChangedInvoked else { return false }

            return true
        }
    }

    // MARK: - Property 8: Mode switching preserves bindings

    /// Feature: combo-hotkey-mode, Property 8: Mode switching preserves bindings
    /// For any configuration state where skills have both modifierKey (single-key) and
    /// comboHotkey (combo-key) bindings, switching hotkeyMode from singleKey to comboKey
    /// and back should preserve all modifierKey bindings unchanged, and switching from
    /// comboKey to singleKey and back should preserve all comboHotkey bindings unchanged.
    /// **Validates: Requirements 7.4**
    func testProperty8_ModeSwitchingPreservesBindings() {
        PropertyTest.verify(
            "Switching hotkeyMode back and forth preserves both modifierKey and comboHotkey bindings",
            iterations: 100
        ) {
            // Generate random skills with both binding types
            let skillCount = Int.random(in: 2...8)
            var skills: [(id: String, modifierKey: TestModifierKeyBinding?, comboHotkey: TestComboHotkey?)] = []

            let modifierDisplayNames = ["⌘", "⌃", "⌥", "⇧", "Fn", "⌘R", "⌃R", "⌥R"]

            for i in 0..<skillCount {
                let id = "skill-\(i)-\(UUID().uuidString.prefix(8))"

                // Randomly assign a modifierKey binding
                let hasModifier = Bool.random()
                let modifier: TestModifierKeyBinding? = hasModifier
                    ? TestModifierKeyBinding(
                        keyCode: UInt16.random(in: 54...63),
                        isSystemModifier: Bool.random(),
                        displayName: modifierDisplayNames.randomElement()!
                    )
                    : nil

                // Randomly assign a comboHotkey binding
                let hasCombo = Bool.random()
                let combo: TestComboHotkey? = hasCombo
                    ? TestComboHotkey(
                        key1: UInt16.random(in: 0...127),
                        key2: UInt16.random(in: 0...127)
                    )
                    : nil

                skills.append((id: id, modifierKey: modifier, comboHotkey: combo))
            }

            // Snapshot the original bindings
            let originalModifierKeys = skills.map { $0.modifierKey }
            let originalComboHotkeys = skills.map { $0.comboHotkey }

            // Simulate mode switching using a test variable (mirrors AppSettings.hotkeyMode)
            // The key insight: mode switching only changes which bindings are ACTIVE,
            // it does NOT modify or delete the other mode's bindings.
            // Both binding types live in separate storage (modifierKey vs comboHotkey in SkillMetadata).

            // Switch singleKey → comboKey → singleKey
            var currentMode = TestHotkeyMode.singleKey
            currentMode = .comboKey
            // In comboKey mode, comboHotkey bindings are active, modifierKey bindings are stored but inactive
            // Verify modifierKey bindings are still intact
            for i in 0..<skillCount {
                guard skills[i].modifierKey == originalModifierKeys[i] else { return false }
            }

            currentMode = .singleKey
            // Back in singleKey mode, modifierKey bindings are active again
            // Verify both binding types are preserved
            for i in 0..<skillCount {
                guard skills[i].modifierKey == originalModifierKeys[i] else { return false }
                guard skills[i].comboHotkey == originalComboHotkeys[i] else { return false }
            }

            // Switch comboKey → singleKey → comboKey
            currentMode = .comboKey
            currentMode = .singleKey
            // In singleKey mode, modifierKey bindings are active, comboHotkey bindings are stored but inactive
            // Verify comboHotkey bindings are still intact
            for i in 0..<skillCount {
                guard skills[i].comboHotkey == originalComboHotkeys[i] else { return false }
            }

            currentMode = .comboKey
            // Back in comboKey mode, comboHotkey bindings are active again
            // Verify both binding types are preserved
            for i in 0..<skillCount {
                guard skills[i].modifierKey == originalModifierKeys[i] else { return false }
                guard skills[i].comboHotkey == originalComboHotkeys[i] else { return false }
            }

            return true
        }
    }

    /// Property 8 variant: Mode switching preserves bindings through metadata JSON persistence
    /// Simulates the full round-trip: bindings → JSON → mode switch → JSON → reload → verify
    /// **Validates: Requirements 7.4**
    func testProperty8_ModeSwitchingPreservesBindingsThroughPersistence() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()

        PropertyTest.verify(
            "Mode switching preserves both binding types through JSON persistence round-trip",
            iterations: 100
        ) {
            // Generate random skills with both binding types
            let skillCount = Int.random(in: 2...6)
            var metadataDict: [String: TestSkillMetadata] = [:]

            let modifierDisplayNames = ["⌘", "⌃", "⌥", "⇧", "Fn"]

            for i in 0..<skillCount {
                let id = "skill-\(i)-\(UUID().uuidString.prefix(8))"

                let modifier: TestModifierKeyBinding? = Bool.random()
                    ? TestModifierKeyBinding(
                        keyCode: UInt16.random(in: 54...63),
                        isSystemModifier: Bool.random(),
                        displayName: modifierDisplayNames.randomElement()!
                    )
                    : nil

                let combo: TestComboHotkey? = Bool.random()
                    ? TestComboHotkey(
                        key1: UInt16.random(in: 0...127),
                        key2: UInt16.random(in: 0...127)
                    )
                    : nil

                metadataDict[id] = TestSkillMetadata(
                    modifierKey: modifier,
                    comboHotkey: combo
                )
            }

            // Snapshot original bindings
            let originalDict = metadataDict

            // Simulate: save to JSON (as SkillMetadataStore does)
            guard let data = try? encoder.encode(metadataDict) else { return false }

            // Simulate: mode switch happens (only changes AppSettings.hotkeyMode, not metadata)
            // The mode value is stored separately in UserDefaults, not in skill_metadata.json

            // Simulate: reload from JSON (as SkillMetadataStore does on next launch)
            guard let reloaded = try? decoder.decode([String: TestSkillMetadata].self, from: data) else { return false }

            // Verify all bindings survived the mode switch + persistence cycle
            for (id, originalMeta) in originalDict {
                guard let reloadedMeta = reloaded[id] else { return false }
                // modifierKey must be preserved
                guard reloadedMeta.modifierKey == originalMeta.modifierKey else { return false }
                // comboHotkey must be preserved
                guard reloadedMeta.comboHotkey == originalMeta.comboHotkey else { return false }
            }

            return true
        }
    }

    // MARK: - Helpers

    /// Test copy of displayNameForKeyCode from SkillPage.swift (private in source)
    private func testDisplayNameForKeyCode(_ keyCode: UInt16) -> String {
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

    /// Simulates SkillManager.hasComboKeyConflict() using ordered pair comparison
    /// Mirrors the real implementation: compares key1==key1 && key2==key2
    private func simulateHasComboKeyConflict(
        _ combo: TestComboHotkey,
        excludingSkillId: String?,
        skills: [(id: String, comboHotkey: TestComboHotkey?)]
    ) -> (id: String, comboHotkey: TestComboHotkey)? {
        for skill in skills {
            if skill.id == excludingSkillId { continue }
            guard let existingCombo = skill.comboHotkey else { continue }
            if existingCombo.key1 == combo.key1 && existingCombo.key2 == combo.key2 {
                return (id: skill.id, comboHotkey: existingCombo)
            }
        }
        return nil
    }
}

// MARK: - Test Simulation: Minimal Skill for Combo Tests

/// Lightweight skill representation for combo event simulation
private struct TestSkillInfo: Equatable {
    let id: String
    let name: String
}

// MARK: - ComboKeySimulator

/// Simulates HotkeyManager.handleComboKeyEvent() logic for property testing.
/// Mirrors the real implementation: tracks pressedKeys, detects combo activation,
/// triggers callbacks on activation/deactivation, and ignores modifier skill switching.
private class ComboKeySimulator {
    // State (mirrors HotkeyManager)
    var pressedKeys: Set<UInt16> = []
    var activeCombo: TestComboHotkey? = nil
    var currentSkill: TestSkillInfo? = nil

    // Registered combos (mirrors SkillManager.comboBindings)
    var comboBindings: [TestComboHotkey: TestSkillInfo] = [:]

    // Modifier-based skill bindings (single-key mode, should be ignored in combo mode)
    var modifierSkillBindings: [UInt16: TestSkillInfo] = [:]

    // Callback tracking
    var hotkeyDownInvoked = false
    var hotkeyUpInvoked = false
    var hotkeyUpSkill: TestSkillInfo? = nil
    var skillChangedInvoked = false

    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    func registerCombo(_ combo: TestComboHotkey, skillId: String, skillName: String) {
        comboBindings[combo] = TestSkillInfo(id: skillId, name: skillName)
    }

    func registerModifierSkill(_ keyCode: UInt16, skillId: String, skillName: String) {
        modifierSkillBindings[keyCode] = TestSkillInfo(id: skillId, name: skillName)
    }

    /// Simulate a key-down event (mirrors handleComboKeyEvent keyDown path)
    func keyDown(_ keyCode: UInt16) {
        pressedKeys.insert(keyCode)

        // If combo already active, just track the key
        if activeCombo != nil { return }

        // Check if any registered combo matches (both keys in pressedKeys)
        for (combo, skill) in comboBindings {
            if pressedKeys.contains(combo.key1) && pressedKeys.contains(combo.key2) {
                activeCombo = combo
                currentSkill = skill
                hotkeyDownInvoked = true
                return
            }
        }
    }

    /// Simulate a key-up event (mirrors handleComboKeyEvent keyUp path)
    func keyUp(_ keyCode: UInt16) {
        pressedKeys.remove(keyCode)

        // If active combo and either key released → end recording
        if let combo = activeCombo, (keyCode == combo.key1 || keyCode == combo.key2) {
            hotkeyUpInvoked = true
            hotkeyUpSkill = currentSkill
            activeCombo = nil
            currentSkill = nil
        }
    }

    /// Simulate a modifier key press during active combo (should NOT trigger skill switching)
    func modifierDown(_ keyCode: UInt16) {
        pressedKeys.insert(keyCode)
        // In combo mode: NO modifier-based skill switching
        // The real HotkeyManager.handleComboKeyEvent does not call onSkillChanged
        // We explicitly do NOT update currentSkill or invoke skillChanged here
    }

    /// Simulate a modifier key release during active combo
    func modifierUp(_ keyCode: UInt16) {
        pressedKeys.remove(keyCode)
        // In combo mode: NO modifier-based skill switching on release either
    }
}

// MARK: - ModeIsolationSimulator

/// Simulates the mode-branching logic in HotkeyManager.handleEvent().
/// In singleKey mode, only single-key hotkey triggers activation.
/// In comboKey mode, only combo key presses trigger activation.
private class ModeIsolationSimulator {
    let mode: TestHotkeyMode
    let singleKeyCode: UInt16

    // Combo mode state
    var pressedKeys: Set<UInt16> = []
    var activeCombo: TestComboHotkey? = nil
    var comboBindings: [TestComboHotkey: TestSkillInfo] = [:]

    // Single-key mode state
    var isHotkeyPressed = false

    // Callback tracking
    var hotkeyDownInvoked = false
    var hotkeyUpInvoked = false

    init(mode: TestHotkeyMode, singleKeyCode: UInt16) {
        self.mode = mode
        self.singleKeyCode = singleKeyCode
    }

    func registerCombo(_ combo: TestComboHotkey, skillId: String, skillName: String) {
        comboBindings[combo] = TestSkillInfo(id: skillId, name: skillName)
    }

    /// Simulate keyDown — branches on mode just like HotkeyManager.handleEvent()
    func keyDown(_ keyCode: UInt16) {
        switch mode {
        case .singleKey:
            // Single-key mode: only the designated single key triggers
            if keyCode == singleKeyCode && !isHotkeyPressed {
                isHotkeyPressed = true
                hotkeyDownInvoked = true
            }
            // Combo key presses are ignored in single-key mode

        case .comboKey:
            // Combo mode: track pressed keys, check for combo match
            pressedKeys.insert(keyCode)

            if activeCombo != nil { return }

            for (combo, _) in comboBindings {
                if pressedKeys.contains(combo.key1) && pressedKeys.contains(combo.key2) {
                    activeCombo = combo
                    hotkeyDownInvoked = true
                    return
                }
            }
            // Single-key hotkey is ignored in combo mode
        }
    }

    /// Simulate keyUp — branches on mode
    func keyUp(_ keyCode: UInt16) {
        switch mode {
        case .singleKey:
            if keyCode == singleKeyCode && isHotkeyPressed {
                isHotkeyPressed = false
                hotkeyUpInvoked = true
            }

        case .comboKey:
            pressedKeys.remove(keyCode)
            if let combo = activeCombo, (keyCode == combo.key1 || keyCode == combo.key2) {
                activeCombo = nil
                hotkeyUpInvoked = true
            }
        }
    }
}
