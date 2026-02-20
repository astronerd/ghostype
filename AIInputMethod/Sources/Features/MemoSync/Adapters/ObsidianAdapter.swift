//
//  ObsidianAdapter.swift
//  AIInputMethod
//
//  Obsidian 同步适配器，通过文件系统写入 Markdown 文件到 Vault 目录
//  使用 security-scoped bookmark 恢复访问权限
//  Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 12.2, 12.3, 12.4
//  Properties: 3 (分组模式决定文件数量), 4 (无效路径返回错误), 17 (目标笔记不存在时自动新建)
//

import Foundation

// MARK: - ObsidianAdapter

class ObsidianAdapter: MemoSyncService {

    var serviceName: String { "Obsidian" }

    // MARK: - Sync

    func sync(memo: MemoSyncPayload, config: SyncAdapterConfig) async -> SyncResult {
        // 1. Resolve bookmark → vault URL
        guard let bookmarkData = config.obsidianVaultBookmark else {
            FileLogger.log("[MemoSync] ❌ Obsidian: no vault bookmark configured")
            return .failure(.bookmarkExpired)
        }

        let resolveResult = resolveBookmark(bookmarkData)
        guard case .success(let vaultURL) = resolveResult else {
            if case .failure(let error) = resolveResult {
                return .failure(error)
            }
            return .failure(.unknown("Failed to resolve bookmark"))
        }

        // 2. Start security-scoped access
        let didStartAccess = vaultURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                vaultURL.stopAccessingSecurityScopedResource()
            }
        }

        // 3. Verify directory exists and is writable
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: vaultURL.path, isDirectory: &isDir), isDir.boolValue else {
            FileLogger.log("[MemoSync] ❌ Obsidian: vault path not found - \(vaultURL.path)")
            return .failure(.pathNotFound(vaultURL.path))
        }

        guard fm.isWritableFile(atPath: vaultURL.path) else {
            FileLogger.log("[MemoSync] ❌ Obsidian: no write permission - \(vaultURL.path)")
            return .failure(.noWritePermission(vaultURL.path))
        }

        // 4. Generate filename via TitleTemplateEngine
        let template = config.titleTemplate.isEmpty
            ? TitleTemplateEngine.defaultTemplate
            : config.titleTemplate
        let filename = TitleTemplateEngine.resolve(
            template: template,
            date: memo.timestamp,
            groupingMode: config.groupingMode
        )
        let fileURL = vaultURL.appendingPathComponent("\(filename).md")

        // 5. Format content
        let formattedContent = MemoContentFormatter.format(
            content: memo.content,
            timestamp: memo.timestamp,
            target: .obsidian
        )

        // 6. Write or append
        do {
            if fm.fileExists(atPath: fileURL.path) {
                // Append to existing file (add blank line separator)
                let existingContent = try String(contentsOf: fileURL, encoding: .utf8)
                let combined = existingContent + "\n" + formattedContent
                try combined.write(to: fileURL, atomically: true, encoding: .utf8)
                FileLogger.log("[MemoSync] ✅ Obsidian: appended to \(filename).md")
            } else {
                // Create new file
                try formattedContent.write(to: fileURL, atomically: true, encoding: .utf8)
                FileLogger.log("[MemoSync] ✅ Obsidian: created \(filename).md")
            }
            return .success
        } catch {
            FileLogger.log("[MemoSync] ❌ Obsidian: write failed - \(error.localizedDescription)")
            return .failure(.noWritePermission(fileURL.path))
        }
    }

    // MARK: - Validate Connection

    func validateConnection(config: SyncAdapterConfig) async -> SyncResult {
        guard let bookmarkData = config.obsidianVaultBookmark else {
            return .failure(.bookmarkExpired)
        }

        let resolveResult = resolveBookmark(bookmarkData)
        guard case .success(let vaultURL) = resolveResult else {
            if case .failure(let error) = resolveResult {
                return .failure(error)
            }
            return .failure(.unknown("Failed to resolve bookmark"))
        }

        let didStartAccess = vaultURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                vaultURL.stopAccessingSecurityScopedResource()
            }
        }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: vaultURL.path, isDirectory: &isDir), isDir.boolValue else {
            return .failure(.pathNotFound(vaultURL.path))
        }

        guard fm.isWritableFile(atPath: vaultURL.path) else {
            return .failure(.noWritePermission(vaultURL.path))
        }

        return .success
    }

    // MARK: - Private

    /// Resolve security-scoped bookmark data to a URL
    private func resolveBookmark(_ data: Data) -> Result<URL, SyncError> {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                FileLogger.log("[MemoSync] ⚠️ Obsidian: bookmark is stale")
                return .failure(.bookmarkExpired)
            }
            return .success(url)
        } catch {
            FileLogger.log("[MemoSync] ❌ Obsidian: bookmark resolve failed - \(error.localizedDescription)")
            return .failure(.bookmarkExpired)
        }
    }
}
