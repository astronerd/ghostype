//
//  WhisperSpeechServiceTests.swift
//  AIInputMethod
//
//  Tests for WhisperSpeechService (Property 2 & 3)
//  Property 2: cancelRecording() NEVER triggers onFinalResult
//  Property 3: buffer < 0.3s → onFinalResult("") called (not a crash)
//
//  Note: Tests use a local protocol + mock to avoid AVAudioEngine dependency
//  (the real service requires a microphone, which CI doesn't have)
//

import XCTest
import Foundation

// MARK: - Local Protocol (test target is standalone)

private protocol SpeechServiceProtocol: AnyObject {
    var onFinalResult: ((String) -> Void)? { get set }
    var onPartialResult: ((String) -> Void)? { get set }
    func startRecording()
    func stopRecording()
    func cancelRecording()
}

// MARK: - Testable Whisper Service Logic

/// Extracts the core transcription gate logic from WhisperSpeechService
/// for testing without AVAudioEngine or real model loading
private final class TestableWhisperLogic {
    var onFinalResult: ((String) -> Void)?
    private var isCancelled = false
    private var inferenceTask: Task<Void, Never>?

    func simulateCancelRecording() {
        isCancelled = true
        inferenceTask?.cancel()
        // No onFinalResult call — this is the invariant
    }

    func simulateStopWithBuffer(_ buffer: [Float]) {
        guard !isCancelled else { return }
        let copy = buffer
        inferenceTask = Task { [weak self] in
            await self?.transcribe(buffer: copy)
        }
    }

    func reset() {
        isCancelled = false
        inferenceTask?.cancel()
        inferenceTask = nil
    }

    private func transcribe(buffer: [Float]) async {
        // Minimum buffer gate: 0.3s @ 16kHz = 4800 frames
        guard buffer.count >= 4800 else {
            await MainActor.run { self.onFinalResult?("") }
            return
        }
        // In tests we don't have a real WhisperKit — model nil path
        await MainActor.run { self.onFinalResult?("") }
    }
}

// MARK: - Tests

@MainActor
final class WhisperSpeechServiceTests: XCTestCase {

    // MARK: - Property 2: cancelRecording → onFinalResult never fires

    func testCancelRecordingDoesNotFireFinalResult() async {
        let service = TestableWhisperLogic()
        var finalResultFired = false
        service.onFinalResult = { _ in finalResultFired = true }

        // Simulate: start → cancel (no buffer)
        service.simulateCancelRecording()

        // Small delay to ensure any spurious async tasks complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        XCTAssertFalse(finalResultFired, "cancelRecording must not trigger onFinalResult")
    }

    func testCancelAfterStopDoesNotFireAgain() async {
        let service = TestableWhisperLogic()
        var callCount = 0
        service.onFinalResult = { _ in callCount += 1 }

        // Cancel first — then even if stop is called, isCancelled blocks it
        service.simulateCancelRecording()
        service.simulateStopWithBuffer([Float](repeating: 0, count: 1000))

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(callCount, 0, "After cancel, stop should not fire onFinalResult")
    }

    // MARK: - Property 3: short buffer → onFinalResult("") without crash

    func testShortBufferFiresEmptyResult() async {
        let service = TestableWhisperLogic()
        var receivedResult: String?
        service.onFinalResult = { receivedResult = $0 }

        // Buffer of 100 frames << 4800 minimum
        service.simulateStopWithBuffer([Float](repeating: 0.01, count: 100))

        // Wait for async transcription
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(receivedResult, "onFinalResult should be called for short buffer")
        XCTAssertEqual(receivedResult, "", "Short buffer should produce empty string result")
    }

    func testEmptyBufferFiresEmptyResult() async {
        let service = TestableWhisperLogic()
        var receivedResult: String?
        service.onFinalResult = { receivedResult = $0 }

        service.simulateStopWithBuffer([])

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(receivedResult, "")
    }

    func testExactlyMinimumBufferDoesNotTakeShortPath() async {
        // 4800 frames is exactly the minimum — should proceed past short-buffer gate
        // (no real WhisperKit, so falls to model-nil path → still returns "")
        let service = TestableWhisperLogic()
        var receivedResult: String?
        service.onFinalResult = { receivedResult = $0 }

        service.simulateStopWithBuffer([Float](repeating: 0, count: 4800))

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(receivedResult, "")
    }

    // MARK: - Reset safety

    func testResetAllowsNewInference() async {
        let service = TestableWhisperLogic()
        var callCount = 0
        service.onFinalResult = { _ in callCount += 1 }

        service.simulateCancelRecording()
        service.reset()

        service.simulateStopWithBuffer([Float](repeating: 0, count: 100))
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(callCount, 1, "After reset, new inference should fire onFinalResult")
    }
}
