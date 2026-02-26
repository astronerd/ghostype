//
//  MemoSyncModels.swift
//  AIInputMethod
//
//  Quick Memo 同步功能的数据模型与枚举定义
//  Validates: Requirements 1, 2, 6
//

import Foundation

// MARK: - SyncServiceType

/// 支持的同步目标服务类型
enum SyncServiceType: String, Codable, CaseIterable {
    case obsidian
    case appleNotes
    case notion
    case bear
}

// MARK: - GroupingMode

/// 笔记分组模式，决定多条 Memo 如何组织到目标笔记中
enum GroupingMode: String, Codable {
    case perNote    // 每条单独
    case perDay     // 按天
    case perWeek    // 按周
}

// MARK: - SyncAdapterConfig

/// 同步适配器配置，每个笔记应用独立存储
/// 通过 UserDefaults + Codable 持久化，新增字段设为 Optional 保证升级兼容
struct SyncAdapterConfig: Codable, Equatable {
    var groupingMode: GroupingMode
    var titleTemplate: String           // 默认 "GHOSTYPE Memo {date}"

    // Obsidian 专用
    var obsidianVaultBookmark: Data?    // security-scoped bookmark

    // Apple Notes 专用
    var appleNotesFolderName: String?   // 默认 "GHOSTYPE"

    // Notion 专用（Token 存 Keychain，不在此处）
    var notionDatabaseId: String?

    // Bear 专用
    var bearDefaultTag: String?         // 默认标签
}

// MARK: - MemoSyncPayload

/// 待同步的 Memo 数据载荷
struct MemoSyncPayload {
    let content: String
    let timestamp: Date
    let memoId: UUID
}

// MARK: - SyncResult

/// 同步操作结果
enum SyncResult {
    case success
    case failure(SyncError)
}

// MARK: - SyncError

/// 同步错误类型，覆盖所有适配器可能的错误场景
enum SyncError: Error {
    case pathNotFound(String)
    case noWritePermission(String)
    case bookmarkExpired
    case appleScriptError(String)
    case notionUnauthorized
    case notionDatabaseNotFound
    case notionRateLimited(retryAfter: TimeInterval)
    case notionApiError(String)
    case bearNotInstalled
    case networkError(String)
    case unknown(String)
}
