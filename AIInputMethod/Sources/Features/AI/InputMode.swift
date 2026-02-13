import Foundation
import AppKit

// MARK: - Input Mode

/// 输入模式枚举（已废弃，新代码请使用 SkillModel + SkillExecutor）
/// 保留用于 OverlayView、AppSettings 等向后兼容
/// 根据修饰键组合决定不同的处理方式
enum InputMode: String, CaseIterable {
    /// 默认模式：AI 润色后上屏
    case polish = "polish"
    
    /// 翻译模式：中英互译后上屏 (默认 Shift + 主键)
    case translate = "translate"
    
    /// 随心记模式：记录到笔记本，不上屏 (默认 Cmd + 主键)
    case memo = "memo"
    
    // MARK: - Properties
    
    /// 模式显示名称
    var displayName: String {
        switch self {
        case .polish: return "润色"
        case .translate: return "翻译"
        case .memo: return "随心记"
        }
    }
    
    /// 模式图标 (SF Symbol)
    var icon: String {
        switch self {
        case .polish: return "wand.and.stars"
        case .translate: return "globe"
        case .memo: return "note.text"
        }
    }
    
    /// 模式颜色
    var color: NSColor {
        switch self {
        case .polish: return .systemGreen
        case .translate: return .systemPurple
        case .memo: return .systemOrange
        }
    }
    
    /// SwiftUI 颜色
    var swiftUIColor: Color {
        switch self {
        case .polish: return .green
        case .translate: return .purple
        case .memo: return .orange
        }
    }
    
    // MARK: - Mode Detection
    
    /// 根据当前修饰键状态判断输入模式（使用用户设置）
    /// - Parameter modifiers: 当前按下的修饰键
    /// - Returns: 对应的输入模式
    static func fromModifiers(_ modifiers: NSEvent.ModifierFlags) -> InputMode {
        return AppSettings.shared.modeFromModifiers(modifiers)
    }
}

import SwiftUI
