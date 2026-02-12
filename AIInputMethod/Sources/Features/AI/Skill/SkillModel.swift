import Foundation
import AppKit
import SwiftUI

// MARK: - Skill Type

/// Skill 类型，决定 API 路由
enum SkillType: String, Codable, CaseIterable {
    case polish         // 默认润色（无修饰键时）
    case memo           // 随心记
    case translate      // 翻译
    case ghostCommand   // Ghost Command
    case ghostTwin      // Call Ghost Twin
    case custom         // 用户自定义
}

// MARK: - Modifier Key Binding

/// 修饰键绑定
struct ModifierKeyBinding: Codable, Equatable {
    let keyCode: UInt16             // 按键 keyCode
    let isSystemModifier: Bool      // 是否为系统修饰键 (Shift/Cmd/Ctrl/Fn)
    let displayName: String         // 显示名称 (如 "⇧", "⌘", "A")
}

// MARK: - Skill Model

/// Skill 数据模型
/// 以 SKILL.md 文件存储（YAML frontmatter + markdown body）
struct SkillModel: Identifiable, Equatable {
    let id: String                          // UUID 字符串或 builtin-xxx
    var name: String                        // 显示名称
    var description: String                 // 功能描述
    var icon: String                        // SF Symbol 名称
    var modifierKey: ModifierKeyBinding?    // 绑定的按键（nil = 未绑定）
    var promptTemplate: String              // prompt 模板（markdown body）
    var behaviorConfig: [String: String]    // 行为配置字典
    var isBuiltin: Bool                     // 是否内置
    var isEditable: Bool                    // prompt 是否可编辑
    var skillType: SkillType               // Skill 类型，决定路由

    // MARK: - Display Helpers

    /// Skill 颜色（用于 UI 展示）
    var color: NSColor {
        switch skillType {
        case .polish: return .systemGreen
        case .memo: return .systemOrange
        case .translate: return .systemPurple
        case .ghostCommand: return .systemBlue
        case .ghostTwin: return .systemPink
        case .custom: return .systemTeal
        }
    }

    var swiftUIColor: Color {
        switch skillType {
        case .polish: return .green
        case .memo: return .orange
        case .translate: return .purple
        case .ghostCommand: return .blue
        case .ghostTwin: return .pink
        case .custom: return .teal
        }
    }
}

// MARK: - Builtin Skill IDs

extension SkillModel {
    static let builtinMemoId = "builtin-memo"
    static let builtinGhostCommandId = "builtin-ghost-command"
    static let builtinGhostTwinId = "builtin-ghost-twin"
    static let builtinTranslateId = "builtin-translate"
}
