//
//  GhostStatusText.swift
//  AIInputMethod
//
//  Ghost 闲置状态文案 - 等宽字体，打字机逐字显示效果
//  位于 CRT_Container 下方，每 8~15 秒随机切换
//
//  Validates: Requirements 2.6, 10.1, 10.2, 10.3
//

import SwiftUI

struct GhostStatusText: View {
    
    /// 当前显示的文本（由 ViewModel 的打字机效果逐字更新）
    let text: String
    
    /// 是否正在打字机效果中（可用于光标闪烁等附加效果）
    let isTyping: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(DS.Typography.mono(12, weight: .regular))
                .foregroundColor(Color.green.opacity(0.7))
            
            // 打字机光标闪烁效果
            if isTyping {
                BlinkingCursor()
            }
            
            Spacer()
        }
        .frame(width: 640, alignment: .leading)
        .frame(height: 20)
    }
}

// MARK: - Blinking Cursor

/// 打字机闪烁光标
private struct BlinkingCursor: View {
    
    @State private var isVisible = true
    
    var body: some View {
        Text("▌")
            .font(DS.Typography.mono(12, weight: .regular))
            .foregroundColor(Color.green.opacity(0.7))
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}
