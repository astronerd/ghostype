//
//  CRTEffectsView.swift
//  AIInputMethod
//
//  CRT 视觉滤镜覆盖层
//  叠加扫描线（Scanlines）和暗角（Vignette）效果，模拟复古 CRT 显示器质感
//  作为不可交互的覆盖层，不拦截点击事件
//
//  Validates: Requirements 4.1, 4.2, 4.3, 4.4
//

import SwiftUI

struct CRTEffectsView: View {
    
    var body: some View {
        ZStack {
            // 扫描线效果：每隔 3px 一条半透明黑色横线
            // Validates: Requirements 4.1
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 3) {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.black.opacity(0.15)))
                }
            }
            
            // 暗角效果：径向渐变从中心透明到四角半透明黑色
            // Validates: Requirements 4.3
            RadialGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                center: .center,
                startRadius: 200,
                endRadius: 400
            )
        }
        .allowsHitTesting(false) // Validates: Requirements 4.4 - 不拦截交互事件
    }
}
