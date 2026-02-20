//
//  BearAdapter.swift
//  AIInputMethod
//
//  Bear 同步适配器，通过 x-callback-url scheme 创建/追加笔记
//  Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5
//  Properties: 7 (Bear URL scheme 构建), 9 (Bear 与 Obsidian 格式一致性)
//

import AppKit
import Foundation

// MARK: - BearAdapter

class BearAdapter: MemoSyncService {

    var serviceName: String { "Bear" }

    /// Bear 的 bundle identifier，用于检测是否安装
    static let bearBundleIdentifier = "net.shinyfrog.bear"

    // MARK: - URL Building (static, accessible for testing)

    /// 构建 Bear x-callback-url
    ///
    /// - Parameters:
    ///   - memo: Memo 数据载荷
    ///   - config: 同步配置
    /// - Returns: 构建好的 URL，或 nil（构建失败时）
    static func buildURL(memo: MemoSyncPayload, config: SyncAdapterConfig) -> URL? {
        let template = config.titleTemplate.isEmpty
            ? TitleTemplateEngine.defaultTemplate
            : config.titleTemplate
        let title = TitleTemplateEngine.resolve(
            template: template,
            date: memo.timestamp,
            groupingMode: config.groupingMode
        )

        let formattedContent = MemoContentFormatter.format(
            content: memo.content,
            timestamp: memo.timestamp,
            target: .bear
        )

        switch config.groupingMode {
        case .perNote:
            return buildCreateURL(title: title, content: formattedContent, tag: config.bearDefaultTag)
        case .perDay, .perWeek:
            return buildAddTextURL(title: title, content: formattedContent, tag: config.bearDefaultTag)
        }
    }

    // MARK: - Sync

    func sync(memo: MemoSyncPayload, config: SyncAdapterConfig) async -> SyncResult {
        // 1. 检测 Bear 是否安装
        guard Self.isBearInstalled() else {
            FileLogger.log("[MemoSync] ❌ Bear: app not installed")
            return .failure(.bearNotInstalled)
        }

        // 2. 构建 URL
        guard let url = Self.buildURL(memo: memo, config: config) else {
            FileLogger.log("[MemoSync] ❌ Bear: failed to build x-callback-url")
            return .failure(.unknown("Failed to build Bear URL"))
        }

        // 3. 打开 URL
        let opened = await MainActor.run {
            NSWorkspace.shared.open(url)
        }

        if opened {
            let preview = String(memo.content.prefix(30))
            FileLogger.log("[MemoSync] ✅ Bear: synced \"\(preview)...\"")
            return .success
        } else {
            FileLogger.log("[MemoSync] ❌ Bear: failed to open x-callback-url")
            return .failure(.unknown("Failed to open Bear URL"))
        }
    }

    // MARK: - Validate Connection

    func validateConnection(config: SyncAdapterConfig) async -> SyncResult {
        if Self.isBearInstalled() {
            return .success
        } else {
            return .failure(.bearNotInstalled)
        }
    }

    // MARK: - Private Helpers

    /// 检测 Bear 是否安装
    static func isBearInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bearBundleIdentifier) != nil
    }

    /// 构建 `bear://x-callback-url/create` URL（perNote 模式）
    private static func buildCreateURL(title: String, content: String, tag: String?) -> URL? {
        var components = URLComponents(string: "bear://x-callback-url/create")
        var queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "text", value: content)
        ]
        if let tag = tag, !tag.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tag))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    /// 构建 `bear://x-callback-url/add-text` URL（perDay/perWeek 模式，通过标题匹配）
    private static func buildAddTextURL(title: String, content: String, tag: String?) -> URL? {
        var components = URLComponents(string: "bear://x-callback-url/add-text")
        var queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "text", value: content),
            URLQueryItem(name: "mode", value: "append")
        ]
        if let tag = tag, !tag.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tag))
        }
        components?.queryItems = queryItems
        return components?.url
    }
}
