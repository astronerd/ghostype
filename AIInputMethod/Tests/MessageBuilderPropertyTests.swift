import XCTest
import Foundation

// MARK: - Test Copies of Models
// Since the test target cannot import the executable, we create test copies.

/// Test copy of ChallengeType
private enum TestChallengeType: String, Codable, CaseIterable {
    case dilemma
    case reverseTuring = "reverse_turing"
    case prediction

    static func random() -> TestChallengeType {
        allCases.randomElement()!
    }
}

/// Test copy of GhostTwinProfile
private struct TestGhostTwinProfile: Codable, Equatable {
    var version: Int
    var level: Int
    var totalXP: Int
    var personalityTags: [String]
    var profileText: String
    var createdAt: Date
    var updatedAt: Date

    static func random() -> TestGhostTwinProfile {
        let tagCount = Int.random(in: 0...5)
        let tags = (0..<tagCount).map { _ in randomChinese(minLength: 1, maxLength: 4) }
        return TestGhostTwinProfile(
            version: Int.random(in: 0...100),
            level: Int.random(in: 1...10),
            totalXP: Int.random(in: 0...100000),
            personalityTags: tags,
            profileText: randomChinese(minLength: 0, maxLength: 200),
            createdAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000)),
            updatedAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000))
        )
    }
}

/// Test copy of CalibrationRecord
private struct TestCalibrationRecord: Codable, Equatable {
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

    static func random() -> TestCalibrationRecord {
        let optionCount = Int.random(in: 2...4)
        let options = (0..<optionCount).map { _ in randomChinese(minLength: 2, maxLength: 20) }
        let useCustom = Bool.random()
        return TestCalibrationRecord(
            id: UUID(),
            type: TestChallengeType.random(),
            scenario: randomChinese(minLength: 5, maxLength: 50),
            options: options,
            selectedOption: useCustom ? -1 : Int.random(in: 0..<optionCount),
            customAnswer: useCustom ? randomChinese(minLength: 2, maxLength: 30) : nil,
            xpEarned: [200, 300, 500].randomElement()!,
            ghostResponse: randomChinese(minLength: 5, maxLength: 30),
            profileDiff: Bool.random() ? randomChinese(minLength: 10, maxLength: 50) : nil,
            createdAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000))
        )
    }
}

/// Test copy of LocalCalibrationChallenge
private struct TestLocalCalibrationChallenge: Codable, Equatable {
    let type: TestChallengeType
    let scenario: String
    let options: [String]
    let targetField: String

    static func random() -> TestLocalCalibrationChallenge {
        let optionCount = Int.random(in: 2...5)
        return TestLocalCalibrationChallenge(
            type: TestChallengeType.random(),
            scenario: randomChinese(minLength: 5, maxLength: 50),
            options: (0..<optionCount).map { _ in randomChinese(minLength: 2, maxLength: 20) },
            targetField: ["form", "spirit", "method"].randomElement()!
        )
    }
}

/// Test copy of ASRCorpusEntry
private struct TestASRCorpusEntry: Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var consumedAtLevel: Int?

    static func random() -> TestASRCorpusEntry {
        TestASRCorpusEntry(
            id: UUID(),
            text: randomChinese(minLength: 3, maxLength: 40),
            createdAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000)),
            consumedAtLevel: Bool.random() ? Int.random(in: 1...10) : nil
        )
    }
}

// MARK: - Random Chinese String Generator

/// Generate a random string with a mix of Chinese characters and ASCII
private func randomChinese(minLength: Int = 1, maxLength: Int = 20) -> String {
    let length = Int.random(in: minLength...max(minLength, maxLength))
    if length == 0 { return "" }
    // Mix of Chinese chars and ASCII for realistic testing
    let chineseRange: [Character] = Array("你好世界测试人格标签直率理性幽默温柔果断独立思考创新务实乐观")
    let asciiRange: [Character] = Array("abcdefghijklmnopqrstuvwxyz0123456789 ")
    let allChars = chineseRange + asciiRange
    return String((0..<length).map { _ in allChars.randomElement()! })
}

