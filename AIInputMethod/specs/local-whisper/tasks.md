# Implementation Plan — 本地 Whisper ASR 支持

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 GHOSTYPE 中引入本地 Whisper 作为可选 ASR 引擎，通过 SpeechServiceProtocol 对 VoiceInputCoordinator 透明，支持模型下载管理和参数配置。

**Architecture:** SpeechServiceProtocol 抽象层 → WhisperSpeechService（批量推理）→ WhisperModelManager（下载/删除）→ PreferencesPage 新增设置区。

**Tech Stack:** Swift 5.9+, WhisperKit (SPM), AVFoundation, CoreML, SwiftUI

---

## Tasks

- [ ] 1. 添加 WhisperKit 依赖

  - [ ] 1.1 修改 `Package.swift`
    - 在 `dependencies: []` 中添加：
      ```swift
      .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0")
      ```
    - 在 `executableTarget` 的 `dependencies` 中添加：
      ```swift
      .product(name: "WhisperKit", package: "WhisperKit")
      ```
    - 在 `testTarget` 的 `dependencies` 中同样添加（测试需要 mock）
    - 运行 `swift package resolve` 确认下载成功
    - _Requirements: 2_

  - [ ] 1.2 验证编译
    - 运行 `swift build 2>&1 | grep -E "error:|Build complete"`
    - 期望：`Build complete!`

---

- [ ] 2. SpeechServiceProtocol 抽象层

  - [ ] 2.1 创建 `Sources/Features/Speech/SpeechServiceProtocol.swift`
    ```swift
    import Foundation

    protocol SpeechServiceProtocol: AnyObject {
        var onFinalResult: ((String) -> Void)? { get set }
        var onPartialResult: ((String) -> Void)? { get set }
        func startRecording()
        func stopRecording()
        func cancelRecording()
    }
    ```
    _Requirements: 1.1_

  - [ ] 2.2 让 `DoubaoSpeechService` 遵守协议
    - 文件：`Sources/Features/Speech/DoubaoSpeechService.swift`
    - 在 `class DoubaoSpeechService` 后加 `: SpeechServiceProtocol`
    - 添加 `cancelRecording()` 方法（实现与 `stopRecording()` 相同）：
      ```swift
      func cancelRecording() {
          stopRecording()
      }
      ```
    - _Requirements: 1.2_

  - [ ] 2.3 修改 `VoiceInputCoordinator` 使用协议类型
    - 文件：`Sources/Features/VoiceInput/VoiceInputCoordinator.swift`
    - `let speechService: DoubaoSpeechService` → `var speechService: any SpeechServiceProtocol`
    - init 参数类型同步改为 `any SpeechServiceProtocol`
    - `handleEscCancel()` 中 `speechService.stopRecording()` → `speechService.cancelRecording()`
    - 将 `fetchCredentials` 调用（行 ~99）改为：
      ```swift
      if let doubao = speechService as? DoubaoSpeechService {
          Task { try? await doubao.fetchCredentials() }
      }
      ```
    - 添加 `updateSpeechService(_ newService: any SpeechServiceProtocol)` 方法：
      ```swift
      func updateSpeechService(_ newService: any SpeechServiceProtocol) {
          guard case .idle = recordingState else {
              FileLogger.log("[VIC] ⚠️ Cannot switch engine while recording")
              return
          }
          speechService = newService
          setupSpeechCallbacks()
      }
      ```
    - _Requirements: 1.3, 1.4_

  - [ ] 2.4 修改 `AppDelegate` 中的类型引用
    - 文件：`Sources/AIInputMethodApp.swift`
    - `var speechService = DoubaoSpeechService()` 保持（具体类型初始化没问题）
    - `VoiceInputCoordinator` init 调用中 `speechService: speechService` 不变（类型推断）
    - 检查 `bootstrapInputServices` 中是否有直接引用 `DoubaoSpeechService` 类型的地方，如有则改为协议类型

  - [ ] 2.5 编译验证
    - `swift build 2>&1 | grep -E "error:|Build complete"`
    - 期望：`Build complete!`

  - [ ] 2.6 编写协议透明性测试（Property 1）
    - 创建 `Tests/SpeechServiceProtocolTests.swift`
    - 实现 `MockSpeechService: SpeechServiceProtocol`（记录调用次数）
    - 测试：用 `MockSpeechService` 替换后，PTT down → PTT up → `onFinalResult` 被调用一次
    - 测试：`cancelRecording()` 被调用后，注入 `onFinalResult` 不触发处理
    - `swift test --filter SpeechServiceProtocolTests`
    - 期望：PASS
    - _Requirements: 1.1, 1.3_

  - [ ] 2.7 提交
    ```
    git add Sources/Features/Speech/SpeechServiceProtocol.swift \
            Sources/Features/Speech/DoubaoSpeechService.swift \
            Sources/Features/VoiceInput/VoiceInputCoordinator.swift \
            Sources/AIInputMethodApp.swift \
            Tests/SpeechServiceProtocolTests.swift
    git commit -m "refactor: introduce SpeechServiceProtocol, decouple VoiceInputCoordinator from DoubaoSpeechService"
    ```

