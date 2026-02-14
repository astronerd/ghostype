//
//  ProfilingFlowState.swift
//  AIInputMethod
//
//  构筑流程状态机 — 持久化中间状态，支持中断恢复
//  Validates: Requirements 12.2, 12.5
//

import Foundation

// MARK: - ProfilingPhase

/// 构筑流程阶段
enum ProfilingPhase: String, Codable {
    case idle       // 无进行中的构筑
    case pending    // 待执行（升级触发或网络失败后等待重试）
    case running    // LLM 请求执行中
}

// MARK: - ProfilingFlowState

/// 构筑流程中间状态（持久化到 JSON 文件）
/// Validates: Requirements 12.2, 12.5
struct ProfilingFlowState: Codable, Equatable {
    var phase: ProfilingPhase
    var triggerLevel: Int?
    var corpusIds: [UUID]?
    var retryCount: Int
    var maxRetries: Int       // 默认 3
    var updatedAt: Date
}
