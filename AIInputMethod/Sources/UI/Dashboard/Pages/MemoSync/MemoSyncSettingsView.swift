//
//  MemoSyncSettingsView.swift
//  AIInputMethod
//
//  笔记同步主设置页 - 为每个笔记应用显示配置卡片
//  Validates: Requirements 8.1, 8.2, 8.3, 8.7, 8.8
//

import SwiftUI

// MARK: - SyncServiceType + Identifiable (for .sheet(item:))

extension SyncServiceType: Identifiable {
    var id: String { rawValue }
}

// MARK: - MemoSyncSettingsView

struct MemoSyncSettingsView: View {
    
    @State private var enabledStates: [SyncServiceType: Bool] = [:]
    @State private var connectionStates: [SyncServiceType: ConnectionState] = [:]
    @State private var activeConfigSheet: SyncServiceType? = nil
    
    // MARK: - Connection State
    
    enum ConnectionState {
        case idle
        case testing
        case connected
        case disconnected
        
        var statusDot: StatusDot.Status {
            switch self {
            case .idle: return .neutral
            case .testing: return .warning
            case .connected: return .success
            case .disconnected: return .error
            }
        }
        
        var label: String {
            switch self {
            case .idle: return L.MemoSync.disconnected
            case .testing: return L.MemoSync.testing
            case .connected: return L.MemoSync.connected
            case .disconnected: return L.MemoSync.disconnected
            }
        }
    }

    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L.MemoSync.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text1)
                    
                    Text(L.MemoSync.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                .padding(.bottom, DS.Spacing.sm)
                
                // Adapter cards
                adapterCard(for: .obsidian, icon: "doc.text", name: L.MemoSync.obsidian)
                adapterCard(for: .appleNotes, icon: "note.text", name: L.MemoSync.appleNotes)
                adapterCard(for: .notion, icon: "square.stack.3d.up", name: L.MemoSync.notion)
                adapterCard(for: .bear, icon: "pawprint", name: L.MemoSync.bear)
                
                Spacer(minLength: DS.Spacing.xl)
            }
            .padding(.top, 21)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
        .onAppear { loadStates() }
        .sheet(item: $activeConfigSheet) { serviceType in
            configView(for: serviceType)
        }
    }
    
    // MARK: - Adapter Card
    
    private func adapterCard(for service: SyncServiceType, icon: String, name: String) -> some View {
        MinimalSettingsSection(title: name, icon: icon) {
            VStack(spacing: 0) {
                // Enable toggle
                MinimalToggleRow(
                    title: L.MemoSync.enableSync,
                    subtitle: name,
                    icon: icon,
                    isOn: Binding(
                        get: { enabledStates[service] ?? false },
                        set: { newValue in
                            enabledStates[service] = newValue
                            SyncConfigStore.shared.setEnabled(newValue, for: service)
                            if newValue && SyncConfigStore.shared.config(for: service) == nil {
                                let defaultConfig = SyncAdapterConfig(
                                    groupingMode: .perDay,
                                    titleTemplate: "GHOSTYPE Memo {date}"
                                )
                                SyncConfigStore.shared.save(config: defaultConfig, for: service)
                            }
                        }
                    )
                )
                
                if enabledStates[service] == true {
                    MinimalDivider()
                        .padding(.leading, 44)
                    
                    // Connection status row
                    statusRow(for: service)
                    
                    MinimalDivider()
                        .padding(.leading, 44)
                    
                    // Config entry
                    MinimalNavigationRow(
                        title: name,
                        subtitle: configSummary(for: service),
                        icon: "gearshape"
                    ) {
                        activeConfigSheet = service
                    }
                }
            }
        }
    }

    // MARK: - Status Row
    
    private func statusRow(for service: SyncServiceType) -> some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                StatusDot(
                    status: (connectionStates[service] ?? .idle).statusDot,
                    size: 8
                )
                
                Text((connectionStates[service] ?? .idle).label)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            Button(action: { testConnection(for: service) }) {
                HStack(spacing: DS.Spacing.xs) {
                    if case .testing = connectionStates[service] {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    }
                    Text(L.MemoSync.testConnection)
                        .font(DS.Typography.caption)
                }
                .foregroundColor(DS.Colors.text1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.highlight)
                .cornerRadius(DS.Layout.cornerRadius)
            }
            .buttonStyle(.plain)
            .disabled({
                if case .testing = connectionStates[service] { return true }
                return false
            }())
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - Helpers
    
    private func configSummary(for service: SyncServiceType) -> String {
        guard let config = SyncConfigStore.shared.config(for: service) else {
            return L.MemoSync.disconnected
        }
        switch config.groupingMode {
        case .perNote: return L.MemoSync.perNote
        case .perDay: return L.MemoSync.perDay
        case .perWeek: return L.MemoSync.perWeek
        }
    }
    
    private func loadStates() {
        for service in SyncServiceType.allCases {
            enabledStates[service] = SyncConfigStore.shared.isEnabled(service)
        }
        // 自动检测已启用 adapter 的连接状态
        for service in SyncServiceType.allCases {
            guard SyncConfigStore.shared.isEnabled(service),
                  SyncConfigStore.shared.config(for: service) != nil else { continue }
            connectionStates[service] = .testing
            let adapter: MemoSyncService
            switch service {
            case .obsidian: adapter = ObsidianAdapter()
            case .appleNotes: adapter = AppleNotesAdapter()
            case .notion: adapter = NotionAdapter()
            case .bear: adapter = BearAdapter()
            }
            let config = SyncConfigStore.shared.config(for: service)!
            Task {
                let result = await adapter.validateConnection(config: config)
                await MainActor.run {
                    switch result {
                    case .success:
                        connectionStates[service] = .connected
                    case .failure:
                        connectionStates[service] = .disconnected
                    }
                }
            }
        }
    }
    
    private func testConnection(for service: SyncServiceType) {
        connectionStates[service] = .testing
        
        let adapter: MemoSyncService
        switch service {
        case .obsidian: adapter = ObsidianAdapter()
        case .appleNotes: adapter = AppleNotesAdapter()
        case .notion: adapter = NotionAdapter()
        case .bear: adapter = BearAdapter()
        }
        
        guard let config = SyncConfigStore.shared.config(for: service) else {
            connectionStates[service] = .disconnected
            return
        }
        
        Task {
            let result = await adapter.validateConnection(config: config)
            await MainActor.run {
                switch result {
                case .success:
                    connectionStates[service] = .connected
                case .failure:
                    connectionStates[service] = .disconnected
                }
            }
        }
    }
    
    // MARK: - Config Views
    
    @ViewBuilder
    private func configView(for service: SyncServiceType) -> some View {
        switch service {
        case .obsidian:
            ObsidianConfigView()
        case .appleNotes:
            AppleNotesConfigView()
        case .notion:
            NotionConfigView()
        case .bear:
            BearConfigView()
        }
    }

}