// MARK: - Test Copy of MessageBuilder

/// Exact replica of MessageBuilder from the main target
private enum TestMessageBuilder {

    static func buildChallengeUserMessage(
        profile: TestGhostTwinProfile,
        records: [TestCalibrationRecord]
    ) -> String {
        var parts: [String] = []
        parts.append("## 当前用户档案")
        parts.append("- 等级: Lv.\(profile.level)")
        parts.append("- 档案版本: v\(profile.version)")
        parts.append("- 已捕捉标签: \(profile.personalityTags.joined(separator: ", "))")
        parts.append("- 人格档案全文:")
        parts.append(profile.profileText)
        parts.append("")
        parts.append("## 最近校准记录（用于去重）")
        if records.isEmpty {
            parts.append("无历史记录")
        } else {
            for record in records {
                parts.append("- [\(record.type.rawValue)] \(record.scenario) → 选项\(record.selectedOption)")
            }
        }
        parts.append("")
        parts.append("请根据以上信息生成一道校准挑战题。")
        return parts.joined(separator: "\n")
    }

    static func buildAnalysisUserMessage(
        profile: TestGhostTwinProfile,
        challenge: TestLocalCalibrationChallenge,
        selectedOption: Int?,
        customAnswer: String?,
        records: [TestCalibrationRecord]
    ) -> String {
        var parts: [String] = []
        parts.append("## 当前人格档案")
        parts.append(profile.profileText)
        parts.append("")
        parts.append("## 本次挑战信息")
        parts.append("- 类型: \(challenge.type.rawValue)")
        parts.append("- 场景: \(challenge.scenario)")
        let optionsText = challenge.options.enumerated()
            .map { "\($0.offset): \($0.element)" }
            .joined(separator: ", ")
        parts.append("- 选项: \(optionsText)")
        parts.append("- 目标层级: \(challenge.targetField)")
        parts.append("")
        parts.append("## 用户选择")
        if let custom = customAnswer, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("- 输入方式: 用户自定义输入（未从预设选项中选择）")
            parts.append("- 自定义答案: \(custom)")
            parts.append("注意：用户对预设选项均不满意，选择了自行表达。请基于用户的原始表述进行更深入的人格分析。")
        } else if let idx = selectedOption, idx >= 0, idx < challenge.options.count {
            parts.append("- 选项索引: \(idx)")
            parts.append("- 选项内容: \(challenge.options[idx])")
        }
        parts.append("")
        parts.append("## 校准历史")
        if records.isEmpty {
            parts.append("无历史记录")
        } else {
            for record in records {
                parts.append("- [\(record.type.rawValue)] \(record.scenario) → 选项\(record.selectedOption)")
            }
        }
        parts.append("")
        parts.append("请分析用户选择并输出 profile_diff。")
        return parts.joined(separator: "\n")
    }

    static func buildProfilingUserMessage(
        profile: TestGhostTwinProfile,
        previousReport: String?,
        corpus: [TestASRCorpusEntry],
        records: [TestCalibrationRecord]
    ) -> String {
        var parts: [String] = []
        parts.append("## 上一轮构筑报告（记忆）")
        parts.append(previousReport ?? "首次构筑，无历史报告")
        parts.append("")
        parts.append("## 当前等级新增 ASR 语料")
        if corpus.isEmpty {
            parts.append("无新增语料")
        } else {
            for entry in corpus {
                parts.append("- \(entry.text)")
            }
        }
        parts.append("")
        parts.append("## 当前等级校准答案")
        if records.isEmpty {
            parts.append("无校准记录")
        } else {
            for record in records {
                parts.append("- [\(record.type.rawValue)] \(record.scenario) → 选项\(record.selectedOption)")
            }
        }
        parts.append("")
        parts.append("## 当前人格档案")
        parts.append("- 等级: Lv.\(profile.level)")
        parts.append("- 已捕捉标签: \(profile.personalityTags.joined(separator: ", "))")
        parts.append("- 档案全文:")
        parts.append(profile.profileText)
        parts.append("")
        parts.append("请输出完整的「形神法三位一体」分析报告。")
        parts.append("报告中对新增/修订/强化的特征使用 [NEW]、[REVISED]、[REINFORCED] 标记。")
        parts.append("最后附上 JSON 格式的结构化摘要：")
        parts.append("{\"summary\": \"人格画像描述\", \"refined_tags\": [\"标签1\", \"[NEW] 标签2\", ...]}")
        return parts.joined(separator: "\n")
    }
}


