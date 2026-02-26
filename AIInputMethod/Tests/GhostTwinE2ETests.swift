import XCTest

// MARK: - Test Copies (test target can't import executable)

private struct TestGhostTwinProfile: Codable, Equatable {
    var version: Int
    var level: Int
    var totalXP: Int
    var summary: String
    var profileText: String
    var createdAt: Date
    var updatedAt: Date

    static let initial = TestGhostTwinProfile(
        version: 0, level: 0, totalXP: 0,
        summary: "", profileText: "",
        createdAt: Date(), updatedAt: Date()
    )
}

private struct TestLocalCalibrationChallenge: Codable, Equatable {
    let scenario: String
    let options: [String]
    let targetField: String
}

private struct TestCalibrationRecord: Codable, Equatable, Identifiable {
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
}

private struct TestCalibrationAnalysisResponse: Codable {
    let profileDiff: ProfileDiff
    let ghostResponse: String
    let analysis: String

    struct ProfileDiff: Codable {
        let layer: String
        let description: String
    }
}

private struct TestASRCorpusEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let createdAt: Date
    var consumedAtLevel: Int?
}

private struct TestCalibrationFlowState: Codable, Equatable {
    var phase: String
    var challenge: TestLocalCalibrationChallenge?
    var selectedOption: Int?
    var customAnswer: String?
    var retryCount: Int
    var updatedAt: Date
}

// MARK: - XP Pure Functions (test copy)

private enum TestGhostTwinXP {
    static let xpForLevel0 = 2_000
    static let xpPerLevel = 10_000
    static let maxLevel = 10
    static let calibrationXPReward = 300

    static func calculateLevel(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return 0 }
        let remaining = totalXP - xpForLevel0
        return min(remaining / xpPerLevel + 1, maxLevel)
    }
    static func currentLevelXP(totalXP: Int) -> Int {
        if totalXP < xpForLevel0 { return totalXP }
        let level = calculateLevel(totalXP: totalXP)
        if level >= maxLevel { return totalXP - xpForLevel0 - (maxLevel - 1) * xpPerLevel }
        return (totalXP - xpForLevel0) % xpPerLevel
    }
    static func checkLevelUp(oldXP: Int, newXP: Int) -> (leveledUp: Bool, oldLevel: Int, newLevel: Int) {
        let oldLevel = calculateLevel(totalXP: oldXP)
        let newLevel = calculateLevel(totalXP: newXP)
        return (newLevel > oldLevel, oldLevel, newLevel)
    }
}

// MARK: - LLM JSON Parser (test copy)

private enum TestLLMJsonParser {
    static func parse<T: Decodable>(_ raw: String) throws -> T {
        let cleaned = stripMarkdownCodeBlock(raw)
        guard let data = cleaned.data(using: .utf8) else { fatalError("Invalid encoding") }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    static func stripMarkdownCodeBlock(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: #"^```(?:json|JSON)?\s*\n?"#, with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: #"\n?```\s*$"#, with: "", options: .regularExpression)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - File-based Store Helpers

private class TestProfileStore {
    let filePath: URL
    init(dir: URL) { self.filePath = dir.appendingPathComponent("profile.json") }
    func load() -> TestGhostTwinProfile {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return .initial }
        let data = try! Data(contentsOf: filePath)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(TestGhostTwinProfile.self, from: data)
    }
    func save(_ profile: TestGhostTwinProfile) throws {
        let dir = filePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: filePath, options: .atomic)
    }
}

private class TestRecordStore {
    let filePath: URL
    static let maxRecords = 20
    static let dailyLimit = 3
    init(dir: URL) { self.filePath = dir.appendingPathComponent("calibration_records.json") }
    func loadAll() -> [TestCalibrationRecord] {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return [] }
        let data = try! Data(contentsOf: filePath)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode([TestCalibrationRecord].self, from: data)
    }
    func append(_ record: TestCalibrationRecord) {
        var records = loadAll(); records.append(record)
        if records.count > Self.maxRecords { records = Array(records.suffix(Self.maxRecords)) }
        let dir = filePath.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try! encoder.encode(records).write(to: filePath, options: .atomic)
    }
    func todayCount() -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.startOfDay(for: Date())
        return loadAll().filter { $0.createdAt >= start }.count
    }
    func challengesRemainingToday() -> Int { max(Self.dailyLimit - todayCount(), 0) }
}

