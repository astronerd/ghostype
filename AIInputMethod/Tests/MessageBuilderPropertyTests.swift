import XCTest
import Foundation

// MARK: - Test Copies of Models

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
            version: Int.random(in: 0...100), level: Int.random(in: 1...10),
            totalXP: Int.random(in: 0...100000), personalityTags: tags,
            profileText: randomChinese(minLength: 0, maxLength: 200),
            createdAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000)),
            updatedAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000))
        )
    }
}

private struct TestCalibrationRecord: Codable, Equatable {
    let id: UUID
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
            id: UUID(), scenario: randomChinese(minLength: 5, maxLength: 50),
            options: options,
            selectedOption: useCustom ? -1 : Int.random(in: 0..<optionCount),
            customAnswer: useCustom ? randomChinese(minLength: 2, maxLength: 30) : nil,
            xpEarned: 300, ghostResponse: randomChinese(minLength: 5, maxLength: 30),
            profileDiff: Bool.random() ? randomChinese(minLength: 10, maxLength: 50) : nil,
            createdAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000))
        )
    }
}

private struct TestLocalCalibrationChallenge: Codable, Equatable {
    let scenario: String
    let options: [String]
    let targetField: String

    static func random() -> TestLocalCalibrationChallenge {
        let optionCount = Int.random(in: 2...5)
        return TestLocalCalibrationChallenge(
            scenario: randomChinese(minLength: 5, maxLength: 50),
            options: (0..<optionCount).map { _ in randomChinese(minLength: 2, maxLength: 20) },
            targetField: ["form", "spirit", "method"].randomElement()!
        )
    }
}

private struct TestASRCorpusEntry: Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var consumedAtLevel: Int?

    static func random() -> TestASRCorpusEntry {
        TestASRCorpusEntry(
            id: UUID(), text: randomChinese(minLength: 3, maxLength: 40),
            createdAt: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000)),
            consumedAtLevel: Bool.random() ? Int.random(in: 1...10) : nil
        )
    }
}

private func randomChinese(minLength: Int = 1, maxLength: Int = 20) -> String {
    let length = Int.random(in: minLength...max(minLength, maxLength))
    if length == 0 { return "" }
    let allChars: [Character] = Array("你好世界测试人格标签直率理性幽默温柔果断独立思考创新务实乐观abcdefghijklmnopqrstuvwxyz0123456789 ")
    return String((0..<length).map { _ in allChars.randomElement()! })
}


// MARK: - Test Copy of MessageBuilder

