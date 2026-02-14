//
//  FlowStatePropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for flow state JSON round-trip consistency
//  Feature: ghost-twin-on-device, Property 13: Flow state round-trip consistency
//

import XCTest
import Foundation

// Uses shared PropertyTest from AuthManagerPropertyTests.swift

// MARK: - Test Copies of Models

/// Test copy of ChallengeType (cannot import executable target)
private enum TestChallengeType: String, Codable, Equatable, CaseIterable {
    case dilemma
    case reverseTuring = "reverse_turing"
    case prediction

    static func random() -> TestChallengeType {
        allCases.randomElement()!
    }
}

/// Test copy of LocalCalibrationChallenge
private struct TestLocalCalibrationChallenge: Codable, Equatable {
    let type: TestChallengeType
    let scenario: String
    let options: [String]
    let targetField: String

    static func random() -> TestLocalCalibrationChallenge {
        let scenarios = [
            "你的朋友发了一条明显有事实错误的朋友圈...",
            "同事在群里发了一个有争议的观点...",
            "老板让你加班但你已经有约了...",
            "A random scenario with special chars <>&\"'",
            "包含 emoji 🎭 的场景描述",
            ""
        ]
        let targetFields = ["form", "spirit", "method"]
        let optionCount = Int.random(in: 2...5)
        let options = (0..<optionCount).map { "选项\($0): \(PropertyTest.randomString(minLength: 1, maxLength: 20))" }

        return TestLocalCalibrationChallenge(
            type: TestChallengeType.random(),
            scenario: scenarios.randomElement()!,
            options: options,
            targetField: targetFields.randomElement()!
        )
    }
}

/// Test copy of CalibrationPhase
private enum TestCalibrationPhase: String, Codable, Equatable, CaseIterable {
    case idle
    case challenging
    case analyzing

    static func random() -> TestCalibrationPhase {
        allCases.randomElement()!
    }
}

/// Test copy of CalibrationFlowState
private struct TestCalibrationFlowState: Codable, Equatable {
    var phase: TestCalibrationPhase
    var challenge: TestLocalCalibrationChallenge?
    var selectedOption: Int?
    var customAnswer: String?
    var retryCount: Int
    var updatedAt: Date

    /// Generate a random instance with phase-consistent data
    static func random() -> TestCalibrationFlowState {
        let phase = TestCalibrationPhase.random()
        let retryCount = Int.random(in: 0...5)
        let updatedAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))

        switch phase {
        case .idle:
            return TestCalibrationFlowState(
                phase: .idle,
                challenge: nil,
                selectedOption: nil,
                customAnswer: nil,
                retryCount: retryCount,
                updatedAt: updatedAt
            )
        case .challenging:
            return TestCalibrationFlowState(
                phase: .challenging,
                challenge: TestLocalCalibrationChallenge.random(),
                selectedOption: nil,
                customAnswer: nil,
                retryCount: retryCount,
                updatedAt: updatedAt
            )
        case .analyzing:
            let challenge = TestLocalCalibrationChallenge.random()
            let useCustom = Bool.random()
            let selectedOption: Int?
            let customAnswer: String?
            if useCustom {
                selectedOption = -1
                customAnswer = PropertyTest.randomString(minLength: 1, maxLength: 50)
            } else {
                selectedOption = Int.random(in: 0..<challenge.options.count)
                customAnswer = nil
            }
            return TestCalibrationFlowState(
                phase: .analyzing,
                challenge: challenge,
                selectedOption: selectedOption,
                customAnswer: customAnswer,
                retryCount: retryCount,
                updatedAt: updatedAt
            )
        }
    }
}

/// Test copy of ProfilingPhase
private enum TestProfilingPhase: String, Codable, Equatable, CaseIterable {
    case idle
    case pending
    case running

    static func random() -> TestProfilingPhase {
        allCases.randomElement()!
    }
}

/// Test copy of ProfilingFlowState
private struct TestProfilingFlowState: Codable, Equatable {
    var phase: TestProfilingPhase
    var triggerLevel: Int?
    var corpusIds: [UUID]?
    var retryCount: Int
    var maxRetries: Int
    var updatedAt: Date

    /// Generate a random instance with phase-consistent data
    static func random() -> TestProfilingFlowState {
        let phase = TestProfilingPhase.random()
        let retryCount = Int.random(in: 0...5)
        let maxRetries = Int.random(in: 1...5)
        let updatedAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))

        switch phase {
        case .idle:
            return TestProfilingFlowState(
                phase: .idle,
                triggerLevel: nil,
                corpusIds: nil,
                retryCount: retryCount,
                maxRetries: maxRetries,
                updatedAt: updatedAt
            )
        case .pending, .running:
            let triggerLevel = Int.random(in: 1...10)
            let corpusCount = Int.random(in: 0...10)
            let corpusIds = (0..<corpusCount).map { _ in UUID() }
            return TestProfilingFlowState(
                phase: phase,
                triggerLevel: triggerLevel,
                corpusIds: corpusIds,
                retryCount: retryCount,
                maxRetries: maxRetries,
                updatedAt: updatedAt
            )
        }
    }
}

// MARK: - Property Tests

