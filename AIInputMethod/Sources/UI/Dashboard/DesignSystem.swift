//
//  DesignSystem.swift
//  AIInputMethod
//
//  统一设计系统 - Radical Minimalist 极简配色方案
//  支持亮色/深色模式自动切换
//

import SwiftUI
import AppKit

// MARK: - Design Tokens

enum DS {
    
    // MARK: - Colors (统一配色 - 支持深色模式)
    
    enum Colors {
        /// 主背景 - 亮色: Porcelain / 深色: Carbon Black
        static let bg1 = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 29/255, green: 34/255, blue: 37/255, alpha: 1) 
                              : NSColor(red: 247/255, green: 247/255, blue: 244/255, alpha: 1)
        })
        
        /// 次级背景 - 亮色: Parchment / 深色: Jet Black
        static let bg2 = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 38/255, green: 42/255, blue: 45/255, alpha: 1)
                              : NSColor(red: 241/255, green: 240/255, blue: 237/255, alpha: 1)
        })
        
        /// 高亮/选中背景
        static let highlight = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 55/255, green: 60/255, blue: 65/255, alpha: 1)
                              : NSColor(red: 227/255, green: 228/255, blue: 224/255, alpha: 1)
        })
        
        /// 边框/分隔线
        static let border = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 70/255, green: 75/255, blue: 80/255, alpha: 1)
                              : NSColor(red: 206/255, green: 205/255, blue: 201/255, alpha: 1)
        })
        
        /// 一级文字 - 主标题
        static let text1 = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 240/255, green: 240/255, blue: 238/255, alpha: 1)
                              : NSColor(red: 38/255, green: 37/255, blue: 30/255, alpha: 1)
        })

        /// 二级文字 - 副标题
        static let text2 = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 160/255, green: 165/255, blue: 170/255, alpha: 1)
                              : NSColor(red: 137/255, green: 136/255, blue: 131/255, alpha: 1)
        })
        
        /// 三级文字 - 更浅
        static let text3 = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 110/255, green: 115/255, blue: 120/255, alpha: 1)
                              : NSColor(red: 184/255, green: 188/255, blue: 191/255, alpha: 1)
        })
        
        /// 图标颜色
        static let icon = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(red: 140/255, green: 145/255, blue: 150/255, alpha: 1)
                              : NSColor(red: 137/255, green: 136/255, blue: 131/255, alpha: 1)
        })
        
        // 兼容旧代码的别名
        static let background = bg1
        static let backgroundSecondary = bg2
        static let sidebarBackground = bg2
        static let textPrimary = text1
        static let textSecondary = text2
        static let textTertiary = text3
        static let divider = border
        
        /// 状态色 - muted colors
        static let statusSuccess = Color(red: 101/255, green: 163/255, blue: 13/255).opacity(0.85)
        static let statusWarning = Color(red: 217/255, green: 119/255, blue: 6/255).opacity(0.85)
        static let statusError = Color(red: 220/255, green: 38/255, blue: 38/255).opacity(0.85)
        
        /// 强调色
        static let accent = text1
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
        
        static let largeTitle = ui(24, weight: .medium)
        static let title = ui(16, weight: .medium)
        static let body = ui(13, weight: .regular)
        static let caption = ui(11, weight: .regular)
        static let sectionHeader = ui(10, weight: .medium)
    }

    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Layout
    
    enum Layout {
        static let sidebarWidth: CGFloat = 200
        static let contentMinWidth: CGFloat = 600
        static let cornerRadius: CGFloat = 4
        static let borderWidth: CGFloat = 1
        static let sidebarRowHeight: CGFloat = 32
    }
}

// MARK: - NSAppearance Extension

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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
                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
    }
}

struct SidebarItemStyle: ViewModifier {
    var isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(height: DS.Layout.sidebarRowHeight)
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
                .fill(DS.Colors.border)
                .frame(width: DS.Layout.borderWidth)
        } else {
            Rectangle()
                .fill(DS.Colors.border)
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
            case .neutral: return DS.Colors.text2
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
    
    var body: some View {
        Text(title.uppercased())
            .font(DS.Typography.sectionHeader)
            .foregroundColor(DS.Colors.text2)
            .tracking(1.5)
    }
}


// MARK: - GHOSTYPE Logo View (从 SVG 文件加载)

struct GHOSTYPELogo: View {
    var tintColor: Color = DS.Colors.text1
    
    var body: some View {
        SVGImageView(svgName: "logo 16px", tintColor: tintColor)
    }
}

// MARK: - SVG Image View (使用 NSImage 加载 SVG)

struct SVGImageView: NSViewRepresentable {
    let svgName: String
    var tintColor: Color = DS.Colors.text1
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        loadSVG(into: imageView)
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        loadSVG(into: nsView)
    }
    
    private func loadSVG(into imageView: NSImageView) {
        // 尝试从 bundle 加载
        if let url = Bundle.main.url(forResource: svgName, withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            imageView.image = image
            imageView.contentTintColor = NSColor(tintColor)
        } else {
            // 开发时从源码目录加载
            let devPath = "/Users/gengdawei/ghostype/AIInputMethod/Sources/Resources/\(svgName).svg"
            if let image = NSImage(contentsOfFile: devPath) {
                image.isTemplate = true
                imageView.image = image
                imageView.contentTintColor = NSColor(tintColor)
            }
        }
    }
}
