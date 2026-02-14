import Foundation

// MARK: - Calibration Record

/// 校准记录
/// 记录单次校准挑战的完整信息，包含题目、选项、用户选择、XP 奖励等
struct CalibrationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let type: ChallengeType
    let scenario: String
    let options: [String]
    let selectedOption: Int        // -1 表示使用了自定义答案
    let customAnswer: String?      // selectedOption == -1 时有值（需求 13.6, 13.7）
    let xpEarned: Int
    let ghostResponse: String
    let profileDiff: String?       // LLM 返回的 diff 原始文本
    let createdAt: Date
}

// MARK: - Local Calibration Challenge

/// 本地校准挑战（端上生成）
struct LocalCalibrationChallenge: Codable, Equatable {
    let type: ChallengeType
    let scenario: String
    let options: [String]
    let targetField: String   // "form" | "spirit" | "method"
}

// MARK: - CalibrationRecordStore

/// 校准记录本地存储（最近 20 条）
/// Validates: Requirements 2.2, 2.3, 4.1, 4.2, 4.3, 4.4
class CalibrationRecordStore {

    /// 最多保留的记录数
    static let maxRecords = 20

    /// 每日校准次数上限
    static let dailyLimit = 3

    private let filePath: URL

    /// 默认路径：~/Library/Application Support/GHOSTYPE/ghost_twin/calibration_records.json
    init(filePath: URL? = nil) {
        if let filePath {
            self.filePath = filePath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.filePath = appSupport
                .appendingPathComponent("GHOSTYPE")
                .appendingPathComponent("ghost_twin")
                .appendingPathComponent("calibration_records.json")
        }
    }

    /// 加载所有校准记录，文件不存在或数据损坏时返回空数组
    func loadAll() -> [CalibrationRecord] {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([CalibrationRecord].self, from: data)
        } catch {
            print("[CalibrationRecordStore] 加载记录失败，返回空数组: \(error)")
            return []
        }
    }

    /// 追加一条校准记录，超过 20 条时丢弃最早的
    /// Validates: Requirements 2.2, 2.3
    func append(_ record: CalibrationRecord) {
        var records = loadAll()
        records.append(record)
        // 超过上限时，丢弃最早的记录
        if records.count > Self.maxRecords {
            records = Array(records.suffix(Self.maxRecords))
        }
        do {
            try save(records)
        } catch {
            print("[CalibrationRecordStore] 保存记录失败: \(error)")
        }
    }

    /// 今日已完成挑战数（UTC 0:00 重置）
    /// Validates: Requirements 4.2, 4.4
    func todayCount() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let todayStart = calendar.startOfDay(for: Date())
        return loadAll().filter { $0.createdAt >= todayStart }.count
    }

    /// 今日剩余挑战次数
    /// Validates: Requirements 4.1, 4.3
    func challengesRemainingToday() -> Int {
        max(Self.dailyLimit - todayCount(), 0)
    }

    // MARK: - Private

    private func save(_ records: [CalibrationRecord]) throws {
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
