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

// MARK: - Model Load State

enum ModelLoadState: Equatable {
    case idle
    case loading(String)   // modelId
    case ready(String)     // modelId
    case failed(String)    // error
}

// MARK: - WhisperModelManager

@Observable
final class WhisperModelManager {
    static let shared = WhisperModelManager()

    /// 模型加载到内存的状态（preload）— AppBootstrapper 写入，UI 读取
    var loadState: ModelLoadState = .idle

    static let supportedModels: [WhisperModelInfo] = [
        .init(id: "openai_whisper-tiny",           displayName: "Tiny",           sizeEstimate: "~150 MB", qualityNote: "速度最快，英文效果好"),
        .init(id: "openai_whisper-small",          displayName: "Small",          sizeEstimate: "~500 MB", qualityNote: "均衡，推荐默认"),
        .init(id: "openai_whisper-medium",         displayName: "Medium",         sizeEstimate: "~1.5 GB", qualityNote: "准确率高，中文更优"),
        .init(id: "openai_whisper-large-v3_turbo", displayName: "Large v3 Turbo", sizeEstimate: "~1.6 GB", qualityNote: "最高质量"),
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
        modelsDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(modelId, isDirectory: true)
    }

    func isDownloaded(_ modelId: String) -> Bool {
        statuses[modelId] == .downloaded
    }

    func refreshStatuses() {
        for model in Self.supportedModels {
            // 只更新非下载中的状态
            if case .downloading = statuses[model.id] { continue }
            statuses[model.id] = isModelComplete(model.id) ? .downloaded : .notDownloaded
        }
    }

    /// 检查模型三大组件（AudioEncoder / MelSpectrogram / TextDecoder）是否都完整下载
    private func isModelComplete(_ modelId: String) -> Bool {
        let folder = modelFolder(for: modelId)
        let fm = FileManager.default
        let required = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc"]
        return required.allSatisfy { component in
            let dir = folder.appendingPathComponent(component)
            // 两种权重格式：coremldata.bin（旧）或 weights/weight.bin（新）
            let legacy = dir.appendingPathComponent("coremldata.bin").path
            let modern = dir.appendingPathComponent("weights/weight.bin").path
            return fm.fileExists(atPath: legacy) || fm.fileExists(atPath: modern)
        }
    }

    /// 根据设置返回下载端点 URL
    private var downloadEndpoint: String {
        switch AppSettings.shared.whisperMirrorEndpoint {
        case "huggingface":
            return "https://huggingface.co"
        default:
            return "https://hf-mirror.com"
        }
    }

    func download(modelId: String) {
        guard downloadTasks[modelId] == nil else { return }
        statuses[modelId] = .downloading(progress: 0)

        let endpoint = downloadEndpoint
        let task = Task { @MainActor in
            do {
                let _ = try await WhisperKit.download(
                    variant: modelId,
                    downloadBase: modelsDirectory,
                    useBackgroundSession: true,
                    endpoint: endpoint,
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
