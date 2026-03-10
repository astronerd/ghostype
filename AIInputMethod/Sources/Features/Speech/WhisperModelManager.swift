import Foundation
import WhisperKit
import Observation

// MARK: - Model Info

struct WhisperModelInfo: Identifiable {
    let id: String
    let displayName: String
    let sizeEstimate: String
    let qualityNote: String
}

// MARK: - Download Status

enum ModelDownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case error(String)
}

// MARK: - WhisperModelManager

@Observable
final class WhisperModelManager {
    static let shared = WhisperModelManager()

    static let supportedModels: [WhisperModelInfo] = [
        .init(id: "openai_whisper-tiny",           displayName: "Tiny",           sizeEstimate: "~150 MB", qualityNote: "速度最快，英文效果好"),
        .init(id: "openai_whisper-small",          displayName: "Small",          sizeEstimate: "~500 MB", qualityNote: "均衡，推荐默认"),
        .init(id: "openai_whisper-medium",         displayName: "Medium",         sizeEstimate: "~1.5 GB", qualityNote: "准确率高，中文更优"),
        .init(id: "openai_whisper-large-v3-turbo", displayName: "Large v3 Turbo", sizeEstimate: "~1.6 GB", qualityNote: "最高质量"),
    ]

    private(set) var statuses: [String: ModelDownloadStatus] = [:]
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("GHOSTYPE/whisper-models", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        refreshStatuses()
    }

    func modelFolder(for modelId: String) -> URL {
        modelsDirectory.appendingPathComponent(modelId, isDirectory: true)
    }

    func isDownloaded(_ modelId: String) -> Bool {
        statuses[modelId] == .downloaded
    }

    func refreshStatuses() {
        for model in Self.supportedModels {
            let folder = modelFolder(for: model.id)
            let exists = FileManager.default.fileExists(atPath: folder.path)
            // 只更新非下载中的状态
            if case .downloading = statuses[model.id] { continue }
            statuses[model.id] = exists ? .downloaded : .notDownloaded
        }
    }

    func download(modelId: String) {
        guard downloadTasks[modelId] == nil else { return }
        statuses[modelId] = .downloading(progress: 0)

        let task = Task { @MainActor in
            do {
                let folder = modelFolder(for: modelId)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

                let _ = try await WhisperKit.download(
                    variant: modelId,
                    downloadBase: modelsDirectory,
                    useBackgroundSession: false,
                    progressCallback: { [weak self] progress in
                        Task { @MainActor in
                            self?.statuses[modelId] = .downloading(progress: progress.fractionCompleted)
                        }
                    }
                )
                statuses[modelId] = .downloaded
                FileLogger.log("[WhisperModelManager] ✅ Downloaded: \(modelId)")
            } catch {
                if Task.isCancelled {
                    statuses[modelId] = .notDownloaded
                } else {
                    statuses[modelId] = .error(error.localizedDescription)
                    FileLogger.log("[WhisperModelManager] ❌ Download failed: \(modelId) — \(error)")
                }
            }
            downloadTasks.removeValue(forKey: modelId)
        }
        downloadTasks[modelId] = task
    }

    func cancelDownload(modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        statuses[modelId] = .notDownloaded
    }

    func delete(modelId: String) throws {
        let folder = modelFolder(for: modelId)
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
        statuses[modelId] = .notDownloaded
        FileLogger.log("[WhisperModelManager] 🗑 Deleted: \(modelId)")
    }
}
