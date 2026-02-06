//
//  OverviewPage.swift
//  AIInputMethod
//
//  概览页 - Dashboard 主页面
//  实现 Bento Grid 布局展示今日战报、能量环、应用分布、最近笔记
//  Validates: Requirements 5.1
//

import SwiftUI

// MARK: - OverviewPage

/// 概览页视图
/// 使用 Bento Grid 布局展示四个数据卡片：
/// - 今日战报：今日输入字数和节省时间
/// - 本月能量环：额度使用情况
/// - 应用分布：各应用使用占比饼图
/// - 最近笔记：最近的语音备忘录
/// Requirement 5.1: THE Overview page SHALL display Bento_Cards in a responsive grid layout
struct OverviewPage: View {
    
    // MARK: - Properties
    
    /// 今日统计数据
    var todayStats: TodayStats
    
    /// 额度信息
    var quotaInfo: QuotaInfo
    
    /// 应用分布数据
    var appDistribution: [AppUsage]
    
    /// 最近笔记记录
    var recentNotes: [UsageRecord]
    
    // MARK: - Constants
    
    /// 卡片间距
    private let cardSpacing: CGFloat = 16
    
    /// 内边距
    private let contentPadding: CGFloat = 24
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: cardSpacing) {
                // 页面标题
                headerView
                    .padding(.bottom, 8)
                
                // Bento Grid 布局
                bentoGridView
            }
            .padding(contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - Header View
    
    /// 页面标题视图
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("概览")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("查看您的语音输入统计数据")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 刷新按钮（预留）
            Button(action: {
                // TODO: 刷新数据
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("刷新数据")
        }
    }
    
    // MARK: - Bento Grid View
    
    /// Bento Grid 布局视图
    /// 使用 LazyVGrid 实现响应式网格布局
    private var bentoGridView: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: cardSpacing),
                GridItem(.flexible(), spacing: cardSpacing)
            ],
            spacing: cardSpacing
        ) {
            // 今日战报卡片
            todayStatsCard
            
            // 本月能量环卡片
            energyRingCard
            
            // 应用分布卡片
            appDistributionCard
            
            // 最近笔记卡片
            recentNotesCard
        }
    }
    
    // MARK: - Today Stats Card
    
    /// 今日战报卡片
    /// Requirement 5.2: THE "今日战报" Bento_Card SHALL display today's input character count and estimated time saved
    private var todayStatsCard: some View {
        BentoCard(title: "今日战报", icon: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // 字符数统计
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(todayStats.characterCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("字符输入")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 节省时间统计
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("节省时间")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(StatsCalculator.formatTimeSaved(todayStats.estimatedTimeSaved))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 180)
    }
    
    // MARK: - Energy Ring Card
    
    /// 本月能量环卡片
    /// Requirement 5.3: THE "本月能量环" Bento_Card SHALL display an Energy_Ring showing used/remaining quota percentage
    private var energyRingCard: some View {
        BentoCard(title: "本月能量环", icon: "circle.circle.fill") {
            VStack(spacing: 12) {
                // 能量环
                EnergyRingView(usedPercentage: quotaInfo.usedPercentage)
                    .frame(width: 100, height: 100)
                
                // 额度详情
                HStack(spacing: 16) {
                    quotaDetailItem(
                        label: "已用",
                        value: quotaInfo.formattedUsedTime,
                        color: .orange
                    )
                    
                    quotaDetailItem(
                        label: "剩余",
                        value: quotaInfo.formattedRemainingTime,
                        color: .green
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 180)
    }
    
    /// 额度详情项
    private func quotaDetailItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
        }
    }
    
    // MARK: - App Distribution Card
    
    /// 应用分布卡片
    /// Requirement 5.4: THE "应用分布" Bento_Card SHALL display a pie chart showing usage distribution across applications
    private var appDistributionCard: some View {
        BentoCard(title: "应用分布", icon: "chart.pie.fill") {
            PieChartView(data: appDistribution, showLegend: true)
                .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 250)
    }
    
    // MARK: - Recent Notes Card
    
    /// 最近笔记卡片
    /// Requirement 5.5: THE "最近笔记" Bento_Card SHALL display the 3 most recent voice memo entries with preview text
    private var recentNotesCard: some View {
        BentoCard(title: "最近笔记", icon: "note.text") {
            if recentNotes.isEmpty {
                emptyNotesView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recentNotes, id: \.id) { note in
                        noteItemView(note: note)
                        
                        if note.id != recentNotes.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(minHeight: 250)
    }
    
    /// 空笔记状态视图
    private var emptyNotesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无笔记")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("使用随心记功能后\n笔记将显示在这里")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// 笔记项视图
    private func noteItemView(note: UsageRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 内容预览（最多2行）
            Text(note.content)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
            
            // 时间戳
            Text(formatTimestamp(note.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// 格式化时间戳
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - QuotaInfo

/// 额度信息结构体
/// 用于传递给 OverviewPage 的额度数据
struct QuotaInfo {
    /// 已使用百分比 (0.0 - 1.0)
    var usedPercentage: Double
    
    /// 格式化的已使用时间
    var formattedUsedTime: String
    
    /// 格式化的剩余时间
    var formattedRemainingTime: String
    
    /// 从 QuotaManager 创建 QuotaInfo
    static func from(_ manager: QuotaManager) -> QuotaInfo {
        return QuotaInfo(
            usedPercentage: manager.usedPercentage,
            formattedUsedTime: manager.formattedUsedTime,
            formattedRemainingTime: manager.formattedRemainingTime
        )
    }
    
    /// 空额度信息
    static let empty = QuotaInfo(
        usedPercentage: 0.0,
        formattedUsedTime: "0秒",
        formattedRemainingTime: "1小时"
    )
}

// MARK: - OverviewPage with Data Loading

/// 带数据加载的概览页视图
/// 自动从 StatsCalculator 和 QuotaManager 加载数据
struct OverviewPageWithData: View {
    
    // MARK: - State
    
    @State private var todayStats: TodayStats = .empty
    @State private var quotaInfo: QuotaInfo = .empty
    @State private var appDistribution: [AppUsage] = []
    @State private var recentNotes: [UsageRecord] = []
    
    // MARK: - Dependencies
    
    private let statsCalculator: StatsCalculator
    private let quotaManager: QuotaManager
    
    // MARK: - Initialization
    
    init(
        statsCalculator: StatsCalculator = StatsCalculator(),
        quotaManager: QuotaManager = QuotaManager.forTesting()
    ) {
        self.statsCalculator = statsCalculator
        self.quotaManager = quotaManager
    }
    
    // MARK: - Body
    
    var body: some View {
        OverviewPage(
            todayStats: todayStats,
            quotaInfo: quotaInfo,
            appDistribution: appDistribution,
            recentNotes: recentNotes
        )
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Data Loading
    
    /// 加载所有数据
    private func loadData() {
        // 加载今日统计
        todayStats = statsCalculator.calculateTodayStats()
        
        // 加载额度信息
        quotaInfo = QuotaInfo.from(quotaManager)
        
        // 加载应用分布
        appDistribution = statsCalculator.calculateAppDistribution()
        
        // 加载最近笔记
        recentNotes = statsCalculator.fetchRecentNotes()
    }
}

// MARK: - Preview

#if DEBUG
struct OverviewPage_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 有数据的预览
            OverviewPage(
                todayStats: sampleTodayStats,
                quotaInfo: sampleQuotaInfo,
                appDistribution: sampleAppDistribution,
                recentNotes: sampleRecentNotes
            )
            .frame(width: 700, height: 800)
            .previewDisplayName("With Data")
            
            // 空数据的预览
            OverviewPage(
                todayStats: .empty,
                quotaInfo: .empty,
                appDistribution: [],
                recentNotes: []
            )
            .frame(width: 700, height: 800)
            .previewDisplayName("Empty State")
            
            // 深色模式预览
            OverviewPage(
                todayStats: sampleTodayStats,
                quotaInfo: sampleQuotaInfo,
                appDistribution: sampleAppDistribution,
                recentNotes: sampleRecentNotes
            )
            .frame(width: 700, height: 800)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
    
    // MARK: - Sample Data
    
    static var sampleTodayStats: TodayStats {
        TodayStats(characterCount: 1234, estimatedTimeSaved: 617)
    }
    
    static var sampleQuotaInfo: QuotaInfo {
        QuotaInfo(
            usedPercentage: 0.35,
            formattedUsedTime: "21分钟",
            formattedRemainingTime: "39分钟"
        )
    }
    
    static var sampleAppDistribution: [AppUsage] {
        [
            AppUsage(bundleId: "com.apple.Notes", appName: "备忘录", usageCount: 45, percentage: 0.45),
            AppUsage(bundleId: "com.apple.Safari", appName: "Safari", usageCount: 25, percentage: 0.25),
            AppUsage(bundleId: "com.microsoft.Word", appName: "Word", usageCount: 20, percentage: 0.20),
            AppUsage(bundleId: "com.apple.mail", appName: "邮件", usageCount: 10, percentage: 0.10)
        ]
    }
    
    static var sampleRecentNotes: [UsageRecord] {
        // 创建模拟的 UsageRecord 数据
        // 注意：这里需要使用 CoreData 的 mock context
        // 在实际预览中可能需要调整
        []
    }
}
#endif
