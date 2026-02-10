import Foundation
import Combine
import AVFoundation
import Compression
import os.log

// 日志（只打印到控制台，不写文件避免权限问题）
func logToFile(_ message: String) {
    #if DEBUG
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] \(message)")
    #endif
}

// 豆包语音识别服务 - 使用二进制 WebSocket 协议

/// ASR 凭证响应模型
struct ASRCredentialsResponse: Codable {
    let app_id: String
    let access_token: String
}

class DoubaoSpeechService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    
    var onFinalResult: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?  // 流式结果回调
    
    private var audioEngine: AVAudioEngine?
    private var webSocketTask: URLSessionWebSocketTask?
    private var sequenceNumber: Int32 = 1  // 从1开始
    
    private let logger = Logger(subsystem: "com.gengdawei.AIInputMethod", category: "Doubao")
    
    // ASR 凭证缓存（从服务器获取，替代环境变量）
    private var cachedAppId: String = ""
    private var cachedAccessToken: String = ""

    private var appId: String { cachedAppId }
    private var accessToken: String { cachedAccessToken }
    
    // 音频缓冲
    private var audioBuffer = Data()
    private var sendTimer: DispatchSourceTimer?
    
    init() {}
    
    /// 从服务器获取 ASR 凭证，缓存到内存
    func fetchCredentials() async throws {
        let baseURL: String = {
            #if DEBUG
            return "http://localhost:3000"
            #else
            return "https://ghostype.com"
            #endif
        }()
        guard let url = URL(string: "\(baseURL)/api/v1/asr/credentials") else {
            throw GhostypeError.serverError(code: "INVALID_URL", message: "Invalid ASR credentials URL")
        }
        var request = URLRequest(url: url)
        request.setValue(DeviceIdManager.shared.deviceId, forHTTPHeaderField: "X-Device-Id")
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GhostypeError.serverError(code: "ASR_CREDENTIALS_FAILED", message: "Failed to fetch ASR credentials (HTTP \(statusCode))")
        }
        let credentials = try JSONDecoder().decode(ASRCredentialsResponse.self, from: data)
        self.cachedAppId = credentials.app_id
        self.cachedAccessToken = credentials.access_token
        logToFile("[Doubao] ASR credentials cached: appId=\(credentials.app_id.prefix(4))...")
    }
    
    func hasCredentials() -> Bool {
        return !appId.isEmpty && !accessToken.isEmpty
    }
    
    // MARK: - 录音控制
    
    func startRecording() {
        guard !isRecording else { 
            logToFile("[Doubao] Already recording, skipping")
            return 
        }
        guard hasCredentials() else {
            logToFile("[Doubao] No credentials!")
            transcript = "请先配置豆包凭证"
            return
        }
        
        logToFile("[Doubao] ========== START RECORDING ==========")
        logToFile("[Doubao] AppID: \(appId.prefix(4))...")
        
        // 取消之前的关闭任务
        closeWorkItem?.cancel()
        closeWorkItem = nil
        
        sequenceNumber = 1
        audioBuffer = Data()
        isRecording = true
        transcript = "正在听..."
        
        connectWebSocket()
    }
    
    func stopRecording() {
        guard isRecording else { 
            logToFile("[Doubao] Not recording, skipping stop")
            return 
        }
        
        logToFile("[Doubao] ========== STOP RECORDING ==========")
        
        sendTimer?.cancel()
        sendTimer = nil
        
        // 移除 inputNode 上的 tap
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        // 发送最后一包
        sendLastAudioPacket()
        
        isRecording = false
        logToFile("[Doubao] Recording stopped")
    }
    
    // MARK: - WebSocket 连接
    
    private func connectWebSocket() {
        // 使用优化版双向流式模式 - 只在结果变化时返回
        let urlString = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"
        guard let url = URL(string: urlString) else { 
            logToFile("[Doubao] ❌ Invalid URL")
            return 
        }
        
        let requestId = UUID().uuidString
        
        var request = URLRequest(url: url)
        request.setValue(appId, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue("volc.seedasr.sauc.duration", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(requestId, forHTTPHeaderField: "X-Api-Request-Id")
        
        logToFile("[Doubao] ========== CONNECTING ==========")
        logToFile("[Doubao] URL: \(urlString)")
        logToFile("[Doubao] AppID: \(appId)")
        logToFile("[Doubao] Token: \(accessToken.prefix(8))...")
        logToFile("[Doubao] RequestID: \(requestId)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        logToFile("[Doubao] WebSocket task resumed, state: \(String(describing: webSocketTask?.state.rawValue))")
        
        // 先开始音频捕获（这样音频数据会先缓存起来）
        startAudioCapture()
        
        // 发送初始化请求
        sendFullClientRequest()
        
        // 开始接收消息
        receiveMessage()
    }
    
    // MARK: - 二进制协议构建
    
    private func buildHeader(messageType: UInt8, flags: UInt8, serialization: UInt8, compression: UInt8) -> Data {
        var header = Data(count: 4)
        header[0] = 0x11  // version (0001) + header size (0001)
        header[1] = (messageType << 4) | flags
        header[2] = (serialization << 4) | compression
        header[3] = 0x00
        return header
    }
    
    private func sendFullClientRequest() {
        logToFile("[Doubao] Building full client request...")
        
        // 优化参数：开启二遍识别模式提升准确率
        let payload: [String: Any] = [
            "user": ["uid": "ai_input_method"],
            "audio": [
                "format": "pcm",
                "rate": 16000,
                "bits": 16,
                "channel": 1
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,      // 文本规范化
                "enable_punc": true,     // 标点
                "enable_ddc": true,      // 语义顺滑
                "show_utterances": true,
                "enable_nonstream": true // 🔥 开启二遍识别：流式+非流式，提升准确率
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            logToFile("[Doubao] ❌ Failed to serialize JSON")
            return
        }
        
        logToFile("[Doubao] JSON payload: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
        
        guard let compressedData = gzipCompress(jsonData) else {
            logToFile("[Doubao] ❌ Failed to compress payload")
            return
        }
        
        logToFile("[Doubao] Compressed: \(jsonData.count) -> \(compressedData.count) bytes")
        
        // flags = 0x00 (no sequence number, like Python demo)
        var packet = buildHeader(messageType: 0x01, flags: 0x00, serialization: 0x01, compression: 0x01)
        
        // Payload size (no sequence number)
        var size = UInt32(compressedData.count).bigEndian
        packet.append(Data(bytes: &size, count: 4))
        
        // Payload
        packet.append(compressedData)
        
        logToFile("[Doubao] Full request packet: \(packet.count) bytes")
        let headerHex = packet.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
        logToFile("[Doubao] Packet header: \(headerHex)")
        
        webSocketTask?.send(.data(packet)) { error in
            if let error = error {
                logToFile("[Doubao] ❌ Send full request error: \(error)")
                logToFile("[Doubao] Error details: \(error.localizedDescription)")
            } else {
                logToFile("[Doubao] ✅ Full request sent successfully")
            }
        }
    }

    private func startAudioCapture() {
        logToFile("[Doubao] ========== STARTING AUDIO CAPTURE ==========")
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { 
            logToFile("[Doubao] ❌ Failed to create audio engine")
            return 
        }
        
        let inputNode = audioEngine.inputNode
        
        // 使用 inputFormat 而不是 outputFormat
        let inputFormat = inputNode.inputFormat(forBus: 0)
        logToFile("[Doubao] Input format (inputFormat): sampleRate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount)")
        
        let outputFormat = inputNode.outputFormat(forBus: 0)
        logToFile("[Doubao] Input format (outputFormat): sampleRate=\(outputFormat.sampleRate), channels=\(outputFormat.channelCount)")
        
        // 选择有效的格式
        let recordFormat: AVAudioFormat
        if inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 {
            recordFormat = inputFormat
            logToFile("[Doubao] Using inputFormat")
        } else if outputFormat.sampleRate > 0 && outputFormat.channelCount > 0 {
            recordFormat = outputFormat
            logToFile("[Doubao] Using outputFormat")
        } else {
            logToFile("[Doubao] ❌ No valid input format available")
            return
        }
        
        // 目标格式：16kHz, float32, mono（用于转换）
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else {
            logToFile("[Doubao] ❌ Failed to create target format")
            return
        }
        
        // 创建转换器
        guard let converter = AVAudioConverter(from: recordFormat, to: targetFormat) else {
            logToFile("[Doubao] ❌ Failed to create converter from \(recordFormat.sampleRate)Hz to 16kHz")
            return
        }
        logToFile("[Doubao] Audio converter created: \(recordFormat.sampleRate)Hz -> 16kHz")
        
        var tapCallCount = 0
        
        logToFile("[Doubao] Installing audio tap with nil format (let system decide)...")
        
        // 关键：使用 nil 作为 format，让系统自动选择最佳格式
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, time in
            guard let self = self else { return }
            
            tapCallCount += 1
            if tapCallCount <= 3 || tapCallCount % 10 == 0 {
                logToFile("[Doubao] Audio tap #\(tapCallCount): \(buffer.frameLength) frames at \(buffer.format.sampleRate)Hz")
            }
            
            // 计算转换后的帧数
            let ratio = 16000.0 / buffer.format.sampleRate
            let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            
            guard outputFrameCount > 0 else { return }
            
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
                if tapCallCount <= 3 {
                    logToFile("[Doubao] ⚠️ Failed to create output buffer")
                }
                return
            }
            
            // 需要为每个 buffer 创建新的 converter（因为输入格式可能变化）
            guard let dynamicConverter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
                if tapCallCount <= 3 {
                    logToFile("[Doubao] ⚠️ Failed to create dynamic converter")
                }
                return
            }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            dynamicConverter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            
            if let error = error {
                if tapCallCount <= 3 {
                    logToFile("[Doubao] ⚠️ Conversion error: \(error)")
                }
                return
            }
            
            guard let floatData = outputBuffer.floatChannelData, outputBuffer.frameLength > 0 else {
                return
            }
            
            // 转换 float32 -> int16
            var int16Data = Data(count: Int(outputBuffer.frameLength) * 2)
            int16Data.withUnsafeMutableBytes { ptr in
                let int16Ptr = ptr.bindMemory(to: Int16.self)
                for i in 0..<Int(outputBuffer.frameLength) {
                    let sample = floatData[0][i]
                    let clipped = max(-1.0, min(1.0, sample))
                    int16Ptr[i] = Int16(clipped * 32767.0)
                }
            }
            
            DispatchQueue.main.async {
                self.audioBuffer.append(int16Data)
                if tapCallCount <= 3 {
                    logToFile("[Doubao] Buffer now: \(self.audioBuffer.count) bytes (\(outputBuffer.frameLength) frames)")
                }
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            logToFile("[Doubao] ✅ Audio engine started!")
            
            // 🔥 优化：使用 200ms 发送间隔（文档推荐，双向流式模式性能最优）
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
            timer.schedule(deadline: .now() + 0.2, repeating: 0.2)
            timer.setEventHandler { [weak self] in
                self?.sendAudioChunk()
            }
            timer.resume()
            sendTimer = timer
            logToFile("[Doubao] ✅ Send timer started (200ms interval - optimized)")
        } catch {
            logToFile("[Doubao] ❌ Audio engine start error: \(error)")
        }
    }
    
    private func sendAudioChunk() {
        guard !audioBuffer.isEmpty else { 
            return 
        }
        let chunkData = audioBuffer
        audioBuffer = Data()
        logToFile("[Doubao] sendAudioChunk: sending \(chunkData.count) bytes, seq=\(sequenceNumber)")
        sendAudioPacket(data: chunkData, isLast: false)
    }
    
    private var closeWorkItem: DispatchWorkItem?
    
    private func sendLastAudioPacket() {
        let chunkData = audioBuffer
        audioBuffer = Data()
        logToFile("[Doubao] sendLastAudioPacket: sending \(chunkData.count) bytes, seq=-\(sequenceNumber)")
        sendAudioPacket(data: chunkData, isLast: true)
        
        // 取消之前的关闭任务
        closeWorkItem?.cancel()
        
        // 2秒后关闭连接
        let workItem = DispatchWorkItem { [weak self] in
            logToFile("[Doubao] Closing WebSocket connection")
            self?.webSocketTask?.cancel(with: .goingAway, reason: nil)
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
    
    private func sendAudioPacket(data: Data, isLast: Bool) {
        // 如果数据为空且不是最后一包，跳过
        if data.isEmpty && !isLast {
            return
        }
        
        let audioData = data.isEmpty ? Data(repeating: 0, count: 200) : data
        guard let compressedData = gzipCompress(audioData) else {
            logToFile("[Doubao] ❌ Failed to compress audio")
            return
        }
        
        // flags: 0x00 = normal, 0x02 = last packet (like Python demo)
        let flags: UInt8 = isLast ? 0x02 : 0x00
        var packet = buildHeader(messageType: 0x02, flags: flags, serialization: 0x00, compression: 0x01)
        
        // Payload size (no sequence number)
        var size = UInt32(compressedData.count).bigEndian
        packet.append(Data(bytes: &size, count: 4))
        packet.append(compressedData)
        
        logToFile("[Doubao] sendAudioPacket: raw=\(audioData.count)B, compressed=\(compressedData.count)B, isLast=\(isLast)")
        
        webSocketTask?.send(.data(packet)) { error in
            if let error = error {
                logToFile("[Doubao] ❌ Send audio error: \(error)")
            } else {
                logToFile("[Doubao] ✅ Audio packet sent")
            }
        }
    }
    
    // MARK: - 接收消息
    
    private func receiveMessage() {
        logToFile("[Doubao] receiveMessage: waiting for next message...")
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { 
                logToFile("[Doubao] receiveMessage: self is nil")
                return 
            }
            
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    logToFile("[Doubao] ✅ Received data: \(data.count) bytes")
                    self.parseResponse(data)
                case .string(let str):
                    logToFile("[Doubao] ⚠️ Received string (unexpected): \(str.prefix(100))")
                @unknown default:
                    logToFile("[Doubao] ⚠️ Received unknown message type")
                }
                self.receiveMessage()
            case .failure(let error):
                logToFile("[Doubao] ❌ Receive error: \(error)")
                logToFile("[Doubao] Error details: \(error.localizedDescription)")
            }
        }
    }
    
    private func parseResponse(_ data: Data) {
        guard data.count >= 4 else { 
            logToFile("[Doubao] parseResponse: data too short (\(data.count) bytes)")
            return 
        }
        
        let messageType = (data[1] >> 4) & 0x0F
        let flags = data[1] & 0x0F
        let compression = data[2] & 0x0F
        
        logToFile("[Doubao] parseResponse: msgType=0x\(String(format: "%02X", messageType)), flags=0x\(String(format: "%02X", flags)), compression=\(compression)")
        
        // 打印原始头部
        let headerHex = data.prefix(min(16, data.count)).map { String(format: "%02X", $0) }.joined(separator: " ")
        logToFile("[Doubao] Header hex: \(headerHex)")
        
        if messageType == 0x0F {
            logToFile("[Doubao] ❌ Error response received")
            parseErrorResponse(data)
            return
        }
        
        if messageType == 0x09 {
            logToFile("[Doubao] Server response (0x09)")
            var offset = 4
            
            // 读取 sequence number (如果有)
            if flags & 0x01 != 0 { 
                if data.count >= offset + 4 {
                    let seq = data[offset..<(offset+4)].withUnsafeBytes { 
                        Int32(bigEndian: $0.load(as: Int32.self)) 
                    }
                    logToFile("[Doubao] Response sequence: \(seq)")
                }
                offset += 4 
            }
            
            guard data.count > offset + 4 else { 
                logToFile("[Doubao] parseResponse: not enough data for payload size")
                return 
            }
            
            let payloadSize = data[offset..<(offset+4)].withUnsafeBytes { 
                UInt32(bigEndian: $0.load(as: UInt32.self)) 
            }
            offset += 4
            logToFile("[Doubao] Payload size: \(payloadSize)")
            
            guard data.count >= offset + Int(payloadSize) else { 
                logToFile("[Doubao] parseResponse: not enough data for payload (need \(offset + Int(payloadSize)), have \(data.count))")
                return 
            }
            
            var payloadData = Data(data[offset..<(offset + Int(payloadSize))])
            
            if compression == 0x01 {
                logToFile("[Doubao] Decompressing gzip payload...")
                if let decompressed = gzipDecompress(payloadData) {
                    payloadData = decompressed
                    logToFile("[Doubao] Decompressed: \(payloadData.count) bytes")
                } else {
                    logToFile("[Doubao] ⚠️ Gzip decompression failed")
                }
            }
            
            if let jsonStr = String(data: payloadData, encoding: .utf8) {
                logToFile("[Doubao] JSON response: \(jsonStr)")
            } else {
                logToFile("[Doubao] ⚠️ Failed to decode payload as UTF-8")
            }
            
            if let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                logToFile("[Doubao] Parsed JSON keys: \(json.keys.joined(separator: ", "))")
                
                if let result = json["result"] as? [String: Any] {
                    logToFile("[Doubao] Result keys: \(result.keys.joined(separator: ", "))")
                    
                    if let text = result["text"] as? String {
                        logToFile("[Doubao] 🎤 Recognized text: '\(text)'")
                        
                        if !text.isEmpty {
                            DispatchQueue.main.async {
                                self.transcript = text
                                self.onPartialResult?(text)
                                logToFile("[Doubao] Updated transcript to: '\(text)'")
                            }
                        } else {
                            logToFile("[Doubao] ⚠️ Text is empty")
                        }
                    } else {
                        logToFile("[Doubao] ⚠️ No 'text' field in result")
                    }
                } else {
                    logToFile("[Doubao] ⚠️ No 'result' field in JSON")
                }
            } else {
                logToFile("[Doubao] ⚠️ Failed to parse JSON")
            }
            
            // 最后一包
            if (flags & 0x02) != 0 {
                logToFile("[Doubao] 🏁 Final response received (flags & 0x02)")
                DispatchQueue.main.async {
                    let finalText = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    logToFile("[Doubao] Final text: '\(finalText)'")
                    if !finalText.isEmpty && finalText != "正在听..." {
                        logToFile("[Doubao] ✅ Calling onFinalResult with: '\(finalText)'")
                        self.onFinalResult?(finalText)
                    } else {
                        logToFile("[Doubao] ⚠️ Skipping onFinalResult (empty or placeholder)")
                    }
                    self.transcript = ""
                }
            }
        } else {
            logToFile("[Doubao] ⚠️ Unknown message type: 0x\(String(format: "%02X", messageType))")
        }
    }
    
    private func parseErrorResponse(_ data: Data) {
        guard data.count >= 12 else { 
            logToFile("[Doubao] Error response too short: \(data.count) bytes")
            return 
        }
        let errorCode = data[4..<8].withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
        let messageSize = data[8..<12].withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
        
        logToFile("[Doubao] Error code: \(errorCode), message size: \(messageSize)")
        
        if data.count >= 12 + Int(messageSize) {
            let message = String(data: data[12..<(12 + Int(messageSize))], encoding: .utf8) ?? "Unknown"
            logToFile("[Doubao] ❌ Error \(errorCode): \(message)")
            DispatchQueue.main.async { self.transcript = "错误: \(message)" }
        } else {
            logToFile("[Doubao] ❌ Error \(errorCode): (message truncated)")
        }
    }

    // MARK: - Gzip 压缩/解压
    
    private func gzipCompress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        
        var compressedData = Data()
        compressedData.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03])
        
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count + 1024)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            let sourceBuffer = sourcePtr.bindMemory(to: UInt8.self).baseAddress!
            return compression_encode_buffer(destinationBuffer, data.count + 1024, sourceBuffer, data.count, nil, COMPRESSION_ZLIB)
        }
        
        guard compressedSize > 0 else { return nil }
        
        compressedData.append(destinationBuffer, count: compressedSize)
        
        let crc = crc32(data)
        var crcLE = crc.littleEndian
        compressedData.append(Data(bytes: &crcLE, count: 4))
        
        var sizeLE = UInt32(data.count).littleEndian
        compressedData.append(Data(bytes: &sizeLE, count: 4))
        
        return compressedData
    }
    
    private func gzipDecompress(_ data: Data) -> Data? {
        guard data.count > 10 else { return nil }
        
        var headerSize = 10
        if data[3] & 0x08 != 0 {
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        
        guard data.count > headerSize + 8 else { return nil }
        
        let compressedData = data.subdata(in: headerSize..<(data.count - 8))
        
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count * 20)
        defer { destinationBuffer.deallocate() }
        
        let decompressedSize = compressedData.withUnsafeBytes { sourcePtr -> Int in
            let sourceBuffer = sourcePtr.bindMemory(to: UInt8.self).baseAddress!
            return compression_decode_buffer(destinationBuffer, compressedData.count * 20, sourceBuffer, compressedData.count, nil, COMPRESSION_ZLIB)
        }
        
        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
    
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = makeCRC32Table()
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
    
    private func makeCRC32Table() -> [UInt32] {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }
}
