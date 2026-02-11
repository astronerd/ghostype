//
//  ReceiptSlipView.swift
//  AIInputMethod
//
//  校准挑战交互卡片 - RPG 像素风格
//  居中覆盖 CRT 屏幕内容，口袋妖怪黄风格边框
//  支持鼠标滚轮滚动长文本
//
//  Validates: Requirements 8a.2, 8a.3, 8a.4
//

import SwiftUI

struct ReceiptSlipView: View {
    let challenge: CalibrationChallenge
    let onSelectOption: (Int) -> Void
    let onDismiss: () -> Void
    
    // 像素边框线宽（与 RPGDialogView / LevelInfoBar 一致）
    private static let borderWidth: CGFloat = 2
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 可滚动内容区
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // 场景描述
                    Text(challenge.scenario)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.green.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // 分隔线
                    Rectangle()
                        .fill(Color.green.opacity(0.25))
                        .frame(height: 1)
                        .padding(.vertical, 2)
                    
                    // 选项按钮
                    ForEach(Array(challenge.options.enumerated()), id: \.offset) { index, option in
                        Button(action: { onSelectOption(index) }) {
                            HStack(spacing: 4) {
                                Text(verbatim: "[\(Character(UnicodeScalar(65 + index)!))]")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.green.opacity(0.9))
                                
                                Text(option)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.green.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.08))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
        }
        .background(pixelBorderBackground)
        .transition(.opacity)
    }
    
    /// 口袋妖怪黄风格像素边框
    /// 外层亮绿边框 → 黑色间隔 → 内层暗绿边框 → 实心黑底
    private var pixelBorderBackground: some View {
        ZStack {
            Rectangle()
                .fill(Color.green.opacity(0.7))
            Rectangle()
                .fill(Color.black)
                .padding(Self.borderWidth)
            Rectangle()
                .fill(Color.green.opacity(0.35))
                .padding(Self.borderWidth + 1)
            Rectangle()
                .fill(Color.black)
                .padding(Self.borderWidth + 1 + Self.borderWidth)
        }
    }
}
