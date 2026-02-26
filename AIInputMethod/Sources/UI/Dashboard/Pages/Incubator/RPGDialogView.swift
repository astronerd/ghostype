//
//  RPGDialogView.swift
//  AIInputMethod
//
//  RPG 风格像素对话框 - 口袋妖怪黄风格
//  实心黑底 + 双层像素边框（外白内黑），像素字体
//  显示在 CRT 屏幕内部底部
//  位于 DotMatrixView 之上、CRTEffectsView 之下
//

import SwiftUI

/// RPG 风格像素对话框
/// 口袋妖怪黄风格：实心黑底 + 绿色双层像素边框
struct RPGDialogView: View {
    
    let text: String
    let isTyping: Bool
    let isInteractive: Bool
    var onTap: (() -> Void)?
    let isBlinking: Bool
    let isDisabled: Bool
    let isLoading: Bool
    let textColor: Color
    
    init(
        text: String,
        isTyping: Bool = false,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil,
        isBlinking: Bool = false,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        textColor: Color = Color.green
    ) {
        self.text = text
        self.isTyping = isTyping
        self.isInteractive = isInteractive
        self.onTap = onTap
        self.isBlinking = isBlinking
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.textColor = textColor
    }
    
    // 像素边框线宽
    private static let borderWidth: CGFloat = 2
    private static let borderInset: CGFloat = 3
    
    var body: some View {
        VStack {
            Spacer()
            
            dialogContent
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
        }
    }
    
    @ViewBuilder
    private var dialogContent: some View {
        let content = HStack(spacing: 0) {
            if isLoading {
                ProgressIndicator()
                    .frame(width: 10, height: 10)
                    .padding(.trailing, 4)
            }
            
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(textColor.opacity(isBlinking ? 1.0 : 0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            if isTyping {
                Text("▌")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.7))
                    .blinkingCursor()
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(pixelBorderBackground)
        
        if isInteractive {
            Button(action: { onTap?() }) {
                content
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        } else {
            content
                .allowsHitTesting(false)
        }
    }
    
    /// 口袋妖怪黄风格：实心黑底 + 双层像素边框
    /// 外层亮绿边框 → 2px 黑色间隔 → 内层暗绿边框 → 实心黑底
    private var pixelBorderBackground: some View {
        ZStack {
            // 外层边框（亮绿）
            Rectangle()
                .fill(Color.green.opacity(0.7))
            
            // 内层黑色间隔
            Rectangle()
                .fill(Color.black)
                .padding(Self.borderWidth)
            
            // 内层边框（暗绿）
            Rectangle()
                .fill(Color.green.opacity(0.35))
                .padding(Self.borderWidth + 1)
            
            // 实心黑底
            Rectangle()
                .fill(Color.black)
                .padding(Self.borderWidth + 1 + Self.borderWidth)
        }
    }
}

// MARK: - Blinking Cursor Modifier

private struct BlinkingCursorModifier: ViewModifier {
    @State private var isVisible = true
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}

extension View {
    fileprivate func blinkingCursor() -> some View {
        modifier(BlinkingCursorModifier())
    }
}

// MARK: - ProgressIndicator

private struct ProgressIndicator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .mini
        indicator.startAnimation(nil)
        return indicator
    }
    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}
