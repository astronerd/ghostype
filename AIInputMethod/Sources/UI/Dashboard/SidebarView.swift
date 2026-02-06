//
//  SidebarView.swift
//  AIInputMethod
//
//  Dashboard Sidebar 视图
//  使用 NSVisualEffectView 实现毛玻璃效果，包含导航项列表和底部设备信息区域
//  Validates: Requirements 3.3, 4.1, 4.2, 4.3, 4.5, 4.6, 2.5
//

import SwiftUI
import AppKit

// MARK: - SidebarView

/// Dashboard Sidebar 视图
/// 实现毛玻璃效果的侧边栏，包含导航项和设备信息
/// - Requirements 3.3: 使用 NSVisualEffectView with .sidebar material
/// - Requirements 4.1: 显示导航项 (概览、历史库、偏好设置)
/// - Requirements 4.2: 点击导航项切换内容区域
/// - Requirements 4.3: 高亮当前选中的导航项
/// - Requirements 4.5: 底部显示 Device_ID 和额度进度条
/// - Requirements 4.6, 2.5: Onboarding 时禁用导航项
struct SidebarView: View {
    
    // MARK: - Properties
    
    /// 当前选中的导航项
    @Binding var selectedItem: NavItem
    
    /// 是否启用导航（Onboarding 时禁用）
    var isEnabled: Bool
    
    /// 设备 ID（截断显示）
    var deviceId: String
    
    /// 额度使用百分比 (0.0 - 1.0)
    var quotaPercentage: Double
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: 顶部标题区域
            headerSection
            
            // MARK: 导航项列表
            // Requirement 4.1: THE Sidebar SHALL display navigation items
            navigationSection
            
            Spacer()
            
            // MARK: 底部设备信息区域
            // Requirement 4.5: THE Sidebar bottom section SHALL display Device_ID and quota progress bar
            bottomSection
        }
        .frame(maxHeight: .infinity)
        .background(
            // Requirement 3.3: THE Sidebar SHALL use NSVisualEffectView with .sidebar material
            SidebarVisualEffectView()
        )
        // Requirement 4.6, 2.5: Onboarding 时视觉上禁用
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    // MARK: - Header Section
    
    /// 顶部标题区域
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GhosTYPE")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Dashboard")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
    
    // MARK: - Navigation Section
    
    /// 导航项列表区域
    private var navigationSection: some View {
        VStack(spacing: 4) {
            ForEach(NavItem.allCases) { item in
                SidebarNavigationItemView(
                    item: item,
                    isSelected: selectedItem == item,
                    isEnabled: isEnabled
                ) {
                    // Requirement 4.2: WHEN a navigation item is clicked, switch Content area
                    if isEnabled {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedItem = item
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Bottom Section
    
    /// 底部设备信息和额度区域
    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal, 16)
            
            // 设备 ID 显示
            // Requirement 4.5: Display Device_ID (truncated)
            deviceIdRow
            
            // 额度进度条
            // Requirement 4.5: Display quota progress bar
            quotaProgressSection
        }
        .padding(.bottom, 20)
    }
    
    /// 设备 ID 行
    private var deviceIdRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(deviceId)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
    
    /// 额度进度条区域
    private var quotaProgressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("本月额度")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text(quotaPercentageText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // 额度进度条
            QuotaProgressBar(percentage: quotaPercentage)
                .frame(height: 4)
        }
        .padding(.horizontal, 16)
    }
    
    /// 额度百分比文本
    private var quotaPercentageText: String {
        let percentage = Int(quotaPercentage * 100)
        return "\(percentage)%"
    }
}

// MARK: - SidebarNavigationItemView

/// Sidebar 导航项视图
/// 实现单个导航项的显示和交互
/// - Requirement 4.3: 高亮当前选中的导航项
/// - Requirement 4.4: 显示 SF Symbols 图标
struct SidebarNavigationItemView: View {
    
    // MARK: - Properties
    
    /// 导航项
    let item: NavItem
    
    /// 是否选中
    let isSelected: Bool
    
    /// 是否启用
    let isEnabled: Bool
    
    /// 点击动作
    let action: () -> Void
    
    // MARK: - State
    
    /// 悬停状态
    @State private var isHovered: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // SF Symbol 图标
                // Requirement 4.4: Display SF Symbols icons
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(foregroundColor)
                    .frame(width: 20)
                
                // 导航项标题
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(foregroundColor)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                // Requirement 4.3: Highlight selected item with accent color background
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - Computed Properties
    
    /// 前景色（文字和图标颜色）
    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if !isEnabled {
            return .secondary.opacity(0.5)
        } else {
            return .primary
        }
    }
    
    /// 背景色
    private var backgroundColor: Color {
        if isSelected {
            // Requirement 4.3: accent color background for selected item
            return Color.accentColor
        } else if isHovered && isEnabled {
            return Color.primary.opacity(0.08)
        } else {
            return Color.clear
        }
    }
}

// MARK: - QuotaProgressBar

/// 额度进度条组件
/// 显示当前额度使用情况，超过 90% 显示警告色
struct QuotaProgressBar: View {
    
    // MARK: - Properties
    
    /// 使用百分比 (0.0 - 1.0)
    let percentage: Double
    
    /// 警告阈值
    private let warningThreshold: Double = 0.9
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                
                // 进度条
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressColor)
                    .frame(width: progressWidth(for: geometry.size.width))
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// 进度条颜色
    private var progressColor: Color {
        if percentage >= warningThreshold {
            return Color.orange
        } else {
            return Color.accentColor
        }
    }
    
    /// 计算进度条宽度
    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        let clampedPercentage = min(max(percentage, 0.0), 1.0)
        return totalWidth * CGFloat(clampedPercentage)
    }
}

// MARK: - SidebarVisualEffectView

/// Sidebar 毛玻璃效果视图
/// 使用 NSVisualEffectView 实现 .sidebar material 的毛玻璃效果
/// Requirement 3.3: THE Sidebar SHALL use NSVisualEffectView with .sidebar material
struct SidebarVisualEffectView: NSViewRepresentable {
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Requirement 3.3: .sidebar material for translucent glass effect
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}

// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 正常状态预览
            SidebarView(
                selectedItem: .constant(.overview),
                isEnabled: true,
                deviceId: DeviceIdManager.shared.truncatedId(),
                quotaPercentage: 0.35
            )
            .frame(width: 220, height: 600)
            .previewDisplayName("Normal State")
            
            // Onboarding 禁用状态预览
            SidebarView(
                selectedItem: .constant(.overview),
                isEnabled: false,
                deviceId: DeviceIdManager.shared.truncatedId(),
                quotaPercentage: 0.35
            )
            .frame(width: 220, height: 600)
            .previewDisplayName("Onboarding State (Disabled)")
            
            // 高额度使用状态预览
            SidebarView(
                selectedItem: .constant(.library),
                isEnabled: true,
                deviceId: "ABCD1234",
                quotaPercentage: 0.95
            )
            .frame(width: 220, height: 600)
            .previewDisplayName("High Quota Usage")
        }
    }
}
#endif
