//
//  LevelInfoBar.swift
//  AIInputMethod
//
//  等级信息栏 - 显示等级、进度条和同步率
//  位于 CRT_Container 上方
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
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // 等级标签
            Text("Lv.\(level)")
                .font(DS.Typography.mono(14, weight: .bold))
                .foregroundColor(DS.Colors.text1)
            
            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Colors.bg2)
                    
                    // 填充进度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.6))
                        .frame(width: geo.size.width * min(max(progressFraction, 0), 1))
                }
            }
            .frame(height: 6)
            
            // 同步率
            Text("\(L.Incubator.syncRate): \(syncRate)%")
                .font(DS.Typography.mono(11, weight: .regular))
                .foregroundColor(DS.Colors.text2)
        }
        .frame(width: 640)
    }
}
