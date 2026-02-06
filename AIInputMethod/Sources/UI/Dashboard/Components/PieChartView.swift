//
//  PieChartView.swift
//  AIInputMethod
//
//  饼图组件 - 显示应用使用分布
//  使用 Swift Charts 实现饼图，展示各应用的使用占比
//  Validates: Requirements 5.4
//

import SwiftUI
import Charts

// MARK: - PieChartView

/// 饼图视图组件
/// 用于显示应用分布的饼图
/// - Requirement 5.4: 显示 usage distribution across applications
struct PieChartView: View {
    
    // MARK: - Properties
    
    /// 应用使用数据
    var data: [AppUsage]
    
    /// 是否显示图例
    var showLegend: Bool = true
    
    /// 选中的扇区（用于交互）
    @State private var selectedItem: AppUsage?
    
    // MARK: - Constants
    
    /// 预定义的颜色数组，用于区分不同应用
    private let chartColors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .pink,
        .cyan,
        .yellow,
        .red,
        .mint,
        .indigo
    ]
    
    // MARK: - Computed Properties
    
    /// 是否有数据
    private var hasData: Bool {
        !data.isEmpty
    }
    
    /// 获取指定项的颜色
    /// - Parameters:
    ///   - item: AppUsage 项
    ///   - index: 索引位置
    /// - Returns: 对应的颜色，"其他"项使用灰色
    private func color(for item: AppUsage, at index: Int) -> Color {
        // "其他" 项使用灰色
        if item.bundleId == "com.ghostype.other" {
            return .gray
        }
        return chartColors[index % chartColors.count]
    }
    
    /// 获取指定索引的颜色（兼容旧调用）
    private func color(for index: Int) -> Color {
        chartColors[index % chartColors.count]
    }
    
    /// 格式化百分比显示
    private func formatPercentage(_ value: Double) -> String {
        let percentage = Int(value * 100)
        return "\(percentage)%"
    }
    
    // MARK: - Body
    
    var body: some View {
        if hasData {
            contentView
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Content View
    
    /// 有数据时的内容视图
    private var contentView: some View {
        VStack(spacing: 12) {
            // 饼图
            chartView
            
            // 图例
            if showLegend {
                legendView
            }
        }
    }
    
    // MARK: - Chart View
    
    /// 饼图视图
    private var chartView: some View {
        Chart(Array(data.enumerated()), id: \.element.id) { index, item in
            SectorMark(
                angle: .value("Usage", item.usageCount),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(color(for: item, at: index))
            .cornerRadius(4)
            .opacity(selectedItem == nil || selectedItem?.id == item.id ? 1.0 : 0.5)
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                let frame = geometry[chartProxy.plotFrame!]
                centerOverlay
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .chartLegend(.hidden)
        .frame(minHeight: 120)
    }
    
    // MARK: - Center Overlay
    
    /// 饼图中心的覆盖视图
    private var centerOverlay: some View {
        VStack(spacing: 2) {
            if let selected = selectedItem {
                // 显示选中项的详情
                Text(selected.appName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(formatPercentage(selected.percentage))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.accentColor)
            } else {
                // 显示总数
                Text("\(data.count)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("应用")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Legend View
    
    /// 图例视图
    /// 由于数据已经在 StatsCalculator 中分组为 Top 5 + "其他"，直接显示所有项
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                legendItem(item: item, color: color(for: item, at: index))
            }
        }
        .padding(.horizontal, 4)
    }
    
    /// 单个图例项
    private func legendItem(item: AppUsage, color: Color) -> some View {
        HStack(spacing: 6) {
            // 颜色指示器
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            // 应用名称
            Text(item.appName)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // 百分比
            Text(formatPercentage(item.percentage))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedItem?.id == item.id {
                    selectedItem = nil
                } else {
                    selectedItem = item
                }
            }
        }
    }
    
    // MARK: - Empty State View
    
    /// 空数据状态视图
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无数据")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("开始使用语音输入后\n这里将显示应用分布")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct PieChartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 正常数据预览
            PieChartView(data: sampleData)
                .frame(width: 200, height: 250)
                .padding()
                .previewDisplayName("Normal Data")
            
            // 在 BentoCard 中使用
            BentoCard(title: "应用分布", icon: "chart.pie.fill") {
                PieChartView(data: sampleData)
            }
            .frame(width: 220, height: 280)
            .padding()
            .previewDisplayName("In BentoCard")
            
            // 空数据预览
            PieChartView(data: [])
                .frame(width: 200, height: 200)
                .padding()
                .previewDisplayName("Empty State")
            
            // 单个应用
            PieChartView(data: [
                AppUsage(bundleId: "com.apple.Notes", appName: "备忘录", usageCount: 10, percentage: 1.0)
            ])
            .frame(width: 200, height: 200)
            .padding()
            .previewDisplayName("Single App")
            
            // 深色模式
            PieChartView(data: sampleData)
                .frame(width: 200, height: 250)
                .padding()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // 不显示图例
            PieChartView(data: sampleData, showLegend: false)
                .frame(width: 150, height: 150)
                .padding()
                .previewDisplayName("No Legend")
            
            // 多个应用（超过5个）
            PieChartView(data: manyAppsData)
                .frame(width: 220, height: 300)
                .padding()
                .previewDisplayName("Many Apps")
        }
    }
    
    /// 示例数据
    static var sampleData: [AppUsage] {
        [
            AppUsage(bundleId: "com.apple.Notes", appName: "备忘录", usageCount: 45, percentage: 0.45),
            AppUsage(bundleId: "com.apple.Safari", appName: "Safari", usageCount: 25, percentage: 0.25),
            AppUsage(bundleId: "com.microsoft.Word", appName: "Word", usageCount: 20, percentage: 0.20),
            AppUsage(bundleId: "com.apple.mail", appName: "邮件", usageCount: 10, percentage: 0.10)
        ]
    }
    
    /// 多应用示例数据
    static var manyAppsData: [AppUsage] {
        [
            AppUsage(bundleId: "com.apple.Notes", appName: "备忘录", usageCount: 30, percentage: 0.30),
            AppUsage(bundleId: "com.apple.Safari", appName: "Safari", usageCount: 20, percentage: 0.20),
            AppUsage(bundleId: "com.microsoft.Word", appName: "Word", usageCount: 15, percentage: 0.15),
            AppUsage(bundleId: "com.apple.mail", appName: "邮件", usageCount: 12, percentage: 0.12),
            AppUsage(bundleId: "com.slack.Slack", appName: "Slack", usageCount: 10, percentage: 0.10),
            AppUsage(bundleId: "com.apple.finder", appName: "访达", usageCount: 8, percentage: 0.08),
            AppUsage(bundleId: "com.apple.Terminal", appName: "终端", usageCount: 5, percentage: 0.05)
        ]
    }
}
#endif
