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
    
    /// 累积输入字符数
    var totalCharacterCount: Int
    
    /// 估算节省的时间（秒）
    /// Requirement 9.3: 基于假设打字速度 60字符/分钟 (1字符/秒) 计算
    var estimatedTimeSaved: TimeInterval
    
    /// 空统计数据
    static let empty = TodayStats(characterCount: 0, totalCharacterCount: 0, estimatedTimeSaved: 0)
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
    /// Requirement 9.3: calculated as characters / 60 characters per minute = 1 char/second
    static let typingSpeedPerSecond: Double = 1.0
    
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
        let todayRecords = fetchTodayRecords()
        let allRecords = fetchAllRecords()
        return calculateStats(todayRecords: todayRecords, allRecords: allRecords)
    }
    
    /// 从 UsageRecord 数组计算统计数据
    /// - Parameter todayRecords: 今日 UsageRecord 数组
    /// - Parameter allRecords: 所有 UsageRecord 数组
    /// - Returns: 计算后的 TodayStats
    func calculateStats(todayRecords: [UsageRecord], allRecords: [UsageRecord]) -> TodayStats {
        // 计算今日字符数
        let characterCount = todayRecords.reduce(0) { total, record in
            total + record.content.count
        }
        
        // 计算累积字符数
        let totalCharacterCount = allRecords.reduce(0) { total, record in
            total + record.content.count
        }
        
        // 计算估算节省时间（秒）
        // 节省时间 = 打字时间 - 说话时间
        // 打字时间 = 字数 / 打字速度（1字/秒）
        // 说话时间 = 音频时长总和
        let typingTime = Double(characterCount) / Self.typingSpeedPerSecond
        let speakingTime = todayRecords.reduce(0.0) { total, record in
            total + Double(record.duration)
        }
        let estimatedTimeSaved = max(0, typingTime - speakingTime)
        
        return TodayStats(
            characterCount: characterCount,
            totalCharacterCount: totalCharacterCount,
            estimatedTimeSaved: estimatedTimeSaved
        )
    }
    
    /// 从 UsageRecord 数组计算统计数据（兼容旧接口）
    func calculateStats(from records: [UsageRecord]) -> TodayStats {
        return calculateStats(todayRecords: records, allRecords: records)
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
    
    /// 从 UsageRecord 数组计算应用分布（Top 5 + 其他）
    /// - Parameter records: UsageRecord 数组
    /// - Returns: 按使用次数降序排列的 AppUsage 数组，最多 6 项（Top 5 + 其他），所有 percentage 之和等于 1.0
    /// - Requirement 11.4: THE pie chart SHALL display top 5 apps, grouping remaining as "其他"
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
        
        // Requirement 11.4: 如果超过 5 个应用，将剩余的合并为"其他"
        if appUsages.count > 5 {
            let top5 = Array(appUsages.prefix(5))
            let others = appUsages.dropFirst(5)
            
            let otherCount = others.reduce(0) { $0 + $1.usageCount }
            let otherPercentage = totalCount > 0 ? Double(otherCount) / Double(totalCount) : 0
            
            let otherUsage = AppUsage(
                bundleId: "com.ghostype.other",
                appName: "其他",
                usageCount: otherCount,
                percentage: otherPercentage
            )
            
            return top5 + [otherUsage]
        }
        
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
    /// 格式化节省时间为可读字符串
    /// - Parameter seconds: 秒数
    /// - Returns: 格式化后的字符串（如 "5分30秒"）
    /// Requirement 9.5: 当无记录时显示 "0 分钟"
    static func formatTimeSaved(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        
        // Requirement 9.5: 当无记录时显示 "0 分钟"
        if totalSeconds == 0 {
            return "0 分钟"
        }
        
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
