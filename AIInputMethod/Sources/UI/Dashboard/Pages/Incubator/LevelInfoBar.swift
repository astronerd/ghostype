//
//  LevelInfoBar.swift
//  AIInputMethod
//
//  等级信息栏 - RPG 像素风格，显示在 CRT 屏幕内部上方
//  口袋妖怪黄风格：实心黑底 + 双层像素边框（外亮绿 → 黑间隔 → 内暗绿）
//
//  Validates: Requirements 2.5
//

import SwiftUI

struct LevelInfoBar: View {
    
    /// 当前等级 (1~10)
    let level: Int
    
    /// 当前等级进度 (0.0 ~ 1.0)
    let progressFraction: Double
    
    /// 同步率百分比 (10~100)
    let syncRate: Int
    
    // 像素边框线宽（与 RPGDialogView 一致）
    private static let borderWidth: CGFloat = 2
    
    var body: some View {
        HStack(spacing: 6) {
            // 等级标签
            Text("Lv.\(level)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.9))
            
            // 像素风格进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景轨道（暗绿边框）
                    Rectangle()
                        .fill(Color.green.opacity(0.15))
                    
                    // 填充进度（亮绿）
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: geo.size.width * min(max(progressFraction, 0), 1))
                }
            }
            .frame(height: 4)
            
            // 同步率
            Text("\(syncRate)%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(pixelBorderBackground)
    }
    
    /// 口袋妖怪黄风格像素边框（与 RPGDialogView 一致）
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
