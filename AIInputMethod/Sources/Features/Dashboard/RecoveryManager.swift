//
//  RecoveryManager.swift
//  AIInputMethod
//
//  启动恢复管理器 — 持久化/加载/清除校准和构筑流程的中间状态
//  数据损坏时丢弃并记录日志，不会导致崩溃
//  Validates: Requirements 12.3, 12.6, 12.7, 12.11
//

import Foundation

// MARK: - RecoveryManager

/// 启动恢复管理器
/// 负责校准流程和构筑流程中间状态的持久化、加载和清除。
/// - 路径：`calibration_flow.json` 和 `profiling_flow.json`
/// - 反序列化失败时丢弃数据并记录日志（Requirements 12.11）
/// - 保存失败时记录日志，不抛出异常
class RecoveryManager {
    private let basePath: URL

    private var calibrationFlowPath: URL {
        basePath.appendingPathComponent("calibration_flow.json")
    }

    private var profilingFlowPath: URL {
        basePath.appendingPathComponent("profiling_flow.json")
    }

    /// 默认路径：~/Library/Application Support/GHOSTYPE/ghost_twin/
    init(basePath: URL? = nil) {
        if let basePath {
            self.basePath = basePath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.basePath = appSupport
                .appendingPathComponent("GHOSTYPE")
                .appendingPathComponent("ghost_twin")
        }
    }

    // MARK: - CalibrationFlowState

    /// 加载校准流程中间状态
    /// - 文件不存在时返回 nil
    /// - 反序列化失败时丢弃数据、记录日志并返回 nil（Requirements 12.11）
    func loadCalibrationFlowState() -> CalibrationFlowState? {
        loadState(from: calibrationFlowPath, label: "CalibrationFlowState")
    }

    /// 保存校准流程中间状态
    /// - 自动创建目录
    /// - 保存失败时记录日志
    func saveCalibrationFlowState(_ state: CalibrationFlowState) {
        saveState(state, to: calibrationFlowPath, label: "CalibrationFlowState")
    }

    /// 清除校准流程中间状态（Requirements 12.6）
    func clearCalibrationFlowState() {
        clearState(at: calibrationFlowPath, label: "CalibrationFlowState")
    }

    // MARK: - ProfilingFlowState

    /// 加载构筑流程中间状态
    /// - 文件不存在时返回 nil
    /// - 反序列化失败时丢弃数据、记录日志并返回 nil（Requirements 12.11）
    func loadProfilingFlowState() -> ProfilingFlowState? {
        loadState(from: profilingFlowPath, label: "ProfilingFlowState")
    }

    /// 保存构筑流程中间状态
    /// - 自动创建目录
    /// - 保存失败时记录日志
    func saveProfilingFlowState(_ state: ProfilingFlowState) {
        saveState(state, to: profilingFlowPath, label: "ProfilingFlowState")
    }

    /// 清除构筑流程中间状态（Requirements 12.6）
    func clearProfilingFlowState() {
        clearState(at: profilingFlowPath, label: "ProfilingFlowState")
    }

    // MARK: - Private Helpers

    private func loadState<T: Decodable>(from path: URL, label: String) -> T? {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            // Requirements 12.11: 数据损坏时丢弃并记录错误日志
            print("[RecoveryManager] \(label) 反序列化失败，丢弃数据: \(error)")
            clearState(at: path, label: label)
            return nil
        }
    }

    private func saveState<T: Encodable>(_ state: T, to path: URL, label: String) {
        do {
            if !FileManager.default.fileExists(atPath: basePath.path) {
                try FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: path, options: .atomic)
        } catch {
            print("[RecoveryManager] \(label) 保存失败: \(error)")
        }
    }

    private func clearState(at path: URL, label: String) {
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            print("[RecoveryManager] \(label) 清除失败: \(error)")
        }
    }
}
