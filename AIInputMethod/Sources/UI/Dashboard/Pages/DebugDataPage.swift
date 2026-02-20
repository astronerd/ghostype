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
    
    private let profileStore = GhostTwinProfileStore()
    private let recordStore = CalibrationRecordStore()
    
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
}
