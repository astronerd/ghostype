//
//  NotionRateLimiter.swift
//  AIInputMethod
//
//  Notion API 限流器，使用 Swift Actor 保证串行 FIFO 执行
//  429 响应按 Retry-After 延迟重试
//  Validates: Requirements 13.1, 13.2, 13.3
//  Properties: 15 (Notion 请求 FIFO 顺序)
//

import Foundation

// MARK: - NotionRateLimiter

/// Notion API 限流器
///
/// 使用 Swift Actor 保证线程安全，所有请求按 FIFO 顺序串行执行。
/// 当收到 429 (Too Many Requests) 响应时，按 Retry-After 头延迟后自动重试。
actor NotionRateLimiter {

    /// 单例
    static let shared = NotionRateLimiter()

    /// 最大重试次数，防止无限重试
    private let maxRetries = 3

    /// 串行执行 API 请求
    ///
    /// Actor 天然保证同一时间只有一个任务在执行（FIFO 顺序）。
    /// 如果操作抛出 `NotionRateLimitError`，将按 retryAfter 延迟后重试。
    ///
    /// - Parameter operation: 要执行的异步操作
    /// - Returns: 操作的返回值
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let result = try await operation()
                return result
            } catch let error as NotionRateLimitError {
                lastError = error
                let delay = error.retryAfter > 0 ? error.retryAfter : 1.0
                FileLogger.log("[MemoSync] 🔄 Notion: rate limited, retrying after \(delay)s (attempt \(attempt + 1)/\(maxRetries + 1))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                throw error
            }
        }

        throw lastError ?? NotionRateLimitError(retryAfter: 0)
    }
}

// MARK: - NotionRateLimitError

/// 429 限流错误，携带 Retry-After 值
struct NotionRateLimitError: Error {
    let retryAfter: TimeInterval
}
