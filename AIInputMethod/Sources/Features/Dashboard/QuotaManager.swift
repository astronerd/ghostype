//
//  QuotaManager.swift
//  AIInputMethod
//
//  Quota management using server-side character quota.
//  Fetches usage data from GHOSTYPE backend via ProfileResponse.
//  Validates: Requirements 7.2, 7.3, 7.4, 7.5
//

import Foundation

// MARK: - Quota Manager

/// 额度管理器
/// 从服务端获取字符额度数据，替代本地 CoreData 秒数额度
/// 使用 @Observable 宏实现响应式状态管理（macOS 14+）
/// Validates: Requirements 7.2, 7.3, 7.4, 7.5
@Observable
class QuotaManager {

    // MARK: - Singleton

    static let shared = QuotaManager()

    // MARK: - Properties

    /// 已使用字符数
    private(set) var usedCharacters: Int

    /// 字符上限（-1 表示无限）
    private(set) var limitCharacters: Int

    /// 下次重置时间
    private(set) var resetAt: Date?

    /// 订阅计划: "free" 或 "pro"
    private(set) var plan: String

    /// 是否为终身 VIP
    private(set) var isLifetimeVip: Bool

    /// 订阅到期时间（Lifetime VIP 为 nil）
    private(set) var currentPeriodEnd: Date?

    // MARK: - Computed Properties

    /// 用户等级
    enum UserTier {
        case free
        case pro
        case lifetimeVip
    }

    /// 当前用户等级
    var userTier: UserTier {
        if isLifetimeVip { return .lifetimeVip }
        if plan == "pro" { return .pro }
        return .free
    }

    /// 额度是否无限制（limit == -1）
    /// Validates: Requirements 7.3
    var isUnlimited: Bool {
        return limitCharacters == -1
    }

    /// 已使用百分比 (0.0 - 1.0)
    /// 无限制用户始终返回 0.0
    /// Validates: Requirements 7.4
    var usedPercentage: Double {
        guard !isUnlimited else { return 0.0 }
        guard limitCharacters > 0 else { return 0.0 }
        let percentage = Double(usedCharacters) / Double(limitCharacters)
        return min(max(percentage, 0.0), 1.0)
    }

    /// 格式化的已使用字符串
    /// Free 用户: "1234 / 6000 字符"
    /// Pro 用户: "1234 字符（无限制）"
    /// Validates: Requirements 7.3, 7.4
    var formattedUsed: String {
        let chars = L.Quota.characters
        if isUnlimited {
            return "\(usedCharacters) \(chars)\(L.Quota.unlimited)"
        } else {
            return "\(usedCharacters) / \(limitCharacters) \(chars)"
        }
    }

    /// 格式化的重置时间
    /// 例如: "3 天后重置" (中文) 或 "Resets in 3 days" (英文)
    /// Validates: Requirements 7.5
    var formattedResetTime: String {
        guard let resetAt = resetAt else { return "" }

        let now = Date()
        guard resetAt > now else {
            return L.Quota.expired
        }

        let interval = resetAt.timeIntervalSince(now)
        let hours = Int(interval / 3600)
        let days = hours / 24

        if days > 0 {
            return "\(L.Quota.resetPrefix)\(days)\(L.Quota.daysUnit)\(L.Quota.resetSuffix)"
        } else if hours > 0 {
            return "\(L.Quota.resetPrefix)\(hours)\(L.Quota.hoursUnit)\(L.Quota.resetSuffix)"
        } else {
            // Less than 1 hour
            return "\(L.Quota.resetPrefix)< 1\(L.Quota.hoursUnit)\(L.Quota.resetSuffix)"
        }
    }

    // MARK: - Initialization

    /// 私有初始化（单例模式）
    private init() {
        self.usedCharacters = 0
        self.limitCharacters = 0
        self.resetAt = nil
        self.plan = "free"
        self.isLifetimeVip = false
        self.currentPeriodEnd = nil
    }

