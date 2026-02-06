//
//  StatsCalculator.swift
//  AIInputMethod
//
//  Statistics calculator for Dashboard data visualization.
//  Provides today's stats, app distribution, and recent notes queries.
//

import Foundation
import CoreData

// MARK: - TodayStats

/// 今日统计数据结构
/// 包含今日输入字数和估算节省时间
struct TodayStats {
    /// 今日输入字符数
    var characterCount: Int
    
    /// 估算节省的时间（秒）
    /// 基于假设打字速度 2字/秒 计算
    var estimatedTimeSaved: TimeInterval
    
    /// 空统计数据
    static let empty = TodayStats(characterCount: 0, estimatedTimeSaved: 0)
}

// MARK: - AppUsage

/// 应用使用统计数据结构
/// 用于显示应用分布饼图
struct AppUsage: Identifiable {
    /// 唯一标识符，使用 bundleId
    var id: String { bundleId }
    
    /// 应用的 Bundle ID
    var bundleId: String
    
    /// 应用显示名称
    var appName: String
    
    /// 使用次数（记录数量）
    var usageCount: Int
    
    /// 使用占比（0.0 - 1.0）
    /// 所有 AppUsage 的 percentage 之和应等于 1.0
    var percentage: Double
}

// MARK: - StatsCalculator

/// 统计计算器
/// 负责从 CoreData 查询数据并计算各种统计指标
class StatsCalculator {
    
    // MARK: - Constants
    
    /// 假设的打字速度（字符/秒）
    /// 用于估算节省时间
    static let typingSpeedPerSecond: Double = 2.0
    
    // MARK: - Properties
    
    /// CoreData 持久化控制器
    private let persistenceController: PersistenceController
    
    /// 设备 ID 管理器
    private let deviceIdManager: DeviceIdManager
    
    // MARK: - Initialization
    
    /// 初始化统计计算器
    /// - Parameters:
    ///   - persistenceController: CoreData 持久化控制器，默认使用共享实例
    ///   - deviceIdManager: 设备 ID 管理器，默认使用共享实例
    init(
        persistenceController: PersistenceController = .shared,
        deviceIdManager: DeviceIdManager = .shared
    ) {
        self.persistenceController = persistenceController
        self.deviceIdManager = deviceIdManager
    }
    
    // MARK: - Today Stats
    
    /// 计算今日统计数据
    /// - Returns: 今日统计数据，包含字符数和估算节省时间
    func calculateTodayStats() -> TodayStats {
        let records = fetchTodayRecords()
        return calculateStats(from: records)
    }
    
    /// 从 UsageRecord 数组计算统计数据
    /// - Parameter records: UsageRecord 数组
    /// - Returns: 计算后的 TodayStats
    func calculateStats(from records: [UsageRecord]) -> TodayStats {
        // 计算总字符数
        let characterCount = records.reduce(0) { total, record in
            total + record.content.count
        }
        
        // 计算估算节省时间（秒）
        // 假设打字速度为 2 字符/秒
        let estimatedTimeSaved = Double(characterCount) / Self.typingSpeedPerSecond
        
        return TodayStats(
            characterCount: characterCount,
            estimatedTimeSaved: estimatedTimeSaved
        )
    }
    
    /// 获取今日的 UsageRecord 记录
    /// - Returns: 今日的 UsageRecord 数组
    func fetchTodayRecords() -> [UsageRecord] {
        let context = persistenceController.viewContext
        let request = UsageRecord.fetchRequest()
        
        // 获取今日的开始和结束时间
        let calendar = Calendar.current
        let now = Date()
        guard let startOfDay = calendar.startOfDay(for: now) as Date?,
              let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        // 设置查询条件：今日 + 当前设备
        let deviceId = deviceIdManager.deviceId
        request.predicate = NSPredicate(
            format: "deviceId == %@ AND timestamp >= %@ AND timestamp < %@",
            deviceId,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // 按时间倒序排列
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \UsageRecord.timestamp, ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("StatsCalculator: Failed to fetch today's records: \(error)")
            return []
        }
    }
    
    // MARK: - App Distribution
    
    /// 计算应用分布统计
    /// - Returns: 按使用次数降序排列的 AppUsage 数组
    func calculateAppDistribution() -> [AppUsage] {
        let records = fetchAllRecords()
        return calculateAppDistribution(from: records)
    }
    
