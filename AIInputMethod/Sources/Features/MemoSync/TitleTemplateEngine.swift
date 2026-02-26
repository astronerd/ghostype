//
//  TitleTemplateEngine.swift
//  AIInputMethod
//
//  标题模板引擎，解析模板字符串并替换变量
//  Validates: Requirements 6.2, 6.3
//

import Foundation

// MARK: - TitleTemplateEngine

/// 标题模板引擎，将模板中的变量占位符替换为实际值
///
/// 支持变量：
/// - `{date}` → yyyy-MM-dd（如 2025-01-15）
/// - `{time}` → HH:mm（如 14:32）
/// - `{weekNumber}` → 两位周数（如 03）
/// - `{year}` → 四位年份（如 2025）
enum TitleTemplateEngine {

    /// 默认标题模板
    static let defaultTemplate = "GHOSTYPE Memo {date}"

    /// 已知的模板变量名集合
    private static let knownVariables: Set<String> = [
        "date", "time", "weekNumber", "year"
    ]

    /// 解析标题模板，替换已知变量
    ///
    /// - Parameters:
    ///   - template: 模板字符串，包含 `{variable}` 占位符
    ///   - date: 用于生成变量值的日期
    ///   - groupingMode: 分组模式（预留，当前未影响变量替换逻辑）
    /// - Returns: 替换后的标题字符串。已知变量被替换，未知变量保留原样。
    static func resolve(
        template: String,
        date: Date,
        groupingMode: GroupingMode
    ) -> String {
        let values = buildVariableValues(for: date)

        var result = template
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return result
    }

    // MARK: - Private

    /// 为给定日期构建所有变量的值映射
    private static func buildVariableValues(for date: Date) -> [String: String] {
        // 使用固定 locale 确保格式不受用户设备影响
        let locale = Locale(identifier: "en_US_POSIX")

        let dateFmt = DateFormatter()
        dateFmt.locale = locale
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.locale = locale
        timeFmt.dateFormat = "HH:mm"

        let yearFmt = DateFormatter()
        yearFmt.locale = locale
        yearFmt.dateFormat = "yyyy"

        let weekFmt = DateFormatter()
        weekFmt.locale = locale
        weekFmt.dateFormat = "ww"

        return [
            "date": dateFmt.string(from: date),
            "time": timeFmt.string(from: date),
            "year": yearFmt.string(from: date),
            "weekNumber": weekFmt.string(from: date)
        ]
    }
}
