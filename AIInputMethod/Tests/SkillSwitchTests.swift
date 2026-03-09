import XCTest
import Foundation

// MARK: - SkillSwitchModel (Testable Copy)

/// Testable model that mirrors the skill switching state machine in
/// HotkeyManager + VoiceInputCoordinator. HotkeyManager is mode-agnostic:
/// it fires onSkillChanged / onHotkeyUp regardless of input mode.
private struct SkillSwitchModel {
    var currentSkill: String? = nil
    var skillChangedCallCount: Int = 0
    var lastSkillUsedForProcessing: String? = nil
    var overlaySkillUpdated: Bool = false
    var aiProcessingSkill: String? = nil

    /// Mirrors HotkeyManager.onSkillChanged → VoiceInputCoordinator callback
    /// Updates currentSkill and overlay.
    mutating func handleSkillChanged(skill: String?) {
        currentSkill = skill
        skillChangedCallCount += 1
        overlaySkillUpdated = true
    }

    /// Mirrors HotkeyManager.onHotkeyUp → VoiceInputCoordinator routing
    /// The final skill is used for AI processing (Push_To_Talk path).
    mutating func handleHotkeyUp(skill: String?) {
        let finalSkill = skill ?? currentSkill
        lastSkillUsedForProcessing = finalSkill
        aiProcessingSkill = finalSkill
    }
}

// MARK: - SkillSwitchTests

/// Unit tests for Skill switching during recording.
final class SkillSwitchTests: XCTestCase {

    // MARK: - Skill switch updates currentSkill

    func testSkillSwitch_updatesCurrentSkill() {
        var model = SkillSwitchModel()

        model.handleSkillChanged(skill: "translate")

        XCTAssertEqual(model.currentSkill, "translate",
                       "Skill switch during recording should update currentSkill")
        XCTAssertEqual(model.skillChangedCallCount, 1)
    }

    // MARK: - Multiple skill switches keep the last one

    func testMultipleSkillSwitches_keepsLastOne() {
        var model = SkillSwitchModel()

        model.handleSkillChanged(skill: "translate")
        model.handleSkillChanged(skill: "memo")
        model.handleSkillChanged(skill: "ghost-command")

        XCTAssertEqual(model.currentSkill, "ghost-command",
                       "Multiple skill switches should keep the last one")
        XCTAssertEqual(model.skillChangedCallCount, 3)
    }

    func testSkillSwitch_backToNil() {
        var model = SkillSwitchModel()

        model.handleSkillChanged(skill: "translate")
        XCTAssertEqual(model.currentSkill, "translate")

        model.handleSkillChanged(skill: nil)
        XCTAssertNil(model.currentSkill,
                     "Switching skill to nil should clear currentSkill")
    }

    // MARK: - Skill switch updates Overlay

    func testSkillSwitch_updatesOverlay() {
        var model = SkillSwitchModel()
        model.overlaySkillUpdated = false

        model.handleSkillChanged(skill: "translate")

        XCTAssertTrue(model.overlaySkillUpdated,
                      "Skill switch should update overlay skill info")
    }

    // MARK: - Final skill is used for AI processing on hotkey up

    func testHotkeyUp_usesLastSkill() {
        var model = SkillSwitchModel()

        model.handleSkillChanged(skill: "translate")
        model.handleSkillChanged(skill: "memo")

        model.handleHotkeyUp(skill: "memo")

        XCTAssertEqual(model.lastSkillUsedForProcessing, "memo",
                       "Hotkey up should use the last selected skill for AI processing")
        XCTAssertEqual(model.aiProcessingSkill, "memo",
                       "AI processing should use the final skill")
    }

    func testNoSkillSwitch_usesDefaultSkill() {
        var model = SkillSwitchModel()

        model.handleHotkeyUp(skill: nil)

        XCTAssertNil(model.lastSkillUsedForProcessing,
                     "No skill switch should result in nil (default polish) for processing")
    }
}
