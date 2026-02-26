//
//  NotionAdapter.swift
//  AIInputMethod
//
//  Notion 同步适配器，通过 Notion Internal Integration API 同步笔记
//  Token 通过 KeychainHelper 存取，API 请求通过 NotionRateLimiter 串行排队
//  Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 13.1, 13.2, 13.3
//  Properties: 5 (Notion HTTP 错误码映射), 6 (Token Keychain 存取往返)
//

import Foundation

// MARK: - NotionAdapter

class NotionAdapter: MemoSyncService {

    var serviceName: String { "Notion" }

    /// Keychain 存储 key
    static let tokenKeychainKey = "memoSync.notion.token"

    /// Notion API 版本
    private let apiVersion = "2022-06-28"

    /// Notion API base URL
    private let baseURL = "https://api.notion.com/v1"

    /// URL session
    private let session: URLSession

    /// Rate limiter
    private let rateLimiter: NotionRateLimiter

    init(session: URLSession = .shared, rateLimiter: NotionRateLimiter = .shared) {
        self.session = session
        self.rateLimiter = rateLimiter
    }

    // MARK: - Sync

    func sync(memo: MemoSyncPayload, config: SyncAdapterConfig) async -> SyncResult {
        // 1. 获取 Token
        guard let token = KeychainHelper.get(key: NotionAdapter.tokenKeychainKey) else {
            FileLogger.log("[MemoSync] ❌ Notion: no token found in Keychain")
            return .failure(.notionUnauthorized)
        }

        // 2. 获取 database ID
        guard let databaseId = config.notionDatabaseId, !databaseId.isEmpty else {
            FileLogger.log("[MemoSync] ❌ Notion: no database ID configured")
            return .failure(.notionDatabaseNotFound)
        }

        // 3. 生成标题
        let template = config.titleTemplate.isEmpty
            ? TitleTemplateEngine.defaultTemplate
            : config.titleTemplate
        let title = TitleTemplateEngine.resolve(
            template: template,
            date: memo.timestamp,
            groupingMode: config.groupingMode
        )

        // 4. 格式化内容（返回 paragraph block JSON 字符串）
        let formattedContent = MemoContentFormatter.format(
            content: memo.content,
            timestamp: memo.timestamp,
            target: .notion
        )

        // 5. 根据分组模式决定创建新 Page 还是追加 Block
        let shouldAppend = config.groupingMode == .perDay || config.groupingMode == .perWeek

        if shouldAppend {
            // 按标题查找已有 Page
            let searchResult = await searchPageByTitle(title, databaseId: databaseId, token: token)
            switch searchResult {
            case .success(let pageId):
                if let pageId = pageId {
                    // 找到已有 Page，追加 Block
                    let appendResult = await appendBlocks(to: pageId, content: formattedContent, token: token)
                    switch appendResult {
                    case .success:
                        FileLogger.log("[MemoSync] ✅ Notion: appended to \"\(title)\"")
                        return .success
                    case .failure(let error):
                        return .failure(error)
                    }
                } else {
                    // 未找到，新建 Page
                    let createResult = await createPage(
                        title: title,
                        content: formattedContent,
                        databaseId: databaseId,
                        token: token
                    )
                    switch createResult {
                    case .success:
                        FileLogger.log("[MemoSync] ✅ Notion: created \"\(title)\"")
                        return .success
                    case .failure(let error):
                        return .failure(error)
                    }
                }
            case .failure(let error):
                return .failure(error)
            }
        } else {
            // perNote 模式：直接新建 Page
            let createResult = await createPage(
                title: title,
                content: formattedContent,
                databaseId: databaseId,
                token: token
            )
            switch createResult {
            case .success:
                FileLogger.log("[MemoSync] ✅ Notion: created \"\(title)\"")
                return .success
            case .failure(let error):
                return .failure(error)
            }
        }
    }

    // MARK: - Validate Connection

