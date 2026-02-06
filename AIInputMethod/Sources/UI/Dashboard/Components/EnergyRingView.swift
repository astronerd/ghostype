//
//  EnergyRingView.swift
//  AIInputMethod
//
//  能量环组件 - 显示额度使用百分比
//  实现圆环进度显示，颜色根据百分比变化 (>90% 警告色)
//  Validates: Requirements 5.3
//

import SwiftUI

// MARK: - EnergyRingView

/// 能量环视图组件
/// 用于显示本月额度使用情况的圆环进度图
/// - Requirement 5.3: 显示 used/remaining quota percentage
struct EnergyRingView: View {
    
    // MARK: - Properties
    
    /// 已使用百分比 (0.0 - 1.0)
    var usedPercentage: Double
    
    /// 警告阈值，超过此值显示警告色 (默认 0.9 即 90%)
    var warningThreshold: Double = 0.9
    
    /// 圆环线宽
    var lineWidth: CGFloat = 12
    
    /// 是否显示百分比文字
    var showPercentageText: Bool = true
    
    // MARK: - Constants
    
    /// 动画时长
    private let animationDuration: Double = 0.8
    
    // MARK: - Computed Properties
    
    /// 安全的百分比值 (确保在 0.0 - 1.0 范围内)
    private var safePercentage: Double {
        min(max(usedPercentage, 0.0), 1.0)
    }
    
    /// 剩余百分比
    private var remainingPercentage: Double {
        1.0 - safePercentage
    }
    
    /// 百分比显示文字
    private var percentageText: String {
        let percentage = Int(safePercentage * 100)
        return "\(percentage)%"
    }
    
    /// 剩余额度描述文字
    private var remainingText: String {
        let remaining = Int(remainingPercentage * 100)
        return "剩余 \(remaining)%"
    }
    
    /// 是否处于警告状态 (>90% 使用)
    private var isWarning: Bool {
        safePercentage > warningThreshold
    }
    
    /// 进度环颜色
    /// - 正常状态: 蓝色渐变
    /// - 警告状态 (>90%): 橙红色渐变
    private var progressColor: LinearGradient {
        if isWarning {
            // 警告色: 橙色到红色渐变
            return LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // 正常色: 蓝色到青色渐变
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    /// 背景环颜色
    private var trackColor: Color {
        Color.gray.opacity(0.2)
    }
    
    /// 文字颜色
    private var textColor: Color {
        isWarning ? .orange : .primary
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // MARK: 背景轨道环
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)
                
                // MARK: 进度环
                Circle()
                    .trim(from: 0, to: safePercentage)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    // 从顶部开始 (12点钟方向)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: animationDuration), value: safePercentage)
                
                // MARK: 中心文字
                if showPercentageText {
                    centerTextView
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    // MARK: - Center Text View
    
    /// 中心文字视图
    private var centerTextView: some View {
        VStack(spacing: 2) {
            // 已使用百分比
            Text(percentageText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
            
            // 剩余额度描述
            Text(remainingText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            
            // 警告提示
            if isWarning {
                Text("额度即将耗尽")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension EnergyRingView {
    
    /// 使用已用秒数和总秒数初始化
    /// - Parameters:
    ///   - usedSeconds: 已使用秒数
    ///   - totalSeconds: 总额度秒数
    init(usedSeconds: Int, totalSeconds: Int) {
        let percentage = totalSeconds > 0 ? Double(usedSeconds) / Double(totalSeconds) : 0.0
        self.init(usedPercentage: percentage)
    }
}

// MARK: - Preview

#if DEBUG
struct EnergyRingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 正常状态 - 50%
            EnergyRingView(usedPercentage: 0.5)
                .frame(width: 120, height: 120)
                .padding()
                .previewDisplayName("50% Used")
            
            // 正常状态 - 75%
            EnergyRingView(usedPercentage: 0.75)
                .frame(width: 120, height: 120)
                .padding()
                .previewDisplayName("75% Used")
            
            // 警告状态 - 92%
            EnergyRingView(usedPercentage: 0.92)
                .frame(width: 120, height: 120)
                .padding()
                .previewDisplayName("92% Used (Warning)")
            
            // 满额状态 - 100%
            EnergyRingView(usedPercentage: 1.0)
                .frame(width: 120, height: 120)
                .padding()
                .previewDisplayName("100% Used")
            
            // 空状态 - 0%
            EnergyRingView(usedPercentage: 0.0)
                .frame(width: 120, height: 120)
                .padding()
                .previewDisplayName("0% Used")
            
            // 在 BentoCard 中使用
            BentoCard(title: "本月能量环", icon: "circle.circle.fill") {
                EnergyRingView(usedPercentage: 0.65)
                    .frame(width: 100, height: 100)
            }
            .frame(width: 180, height: 180)
            .padding()
            .previewDisplayName("In BentoCard")
            
            // 深色模式
            EnergyRingView(usedPercentage: 0.85)
                .frame(width: 120, height: 120)
                .padding()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // 自定义线宽
            EnergyRingView(usedPercentage: 0.6, lineWidth: 8)
                .frame(width: 80, height: 80)
                .padding()
                .previewDisplayName("Thin Ring")
        }
    }
}
#endif
