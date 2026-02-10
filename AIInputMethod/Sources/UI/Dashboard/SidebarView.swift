//
//  SidebarView.swift
//  AIInputMethod
//
//  Dashboard Sidebar 视图 - Radical Minimalist 极简风格
//  高密度树形导航，紧凑行高，无毛玻璃效果
//

import SwiftUI
import AppKit

// MARK: - SidebarView

struct SidebarView: View {
    
    // MARK: - Properties
    
    @Binding var selectedItem: NavItem
    var isEnabled: Bool
    var deviceId: String
    @ObservedObject private var authManager = AuthManager.shared
    
    // MARK: - Body
    
    var body: some View {
        // 直接在 body 中访问 QuotaManager.shared，确保 SwiftUI 追踪变化
        let quotaManager = QuotaManager.shared
        
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题
            headerSection
            
            // 导航列表
            navigationSection
            
            Spacer()
            
            // 底部设备信息
            bottomSection(quotaManager: quotaManager)
        }
        .frame(maxHeight: .infinity)
        .background(DS.Colors.bg2)
        .onAppear {
            // 刷新服务器额度数据
            Task { await QuotaManager.shared.refresh() }
        }
        .onChange(of: authManager.isLoggedIn) { _, isLoggedIn in
            // 未登录时自动切换到 AccountPage
            if !isLoggedIn && selectedItem.requiresAuth {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedItem = .account
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            GHOSTYPELogo()
                .frame(width: 152, height: 21)
            
            Text("Your Type of Spirit.")
                .font(DS.Typography.caption.italic())
                .foregroundColor(DS.Colors.text2)
        }
        .padding(.top, DS.Spacing.xl)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xl)
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(Array(NavItem.groups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(group) { item in
                        let itemEnabled = isEnabled && (!item.requiresAuth || authManager.isLoggedIn)
                        SidebarNavItem(
                            item: item,
                            isSelected: selectedItem == item,
                            isEnabled: itemEnabled
                        ) {
                            if itemEnabled {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedItem = item
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
    }
    
    // MARK: - Bottom Section
    
    private func bottomSection(quotaManager: QuotaManager) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            MinimalDivider()
                .padding(.horizontal, DS.Spacing.lg)
            
            // 设备 ID
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.icon)
                
                Text(deviceId)
                    .font(DS.Typography.mono(10, weight: .regular))
                    .foregroundColor(DS.Colors.text2)
            }
            .padding(.horizontal, DS.Spacing.lg)
            
            // 额度进度
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text(L.Quota.monthlyQuota)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    Spacer()
                    Text("\(Int(quotaManager.usedPercentage * 100))%")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(DS.Colors.border)
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(quotaManager.usedPercentage > 0.9 ? DS.Colors.statusWarning : DS.Colors.text1)
                            .frame(width: geo.size.width * min(quotaManager.usedPercentage, 1.0), height: 3)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.bottom, DS.Spacing.xl)
    }
}

// MARK: - SidebarNavItem

struct SidebarNavItem: View {
    let item: NavItem
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? DS.Colors.text1 : DS.Colors.icon)
                    .frame(width: 18)
                
                Text(item.title)
                    .font(DS.Typography.body)
                    .foregroundColor(isSelected ? DS.Colors.text1 : DS.Colors.text2)
                
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .frame(height: DS.Layout.sidebarRowHeight)
            .background(backgroundColor)
            .cornerRadius(DS.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return DS.Colors.highlight
        } else if isHovered && isEnabled {
            return DS.Colors.highlight.opacity(0.5)
        }
        return Color.clear
    }
}

// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(
            selectedItem: .constant(.overview),
            isEnabled: true,
            deviceId: "ABCD1234"
        )
        .frame(width: DS.Layout.sidebarWidth, height: 600)
    }
}
#endif
