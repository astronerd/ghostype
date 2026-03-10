import Foundation

// MARK: - Speech Service Protocol

/// ASR 引擎抽象协议
/// DoubaoSpeechService 和 WhisperSpeechService 均遵守此协议
/// VoiceInputCoordinator 通过此协议与引擎交互，对引擎实现无感知
protocol SpeechServiceProtocol: AnyObject {
    /// 最终识别结果回调（Doubao: utterance 结束；Whisper: 推理完成）
    var onFinalResult: ((String) -> Void)? { get set }
    /// 中间流式结果回调（Whisper v1 不实现）
    var onPartialResult: ((String) -> Void)? { get set }

    /// 开始录音
    func startRecording()
    /// 停止录音并触发识别（松开快捷键时调用）
    func stopRecording()
    /// 取消录音，丢弃所有已录音频，不触发识别（ESC 时调用）
    func cancelRecording()
}
