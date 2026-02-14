//
//  CalibrationRecordPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for CalibrationRecord JSON round-trip consistency
//  Feature: ghost-twin-on-device, Property 2: CalibrationRecord round-trip consistency
//

import XCTest
import Foundation

// MARK: - Test Copy of ChallengeType

/// Test copy of ChallengeType since the test target cannot import the executable target.
private enum TestChallengeType: String, Codable, CaseIterable, Equatable {
    case dilemma
    case reverseTuring = "reverse_turing"
    case prediction

    static func random() -> TestChallengeType {
        allCases.randomElement()!
    }
}

// MARK: - Test Copy of CalibrationRecord

/// Test copy of CalibrationRecord for property testing.
/// Mirrors the production struct exactly.
private struct TestCalibrationRecord: Codable, Equatable {
    let id: UUID
    let type: TestChallengeType
    let scenario: String
    let options: [String]
    let selectedOption: Int        // -1 表示使用了自定义答案
    let customAnswer: String?      // selectedOption == -1 时有值
    let xpEarned: Int
    let ghostResponse: String
    let profileDiff: String?
    let createdAt: Date

    /// Generate a random instance for property testing.
    /// When selectedOption == -1, customAnswer is non-nil.
    /// When selectedOption >= 0, customAnswer is nil.
    static func random() -> TestCalibrationRecord {
        let id = UUID()
        let type = TestChallengeType.random()
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

        let xpEarned: Int
        switch type {
        case .dilemma: xpEarned = 500
        case .reverseTuring: xpEarned = 300
        case .prediction: xpEarned = 200
        }

        let ghostResponse = randomGhostResponse()
        let profileDiff: String? = Bool.random() ? randomProfileDiff() : nil
        // Use integer seconds to avoid sub-second precision loss in ISO 8601
        let createdAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))

        return TestCalibrationRecord(
            id: id,
            type: type,
            scenario: scenario,
            options: options,
            selectedOption: selectedOption,
            customAnswer: customAnswer,
            xpEarned: xpEarned,
            ghostResponse: ghostResponse,
            profileDiff: profileDiff,
            createdAt: createdAt
        )
    }

    // MARK: - Random Generators

    private static func randomScenario() -> String {
        let scenarios = [
            "你的朋友发了一条明显有事实错误的朋友圈...",
            "你的同事在群里发了一个有争议的观点...",
            "老板让你周末加班但你已经有约了...",
            "A friend asks you to lie for them...",
            "你发现同事在背后说你坏话...",
            "",
            "包含特殊字符 <>&\"' 和 emoji 🎭 的场景",
            String(repeating: "长场景描述。", count: Int.random(in: 1...20))
        ]
        return scenarios.randomElement()!
    }

    private static func randomOptionText() -> String {
        let options = [
            "私信提醒", "公开评论纠正", "假装没看到",
            "立刻反驳", "私下讨论", "沉默观望",
            "Say yes", "Politely decline", "Ignore",
            "选项 with emoji 👻", ""
        ]
        return options.randomElement()!
    }

    private static func randomCustomAnswer() -> String {
        let answers = [
            "我觉得都不对，我会直接忽略这件事",
            "I would handle it differently by talking to them first",
            "其实我会先观察一下再决定",
            "包含 emoji 🤔 和换行\n的自定义答案",
            "短答案"
        ]
        return answers.randomElement()!
    }

    private static func randomGhostResponse() -> String {
        let responses = [
            "嘿嘿...选择私下说，果然是个体面人 👻",
            "哦？自己的想法，有意思 👻",
            "Interesting choice... 🤖",
            "有点意思，让我想想...",
            ""
        ]
        return responses.randomElement()!
    }

    private static func randomProfileDiff() -> String {
        let diffs = [
            "{\"layer\":\"spirit\",\"changes\":{\"socialStrategy\":\"注重面子\"},\"new_tags\":[\"体面\"]}",
            "{\"layer\":\"method\",\"changes\":{},\"new_tags\":[\"独立思考\"]}",
            "{\"layer\":\"form\",\"changes\":{\"verbalHabits\":[\"嗯...\"]},\"new_tags\":[]}",
            "raw diff text without json structure",
            ""
        ]
        return diffs.randomElement()!
    }
}

// MARK: - Property Tests

/// Property-based tests for CalibrationRecord JSON round-trip consistency
/// Feature: ghost-twin-on-device, Property 2: CalibrationRecord round-trip consistency
final class CalibrationRecordPropertyTests: XCTestCase {

    // MARK: - Property 2: CalibrationRecord round-trip consistency

    /// Property 2: CalibrationRecord round-trip consistency
    /// *For any* valid CalibrationRecord (with any ChallengeType, any scenario/options,
    /// selectedOption in valid range or -1 with customAnswer, valid xpEarned,
    /// any ghostResponse/profileDiff, and valid date), encoding to JSON then decoding
    /// should produce an object equal to the original.
    /// Feature: ghost-twin-on-device, Property 2: CalibrationRecord round-trip consistency
    /// **Validates: Requirements 2.4**
    func testProperty2_CalibrationRecordRoundTripConsistency() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        PropertyTest.verify(
            "CalibrationRecord JSON round-trip",
            iterations: 100
        ) {
            let original = TestCalibrationRecord.random()

            guard let data = try? encoder.encode(original) else {
                return false
            }

            guard let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
                return false
            }

