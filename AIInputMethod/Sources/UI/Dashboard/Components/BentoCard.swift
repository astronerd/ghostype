//
//  BentoCard.swift
//  AIInputMethod
//
//  Bento 风格卡片组件
//  实现 16pt 圆角、阴影和 hover 时 1.02x 缩放动画
//  Validates: Requirements 5.6, 5.7
//

import SwiftUI

// MARK: - BentoCard

/// Bento 风格卡片组件
/// 用于 Dashboard 概览页的数据展示卡片
/// - Requirement 5.6: hover 时 1.02x 缩放动画 (200ms)
/// - Requirement 5.7: 16pt 圆角和阴影
struct BentoCard<Content: View>: View {
    
    // MARK: - Properties
    
    /// 卡片标题
    var title: String
    
    /// SF Symbol 图标名称
    var icon: String
    
    /// 卡片内容
    @ViewBuilder var content: () -> Content
    
    // MARK: - State
    
    /// 悬停状态
    @State private var isHovered: Bool = false
    
    // MARK: - Constants
    
    /// 圆角半径 (Requirement 5.7: 16pt radius)
    private let cornerRadius: CGFloat = 16
    
    /// 缩放比例 (Requirement 5.6: 1.02x scale)
    private let hoverScale: CGFloat = 1.02
    
    /// 动画时长 (Requirement 5.6: 200ms transition)
    private let animationDuration: Double = 0.2
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: 卡片头部
            headerView
            
            // MARK: 卡片内容
            content()
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // Requirement 5.7: subtle shadow
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        // Requirement 5.6: 1.02x scale transform on hover
        .scaleEffect(isHovered ? hoverScale : 1.0)
        // Requirement 5.6: 200ms transition
        .animation(.easeInOut(duration: animationDuration), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - Header View
    
    /// 卡片头部视图（图标 + 标题）
    private var headerView: some View {
        HStack(spacing: 8) {
            // SF Symbol 图标
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
            
            // 标题
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - Background
    
    /// 卡片背景
    private var cardBackground: some View {
        // 使用系统背景色，支持 light/dark mode
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Shadow Properties
    
    /// 阴影颜色
    private var shadowColor: Color {
        Color.black.opacity(0.08)
    }
    
    /// 阴影半径
    private var shadowRadius: CGFloat {
        isHovered ? 12 : 8
    }
    
    /// 阴影 Y 偏移
    private var shadowY: CGFloat {
        isHovered ? 6 : 4
    }
}

// MARK: - Preview

#if DEBUG
struct BentoCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 基础卡片预览
            BentoCard(title: "今日战报", icon: "chart.bar.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1,234")
                        .font(.system(size: 32, weight: .bold))
                    Text("字符输入")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 150)
            .padding()
            .previewDisplayName("Today Stats Card")
            
            // 能量环卡片预览
            BentoCard(title: "本月能量环", icon: "circle.circle.fill") {
                Text("能量环内容")
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, height: 150)
            .padding()
            .previewDisplayName("Energy Ring Card")
            
            // 深色模式预览
            BentoCard(title: "应用分布", icon: "chart.pie.fill") {
                Text("饼图内容")
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, height: 150)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
