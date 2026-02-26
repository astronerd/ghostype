//
//  DotMatrixView.swift
//  AIInputMethod
//
//  点阵屏 Canvas 渲染视图
//  双层 Canvas：底层模糊光晕 + 上层锐利像素
//  背景像素：80×60 网格，8×8px，真随机参数表驱动闪烁
//  Ghost 像素：160×120 网格，4×4px，呼吸特效
//  Ghost 黑边：ghostZone 区域不画背景像素
//  640×480px，scaleEffect(0.5) → 320×240
//
//  入场动画：ease-out（前快后慢），每次升级重新随机
//  像素闪烁：预生成随机参数表，每像素独立明暗 + 偶尔熄灭
//

import SwiftUI

/// 每个背景像素的随机参数
private struct PixelParams {
    let bootOrder: Double   // 入场顺序 (0~1)
    let phase1: Double      // sin 波 1 相位
    let phase2: Double      // sin 波 2 相位
    let phase3: Double      // sin 波 3 相位
    let freq1: Double       // sin 波 1 周期 (秒)
    let freq2: Double       // sin 波 2 周期 (秒)
    let freq3: Double       // sin 波 3 周期 (秒)
    let flickerOffset: Double // 熄灭判定偏移
}

struct DotMatrixView: View {
    
    let activePixels: Set<Int>
    let ghostMask: [Bool]
    let ghostZone: [Bool]
    let ghostOpacity: Double
    let level: Int
    
    // MARK: - Animation State
    
    @State private var bootProgress: Double = 0.0
    @State private var bootComplete: Bool = false
    @State private var bootTimer: Timer?
    @State private var lastActiveCount: Int = 0
    
    /// 预生成的随机参数表（80×60 = 4800 个像素）
    @State private var pixelParams: [PixelParams] = []
    
    // MARK: - Constants
    
    private static let bgPixelSize: CGFloat = 8
    private static let ghostPixelSize: CGFloat = 4
    private static let bgGap: CGFloat = 1.0
    private static let ghostGap: CGFloat = 0.5
    private static let bgCornerRadius: CGFloat = 1.5
    private static let ghostCornerRadius: CGFloat = 0.75
    private static let bgCols = 80
    private static let bgRows = 60
    private static let bgTotal = 80 * 60
    private static let ghostCols = 160
    private static let ghostRows = 120
    private static let breathingAmplitude: Double = 0.08
    private static let breathingPeriod: Double = 3.0
    
    private static let bootInterval: TimeInterval = 0.03
    private static let bootStep: Double = 0.008
    
    // MARK: - Body
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let breathingWave = sin(now / Self.breathingPeriod * .pi * 2) * Self.breathingAmplitude
            let effectiveGhostOp = min(max(ghostOpacity + breathingWave, 0.05), 1.0)
            let rawProgress = bootComplete ? 1.0 : bootProgress
            let easedProgress = 1.0 - (1.0 - rawProgress) * (1.0 - rawProgress)
            
