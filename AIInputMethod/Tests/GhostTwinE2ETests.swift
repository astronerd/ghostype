import XCTest

// MARK: - Test Copies (test target can't import executable)

private enum TestChallengeType: String, Codable, CaseIterable {
    case dilemma
    case reverseTuring = "reverse_turing"
    case prediction
}

private struct TestGhostTwinProfile: Codable, Equatable {
    var version: Int
    var level: Int
    var totalXP: Int
    var personalityTags: [String]
    var profileText: String
    var createdAt: Date
    var updatedAt: Date

    static let initial = TestGhostTwinProfile(
        version: 0, level: 1, totalXP: 0,
        personalityTags: [], profileText: "",
        createdAt: Date(), updatedAt: Date()
    )
}

private struct TestLocalCalibrationChallenge: Codable, Equatable {
    let type: TestChallengeType
    let scenario: String
    let options: [String]
    let targetField: String
}

private struct TestCalibrationRecord: Codable, Equatable, Identifiable {
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
}

private struct TestCalibrationAnalysisResponse: Codable {
    let profile_diff: ProfileDiff
    let ghost_response: String
    let analysis: String

    struct ProfileDiff: Codable {
        let layer: String
        let changes: [String: String]
        let new_tags: [String]
    }
}

private struct TestASRCorpusEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let createdAt: Date
    var consumedAtLevel: Int?
}

private struct TestCalibrationFlowState: Codable, Equatable {
    var phase: String  // "idle" | "challenging" | "analyzing"
    var challenge: TestLocalCalibrationChallenge?
    var selectedOption: Int?
    var customAnswer: String?
    var retryCount: Int
    var updatedAt: Date
}

// MARK: - XP Pure Functions (test copy)

private enum TestGhostTwinXP {
    static let xpPerLevel = 10_000
    static let maxLevel = 10

    static func calculateLevel(totalXP: Int) -> Int {
        min(totalXP / xpPerLevel + 1, maxLevel)
    }

    static func currentLevelXP(totalXP: Int) -> Int {
        let level = calculateLevel(totalXP: totalXP)
        if level >= maxLevel { return totalXP - (maxLevel - 1) * xpPerLevel }
        return totalXP % xpPerLevel
    }

    static func checkLevelUp(oldXP: Int, newXP: Int) -> (leveledUp: Bool, oldLevel: Int, newLevel: Int) {
        let oldLevel = calculateLevel(totalXP: oldXP)
        let newLevel = calculateLevel(totalXP: newXP)
        return (newLevel > oldLevel, oldLevel, newLevel)
    }

    static func xpReward(for type: TestChallengeType) -> Int {
        switch type {
        case .dilemma: return 500
        case .reverseTuring: return 300
        case .prediction: return 200
        }
    }
}

// MARK: - LLM JSON Parser (test copy)

