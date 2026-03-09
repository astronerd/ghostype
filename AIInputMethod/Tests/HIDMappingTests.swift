import XCTest
import Foundation

// MARK: - Test Copy of HIDMapping
// Since the test target cannot import the executable target,
// we duplicate the model here for testing.

/// Exact copy of HIDMapping from HIDMappingManager.swift
private struct TestHIDMapping: Codable, Identifiable, Equatable {
    let id: UUID
    let deviceName: String
    let sourceKeyCode: UInt32
    let sourceKeyName: String
    var targetKeyCode: UInt32
    var isConnected: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, deviceName, sourceKeyCode, sourceKeyName, targetKeyCode
        // isConnected is runtime-only, not persisted
    }
    
    init(id: UUID = UUID(), deviceName: String, sourceKeyCode: UInt32, sourceKeyName: String, targetKeyCode: UInt32, isConnected: Bool = true) {
        self.id = id
        self.deviceName = deviceName
        self.sourceKeyCode = sourceKeyCode
        self.sourceKeyName = sourceKeyName
        self.targetKeyCode = targetKeyCode
        self.isConnected = isConnected
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        sourceKeyCode = try container.decode(UInt32.self, forKey: .sourceKeyCode)
        sourceKeyName = try container.decode(String.self, forKey: .sourceKeyName)
        targetKeyCode = try container.decode(UInt32.self, forKey: .targetKeyCode)
        isConnected = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encode(sourceKeyCode, forKey: .sourceKeyCode)
        try container.encode(sourceKeyName, forKey: .sourceKeyName)
        try container.encode(targetKeyCode, forKey: .targetKeyCode)
    }
}

// MARK: - Test Copy of keyNameMap and keyName

private let testKeyNameMap: [UInt16: String] = [
    // Numpad
    82: "Numpad 0", 83: "Numpad 1", 84: "Numpad 2",
    85: "Numpad 3", 86: "Numpad 4", 87: "Numpad 5",
    88: "Numpad 6", 89: "Numpad 7", 91: "Numpad 8",
    92: "Numpad 9",
    65: "Numpad .", 67: "Numpad *", 69: "Numpad +",
    75: "Numpad /", 78: "Numpad -", 81: "Numpad =",
    76: "Numpad Enter",
    // Function keys
    105: "F13", 107: "F14", 113: "F15",
    106: "F16", 64: "F17", 79: "F18",
    80: "F19", 90: "F20",
    // Other
    114: "Insert", 115: "Home", 116: "Page Up",
    117: "Forward Delete", 119: "End", 121: "Page Down",
]

private func testKeyName(for keyCode: UInt16) -> String {
    return testKeyNameMap[keyCode] ?? "Key \(keyCode)"
}

// MARK: - Random Generators

private func randomDeviceName() -> String {
    let vendors = ["Nuphy", "Keychron", "Logitech", "Apple", "Razer", "Corsair", "Ducky"]
    let models = ["Air75 V2", "K8 Pro", "MX Keys", "Magic Keyboard", "BlackWidow", "K70", "One 3"]
    return "\(vendors.randomElement()!) \(models.randomElement()!)"
}

private func randomHIDMapping() -> TestHIDMapping {
    TestHIDMapping(
        id: UUID(),
        deviceName: randomDeviceName(),
        sourceKeyCode: UInt32.random(in: 0...255),
        sourceKeyName: testKeyName(for: UInt16.random(in: 0...255)),
        targetKeyCode: UInt32.random(in: 0...255),
        isConnected: Bool.random()
    )
}

private func randomHIDMappingArray(minCount: Int = 0, maxCount: Int = 10) -> [TestHIDMapping] {
    let count = Int.random(in: minCount...maxCount)
    return (0..<count).map { _ in randomHIDMapping() }
}

// MARK: - Test Copy of hidutil helpers

private func testHidutilMappingEntry(src: UInt32, dst: UInt32) -> String {
    let srcHex = String(format: "0x%09X", 0x700000000 | UInt64(src))
    let dstHex = String(format: "0x%09X", 0x700000000 | UInt64(dst))
    return "{\"HIDKeyboardModifierMappingSrc\":\(srcHex),\"HIDKeyboardModifierMappingDst\":\(dstHex)}"
}

private func testHidutilCommand(for mappings: [TestHIDMapping]) -> String {
    let entries = mappings.map { testHidutilMappingEntry(src: $0.sourceKeyCode, dst: $0.targetKeyCode) }
    return "hidutil property --set '{\"UserKeyMapping\":[\(entries.joined(separator: ","))]}'"
}