---

- [ ] 3. AppSettings 新增 ASR 相关设置

  - [ ] 3.1 在 `Sources/Features/Settings/AppSettings.swift` 新增

    在文件顶部（`SendMethod` 枚举附近）添加：
    ```swift
    enum ASREngine: String, CaseIterable {
        case doubao = "whisper"  // 注意：raw value 用于 UserDefaults
        case doubao = "doubao"
        case whisper = "whisper"
    }
    ```
    > **注意**：正确写法如下：
    ```swift
    enum ASREngine: String, CaseIterable {
        case doubao = "doubao"
        case whisper = "whisper"
    }
    ```

    在 `AppSettings` class 属性区添加：
    ```swift
    // MARK: - ASR 引擎设置
    @Published var asrEngine: ASREngine {
        didSet { debouncedSave() }
    }
    @Published var whisperModelId: String {
        didSet { debouncedSave() }
    }
    @Published var whisperLanguage: String {
        didSet { debouncedSave() }
    }
    @Published var whisperTemperature: Double {
        didSet { debouncedSave() }
    }
    ```

    在 `Keys` enum 添加：
    ```swift
    static let asrEngine = "asrEngine"
    static let whisperModelId = "whisperModelId"
    static let whisperLanguage = "whisperLanguage"
    static let whisperTemperature = "whisperTemperature"
    ```

    在 `init()` 加载逻辑中添加：
    ```swift
    if let raw = defaults.string(forKey: Keys.asrEngine),
       let engine = ASREngine(rawValue: raw) {
        asrEngine = engine
    } else {
        asrEngine = .doubao
    }
    whisperModelId = defaults.string(forKey: Keys.whisperModelId) ?? "openai_whisper-small"
    whisperLanguage = defaults.string(forKey: Keys.whisperLanguage) ?? "auto"
    whisperTemperature = defaults.object(forKey: Keys.whisperTemperature) as? Double ?? 0.0
    ```

    在 `saveToUserDefaults()` 末尾添加：
    ```swift
    defaults.set(asrEngine.rawValue, forKey: Keys.asrEngine)
    defaults.set(whisperModelId, forKey: Keys.whisperModelId)
    defaults.set(whisperLanguage, forKey: Keys.whisperLanguage)
    defaults.set(whisperTemperature, forKey: Keys.whisperTemperature)
    ```
    _Requirements: 4.6_

  - [ ] 3.2 编译验证
    - `swift build 2>&1 | grep -E "error:|Build complete"`

  - [ ] 3.3 提交
    ```
    git add Sources/Features/Settings/AppSettings.swift
    git commit -m "feat: add ASR engine settings to AppSettings (asrEngine, whisperModelId, whisperLanguage, whisperTemperature)"
    ```

---