private class TestCorpusStore {
    let filePath: URL
    init(dir: URL) { self.filePath = dir.appendingPathComponent("asr_corpus.json") }
    func loadAll() -> [TestASRCorpusEntry] {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return [] }
        let data = try! Data(contentsOf: filePath)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode([TestASRCorpusEntry].self, from: data)
    }
    func append(text: String) {
        var entries = loadAll()
        entries.append(TestASRCorpusEntry(id: UUID(), text: text, createdAt: Date(), consumedAtLevel: nil))
        save(entries)
    }
    func unconsumed() -> [TestASRCorpusEntry] { loadAll().filter { $0.consumedAtLevel == nil } }
    func markConsumed(ids: [UUID], atLevel level: Int) {
        var entries = loadAll()
        for i in entries.indices { if ids.contains(entries[i].id) { entries[i].consumedAtLevel = level } }
        save(entries)
    }
    private func save(_ entries: [TestASRCorpusEntry]) {
        let dir = filePath.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(entries).write(to: filePath, options: .atomic)
    }
}

private class TestRecoveryManager {
    let calibrationPath: URL
    init(dir: URL) { self.calibrationPath = dir.appendingPathComponent("calibration_flow.json") }
    func saveCalibrationFlowState(_ state: TestCalibrationFlowState) {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(state).write(to: calibrationPath, options: .atomic)
    }
    func loadCalibrationFlowState() -> TestCalibrationFlowState? {
        guard FileManager.default.fileExists(atPath: calibrationPath.path) else { return nil }
        let data = try! Data(contentsOf: calibrationPath)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TestCalibrationFlowState.self, from: data)
    }
    func clearCalibrationFlowState() { try? FileManager.default.removeItem(at: calibrationPath) }
}


// MARK: - E2E Test Class

final class GhostTwinE2ETests: XCTestCase {