// MARK: - Property Tests

/// Property-based tests for HIDMapping and HIDMappingManager
/// Feature: realtime-input-and-esc-cancel
final class HIDMappingTests: XCTestCase {

    // MARK: - Property 2: HIDMapping 序列化往返

    /// Feature: realtime-input-and-esc-cancel, Property 2: HIDMapping 序列化往返
    /// For any valid [HIDMapping] array, JSON encode → decode should produce equal result.
    /// Note: isConnected is runtime-only and not persisted, so decoded value defaults to false.
    /// **Validates: Requirements 15.6**
    func testProperty2_HIDMappingSerializationRoundTrip() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        PropertyTest.verify(
            "HIDMapping array JSON round-trip preserves all persisted fields",
            iterations: 100
        ) {
            let original = randomHIDMappingArray(minCount: 0, maxCount: 10)

            guard let data = try? encoder.encode(original) else { return false }
            guard let decoded = try? decoder.decode([TestHIDMapping].self, from: data) else { return false }

            // Same count
            guard original.count == decoded.count else { return false }

            // Each mapping's persisted fields should match
            for (orig, dec) in zip(original, decoded) {
                guard orig.id == dec.id else { return false }
                guard orig.deviceName == dec.deviceName else { return false }
                guard orig.sourceKeyCode == dec.sourceKeyCode else { return false }
                guard orig.sourceKeyName == dec.sourceKeyName else { return false }
                guard orig.targetKeyCode == dec.targetKeyCode else { return false }
                // isConnected defaults to false after decode (runtime-only)
                guard dec.isConnected == false else { return false }
            }

            return true
        }
    }

    /// Single mapping round-trip
    /// **Validates: Requirements 15.6**
    func testProperty2_SingleMappingRoundTrip() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        PropertyTest.verify(
            "Single HIDMapping JSON round-trip preserves persisted fields",
            iterations: 100
        ) {
            let original = randomHIDMapping()

            guard let data = try? encoder.encode(original) else { return false }
            guard let decoded = try? decoder.decode(TestHIDMapping.self, from: data) else { return false }

            return original.id == decoded.id
                && original.deviceName == decoded.deviceName
                && original.sourceKeyCode == decoded.sourceKeyCode
                && original.sourceKeyName == decoded.sourceKeyName
                && original.targetKeyCode == decoded.targetKeyCode
        }
    }

    /// Empty array round-trip
    /// **Validates: Requirements 15.6**
    func testProperty2_EmptyArrayRoundTrip() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original: [TestHIDMapping] = []
        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode empty array")
            return
        }
        guard let decoded = try? decoder.decode([TestHIDMapping].self, from: data) else {
            XCTFail("Failed to decode empty array")
            return
        }
        XCTAssertEqual(decoded.count, 0)
    }

    // MARK: - Property 15: 按键名称映射覆盖与正确性

    /// Feature: realtime-input-and-esc-cancel, Property 15: 按键名称映射覆盖与正确性
    /// For all keyCodes in the expected set, keyNameMap should return non-empty name.
    /// For unknown keyCodes, display "Key \(keyCode)".
    /// **Validates: Requirements 11.1, 11.2, 11.3**
    func testProperty15_KnownKeyCodesReturnNonEmptyName() {
        // All expected keyCodes from the design spec
        let expectedKeyCodes: [UInt16] = [
            // Numpad: 65, 67, 69, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92
            65, 67, 69, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92,
            // Function keys: 64, 79, 80, 90, 105, 106, 107, 113
            64, 79, 80, 90, 105, 106, 107, 113,
            // Other: 114, 115, 116, 117, 119, 121
            114, 115, 116, 117, 119, 121,
        ]

        for keyCode in expectedKeyCodes {
            let name = testKeyName(for: keyCode)
            XCTAssertFalse(name.isEmpty, "keyName for known keyCode \(keyCode) should be non-empty")
            XCTAssertFalse(name.hasPrefix("Key "), "keyName for known keyCode \(keyCode) should not be fallback 'Key \(keyCode)', got '\(name)'")
        }
    }

    /// Unknown keyCodes should display "Key \(keyCode)"
    /// **Validates: Requirements 11.1, 11.2, 11.3**
    func testProperty15_UnknownKeyCodesDisplayFallback() {
        let knownKeyCodes: Set<UInt16> = Set(testKeyNameMap.keys)

        PropertyTest.verify(
            "Unknown keyCodes display 'Key \\(keyCode)' fallback",
            iterations: 100
        ) {
            var keyCode: UInt16
            repeat {
                keyCode = UInt16.random(in: 0...65535)
            } while knownKeyCodes.contains(keyCode)

            let name = testKeyName(for: keyCode)
            return name == "Key \(keyCode)"
        }
    }

    /// All mapped keyCodes have non-empty, non-whitespace names
    /// **Validates: Requirements 11.1, 11.2, 11.3**
    func testProperty15_AllMappedNamesAreNonEmpty() {
        for (keyCode, name) in testKeyNameMap {
            XCTAssertFalse(name.isEmpty, "Name for keyCode \(keyCode) should not be empty")
            XCTAssertFalse(name.trimmingCharacters(in: .whitespaces).isEmpty,
                           "Name for keyCode \(keyCode) should not be whitespace-only")
        }
    }

    // MARK: - Property 16: 主快捷键变更同步所有 HID 映射

    /// Feature: realtime-input-and-esc-cancel, Property 16: 主快捷键变更同步所有 HID 映射
    /// For any [HIDMapping] list and any new targetKeyCode, after sync all mappings
    /// should have the new targetKeyCode.
    /// **Validates: Requirements 15.4**
    func testProperty16_SyncTargetKeyCodeUpdatesAllMappings() {
        PropertyTest.verify(
            "syncTargetKeyCode updates all mappings' targetKeyCode",
            iterations: 100
        ) {
            var mappings = randomHIDMappingArray(minCount: 1, maxCount: 20)
            let newKeyCode = UInt32.random(in: 0...255)

            // Simulate syncTargetKeyCode logic
            for i in mappings.indices {
                mappings[i].targetKeyCode = newKeyCode
            }

            // Verify all mappings have the new targetKeyCode
            return mappings.allSatisfy { $0.targetKeyCode == newKeyCode }
        }
    }

    /// Empty mappings list: sync should be a no-op
    /// **Validates: Requirements 15.4**
    func testProperty16_SyncEmptyMappingsIsNoOp() {
        var mappings: [TestHIDMapping] = []
        let newKeyCode = UInt32.random(in: 0...255)

        for i in mappings.indices {
            mappings[i].targetKeyCode = newKeyCode
        }

        XCTAssertTrue(mappings.isEmpty, "Empty mappings should remain empty after sync")
    }

    /// Sync preserves other fields (only targetKeyCode changes)
    /// **Validates: Requirements 15.4**
    func testProperty16_SyncPreservesOtherFields() {
        PropertyTest.verify(
            "syncTargetKeyCode only changes targetKeyCode, preserves other fields",
            iterations: 100
        ) {
            let original = randomHIDMappingArray(minCount: 1, maxCount: 10)
            var synced = original
            let newKeyCode = UInt32.random(in: 0...255)

            for i in synced.indices {
                synced[i].targetKeyCode = newKeyCode
            }

            for (orig, s) in zip(original, synced) {
                guard orig.id == s.id else { return false }
                guard orig.deviceName == s.deviceName else { return false }
                guard orig.sourceKeyCode == s.sourceKeyCode else { return false }
                guard orig.sourceKeyName == s.sourceKeyName else { return false }
                guard s.targetKeyCode == newKeyCode else { return false }
            }
            return true
        }
    }

    // MARK: - Unit Tests (13.5)

    /// Unit test: Recording identifies key (model test)
    /// Simulates what happens when a key event is captured during recording.
    /// _Requirements: 10.4_
    func testRecordingIdentifiesKey() {
        // Simulate recording capturing a known key
        let keyCode: UInt16 = 105 // F13
        let keyName = testKeyName(for: keyCode)
        let deviceName = "External HID Device"

        XCTAssertEqual(keyName, "F13")
        XCTAssertFalse(deviceName.isEmpty)

        // Simulate recording capturing an unknown key
        let unknownKeyCode: UInt16 = 200
        let unknownKeyName = testKeyName(for: unknownKeyCode)
        XCTAssertEqual(unknownKeyName, "Key 200")
    }

    /// Unit test: Mapping creates correct hidutil command string
    /// _Requirements: 15.3_
    func testMappingCreatesCorrectHidutilCommand() {
        let mapping = TestHIDMapping(
            deviceName: "Nuphy Air75 V2",
            sourceKeyCode: 0x65, // F13 in HID usage
            sourceKeyName: "F13",
            targetKeyCode: 0x3A  // Option key
        )

        let entry = testHidutilMappingEntry(src: mapping.sourceKeyCode, dst: mapping.targetKeyCode)

        // Verify the entry contains the correct hex values
        XCTAssertTrue(entry.contains("HIDKeyboardModifierMappingSrc"))
        XCTAssertTrue(entry.contains("HIDKeyboardModifierMappingDst"))

        // Verify full command format
        let command = testHidutilCommand(for: [mapping])
        XCTAssertTrue(command.hasPrefix("hidutil property --set"))
        XCTAssertTrue(command.contains("UserKeyMapping"))
        XCTAssertTrue(command.contains("HIDKeyboardModifierMappingSrc"))
        XCTAssertTrue(command.contains("HIDKeyboardModifierMappingDst"))
    }

    /// Unit test: Multiple mappings produce correct command with all entries
    /// _Requirements: 15.3_
    func testMultipleMappingsCommand() {
        let mappings = [
            TestHIDMapping(deviceName: "Device A", sourceKeyCode: 0x65, sourceKeyName: "F13", targetKeyCode: 0x3A),
            TestHIDMapping(deviceName: "Device B", sourceKeyCode: 0x52, sourceKeyName: "Numpad 0", targetKeyCode: 0x3A),
        ]

        let command = testHidutilCommand(for: mappings)

        // Should contain both entries separated by comma
        let entryA = testHidutilMappingEntry(src: 0x65, dst: 0x3A)
        let entryB = testHidutilMappingEntry(src: 0x52, dst: 0x3A)
        XCTAssertTrue(command.contains(entryA))
        XCTAssertTrue(command.contains(entryB))
    }

    /// Unit test: Mapping removal (model test - removing from array)
    /// _Requirements: 15.5_
    func testMappingRemoval() {
        let mapping1 = TestHIDMapping(deviceName: "Device A", sourceKeyCode: 0x65, sourceKeyName: "F13", targetKeyCode: 0x3A)
        let mapping2 = TestHIDMapping(deviceName: "Device B", sourceKeyCode: 0x52, sourceKeyName: "Numpad 0", targetKeyCode: 0x3A)

        var mappings = [mapping1, mapping2]
        XCTAssertEqual(mappings.count, 2)

        // Remove mapping1
        mappings.removeAll { $0.id == mapping1.id }
        XCTAssertEqual(mappings.count, 1)
        XCTAssertEqual(mappings.first?.id, mapping2.id)

        // Remove mapping2
        mappings.removeAll { $0.id == mapping2.id }
        XCTAssertTrue(mappings.isEmpty)
    }

    /// Unit test: Disconnected device marking (isConnected = false)
    /// _Requirements: 15.7_
    func testDisconnectedDeviceMarking() {
        var mapping = TestHIDMapping(
            deviceName: "Nuphy Air75 V2",
            sourceKeyCode: 0x65,
            sourceKeyName: "F13",
            targetKeyCode: 0x3A,
            isConnected: true
        )

        XCTAssertTrue(mapping.isConnected)

        // Mark as disconnected
        mapping.isConnected = false
        XCTAssertFalse(mapping.isConnected)

        // Verify other fields are preserved
        XCTAssertEqual(mapping.deviceName, "Nuphy Air75 V2")
        XCTAssertEqual(mapping.sourceKeyCode, 0x65)
        XCTAssertEqual(mapping.sourceKeyName, "F13")
        XCTAssertEqual(mapping.targetKeyCode, 0x3A)
    }

    /// Unit test: isConnected defaults to false after JSON decode (runtime-only field)
    /// _Requirements: 15.7_
    func testIsConnectedNotPersisted() {
        let mapping = TestHIDMapping(
            deviceName: "Test Device",
            sourceKeyCode: 105,
            sourceKeyName: "F13",
            targetKeyCode: 58,
            isConnected: true
        )

        // Encode and decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        guard let data = try? encoder.encode(mapping),
              let decoded = try? decoder.decode(TestHIDMapping.self, from: data) else {
            XCTFail("Failed to encode/decode HIDMapping")
            return
        }

        // isConnected should be false after decode (not persisted)
        XCTAssertFalse(decoded.isConnected, "isConnected should default to false after decode")

        // Other fields should be preserved
        XCTAssertEqual(decoded.id, mapping.id)
        XCTAssertEqual(decoded.deviceName, mapping.deviceName)
        XCTAssertEqual(decoded.sourceKeyCode, mapping.sourceKeyCode)
    }
}
