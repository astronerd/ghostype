//
//  ASRCorpusStorePropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for ASRCorpusStore corpus consumption state management
//  Feature: ghost-twin-on-device, Property 11: Corpus consumption state management
//

import XCTest
import Foundation

// MARK: - Test Copy of ASRCorpusEntry

private struct TestASRCorpusEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var consumedAtLevel: Int?   // nil = 未消费

    static func random(consumedAtLevel: Int? = nil) -> TestASRCorpusEntry {
        TestASRCorpusEntry(
            id: UUID(),
            text: "语料\(Int.random(in: 1...10000))",
            createdAt: Date(timeIntervalSince1970: Double(Int.random(in: 1_000_000...1_900_000_000))),
            consumedAtLevel: consumedAtLevel
        )
    }
}

// MARK: - Test Copy of ASRCorpusStore

/// Test copy of ASRCorpusStore that mirrors production logic exactly.
/// Uses a custom file path (temp directory) for isolation.
private class TestASRCorpusStore {

    private let filePath: URL

    init(filePath: URL) {
        self.filePath = filePath
    }

    func loadAll() -> [TestASRCorpusEntry] {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TestASRCorpusEntry].self, from: data)
        } catch {
            return []
        }
    }

    func append(text: String) {
        var entries = loadAll()
        let entry = TestASRCorpusEntry(
            id: UUID(),
            text: text,
            createdAt: Date(),
            consumedAtLevel: nil
        )
        entries.append(entry)
        do {
            try save(entries)
        } catch {
            // silent in tests
        }
    }

    func unconsumed() -> [TestASRCorpusEntry] {
        loadAll().filter { $0.consumedAtLevel == nil }
    }

    func markConsumed(ids: [UUID], atLevel: Int) {
        var entries = loadAll()
        let idSet = Set(ids)
        for i in entries.indices {
            if idSet.contains(entries[i].id) {
                entries[i].consumedAtLevel = atLevel
            }
        }
        do {
            try save(entries)
        } catch {
            // silent in tests
        }
    }

    func save(_ entries: [TestASRCorpusEntry]) throws {
        let directory = filePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: filePath, options: .atomic)
    }
}

// MARK: - Property Tests

