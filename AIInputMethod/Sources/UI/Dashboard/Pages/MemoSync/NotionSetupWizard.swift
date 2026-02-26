//
//  NotionSetupWizard.swift
//  AIInputMethod
//
//  Notion 配置分步向导 - 引导用户完成 Internal Integration 配置
//  步骤：打开开发者门户 → 创建 Integration → 复制 Token → 粘贴到 GHOSTYPE → 选择数据库
//  Validates: Requirements 9.1, 9.2, 9.4, 9.5
//

import SwiftUI

// MARK: - NotionSetupWizard

struct NotionSetupWizard: View {

    @Environment(\.dismiss) private var dismiss

    /// 完成回调：(token, databaseId?)
    var onComplete: (String, String?) -> Void

    @State private var currentStep: Int = 1
    @State private var tokenInput: String = ""
    @State private var databaseIdInput: String = ""
    @State private var connectionState: ConnectionState = .idle

    private let totalSteps = 5
    private let notionPortalURL = URL(string: "https://www.notion.so/my-integrations")!

    // MARK: - Connection State

    private enum ConnectionState {
        case idle, testing, connected, failed
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            MinimalDivider()

            // Step content
            VStack(spacing: DS.Spacing.xl) {
                stepIndicator
                stepContent
                Spacer()
                navigationButtons
            }
            .padding(DS.Spacing.xl)
        }
        .frame(width: 500, height: 400)
        .background(DS.Colors.bg1)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L.MemoSync.notionSetupTitle)
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text1)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.text2)
                    .frame(width: 24, height: 24)
                    .background(DS.Colors.highlight)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? DS.Colors.statusSuccess : (step < currentStep ? DS.Colors.statusSuccess.opacity(0.4) : DS.Colors.text3.opacity(0.3)))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 1:
            stepView(
                stepNumber: 1,
                description: L.MemoSync.notionStep1,
                actionButton: {
                    Button(action: { NSWorkspace.shared.open(notionPortalURL) }) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.up.right.square")
                            Text(L.MemoSync.openNotionPortal)
                        }
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                    }
                    .buttonStyle(.plain)
                }
            )
        case 2:
            stepView(
                stepNumber: 2,
                description: L.MemoSync.notionStep2,
                actionButton: { EmptyView() }
            )
        case 3:
            stepView(
                stepNumber: 3,
                description: L.MemoSync.notionStep3,
                actionButton: { EmptyView() }
            )
        case 4:
            stepView(
                stepNumber: 4,
                description: L.MemoSync.notionStep4,
                actionButton: {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SecureField(L.MemoSync.token, text: $tokenInput)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                            .padding(DS.Spacing.sm)
                            .background(DS.Colors.bg2)
                            .cornerRadius(DS.Layout.cornerRadius)

                        if case .testing = connectionState {
                            HStack(spacing: DS.Spacing.xs) {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                Text(L.MemoSync.testing)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.text2)
                            }
                        } else if case .connected = connectionState {
                            HStack(spacing: DS.Spacing.xs) {
                                StatusDot(status: .success, size: 8)
                                Text(L.MemoSync.connected)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.statusSuccess)
                            }
                        } else if case .failed = connectionState {
                            HStack(spacing: DS.Spacing.xs) {
                                StatusDot(status: .error, size: 8)
                                Text(L.MemoSync.disconnected)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.statusError)
                            }
                        }
                    }
                }
            )
        case 5:
            stepView(
                stepNumber: 5,
                description: L.MemoSync.notionStep5,
                actionButton: {
                    TextField(L.MemoSync.databaseId, text: $databaseIdInput)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.bg2)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
            )
        default:
            EmptyView()
        }
    }

    private func stepView<ActionContent: View>(
        stepNumber: Int,
        description: String,
        @ViewBuilder actionButton: () -> ActionContent
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(description)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
                .fixedSize(horizontal: false, vertical: true)

            actionButton()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep > 1 {
                Button(action: { currentStep -= 1 }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "chevron.left")
                        Text(L.Onboarding.back)
                    }
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text2)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if currentStep < totalSteps {
                Button(action: handleNext) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L.Onboarding.next)
                        Image(systemName: "chevron.right")
                    }
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: handleFinish) {
                    Text(L.Common.done)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
                .disabled(tokenInput.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func handleNext() {
        if currentStep == 4 && !tokenInput.isEmpty {
            // Token 输入后自动测试连接
            testToken()
        }
        currentStep += 1
    }

    private func handleFinish() {
        guard !tokenInput.isEmpty else { return }
        // 保存 Token 到 Keychain
        KeychainHelper.save(key: NotionAdapter.tokenKeychainKey, value: tokenInput)
        onComplete(tokenInput, databaseIdInput.isEmpty ? nil : databaseIdInput)
        dismiss()
    }

    private func testToken() {
        guard !tokenInput.isEmpty else { return }
        connectionState = .testing
        // 先保存 Token 以便 validateConnection 能读取
        KeychainHelper.save(key: NotionAdapter.tokenKeychainKey, value: tokenInput)

        Task {
            let config = SyncAdapterConfig(
                groupingMode: .perDay,
                titleTemplate: "GHOSTYPE Memo {date}",
                notionDatabaseId: databaseIdInput.isEmpty ? nil : databaseIdInput
            )
            let result = await NotionAdapter().validateConnection(config: config)
            await MainActor.run {
                switch result {
                case .success:
                    connectionState = .connected
                case .failure:
                    connectionState = .failed
                }
            }
        }
    }
}
