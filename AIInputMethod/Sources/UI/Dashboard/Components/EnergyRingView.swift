//
//  EnergyRingView.swift
//  AIInputMethod
//
//  能量环组件 - Radical Minimalist 极简风格
//  使用 muted colors 作为状态指示
//

import SwiftUI

// MARK: - EnergyRingView

struct EnergyRingView: View {
    
    var usedPercentage: Double
    var warningThreshold: Double = 0.8
    var criticalThreshold: Double = 0.95
    var lineWidth: CGFloat = 10
    var showPercentageText: Bool = true
    
    private var safePercentage: Double {
        min(max(usedPercentage, 0.0), 1.0)
    }
    
    private var remainingPercentage: Double {
        1.0 - safePercentage
    }
    
    private var percentageText: String {
        "\(Int(safePercentage * 100))%"
    }
    
    private var isWarning: Bool {
        safePercentage > warningThreshold && safePercentage <= criticalThreshold
    }
    
    private var isCritical: Bool {
        safePercentage > criticalThreshold
    }
    
    /// 进度环颜色 - 使用 muted colors
    private var progressColor: Color {
        if isCritical {
            return DS.Colors.statusError
        } else if isWarning {
            return DS.Colors.statusWarning
        } else {
            return DS.Colors.text1
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // 背景轨道
                Circle()
                    .stroke(DS.Colors.border, lineWidth: lineWidth)
                
                // 进度环
                Circle()
                    .trim(from: 0, to: safePercentage)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: safePercentage)
                
                // 中心文字
                if showPercentageText {
                    centerTextView
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    private var centerTextView: some View {
        VStack(spacing: 2) {
            Text(percentageText)
                .font(DS.Typography.ui(20, weight: .medium))
                .foregroundColor(DS.Colors.text1)
            
            Text("已用")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
        }
    }
}

extension EnergyRingView {
    init(usedSeconds: Int, totalSeconds: Int) {
        let percentage = totalSeconds > 0 ? Double(usedSeconds) / Double(totalSeconds) : 0.0
        self.init(usedPercentage: percentage)
    }
}

// MARK: - Preview

#if DEBUG
struct EnergyRingView_Previews: PreviewProvider {
    static var previews: some View {
        EnergyRingView(usedPercentage: 0.5)
            .frame(width: 100, height: 100)
            .padding()
    }
}
#endif