private enum TestLLMJsonParser {
    static func parse<T: Decodable>(_ raw: String) throws -> T {
        let cleaned = stripMarkdownCodeBlock(raw)
        guard let data = cleaned.data(using: .utf8) else {
            fatalError("Invalid encoding")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func stripMarkdownCodeBlock(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(
                of: #"^```(?:json|JSON)?\s*\n?"#, with: "", options: .regularExpression
            )
            cleaned = cleaned.replacingOccurrences(
                of: #"\n?```\s*$"#, with: "", options: .regularExpression
            )
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


// MARK: - File-based Store Helpers

private class TestProfileStore {
    let filePath: URL

    init(dir: URL) {
        self.filePath = dir.appendingPathComponent("profile.json")
    }

    func load() -> TestGhostTwinProfile {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return .initial }
        let data = try! Data(contentsOf: filePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(TestGhostTwinProfile.self, from: data)
    }

    func save(_ profile: TestGhostTwinProfile) throws {
        let dir = filePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: filePath, options: .atomic)
    }
}

private class TestRecordStore {
    let filePath: URL
    static let maxRecords = 20
    static let dailyLimit = 3

    init(dir: URL) {
        self.filePath = dir.appendingPathComponent("calibration_records.json")
    }

    func loadAll() -> [TestCalibrationRecord] {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return [] }
        let data = try! Data(contentsOf: filePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode([TestCalibrationRecord].self, from: data)
    }

    func append(_ record: TestCalibrationRecord) {
        var records = loadAll()
        records.append(record)
        if records.count > Self.maxRecords {
            records = Array(records.suffix(Self.maxRecords))
        }
        let dir = filePath.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try! encoder.encode(records).write(to: filePath, options: .atomic)
    }

    func todayCount() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.startOfDay(for: Date())
        return loadAll().filter { $0.createdAt >= start }.count
    }

    func challengesRemainingToday() -> Int {
        max(Self.dailyLimit - todayCount(), 0)
    }
}

private class TestCorpusStore {
    let filePath: URL

    init(dir: URL) {
        self.filePath = dir.appendingPathComponent("asr_corpus.json")
    }

    func loadAll() -> [TestASRCorpusEntry] {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return [] }
        let data = try! Data(contentsOf: filePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode([TestASRCorpusEntry].self, from: data)
    }

    func append(text: String) {
        var entries = loadAll()
        entries.append(TestASRCorpusEntry(id: UUID(), text: text, createdAt: Date(), consumedAtLevel: nil))
        save(entries)
    }

    func unconsumed() -> [TestASRCorpusEntry] {
        loadAll().filter { $0.consumedAtLevel == nil }
    }

    func markConsumed(ids: [UUID], atLevel level: Int) {
        var entries = loadAll()
        for i in entries.indices {
            if ids.contains(entries[i].id) {
                entries[i].consumedAtLevel = level
            }
        }
        save(entries)
    }

    private func save(_ entries: [TestASRCorpusEntry]) {
        let dir = filePath.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(entries).write(to: filePath, options: .atomic)
    }
}

private class TestRecoveryManager {
    let calibrationPath: URL
    let profilingPath: URL

    init(dir: URL) {
        self.calibrationPath = dir.appendingPathComponent("calibration_flow.json")
        self.profilingPath = dir.appendingPathComponent("profiling_flow.json")
    }

    func saveCalibrationFlowState(_ state: TestCalibrationFlowState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(state).write(to: calibrationPath, options: .atomic)
    }

    func loadCalibrationFlowState() -> TestCalibrationFlowState? {
        guard FileManager.default.fileExists(atPath: calibrationPath.path) else { return nil }
        let data = try! Data(contentsOf: calibrationPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TestCalibrationFlowState.self, from: data)
    }

    func clearCalibrationFlowState() {
        try? FileManager.default.removeItem(at: calibrationPath)
    }
}


// MARK: - E2E Test Class

/// Ghost Twin 端到端流程测试
/// 模拟完整的校准流程：初始化 → 出题 → 答题 → XP/升级 → 记录持久化 → 恢复
/// 不依赖真实 LLM，用 mock JSON 模拟 LLM 返回
final class GhostTwinE2ETests: XCTestCase {

    private var tempDir: URL!
    private var profileStore: TestProfileStore!
    private var recordStore: TestRecordStore!
    private var corpusStore: TestCorpusStore!
    private var recoveryManager: TestRecoveryManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GhostTwinE2E_\(UUID().uuidString)")
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

    /// 完整校准流程：初始 profile → LLM 出题 → 用户选预设选项 → LLM 分析 → XP 累加 → 记录保存
    func testE2E_FullCalibrationFlow_PresetOption() throws {
        // === Step 1: Initial state ===
        var profile = profileStore.load()
        XCTAssertEqual(profile.level, 1)
        XCTAssertEqual(profile.totalXP, 0)
        XCTAssertEqual(profile.personalityTags, [])
        XCTAssertEqual(recordStore.challengesRemainingToday(), 3)

        // === Step 2: Simulate LLM challenge response ===
        let mockChallengeJSON = """
        {
            "type": "dilemma",
            "scenario": "你的好朋友在背后说你坏话，你偶然听到了。你会怎么做？",
            "options": ["当面质问", "假装没听到", "找第三方调解"],
            "targetField": "spirit"
        }
        """
        let challenge: TestLocalCalibrationChallenge = try TestLLMJsonParser.parse(mockChallengeJSON)
        XCTAssertEqual(challenge.type, .dilemma)
        XCTAssertEqual(challenge.options.count, 3)

        // === Step 3: Save intermediate state (challenging phase) ===
        let flowState = TestCalibrationFlowState(
            phase: "challenging",
            challenge: challenge,
            selectedOption: nil,
            customAnswer: nil,
            retryCount: 0,
            updatedAt: Date()
        )
        recoveryManager.saveCalibrationFlowState(flowState)
        let recovered = recoveryManager.loadCalibrationFlowState()
        XCTAssertEqual(recovered?.phase, "challenging")
        XCTAssertEqual(recovered?.challenge, challenge)

        // === Step 4: User selects option 1 ("假装没听到") ===
        let selectedOption = 1

        // === Step 5: Simulate LLM analysis response ===
        let mockAnalysisJSON = """
        {
            "profile_diff": {
                "layer": "spirit",
                "changes": {"conflict_style": "avoidant → diplomatic"},
                "new_tags": ["隐忍型", "大局观"]
            },
            "ghost_response": "有意思，你选择了冷处理。看来你更在意关系的长期稳定。",
            "analysis": "用户倾向于避免直接冲突，优先维护关系和谐。"
        }
        """
        let analysis: TestCalibrationAnalysisResponse = try TestLLMJsonParser.parse(mockAnalysisJSON)
        XCTAssertEqual(analysis.profile_diff.new_tags, ["隐忍型", "大局观"])

        // === Step 6: Merge tags ===
        var updatedTags = profile.personalityTags
        for tag in analysis.profile_diff.new_tags {
            if !updatedTags.contains(tag) { updatedTags.append(tag) }
        }
        XCTAssertEqual(updatedTags, ["隐忍型", "大局观"])

        // === Step 7: Calculate XP ===
        let xpReward = TestGhostTwinXP.xpReward(for: challenge.type)
        XCTAssertEqual(xpReward, 500) // dilemma = 500
        let oldXP = profile.totalXP
        let newXP = oldXP + xpReward
        let levelCheck = TestGhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: newXP)
        XCTAssertFalse(levelCheck.leveledUp) // 0 → 500, still Lv.1
        XCTAssertEqual(TestGhostTwinXP.calculateLevel(totalXP: newXP), 1)

        // === Step 8: Update and save profile ===
        profile.personalityTags = updatedTags
        profile.totalXP = newXP
        profile.level = TestGhostTwinXP.calculateLevel(totalXP: newXP)
        profile.version += 1
        profile.updatedAt = Date()
        try profileStore.save(profile)

        // Verify profile persisted
        let reloaded = profileStore.load()
        XCTAssertEqual(reloaded.totalXP, 500)
        XCTAssertEqual(reloaded.level, 1)
        XCTAssertEqual(reloaded.personalityTags, ["隐忍型", "大局观"])
        XCTAssertEqual(reloaded.version, 1)

        // === Step 9: Save calibration record ===
        let record = TestCalibrationRecord(
            id: UUID(),
            type: challenge.type,
            scenario: challenge.scenario,
            options: challenge.options,
            selectedOption: selectedOption,
            customAnswer: nil,
            xpEarned: xpReward,
            ghostResponse: analysis.ghost_response,
            profileDiff: mockAnalysisJSON,
            createdAt: Date()
        )
        recordStore.append(record)

        let records = recordStore.loadAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].selectedOption, 1)
        XCTAssertNil(records[0].customAnswer)
        XCTAssertEqual(records[0].xpEarned, 500)

