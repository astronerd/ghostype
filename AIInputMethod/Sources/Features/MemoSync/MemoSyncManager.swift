//
//  MemoSyncManager.swift
//  AIInputMethod
//
//  同步管理器，负责协调触发和分发同步到各笔记应用
//  Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 10.3, 15.1, 15.2
//

import Foundation
import Combine

// MARK: - SyncStatus

/// Memo 同步状态（用于 UI 展示）
enum SyncStatus {
    case synced       // 全部成功
    case partialFail  // 部分失败
    case failed       // 全部失败
}

// MARK: - MemoSyncManager

/// 同步管理器
/// 负责读取已启用的适配器，并行分发同步，记录结果
/// 同步在后台线程异步执行，不阻塞主流程
/// 同步失败不影响本地 CoreData 保存（fire-and-forget）
class MemoSyncManager: ObservableObject {
    static let shared = MemoSyncManager()

    private let configStore: SyncConfigStore

    /// 适配器注册表：SyncServiceType → MemoSyncService 实例
    private let adapterMap: [SyncServiceType: MemoSyncService]

    /// 内存缓存：最近同步结果，按 timestamp 索引，用于 UI 状态展示（不持久化）
    @Published private(set) var syncStatusCache: [Date: SyncStatus] = [:]

    /// 详细同步结果缓存（按 memoId），用于调试和日志
    private(set) var syncResultCache: [UUID: [SyncServiceType: SyncResult]] = [:]

    // MARK: - Init

    init(
        configStore: SyncConfigStore = .shared,
        adapterMap: [SyncServiceType: MemoSyncService]? = nil
    ) {
        self.configStore = configStore
        self.adapterMap = adapterMap ?? [
            .obsidian: ObsidianAdapter(),
            .appleNotes: AppleNotesAdapter(),
            .notion: NotionAdapter(),
            .bear: BearAdapter()
        ]
    }

    // MARK: - Sync Status Query

    /// 查询某条 Memo 的同步状态（通过 timestamp 匹配）
    func syncStatus(for timestamp: Date) -> SyncStatus? {
        return syncStatusCache[timestamp]
    }

    /// 是否有任何同步服务已启用
    var hasAnySyncServiceEnabled: Bool {
        SyncServiceType.allCases.contains { configStore.isEnabled($0) }
    }

    // MARK: - Enabled Adapters

    /// 获取所有已启用的适配器及其配置
    /// 仅返回已启用且有配置的适配器
    func enabledAdapters() -> [(MemoSyncService, SyncAdapterConfig)] {
        var result: [(MemoSyncService, SyncAdapterConfig)] = []
        for serviceType in SyncServiceType.allCases {
            guard configStore.isEnabled(serviceType),
                  let config = configStore.config(for: serviceType),
                  let adapter = adapterMap[serviceType] else {
                continue
            }
            result.append((adapter, config))
        }
        return result
    }

    // MARK: - Sync Memo

    /// 触发同步（从 TextInsertionService 调用）
    /// Fire-and-forget：在后台线程异步执行，不阻塞调用方
    /// 同步失败不影响本地 CoreData 保存
    func syncMemo(content: String, timestamp: Date) {
        let memoId = UUID()
        let payload = MemoSyncPayload(content: content, timestamp: timestamp, memoId: memoId)

        Task.detached { [weak self] in
            guard let self = self else { return }
            await self.dispatchSync(payload: payload)
        }
    }

    // MARK: - Dispatch

    /// 并行分发同步到所有已启用的适配器
    /// 遍历所有 SyncServiceType，检查启用状态和历史数据过滤后并行执行
    private func dispatchSync(payload: MemoSyncPayload) async {
        // 收集需要同步的 (serviceType, adapter, config) 三元组
        var tasks: [(SyncServiceType, MemoSyncService, SyncAdapterConfig)] = []

        for serviceType in SyncServiceType.allCases {
            guard configStore.isEnabled(serviceType),
                  let config = configStore.config(for: serviceType),
                  let adapter = adapterMap[serviceType] else {
                continue
            }

            // 历史数据过滤：仅同步 timestamp > enabledSince 的 Memo
            if let enabledSince = configStore.enabledSince(serviceType),
               payload.timestamp <= enabledSince {
                FileLogger.log("[MemoSync] ⏭️ \(adapter.serviceName): skipped (memo before enabledSince)")
                continue
            }

            tasks.append((serviceType, adapter, config))
        }

        guard !tasks.isEmpty else {
            FileLogger.log("[MemoSync] No enabled adapters, skipping sync")
            return
        }

        let contentPreview = String(payload.content.prefix(30))
        FileLogger.log("[MemoSync] Dispatching to \(tasks.count) adapter(s): \"\(contentPreview)...\"")

        var successCount = 0
        var failureCount = 0

        await withTaskGroup(of: (String, SyncServiceType, SyncResult).self) { group in
            for (serviceType, adapter, config) in tasks {
                group.addTask {
                    let result = await adapter.sync(memo: payload, config: config)
                    return (adapter.serviceName, serviceType, result)
                }
            }

            for await (serviceName, serviceType, result) in group {
                // 缓存详细同步结果
                if self.syncResultCache[payload.memoId] == nil {
                    self.syncResultCache[payload.memoId] = [:]
                }
                self.syncResultCache[payload.memoId]?[serviceType] = result

                // 统计成功/失败
                switch result {
                case .success:
                    successCount += 1
                    FileLogger.log("[MemoSync] ✅ \(serviceName): synced \"\(contentPreview)...\"")
                case .failure(let error):
                    failureCount += 1
                    FileLogger.log("[MemoSync] ❌ \(serviceName): \(error)")
                }
            }
        }

        // 计算综合同步状态并缓存（按 timestamp 索引，供 MemoCard 查询）
        let status: SyncStatus
        if failureCount == 0 {
            status = .synced
        } else if successCount == 0 {
            status = .failed
        } else {
            status = .partialFail
        }

        await MainActor.run {
            self.syncStatusCache[payload.timestamp] = status
            // 同步全部成功时，更新 Overlay 提示（仅在 Overlay 仍显示 memoSaved 时生效）
            if status == .synced {
                OverlayStateManager.shared.setMemoSavedAndSynced()
            }
        }
    }
}