    func validateConnection(config: SyncAdapterConfig) async -> SyncResult {
        guard let token = KeychainHelper.get(key: NotionAdapter.tokenKeychainKey) else {
            return .failure(.notionUnauthorized)
        }

        guard let databaseId = config.notionDatabaseId, !databaseId.isEmpty else {
            return .failure(.notionDatabaseNotFound)
        }

        // 用 Search API 验证 Token 和数据库访问权限
        let url = URL(string: "\(baseURL)/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "filter": ["property": "object", "value": "database"],
            "page_size": 1
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let result: (Data, URLResponse) = try await rateLimiter.execute {
                try await self.session.data(for: request)
            }
            let response = result.1
            return mapHTTPResponse(response, data: result.0)
        } catch let error as NotionRateLimitError {
            return .failure(.notionRateLimited(retryAfter: error.retryAfter))
        } catch {
            FileLogger.log("[MemoSync] ❌ Notion: validate connection failed - \(error.localizedDescription)")
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - Private: API Operations

    /// 通过 Search API 按标题查找数据库中的 Page
    /// 返回 pageId（找到）或 nil（未找到）
    private func searchPageByTitle(
        _ title: String,
        databaseId: String,
        token: String
    ) async -> Result<String?, SyncError> {
        let url = URL(string: "\(baseURL)/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": title,
            "filter": ["property": "object", "value": "page"],
            "page_size": 10
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let result: (Data, URLResponse) = try await rateLimiter.execute {
                try await self.session.data(for: request)
            }
            let data = result.0
            let response = result.1

            // 检查 HTTP 状态码
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let error = mapHTTPStatusToError(httpResponse.statusCode, data: data, response: httpResponse)
                return .failure(error)
            }

            // 解析搜索结果，匹配标题和数据库
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                return .success(nil)
            }

            // 遍历结果，找到标题完全匹配且属于目标数据库的 Page
            for page in results {
                guard let pageParent = page["parent"] as? [String: Any],
                      let parentDatabaseId = pageParent["database_id"] as? String,
                      normalizeId(parentDatabaseId) == normalizeId(databaseId) else {
                    continue
                }

                // 检查标题匹配
                guard let properties = page["properties"] as? [String: Any] else { continue }

                // Notion 的标题字段名可能是 "Name" 或 "title" 等，遍历查找 title 类型
                for (_, propValue) in properties {
                    guard let prop = propValue as? [String: Any],
                          let propType = prop["type"] as? String,
                          propType == "title",
                          let titleArray = prop["title"] as? [[String: Any]] else {
                        continue
                    }

                    let pageTitle = titleArray.compactMap { $0["plain_text"] as? String }.joined()
                    if pageTitle == title, let pageId = page["id"] as? String {
                        return .success(pageId)
                    }
                }
            }

            return .success(nil)
        } catch let error as NotionRateLimitError {
            return .failure(.notionRateLimited(retryAfter: error.retryAfter))
        } catch {
            FileLogger.log("[MemoSync] ❌ Notion: search failed - \(error.localizedDescription)")
            return .failure(.networkError(error.localizedDescription))
        }
    }

    /// 创建新 Page
    private func createPage(
        title: String,
        content: String,
        databaseId: String,
        token: String
    ) async -> Result<Void, SyncError> {
        let url = URL(string: "\(baseURL)/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 构建请求体：parent + properties (title) + children (content block)
        var body: [String: Any] = [
            "parent": ["database_id": databaseId],
            "properties": [
                "title": [
                    "title": [
                        ["type": "text", "text": ["content": title]]
                    ]
                ]
            ]
        ]

        // 解析 content JSON 字符串为 block 对象
        if let blockData = content.data(using: .utf8),
           let block = try? JSONSerialization.jsonObject(with: blockData) as? [String: Any] {
            body["children"] = [block]
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let result: (Data, URLResponse) = try await rateLimiter.execute {
                try await self.session.data(for: request)
            }
            let response = result.1

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let error = mapHTTPStatusToError(httpResponse.statusCode, data: result.0, response: httpResponse)
                return .failure(error)
            }

            return .success(())
        } catch let error as NotionRateLimitError {
            return .failure(.notionRateLimited(retryAfter: error.retryAfter))
        } catch {
            FileLogger.log("[MemoSync] ❌ Notion: create page failed - \(error.localizedDescription)")
            return .failure(.networkError(error.localizedDescription))
        }
    }

