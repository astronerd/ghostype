//
//  ReceiptSlipView.swift
//  AIInputMethod
//
//  热敏纸条 UI - 校准挑战交互卡片
//  从 CRT 屏幕上方滑出，米白色背景，等宽字体
//  显示场景描述和 2~3 个选项按钮
//
//  Validates: Requirements 8a.2, 8a.3, 8a.4
//

import SwiftUI

struct ReceiptSlipView: View {
    let challenge: CalibrationChallenge
    let onSelectOption: (Int) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // 场景描述
            Text(challenge.scenario)
                .font(DS.Typography.mono(12, weight: .regular))
                .foregroundColor(.black)
            
            // 选项按钮
            ForEach(Array(challenge.options.enumerated()), id: \.offset) { index, option in
                Button(action: { onSelectOption(index) }) {
                    Text("[\(Character(UnicodeScalar(65 + index)!))] \(option)")
                        .font(DS.Typography.mono(12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.sm)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.lg)
        .background(Color(red: 0.96, green: 0.94, blue: 0.90))  // 米白色热敏纸
        .cornerRadius(DS.Layout.cornerRadius)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
