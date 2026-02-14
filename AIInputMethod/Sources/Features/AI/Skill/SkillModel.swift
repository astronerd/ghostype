import Foundation
import AppKit
import SwiftUI

// MARK: - Modifier Key Binding

struct ModifierKeyBinding: Codable, Equatable {
    let keyCode: UInt16
    let isSystemModifier: Bool
    let displayName: String
}

// MARK: - Skill Model

struct SkillModel: Identifiable, Equatable {
    // 来自 SKILL.md（语义内容）
    let id: String                          // 目录名
    var name: String                        // 必填
    var description: String                 // 必填
    var userPrompt: String                  // 用户原始指令（UI 展示用）
    var systemPrompt: String                // AI 生成的完整 prompt（实际执行用）
    var allowedTools: [String]              // 默认 ["provide_text"]
    var config: [String: String]            // 可选配置参数

    // 来自 SkillMetadataStore（UI 元数据）
    var icon: String                        // emoji，默认 "✨"
    var colorHex: String                    // 颜色，默认 "#5AC8FA"
    var modifierKey: ModifierKeyBinding?    // 快捷键绑定
    var isBuiltin: Bool                     // 是否内置
    var isInternal: Bool                    // 是否内部 skill（不对用户展示）

    // MARK: - Color Helpers

    var color: NSColor {
        NSColor(hex: colorHex) ?? .systemTeal
    }

    var swiftUIColor: Color {
        Color(hex: colorHex)
    }

    // MARK: - Localized Display

    var localizedName: String {
        switch id {
        case SkillModel.builtinGhostCommandId: return L.Skill.builtinGhostCommandName
        case SkillModel.builtinGhostTwinId: return L.Skill.builtinGhostTwinName
        case SkillModel.builtinMemoId: return L.Skill.builtinMemoName
        case SkillModel.builtinTranslateId: return L.Skill.builtinTranslateName
        default: return name
        }
    }

    var localizedDescription: String {
        switch id {
        case SkillModel.builtinGhostCommandId: return L.Skill.builtinGhostCommandDesc
        case SkillModel.builtinGhostTwinId: return L.Skill.builtinGhostTwinDesc
        case SkillModel.builtinMemoId: return L.Skill.builtinMemoDesc
        case SkillModel.builtinTranslateId: return L.Skill.builtinTranslateDesc
        default: return description
        }
    }

    // MARK: - Default Color

    static let defaultColorHex = "#5AC8FA"
}

// MARK: - Builtin Skill IDs

extension SkillModel {
    static let builtinMemoId = "builtin-memo"
    static let builtinGhostCommandId = "builtin-ghost-command"
    static let builtinGhostTwinId = "builtin-ghost-twin"
    static let builtinTranslateId = "builtin-translate"
    static let builtinPromptGeneratorId = "builtin-prompt-generator"
    static let internalGhostCalibrationId = "internal-ghost-calibration"
    static let internalGhostProfilingId = "internal-ghost-profiling"
}

// MARK: - NSColor hex init

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        guard hex.count == 6 else { return nil }
        let r: CGFloat = CGFloat((int >> 16) & 0xFF) / 255.0
        let g: CGFloat = CGFloat((int >> 8) & 0xFF) / 255.0
        let b: CGFloat = CGFloat(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
