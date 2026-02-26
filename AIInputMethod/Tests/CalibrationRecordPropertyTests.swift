//
//  CalibrationRecordPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for CalibrationRecord JSON round-trip consistency
//  Feature: calibration-fix, Property 3: CalibrationRecord round-trip consistency
//

import XCTest
import Foundation

// MARK: - Test Copy of CalibrationRecord

/// Test copy of CalibrationRecord for property testing.
/// Mirrors the production struct exactly (no type field).
private struct TestCalibrationRecord: Codable, Equatable {
    let id: UUID
    let scenario: String
    let options: [String]
    let selectedOption: Int        // -1 表示使用了自定义答案
    let customAnswer: String?      // selectedOption == -1 时有值
    let xpEarned: Int
    let ghostResponse: String
    let profileDiff: String?
    let analysis: String?
    var consumedAtLevel: Int?
    let createdAt: Date

    /// Generate a random instance for property testing.
    static func random() -> TestCalibrationRecord {
        let id = UUID()
        let scenario = randomScenario()
        let optionCount = Int.random(in: 2...4)
        let options = (0..<optionCount).map { _ in randomOptionText() }
        let useCustomAnswer = Bool.random()

        let selectedOption: Int
        let customAnswer: String?

        if useCustomAnswer {
            selectedOption = -1
            customAnswer = randomCustomAnswer()
        } else {
            selectedOption = Int.random(in: 0..<optionCount)
            customAnswer = nil
        }

        let xpEarned = 300
        let ghostResponse = randomGhostResponse()
        let profileDiff: String? = Bool.random() ? randomProfileDiff() : nil
        let analysis: String? = Bool.random() ? "分析推理过程" : nil
        let consumedAtLevel: Int? = Bool.random() ? Int.random(in: 1...10) : nil
        let createdAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))

        return TestCalibrationRecord(
            id: id,
            scenario: scenario,
            options: options,
            selectedOption: selectedOption,
            customAnswer: customAnswer,
            xpEarned: xpEarned,
            ghostResponse: ghostResponse,
            profileDiff: profileDiff,
            analysis: analysis,
            consumedAtLevel: consumedAtLevel,
            createdAt: createdAt
        )
    }

    // MARK: - Random Generators

    private static func randomScenario() -> String {
        [
            "你的朋友发了一条明显有事实错误的朋友圈...",
            "你的同事在群里发了一个有争议的观点...",
            "老板让你周末加班但你已经有约了...",
            "A friend asks you to lie for them...",
            "",
            "包含特殊字符 <>&\"' 和 emoji 🎭 的场景",
            String(repeating: "长场景描述。", count: Int.random(in: 1...20))
        ].randomElement()!
    }

    private static func randomOptionText() -> String {
        ["私信提醒", "公开评论纠正", "假装没看到", "Say yes", "Politely decline", "选项 with emoji 👻", ""].randomElement()!
    }

    private static func randomCustomAnswer() -> String {
        ["我觉得都不对，我会直接忽略这件事", "I would handle it differently", "包含 emoji 🤔 和换行\n的自定义答案", "短答案"].randomElement()!
    }

    private static func randomGhostResponse() -> String {
        ["嘿嘿...选择私下说，果然是个体面人 👻", "哦？自己的想法，有意思 👻", "Interesting choice... 🤖", ""].randomElement()!
    }

    private static func randomProfileDiff() -> String {
        ["{\"layer\":\"spirit\",\"changes\":{\"socialStrategy\":\"注重面子\"},\"new_tags\":[\"体面\"]}", "raw diff text", ""].randomElement()!
    }
}

// MARK: - Property Tests

/// Feature: calibration-fix, Property 3: CalibrationRecord round-trip consistency
final class CalibrationRecordPropertyTests: XCTestCase {

    /// Property 3: CalibrationRecord round-trip consistency (no type field)
    /// **Validates: Requirements 2.3**
    func testProperty3_CalibrationRecordRoundTripConsistency() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        PropertyTest.verify("CalibrationRecord JSON round-trip", iterations: 100) {
            let original = TestCalibrationRecord.random()
            guard let data = try? encoder.encode(original) else { return false }
            guard let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else { return false }
            return original == decoded
        }
    }

    func testEdgeCase_CustomAnswerRecordRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationRecord(
            id: UUID(), scenario: "你的同事在群里发了一个有争议的观点...",
            options: ["立刻反驳", "私下讨论", "沉默观望"],
            selectedOption: -1, customAnswer: "我觉得都不对，我会直接忽略这件事",
            xpEarned: 300, ghostResponse: "哦？自己的想法，有意思 👻",
            profileDiff: "{\"layer\":\"method\",\"changes\":{},\"new_tags\":[\"独立思考\"]}",
            analysis: "用户选择自定义答案，体现独立思考。", consumedAtLevel: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original),
              let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
            XCTFail("Round-trip failed"); return
        }
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.selectedOption, -1)
        XCTAssertEqual(decoded.customAnswer, "我觉得都不对，我会直接忽略这件事")
    }

    func testEdgeCase_PresetOptionRecordRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationRecord(
            id: UUID(), scenario: "你的朋友发了一条明显有事实错误的朋友圈...",
            options: ["私信提醒", "公开评论纠正", "假装没看到"],
            selectedOption: 0, customAnswer: nil,
            xpEarned: 300, ghostResponse: "嘿嘿...选择私下说，果然是个体面人 👻",
            profileDiff: nil, analysis: nil, consumedAtLevel: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original),
              let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
            XCTFail("Round-trip failed"); return
        }
        XCTAssertEqual(original, decoded)
        XCTAssertNil(decoded.customAnswer)
    }

    func testEdgeCase_UnicodeRecordRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationRecord(
            id: UUID(), scenario: "包含 emoji 🎭🛡️ 和特殊字符 <>&\"'\n换行\t制表符",
            options: ["选项 with emoji 👻", "Option <special>", ""],
            selectedOption: -1, customAnswer: "自定义答案 with 日本語テスト and emoji 🤔\n多行\n答案",
            xpEarned: 300, ghostResponse: "有意思 🤖\n换行反馈",
            profileDiff: "{\"layer\":\"form\",\"changes\":{\"key\":\"值 with 特殊字符\"}}",
            analysis: "Unicode 分析 🎭", consumedAtLevel: 2,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        guard let data = try? encoder.encode(original),
              let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
            XCTFail("Round-trip failed"); return
        }
        XCTAssertEqual(original, decoded)
        XCTAssertTrue(decoded.scenario.contains("🎭"))
    }
}