- [ ] 4. WhisperModelManager

  - [ ] 4.1 创建 `Sources/Features/Speech/WhisperModelManager.swift`

    实现以下完整内容：
    ```swift
    import Foundation
    import WhisperKit
    import Observation

    struct WhisperModelInfo: Identifiable {
        let id: String
        let displayName: String
        let sizeEstimate: String
        let qualityNote: String
    }

    enum ModelDownloadStatus: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case error(String)
    }

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

                    // WhisperKit.download 支持 modelFolder 参数和 progressCallback
                    let _ = try await WhisperKit.download(
                        variant: modelId,
                        downloadBase: modelsDirectory.path,
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
    ```
    _Requirements: 3.1–3.8_

  - [ ] 4.2 编译验证
    - `swift build 2>&1 | grep -E "error:|Build complete"`

  - [ ] 4.3 编写 `WhisperModelManager` 测试（Property 4）
    - 创建 `Tests/WhisperModelManagerTests.swift`
    - 测试：创建临时目录，`refreshStatuses()` 后 `isDownloaded` 返回 false
    - 测试：创建模型目录后 `refreshStatuses()`，`isDownloaded` 返回 true（Property 4）
    - 测试：`delete()` 后 status 变为 `.notDownloaded`
    - `swift test --filter WhisperModelManagerTests`
    - 期望：PASS
    - _Requirements: 3.5, 3.7_

  - [ ] 4.4 提交
    ```
    git add Sources/Features/Speech/WhisperModelManager.swift \
            Tests/WhisperModelManagerTests.swift
    git commit -m "feat: WhisperModelManager - model download/delete/status tracking"
    ```

---

