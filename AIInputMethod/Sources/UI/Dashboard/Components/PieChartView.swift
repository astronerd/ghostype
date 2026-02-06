//
//  PieChartView.swift
//  AIInputMethod
//
//  饼图组件 - Radical Minimalist 极简风格
//  使用灰度色系
//

import SwiftUI
import Charts

// MARK: - PieChartView

struct PieChartView: View {
    
    var data: [AppUsage]
    var showLegend: Bool = true
    
    @State private var selectedItem: AppUsage?
    
    /// 灰度色系
    private let chartColors: [Color] = [
        Color(hex: "26251E"),
        Color(hex: "5D626A"),
        Color(hex: "898883"),
        Color(hex: "B8BCBF"),
        Color(hex: "CECDC9"),
        Color(hex: "E3E4E0"),
    ]
    
    private var hasData: Bool { !data.isEmpty }
    
    private func color(for item: AppUsage, at index: Int) -> Color {
        if item.bundleId == "com.ghostype.other" {
            return DS.Colors.border
        }
        return chartColors[index % chartColors.count]
    }
    
    private func formatPercentage(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }
    
    var body: some View {
        if hasData {
            contentView
        } else {
            emptyStateView
        }
    }
    
    private var contentView: some View {
        VStack(spacing: DS.Spacing.md) {
            chartView
            if showLegend { legendView }
        }
    }

    private var chartView: some View {
        Chart(Array(data.enumerated()), id: \.element.id) { index, item in
            SectorMark(
                angle: .value("Usage", item.usageCount),
                innerRadius: .ratio(0.5),
                angularInset: 1
            )
            .foregroundStyle(color(for: item, at: index))
            .cornerRadius(2)
            .opacity(selectedItem == nil || selectedItem?.id == item.id ? 1.0 : 0.5)
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let frame = chartProxy.plotFrame {
                    let rect = geometry[frame]
                    centerOverlay
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .chartLegend(.hidden)
        .frame(minHeight: 100)
    }
    
    private var centerOverlay: some View {
        VStack(spacing: 2) {
            if let selected = selectedItem {
                Text(selected.appName)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text1)
                    .lineLimit(1)
                
                Text(formatPercentage(selected.percentage))
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
            } else {
                Text("\(data.count)")
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text1)
                
                Text("应用")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
            }
        }
    }
    
    private var legendView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                legendItem(item: item, color: color(for: item, at: index))
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
    }
    
    private func legendItem(item: AppUsage, color: Color) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(item.appName)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text1)
                .lineLimit(1)
            
            Spacer()
            
            Text(formatPercentage(item.percentage))
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedItem = selectedItem?.id == item.id ? nil : item
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.pie")
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.text3)
            
            Text("暂无数据")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct PieChartView_Previews: PreviewProvider {
    static var previews: some View {
        PieChartView(data: [
            AppUsage(bundleId: "com.apple.Notes", appName: "备忘录", usageCount: 45, percentage: 0.45),
            AppUsage(bundleId: "com.apple.Safari", appName: "Safari", usageCount: 25, percentage: 0.25),
            AppUsage(bundleId: "com.microsoft.Word", appName: "Word", usageCount: 20, percentage: 0.20),
        ])
        .frame(width: 200, height: 250)
        .padding()
    }
}
#endif