            return original == decoded
        }
    }

    // MARK: - Edge Cases

    /// Edge case: Record with custom answer (selectedOption == -1)
    /// **Validates: Requirements 2.4, 13.6, 13.7**
    func testEdgeCase_CustomAnswerRecordRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationRecord(
            id: UUID(),
            type: .prediction,
            scenario: "你的同事在群里发了一个有争议的观点...",
            options: ["立刻反驳", "私下讨论", "沉默观望"],
            selectedOption: -1,
            customAnswer: "我觉得都不对，我会直接忽略这件事",
            xpEarned: 200,
            ghostResponse: "哦？自己的想法，有意思 👻",
            profileDiff: "{\"layer\":\"method\",\"changes\":{},\"new_tags\":[\"独立思考\"]}",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode custom answer record")
            return
        }

        guard let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
            XCTFail("Failed to decode custom answer record")
            return
        }

        XCTAssertEqual(original, decoded, "Custom answer record should round-trip correctly")
        XCTAssertEqual(decoded.selectedOption, -1)
        XCTAssertEqual(decoded.customAnswer, "我觉得都不对，我会直接忽略这件事")
    }

    /// Edge case: Record with preset option (customAnswer == nil)
    /// **Validates: Requirements 2.4**
    func testEdgeCase_PresetOptionRecordRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationRecord(
            id: UUID(),
            type: .dilemma,
            scenario: "你的朋友发了一条明显有事实错误的朋友圈...",
            options: ["私信提醒", "公开评论纠正", "假装没看到"],
            selectedOption: 0,
            customAnswer: nil,
            xpEarned: 500,
            ghostResponse: "嘿嘿...选择私下说，果然是个体面人 👻",
            profileDiff: "{\"layer\":\"spirit\",\"changes\":{\"socialStrategy\":\"注重面子\"},\"new_tags\":[\"体面\"]}",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode preset option record")
            return
        }

        guard let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
            XCTFail("Failed to decode preset option record")
            return
        }

        XCTAssertEqual(original, decoded, "Preset option record should round-trip correctly")
        XCTAssertEqual(decoded.selectedOption, 0)
        XCTAssertNil(decoded.customAnswer)
    }

    /// Edge case: Record with nil profileDiff
    /// **Validates: Requirements 2.4**
    func testEdgeCase_NilProfileDiffRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationRecord(
            id: UUID(),
            type: .reverseTuring,
            scenario: "找出哪个是 AI 写的",
            options: ["选项A", "选项B"],
            selectedOption: 1,
            customAnswer: nil,
            xpEarned: 300,
            ghostResponse: "不错的眼力 👻",
            profileDiff: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode nil profileDiff record")
            return
        }

        guard let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
            XCTFail("Failed to decode nil profileDiff record")
            return
        }

        XCTAssertEqual(original, decoded, "Nil profileDiff record should round-trip correctly")
        XCTAssertNil(decoded.profileDiff)
    }

    /// Edge case: Record with all ChallengeType variants
    /// **Validates: Requirements 2.4**
    func testEdgeCase_AllChallengeTypesRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for challengeType in TestChallengeType.allCases {
            let original = TestCalibrationRecord(
                id: UUID(),
                type: challengeType,
                scenario: "测试场景 for \(challengeType.rawValue)",
                options: ["A", "B", "C"],
                selectedOption: 0,
                customAnswer: nil,
                xpEarned: challengeType == .dilemma ? 500 : (challengeType == .reverseTuring ? 300 : 200),
                ghostResponse: "反馈",
                profileDiff: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )

            guard let data = try? encoder.encode(original) else {
                XCTFail("Failed to encode \(challengeType.rawValue) record")
                continue
            }

            guard let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
                XCTFail("Failed to decode \(challengeType.rawValue) record")
                continue
            }

            XCTAssertEqual(original, decoded, "\(challengeType.rawValue) record should round-trip correctly")
            XCTAssertEqual(decoded.type, challengeType)
        }
    }

    /// Edge case: Record with unicode and special characters
    /// **Validates: Requirements 2.4**
    func testEdgeCase_UnicodeRecordRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationRecord(
            id: UUID(),
            type: .dilemma,
            scenario: "包含 emoji 🎭🛡️ 和特殊字符 <>&\"'\n换行\t制表符",
            options: ["选项 with emoji 👻", "Option <special>", ""],
            selectedOption: -1,
            customAnswer: "自定义答案 with 日本語テスト and emoji 🤔\n多行\n答案",
            xpEarned: 500,
            ghostResponse: "有意思 🤖\n换行反馈",
            profileDiff: "{\"layer\":\"form\",\"changes\":{\"key\":\"值 with 特殊字符\"}}",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode unicode record")
            return
        }

        guard let decoded = try? decoder.decode(TestCalibrationRecord.self, from: data) else {
            XCTFail("Failed to decode unicode record")
            return
        }

        XCTAssertEqual(original, decoded, "Unicode record should round-trip correctly")
        XCTAssertTrue(decoded.scenario.contains("🎭"))
        XCTAssertEqual(decoded.customAnswer, original.customAnswer)
    }
}