        // === Step 10: Challenges remaining ===
        XCTAssertEqual(recordStore.challengesRemainingToday(), 2)

        // === Step 11: Clear flow state ===
        recoveryManager.clearCalibrationFlowState()
        XCTAssertNil(recoveryManager.loadCalibrationFlowState())

        print("✅ E2E Test 1 PASSED: Full calibration flow with preset option")
    }

    // MARK: - E2E Test 2: Custom Answer Flow

    /// 自定义答案流程：用户不选预设选项，自己输入答案
    func testE2E_CustomAnswerFlow() throws {
        // Setup: give profile some existing state
        var profile = TestGhostTwinProfile(
            version: 1, level: 1, totalXP: 500,
            personalityTags: ["隐忍型", "大局观"],
            profileText: "初始档案",
            createdAt: Date(), updatedAt: Date()
        )
        try profileStore.save(profile)

        // Simulate challenge
        let challenge = TestLocalCalibrationChallenge(
            type: .reverseTuring,
            scenario: "以下哪段话更像你会说的？",
            options: ["我觉得这件事需要再想想", "直接干就完了"],
            targetField: "form"
        )

        // User provides custom answer
        let customAnswer = "我会先问问朋友的意见再决定"

        // Whitespace validation
        XCTAssertFalse(customAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue("   \n\t  ".trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // Simulate LLM analysis
        let mockAnalysisJSON = """
        {
            "profile_diff": {
                "layer": "form",
                "changes": {"decision_style": "independent → consultative"},
                "new_tags": ["协商型"]
            },
            "ghost_response": "你不走寻常路啊，自己写答案。看来你是个有主见但也重视他人意见的人。",
            "analysis": "用户选择自定义答案，表明对预设选项不满意，倾向于协商式决策。"
        }
        """
        let analysis: TestCalibrationAnalysisResponse = try TestLLMJsonParser.parse(mockAnalysisJSON)

        // Merge tags
        for tag in analysis.profile_diff.new_tags {
            if !profile.personalityTags.contains(tag) { profile.personalityTags.append(tag) }
        }

        // XP
        let xpReward = TestGhostTwinXP.xpReward(for: .reverseTuring)
        XCTAssertEqual(xpReward, 300)
        profile.totalXP += xpReward
        profile.level = TestGhostTwinXP.calculateLevel(totalXP: profile.totalXP)
        profile.version += 1
        try profileStore.save(profile)

        // Record with custom answer: selectedOption = -1
        let record = TestCalibrationRecord(
            id: UUID(),
            type: challenge.type,
            scenario: challenge.scenario,
            options: challenge.options,
            selectedOption: -1,
            customAnswer: customAnswer,
            xpEarned: xpReward,
            ghostResponse: analysis.ghost_response,
            profileDiff: nil,
            createdAt: Date()
        )
        recordStore.append(record)

        // Verify
        let reloaded = profileStore.load()
        XCTAssertEqual(reloaded.totalXP, 800)
        XCTAssertEqual(reloaded.personalityTags, ["隐忍型", "大局观", "协商型"])

        let records = recordStore.loadAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].selectedOption, -1)
        XCTAssertEqual(records[0].customAnswer, "我会先问问朋友的意见再决定")

        print("✅ E2E Test 2 PASSED: Custom answer flow")
    }

    // MARK: - E2E Test 3: Level-Up Detection

    /// 升级检测：XP 跨越等级边界时触发升级
    func testE2E_LevelUpDetection() throws {
        var profile = TestGhostTwinProfile(
            version: 5, level: 1, totalXP: 9700,
            personalityTags: ["隐忍型"],
            profileText: "档案内容",
            createdAt: Date(), updatedAt: Date()
        )
        try profileStore.save(profile)

        // dilemma = 500 XP, 9700 + 500 = 10200 → Lv.2
        let xpReward = TestGhostTwinXP.xpReward(for: .dilemma)
        let oldXP = profile.totalXP
        let newXP = oldXP + xpReward
        let levelCheck = TestGhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: newXP)

        XCTAssertTrue(levelCheck.leveledUp)
        XCTAssertEqual(levelCheck.oldLevel, 1)
        XCTAssertEqual(levelCheck.newLevel, 2)

        profile.totalXP = newXP
        profile.level = TestGhostTwinXP.calculateLevel(totalXP: newXP)
        try profileStore.save(profile)

        XCTAssertEqual(profileStore.load().level, 2)
        XCTAssertEqual(TestGhostTwinXP.currentLevelXP(totalXP: newXP), 200)

        print("✅ E2E Test 3 PASSED: Level-up detection")
    }

    // MARK: - E2E Test 4: Daily Limit Enforcement

    /// 每日 3 次限制
    func testE2E_DailyLimitEnforcement() throws {
        XCTAssertEqual(recordStore.challengesRemainingToday(), 3)

        for i in 0..<3 {
            let record = TestCalibrationRecord(
                id: UUID(), type: .prediction,
                scenario: "场景\(i)", options: ["A", "B"],
                selectedOption: 0, customAnswer: nil,
                xpEarned: 200, ghostResponse: "反馈\(i)",
                profileDiff: nil, createdAt: Date()
            )
            recordStore.append(record)
        }

        XCTAssertEqual(recordStore.challengesRemainingToday(), 0)
        XCTAssertEqual(recordStore.todayCount(), 3)

        print("✅ E2E Test 4 PASSED: Daily limit enforcement")
    }

    // MARK: - E2E Test 5: Record Store Max-20 Invariant

    /// 记录上限 20 条
    func testE2E_RecordStoreMax20() throws {
        for i in 0..<25 {
            let record = TestCalibrationRecord(
                id: UUID(), type: .prediction,
                scenario: "场景\(i)", options: ["A"],
                selectedOption: 0, customAnswer: nil,
                xpEarned: 200, ghostResponse: "反馈",
                profileDiff: nil, createdAt: Date()
            )
            recordStore.append(record)
        }

        let records = recordStore.loadAll()
        XCTAssertEqual(records.count, 20)
        // Oldest should be dropped — first record should be scenario 5
        XCTAssertEqual(records[0].scenario, "场景5")

        print("✅ E2E Test 5 PASSED: Record store max-20 invariant")
    }

    // MARK: - E2E Test 6: ASR Corpus Collection & Consumption

    /// ASR 语料收集和消费
    func testE2E_ASRCorpusFlow() throws {
        // Simulate voice input collecting corpus
        corpusStore.append(text: "今天天气真不错")
        corpusStore.append(text: "我觉得这个方案可以再优化一下")
        corpusStore.append(text: "帮我订一下明天的会议室")

        XCTAssertEqual(corpusStore.loadAll().count, 3)
        XCTAssertEqual(corpusStore.unconsumed().count, 3)

        // Simulate profiling consuming corpus at level 2
        let unconsumed = corpusStore.unconsumed()
        let ids = unconsumed.map { $0.id }
        corpusStore.markConsumed(ids: ids, atLevel: 2)

        XCTAssertEqual(corpusStore.unconsumed().count, 0)
        XCTAssertEqual(corpusStore.loadAll().count, 3)
        XCTAssertTrue(corpusStore.loadAll().allSatisfy { $0.consumedAtLevel == 2 })

        // New corpus after consumption
        corpusStore.append(text: "新的语料")
        XCTAssertEqual(corpusStore.unconsumed().count, 1)

        print("✅ E2E Test 6 PASSED: ASR corpus collection & consumption")
    }

    // MARK: - E2E Test 7: Recovery from Crash

    /// 崩溃恢复：模拟 analyzing 阶段崩溃后恢复
    func testE2E_RecoveryFromCrash() throws {
        let challenge = TestLocalCalibrationChallenge(
            type: .dilemma,
            scenario: "测试恢复场景",
            options: ["选项A", "选项B"],
            targetField: "spirit"
        )

        // Simulate crash during analyzing phase
        let flowState = TestCalibrationFlowState(
            phase: "analyzing",
            challenge: challenge,
            selectedOption: 0,
            customAnswer: nil,
            retryCount: 0,
            updatedAt: Date()
        )
        recoveryManager.saveCalibrationFlowState(flowState)

        // App restarts — check recovery
        let recovered = recoveryManager.loadCalibrationFlowState()
        XCTAssertNotNil(recovered)
        XCTAssertEqual(recovered?.phase, "analyzing")
        XCTAssertEqual(recovered?.challenge, challenge)
        XCTAssertEqual(recovered?.selectedOption, 0)

        // After successful retry, clear state
        recoveryManager.clearCalibrationFlowState()
        XCTAssertNil(recoveryManager.loadCalibrationFlowState())

        print("✅ E2E Test 7 PASSED: Recovery from crash")
    }

    // MARK: - E2E Test 8: Multi-Round Calibration with Tag Accumulation

    /// 多轮校准：标签累积不重复
    func testE2E_MultiRoundTagAccumulation() throws {
        var profile = TestGhostTwinProfile.initial
        try profileStore.save(profile)

        let rounds: [(TestChallengeType, [String])] = [
            (.dilemma, ["隐忍型", "大局观"]),
            (.reverseTuring, ["大局观", "协商型"]),  // "大局观" already exists
            (.prediction, ["直觉型"]),
        ]

        for (type, newTags) in rounds {
            for tag in newTags {
                if !profile.personalityTags.contains(tag) {
                    profile.personalityTags.append(tag)
                }
            }
            let xp = TestGhostTwinXP.xpReward(for: type)
            profile.totalXP += xp
            profile.level = TestGhostTwinXP.calculateLevel(totalXP: profile.totalXP)
            profile.version += 1
        }

        try profileStore.save(profile)
        let final = profileStore.load()

        // Tags should be deduplicated
        XCTAssertEqual(final.personalityTags, ["隐忍型", "大局观", "协商型", "直觉型"])
        // XP: 500 + 300 + 200 = 1000
        XCTAssertEqual(final.totalXP, 1000)
        XCTAssertEqual(final.level, 1)
        XCTAssertEqual(final.version, 3)

        print("✅ E2E Test 8 PASSED: Multi-round tag accumulation (no duplicates)")
    }

    // MARK: - E2E Test 9: Markdown Code Block Stripping

    /// LLM 返回带 markdown 包裹的 JSON
    func testE2E_MarkdownCodeBlockStripping() throws {
        let wrappedJSON = """
        ```json
        {
            "type": "prediction",
            "scenario": "你觉得明天会下雨吗？",
            "options": ["会", "不会"],
            "targetField": "method"
        }
        ```
        """
        let challenge: TestLocalCalibrationChallenge = try TestLLMJsonParser.parse(wrappedJSON)
        XCTAssertEqual(challenge.type, .prediction)
        XCTAssertEqual(challenge.scenario, "你觉得明天会下雨吗？")

        print("✅ E2E Test 9 PASSED: Markdown code block stripping")
    }

    // MARK: - E2E Test 10: Full Journey from Lv.1 to Lv.2

    /// 完整旅程：从 Lv.1 到 Lv.2（需要 10000 XP = 20 次 dilemma）
    func testE2E_FullJourneyLv1ToLv2() throws {
        var profile = TestGhostTwinProfile.initial
        try profileStore.save(profile)

        // 20 rounds of dilemma (500 XP each) = 10000 XP → Lv.2
        for i in 0..<20 {
            let oldXP = profile.totalXP
            let xp = TestGhostTwinXP.xpReward(for: .dilemma)
            profile.totalXP += xp
            profile.level = TestGhostTwinXP.calculateLevel(totalXP: profile.totalXP)
            profile.version += 1

            let record = TestCalibrationRecord(
                id: UUID(), type: .dilemma,
                scenario: "挑战\(i)", options: ["A", "B"],
                selectedOption: i % 2, customAnswer: nil,
                xpEarned: xp, ghostResponse: "反馈\(i)",
                profileDiff: nil, createdAt: Date()
            )
            recordStore.append(record)

            if i == 19 {
                let check = TestGhostTwinXP.checkLevelUp(oldXP: oldXP, newXP: profile.totalXP)
                XCTAssertTrue(check.leveledUp)
                XCTAssertEqual(check.newLevel, 2)
            }
        }

        try profileStore.save(profile)
        let final = profileStore.load()
        XCTAssertEqual(final.level, 2)
        XCTAssertEqual(final.totalXP, 10000)
        XCTAssertEqual(TestGhostTwinXP.currentLevelXP(totalXP: final.totalXP), 0)

        // Record store should cap at 20
        XCTAssertEqual(recordStore.loadAll().count, 20)

        print("✅ E2E Test 10 PASSED: Full journey Lv.1 → Lv.2")
    }
}
