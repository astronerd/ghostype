//
//  AppPickerSheet.swift
//  AIInputMethod
//
//  共享应用选择器组件
//  扫描已安装应用，提供搜索功能
//  同时服务于「应用专属配置」和「自动回车」
//

import SwiftUI
import AppKit

// MARK: - InstalledAppInfo

struct InstalledAppInfo: Identifiable {
    let id: String  // bundleId
    let name: String
    let icon: NSImage
    let bundleId: String
}

// MARK: - AppPickerSheet

struct AppPickerSheet: View {
    let onSelect: (String) -> Void
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    @State private var installedApps: [InstalledAppInfo] = []
    @State private var isLoading = true
    
    private var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            header
            
            MinimalDivider()
            
            // 搜索框
            searchBar
            
            MinimalDivider()
            
            // 应用列表
            appList
        }
        .frame(width: 420, height: 400)
        .background(DS.Colors.bg1)
        .onAppear { loadInstalledApps() }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text(L.AppPicker.title)
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text1)
            Spacer()
            Button(L.Common.done) { isPresented = false }
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
                .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.text3)
            
            TextField(L.Library.search, text: $searchText)
                .textFieldStyle(.plain)
                .font(DS.Typography.body)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.highlight)
        .cornerRadius(DS.Layout.cornerRadius)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }
    
    // MARK: - App List
    
    private var appList: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L.Common.loading)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Spacer()
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 36))
                        .foregroundColor(DS.Colors.text3)
                    Text(L.AppPicker.noApps)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text2)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filteredApps) { app in
                    Button(action: {
                        onSelect(app.bundleId)
                        isPresented = false
                    }) {
                        HStack(spacing: DS.Spacing.md) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(DS.Typography.body)
                                    .foregroundColor(DS.Colors.text1)
                                Text(app.bundleId)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.text2)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Load Installed Apps
    
    private func loadInstalledApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = Self.scanInstalledApps()
            DispatchQueue.main.async {
                self.installedApps = apps
                self.isLoading = false
            }
        }
    }
    
    /// 扫描已安装应用
    static func scanInstalledApps() -> [InstalledAppInfo] {
        let fm = FileManager.default
        var seenBundleIds = Set<String>()
        var results: [InstalledAppInfo] = []
        
        // 扫描目录列表
        let searchDirs = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications"
        ]
        
        for dir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents {
                guard item.hasSuffix(".app") else { continue }
                let appPath = (dir as NSString).appendingPathComponent(item)
                let appURL = URL(fileURLWithPath: appPath)
                
                guard let bundle = Bundle(url: appURL),
                      let bundleId = bundle.bundleIdentifier,
                      !seenBundleIds.contains(bundleId) else { continue }
                
                seenBundleIds.insert(bundleId)
                
                let name = fm.displayName(atPath: appPath)
                    .replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: appPath)
                
                results.append(InstalledAppInfo(
                    id: bundleId,
                    name: name,
                    icon: icon,
                    bundleId: bundleId
                ))
            }
        }
        
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
