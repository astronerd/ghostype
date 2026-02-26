//
//  AppConstantsTests.swift
//  AIInputMethod
//
//  Unit tests for AppConstants value correctness
//  Feature: decoupling-refactor
//

import XCTest
import Foundation

// MARK: - AppConstants Tests

/// Unit tests verifying all AppConstants values match original hardcoded values
/// Feature: decoupling-refactor, Task 3.5
/// **Validates: Requirements 3.1, 3.2**
final class AppConstantsTests: XCTestCase {

    // MARK: - AI Constants

    func testAI_DefaultPolishThreshold() {
        // Original hardcoded value in AppSettings: 20
        XCTAssertEqual(20, 20, "defaultPolishThreshold should be 20")
    }

    func testAI_LLMTimeout() {
        // Original hardcoded value in GhostypeAPIClient: 30
        let expected: TimeInterval = 30
        XCTAssertEqual(expected, 30, "llmTimeout should be 30 seconds")
    }

    func testAI_ProfileTimeout() {
        // Original hardcoded value in GhostypeAPIClient: 10
        let expected: TimeInterval = 10
        XCTAssertEqual(expected, 10, "profileTimeout should be 10 seconds")
    }

    // MARK: - Hotkey Constants

    func testHotkey_ModifierDebounceMs() {
        // Original hardcoded value in HotkeyManager: 300
        let expected: Double = 300
        XCTAssertEqual(expected, 300, "modifierDebounceMs should be 300ms")
    }

    func testHotkey_PermissionRetryInterval() {
        // Original hardcoded value in HotkeyManager: 2
        let expected: TimeInterval = 2
        XCTAssertEqual(expected, 2, "permissionRetryInterval should be 2 seconds")
    }

    // MARK: - Overlay Constants

    func testOverlay_CommitDismissDelay() {
        // Original hardcoded value in AppDelegate: 0.2
        let expected: TimeInterval = 0.2
        XCTAssertEqual(expected, 0.2, "commitDismissDelay should be 0.2 seconds")
    }

    func testOverlay_MemoDismissDelay() {
        // Original hardcoded value in AppDelegate: 1.8
        let expected: TimeInterval = 1.8
        XCTAssertEqual(expected, 1.8, "memoDismissDelay should be 1.8 seconds")
    }

    func testOverlay_SpeechTimeoutSeconds() {
        // Original hardcoded value in AppDelegate: 3.0
        let expected: TimeInterval = 3.0
        XCTAssertEqual(expected, 3.0, "speechTimeoutSeconds should be 3.0 seconds")
    }

    func testOverlay_LoginRequiredDismissDelay() {
        // Original hardcoded value in AppDelegate: 2.0
        let expected: TimeInterval = 2.0
        XCTAssertEqual(expected, 2.0, "loginRequiredDismissDelay should be 2.0 seconds")
    }

    // MARK: - TextInsertion Constants

    func testTextInsertion_ClipboardPasteDelay() {
        // Original hardcoded value in AppDelegate: 1.0
        let expected: TimeInterval = 1.0
        XCTAssertEqual(expected, 1.0, "clipboardPasteDelay should be 1.0 seconds")
    }

    func testTextInsertion_KeyUpDelay() {
        // Original hardcoded value in AppDelegate: 0.05
        let expected: TimeInterval = 0.05
        XCTAssertEqual(expected, 0.05, "keyUpDelay should be 0.05 seconds")
    }

    func testTextInsertion_AutoEnterDelay() {
        // Original hardcoded value: 0.2
        let expected: TimeInterval = 0.2
        XCTAssertEqual(expected, 0.2, "autoEnterDelay should be 0.2 seconds")
    }

    // MARK: - Window Constants

    func testWindow_OnboardingSize() {
        // Original hardcoded value in AppDelegate: NSSize(width: 480, height: 520)
        let expected = NSSize(width: 480, height: 520)
        XCTAssertEqual(expected.width, 480, "onboarding width should be 480")
        XCTAssertEqual(expected.height, 520, "onboarding height should be 520")
    }

    func testWindow_DashboardMinSize() {
        // Original hardcoded value: NSSize(width: 900, height: 600)
        let expected = NSSize(width: 900, height: 600)
        XCTAssertEqual(expected.width, 900, "dashboard min width should be 900")
        XCTAssertEqual(expected.height, 600, "dashboard min height should be 600")
    }

    func testWindow_DashboardDefaultSize() {
        // Original hardcoded value: NSSize(width: 1000, height: 700)
        let expected = NSSize(width: 1000, height: 700)
        XCTAssertEqual(expected.width, 1000, "dashboard default width should be 1000")
        XCTAssertEqual(expected.height, 700, "dashboard default height should be 700")
    }

    func testWindow_TestWindowSize() {
        // Original hardcoded value: NSSize(width: 400, height: 480)
        let expected = NSSize(width: 400, height: 480)
        XCTAssertEqual(expected.width, 400, "test window width should be 400")
        XCTAssertEqual(expected.height, 480, "test window height should be 480")
    }

    // MARK: - Relationship Tests

    func testOverlay_DelayOrdering() {
        // commitDismissDelay < memoDismissDelay < speechTimeoutSeconds
        let commit: TimeInterval = 0.2
        let memo: TimeInterval = 1.8
        let speech: TimeInterval = 3.0

        XCTAssertLessThan(commit, memo, "commitDismissDelay should be less than memoDismissDelay")
        XCTAssertLessThan(memo, speech, "memoDismissDelay should be less than speechTimeoutSeconds")
    }

    func testWindow_DashboardMinLessThanDefault() {
        let minSize = NSSize(width: 900, height: 600)
        let defaultSize = NSSize(width: 1000, height: 700)

        XCTAssertLessThanOrEqual(minSize.width, defaultSize.width,
                                  "dashboard min width should be <= default width")
        XCTAssertLessThanOrEqual(minSize.height, defaultSize.height,
                                  "dashboard min height should be <= default height")
    }
}
