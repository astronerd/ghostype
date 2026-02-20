//
//  ObsidianConfigView.swift
//  AIInputMethod
//
//  Obsidian 同步配置视图 - NSOpenPanel 选择 Vault、分组模式、标题模板、测试连接
//  Validates: Requirements 2.1, 6.1, 6.2, 8.3, 8.4, 8.5, 8.6, 12.1
//

import SwiftUI
import AppKit

// MARK: - ObsidianConfigView

struct ObsidianConfigView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var config: SyncAdapterConfig
    @State private var vaultPathDisplay: String = ""
    @State private var connectionState: ConnectionState = .idle

    // MARK: - Init

    init() {
        let existing = SyncConfigStore.shared.config(for: .obsidian)
            ?? SyncAdapterConfig(groupingMode: .perDay, titleTemplate: "GHOSTYPE Memo {date}")
        _config = State(initialValue: existing)
    }

    // MARK: - Connection State

    private enum ConnectionState {
        case idle, testing, connected, disconnected
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            MinimalDivider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    vaultSection
                    groupingSection
                    templateSection
                    connectionSection
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 450, height: 400)
        .background(DS.Colors.bg1)
        .onAppear { resolveVaultPath() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L.MemoSync.obsidian)
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text1)

            Spacer()

            Button(action: {
                SyncConfigStore.shared.save(config: config, for: .obsidian)
                dismiss()
            }) {
                Text(L.Common.done)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: - Vault Section

    private var vaultSection: some View {
        MinimalSettingsSection(title: L.MemoSync.vaultPath, icon: "folder") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.MemoSync.vaultPath)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)

                    Text(vaultPathDisplay.isEmpty ? L.MemoSync.disconnected : vaultPathDisplay)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button(action: selectVault) {
                    Text(L.MemoSync.selectVault)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text1)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    // MARK: - Grouping Section

    private var groupingSection: some View {
        MinimalSettingsSection(title: L.MemoSync.groupingMode, icon: "rectangle.3.group") {
            VStack(spacing: 0) {
                groupingRow(.perNote, label: L.MemoSync.perNote)
                MinimalDivider().padding(.leading, 44)
                groupingRow(.perDay, label: L.MemoSync.perDay)
                MinimalDivider().padding(.leading, 44)
                groupingRow(.perWeek, label: L.MemoSync.perWeek)
            }
        }
    }

    private func groupingRow(_ mode: GroupingMode, label: String) -> some View {
        Button(action: {
            config.groupingMode = mode
            saveConfig()
        }) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: config.groupingMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(config.groupingMode == mode ? DS.Colors.statusSuccess : DS.Colors.text3)

                Text(label)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Template Section

    private var templateSection: some View {
        MinimalSettingsSection(title: L.MemoSync.titleTemplate, icon: "textformat") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "textformat")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)

                TextField(L.MemoSync.titleTemplatePlaceholder, text: $config.titleTemplate)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                    .onSubmit { saveConfig() }
                    .onChange(of: config.titleTemplate) { saveConfig() }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        MinimalSettingsSection(title: L.MemoSync.testConnection, icon: "link") {
            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    StatusDot(
                        status: connectionStatusDot,
                        size: 8
                    )

                    Text(connectionLabel)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }

                Spacer()

                Button(action: testConnection) {
                    HStack(spacing: DS.Spacing.xs) {
                        if case .testing = connectionState {
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
                .disabled(connectionState == .testing)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    private var connectionStatusDot: StatusDot.Status {
        switch connectionState {
        case .idle: return .neutral
        case .testing: return .warning
        case .connected: return .success
        case .disconnected: return .error
        }
    }

    private var connectionLabel: String {
        switch connectionState {
        case .idle: return L.MemoSync.disconnected
        case .testing: return L.MemoSync.testing
        case .connected: return L.MemoSync.connected
        case .disconnected: return L.MemoSync.disconnected
        }
    }

    // MARK: - Actions

    /// NSOpenPanel 选择 Vault 目录，创建 security-scoped bookmark
    private func selectVault() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            config.obsidianVaultBookmark = bookmarkData
            vaultPathDisplay = url.path
            saveConfig()
        } catch {
            FileLogger.log("[MemoSync] ❌ Obsidian: failed to create bookmark - \(error.localizedDescription)")
        }
    }

    /// 从 bookmark 解析并显示 Vault 路径
    private func resolveVaultPath() {
        guard let bookmarkData = config.obsidianVaultBookmark else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else { return }
        vaultPathDisplay = url.path
    }

    /// 测试连接
    private func testConnection() {
        connectionState = .testing
        Task {
            let result = await ObsidianAdapter().validateConnection(config: config)
            await MainActor.run {
                switch result {
                case .success:
                    connectionState = .connected
                case .failure:
                    connectionState = .disconnected
                }
            }
        }
    }

    /// 保存配置到 SyncConfigStore
    private func saveConfig() {
        SyncConfigStore.shared.save(config: config, for: .obsidian)
    }
}
