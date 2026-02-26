//
//  CalibrationFlowState.swift
//  AIInputMethod
//
//  校准流程状态机 — 持久化中间状态，支持中断恢复
//  Validates: Requirements 12.1, 12.4
//

import Foundation

// MARK: - CalibrationPhase

/// 校准流程阶段
enum CalibrationPhase: String, Codable {
    case idle           // 无进行中的校准
    case challenging    // 已出题，等待用户选择
    case analyzing      // 已答题，等待 LLM 分析结果
}

// MARK: - CalibrationFlowState

/// 校准流程中间状态（持久化到 JSON 文件）
/// Validates: Requirements 12.1, 12.4
struct CalibrationFlowState: Codable, Equatable {
    var phase: CalibrationPhase
    var challenge: LocalCalibrationChallenge?
    var selectedOption: Int?
    var customAnswer: String?
    var retryCount: Int
    var updatedAt: Date
}
