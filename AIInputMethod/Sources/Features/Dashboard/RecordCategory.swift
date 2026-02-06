//
//  RecordCategory.swift
//  AIInputMethod
//
//  Created for GhosTYPE Dashboard Console
//

import Foundation

/// 记录分类枚举，用于历史库页面的过滤标签
/// - Requirements: 6.2 - THE Library page SHALL display filter tabs: 全部, 润色, 翻译, 随心记
enum RecordCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case polish = "润色"
    case translate = "翻译"
    case memo = "随心记"
    
    var id: String { rawValue }
}