    /// 向已有 Page 追加 Block
    private func appendBlocks(
        to pageId: String,
        content: String,
        token: String
    ) async -> Result<Void, SyncError> {
        let url = URL(string: "\(baseURL)/blocks/\(pageId)/children")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 先插入一个空段落作为分隔，再追加内容 block
        var children: [[String: Any]] = []
        // Empty paragraph block as separator
        let emptyBlock: [String: Any] = [
            "object": "block",
            "type": "paragraph",
            "paragraph": ["rich_text": [] as [[String: Any]]]
        ]
        children.append(emptyBlock)
        if let blockData = content.data(using: .utf8),
           let block = try? JSONSerialization.jsonObject(with: blockData) as? [String: Any] {
            children.append(block)
        }

        let body: [String: Any] = ["children": children]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let result: (Data, URLResponse) = try await rateLimiter.execute {
                try await self.session.data(for: request)
            }
            let response = result.1

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let error = mapHTTPStatusToError(httpResponse.statusCode, data: result.0, response: httpResponse)
                return .failure(error)
            }

            return .success(())
        } catch let error as NotionRateLimitError {
            return .failure(.notionRateLimited(retryAfter: error.retryAfter))
        } catch {
            FileLogger.log("[MemoSync] ❌ Notion: append blocks failed - \(error.localizedDescription)")
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - Private: Error Mapping

    /// 将 HTTP 响应映射为 SyncResult（用于 validateConnection）
    private func mapHTTPResponse(_ response: URLResponse, data: Data) -> SyncResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.networkError("Invalid response"))
        }

        switch httpResponse.statusCode {
        case 200:
            return .success
        default:
            let error = mapHTTPStatusToError(httpResponse.statusCode, data: data, response: httpResponse)
            return .failure(error)
        }
    }

    /// 将 HTTP 状态码映射为 SyncError
    /// Property 5: 401→notionUnauthorized, 404→notionDatabaseNotFound, 429→notionRateLimited
    static func mapHTTPStatusToError(_ statusCode: Int, data: Data?, retryAfterHeader: String?) -> SyncError {
        switch statusCode {
        case 401:
            return .notionUnauthorized
        case 404:
            return .notionDatabaseNotFound
        case 429:
            let retryAfter = retryAfterHeader.flatMap { TimeInterval($0) } ?? 1.0
            return .notionRateLimited(retryAfter: retryAfter)
        default:
            let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(statusCode)"
            return .notionApiError(message)
        }
    }

    /// 实例方法版本，从 HTTPURLResponse 提取 Retry-After
    private func mapHTTPStatusToError(_ statusCode: Int, data: Data, response: HTTPURLResponse) -> SyncError {
        let retryAfterHeader = response.value(forHTTPHeaderField: "Retry-After")

        // 429 时抛出 NotionRateLimitError 让 RateLimiter 处理重试
        if statusCode == 429 {
            let retryAfter = retryAfterHeader.flatMap { TimeInterval($0) } ?? 1.0
            FileLogger.log("[MemoSync] ⚠️ Notion: rate limited (429), Retry-After: \(retryAfter)s")
            return .notionRateLimited(retryAfter: retryAfter)
        }

        return NotionAdapter.mapHTTPStatusToError(statusCode, data: data, retryAfterHeader: retryAfterHeader)
    }

    /// 标准化 Notion ID（移除连字符以便比较）
    private func normalizeId(_ id: String) -> String {
        id.replacingOccurrences(of: "-", with: "")
    }
}
