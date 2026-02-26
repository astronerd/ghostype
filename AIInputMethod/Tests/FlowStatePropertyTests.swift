//
//  FlowStatePropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for flow state JSON round-trip consistency
//  Feature: ghost-twin-on-device, Property 13: Flow state round-trip consistency
//

import XCTest
import Foundation

// MARK: - Test Copies of Models

private struct TestLocalCalibrationChallenge: Codable, Equatable {
    let scenario: String
    let options: [String]
    let targetField: String

    static func random() -> TestLocalCalibrationChallenge {
        let scenarios = [
            "你的朋友发了一条明显有事实错误的朋友圈...",
            "同事在群里发了一个有争议的观点...",
            "包含 emoji 🎭 的场景描述", ""
        ]
        let optionCount = Int.random(in: 2...5)
        let options = (0..<optionCount).map { "选项\($0): \(PropertyTest.randomString(minLength: 1, maxLength: 20))" }
        return TestLocalCalibrationChallenge(
            scenario: scenarios.randomElement()!,
            options: options,
            targetField: ["form", "spirit", "method"].randomElement()!
        )
    }
}

private enum TestCalibrationPhase: String, Codable, Equatable, CaseIterable {
    case idle, challenging, analyzing
    static func random() -> TestCalibrationPhase { allCases.randomElement()! }
}

private struct TestCalibrationFlowState: Codable, Equatable {
    var phase: TestCalibrationPhase
    var challenge: TestLocalCalibrationChallenge?
    var selectedOption: Int?
    var customAnswer: String?
    var retryCount: Int
    var updatedAt: Date

    static func random() -> TestCalibrationFlowState {
        let phase = TestCalibrationPhase.random()
        let retryCount = Int.random(in: 0...5)
        let updatedAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))
        switch phase {
        case .idle:
            return TestCalibrationFlowState(phase: .idle, challenge: nil, selectedOption: nil, customAnswer: nil, retryCount: retryCount, updatedAt: updatedAt)
        case .challenging:
            return TestCalibrationFlowState(phase: .challenging, challenge: TestLocalCalibrationChallenge.random(), selectedOption: nil, customAnswer: nil, retryCount: retryCount, updatedAt: updatedAt)
        case .analyzing:
            let challenge = TestLocalCalibrationChallenge.random()
            let useCustom = Bool.random()
            return TestCalibrationFlowState(
                phase: .analyzing, challenge: challenge,
                selectedOption: useCustom ? -1 : Int.random(in: 0..<challenge.options.count),
                customAnswer: useCustom ? PropertyTest.randomString(minLength: 1, maxLength: 50) : nil,
                retryCount: retryCount, updatedAt: updatedAt
            )
        }
    }
}

private enum TestProfilingPhase: String, Codable, Equatable, CaseIterable {
    case idle, pending, running
    static func random() -> TestProfilingPhase { allCases.randomElement()! }
}

private struct TestProfilingFlowState: Codable, Equatable {
    var phase: TestProfilingPhase
    var triggerLevel: Int?
    var corpusIds: [UUID]?
    var retryCount: Int
    var maxRetries: Int
    var updatedAt: Date

    static func random() -> TestProfilingFlowState {
        let phase = TestProfilingPhase.random()
        let retryCount = Int.random(in: 0...5)
        let maxRetries = Int.random(in: 1...5)
        let updatedAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))
        switch phase {
        case .idle:
            return TestProfilingFlowState(phase: .idle, triggerLevel: nil, corpusIds: nil, retryCount: retryCount, maxRetries: maxRetries, updatedAt: updatedAt)
        case .pending, .running:
            return TestProfilingFlowState(phase: phase, triggerLevel: Int.random(in: 1...10), corpusIds: (0..<Int.random(in: 0...10)).map { _ in UUID() }, retryCount: retryCount, maxRetries: maxRetries, updatedAt: updatedAt)
        }
    }
}


// MARK: - Property Tests

final class FlowStatePropertyTests: XCTestCase {

    func testProperty13_CalibrationFlowStateRoundTrip() {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        PropertyTest.verify("CalibrationFlowState JSON round-trip", iterations: 100) {
            let original = TestCalibrationFlowState.random()
            guard let data = try? encoder.encode(original) else { return false }
            guard let decoded = try? decoder.decode(TestCalibrationFlowState.self, from: data) else { return false }
            return original == decoded
        }
    }

    func testProperty13_ProfilingFlowStateRoundTrip() {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        PropertyTest.verify("ProfilingFlowState JSON round-trip", iterations: 100) {
            let original = TestProfilingFlowState.random()
            guard let data = try? encoder.encode(original) else { return false }
            guard let decoded = try? decoder.decode(TestProfilingFlowState.self, from: data) else { return false }
            return original == decoded
        }
    }

    func testEdgeCase_IdleCalibrationFlowStateRoundTrip() {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let original = TestCalibrationFlowState(phase: .idle, challenge: nil, selectedOption: nil, customAnswer: nil, retryCount: 0, updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        guard let data = try? encoder.encode(original), let decoded = try? decoder.decode(TestCalibrationFlowState.self, from: data) else { XCTFail("Round-trip failed"); return }
        XCTAssertEqual(original, decoded)
        XCTAssertNil(decoded.challenge)
    }

    func testEdgeCase_AnalyzingWithCustomAnswerRoundTrip() {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let challenge = TestLocalCalibrationChallenge(scenario: "包含特殊字符 <>&\"' 和 emoji 🎭 的场景", options: ["选项A", "选项B", "选项C"], targetField: "spirit")
        let original = TestCalibrationFlowState(phase: .analyzing, challenge: challenge, selectedOption: -1, customAnswer: "我觉得都不对，我想自己说 🤔", retryCount: 2, updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        guard let data = try? encoder.encode(original), let decoded = try? decoder.decode(TestCalibrationFlowState.self, from: data) else { XCTFail("Round-trip failed"); return }
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.customAnswer, "我觉得都不对，我想自己说 🤔")
    }

    func testEdgeCase_RunningProfilingWithManyCorpusIds() {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let original = TestProfilingFlowState(phase: .running, triggerLevel: 5, corpusIds: (0..<50).map { _ in UUID() }, retryCount: 1, maxRetries: 3, updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        guard let data = try? encoder.encode(original), let decoded = try? decoder.decode(TestProfilingFlowState.self, from: data) else { XCTFail("Round-trip failed"); return }
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.corpusIds?.count, 50)
    }
}
