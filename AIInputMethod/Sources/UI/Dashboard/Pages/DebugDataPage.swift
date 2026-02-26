//
//  DebugDataPage.swift
//  AIInputMethod
//
//  临时调试页面 — 查看当前 Profile 和校准记录的原始数据
//  完全解耦，删除时只需：删此文件 + NavItem 去 case + DashboardView 去 route + 本地化删文案
//

import SwiftUI

struct DebugDataPage: View {
    
    @State private var profile: GhostTwinProfile = .initial
    @State private var records: [CalibrationRecord] = []
    @State private var selectedTab: DebugTab = .profile
    @State private var selectedRecord: CalibrationRecord?
    
    // Re-Profile 状态
    @State private var isProfilingRunning: Bool = false
    @State private var profilingStatus: ProfilingStatus = .idle
    
    enum ProfilingStatus: Equatable {
        case idle
        case running
        case success
        case error(String)
    }
    
    private let profileStore = GhostTwinProfileStore()
    private let recordStore = CalibrationRecordStore()
    private let corpusStore = ASRCorpusStore()
    
    enum DebugTab: String, CaseIterable {
        case profile = "Profile"
        case calibration = "Calibration"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, 21)
                .padding(.bottom, DS.Spacing.md)
            
            // Tab bar
            tabBar
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            
            // Content
            switch selectedTab {
            case .profile:
                profileView
            case .calibration:
                calibrationView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.Colors.bg1)
        .onAppear { reload() }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Debug Data")
                .font(DS.Typography.largeTitle)
                .foregroundColor(DS.Colors.text1)
            Text("Raw profile & calibration records")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(DebugTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(DS.Typography.body)
                        .foregroundColor(selectedTab == tab ? DS.Colors.text1 : DS.Colors.text2)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(selectedTab == tab ? DS.Colors.highlight : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? DS.Colors.border : Color.clear, lineWidth: DS.Layout.borderWidth)
                        )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Button(action: { Task { await runProfiling() } }) {
                HStack(spacing: 4) {
                    if isProfilingRunning {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: profilingStatusIcon)
                            .font(.system(size: 11))
                    }
                    Text(profilingStatusLabel)
                        .font(DS.Typography.mono(11, weight: .medium))
                }
                .foregroundColor(profilingStatusColor)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.highlight)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(profilingStatusColor.opacity(0.3), lineWidth: DS.Layout.borderWidth)
                )
            }
            .buttonStyle(.plain)
            .disabled(isProfilingRunning)
            
            Button(action: reload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.icon)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Profile View
    
    private var profileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Meta info
                infoRow("Level", "Lv.\(profile.level)")
                infoRow("Total XP", "\(profile.totalXP)")
                infoRow("Version", "v\(profile.version)")
                infoRow("Summary", profile.summary.isEmpty ? "(empty)" : profile.summary)
                infoRow("Updated", formatDate(profile.updatedAt))
                
                Divider().background(DS.Colors.border)
                
                // Profile text
                Text("profileText")
                    .font(DS.Typography.mono(11, weight: .bold))
                    .foregroundColor(DS.Colors.text2)
                
                if profile.profileText.isEmpty {
                    Text("(empty)")
                        .font(DS.Typography.mono(11, weight: .regular))
                        .foregroundColor(DS.Colors.text3)
                } else {
                    Text(profile.profileText)
                        .font(DS.Typography.mono(11, weight: .regular))
                        .foregroundColor(DS.Colors.text1)
                        .textSelection(.enabled)
                }
            }
            .padding(DS.Spacing.lg)
        }
    }
    
    // MARK: - Calibration View
    
    private var calibrationView: some View {
        Group {
            if records.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(DS.Colors.text3)
                    Text("No calibration records")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text2)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                HSplitView {
                    // Left: record list
                    recordList
                        .frame(minWidth: 250, maxWidth: 350)
                    
                    // Right: detail
                    if let record = selectedRecord {
                        recordDetail(record)
                    } else {
                        VStack {
                            Spacer()
                            Text("Select a record")
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text3)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    private var recordList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(records.reversed()) { record in
                    Button(action: { selectedRecord = record }) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.scenario)
                                .font(DS.Typography.mono(11, weight: .medium))
                                .foregroundColor(selectedRecord?.id == record.id ? DS.Colors.text1 : DS.Colors.text2)
                                .lineLimit(2)
                            
                            HStack(spacing: DS.Spacing.sm) {
                                Text(formatDate(record.createdAt))
                                    .font(DS.Typography.mono(9, weight: .regular))
                                    .foregroundColor(DS.Colors.text3)
                                
                                if let level = record.consumedAtLevel {
                                    Text("consumed@Lv.\(level)")
                                        .font(DS.Typography.mono(9, weight: .regular))
                                        .foregroundColor(DS.Colors.text3)
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedRecord?.id == record.id ? DS.Colors.highlight : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(DS.Colors.bg2.opacity(0.3))
    }
    
    private func recordDetail(_ record: CalibrationRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Scenario
                Text("scenario")
                    .font(DS.Typography.mono(11, weight: .bold))
                    .foregroundColor(DS.Colors.text2)
                Text(record.scenario)
                    .font(DS.Typography.mono(11, weight: .regular))
                    .foregroundColor(DS.Colors.text1)
                    .textSelection(.enabled)
                
                Divider().background(DS.Colors.border)
                
                // Options
                Text("options")
                    .font(DS.Typography.mono(11, weight: .bold))
                    .foregroundColor(DS.Colors.text2)
                ForEach(Array(record.options.enumerated()), id: \.offset) { idx, option in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Text(idx == record.selectedOption ? "●" : "○")
                            .font(DS.Typography.mono(11, weight: .regular))
                            .foregroundColor(idx == record.selectedOption ? DS.Colors.text1 : DS.Colors.text3)
                        Text(option)
                            .font(DS.Typography.mono(11, weight: .regular))
                            .foregroundColor(idx == record.selectedOption ? DS.Colors.text1 : DS.Colors.text2)
                    }
                }
                
                // Custom answer
                if let custom = record.customAnswer, !custom.isEmpty {
                    Divider().background(DS.Colors.border)
                    Text("customAnswer")
                        .font(DS.Typography.mono(11, weight: .bold))
                        .foregroundColor(DS.Colors.text2)
                    Text(custom)
                        .font(DS.Typography.mono(11, weight: .regular))
                        .foregroundColor(DS.Colors.text1)
                        .textSelection(.enabled)
                }
                
                Divider().background(DS.Colors.border)
                
                // Ghost response
                Text("ghostResponse")
                    .font(DS.Typography.mono(11, weight: .bold))
                    .foregroundColor(DS.Colors.text2)
                Text(record.ghostResponse)
                    .font(DS.Typography.mono(11, weight: .regular))
                    .foregroundColor(DS.Colors.text1)
                    .textSelection(.enabled)
                
                // Analysis
                if let analysis = record.analysis, !analysis.isEmpty {
                    Divider().background(DS.Colors.border)
                    Text("analysis")
                        .font(DS.Typography.mono(11, weight: .bold))
                        .foregroundColor(DS.Colors.text2)
                    Text(analysis)
                        .font(DS.Typography.mono(11, weight: .regular))
                        .foregroundColor(DS.Colors.text1)
                        .textSelection(.enabled)
                }
                
                // Profile diff
                if let diff = record.profileDiff, !diff.isEmpty {
                    Divider().background(DS.Colors.border)
                    Text("profileDiff")
                        .font(DS.Typography.mono(11, weight: .bold))
                        .foregroundColor(DS.Colors.text2)
                    Text(diff)
                        .font(DS.Typography.mono(11, weight: .regular))
                        .foregroundColor(DS.Colors.text1)
                        .textSelection(.enabled)
                }
                
                Divider().background(DS.Colors.border)
                
                // Meta
                infoRow("XP Earned", "+\(record.xpEarned)")
                infoRow("Created", formatDate(record.createdAt))
                if let level = record.consumedAtLevel {
                    infoRow("Consumed At", "Lv.\(level)")
                }
            }
            .padding(DS.Spacing.lg)
        }
    }
    
    // MARK: - Helpers
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(DS.Typography.mono(11, weight: .bold))
                .foregroundColor(DS.Colors.text2)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(DS.Typography.mono(11, weight: .regular))
                .foregroundColor(DS.Colors.text1)
                .textSelection(.enabled)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt.string(from: date)
    }
    
    private func reload() {
        profile = profileStore.load()
        records = recordStore.loadAll()
    }
    
    // MARK: - Re-Profile
    
    private var profilingStatusIcon: String {
        switch profilingStatus {
        case .idle: return "brain"
        case .running: return "brain"
        case .success: return "checkmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    private var profilingStatusLabel: String {
        switch profilingStatus {
        case .idle: return "Re-Profile"
        case .running: return "Profiling..."
        case .success: return "Done"
        case .error: return "Failed"
        }
    }
    
    private var profilingStatusColor: Color {
        switch profilingStatus {
        case .idle: return DS.Colors.text2
        case .running: return DS.Colors.text2
        case .success: return .green
        case .error: return .red
        }
    }
    
    private func runProfiling() async {
        guard !isProfilingRunning else { return }
        isProfilingRunning = true
        profilingStatus = .running
        
        do {
            let level = profile.level
            
            // 选择 skill
            let skillId: String
            if level == 1 && profile.profileText.isEmpty {
                skillId = SkillModel.internalGhostInitialProfilingId
            } else {
                skillId = SkillModel.internalGhostProfilingId
            }
            
            guard let skill = SkillManager.shared.skill(byId: skillId) else {
                throw NSError(domain: "DebugDataPage", code: -1, userInfo: [NSLocalizedDescriptionKey: "构筑技能未找到"])
            }
            
            let unconsumedCorpus = corpusStore.unconsumed()
            let corpusIds = unconsumedCorpus.map { $0.id }
            let unconsumedRecords = recordStore.unconsumed()
            let recordIds = unconsumedRecords.map { $0.id }
            let previousReport = profile.profileText.isEmpty ? nil : profile.profileText
            
            let userMessage = MessageBuilder.buildProfilingUserMessage(
                profile: profile,
                previousReport: previousReport,
                corpus: unconsumedCorpus,
                records: unconsumedRecords
            )
            
            let result = try await GhostypeAPIClient.shared.executeSkill(
                systemPrompt: skill.systemPrompt,
                message: userMessage,
                context: .noInput
            )
            
            // Parse summary JSON
            if let jsonStart = result.range(of: "{\"summary\""),
               let jsonEnd = result.range(of: "}", options: .backwards, range: jsonStart.lowerBound..<result.endIndex) {
                let jsonStr = String(result[jsonStart.lowerBound...jsonEnd.lowerBound])
                if let data = jsonStr.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    struct ProfilingSummary: Decodable { let summary: String }
                    if let summary = try? decoder.decode(ProfilingSummary.self, from: data) {
                        profile.summary = summary.summary
                        profile.profileText = result
                        profile.updatedAt = Date()
                        try profileStore.save(profile)
                        
                        corpusStore.markConsumed(ids: corpusIds, atLevel: level)
                        recordStore.markConsumed(ids: recordIds, atLevel: level)
                    }
                }
            }
            
            profilingStatus = .success
            reload()
            
            // 3 秒后恢复 idle
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            profilingStatus = .idle
            
        } catch {
            profilingStatus = .error(error.localizedDescription)
            FileLogger.log("[DebugDataPage] Re-Profile failed: \(error)")
            
            // 5 秒后恢复 idle
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            profilingStatus = .idle
        }
        
        isProfilingRunning = false
    }
}
