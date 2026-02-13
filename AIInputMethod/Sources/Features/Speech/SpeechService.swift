import Foundation
import Combine
import AVFoundation
import Speech

protocol SpeechService: ObservableObject {
    var transcript: String { get }
    var isRecording: Bool { get }
    var onFinalResult: ((String) -> Void)? { get set }
    
    func startRecording()
    func stopRecording()
}

// Real Speech Service using Apple's Speech Framework
class AppleSpeechService: SpeechService {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    
    var onFinalResult: ((String) -> Void)?
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var lastTranscript: String = ""
    private var isAuthorized = false
    
    init() {
        // 不在 init 里请求权限，等外部调用
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorized = (status == .authorized)
                completion(self.isAuthorized)
                print("[Speech] Authorization status: \(status.rawValue)")
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Reset previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcript = AppConstants.Speech.listeningSentinel
        } catch {
            print("[Speech] Audio engine start error: \(error)")
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.lastTranscript = result.bestTranscription.formattedString
                    self.transcript = self.lastTranscript
                }
            }
            
            if error != nil {
                print("[Speech] Error: \(error!.localizedDescription)")
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        
        // 等一小段时间让最后的识别结果返回
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let finalText = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalText.isEmpty && finalText != AppConstants.Speech.listeningSentinel {
                self.onFinalResult?(finalText)
            }
            self.transcript = ""
            self.lastTranscript = ""
        }
        
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        isRecording = false
    }
}

// Mock for testing UI without real audio
class MockSpeechService: SpeechService {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    var onFinalResult: ((String) -> Void)?
    
    func startRecording() {
        isRecording = true
        transcript = AppConstants.Speech.listeningSentinel
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.transcript = "这是模拟语音结果"
        }
    }
    
    func stopRecording() {
        isRecording = false
        onFinalResult?("这是模拟语音结果")
        transcript = ""
    }
}
