//
//  NotionConfigView.swift
//  AIInputMethod
//
//  Notion 同步配置视图 - Token 状态、数据库 ID、分组模式、标题模板、测试连接、Setup Wizard 入口
//  Validates: Requirements 4.1, 4.6, 6.1, 6.2, 8.3, 8.4, 8.5, 8.6, 9.1
//

import SwiftUI

// MARK: - NotionConfigView

struct NotionConfigView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var config: SyncAdapterConfig
    @State private var connectionState: ConnectionState = .idle
    @State private var showSetupWizard = false

    // MARK: - Init

    init() {
        let existing = SyncConfigStore.shared.config(for: .notion)
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
            header
            MinimalDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    tokenSection
                    databaseSection
                    groupingSection
                    templateSection
                    connectionSection
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 450, height: 450)
        .background(DS.Colors.bg1)
        .sheet(isPresented: $showSetupWizard) {
            NotionSetupWizard(onComplete: { token, databaseId in
                // Token saved to Keychain inside wizard
                if let dbId = databaseId, !dbId.isEmpty {
                    config.notionDatabaseId = dbId
                }
                saveConfig()
                connectionState = .connected
            })
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L.MemoSync.notion)
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text1)

            Spacer()

            Button(action: {
                saveConfig()
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

    // MARK: - Token Section

    private var tokenSection: some View {
        MinimalSettingsSection(title: L.MemoSync.token, icon: "key") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "key")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.MemoSync.token)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)

                    Text(maskedToken)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { showSetupWizard = true }) {
                    Text(L.MemoSync.notionSetupTitle)
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

    /// Token 脱敏显示
    private var maskedToken: String {
        guard let token = KeychainHelper.get(key: NotionAdapter.tokenKeychainKey),
              !token.isEmpty else {
            return L.MemoSync.disconnected
        }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)****...\(suffix)"
    }

    // MARK: - Database Section

    private var databaseSection: some View {
        MinimalSettingsSection(title: L.MemoSync.databaseId, icon: "cylinder") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "cylinder")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)

                TextField(L.MemoSync.databaseId, text: Binding(
                    get: { config.notionDatabaseId ?? "" },
                    set: { newValue in
                        config.notionDatabaseId = newValue.isEmpty ? nil : newValue
                        saveConfig()
                    }
                ))
                .textFieldStyle(.plain)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
                .onSubmit { saveConfig() }
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

    private func testConnection() {
        connectionState = .testing
        Task {
            let result = await NotionAdapter().validateConnection(config: config)
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

    private func saveConfig() {
        SyncConfigStore.shared.save(config: config, for: .notion)
    }
}