/// Property-based tests for flow state JSON round-trip consistency
/// Feature: ghost-twin-on-device, Property 13: Flow state round-trip consistency
final class FlowStatePropertyTests: XCTestCase {

    // MARK: - Property 13: Flow state round-trip consistency

    /// Property 13: CalibrationFlowState round-trip consistency
    /// *For any* valid CalibrationFlowState, encoding to JSON then decoding
    /// should produce an object equal to the original.
    /// Feature: ghost-twin-on-device, Property 13: Flow state round-trip consistency
    /// **Validates: Requirements 12.1, 12.2, 12.12**
    func testProperty13_CalibrationFlowStateRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        PropertyTest.verify(
            "CalibrationFlowState JSON round-trip",
            iterations: 100
        ) {
            let original = TestCalibrationFlowState.random()

            guard let data = try? encoder.encode(original) else {
                return false
            }

            guard let decoded = try? decoder.decode(TestCalibrationFlowState.self, from: data) else {
                return false
            }

            return original == decoded
        }
    }

    /// Property 13: ProfilingFlowState round-trip consistency
    /// *For any* valid ProfilingFlowState, encoding to JSON then decoding
    /// should produce an object equal to the original.
    /// Feature: ghost-twin-on-device, Property 13: Flow state round-trip consistency
    /// **Validates: Requirements 12.1, 12.2, 12.12**
    func testProperty13_ProfilingFlowStateRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        PropertyTest.verify(
            "ProfilingFlowState JSON round-trip",
            iterations: 100
        ) {
            let original = TestProfilingFlowState.random()

            guard let data = try? encoder.encode(original) else {
                return false
            }

            guard let decoded = try? decoder.decode(TestProfilingFlowState.self, from: data) else {
                return false
            }

            return original == decoded
        }
    }

    // MARK: - Edge Cases

    /// Edge case: Idle CalibrationFlowState with all nil optionals
    /// **Validates: Requirements 12.1, 12.12**
    func testEdgeCase_IdleCalibrationFlowStateRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestCalibrationFlowState(
            phase: .idle,
            challenge: nil,
            selectedOption: nil,
            customAnswer: nil,
            retryCount: 0,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode idle CalibrationFlowState")
            return
        }

        guard let decoded = try? decoder.decode(TestCalibrationFlowState.self, from: data) else {
            XCTFail("Failed to decode idle CalibrationFlowState")
            return
        }

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.phase, .idle)
        XCTAssertNil(decoded.challenge)
        XCTAssertNil(decoded.selectedOption)
        XCTAssertNil(decoded.customAnswer)
        XCTAssertEqual(decoded.retryCount, 0)
    }

    /// Edge case: Idle ProfilingFlowState with all nil optionals
    /// **Validates: Requirements 12.2, 12.12**
    func testEdgeCase_IdleProfilingFlowStateRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestProfilingFlowState(
            phase: .idle,
            triggerLevel: nil,
            corpusIds: nil,
            retryCount: 0,
            maxRetries: 3,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode idle ProfilingFlowState")
            return
        }

        guard let decoded = try? decoder.decode(TestProfilingFlowState.self, from: data) else {
            XCTFail("Failed to decode idle ProfilingFlowState")
            return
        }

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.phase, .idle)
        XCTAssertNil(decoded.triggerLevel)
        XCTAssertNil(decoded.corpusIds)
    }

    /// Edge case: Analyzing state with custom answer
    /// **Validates: Requirements 12.1, 12.12**
    func testEdgeCase_AnalyzingWithCustomAnswerRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let challenge = TestLocalCalibrationChallenge(
            type: .dilemma,
            scenario: "包含特殊字符 <>&\"' 和 emoji 🎭 的场景",
            options: ["选项A", "选项B", "选项C"],
            targetField: "spirit"
        )

        let original = TestCalibrationFlowState(
            phase: .analyzing,
            challenge: challenge,
            selectedOption: -1,
            customAnswer: "我觉得都不对，我想自己说 🤔",
            retryCount: 2,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode analyzing CalibrationFlowState")
            return
        }

        guard let decoded = try? decoder.decode(TestCalibrationFlowState.self, from: data) else {
            XCTFail("Failed to decode analyzing CalibrationFlowState")
            return
        }

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.phase, .analyzing)
        XCTAssertNotNil(decoded.challenge)
        XCTAssertEqual(decoded.selectedOption, -1)
        XCTAssertEqual(decoded.customAnswer, "我觉得都不对，我想自己说 🤔")
    }

    /// Edge case: Running ProfilingFlowState with many corpus IDs
    /// **Validates: Requirements 12.2, 12.12**
    func testEdgeCase_RunningProfilingWithManyCorpusIds() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let corpusIds = (0..<50).map { _ in UUID() }

        let original = TestProfilingFlowState(
            phase: .running,
            triggerLevel: 5,
            corpusIds: corpusIds,
            retryCount: 1,
            maxRetries: 3,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode running ProfilingFlowState")
            return
        }

        guard let decoded = try? decoder.decode(TestProfilingFlowState.self, from: data) else {
            XCTFail("Failed to decode running ProfilingFlowState")
            return
        }

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.phase, .running)
        XCTAssertEqual(decoded.triggerLevel, 5)
        XCTAssertEqual(decoded.corpusIds?.count, 50)
    }
}
