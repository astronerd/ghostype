//
//  MessageBuilder.swift
//  AIInputMethod
//
//  User message 构建工具 — 为校准出题、答案分析、人格构筑三个阶段拼接 LLM user message
//  设计为 enum 静态方法，便于单元测试和属性测试
//  Validates: Requirements 5.1, 5.2, 6.1, 7.3, 7.4, 13.3, 13.4
//

import Foundation

// MARK: - MessageBuilder

/// User message 构建工具
/// 为校准出题、答案分析、人格构筑三个阶段拼接 LLM user message
enum MessageBuilder {

    // MARK: - Challenge (出题阶段)

    /// 构建出题阶段的 user message
    /// Validates: Requirements 5.1, 5.2
    static func buildChallengeUserMessage(
        profile: GhostTwinProfile,
        records: [CalibrationRecord]
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
                parts.append("- \(record.scenario) → 选项\(record.selectedOption)")
            }
        }

        parts.append("")
        parts.append("请根据以上信息生成一道校准挑战题。")

        return parts.joined(separator: "\n")
    }

    // MARK: - Analysis (分析阶段)

    /// 构建分析阶段的 user message（支持预设选项和自定义答案）
    /// Validates: Requirements 6.1, 13.3, 13.4
    static func buildAnalysisUserMessage(
        profile: GhostTwinProfile,
        challenge: LocalCalibrationChallenge,
        selectedOption: Int?,
        customAnswer: String?,
        records: [CalibrationRecord]
    ) -> String {
        var parts: [String] = []

        // 当前人格档案
        parts.append("## 当前人格档案")
        parts.append(profile.profileText)

        // 本次挑战信息
        parts.append("")
        parts.append("## 本次挑战信息")
        parts.append("- 场景: \(challenge.scenario)")
        let optionsText = challenge.options.enumerated()
            .map { "\($0.offset): \($0.element)" }
            .joined(separator: ", ")
        parts.append("- 选项: \(optionsText)")
        parts.append("- 目标层级: \(challenge.targetField)")

        // 用户选择
        parts.append("")
        parts.append("## 用户选择")

        if let custom = customAnswer, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 自定义答案标注 — Requirements 13.3, 13.4
            parts.append("- 输入方式: 用户自定义输入（未从预设选项中选择）")
            parts.append("- 自定义答案: \(custom)")
            parts.append("注意：用户对预设选项均不满意，选择了自行表达。请基于用户的原始表述进行更深入的人格分析。")
        } else if let idx = selectedOption, idx >= 0, idx < challenge.options.count {
            // 预设选项
            parts.append("- 选项索引: \(idx)")
            parts.append("- 选项内容: \(challenge.options[idx])")
        }

        // 校准历史
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

    // MARK: - Profiling (构筑阶段)

    /// 构建构筑阶段的 user message
    /// Validates: Requirements 7.3, 7.4
    static func buildProfilingUserMessage(
        profile: GhostTwinProfile,
        previousReport: String?,
        corpus: [ASRCorpusEntry],
        records: [CalibrationRecord]
    ) -> String {
        var parts: [String] = []

        // 上一轮构筑报告
        parts.append("## 上一轮构筑报告（记忆）")
        parts.append(previousReport ?? "首次构筑，无历史报告")

        // 当前等级新增 ASR 语料
        parts.append("")
        parts.append("## 当前等级新增 ASR 语料")
        if corpus.isEmpty {
            parts.append("无新增语料")
        } else {
            for entry in corpus {
                parts.append("- \(entry.text)")
            }
        }

        // 当前等级校准答案
        parts.append("")
        parts.append("## 当前等级校准答案")
        if records.isEmpty {
            parts.append("无校准记录")
        } else {
            for record in records {
                parts.append("- \(record.scenario) → 选项\(record.selectedOption)")
            }
        }

        // 当前人格档案
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
