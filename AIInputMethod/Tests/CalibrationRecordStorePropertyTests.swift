//
//  CalibrationRecordStorePropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for CalibrationRecordStore max-20 invariant
//  Feature: ghost-twin-on-device, Property 3: Record store max-20 invariant
//

import XCTest
import Foundation

// MARK: - Test Copy of CalibrationRecord

private struct TestCalibrationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let scenario: String
    let options: [String]
    let selectedOption: Int
    let customAnswer: String?
    let xpEarned: Int
    let ghostResponse: String
    let profileDiff: String?
    let analysis: String?
    var consumedAtLevel: Int?
    let createdAt: Date

    static func random(createdAt: Date = Date()) -> TestCalibrationRecord {
        let useCustom = Bool.random()
        return TestCalibrationRecord(
            id: UUID(),
            scenario: "场景\(Int.random(in: 1...100))",
            options: ["A", "B", "C"],
            selectedOption: useCustom ? -1 : Int.random(in: 0...2),
            customAnswer: useCustom ? "自定义答案" : nil,
            xpEarned: 300,
            ghostResponse: "反馈 👻",
            profileDiff: Bool.random() ? "{\"layer\":\"spirit\"}" : nil,
            analysis: Bool.random() ? "分析过程" : nil,
            consumedAtLevel: nil,
            createdAt: createdAt
        )
    }
}

// MARK: - Test Copy of CalibrationRecordStore

private class TestCalibrationRecordStore {
    static let maxRecords = 20
    private let filePath: URL

    init(filePath: URL) { self.filePath = filePath }

    func loadAll() -> [TestCalibrationRecord] {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return [] }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TestCalibrationRecord].self, from: data)
        } catch { return [] }
    }

    func append(_ record: TestCalibrationRecord) {
        var records = loadAll()
        records.append(record)
        if records.count > Self.maxRecords { records = Array(records.suffix(Self.maxRecords)) }
        do { try save(records) } catch {}
    }

    static let dailyLimit = 3

    func todayCount() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = calendar.startOfDay(for: Date())
        return loadAll().filter { $0.createdAt >= todayStart }.count
    }

    func challengesRemainingToday() -> Int { max(Self.dailyLimit - todayCount(), 0) }

    private func save(_ records: [TestCalibrationRecord]) throws {
        let directory = filePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: filePath, options: .atomic)
    }
}


// MARK: - Property Tests

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

    /// Property 3: Record store max-20 invariant
    /// **Validates: Requirements 2.2, 2.3**
    func testProperty3_RecordStoreMax20Invariant() {
        PropertyTest.verify("CalibrationRecordStore max-20 invariant", iterations: 100) {
            let filePath = self.tempDir.appendingPathComponent("records_\(UUID().uuidString).json")
            let store = TestCalibrationRecordStore(filePath: filePath)
            let n = Int.random(in: 1...30)
            var allAppended: [TestCalibrationRecord] = []
            let baseTime = Date(timeIntervalSince1970: Double(Int.random(in: 1_000_000...1_900_000_000)))
            for i in 0..<n {
                let record = TestCalibrationRecord.random(createdAt: baseTime.addingTimeInterval(Double(i)))
                allAppended.append(record)
                store.append(record)
            }
            let loaded = store.loadAll()
            guard loaded.count <= 20 else { return false }
            guard loaded.count == min(n, 20) else { return false }
            let expectedRecords = Array(allAppended.suffix(min(n, 20)))
            for (idx, record) in loaded.enumerated() {
                guard record.id == expectedRecords[idx].id else { return false }
            }
            for i in 1..<loaded.count {
                guard loaded[i].createdAt >= loaded[i - 1].createdAt else { return false }
            }
            return true
        }
    }

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
        XCTAssertEqual(loaded.count, 20)
        for (idx, record) in loaded.enumerated() { XCTAssertEqual(record.id, ids[idx]) }
    }

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
        XCTAssertEqual(loaded.count, 20)
        for (idx, record) in loaded.enumerated() { XCTAssertEqual(record.id, ids[idx + 1]) }
    }

    func testEdgeCase_EmptyStore() {
        let filePath = tempDir.appendingPathComponent("records_empty.json")
        let store = TestCalibrationRecordStore(filePath: filePath)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    /// Property 7: Daily challenge limit
    /// **Validates: Requirements 4.1, 4.2, 4.3**
    func testProperty7_DailyChallengeLimit() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let todayStart = utcCalendar.startOfDay(for: now)

        PropertyTest.verify("Daily challenge limit", iterations: 100) {
            let filePath = self.tempDir.appendingPathComponent("daily_\(UUID().uuidString).json")
            let store = TestCalibrationRecordStore(filePath: filePath)
            let totalRecords = Int.random(in: 0...10)
            var expectedTodayCount = 0
            for _ in 0..<totalRecords {
                let isToday = Bool.random()
                let createdAt: Date
                if isToday {
                    createdAt = todayStart.addingTimeInterval(Double.random(in: 0..<min(now.timeIntervalSince(todayStart), 86400)))
                    expectedTodayCount += 1
                } else {
                    createdAt = todayStart.addingTimeInterval(-Double.random(in: 1...365) * 86400)
                }
                store.append(TestCalibrationRecord.random(createdAt: createdAt))
            }
            guard store.todayCount() == expectedTodayCount else { return false }
            guard store.challengesRemainingToday() == max(3 - expectedTodayCount, 0) else { return false }
            return true
        }
    }

    func testEdgeCase_EmptyStoreMeans3Remaining() {
        let filePath = tempDir.appendingPathComponent("daily_empty.json")
        let store = TestCalibrationRecordStore(filePath: filePath)
        XCTAssertEqual(store.challengesRemainingToday(), 3)
    }

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
        XCTAssertEqual(loaded.count, 20)
        for (idx, record) in loaded.enumerated() { XCTAssertEqual(record.id, ids[idx + 30]) }
    }
}
