//
//  RecordCategory.swift
//  AIInputMethod
//
//  Created for GHOSTYPE Dashboard Console
//

import Foundation

/// 记录分类枚举，用于历史库页面的过滤标签
enum RecordCategory: String, CaseIterable, Identifiable {
    case all = "all"
    case polish = "polish"
    case translate = "translate"
    case memo = "memo"
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .polish: return "润色"
        case .translate: return "翻译"
        case .memo: return "随心记"
        }
    }
}