private enum TestMessageBuilder {
    static func buildChallengeUserMessage(profile: TestGhostTwinProfile, records: [TestCalibrationRecord]) -> String {
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
                parts.append("- \(record.scenario) → 选项\(record.selectedOption)")
            }
        }
        parts.append("")
        parts.append("请根据以上信息生成一道校准挑战题。")
        return parts.joined(separator: "\n")
    }

    static func buildAnalysisUserMessage(
        profile: TestGhostTwinProfile, challenge: TestLocalCalibrationChallenge,
        selectedOption: Int?, customAnswer: String?, records: [TestCalibrationRecord]
    ) -> String {
        var parts: [String] = []
        parts.append("## 当前人格档案")
        parts.append(profile.profileText)
        parts.append("")
        parts.append("## 本次挑战信息")
        parts.append("- 场景: \(challenge.scenario)")
        let optionsText = challenge.options.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: ", ")
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
                parts.append("- \(record.scenario) → 选项\(record.selectedOption)")
            }
        }
        parts.append("")
        parts.append("请分析用户选择并输出 profile_diff。")
        return parts.joined(separator: "\n")
    }

    static func buildProfilingUserMessage(
        profile: TestGhostTwinProfile, previousReport: String?,
        corpus: [TestASRCorpusEntry], records: [TestCalibrationRecord]
    ) -> String {
        var parts: [String] = []
        parts.append("## 上一轮构筑报告（记忆）")
        parts.append(previousReport ?? "首次构筑，无历史报告")
        parts.append("")
        parts.append("## 当前等级新增 ASR 语料")
        if corpus.isEmpty { parts.append("无新增语料") }
        else { for entry in corpus { parts.append("- \(entry.text)") } }
        parts.append("")
        parts.append("## 当前等级校准答案")
        if records.isEmpty { parts.append("无校准记录") }
        else { for record in records { parts.append("- \(record.scenario) → 选项\(record.selectedOption)") } }
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

final class MessageBuilderPropertyTests: XCTestCase {

    func testProperty8_ChallengeUserMessageContainsRequiredData() {
        PropertyTest.verify("Challenge user message contains required data", iterations: 100) {
            let profile = TestGhostTwinProfile.random()
            let records = (0..<Int.random(in: 0...5)).map { _ in TestCalibrationRecord.random() }
            let message = TestMessageBuilder.buildChallengeUserMessage(profile: profile, records: records)
            guard message.contains("Lv.\(profile.level)") else { return false }
            guard message.contains("v\(profile.version)") else { return false }
            for tag in profile.personalityTags { guard message.contains(tag) else { return false } }
            if !profile.profileText.isEmpty { guard message.contains(profile.profileText) else { return false } }
            guard message.contains("请根据以上信息生成一道校准挑战题") else { return false }
            return true
        }
    }

    func testProperty9_AnalysisUserMessageContainsProfileAndChallengeData() {
        PropertyTest.verify("Analysis user message contains profile and challenge data", iterations: 100) {
            let profile = TestGhostTwinProfile.random()
            let challenge = TestLocalCalibrationChallenge.random()
            let selectedOption = Int.random(in: 0..<challenge.options.count)
            let records = (0..<Int.random(in: 0...3)).map { _ in TestCalibrationRecord.random() }
            let message = TestMessageBuilder.buildAnalysisUserMessage(
                profile: profile, challenge: challenge, selectedOption: selectedOption, customAnswer: nil, records: records)
            if !profile.profileText.isEmpty { guard message.contains(profile.profileText) else { return false } }
            guard message.contains(challenge.scenario) else { return false }
            for option in challenge.options { guard message.contains(option) else { return false } }
            guard message.contains("请分析用户选择并输出 profile_diff") else { return false }
            return true
        }
    }

    func testProperty10_ProfilingUserMessageContainsFrameworkAndData() {
        PropertyTest.verify("Profiling user message contains framework and data", iterations: 100) {
            let profile = TestGhostTwinProfile.random()
            let previousReport: String? = Bool.random() ? randomChinese(minLength: 10, maxLength: 100) : nil
            let corpus = (0..<Int.random(in: 0...5)).map { _ in TestASRCorpusEntry.random() }
            let records = (0..<Int.random(in: 0...3)).map { _ in TestCalibrationRecord.random() }
            let message = TestMessageBuilder.buildProfilingUserMessage(
                profile: profile, previousReport: previousReport, corpus: corpus, records: records)
            if let report = previousReport { guard message.contains(report) else { return false } }
            else { guard message.contains("首次构筑，无历史报告") else { return false } }
            for entry in corpus { guard message.contains(entry.text) else { return false } }
            guard message.contains("形神法三位一体") else { return false }
            return true
        }
    }

    func testProperty14_CustomAnswerUserMessageAnnotation() {
        PropertyTest.verify("Custom answer annotation", iterations: 100) {
            let profile = TestGhostTwinProfile.random()
            let challenge = TestLocalCalibrationChallenge.random()
            let records = (0..<Int.random(in: 0...3)).map { _ in TestCalibrationRecord.random() }
            let baseText = randomChinese(minLength: 1, maxLength: 30)
            let customAnswer = baseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定义" + baseText : baseText
            let message = TestMessageBuilder.buildAnalysisUserMessage(
                profile: profile, challenge: challenge, selectedOption: nil, customAnswer: customAnswer, records: records)
            guard message.contains(customAnswer) else { return false }
            guard message.contains("用户自定义输入") else { return false }
            guard message.contains("未从预设选项中选择") else { return false }
            return true
        }
    }
}
