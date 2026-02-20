//
//  MemoContentFormatter.swift
//  AIInputMethod
//
//  Memo 内容格式化器，根据目标同步服务生成对应格式的内容
//  Validates: Requirements 14.1, 14.3, 14.4, 14.5, 14.6, 16.6
//  Properties: 8 (内容格式化正确性), 9 (Bear 与 Obsidian 格式一致性)
//

import Foundation

// MARK: - MemoContentFormatter

/// 将 Memo 内容格式化为目标笔记应用所需的格式
///
/// 各目标格式：
/// - Obsidian/Bear (Markdown)：`**HH:mm**\n\n{content}\n\n`
/// - Notion：JSON 字符串，paragraph block with bold timestamp
/// - Apple Notes：`HH:mm\n{content}\n\n`
enum MemoContentFormatter {

    // MARK: - Public

    /// 格式化 Memo 内容为目标格式
    ///
    /// - Parameters:
    ///   - content: Memo 原始文本内容
    ///   - timestamp: Memo 的时间戳
    ///   - target: 目标同步服务类型
    /// - Returns: 格式化后的字符串
    static func format(
        content: String,
        timestamp: Date,
        target: SyncServiceType
    ) -> String {
        let timeString = formatTime(timestamp)

        switch target {
        case .obsidian, .bear:
            return formatMarkdown(content: content, timeString: timeString)
        case .notion:
            return formatNotion(content: content, timeString: timeString)
        case .appleNotes:
            return formatAppleNotes(content: content, timeString: timeString)
        }
    }

    // MARK: - Private

    /// 格式化时间戳为 HH:mm，使用固定 locale 不受设备设置影响
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// Obsidian / Bear Markdown 格式：**HH:mm**\n\n{content}\n\n
    private static func formatMarkdown(content: String, timeString: String) -> String {
        "**\(timeString)**\n\n\(content)\n\n"
    }

    /// Apple Notes 纯文本格式：HH:mm\n{content}\n\n
    private static func formatAppleNotes(content: String, timeString: String) -> String {
        "\(timeString)\n\(content)\n\n"
    }

    /// Notion paragraph block JSON 格式，时间戳为 bold text
    private static func formatNotion(content: String, timeString: String) -> String {
        let block: [String: Any] = [
            "object": "block",
            "type": "paragraph",
            "paragraph": [
                "rich_text": [
                    [
                        "type": "text",
                        "text": ["content": timeString],
                        "annotations": ["bold": true]
                    ],
                    [
                        "type": "text",
                        "text": ["content": "\n\n"]
                    ],
                    [
                        "type": "text",
                        "text": ["content": content]
                    ]
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: block,
            options: [.sortedKeys]
        ) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
