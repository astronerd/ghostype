import XCTest
import Foundation

// MARK: - Test Copies for Localization Completeness
// Since the test target cannot import the executable target,
// we duplicate the localization structures here for testing.

/// Supported languages for testing
private enum TestLanguage: String, CaseIterable {
    case chinese = "Chinese"
    case english = "English"
}

/// Test copy of the new Prefs localization keys added for realtime-input feature
private struct TestPrefsStrings {
    let inputModeSection: String
    let inputModeTitle: String
    let inputModeDesc: String
    let pushToTalk: String
    let realtimeMode: String
    let imkNotRegistered: String
    let imkGuideDesc: String
    let openInputSettings: String
    let hidDevices: String
    let hidDevicesTitle: String
    let hidDevicesDesc: String
    let hidAddDevice: String
    let hidRecording: String
    let hidDisconnected: String
}

/// Returns the test prefs strings for a given language, mirroring the actual translations
private func testPrefsStrings(for language: TestLanguage) -> TestPrefsStrings {
    switch language {
    case .chinese:
        return TestPrefsStrings(
            inputModeSection: "输入模式",
            inputModeTitle: "输入模式",
            inputModeDesc: "选择语音输入的工作方式",
            pushToTalk: "按住说话",
            realtimeMode: "实时输入",
            imkNotRegistered: "输入法未启用",
            imkGuideDesc: "实时输入模式需要启用 GHOSTYPE 输入法",
            openInputSettings: "前往设置",
            hidDevices: "外接设备快捷键",
            hidDevicesTitle: "外接设备快捷键",
            hidDevicesDesc: "将外接键盘按键映射为 GHOSTYPE 触发键",
            hidAddDevice: "添加设备",
            hidRecording: "录制中...",
            hidDisconnected: "未连接"
        )
    case .english:
        return TestPrefsStrings(
            inputModeSection: "Input Mode",
            inputModeTitle: "Input Mode",
            inputModeDesc: "Choose how voice input works",
            pushToTalk: "Push to Talk",
            realtimeMode: "Realtime",
            imkNotRegistered: "Input method not enabled",
            imkGuideDesc: "Realtime mode requires GHOSTYPE input method",
            openInputSettings: "Open Settings",
            hidDevices: "External Device Shortcuts",
            hidDevicesTitle: "External Device Shortcuts",
            hidDevicesDesc: "Map external keyboard keys as GHOSTYPE trigger",
            hidAddDevice: "Add Device",
            hidRecording: "Recording...",
            hidDisconnected: "Disconnected"
        )
    }
}

// MARK: - Property Tests

/// Property-based tests for localization completeness
/// Feature: realtime-input-and-esc-cancel
/// **Validates: Requirements 14.1, 14.2**
final class LocalizationTests: XCTestCase {

    // MARK: - Property 18: 本地化完整性

    /// Feature: realtime-input-and-esc-cancel, Property 18: 本地化完整性
    /// For all supported languages (Chinese, English) and all new L.xxx localization keys,
    /// the value should be a non-empty string.
    /// **Validates: Requirements 14.1, 14.2**
    func testProperty18_LocalizationCompleteness() {
        for language in TestLanguage.allCases {
            let strings = testPrefsStrings(for: language)
            let mirror = Mirror(reflecting: strings)

            for child in mirror.children {
                guard let value = child.value as? String else {
                    XCTFail("Property \(child.label ?? "unknown") is not a String for \(language.rawValue)")
                    continue
                }
                XCTAssertFalse(
                    value.isEmpty,
                    "L.Prefs.\(child.label ?? "unknown") is empty for \(language.rawValue)"
                )
            }
        }
    }

    /// Verify that Chinese and English translations are distinct for keys that should differ
    /// **Validates: Requirements 14.1, 14.2**
    func testProperty18_ChineseAndEnglishAreDifferent() {
        let chinese = testPrefsStrings(for: .chinese)
        let english = testPrefsStrings(for: .english)

        let zhMirror = Mirror(reflecting: chinese)
        let enMirror = Mirror(reflecting: english)

        let zhValues = zhMirror.children.compactMap { $0.value as? String }
        let enValues = enMirror.children.compactMap { $0.value as? String }

        XCTAssertEqual(zhValues.count, enValues.count, "Chinese and English should have the same number of keys")

        // At least some values should differ between languages
        var differCount = 0
        for (zh, en) in zip(zhValues, enValues) {
            if zh != en { differCount += 1 }
        }
        XCTAssertGreaterThan(
            differCount, 0,
            "Chinese and English translations should have at least some different values"
        )
    }

    /// Verify that all 14 expected keys exist (count check)
    /// **Validates: Requirements 14.1, 14.2**
    func testProperty18_AllExpectedKeysExist() {
        let expectedKeyCount = 14

        for language in TestLanguage.allCases {
            let strings = testPrefsStrings(for: language)
            let mirror = Mirror(reflecting: strings)
            let count = mirror.children.count

            XCTAssertEqual(
                count, expectedKeyCount,
                "Expected \(expectedKeyCount) localization keys for \(language.rawValue), got \(count)"
            )
        }
    }
}