            ZStack {
                Canvas { context, size in
                    drawBackgroundPixels(context: context, progress: easedProgress, time: now)
                    drawGhostPixels(context: context, opacity: effectiveGhostOp)
                }
                .blur(radius: 1.5)
                .blendMode(.screen)
                
                Canvas { context, size in
                    drawBackgroundPixels(context: context, progress: easedProgress, time: now)
                    drawGhostPixels(context: context, opacity: effectiveGhostOp)
                }
            }
        }
        .frame(width: 640, height: 480)
        .drawingGroup()
        .onAppear {
            regenerateParams()
            startBootSequence()
        }
        .onDisappear {
            bootTimer?.invalidate()
            bootTimer = nil
        }
        .onChange(of: activePixels.count) { oldVal, newVal in
            if newVal > lastActiveCount && bootComplete {
                bootComplete = false
                let ratio = lastActiveCount > 0 ? Double(lastActiveCount) / Double(newVal) : 0
                bootProgress = ratio
                regenerateParams()
                startBootSequence()
            }
            lastActiveCount = newVal
        }
    }
    
    // MARK: - Random Params Generation
    
    /// 生成全新的随机参数表，每次调用结果不同
    private func regenerateParams() {
        var params = [PixelParams]()
        params.reserveCapacity(Self.bgTotal)
        for _ in 0..<Self.bgTotal {
            params.append(PixelParams(
                bootOrder: Double.random(in: 0..<1),
                phase1: Double.random(in: 0..<(.pi * 2)),
                phase2: Double.random(in: 0..<(.pi * 2)),
                phase3: Double.random(in: 0..<(.pi * 2)),
                freq1: Double.random(in: 1.5...3.5),
                freq2: Double.random(in: 3.0...7.0),
                freq3: Double.random(in: 0.7...1.7),
                flickerOffset: Double.random(in: 0..<1000)
            ))
        }
        pixelParams = params
    }
    
    // MARK: - Boot Sequence
    
    private func startBootSequence() {
        bootTimer?.invalidate()
        
        if activePixels.isEmpty {
            bootComplete = true
            return
        }
        
        bootTimer = Timer.scheduledTimer(withTimeInterval: Self.bootInterval, repeats: true) { timer in
            Task { @MainActor in
                bootProgress = min(bootProgress + Self.bootStep, 1.0)
                if bootProgress >= 1.0 {
                    bootComplete = true
                    timer.invalidate()
                    bootTimer = nil
                }
            }
        }
    }
    
    // MARK: - Background Pixels (80×60, 8×8px each)
    
    private func drawBackgroundPixels(context: GraphicsContext, progress: Double, time: Double) {
        let ps = Self.bgPixelSize
        let gap = Self.bgGap
        let cr = Self.bgCornerRadius
        let params = pixelParams
        guard params.count == Self.bgTotal else { return }
        
        for row in 0..<Self.bgRows {
            for col in 0..<Self.bgCols {
                // ghostZone 检查
                let baseRow = row * 2
                let baseCol = col * 2
                var inZone = false
                for dr in 0..<2 {
                    for dc in 0..<2 {
                        let idx = (baseRow + dr) * Self.ghostCols + (baseCol + dc)
                        if idx < ghostZone.count, ghostZone[idx] {
                            inZone = true
                        }
                    }
                }
                if inZone { continue }
                
                let x = CGFloat(col) * ps
                let y = CGFloat(row) * ps
                let rect = CGRect(
                    x: x + gap / 2,
                    y: y + gap / 2,
                    width: ps - gap,
                    height: ps - gap
                )
                let path = Path(roundedRect: rect, cornerRadius: cr)
                
                // 检查是否有激活像素
                var isActive = false
                for dr in 0..<2 {
                    for dc in 0..<2 {
                        let idx = (baseRow + dr) * Self.ghostCols + (baseCol + dc)
                        if activePixels.contains(idx) {
                            isActive = true
                        }
                    }
                }
                
                let bgIndex = row * Self.bgCols + col
                let p = params[bgIndex]
                
                // 入场动画：用预生成的随机 bootOrder
                if isActive && !bootComplete {
                    if p.bootOrder >= progress { isActive = false }
                }
                
                let color: Color
                if isActive {
                    // 三个不同频率 sin 波叠加，用预生成的随机相位和频率
                    let wave1 = sin(time / p.freq1 * .pi * 2 + p.phase1) * 0.12
                    let wave2 = sin(time / p.freq2 * .pi * 2 + p.phase2) * 0.08
                    let wave3 = sin(time / p.freq3 * .pi * 2 + p.phase3) * 0.05
                    
                    var opacity = 0.65 + wave1 + wave2 + wave3
                    
                    // 偶尔熄灭：用 time + 随机偏移，每个像素在不同时刻熄灭
                    let flickTime = time + p.flickerOffset
                    let flickSlot = Int(flickTime * 3.0) // 每 0.33s 一个 slot
                    // 用简单的整数运算判断：slot 能被 50 整除时熄灭（约 2% 概率）
                    if flickSlot % 50 == 0 {
                        opacity = 0.05
                    }
                    
                    opacity = min(max(opacity, 0.35), 0.95)
                    color = Color.green.opacity(opacity)
                } else {
                    color = Color.gray.opacity(0.04)
                }
                
                context.fill(path, with: .color(color))
            }
        }
    }
    
    // MARK: - Ghost Pixels (160×120, 4×4px each)
    
    private func drawGhostPixels(context: GraphicsContext, opacity: Double) {
        let ps = Self.ghostPixelSize
        let gap = Self.ghostGap
        let cr = Self.ghostCornerRadius
        
        for row in 0..<Self.ghostRows {
            for col in 0..<Self.ghostCols {
                let index = row * Self.ghostCols + col
                guard index < ghostMask.count, ghostMask[index] else { continue }
                
                let x = CGFloat(col) * ps
                let y = CGFloat(row) * ps
                let rect = CGRect(
                    x: x + gap / 2,
                    y: y + gap / 2,
                    width: ps - gap,
                    height: ps - gap
                )
                let path = Path(roundedRect: rect, cornerRadius: cr)
                context.fill(path, with: .color(Color.green.opacity(opacity)))
            }
        }
    }
}
