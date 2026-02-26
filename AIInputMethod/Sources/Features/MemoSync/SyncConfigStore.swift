//
//  SyncConfigStore.swift
//  AIInputMethod
//
//  同步配置管理，基于 UserDefaults + Codable
//  Validates: Requirements 6.4, 6.5, 15.1
//

import Foundation

// MARK: - SyncConfigStore

/// 同步配置管理器
/// 为每个 SyncServiceType 独立存储配置、启用状态和启用时间点
class SyncConfigStore {
    static let shared = SyncConfigStore()

    private let defaults: UserDefaults

    // MARK: - Key Prefixes

    private enum KeyPrefix {
        static let config = "memoSync.config."
        static let enabled = "memoSync.enabled."
        static let enabledSince = "memoSync.enabledSince."
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Config

    /// 读取指定服务的配置
    func config(for service: SyncServiceType) -> SyncAdapterConfig? {
        let key = KeyPrefix.config + service.rawValue
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SyncAdapterConfig.self, from: data)
    }

    /// 保存配置
    func save(config: SyncAdapterConfig, for service: SyncServiceType) {
        let key = KeyPrefix.config + service.rawValue
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Enabled

    /// 服务是否已启用
    func isEnabled(_ service: SyncServiceType) -> Bool {
        let key = KeyPrefix.enabled + service.rawValue
        return defaults.bool(forKey: key)
    }

    /// 启用/禁用服务
    /// 首次启用时自动记录 enabledSince 时间点
    /// 禁用时不清除 enabledSince（保留用于重新启用场景）
    func setEnabled(_ enabled: Bool, for service: SyncServiceType) {
        let key = KeyPrefix.enabled + service.rawValue
        defaults.set(enabled, forKey: key)

        if enabled && enabledSince(service) == nil {
            let sinceKey = KeyPrefix.enabledSince + service.rawValue
            defaults.set(Date().timeIntervalSince1970, forKey: sinceKey)
        }
    }

    // MARK: - Enabled Since

    /// 获取同步启用时间点（用于过滤历史数据）
    func enabledSince(_ service: SyncServiceType) -> Date? {
        let key = KeyPrefix.enabledSince + service.rawValue
        let interval = defaults.double(forKey: key)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
