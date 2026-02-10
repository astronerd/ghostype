//
//  DotMatrixView.swift
//  AIInputMethod
//
//  点阵屏 Canvas 渲染视图
//  双层 Canvas 实现 CRT Bloom 辉光效果：底层模糊光晕 + 上层锐利像素
//  160×120 分辨率（19,200 像素点），每个像素 4×4px，物理尺寸 640×480px
//
//  Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6
//

import SwiftUI

struct DotMatrixView: View {
    
    /// 当前已激活的像素索引集合
    let activePixels: Set<Int>
    
    /// Ghost Logo 掩码：true = Logo 像素
    let ghostMask: [Bool]
    
    /// Ghost Logo 像素的基础透明度（随等级递增：Lv.1=0.1 → Lv.10=1.0）
    let ghostOpacity: Double
    
    /// 当前等级（1~10）
    let level: Int
    
    // MARK: - Constants
    
    /// 像素点尺寸（4×4px）
    private static let pixelSize: CGFloat = 4
    
    /// 像素间隙（0.5px，模拟晶格感）
    private static let gap: CGFloat = 0.5
    
    /// 像素圆角半径（0.75px，模拟 CRT 显像管）
    private static let cornerRadius: CGFloat = 0.75
    
    /// 点阵列数
    private static let cols = 160
    
    /// 点阵行数
    private static let rows = 120
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 底层：模糊光晕（仅绘制已激活像素产生 Bloom 效果）
            // Validates: Requirements 4.2
            Canvas { context, size in
                drawPixels(context: context, size: size)
            }
            .blur(radius: 1.5)
            .blendMode(.screen)
            
            // 上层：锐利像素（清晰的点阵显示）
            Canvas { context, size in
                drawPixels(context: context, size: size)
            }
        }
        .frame(width: 640, height: 480)
        .drawingGroup() // Validates: Requirements 3.6 - 离屏渲染优化性能
    }
    
    // MARK: - Pixel Drawing
    
    /// 绘制所有 19,200 个像素点
    /// 三种像素状态：
    /// - 未激活：极暗灰色（opacity 0.04），模拟熄灭的显像管底噪
    /// - 已激活背景：暗绿色（opacity 0.25）
    /// - Ghost Logo：高亮绿色（opacity = ghostOpacity，随等级递增）
    private func drawPixels(context: GraphicsContext, size: CGSize) {
        let pixelSize = Self.pixelSize
        let gap = Self.gap
        let cornerRadius = Self.cornerRadius
        
        for row in 0..<Self.rows {
            for col in 0..<Self.cols {
                let index = row * Self.cols + col
                let x = CGFloat(col) * pixelSize
                let y = CGFloat(row) * pixelSize
                let rect = CGRect(
                    x: x + gap / 2,
                    y: y + gap / 2,
                    width: pixelSize - gap,
                    height: pixelSize - gap
                )
                let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
                
                let color: Color
                if activePixels.contains(index) {
                    if index < ghostMask.count, ghostMask[index] {
                        // Ghost Logo 像素：高亮绿色，亮度由等级决定
                        // Validates: Requirements 3.5
                        color = Color.green.opacity(ghostOpacity)
                    } else {
                        // 已激活背景像素：暗绿色
                        // Validates: Requirements 3.4
                        color = Color.green.opacity(0.25)
                    }
                } else {
                    // 未激活像素：极暗底噪
                    // Validates: Requirements 3.3
                    color = Color.gray.opacity(0.04)
                }
                
                context.fill(path, with: .color(color))
            }
        }
    }
}
