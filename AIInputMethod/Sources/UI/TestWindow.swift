import SwiftUI

struct TestWindow: View {
    @ObservedObject var speechService: DoubaoSpeechService
    @State private var logs: [String] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // Overlay 预览
            OverlayView(speechService: speechService)
                .padding(.top, 8)
            
            // 识别结果
            GroupBox("识别结果") {
                ScrollView {
                    Text(speechService.transcript.isEmpty ? "按住按钮说话..." : speechService.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(speechService.transcript.isEmpty ? .secondary : .primary)
                }
                .frame(height: 80)
            }
            
            // 按住说话按钮
            Button(action: {}) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("按住说话")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(speechService.isRecording ? .red : .blue)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !speechService.isRecording {
                            addLog("开始录音")
                            speechService.startRecording()
                        }
                    }
                    .onEnded { _ in
                        addLog("停止录音")
                        speechService.stopRecording()
                    }
            )
            
            // 日志区域
            GroupBox("日志") {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(logs.enumerated()), id: \.offset) { idx, log in
                                Text(log)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .id(idx)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: logs.count) { _, _ in
                        if let last = logs.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .frame(height: 120)
            }
            
            Button("清除日志") {
                logs.removeAll()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 400, height: 480)
        .onReceive(speechService.$transcript) { text in
            if !text.isEmpty && text != "正在听..." {
                addLog("识别: \(text)")
            }
        }
    }
    
    private func addLog(_ msg: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(time)] \(msg)")
    }
}
