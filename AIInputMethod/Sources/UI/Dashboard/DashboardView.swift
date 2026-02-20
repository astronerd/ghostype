//
//  DashboardView.swift
//  AIInputMethod
//
//  Dashboard 主视图 - Radical Minimalist 极简风格
//  2栏布局：Sidebar + Content，1px 边框分隔，无阴影
//

import SwiftUI
import AppKit

// MARK: - Dashboard 主视图

struct DashboardView: View {
    
    // MARK: - Properties
    
    @State private var dashboardState = DashboardState()
    @State private var permissionManager = PermissionManager()
    @State private var showPermissionBanner = false
    @ObservedObject private var localization = LocalizationManager.shared
    
    /// 权限轮询定时器
    @State private var permissionPollTimer: Timer?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 权限提醒 Banner
            if showPermissionBanner && dashboardState.phase == .normal {
                PermissionReminderBanner(
                    isAccessibilityGranted: permissionManager.isAccessibilityTrusted,
                    isMicrophoneGranted: permissionManager.isMicrophoneGranted,
                    onDismiss: { showPermissionBanner = false },
                    onRequestAccessibility: requestAccessibility,
                    onRequestMicrophone: requestMicrophone
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            HStack(spacing: 0) {
                // Sidebar
                SidebarView(
                    selectedItem: $dashboardState.selectedNavItem,
                    isEnabled: dashboardState.isSidebarNavigationEnabled,
                    deviceId: DeviceIdManager.shared.truncatedId()
                )
                .frame(width: DS.Layout.sidebarWidth)
                
                // 1px 分隔线
                MinimalDivider(vertical: true)
                
                // Content Area
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DS.Colors.bg1)
        .environment(dashboardState)
        .id(localization.currentLanguage)
        .onAppear {
            checkPermissions()
        }
        .onDisappear {
            permissionManager.stopPolling()
        }
    }
    
    // MARK: - Permission Check
    
    private func checkPermissions() {
        permissionManager.refreshAll()
        
        if !permissionManager.isAccessibilityTrusted || !permissionManager.isMicrophoneGranted {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPermissionBanner = true
            }
            // 开始轮询，权限全部授予后自动隐藏 banner 并重启 hotkey
            permissionManager.startPolling {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showPermissionBanner = false
                }
                // 权限授予后通知 AppDelegate 重启 hotkey event tap
                NotificationCenter.default.post(name: .permissionsDidChange, object: nil)
            }
        }
    }
    
    private func requestAccessibility() {
        permissionManager.promptForAccessibility()
        // 开始轮询等待用户在系统设置中授权
        permissionManager.startPolling {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPermissionBanner = false
            }
            NotificationCenter.default.post(name: .permissionsDidChange, object: nil)
        }
    }
    
    private func requestMicrophone() {
        permissionManager.requestMicrophoneAccess()
        // 开始轮询等待用户授权
        permissionManager.startPolling {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPermissionBanner = false
            }
            NotificationCenter.default.post(name: .permissionsDidChange, object: nil)
        }
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        normalContentView
    }
    
    @ViewBuilder
    private var normalContentView: some View {
        switch dashboardState.selectedNavItem {
        case .account:
            AccountPage()
        case .overview:
            OverviewPageWithData()
        case .incubator:
            IncubatorPage()
        case .skills:
            SkillPage()
        case .memo:
            MemoPage()
        case .memoSync:
            MemoSyncSettingsView()
        case .library:
            LibraryPageWithData()
        case .aiPolish:
            AIPolishPage()
        case .debugData:
            DebugDataPage()
        case .preferences:
            PreferencesPage()
        }
    }
}

// MARK: - Permission Reminder Banner

struct PermissionReminderBanner: View {
    let isAccessibilityGranted: Bool
    let isMicrophoneGranted: Bool
    let onDismiss: () -> Void
    let onRequestAccessibility: () -> Void
    let onRequestMicrophone: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.statusWarning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(L.Banner.permissionTitle)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                
                Text(permissionMessage)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            // 按缺失权限分别显示按钮
            if !isAccessibilityGranted {
                Button(action: onRequestAccessibility) {
                    Text(L.Banner.grantAccessibility)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text1)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            
            if !isMicrophoneGranted {
                Button(action: onRequestMicrophone) {
                    Text(L.Banner.grantMicrophone)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text1)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.text2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.bg2)
        .overlay(
            Rectangle()
                .fill(DS.Colors.statusWarning)
                .frame(height: 2),
            alignment: .bottom
        )
    }
    
    private var permissionMessage: String {
        var missing: [String] = []
        if !isAccessibilityGranted { missing.append(L.Prefs.accessibility) }
        if !isMicrophoneGranted { missing.append(L.Prefs.microphone) }
        return "\(L.Banner.permissionMissing): \(missing.joined(separator: "、"))"
    }
}

// MARK: - Visual Effect View (保留用于兼容)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .frame(width: 1000, height: 700)
    }
}
#endif
