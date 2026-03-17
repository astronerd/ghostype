import Foundation
import AVFoundation
import WhisperKit

// MARK: - WhisperSpeechService

final class WhisperSpeechService: SpeechServiceProtocol {
    var onFinalResult: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?

    private let modelId: String
    private let language: String      // "auto"/"zh"/"en"/"ja"
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

    /// 加载模型到内存（App 启动时后台调用）
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
        guard frameCount > 0, let outputBuffer = AVAudioPCMBuffer(
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

        // Lazy load: 模型可能在 preload 后才下载完成
        if whisperKit == nil {
            await MainActor.run { WhisperModelManager.shared.loadState = .loading(modelId) }
            do {
                try await preload()
                await MainActor.run { WhisperModelManager.shared.loadState = .ready(modelId) }
            } catch {
                await MainActor.run { WhisperModelManager.shared.loadState = .failed(error.localizedDescription) }
                FileLogger.log("[Whisper] ❌ Lazy preload failed: \(error)")
            }
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