/// Property-based tests for ASRCorpusStore corpus consumption state management
/// Feature: ghost-twin-on-device, Property 11: Corpus consumption state management
final class ASRCorpusStorePropertyTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ASRCorpusStoreTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Property 11: Corpus consumption state management

    /// Property 11: Corpus consumption state management
    /// *For any* list of ASRCorpusEntry entries, unconsumed() should return exactly those entries
    /// where consumedAtLevel == nil. After calling markConsumed(ids:atLevel:) with a set of IDs
    /// and a level value, those entries should have consumedAtLevel set to the given level,
    /// and unconsumed() should no longer include them.
    /// Feature: ghost-twin-on-device, Property 11: Corpus consumption state management
    /// **Validates: Requirements 7.5, 8.3, 8.4**
    func testProperty11_CorpusConsumptionStateManagement() throws {
        try PropertyTest.verify(
            "Corpus consumption state management",
            iterations: 100
        ) {
            let filePath = self.tempDir.appendingPathComponent("corpus_\(UUID().uuidString).json")
            let store = TestASRCorpusStore(filePath: filePath)

            // Generate random entries: some already consumed, some not
            let totalEntries = Int.random(in: 1...20)
            var entries: [TestASRCorpusEntry] = []
            for _ in 0..<totalEntries {
                let isPreConsumed = Bool.random()
                let entry = TestASRCorpusEntry.random(
                    consumedAtLevel: isPreConsumed ? Int.random(in: 1...10) : nil
                )
                entries.append(entry)
            }

            // Save initial entries
            try store.save(entries)

            // Verify unconsumed() returns exactly those with consumedAtLevel == nil
            let unconsumedBefore = store.unconsumed()
            let expectedUnconsumed = entries.filter { $0.consumedAtLevel == nil }
            guard unconsumedBefore.count == expectedUnconsumed.count else { return false }

            let unconsumedIdsBefore = Set(unconsumedBefore.map { $0.id })
            let expectedUnconsumedIds = Set(expectedUnconsumed.map { $0.id })
            guard unconsumedIdsBefore == expectedUnconsumedIds else { return false }

            // Pick a random subset of unconsumed entries to mark as consumed
            let toConsume = expectedUnconsumed.filter { _ in Bool.random() }
            let consumeIds = toConsume.map { $0.id }
            let level = Int.random(in: 1...10)

            if !consumeIds.isEmpty {
                store.markConsumed(ids: consumeIds, atLevel: level)
            }

            // Verify: consumed entries now have consumedAtLevel set to the given level
            let allAfter = store.loadAll()
            let consumeIdSet = Set(consumeIds)
            for entry in allAfter {
                if consumeIdSet.contains(entry.id) {
                    guard entry.consumedAtLevel == level else { return false }
                }
            }

            // Verify: unconsumed() no longer includes the consumed entries
            let unconsumedAfter = store.unconsumed()
            let unconsumedIdsAfter = Set(unconsumedAfter.map { $0.id })
            for id in consumeIds {
                guard !unconsumedIdsAfter.contains(id) else { return false }
            }

            // Verify: entries that were NOT consumed remain unchanged
            let notConsumedIds = Set(expectedUnconsumed.map { $0.id }).subtracting(consumeIdSet)
            for id in notConsumedIds {
                guard unconsumedIdsAfter.contains(id) else { return false }
            }

            // Verify: total entry count unchanged
            guard allAfter.count == totalEntries else { return false }

            return true
        }
    }

    // MARK: - Edge Cases

    /// Edge case: Empty store returns empty unconsumed list
    /// **Validates: Requirements 8.3**
    func testEdgeCase_EmptyStoreReturnsEmptyUnconsumed() {
        let filePath = tempDir.appendingPathComponent("corpus_empty.json")
        let store = TestASRCorpusStore(filePath: filePath)

        XCTAssertTrue(store.unconsumed().isEmpty, "Empty store should return empty unconsumed list")
        XCTAssertTrue(store.loadAll().isEmpty, "Empty store should return empty list")
    }

    /// Edge case: All entries consumed means unconsumed returns empty
    /// **Validates: Requirements 8.3, 8.4**
    func testEdgeCase_AllConsumedMeansEmptyUnconsumed() {
        let filePath = tempDir.appendingPathComponent("corpus_all_consumed.json")
        let store = TestASRCorpusStore(filePath: filePath)

        let entries = (0..<5).map { _ in TestASRCorpusEntry.random(consumedAtLevel: nil) }
        try! store.save(entries)

        let allIds = entries.map { $0.id }
        store.markConsumed(ids: allIds, atLevel: 3)

        XCTAssertTrue(store.unconsumed().isEmpty, "All consumed should mean empty unconsumed")
        XCTAssertEqual(store.loadAll().count, 5, "Total count should remain 5")
    }

    /// Edge case: markConsumed with non-existent IDs does not affect existing entries
    /// **Validates: Requirements 8.4**
    func testEdgeCase_MarkConsumedWithNonExistentIds() {
        let filePath = tempDir.appendingPathComponent("corpus_nonexistent.json")
        let store = TestASRCorpusStore(filePath: filePath)

        let entries = (0..<3).map { _ in TestASRCorpusEntry.random(consumedAtLevel: nil) }
        try! store.save(entries)

        // Mark non-existent IDs
        store.markConsumed(ids: [UUID(), UUID()], atLevel: 5)

        let unconsumed = store.unconsumed()
        XCTAssertEqual(unconsumed.count, 3, "Non-existent IDs should not affect existing entries")
    }

    /// Edge case: markConsumed with empty ID list is a no-op
    /// **Validates: Requirements 8.4**
    func testEdgeCase_MarkConsumedWithEmptyIds() {
        let filePath = tempDir.appendingPathComponent("corpus_empty_ids.json")
        let store = TestASRCorpusStore(filePath: filePath)

        let entries = (0..<4).map { _ in TestASRCorpusEntry.random(consumedAtLevel: nil) }
        try! store.save(entries)

        store.markConsumed(ids: [], atLevel: 2)

        let unconsumed = store.unconsumed()
        XCTAssertEqual(unconsumed.count, 4, "Empty ID list should not change anything")
    }

    /// Edge case: Single entry consumed then unconsumed is empty
    /// **Validates: Requirements 8.3, 8.4**
    func testEdgeCase_SingleEntryConsumed() {
        let filePath = tempDir.appendingPathComponent("corpus_single.json")
        let store = TestASRCorpusStore(filePath: filePath)

        let entry = TestASRCorpusEntry.random(consumedAtLevel: nil)
        try! store.save([entry])

        XCTAssertEqual(store.unconsumed().count, 1)

        store.markConsumed(ids: [entry.id], atLevel: 1)

        XCTAssertTrue(store.unconsumed().isEmpty)
        let loaded = store.loadAll()
        XCTAssertEqual(loaded.first?.consumedAtLevel, 1)
    }

    /// Edge case: Already consumed entries are not affected by markConsumed on different IDs
    /// **Validates: Requirements 8.3, 8.4**
    func testEdgeCase_AlreadyConsumedNotAffected() {
        let filePath = tempDir.appendingPathComponent("corpus_already.json")
        let store = TestASRCorpusStore(filePath: filePath)

        let consumed = TestASRCorpusEntry.random(consumedAtLevel: 2)
        let unconsumedEntry = TestASRCorpusEntry.random(consumedAtLevel: nil)
        try! store.save([consumed, unconsumedEntry])

        store.markConsumed(ids: [unconsumedEntry.id], atLevel: 5)

        let loaded = store.loadAll()
        let consumedAfter = loaded.first { $0.id == consumed.id }
        XCTAssertEqual(consumedAfter?.consumedAtLevel, 2, "Previously consumed entry should keep its original level")

        let newlyConsumed = loaded.first { $0.id == unconsumedEntry.id }
        XCTAssertEqual(newlyConsumed?.consumedAtLevel, 5)
    }
}
