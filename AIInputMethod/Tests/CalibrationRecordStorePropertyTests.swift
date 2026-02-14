//
//  CalibrationRecordStorePropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for CalibrationRecordStore max-20 invariant
//  Feature: ghost-twin-on-device, Property 3: Record store max-20 invariant
//

import XCTest
import Foundation

// MARK: - Test Copy of ChallengeType

private enum TestChallengeType: String, Codable, CaseIterable, Equatable {
    case dilemma
    case reverseTuring = "reverse_turing"
    case prediction

    static func random() -> TestChallengeType {
        allCases.randomElement()!
    }
}

// MARK: - Test Copy of CalibrationRecord

private struct TestCalibrationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let type: TestChallengeType
    let scenario: String
    let options: [String]
    let selectedOption: Int
    let customAnswer: String?
    let xpEarned: Int
    let ghostResponse: String
    let profileDiff: String?
    let createdAt: Date

    /// Generate a random record with a specific createdAt for ordering verification
    static func random(createdAt: Date = Date()) -> TestCalibrationRecord {
        let type = TestChallengeType.random()
        let useCustom = Bool.random()
        return TestCalibrationRecord(
            id: UUID(),
            type: type,
            scenario: "场景\(Int.random(in: 1...100))",
            options: ["A", "B", "C"],
            selectedOption: useCustom ? -1 : Int.random(in: 0...2),
            customAnswer: useCustom ? "自定义答案" : nil,
            xpEarned: type == .dilemma ? 500 : (type == .reverseTuring ? 300 : 200),
            ghostResponse: "反馈 👻",
            profileDiff: Bool.random() ? "{\"layer\":\"spirit\"}" : nil,
            createdAt: createdAt
        )
    }
}

// MARK: - Test Copy of CalibrationRecordStore

/// Test copy of CalibrationRecordStore that mirrors production logic exactly.
/// Uses a custom file path (temp directory) for isolation.
private class TestCalibrationRecordStore {

    static let maxRecords = 20

    private let filePath: URL

    init(filePath: URL) {
        self.filePath = filePath
    }

    func loadAll() -> [TestCalibrationRecord] {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TestCalibrationRecord].self, from: data)
        } catch {
            return []
        }
    }

    func append(_ record: TestCalibrationRecord) {
        var records = loadAll()
        records.append(record)
        if records.count > Self.maxRecords {
            records = Array(records.suffix(Self.maxRecords))
        }
        do {
            try save(records)
        } catch {
            // silent in tests
        }
    }

    static let dailyLimit = 3

    /// 今日已完成挑战数（UTC 0:00 重置）
    func todayCount() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = calendar.startOfDay(for: Date())
        return loadAll().filter { $0.createdAt >= todayStart }.count
    }

    /// 今日剩余挑战次数
    func challengesRemainingToday() -> Int {
        max(Self.dailyLimit - todayCount(), 0)
    }

    private func save(_ records: [TestCalibrationRecord]) throws {
        let directory = filePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: filePath, options: .atomic)
    }
}


// MARK: - Property Tests

