//
//  MemoSyncService.swift
//  AIInputMethod
//
//  同步服务统一协议，所有同步适配器需实现此协议
//  Validates: Requirements 1.1, 1.2, 1.3
//

import Foundation

// MARK: - MemoSyncService

/// 同步服务统一协议
protocol MemoSyncService {
    /// 服务名称标识
    var serviceName: String { get }

    /// 同步单条 Memo
    func sync(memo: MemoSyncPayload, config: SyncAdapterConfig) async -> SyncResult

    /// 验证连接状态
    func validateConnection(config: SyncAdapterConfig) async -> SyncResult
}
