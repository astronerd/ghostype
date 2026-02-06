//
//  QuotaManager.swift
//  AIInputMethod
//
//  Quota management for tracking voice input duration.
//  Implements the Quota_System for tracking usage and calculating percentages.
//  Validates: Requirements 9.1, 9.3
//

import Foundation
import SwiftUI

// MARK: - Quota Constants

/// 额度系统常量配置
enum QuotaConstants {
    /// 免费用户每月额度（秒）- 1小时 = 3600秒
    static let freeMonthlyQuota: Int = 3600
    
    /// 警告阈值（百分比）- 超过此值显示警告
    static let warningThreshold: Double = 0.9
}

// MARK: - Quota Manager

/// 额度管理器
/// 负责追踪语音输入时长、计算使用百分比、管理额度重置
/// 使用 @Observable 宏实现响应式状态管理（macOS 14+）
/// Validates: Requirements 9.1, 9.3
@Observable
class QuotaManager {
    
    // MARK: - Properties
    
    /// 已使用的秒数
    private(set) var usedSeconds: Int
    
    /// 额度重置日期
    private(set) var resetDate: Date
    
    /// 每月总额度（秒）
    let totalSeconds: Int
    
    /// 持久化控制器（用于 CoreData 存储）
    private let persistenceController: PersistenceController
    
    /// 设备 ID 管理器
    private let deviceIdManager: DeviceIdManager
    
    // MARK: - Computed Properties
    
    /// 已使用百分比 (0.0 - 1.0)
    /// 计算公式: usedSeconds / totalSeconds，结果限制在 [0.0, 1.0] 范围内
    /// Validates: Requirements 9.3
    var usedPercentage: Double {
        guard totalSeconds > 0 else {
            return 0.0
        }
        let percentage = Double(usedSeconds) / Double(totalSeconds)
        // 确保百分比在 0.0 到 1.0 之间
        return min(max(percentage, 0.0), 1.0)
    }
    
    /// 剩余秒数
    var remainingSeconds: Int {
        return max(totalSeconds - usedSeconds, 0)
    }
    
    /// 是否已超过警告阈值
    var isWarning: Bool {
        return usedPercentage >= QuotaConstants.warningThreshold
    }
    
    /// 是否已耗尽额度
    var isExhausted: Bool {
        return usedSeconds >= totalSeconds
    }
    
    /// 格式化的已使用时间字符串
    var formattedUsedTime: String {
        return formatTime(seconds: usedSeconds)
    }
    
    /// 格式化的剩余时间字符串
    var formattedRemainingTime: String {
        return formatTime(seconds: remainingSeconds)
    }
    
    /// 格式化的总额度时间字符串
    var formattedTotalTime: String {
        return formatTime(seconds: totalSeconds)
    }
    
    // MARK: - Initialization
    
    /// 初始化额度管理器
    /// - Parameters:
    ///   - persistenceController: CoreData 持久化控制器，默认使用共享实例
    ///   - deviceIdManager: 设备 ID 管理器，默认使用共享实例
    ///   - totalSeconds: 每月总额度（秒），默认为免费用户额度
    init(
        persistenceController: PersistenceController = .shared,
        deviceIdManager: DeviceIdManager = .shared,
        totalSeconds: Int = QuotaConstants.freeMonthlyQuota
    ) {
        self.persistenceController = persistenceController
        self.deviceIdManager = deviceIdManager
        self.totalSeconds = totalSeconds
        
        // 从 CoreData 加载或创建额度记录
        let quotaRecord = persistenceController.fetchOrCreateQuotaRecord(deviceId: deviceIdManager.deviceId)
        self.usedSeconds = Int(quotaRecord.usedSeconds)
        self.resetDate = quotaRecord.resetDate
        
        // 检查是否需要重置
        checkAndResetIfNeeded()
    }
    
    /// 用于测试的初始化方法（不依赖 CoreData）
    /// - Parameters:
    ///   - usedSeconds: 初始已使用秒数
    ///   - resetDate: 重置日期
    ///   - totalSeconds: 总额度秒数
    init(usedSeconds: Int, resetDate: Date, totalSeconds: Int = QuotaConstants.freeMonthlyQuota) {
        self.usedSeconds = max(usedSeconds, 0)
        self.resetDate = resetDate
        self.totalSeconds = totalSeconds
        self.persistenceController = .shared
        self.deviceIdManager = .shared
    }
    
    // MARK: - Public Methods
    
    /// 记录使用时长
    /// - Parameter seconds: 使用的秒数
    /// Validates: Requirements 9.1
    func recordUsage(seconds: Int) {
        guard seconds > 0 else {
            return
        }
        
        // 累加使用时长
        usedSeconds += seconds
        
        // 更新 CoreData
        updateQuotaRecord()
    }
    
    /// 检查并在需要时重置额度
    /// 如果当前日期已超过重置日期，则重置已使用秒数并设置新的重置日期
    func checkAndResetIfNeeded() {
        let now = Date()
        
        // 如果当前日期已超过重置日期，执行重置
        if now >= resetDate {
            resetQuota()
        }
    }
    
    /// 重置额度
    /// 将已使用秒数归零，并设置新的重置日期（下个月）
    func resetQuota() {
        usedSeconds = 0
        resetDate = Self.calculateNextResetDate()
        
        // 更新 CoreData
        updateQuotaRecord()
    }
    
    /// 获取距离重置还有多少天
    var daysUntilReset: Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: resetDate)
        return max(components.day ?? 0, 0)
    }
    
    // MARK: - Private Methods
    
    /// 更新 CoreData 中的额度记录
    private func updateQuotaRecord() {
        let quotaRecord = persistenceController.fetchOrCreateQuotaRecord(deviceId: deviceIdManager.deviceId)
        quotaRecord.usedSeconds = Int32(usedSeconds)
        quotaRecord.resetDate = resetDate
        quotaRecord.lastUpdated = Date()
        persistenceController.save()
    }
    
    /// 计算下一个重置日期（下个月的第一天）
    private static func calculateNextResetDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取当前年月
        let components = calendar.dateComponents([.year, .month], from: now)
        
        // 获取本月第一天
        guard let startOfMonth = calendar.date(from: components),
              // 加一个月得到下个月第一天
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            // 如果计算失败，返回 30 天后
            return calendar.date(byAdding: .day, value: 30, to: now) ?? now
        }
        
        return nextMonth
    }
    
    /// 格式化时间为可读字符串
    /// - Parameter seconds: 秒数
    /// - Returns: 格式化的时间字符串（如 "30分钟" 或 "1小时30分钟"）
    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)小时\(minutes)分钟"
            } else {
                return "\(hours)小时"
            }
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(remainingSeconds)秒"
        }
    }
}

// MARK: - QuotaManager Extension for Testing

extension QuotaManager {
    
    /// 创建用于测试的 QuotaManager 实例
    /// - Parameters:
    ///   - usedSeconds: 已使用秒数
    ///   - totalSeconds: 总额度秒数
    /// - Returns: 配置好的 QuotaManager 实例
    static func forTesting(usedSeconds: Int = 0, totalSeconds: Int = QuotaConstants.freeMonthlyQuota) -> QuotaManager {
        let futureDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        return QuotaManager(usedSeconds: usedSeconds, resetDate: futureDate, totalSeconds: totalSeconds)
    }
}