/// Property-based tests for CalibrationRecordStore max-20 invariant
/// Feature: ghost-twin-on-device, Property 3: Record store max-20 invariant
final class CalibrationRecordStorePropertyTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CalibrationRecordStoreTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Property 3: Record store max-20 invariant

    /// Property 3: Record store max-20 invariant
    /// *For any* sequence of N appended CalibrationRecord entries (N >= 1),
    /// the CalibrationRecordStore should never contain more than 20 records,
    /// and should always contain the most recent min(N, 20) records in chronological order.
    /// Feature: ghost-twin-on-device, Property 3: Record store max-20 invariant
    /// **Validates: Requirements 2.2, 2.3**
    func testProperty3_RecordStoreMax20Invariant() {
        PropertyTest.verify(
            "CalibrationRecordStore max-20 invariant",
            iterations: 100
        ) {
            // Fresh store for each iteration
            let filePath = self.tempDir.appendingPathComponent("records_\(UUID().uuidString).json")
            let store = TestCalibrationRecordStore(filePath: filePath)

            // Generate N records (1..30) with increasing timestamps for chronological ordering
            let n = Int.random(in: 1...30)
            var allAppended: [TestCalibrationRecord] = []
            let baseTime = Date(timeIntervalSince1970: Double(Int.random(in: 1_000_000...1_900_000_000)))

            for i in 0..<n {
                let createdAt = baseTime.addingTimeInterval(Double(i))
                let record = TestCalibrationRecord.random(createdAt: createdAt)
                allAppended.append(record)
                store.append(record)
            }

            let loaded = store.loadAll()

            // Invariant 1: Never more than 20 records
            guard loaded.count <= 20 else { return false }

            // Invariant 2: Should contain exactly min(N, 20) records
            let expectedCount = min(n, 20)
            guard loaded.count == expectedCount else { return false }

            // Invariant 3: Should be the most recent min(N, 20) records
            let expectedRecords = Array(allAppended.suffix(expectedCount))
            for (idx, record) in loaded.enumerated() {
                // Compare by id to verify correct records are kept
                guard record.id == expectedRecords[idx].id else { return false }
            }

            // Invariant 4: Records should be in chronological order
            for i in 1..<loaded.count {
                guard loaded[i].createdAt >= loaded[i - 1].createdAt else { return false }
            }

            return true
        }
    }

    // MARK: - Edge Cases

    /// Edge case: Appending exactly 20 records should keep all of them
    /// **Validates: Requirements 2.2**
    func testEdgeCase_Exactly20Records() {
        let filePath = tempDir.appendingPathComponent("records_20.json")
        let store = TestCalibrationRecordStore(filePath: filePath)
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

        var ids: [UUID] = []
        for i in 0..<20 {
            let record = TestCalibrationRecord.random(createdAt: baseTime.addingTimeInterval(Double(i)))
            ids.append(record.id)
            store.append(record)
        }

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 20, "Should keep all 20 records")
        for (idx, record) in loaded.enumerated() {
            XCTAssertEqual(record.id, ids[idx], "Record \(idx) should match")
        }
    }

    /// Edge case: Appending 21 records should drop the first one
    /// **Validates: Requirements 2.3**
    func testEdgeCase_21stRecordDropsFirst() {
        let filePath = tempDir.appendingPathComponent("records_21.json")
        let store = TestCalibrationRecordStore(filePath: filePath)
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

        var ids: [UUID] = []
        for i in 0..<21 {
            let record = TestCalibrationRecord.random(createdAt: baseTime.addingTimeInterval(Double(i)))
            ids.append(record.id)
            store.append(record)
        }

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 20, "Should cap at 20 records")
        // First record (ids[0]) should be dropped, records 1..20 should remain
        for (idx, record) in loaded.enumerated() {
            XCTAssertEqual(record.id, ids[idx + 1], "Record \(idx) should be ids[\(idx + 1)]")
        }
    }

    /// Edge case: Single record
    /// **Validates: Requirements 2.2**
    func testEdgeCase_SingleRecord() {
        let filePath = tempDir.appendingPathComponent("records_1.json")
        let store = TestCalibrationRecordStore(filePath: filePath)

        let record = TestCalibrationRecord.random()
        store.append(record)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, record.id)
    }

    /// Edge case: Empty store returns empty array
    /// **Validates: Requirements 2.2**
    func testEdgeCase_EmptyStore() {
        let filePath = tempDir.appendingPathComponent("records_empty.json")
        let store = TestCalibrationRecordStore(filePath: filePath)

        let loaded = store.loadAll()
        XCTAssertTrue(loaded.isEmpty, "Empty store should return empty array")
    }

    // MARK: - Property 7: Daily challenge limit

    /// Property 7: Daily challenge limit
    /// *For any* list of CalibrationRecord entries with various createdAt timestamps,
    /// todayCount() should equal the count of records whose createdAt falls on or after
    /// UTC midnight today, and challengesRemainingToday() should equal max(3 - todayCount(), 0).
    /// Feature: ghost-twin-on-device, Property 7: Daily challenge limit
    /// **Validates: Requirements 4.1, 4.2, 4.3**
    func testProperty7_DailyChallengeLimit() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let todayStart = utcCalendar.startOfDay(for: now)

        PropertyTest.verify(
            "Daily challenge limit: todayCount and challengesRemainingToday",
            iterations: 100
        ) {
            let filePath = self.tempDir.appendingPathComponent("daily_\(UUID().uuidString).json")
            let store = TestCalibrationRecordStore(filePath: filePath)

            // Generate a random mix of today and past records (0..10 total)
            let totalRecords = Int.random(in: 0...10)
            var expectedTodayCount = 0

            for _ in 0..<totalRecords {
                let isToday = Bool.random()
                let createdAt: Date
                if isToday {
                    // Random time today: todayStart + 0..<86400 seconds
                    let secondsIntoDay = Double.random(in: 0..<min(now.timeIntervalSince(todayStart), 86400))
                    createdAt = todayStart.addingTimeInterval(secondsIntoDay)
                    expectedTodayCount += 1
                } else {
                    // Random past date: 1 to 365 days ago
                    let daysAgo = Double.random(in: 1...365)
                    createdAt = todayStart.addingTimeInterval(-daysAgo * 86400)
                }
                let record = TestCalibrationRecord.random(createdAt: createdAt)
                store.append(record)
            }

            // If more than 20 records, oldest get dropped — but we cap at 10 so this won't happen
            let actualTodayCount = store.todayCount()
            guard actualTodayCount == expectedTodayCount else { return false }

            let expectedRemaining = max(3 - expectedTodayCount, 0)
            let actualRemaining = store.challengesRemainingToday()
            guard actualRemaining == expectedRemaining else { return false }

            return true
        }
    }

    /// Edge case: No records means 3 challenges remaining
    /// **Validates: Requirements 4.1**
    func testEdgeCase_EmptyStoreMeans3Remaining() {
        let filePath = tempDir.appendingPathComponent("daily_empty.json")
        let store = TestCalibrationRecordStore(filePath: filePath)

        XCTAssertEqual(store.todayCount(), 0)
        XCTAssertEqual(store.challengesRemainingToday(), 3)
    }

    /// Edge case: Exactly 3 today records means 0 remaining
    /// **Validates: Requirements 4.1, 4.3**
    func testEdgeCase_Exactly3TodayMeans0Remaining() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = utcCalendar.startOfDay(for: Date())

        let filePath = tempDir.appendingPathComponent("daily_3.json")
        let store = TestCalibrationRecordStore(filePath: filePath)

        for i in 0..<3 {
            let record = TestCalibrationRecord.random(createdAt: todayStart.addingTimeInterval(Double(i * 60)))
            store.append(record)
        }

        XCTAssertEqual(store.todayCount(), 3)
        XCTAssertEqual(store.challengesRemainingToday(), 0)
    }

    /// Edge case: More than 3 today records still returns 0 remaining (not negative)
    /// **Validates: Requirements 4.1, 4.3**
    func testEdgeCase_MoreThan3TodayStillReturns0() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = utcCalendar.startOfDay(for: Date())

        let filePath = tempDir.appendingPathComponent("daily_5.json")
        let store = TestCalibrationRecordStore(filePath: filePath)

        for i in 0..<5 {
            let record = TestCalibrationRecord.random(createdAt: todayStart.addingTimeInterval(Double(i * 60)))
            store.append(record)
        }

        XCTAssertEqual(store.todayCount(), 5)
        XCTAssertEqual(store.challengesRemainingToday(), 0, "Should be 0, not negative")
    }

    /// Edge case: Only past records means 3 remaining
    /// **Validates: Requirements 4.2, 4.4**
    func testEdgeCase_OnlyPastRecordsMeans3Remaining() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = utcCalendar.startOfDay(for: Date())

        let filePath = tempDir.appendingPathComponent("daily_past.json")
        let store = TestCalibrationRecordStore(filePath: filePath)

        for i in 1...5 {
            let record = TestCalibrationRecord.random(createdAt: todayStart.addingTimeInterval(Double(-i) * 86400))
            store.append(record)
        }

        XCTAssertEqual(store.todayCount(), 0)
        XCTAssertEqual(store.challengesRemainingToday(), 3)
    }

    /// Edge case: Large number of appends (50) still caps at 20
    /// **Validates: Requirements 2.2, 2.3**
    func testEdgeCase_LargeNumberOfAppends() {
        let filePath = tempDir.appendingPathComponent("records_50.json")
        let store = TestCalibrationRecordStore(filePath: filePath)
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

        var ids: [UUID] = []
        for i in 0..<50 {
            let record = TestCalibrationRecord.random(createdAt: baseTime.addingTimeInterval(Double(i)))
            ids.append(record.id)
            store.append(record)
        }

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 20, "Should cap at 20 even after 50 appends")
        // Should contain the last 20 records (indices 30..49)
        for (idx, record) in loaded.enumerated() {
            XCTAssertEqual(record.id, ids[idx + 30], "Record \(idx) should be ids[\(idx + 30)]")
        }
    }
}