- [ ] 5. WhisperSpeechService

  - [ ] 5.1 创建 `Sources/Features/Speech/WhisperSpeechService.swift`

    ```swift
    import Foundation
    import AVFoundation
    import WhisperKit

    final class WhisperSpeechService: SpeechServiceProtocol {
        var onFinalResult: ((String) -> Void)?
        var onPartialResult: ((String) -> Void)?

        private let modelId: String
        private let language: String      // "auto"/"zh"/"en"/"ja", nil → auto
        private let temperature: Float

        private var whisperKit: WhisperKit?
        private var audioEngine: AVAudioEngine?
        private var audioBuffer: [Float] = []
        private var isRecording = false
        private var isCancelled = false
        private var inferenceTask: Task<Void, Never>?

        private let targetSampleRate: Double = 16000
        private var audioConverter: AVAudioConverter?

        init(modelId: String, language: String = "auto", temperature: Float = 0.0) {
            self.modelId = modelId
            self.language = language
            self.temperature = temperature
        }

        // MARK: - Preload

        func preload() async throws {
            let folder = WhisperModelManager.shared.modelFolder(for: modelId).path
            guard FileManager.default.fileExists(atPath: folder) else {
                FileLogger.log("[Whisper] ⚠️ Model not downloaded: \(modelId)")
                return
            }
            FileLogger.log("[Whisper] Loading model: \(modelId)")
            whisperKit = try await WhisperKit(modelFolder: folder)
            FileLogger.log("[Whisper] ✅ Model loaded: \(modelId)")
        }

        // MARK: - SpeechServiceProtocol

        func startRecording() {
            guard !isRecording else { return }
            isCancelled = false
            audioBuffer = []
            audioConverter = nil

            let engine = AVAudioEngine()
            audioEngine = engine
            let inputNode = engine.inputNode
            let recordFormat = inputNode.outputFormat(forBus: 0)

            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            ) else {
                FileLogger.log("[Whisper] ❌ Failed to create target audio format")
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
                guard let self else { return }
                self.processTapBuffer(buffer, targetFormat: targetFormat)
            }

            do {
                try engine.start()
                isRecording = true
                FileLogger.log("[Whisper] 🎙 Recording started")
            } catch {
                FileLogger.log("[Whisper] ❌ Failed to start engine: \(error)")
            }
        }

        func stopRecording() {
            guard isRecording else { return }
            stopEngine()
            guard !isCancelled else { return }

            let bufferCopy = audioBuffer
            inferenceTask = Task { [weak self] in
                await self?.transcribe(buffer: bufferCopy)
            }
        }

        func cancelRecording() {
            isCancelled = true
            inferenceTask?.cancel()
            stopEngine()
            audioBuffer = []
            FileLogger.log("[Whisper] ⏹ Recording cancelled")
        }

        // MARK: - Private

        private func stopEngine() {
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            audioEngine = nil
            audioConverter = nil
            isRecording = false
        }

        private func processTapBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
            // 复用 converter，仅格式变化时重建
            if audioConverter == nil || audioConverter?.inputFormat != buffer.format {
                audioConverter = AVAudioConverter(from: buffer.format, to: targetFormat)
            }
            guard let converter = audioConverter else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate
            )
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCount
            ) else { return }

            var error: NSError?
            converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            if error != nil { return }

            if let channelData = outputBuffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
                audioBuffer.append(contentsOf: samples)
            }
        }

        private func transcribe(buffer: [Float]) async {
            // 最短录音检查：< 0.3s（4800 帧 @ 16kHz）
            guard buffer.count >= 4800 else {
                FileLogger.log("[Whisper] ⚠️ Buffer too short (\(buffer.count) frames), skipping")
                await MainActor.run { onFinalResult?("") }
                return
            }

            guard let whisperKit else {
                FileLogger.log("[Whisper] ⚠️ Model not loaded, returning empty")
                await MainActor.run { onFinalResult?("") }
                return
            }

            FileLogger.log("[Whisper] 🔄 Transcribing \(buffer.count) frames...")

            let langOpt: String? = language == "auto" ? nil : language
            let options = DecodingOptions(
                language: langOpt,
                temperature: temperature,
                temperatureFallbackCount: 0
            )

            do {
                let results = try await whisperKit.transcribe(audioArray: buffer, decodeOptions: options)
                let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
                FileLogger.log("[Whisper] ✅ Result: \(text.prefix(80))")
                await MainActor.run { onFinalResult?(text) }
            } catch {
                FileLogger.log("[Whisper] ❌ Transcription error: \(error)")
                await MainActor.run { onFinalResult?("") }
            }
        }
    }
    ```
    _Requirements: 2.1–2.7_

  - [ ] 5.2 编译验证
    - `swift build 2>&1 | grep -E "error:|Build complete"`

  - [ ] 5.3 编写 `WhisperSpeechService` 测试（Property 2, 3）
    - 创建 `Tests/WhisperSpeechServiceTests.swift`
    - **Property 2 测试**：调用 `cancelRecording()` 后，`onFinalResult` 绝不被调用
      - 创建 service，`startRecording()`，立刻 `cancelRecording()`，等待 1s，断言 `onFinalResult` 未被调用
    - **Property 3 测试**：buffer 为空时 `transcribe` 调用 `onFinalResult("")`
      - 直接调用 service 的内部 `transcribe(buffer: [])` 或通过 `stopRecording()` 触发空 buffer
      - 断言 `onFinalResult` 收到 `""`
    - `swift test --filter WhisperSpeechServiceTests`
    - 期望：PASS
    - _Requirements: 2.3, 2.7_

  - [ ] 5.4 提交
    ```
    git add Sources/Features/Speech/WhisperSpeechService.swift \
            Tests/WhisperSpeechServiceTests.swift
    git commit -m "feat: WhisperSpeechService - local Whisper ASR via WhisperKit (batch PTT mode)"
    ```

---

- [ ] 6. Checkpoint 1 — 后端逻辑验证
  - `swift test 2>&1 | tail -10`
  - 期望：所有测试通过，无新增失败

---

