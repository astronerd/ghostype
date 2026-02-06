//
//  DesignSystem.swift
//  AIInputMethod
//
//  统一设计系统 - 极简配色方案
//

import SwiftUI

// MARK: - Design Tokens

enum DS {
    
    // MARK: - Colors (统一配色)
    
    enum Colors {
        /// 一级背景 - F2F1EE
        static let bg1 = Color(hex: "F2F1EE")
        /// 二级背景 - F7F7F4
        static let bg2 = Color(hex: "F7F7F4")
        /// 高亮色 - E6E5E1
        static let highlight = Color(hex: "E6E5E1")
        
        /// 一级小标题字体 - 787771
        static let text1 = Color(hex: "787771")
        /// 二级大标题字体 - 26251E
        static let text2 = Color(hex: "26251E")
        /// 图标颜色 - 7A7973
        static let icon = Color(hex: "7A7973")
        
        // 兼容旧代码的别名
        static let background = bg1
        static let backgroundSecondary = bg2
        static let sidebarBackground = bg2
        static let textPrimary = text2
        static let textSecondary = text1
        static let textTertiary = text1
        static let border = highlight
        static let divider = highlight
        
        /// 状态色 - 柔和
        static let statusSuccess = Color(hex: "65A30D")
        static let statusWarning = Color(hex: "D97706")
        static let statusError = Color(hex: "DC2626")
        static let accent = text2
    }
    
    // MARK: - Typography
    
    enum Typography {
        static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
        
        static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }
        
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        
        static let largeTitle = serif(28, weight: .medium)
        static let title = serif(22, weight: .medium)
        static let headline = ui(15, weight: .semibold)
        static let body = ui(14, weight: .regular)
        static let bodySerif = serif(14, weight: .regular)
        static let caption = ui(12, weight: .regular)
        static let small = ui(11, weight: .regular)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
    
    // MARK: - Layout
    
    enum Layout {
        static let sidebarWidth: CGFloat = 180
        static let contentMinWidth: CGFloat = 600
        static let cornerRadius: CGFloat = 4
        static let borderWidth: CGFloat = 1
    }
}

// MARK: - View Modifiers

struct MinimalCardStyle: ViewModifier {
    var padding: CGFloat = DS.Spacing.lg
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DS.Colors.bg2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                    .stroke(DS.Colors.highlight, lineWidth: DS.Layout.borderWidth)
            )
    }
}

struct SidebarItemStyle: ViewModifier {
    var isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.highlight : Color.clear)
            .cornerRadius(DS.Layout.cornerRadius)
    }
}

extension View {
    func minimalCard(padding: CGFloat = DS.Spacing.lg) -> some View {
        modifier(MinimalCardStyle(padding: padding))
    }
    
    func sidebarItem(isSelected: Bool) -> some View {
        modifier(SidebarItemStyle(isSelected: isSelected))
    }
}

// MARK: - Reusable Components

struct MinimalDivider: View {
    var vertical: Bool = false
    
    var body: some View {
        if vertical {
            Rectangle()
                .fill(DS.Colors.highlight)
                .frame(width: DS.Layout.borderWidth)
        } else {
            Rectangle()
                .fill(DS.Colors.highlight)
                .frame(height: DS.Layout.borderWidth)
        }
    }
}

struct StatusDot: View {
    enum Status {
        case success, warning, error, neutral
        
        var color: Color {
            switch self {
            case .success: return DS.Colors.statusSuccess
            case .warning: return DS.Colors.statusWarning
            case .error: return DS.Colors.statusError
            case .neutral: return DS.Colors.text1
            }
        }
    }
    
    var status: Status
    var size: CGFloat = 6
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text2)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text1)
            }
        }
    }
}
