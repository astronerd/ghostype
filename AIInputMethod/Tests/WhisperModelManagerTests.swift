//
//  WhisperModelManagerTests.swift
//  AIInputMethod
//
//  Tests for WhisperModelManager disk state tracking (Property 4)
//  Test uses a temporary directory to avoid touching real model storage
//

import XCTest
import Foundation

// MARK: - Standalone Model Types (test target is standalone)

private struct TestWhisperModelInfo: Identifiable {
    let id: String
    let displayName: String
    let sizeEstimate: String
    let qualityNote: String
}

private enum TestModelDownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case error(String)
}

// MARK: - Testable Manager (uses custom directory)

/// Lightweight version of WhisperModelManager logic for unit testing
/// (Production class is @Observable singleton; we test the core logic here)
private final class TestableModelTracker {
    let modelsDirectory: URL
    var statuses: [String: TestModelDownloadStatus] = [:]

    static let testModels: [TestWhisperModelInfo] = [
        .init(id: "openai_whisper-tiny",  displayName: "Tiny",  sizeEstimate: "~150 MB", qualityNote: ""),
        .init(id: "openai_whisper-small", displayName: "Small", sizeEstimate: "~500 MB", qualityNote: ""),
    ]

    init(directory: URL) {
        self.modelsDirectory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        refreshStatuses()
    }

    func modelFolder(for modelId: String) -> URL {
        modelsDirectory.appendingPathComponent(modelId, isDirectory: true)
    }

    func isDownloaded(_ modelId: String) -> Bool {
        statuses[modelId] == .downloaded
    }

    func refreshStatuses() {
        for model in Self.testModels {
            let folder = modelFolder(for: model.id)
            let exists = FileManager.default.fileExists(atPath: folder.path)
            if case .downloading = statuses[model.id] { continue }
            statuses[model.id] = exists ? .downloaded : .notDownloaded
        }
    }

    func delete(modelId: String) throws {
        let folder = modelFolder(for: modelId)
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
        statuses[modelId] = .notDownloaded
    }
}

// MARK: - Tests

final class WhisperModelManagerTests: XCTestCase {

    private var tempDir: URL!
    private var tracker: TestableModelTracker!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-test-\(UUID().uuidString)")
        tracker = TestableModelTracker(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Property 4: isDownloaded consistent with disk

    /// Empty directory → all models not downloaded
    func testInitialStatusAllNotDownloaded() {
        for model in TestableModelTracker.testModels {
            XCTAssertFalse(tracker.isDownloaded(model.id),
                "Model \(model.id) should not be downloaded on fresh directory")
            XCTAssertEqual(tracker.statuses[model.id], .notDownloaded)
        }
    }

    /// Creating model folder on disk → refreshStatuses → isDownloaded returns true (Property 4)
    func testRefreshDetectsExistingModel() throws {
        let modelId = "openai_whisper-tiny"
        let folder = tracker.modelFolder(for: modelId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        tracker.refreshStatuses()

        XCTAssertTrue(tracker.isDownloaded(modelId), "Should detect model folder on disk")
        XCTAssertEqual(tracker.statuses[modelId], .downloaded)
    }

    /// delete() removes folder and sets status to notDownloaded
    func testDeleteUpdatesStatus() throws {
        let modelId = "openai_whisper-small"
        let folder = tracker.modelFolder(for: modelId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        tracker.refreshStatuses()
        XCTAssertTrue(tracker.isDownloaded(modelId))

        try tracker.delete(modelId: modelId)

        XCTAssertFalse(tracker.isDownloaded(modelId))
        XCTAssertEqual(tracker.statuses[modelId], .notDownloaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    /// modelFolder path is deterministic: modelsDirectory/{modelId}
    func testModelFolderPath() {
        let modelId = "openai_whisper-medium"
        let expected = tempDir.appendingPathComponent(modelId)
        XCTAssertEqual(tracker.modelFolder(for: modelId).path, expected.path)
    }

    /// refreshStatuses skips models currently downloading
    func testRefreshSkipsDownloadingStatus() throws {
        let modelId = "openai_whisper-tiny"
        tracker.statuses[modelId] = .downloading(progress: 0.5)

        // Even if folder exists, downloading status should be preserved
        let folder = tracker.modelFolder(for: modelId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        tracker.refreshStatuses()

        if case .downloading(let p) = tracker.statuses[modelId] {
            XCTAssertEqual(p, 0.5, "Downloading progress should be preserved")
        } else {
            XCTFail("Status should remain .downloading")
        }
    }

    /// delete() on non-existent folder does not throw
    func testDeleteNonExistentFolderIsSafe() throws {
        let modelId = "openai_whisper-tiny"
        // No folder exists — delete should succeed silently
        XCTAssertNoThrow(try tracker.delete(modelId: modelId))
        XCTAssertEqual(tracker.statuses[modelId], .notDownloaded)
    }

    // MARK: - ModelDownloadStatus Equatable

    func testStatusEquality() {
        XCTAssertEqual(TestModelDownloadStatus.notDownloaded, .notDownloaded)
        XCTAssertEqual(TestModelDownloadStatus.downloaded, .downloaded)
        XCTAssertEqual(TestModelDownloadStatus.downloading(progress: 0.5), .downloading(progress: 0.5))
        XCTAssertNotEqual(TestModelDownloadStatus.downloading(progress: 0.3), .downloading(progress: 0.7))
        XCTAssertEqual(TestModelDownloadStatus.error("x"), .error("x"))
        XCTAssertNotEqual(TestModelDownloadStatus.error("a"), .error("b"))
    }
}