- [ ] 7. AppBootstrapper 集成引擎切换

  - [ ] 7.1 修改 `Sources/Features/App/AppBootstrapper.swift`

    在 `bootstrapInputServices` 中，在 `voiceCoordinator.setup()` 之前，根据设置创建正确的 speech service。当前 `delegate.speechService` 是 `DoubaoSpeechService`，需要有条件地替换：

    ```swift
    private func bootstrapInputServices(delegate: AppDelegate) {
        // 根据设置选择 ASR 引擎
        if AppSettings.shared.asrEngine == .whisper {
            let svc = WhisperSpeechService(
                modelId: AppSettings.shared.whisperModelId,
                language: AppSettings.shared.whisperLanguage,
                temperature: Float(AppSettings.shared.whisperTemperature)
            )
            // 后台预加载，不阻塞启动
            Task { try? await svc.preload() }
            delegate.voiceCoordinator.updateSpeechService(svc)
        }
        // 豆包引擎：保持 AppDelegate 默认的 speechService

        delegate.focusObserver.startObserving()
        // ... 其余不变
    }
    ```

    在 `bootstrapObservers` 中添加引擎切换订阅：
    ```swift
    // 监听 ASR 引擎变更，热切换（仅在 .idle 时生效）
    AppSettings.shared.$asrEngine
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak delegate] newEngine in
            guard let delegate else { return }
            switch newEngine {
            case .doubao:
                delegate.voiceCoordinator.updateSpeechService(delegate.speechService)
            case .whisper:
                let svc = WhisperSpeechService(
                    modelId: AppSettings.shared.whisperModelId,
                    language: AppSettings.shared.whisperLanguage,
                    temperature: Float(AppSettings.shared.whisperTemperature)
                )
                Task { try? await svc.preload() }
                delegate.voiceCoordinator.updateSpeechService(svc)
            }
        }
        .store(in: &cancellables)
    ```
    _Requirements: 1.4, 2 (preload)_

  - [ ] 7.2 编译验证
    - `swift build 2>&1 | grep -E "error:|Build complete"`

  - [ ] 7.3 提交
    ```
    git add Sources/Features/App/AppBootstrapper.swift
    git commit -m "feat: AppBootstrapper selects ASR engine on startup, subscribes to engine changes"
    ```

---

- [ ] 8. 本地化字符串

  - [ ] 8.1 在 `Sources/Features/Settings/Strings.swift` 添加 `WhisperStrings` protocol 和 `L.Whisper` namespace：
    ```swift
    protocol WhisperStrings {
        var whisperSectionTitle: String { get }
        var whisperEngineLabel: String { get }
        var whisperEngineDoubao: String { get }
        var whisperEngineLocal: String { get }
        var whisperModelLabel: String { get }
        var whisperLanguageLabel: String { get }
        var whisperLanguageAuto: String { get }
        var whisperLanguageZh: String { get }
        var whisperLanguageEn: String { get }
        var whisperLanguageJa: String { get }
        var whisperTemperatureLabel: String { get }
        var whisperDownload: String { get }
        var whisperCancelDownload: String { get }
        var whisperDelete: String { get }
        var whisperDownloaded: String { get }
        var whisperDownloadError: String { get }
        var whisperNoModelWarning: String { get }
        var whisperAppleSiliconTip: String { get }
    }
    ```
    在 `L` enum 添加 `static var Whisper: WhisperStrings { ... }` accessor
    _Requirements: 4_

  - [ ] 8.2 在 `Strings+Chinese.swift` 添加中文实现

  - [ ] 8.3 在 `Strings+English.swift` 添加英文实现

  - [ ] 8.4 编译验证

  - [ ] 8.5 提交
    ```
    git add Sources/Features/Settings/Strings.swift \
            Sources/Features/Settings/Strings+Chinese.swift \
            Sources/Features/Settings/Strings+English.swift
    git commit -m "feat: add Whisper ASR localization strings"
    ```

---

