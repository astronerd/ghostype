//
//  AppleNotesConfigView.swift
//  AIInputMethod
//
//  Apple Notes 同步配置视图 - 文件夹名称、分组模式、标题模板、测试连接
//  Validates: Requirements 3.5, 6.1, 6.2, 8.3, 8.4, 8.5, 8.6
//

import SwiftUI

// MARK: - AppleNotesConfigView

struct AppleNotesConfigView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var config: SyncAdapterConfig
    @State private var connectionState: ConnectionState = .idle

    // MARK: - Init

    init() {
        let existing = SyncConfigStore.shared.config(for: .appleNotes)
            ?? SyncAdapterConfig(
                groupingMode: .perDay,
                titleTemplate: "GHOSTYPE Memo {date}",
                appleNotesFolderName: "GHOSTYPE"
            )
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
                    folderSection
                    groupingSection
                    templateSection
                    connectionSection
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 450, height: 350)
        .background(DS.Colors.bg1)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L.MemoSync.appleNotes)
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

    // MARK: - Folder Section

    private var folderSection: some View {
        MinimalSettingsSection(title: L.MemoSync.folderName, icon: "folder") {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.icon)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)

                TextField("GHOSTYPE", text: Binding(
                    get: { config.appleNotesFolderName ?? "GHOSTYPE" },
                    set: { newValue in
                        config.appleNotesFolderName = newValue.isEmpty ? "GHOSTYPE" : newValue
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
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.MemoSync.templateVariables)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                    Text(L.MemoSync.templateExample)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                }
                .padding(.leading, 40)
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
            let result = await AppleNotesAdapter().validateConnection(config: config)
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
        SyncConfigStore.shared.save(config: config, for: .appleNotes)
    }
}
