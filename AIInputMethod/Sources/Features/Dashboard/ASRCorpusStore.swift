//
//  ASRCorpusStore.swift
//  AIInputMethod
//
//  ASR 语料收集与管理
//  存储用户语音输入的原始转写文本，标记 consumedAtLevel 表示已被哪个等级的构筑消费
//  Validates: Requirements 8.1, 8.2, 8.3, 8.4
//

import Cocoa
import Foundation

/// ASR 语料条目
/// Validates: Requirements 8.2
struct ASRCorpusEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var consumedAtLevel: Int?   // nil = 未消费
    let appBundleId: String?    // 语料产生时的前台 app bundle ID
    let appName: String?        // 语料产生时的前台 app 名称
}

// MARK: - ASRCorpusStore

/// ASR 语料本地存储
/// Validates: Requirements 8.1, 8.2, 8.3, 8.4
class ASRCorpusStore {

    private let filePath: URL

    /// 默认路径：~/Library/Application Support/GHOSTYPE/ghost_twin/asr_corpus.json
    init(filePath: URL? = nil) {
        if let filePath {
            self.filePath = filePath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.filePath = appSupport
                .appendingPathComponent("GHOSTYPE")
                .appendingPathComponent("ghost_twin")
                .appendingPathComponent("asr_corpus.json")
        }
    }

    /// 加载所有语料，文件不存在或数据损坏时返回空数组
    func loadAll() -> [ASRCorpusEntry] {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ASRCorpusEntry].self, from: data)
        } catch {
            print("[ASRCorpusStore] 加载语料失败，返回空数组: \(error)")
            return []
        }
    }

    /// 新增一条语料（自动记录当前前台 app）
    /// Validates: Requirements 8.1
    func append(text: String, appBundleId: String? = nil, appName: String? = nil) {
        var entries = loadAll()
        // 自动检测前台 app（如果调用方未传入）
        let bundleId = appBundleId ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let name = appName ?? NSWorkspace.shared.frontmostApplication?.localizedName
        let entry = ASRCorpusEntry(
            id: UUID(),
            text: text,
            createdAt: Date(),
            consumedAtLevel: nil,
            appBundleId: bundleId,
            appName: name
        )
        entries.append(entry)
        do {
            try save(entries)
        } catch {
            print("[ASRCorpusStore] 保存语料失败: \(error)")
        }
    }

    /// 返回未消费的语料（consumedAtLevel == nil）
    /// Validates: Requirements 8.3
    func unconsumed() -> [ASRCorpusEntry] {
        loadAll().filter { $0.consumedAtLevel == nil }
    }

    /// 标记指定语料为已消费
    /// Validates: Requirements 8.4
    func markConsumed(ids: [UUID], atLevel: Int) {
        var entries = loadAll()
        let idSet = Set(ids)
        for i in entries.indices {
            if idSet.contains(entries[i].id) {
                entries[i].consumedAtLevel = atLevel
            }
        }
        do {
            try save(entries)
        } catch {
            print("[ASRCorpusStore] 保存语料失败: \(error)")
        }
    }

    /// 保存语料列表，自动创建目录
    func save(_ entries: [ASRCorpusEntry]) throws {
        let directory = filePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: filePath, options: .atomic)
    }
}