- [ ] 9. PreferencesPage — ASR 设置区 UI

  - [ ] 9.1 在 `Sources/UI/Dashboard/Pages/PreferencesPage.swift` 的 `PreferencesViewModel` 添加属性：
    ```swift
    var asrEngine: ASREngine {
        get { AppSettings.shared.asrEngine }
        set { AppSettings.shared.asrEngine = newValue }
    }
    var whisperModelId: String {
        get { AppSettings.shared.whisperModelId }
        set { AppSettings.shared.whisperModelId = newValue }
    }
    var whisperLanguage: String {
        get { AppSettings.shared.whisperLanguage }
        set { AppSettings.shared.whisperLanguage = newValue }
    }
    var whisperTemperature: Double {
        get { AppSettings.shared.whisperTemperature }
        set { AppSettings.shared.whisperTemperature = newValue }
    }
    ```
    _Requirements: 4_

  - [ ] 9.2 在 `PreferencesPage` 的 `body` 中，`hotkeySettingsSection` 之后插入 `asrSettingsSection`

  - [ ] 9.3 实现 `asrSettingsSection`：

    结构如下：
    - `MinimalSettingsSection(title: L.Whisper.whisperSectionTitle, icon: "waveform.badge.mic")` 包裹
    - Picker 切换引擎（`viewModel.asrEngine`）
    - `if viewModel.asrEngine == .whisper` 展开：
      - 模型列表：`ForEach(WhisperModelManager.supportedModels)` → 每行显示：单选圆圈 + 名称 + 大小 + 质量说明 + 状态（下载按钮 / 进度条 / 已下载 Badge + 删除按钮）
      - 语言 Picker（auto/zh/en/ja）
      - Temperature Slider（0.0–1.0，步长 0.1）
      - Intel Mac 提示（`if !ProcessInfo.processInfo.processorArchitecture.isAppleSilicon` → 用 `ProcessInfo().machineHardwareName` 或 `uname` 判断 arm64）
      - 无已下载模型时的警告 Banner
    - 使用 `@State private var modelManager = WhisperModelManager.shared` 绑定状态
    _Requirements: 3.1–3.8, 4.1–4.7_

  - [ ] 9.4 编译验证
    - `swift build 2>&1 | grep -E "error:|Build complete"`

  - [ ] 9.5 提交
    ```
    git add Sources/UI/Dashboard/Pages/PreferencesPage.swift
    git commit -m "feat: add ASR engine settings section to PreferencesPage (model download, language, temperature)"
    ```

---

- [ ] 10. Checkpoint 2 — 手动 smoke test
  - `bash ghostype.sh debug`
  - 测试清单：
    - [ ] 打开 Dashboard → 设置 → 找到「语音识别引擎」section
    - [ ] 切换到「本地 Whisper」，看到模型列表
    - [ ] 下载 Tiny 模型，进度条显示正常，完成后显示「已下载」
    - [ ] 选中 Tiny 模型，保存
    - [ ] 使用一次语音输入，文字正常上屏
    - [ ] 切回「豆包云端」，语音输入仍正常
    - [ ] ESC 取消，不崩溃
  - 如有 bug，在此 checkpoint 修复后再继续

---

- [ ] 11. 全量测试
  - `swift test 2>&1 | tail -10`
  - 期望：全部测试通过

- [ ] 12. 提交 specs 文件
  ```
  git add specs/
  git commit -m "docs: add local-whisper spec (requirements, design, tasks)"
  ```

---

## Notes

- **实现顺序理由**：协议层先行（Task 2）→ 设置持久化（Task 3）→ 模型管理（Task 4）→ 引擎实现（Task 5）→ 集成（Task 7）→ UI（Task 8-9）。每一层都在前一层编译通过后才开始。
- **WhisperKit API 注意**：`WhisperKit.download` 的签名在各版本略有不同，Task 4 实现时需对照 `0.9.x` 实际 API 调整参数名（`variant`/`model` 等）
- **`@Observable` vs `ObservableObject`**：`WhisperModelManager` 用 `@Observable`（Swift 5.9+），与 `PermissionManager` 保持一致
- **Intel Mac 判断**：用 `uname -m` syscall 或 `ProcessInfo().machineHardwareName`，返回 `"arm64"` 则为 Apple Silicon
- **Task 5.3 测试**：`WhisperSpeechService` 的 `transcribe` 是 `private`，通过 `stopRecording()` 间接测试；或临时暴露为 `internal` for testing
