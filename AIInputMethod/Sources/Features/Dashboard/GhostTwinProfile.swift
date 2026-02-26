//
//  GhostTwinProfile.swift
//  AIInputMethod
//
//  Ghost Twin 简化人格档案模型
//  人格档案的「形/神/法」三层内容以纯文本 profileText 存储，
//  仅 level、totalXP 等需要程序计算的字段保留为结构化字段。
//  Validates: Requirements 1.1, 1.5, 1.6
//

import Foundation

// MARK: - GhostTwinProfile

/// Ghost Twin 简化人格档案模型
///
/// 设计决策：人格档案的「形/神/法」三层内容均以纯文本字符串 `profileText` 存储。
/// - 该内容仅作为 LLM prompt 注入使用，不需要程序解析其内部结构
/// - LLM 构筑输出的格式可能随 prompt 迭代变化，纯文本更灵活
/// - 仅 `level`、`totalXP` 等需要程序计算的字段保留为结构化字段
///
/// Validates: Requirements 1.1, 1.5, 1.6
struct GhostTwinProfile: Codable, Equatable {

    /// 档案版本号，每次更新 +1
    var version: Int

    /// 当前等级 1~10
    var level: Int

    /// 总经验值
    var totalXP: Int

    /// 一句话人格画像（从 profiling JSON 的 summary 字段提取）
    var summary: String

    /// 人格档案全文（形/神/法三层，纯文本）
    var profileText: String

    /// 创建时间
    var createdAt: Date

    /// 更新时间
    var updatedAt: Date

    // MARK: - Codable 兼容（老数据有 personalityTags 无 summary）

    private enum CodingKeys: String, CodingKey {
        case version, level, totalXP, summary, profileText, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        level = try container.decode(Int.self, forKey: .level)
        totalXP = try container.decode(Int.self, forKey: .totalXP)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        profileText = try container.decode(String.self, forKey: .profileText)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // personalityTags 被忽略（老数据中存在但不再使用）
    }

    // MARK: - Memberwise Init

    init(version: Int, level: Int, totalXP: Int, summary: String, profileText: String, createdAt: Date, updatedAt: Date) {
        self.version = version
        self.level = level
        self.totalXP = totalXP
        self.summary = summary
        self.profileText = profileText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 初始空档案
    /// Validates: Requirements 1.5
    static let initial = GhostTwinProfile(
        version: 0,
        level: 0,
        totalXP: 0,
        summary: "",
        profileText: "",
        createdAt: Date(),
        updatedAt: Date()
    )
}

// MARK: - GhostTwinProfileStore

/// 人格档案持久化管理
/// Validates: Requirements 1.5, 1.6
class GhostTwinProfileStore {
    private let filePath: URL

    /// 默认路径：~/Library/Application Support/GHOSTYPE/ghost_twin/profile.json
    init(filePath: URL? = nil) {
        if let filePath {
            self.filePath = filePath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.filePath = appSupport
                .appendingPathComponent("GHOSTYPE")
                .appendingPathComponent("ghost_twin")
                .appendingPathComponent("profile.json")
        }
    }

    /// 加载人格档案，文件不存在或数据损坏时返回 `.initial`
    func load() -> GhostTwinProfile {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return .initial
        }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(GhostTwinProfile.self, from: data)
        } catch {
            print("[GhostTwinProfileStore] 加载档案失败，返回初始档案: \(error)")
            return .initial
        }
    }

    /// 保存人格档案，自动创建目录
    func save(_ profile: GhostTwinProfile) throws {
        let directory = filePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile)
        try data.write(to: filePath, options: .atomic)
    }
}

