//
//  OverviewPage.swift
//  AIInputMethod
//
//  概览页 - Radical Minimalist 极简风格
//  Bento Grid 布局，1px 边框卡片，无阴影
//

import SwiftUI

// MARK: - OverviewPage

struct OverviewPage: View {
    
    // MARK: - Properties
    
    var todayStats: TodayStats
    var quotaInfo: QuotaInfo
    var appDistribution: [AppUsage]
    var recentNotes: [UsageRecord]
    
    private let cardSpacing: CGFloat = 24
    private let contentPadding: CGFloat = 24
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: cardSpacing) {
                // 页面标题
                headerView
                
                // Bento Grid
                bentoGridView
            }
            .padding(.top, 21)
            .padding(.horizontal, contentPadding)
            .padding(.bottom, contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("概览")
                .font(DS.Typography.largeTitle)
                .foregroundColor(DS.Colors.text1)
            
            Text("查看您的语音输入统计数据")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
        }
        .padding(.bottom, 0)
    }
    
    // MARK: - Bento Grid View
    
    private var bentoGridView: some View {
        VStack(spacing: cardSpacing) {
            // 第一行：今日战报 + 能量环（较小）
            HStack(spacing: cardSpacing) {
                todayStatsCard
                energyRingCard
            }
            
            // 第二行：应用分布 + 最近笔记（较大）
            HStack(spacing: cardSpacing) {
                appDistributionCard
                recentNotesCard
            }
        }
    }
    
    // MARK: - Bento Card Heights
    
    private let smallCardHeight: CGFloat = 200
    private let largeCardHeight: CGFloat = 320
    
    // MARK: - Today Stats Card
    
    private var todayStatsCard: some View {
        MinimalBentoCard(title: "输入字数统计", icon: "character.cursor.ibeam") {
            VStack(alignment: .leading, spacing: 12) {
                // 今日字数 - 大字号
                HStack(alignment: .lastTextBaseline) {
                    Text("今日")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    Spacer()
                    Text("\(todayStats.characterCount)")
                        .font(DS.Typography.ui(32, weight: .medium))
                        .foregroundColor(DS.Colors.text1)
                    Text("字")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                MinimalDivider()
                
                // 累积字数
                HStack {
                    Text("累积")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    Spacer()
                    Text("\(todayStats.totalCharacterCount) 字")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                }
                
                MinimalDivider()
                
                // 节省时间
                HStack {
                    Text("节省时间")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    Spacer()
                    Text(StatsCalculator.formatTimeSaved(todayStats.estimatedTimeSaved))
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: smallCardHeight)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Energy Ring Card
    
    private var energyRingCard: some View {
        MinimalBentoCard(title: "本月能量环", icon: "circle.circle") {
            VStack(spacing: DS.Spacing.sm) {
                EnergyRingView(usedPercentage: quotaInfo.usedPercentage)
                    .frame(width: 70, height: 70)
                
                HStack(spacing: DS.Spacing.xl) {
                    quotaDetailItem(label: "已用", value: quotaInfo.formattedUsedTime)
                    quotaDetailItem(label: "剩余", value: quotaInfo.formattedRemainingTime)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: smallCardHeight)
        .frame(maxWidth: .infinity)
    }
    
    private func quotaDetailItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
            
            Text(value)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
        }
    }
    
    // MARK: - App Distribution Card
    
    private var appDistributionCard: some View {
        MinimalBentoCard(title: "应用分布", icon: "chart.pie") {
            PieChartView(data: appDistribution, showLegend: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: largeCardHeight)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Recent Notes Card
    
    private var recentNotesCard: some View {
        MinimalBentoCard(title: "最近笔记", icon: "note.text") {
            if recentNotes.isEmpty {
                emptyNotesView
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(recentNotes.prefix(3), id: \.id) { note in
                        noteItemView(note: note)
                        
                        if note.id != recentNotes.prefix(3).last?.id {
                            MinimalDivider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: largeCardHeight)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyNotesView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "note.text")
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.text3)
            
            Text("暂无笔记")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func noteItemView(note: UsageRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(note.content)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
                .lineLimit(2)
            
            Text(formatTimestamp(note.timestamp))
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - MinimalBentoCard

struct MinimalBentoCard<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.icon)
                
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
            }
            
            // Content
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(DS.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
    }
}

// MARK: - QuotaInfo

struct QuotaInfo {
    var usedPercentage: Double
    var formattedUsedTime: String
    var formattedRemainingTime: String
    
    static func from(_ manager: QuotaManager) -> QuotaInfo {
        return QuotaInfo(
            usedPercentage: manager.usedPercentage,
            formattedUsedTime: manager.formattedUsed,
            formattedRemainingTime: manager.formattedResetTime
        )
    }
    
    static let empty = QuotaInfo(
        usedPercentage: 0.0,
        formattedUsedTime: "0 / 6000 \(L.Quota.characters)",
        formattedRemainingTime: ""
    )
}

// MARK: - OverviewPageWithData

struct OverviewPageWithData: View {
    
    @State private var todayStats: TodayStats = .empty
    @State private var appDistribution: [AppUsage] = []
    @State private var recentNotes: [UsageRecord] = []
    
    private let statsCalculator: StatsCalculator
    private var quotaManager = QuotaManager.shared
    
    init(
        statsCalculator: StatsCalculator = StatsCalculator()
    ) {
        self.statsCalculator = statsCalculator
    }
    
    var body: some View {
        // 直接在 body 中访问 @Observable 属性，确保 SwiftUI 追踪变化
        let quotaInfo = QuotaInfo(
            usedPercentage: quotaManager.usedPercentage,
            formattedUsedTime: quotaManager.formattedUsed,
            formattedRemainingTime: quotaManager.formattedResetTime
        )
        
        OverviewPage(
            todayStats: todayStats,
            quotaInfo: quotaInfo,
            appDistribution: appDistribution,
            recentNotes: recentNotes
        )
        .onAppear {
            loadData()
            // 刷新服务器额度数据
            Task { await QuotaManager.shared.refresh() }
        }
    }
    
    private func loadData() {
        todayStats = statsCalculator.calculateTodayStats()
        appDistribution = statsCalculator.calculateAppDistribution()
        recentNotes = statsCalculator.fetchRecentNotes()
    }
}

// MARK: - Preview

#if DEBUG
struct OverviewPage_Previews: PreviewProvider {
    static var previews: some View {
        OverviewPage(
            todayStats: TodayStats(characterCount: 1234, totalCharacterCount: 12345, estimatedTimeSaved: 617),
            quotaInfo: QuotaInfo(usedPercentage: 0.35, formattedUsedTime: "2100 / 6000 characters", formattedRemainingTime: "Resets in 5 days"),
            appDistribution: [],
            recentNotes: []
        )
        .frame(width: 700, height: 800)
    }
}
#endif