    /// 从 UsageRecord 数组计算应用分布
    /// - Parameter records: UsageRecord 数组
    /// - Returns: 按使用次数降序排列的 AppUsage 数组，所有 percentage 之和等于 1.0
    func calculateAppDistribution(from records: [UsageRecord]) -> [AppUsage] {
        // 空记录返回空数组
        guard !records.isEmpty else {
            return []
        }
        
        // 按 sourceAppBundleId 分组统计
        var appUsageDict: [String: (appName: String, count: Int)] = [:]
        
        for record in records {
            let bundleId = record.sourceAppBundleId
            let appName = record.sourceApp
            
            if let existing = appUsageDict[bundleId] {
                appUsageDict[bundleId] = (appName: existing.appName, count: existing.count + 1)
            } else {
                appUsageDict[bundleId] = (appName: appName, count: 1)
            }
        }
        
        // 计算总使用次数
        let totalCount = records.count
        
        // 转换为 AppUsage 数组并计算百分比
        var appUsages = appUsageDict.map { (bundleId, data) -> AppUsage in
            let percentage = Double(data.count) / Double(totalCount)
            return AppUsage(
                bundleId: bundleId,
                appName: data.appName,
                usageCount: data.count,
                percentage: percentage
            )
        }
        
        // 按使用次数降序排列
        appUsages.sort { $0.usageCount > $1.usageCount }
        
        return appUsages
    }
    
    /// 获取所有 UsageRecord 记录（当前设备）
    /// - Returns: 当前设备的所有 UsageRecord 数组
    func fetchAllRecords() -> [UsageRecord] {
        let context = persistenceController.viewContext
        let request = UsageRecord.fetchRequest()
        
        // 设置查询条件：当前设备
        let deviceId = deviceIdManager.deviceId
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId)
        
        // 按时间倒序排列
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \UsageRecord.timestamp, ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("StatsCalculator: Failed to fetch all records: \(error)")
            return []
        }
    }
    
    // MARK: - Recent Notes Query
    
    /// 查询最近的笔记记录
    /// 返回最多 3 条 memo 类型记录，按时间倒序排列
    /// - Returns: 最近的 memo 类型 UsageRecord 数组（最多 3 条）
    func fetchRecentNotes() -> [UsageRecord] {
        let records = fetchAllMemoRecords()
        return getRecentNotes(from: records)
    }
    
    /// 从 UsageRecord 数组中获取最近的笔记
    /// - Parameter records: UsageRecord 数组
    /// - Returns: 最多 3 条 memo 类型记录，按时间倒序排列
    func getRecentNotes(from records: [UsageRecord]) -> [UsageRecord] {
        // 过滤出 memo 类型的记录
        let memoRecords = records.filter { $0.category == "memo" }
        
        // 按时间倒序排列
        let sortedRecords = memoRecords.sorted { record1, record2 in
            record1.timestamp > record2.timestamp
        }
        
        // 返回最多 3 条记录
        return Array(sortedRecords.prefix(3))
    }
    
    /// 获取所有 memo 类型的 UsageRecord 记录（当前设备）
    /// - Returns: 当前设备的所有 memo 类型 UsageRecord 数组
    func fetchAllMemoRecords() -> [UsageRecord] {
        let context = persistenceController.viewContext
        let request = UsageRecord.fetchRequest()
        
        // 设置查询条件：当前设备 + memo 类型
        let deviceId = deviceIdManager.deviceId
        request.predicate = NSPredicate(
            format: "deviceId == %@ AND category == %@",
            deviceId,
            "memo"
        )
        
        // 按时间倒序排列
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \UsageRecord.timestamp, ascending: false)
        ]
        
        // 限制返回数量为 3
        request.fetchLimit = 3
        
        do {
            return try context.fetch(request)
        } catch {
            print("StatsCalculator: Failed to fetch memo records: \(error)")
            return []
        }
    }
    
    // MARK: - Convenience Methods
    
    /// 格式化节省时间为可读字符串
    /// - Parameter seconds: 秒数
    /// - Returns: 格式化后的字符串（如 "5分30秒"）
    static func formatTimeSaved(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        
        if totalSeconds < 60 {
            return "\(totalSeconds)秒"
        }
        
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        
        if remainingSeconds == 0 {
            return "\(minutes)分钟"
        }
        
        return "\(minutes)分\(remainingSeconds)秒"
    }
}