// MARK: - Property Tests

/// Property-based tests for MessageBuilder user message construction
/// Feature: ghost-twin-on-device
/// **Validates: Requirements 5.1, 5.2, 6.1, 7.3, 7.4, 13.3, 13.4**
final class MessageBuilderPropertyTests: XCTestCase {

    // MARK: - Property 8: Challenge user message contains required data

    /// Feature: ghost-twin-on-device, Property 8: Challenge user message contains required data
    /// For any GhostTwinProfile and list of recent CalibrationRecord entries,
    /// the output of buildChallengeUserMessage should contain the profile's level,
    /// version, personalityTags, and profileText content.
    /// **Validates: Requirements 5.1, 5.2**
    func testProperty8_ChallengeUserMessageContainsRequiredData() {
        PropertyTest.verify(
            "Challenge user message contains profile level, version, tags, profileText, and closing instruction",
            iterations: 100
        ) {
            let profile = TestGhostTwinProfile.random()
            let recordCount = Int.random(in: 0...5)
            let records = (0..<recordCount).map { _ in TestCalibrationRecord.random() }

            let message = TestMessageBuilder.buildChallengeUserMessage(
                profile: profile,
                records: records
            )

            // Must contain level
            guard message.contains("Lv.\(profile.level)") else { return false }

            // Must contain version
            guard message.contains("v\(profile.version)") else { return false }

            // Must contain each personality tag
            for tag in profile.personalityTags {
                guard message.contains(tag) else { return false }
            }

            // Must contain profileText (if non-empty)
            if !profile.profileText.isEmpty {
                guard message.contains(profile.profileText) else { return false }
            }

            // Must contain closing instruction
            guard message.contains("请根据以上信息生成一道校准挑战题") else { return false }

            return true
        }
    }

    // MARK: - Property 9: Analysis user message contains profile and challenge data

    /// Feature: ghost-twin-on-device, Property 9: Analysis user message contains profile and challenge data
    /// For any GhostTwinProfile, LocalCalibrationChallenge, selected option, and list of recent records,
    /// the output of buildAnalysisUserMessage should contain the profile data, challenge scenario,
    /// options, and the user's selection.
    /// **Validates: Requirements 6.1**
    func testProperty9_AnalysisUserMessageContainsProfileAndChallengeData() {
        PropertyTest.verify(
            "Analysis user message contains profile, challenge scenario, options, and selected option content",
            iterations: 100
        ) {
            let profile = TestGhostTwinProfile.random()
            let challenge = TestLocalCalibrationChallenge.random()
            // Pick a valid selected option index
            let selectedOption = Int.random(in: 0..<challenge.options.count)
            let recordCount = Int.random(in: 0...3)
            let records = (0..<recordCount).map { _ in TestCalibrationRecord.random() }

            let message = TestMessageBuilder.buildAnalysisUserMessage(
                profile: profile,
                challenge: challenge,
                selectedOption: selectedOption,
                customAnswer: nil,
                records: records
            )

            // Must contain profileText
            if !profile.profileText.isEmpty {
                guard message.contains(profile.profileText) else { return false }
            }

            // Must contain challenge scenario
            guard message.contains(challenge.scenario) else { return false }

            // Must contain each option text
            for option in challenge.options {
                guard message.contains(option) else { return false }
            }

            // Must contain the selected option content
            guard message.contains(challenge.options[selectedOption]) else { return false }

            // Must contain closing instruction
            guard message.contains("请分析用户选择并输出 profile_diff") else { return false }

            return true
        }
    }