    /// 用于测试的内部初始化方法
    /// - Parameters:
    ///   - usedCharacters: 已使用字符数
    ///   - limitCharacters: 字符上限（-1 表示无限）
    ///   - resetAt: 下次重置时间
    ///   - plan: 订阅计划
    ///   - isLifetimeVip: 是否终身 VIP
    init(
        usedCharacters: Int,
        limitCharacters: Int,
        resetAt: Date?,
        plan: String = "free",
        isLifetimeVip: Bool = false
    ) {
        self.usedCharacters = usedCharacters
        self.limitCharacters = limitCharacters
        self.resetAt = resetAt
        self.plan = plan
        self.isLifetimeVip = isLifetimeVip
        self.currentPeriodEnd = nil
    }

    // MARK: - Public Methods

    /// 从服务器刷新额度数据
    /// 调用 GhostypeAPIClient.shared.fetchProfile() 并更新本地状态
    func refresh() async {
        do {
            let response = try await GhostypeAPIClient.shared.fetchProfile()
            print("[QuotaManager] 📊 Server response - used: \(response.usage.used), limit: \(response.usage.limit), reset_at: \(response.usage.reset_at), plan: \(response.subscription.plan)")
            await MainActor.run {
                self.update(from: response)
                print("[QuotaManager] ✅ Updated - usedCharacters: \(self.usedCharacters), limitCharacters: \(self.limitCharacters), usedPercentage: \(self.usedPercentage)")
            }
        } catch {
            // 刷新失败时保持当前状态，仅记录日志
            print("[QuotaManager] ❌ Failed to refresh quota: \(error)")
        }
    }

    /// 上报用量并用返回值直接刷新能量环
    /// - Parameter characters: 本次上屏的字符数
    func reportAndRefresh(characters: Int) async {
        guard characters > 0 else { return }
        do {
            let response = try await GhostypeAPIClient.shared.reportUsage(characters: characters)
            print("[QuotaManager] 📤 Reported \(characters) chars → used: \(response.used), limit: \(response.limit)")
            await MainActor.run {
                self.usedCharacters = response.used
                self.limitCharacters = response.limit
                print("[QuotaManager] ✅ Updated from report - usedPercentage: \(self.usedPercentage)")
            }
        } catch {
            print("[QuotaManager] ❌ Failed to report usage: \(error)")
            // 上报失败时 fallback 到 refresh
            await refresh()
        }
    }

    /// 用 ProfileResponse 更新本地状态
    /// - Parameter response: 服务器返回的用户配置响应
    /// Validates: Requirements 7.2, 7.3, 7.4, 7.5
    func update(from response: ProfileResponse) {
        self.usedCharacters = response.usage.used
        self.limitCharacters = response.usage.limit
        self.plan = response.subscription.plan
        self.isLifetimeVip = response.subscription.is_lifetime_vip

        // 解析 ISO 8601 格式的 reset_at 时间
        self.resetAt = Self.parseISO8601(response.usage.reset_at)

        // 解析订阅到期时间
        if let endStr = response.subscription.current_period_end {
            self.currentPeriodEnd = Self.parseISO8601(endStr)
        } else {
            self.currentPeriodEnd = nil
        }
    }

    // MARK: - Private Helpers

    /// 解析 ISO 8601 日期字符串
    /// - Parameter dateString: ISO 8601 格式的日期字符串
    /// - Returns: 解析后的 Date，解析失败返回 nil
    private static func parseISO8601(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // 尝试不带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}

// MARK: - QuotaManager Extension for Testing

extension QuotaManager {

    /// 创建用于测试的 QuotaManager 实例
    /// - Parameters:
    ///   - usedCharacters: 已使用字符数
    ///   - limitCharacters: 字符上限（-1 表示无限）
    ///   - plan: 订阅计划
    /// - Returns: 配置好的 QuotaManager 实例
    static func forTesting(
        usedCharacters: Int = 0,
        limitCharacters: Int = 6000,
        plan: String = "free"
    ) -> QuotaManager {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        return QuotaManager(
            usedCharacters: usedCharacters,
            limitCharacters: limitCharacters,
            resetAt: futureDate,
            plan: plan,
            isLifetimeVip: plan == "pro"
        )
    }
}
