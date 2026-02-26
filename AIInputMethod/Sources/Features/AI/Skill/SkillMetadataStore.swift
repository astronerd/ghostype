import Foundation
import Observation

// MARK: - Skill Metadata

struct SkillMetadata: Codable, Equatable {
    var icon: String
    var colorHex: String
    var modifierKey: ModifierKeyBinding?
    var isBuiltin: Bool
    var isInternal: Bool

    static let defaultIcon = "✨"
    static let defaultColorHex = "#5AC8FA"

    static var `default`: SkillMetadata {
        SkillMetadata(
            icon: defaultIcon,
            colorHex: defaultColorHex,
            modifierKey: nil,
            isBuiltin: false,
            isInternal: false
        )
    }

    // 自定义解码：isInternal 在旧版 JSON 中不存在，默认 false
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        icon = try container.decode(String.self, forKey: .icon)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        modifierKey = try container.decodeIfPresent(ModifierKeyBinding.self, forKey: .modifierKey)
        isBuiltin = try container.decode(Bool.self, forKey: .isBuiltin)
        isInternal = try container.decodeIfPresent(Bool.self, forKey: .isInternal) ?? false
    }

    init(icon: String, colorHex: String, modifierKey: ModifierKeyBinding?, isBuiltin: Bool, isInternal: Bool = false) {
        self.icon = icon
        self.colorHex = colorHex
        self.modifierKey = modifierKey
        self.isBuiltin = isBuiltin
        self.isInternal = isInternal
    }
}

// MARK: - Skill Metadata Store

@Observable
class SkillMetadataStore {

    private var metadata: [String: SkillMetadata] = [:]
    private let storageURL: URL

    // MARK: - Init

    /// Initialize with a custom storage URL (useful for testing).
    /// Defaults to ~/Library/Application Support/GHOSTYPE/skill_metadata.json
    init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.storageURL = appSupport
                .appendingPathComponent("GHOSTYPE")
                .appendingPathComponent("skill_metadata.json")
        }
    }

    // MARK: - CRUD

    /// Get metadata for a skill. Returns default values if not found.
    func get(skillId: String) -> SkillMetadata {
        metadata[skillId] ?? .default
    }

    /// Update metadata for a skill.
    func update(skillId: String, metadata: SkillMetadata) {
        self.metadata[skillId] = metadata
        save()
    }

    /// Remove metadata for a skill.
    func remove(skillId: String) {
        self.metadata.removeValue(forKey: skillId)
        save()
    }

    /// All stored skill IDs.
    var allSkillIds: [String] {
        Array(metadata.keys)
    }

    // MARK: - Persistence

    /// Load metadata from disk. Resets to empty on failure.
    func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storageURL.path) else {
            FileLogger.log("[MetadataStore] No metadata file found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([String: SkillMetadata].self, from: data)
            self.metadata = decoded
            FileLogger.log("[MetadataStore] Loaded \(decoded.count) skill metadata entries")
        } catch {
            FileLogger.log("[MetadataStore] ⚠️ Failed to load metadata, resetting: \(error.localizedDescription)")
            self.metadata = [:]
        }
    }

    /// Save metadata to disk.
    func save() {
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            FileLogger.log("[MetadataStore] ⚠️ Failed to save metadata: \(error.localizedDescription)")
        }
    }

    // MARK: - Legacy Import

    /// Import UI metadata from legacy SKILL.md fields into the store.
    func importLegacy(skillId: String, legacy: SkillFileParser.LegacyFields) {
        var meta = metadata[skillId] ?? .default

        if let icon = legacy.icon {
            meta.icon = icon
        }
        if let colorHex = legacy.colorHex {
            meta.colorHex = colorHex
        }
        if let isBuiltin = legacy.isBuiltin {
            meta.isBuiltin = isBuiltin
        }

        // Build ModifierKeyBinding if all required fields are present
        if let keyCode = legacy.modifierKeyCode,
           let isSystem = legacy.modifierKeyIsSystem,
           let display = legacy.modifierKeyDisplay {
            meta.modifierKey = ModifierKeyBinding(
                keyCode: keyCode,
                isSystemModifier: isSystem,
                displayName: display
            )
        }

        metadata[skillId] = meta
    }
}