    // MARK: - Property 10: Profiling user message contains framework and data

    /// Feature: ghost-twin-on-device, Property 10: Profiling user message contains framework and data
    /// For any GhostTwinProfile, optional previous report, list of ASR corpus entries,
    /// and list of calibration records, the output of buildProfilingUserMessage should contain
    /// the previous report (or "首次构筑" indicator), the ASR corpus texts, and the calibration record summaries.
    /// **Validates: Requirements 7.3, 7.4**
    func testProperty10_ProfilingUserMessageContainsFrameworkAndData() {
        PropertyTest.verify(
            "Profiling user message contains previous report or 首次构筑, corpus texts, and 形神法三位一体",
            iterations: 100
        ) {
            let profile = TestGhostTwinProfile.random()
            let hasPreviousReport = Bool.random()
            let previousReport: String? = hasPreviousReport ? randomChinese(minLength: 10, maxLength: 100) : nil
            let corpusCount = Int.random(in: 0...5)
            let corpus = (0..<corpusCount).map { _ in TestASRCorpusEntry.random() }
            let recordCount = Int.random(in: 0...3)
            let records = (0..<recordCount).map { _ in TestCalibrationRecord.random() }

            let message = TestMessageBuilder.buildProfilingUserMessage(
                profile: profile,
                previousReport: previousReport,
                corpus: corpus,
                records: records
            )

            // Must contain previous report text OR "首次构筑" indicator
            if let report = previousReport {
                guard message.contains(report) else { return false }
            } else {
                guard message.contains("首次构筑，无历史报告") else { return false }
            }

            // Must contain each corpus entry text
            for entry in corpus {
                guard message.contains(entry.text) else { return false }
            }

            // Must contain 形神法三位一体 framework reference
            guard message.contains("形神法三位一体") else { return false }

            return true
        }
    }

    // MARK: - Property 14: Custom answer user message annotation

    /// Feature: ghost-twin-on-device, Property 14: Custom answer user message annotation
    /// For any non-empty, non-whitespace custom answer string, the output of buildAnalysisUserMessage
    /// with customAnswer set should contain the custom answer text and an explicit annotation
    /// indicating it is a user-provided custom input (not a preset option selection).
    /// **Validates: Requirements 13.3, 13.4**
    func testProperty14_CustomAnswerUserMessageAnnotation() {
        PropertyTest.verify(
            "Analysis user message with custom answer contains the answer text and custom input annotations",
            iterations: 100
        ) {
            let profile = TestGhostTwinProfile.random()
            let challenge = TestLocalCalibrationChallenge.random()
            let records = (0..<Int.random(in: 0...3)).map { _ in TestCalibrationRecord.random() }

            // Generate a non-empty, non-whitespace custom answer
            // Ensure at least one non-whitespace character
            let baseText = randomChinese(minLength: 1, maxLength: 30)
            // If by chance it's all whitespace, prepend a real character
            let customAnswer: String
            if baseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                customAnswer = "自定义" + baseText
            } else {
                customAnswer = baseText
            }

            let message = TestMessageBuilder.buildAnalysisUserMessage(
                profile: profile,
                challenge: challenge,
                selectedOption: nil,
                customAnswer: customAnswer,
                records: records
            )

            // Must contain the custom answer text
            guard message.contains(customAnswer) else { return false }

            // Must contain "用户自定义输入" annotation
            guard message.contains("用户自定义输入") else { return false }

            // Must contain "未从预设选项中选择" annotation
            guard message.contains("未从预设选项中选择") else { return false }

            return true
        }
    }
}
