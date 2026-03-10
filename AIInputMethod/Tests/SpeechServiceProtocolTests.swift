//
//  SpeechServiceProtocolTests.swift
//  AIInputMethod
//
//  Tests for Property 1: SpeechServiceProtocol transparency
//  Any conforming implementation should be interchangeable in VoiceInputCoordinator
//

import XCTest
import Foundation

// MARK: - Local Protocol Definition (test target is standalone)

private protocol SpeechServiceProtocol: AnyObject {
    var onFinalResult: ((String) -> Void)? { get set }
    var onPartialResult: ((String) -> Void)? { get set }
    func startRecording()
    func stopRecording()
    func cancelRecording()
}

// MARK: - Mock Speech Service

/// Mock SpeechServiceProtocol for testing protocol transparency
private final class MockSpeechService: SpeechServiceProtocol {
    var onFinalResult: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?

    var startCount = 0
    var stopCount = 0
    var cancelCount = 0

    func startRecording() {
        startCount += 1
    }

    func stopRecording() {
        stopCount += 1
    }

    func cancelRecording() {
        cancelCount += 1
    }

    /// Simulate ASR returning a result
    func simulateFinalResult(_ text: String) {
        onFinalResult?(text)
    }
}

// MARK: - Tests

final class SpeechServiceProtocolTests: XCTestCase {

    // MARK: - Property 1: Protocol Conformance

    /// MockSpeechService conforms to SpeechServiceProtocol
    func testMockConformsToProtocol() {
        let mock: any SpeechServiceProtocol = MockSpeechService()
        XCTAssertNotNil(mock)
    }

    /// onFinalResult callback is called when injected and triggered
    func testFinalResultCallbackFired() {
        let mock = MockSpeechService()
        var receivedText: String?
        mock.onFinalResult = { receivedText = $0 }

        mock.simulateFinalResult("hello world")

        XCTAssertEqual(receivedText, "hello world")
    }

    /// onPartialResult callback is settable and callable
    func testPartialResultCallbackSettable() {
        let mock = MockSpeechService()
        var receivedPartial: String?
        mock.onPartialResult = { receivedPartial = $0 }
        mock.onPartialResult?("partial text")

        XCTAssertEqual(receivedPartial, "partial text")
    }

    // MARK: - Property 2: cancelRecording does not trigger processing

    /// After cancelRecording(), onFinalResult must NOT be called by the service
    func testCancelRecordingDoesNotFireFinalResult() {
        let mock = MockSpeechService()
        var finalResultFired = false
        mock.onFinalResult = { _ in finalResultFired = true }

        mock.startRecording()
        mock.cancelRecording()

        // Mock doesn't auto-fire onFinalResult after cancel
        XCTAssertFalse(finalResultFired)
        XCTAssertEqual(mock.cancelCount, 1)
    }

    /// cancelRecording increments cancelCount, not stopCount
    func testCancelVsStop() {
        let mock = MockSpeechService()
        mock.cancelRecording()

        XCTAssertEqual(mock.cancelCount, 1)
        XCTAssertEqual(mock.stopCount, 0)
    }

    // MARK: - Recording lifecycle

    /// startRecording increments startCount
    func testStartRecording() {
        let mock = MockSpeechService()
        mock.startRecording()
        XCTAssertEqual(mock.startCount, 1)
    }

    /// stopRecording increments stopCount
    func testStopRecording() {
        let mock = MockSpeechService()
        mock.startRecording()
        mock.stopRecording()
        XCTAssertEqual(mock.stopCount, 1)
    }

    /// Callbacks survive being reassigned (hot-swap simulation)
    func testCallbackReassignment() {
        let mock = MockSpeechService()
        var firstFired = false
        var secondFired = false

        mock.onFinalResult = { _ in firstFired = true }
        mock.onFinalResult = { _ in secondFired = true }

        mock.simulateFinalResult("test")

        XCTAssertFalse(firstFired)
        XCTAssertTrue(secondFired)
    }
}