    private var tempDir: URL!
    private var profileStore: TestProfileStore!
    private var recordStore: TestRecordStore!
    private var corpusStore: TestCorpusStore!
    private var recoveryManager: TestRecoveryManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("GhostTwinE2E_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        profileStore = TestProfileStore(dir: tempDir)
        recordStore = TestRecordStore(dir: tempDir)
        corpusStore = TestCorpusStore(dir: tempDir)
        recoveryManager = TestRecoveryManager(dir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - E2E Test 1: Full Calibration Flow (preset option)

    func testE2E_FullCalibrationFlow_PresetOption() throws {
        var profile = profileStore.load()
        XCTAssertEqual(profile.level, 0)
        XCTAssertEqual(profile.totalXP, 0)
        XCTAssertEqual(recordStore.challengesRemainingToday(), 3)

        // Simulate LLM challenge response (snake_case JSON, parsed via convertFromSnakeCase)
        let mockChallengeJSON = """
        {"scenario": "你的好朋友在背后说你坏话，你偶然听到了。你会怎么做？", "options": ["当面质问", "假装没听到", "找第三方调解"], "target_field": "spirit"}
        """
        let challenge: TestLocalCalibrationChallenge = try TestLLMJsonParser.parse(mockChallengeJSON)
        XCTAssertEqual(challenge.options.count, 3)
        XCTAssertEqual(challenge.targetField, "spirit")

        // Save intermediate state
        let flowState = TestCalibrationFlowState(phase: "challenging", challenge: challenge, selectedOption: nil, customAnswer: nil, retryCount: 0, updatedAt: Date())
        recoveryManager.saveCalibrationFlowState(flowState)
        XCTAssertEqual(recoveryManager.loadCalibrationFlowState()?.phase, "challenging")

        let selectedOption = 1

        // Simulate LLM analysis response (snake_case JSON)
        let mockAnalysisJSON = """
        {"profile_diff": {"layer": "spirit", "description": "用户倾向于避免直接冲突，选择冷处理方式，体现隐忍和大局观"}, "ghost_response": "有意思，你选择了冷处理。", "analysis": "用户倾向于避免直接冲突。"}
        """
        let analysis: TestCalibrationAnalysisResponse = try TestLLMJsonParser.parse(mockAnalysisJSON)
        XCTAssertEqual(analysis.profileDiff.layer, "spirit")

        // XP (unified 300)
        let xpReward = TestGhostTwinXP.calibrationXPReward
        XCTAssertEqual(xpReward, 300)
        let newXP = profile.totalXP + xpReward
        let levelCheck = TestGhostTwinXP.checkLevelUp(oldXP: profile.totalXP, newXP: newXP)
        XCTAssertFalse(levelCheck.leveledUp)

        profile.totalXP = newXP
        profile.level = TestGhostTwinXP.calculateLevel(totalXP: newXP)
        profile.version += 1
        try profileStore.save(profile)

        let reloaded = profileStore.load()
        XCTAssertEqual(reloaded.totalXP, 300)

        let record = TestCalibrationRecord(
            id: UUID(), scenario: challenge.scenario, options: challenge.options,
            selectedOption: selectedOption, customAnswer: nil, xpEarned: xpReward,
            ghostResponse: analysis.ghostResponse, profileDiff: mockAnalysisJSON,
            analysis: analysis.analysis, consumedAtLevel: nil, createdAt: Date()
        )
        recordStore.append(record)
        XCTAssertEqual(recordStore.loadAll().count, 1)
        XCTAssertEqual(recordStore.challengesRemainingToday(), 2)

        recoveryManager.clearCalibrationFlowState()
        XCTAssertNil(recoveryManager.loadCalibrationFlowState())
    }

    // MARK: - E2E Test 2: Custom Answer Flow

    func testE2E_CustomAnswerFlow() throws {
        var profile = TestGhostTwinProfile(version: 1, level: 1, totalXP: 2300, summary: "", profileText: "初始档案", createdAt: Date(), updatedAt: Date())
        try profileStore.save(profile)

        let challenge = TestLocalCalibrationChallenge(scenario: "以下哪段话更像你会说的？", options: ["我觉得这件事需要再想想", "直接干就完了"], targetField: "form")
        let customAnswer = "我会先问问朋友的意见再决定"

        let mockAnalysisJSON = """
        {"profile_diff": {"layer": "form", "description": "用户倾向于咨询他人意见后再做决定，体现协商型决策风格"}, "ghost_response": "你不走寻常路啊。", "analysis": "用户选择自定义答案。"}
        """
        let _: TestCalibrationAnalysisResponse = try TestLLMJsonParser.parse(mockAnalysisJSON)

        profile.totalXP += TestGhostTwinXP.calibrationXPReward
        profile.level = TestGhostTwinXP.calculateLevel(totalXP: profile.totalXP)
        profile.version += 1
        try profileStore.save(profile)

        let record = TestCalibrationRecord(
            id: UUID(), scenario: challenge.scenario, options: challenge.options,
            selectedOption: -1, customAnswer: customAnswer, xpEarned: TestGhostTwinXP.calibrationXPReward,
            ghostResponse: "你不走寻常路啊。", profileDiff: nil,
            analysis: "用户选择自定义答案。", consumedAtLevel: nil, createdAt: Date()
        )
        recordStore.append(record)

        let reloaded = profileStore.load()
        XCTAssertEqual(reloaded.totalXP, 2600)
        XCTAssertEqual(recordStore.loadAll().first?.selectedOption, -1)
        XCTAssertEqual(recordStore.loadAll().first?.customAnswer, customAnswer)
    }

    // MARK: - E2E Test 3: Level-Up Detection

    func testE2E_LevelUpDetection() throws {
        var profile = TestGhostTwinProfile(version: 5, level: 1, totalXP: 11800, summary: "", profileText: "档案内容", createdAt: Date(), updatedAt: Date())
        try profileStore.save(profile)

        // 300 XP: 11800 + 300 = 12100 → Lv.2
        let oldXP = profile.totalXP
        let newXP = oldXP + TestGhostTwinXP.calibrationXPReward
        let levelCheck = TestGhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: newXP)
        XCTAssertTrue(levelCheck.leveledUp)
        XCTAssertEqual(levelCheck.newLevel, 2)

        profile.totalXP = newXP
        profile.level = TestGhostTwinXP.calculateLevel(totalXP: newXP)
        try profileStore.save(profile)
        XCTAssertEqual(profileStore.load().level, 2)
    }

    // MARK: - E2E Test 4: Daily Limit

    func testE2E_DailyLimitEnforcement() throws {
        XCTAssertEqual(recordStore.challengesRemainingToday(), 3)
        for i in 0..<3 {
            recordStore.append(TestCalibrationRecord(
                id: UUID(), scenario: "场景\(i)", options: ["A", "B"],
                selectedOption: 0, customAnswer: nil, xpEarned: 300,
                ghostResponse: "反馈\(i)", profileDiff: nil,
                analysis: nil, consumedAtLevel: nil, createdAt: Date()
            ))
        }
        XCTAssertEqual(recordStore.challengesRemainingToday(), 0)
    }

    // MARK: - E2E Test 5: Record Store Max-20

    func testE2E_RecordStoreMax20() throws {
        for i in 0..<25 {
            recordStore.append(TestCalibrationRecord(
                id: UUID(), scenario: "场景\(i)", options: ["A"],
                selectedOption: 0, customAnswer: nil, xpEarned: 300,
                ghostResponse: "反馈", profileDiff: nil,
                analysis: nil, consumedAtLevel: nil, createdAt: Date()
            ))
        }
        let records = recordStore.loadAll()
        XCTAssertEqual(records.count, 20)
        XCTAssertEqual(records[0].scenario, "场景5")
    }

    // MARK: - E2E Test 6: ASR Corpus

    func testE2E_ASRCorpusFlow() throws {
        corpusStore.append(text: "今天天气真不错")
        corpusStore.append(text: "我觉得这个方案可以再优化一下")
        XCTAssertEqual(corpusStore.unconsumed().count, 2)
        let ids = corpusStore.unconsumed().map { $0.id }
        corpusStore.markConsumed(ids: ids, atLevel: 2)
        XCTAssertEqual(corpusStore.unconsumed().count, 0)
        corpusStore.append(text: "新的语料")
        XCTAssertEqual(corpusStore.unconsumed().count, 1)
    }

    // MARK: - E2E Test 7: Recovery

    func testE2E_RecoveryFromCrash() throws {
        let challenge = TestLocalCalibrationChallenge(scenario: "测试恢复场景", options: ["选项A", "选项B"], targetField: "spirit")
        recoveryManager.saveCalibrationFlowState(TestCalibrationFlowState(phase: "analyzing", challenge: challenge, selectedOption: 0, customAnswer: nil, retryCount: 0, updatedAt: Date()))
        let recovered = recoveryManager.loadCalibrationFlowState()
        XCTAssertEqual(recovered?.phase, "analyzing")
        XCTAssertEqual(recovered?.challenge, challenge)
        recoveryManager.clearCalibrationFlowState()
        XCTAssertNil(recoveryManager.loadCalibrationFlowState())
    }

    // MARK: - E2E Test 8: Multi-Round XP Accumulation

    func testE2E_MultiRoundXPAccumulation() throws {
        var profile = TestGhostTwinProfile.initial
        let rounds = 3
        for _ in 0..<rounds {
            profile.totalXP += TestGhostTwinXP.calibrationXPReward
            profile.level = TestGhostTwinXP.calculateLevel(totalXP: profile.totalXP)
            profile.version += 1
        }
        try profileStore.save(profile)
        let final = profileStore.load()
        XCTAssertEqual(final.totalXP, 900)
    }

    // MARK: - E2E Test 9: Markdown Code Block Stripping

    func testE2E_MarkdownCodeBlockStripping() throws {
        let wrappedJSON = """
        ```json
        {"scenario": "你觉得明天会下雨吗？", "options": ["会", "不会"], "target_field": "method"}
        ```
        """
        let challenge: TestLocalCalibrationChallenge = try TestLLMJsonParser.parse(wrappedJSON)
        XCTAssertEqual(challenge.scenario, "你觉得明天会下雨吗？")
        XCTAssertEqual(challenge.targetField, "method")
    }

    // MARK: - E2E Test 10: Full Journey Lv.1 → Lv.2

    func testE2E_FullJourneyLv1ToLv2() throws {
        var profile = TestGhostTwinProfile.initial
        // 300 XP × 41 rounds = 12300 XP → Lv.2 (Lv.2 starts at 12000)
        let roundsNeeded = 41
        for i in 0..<roundsNeeded {
            let oldXP = profile.totalXP
            profile.totalXP += TestGhostTwinXP.calibrationXPReward
            profile.level = TestGhostTwinXP.calculateLevel(totalXP: profile.totalXP)
            profile.version += 1
            recordStore.append(TestCalibrationRecord(
                id: UUID(), scenario: "挑战\(i)", options: ["A", "B"],
                selectedOption: i % 2, customAnswer: nil, xpEarned: TestGhostTwinXP.calibrationXPReward,
                ghostResponse: "反馈\(i)", profileDiff: nil,
                analysis: nil, consumedAtLevel: nil, createdAt: Date()
            ))
            if profile.level == 2 && TestGhostTwinXP.calculateLevel(totalXP: oldXP) == 1 {
                let check = TestGhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: profile.totalXP)
                XCTAssertTrue(check.leveledUp)
            }
        }
        try profileStore.save(profile)
        let final = profileStore.load()
        XCTAssertEqual(final.level, 2)
        XCTAssertEqual(final.totalXP, 12300)
        XCTAssertEqual(recordStore.loadAll().count, 20)
    }
}
