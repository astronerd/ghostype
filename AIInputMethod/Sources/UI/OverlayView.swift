import SwiftUI
import AppKit

class TransparentBackgroundView: NSView {
    override func viewDidMoveToWindow() {
        window?.backgroundColor = .clear
        window?.isOpaque = false
        super.viewDidMoveToWindow()
    }
}

struct TransparentBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { TransparentBackgroundView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct OverlayView: View {
    @ObservedObject var speechService: DoubaoSpeechService
    @State private var animatePulse = false
    
    // 跑道圆尺寸：宽200，高28，圆角14（高度的一半=完美跑道圆）
    private let width: CGFloat = 200
    private let height: CGFloat = 28
    
    var body: some View {
        ZStack {
            TransparentBackground()
            
            // 跑道圆背景（cornerRadius = height/2）
            Capsule()
                .fill(.clear)
                .background(
                    VisualEffectBackground()
                        .clipShape(Capsule())
                )
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            
            HStack(spacing: 8) {
                ZStack {
                    if speechService.isRecording {
                        Circle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .scaleEffect(animatePulse ? 1.4 : 1.0)
                            .opacity(animatePulse ? 0 : 0.6)
                    }
                    Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(speechService.isRecording ? Color.accentColor : .secondary)
                }
                .frame(width: 18)
                
                Text(getDisplayText())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: width, height: height)
        .onAppear { print("[OverlayView] STADIUM_UI_V4") }
        .onChange(of: speechService.isRecording) { _, isRecording in
            if isRecording {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    animatePulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    animatePulse = false
                }
            }
        }
    }
    
    private func getDisplayText() -> String {
        let text = speechService.transcript
        if text.isEmpty || text == "正在听..." {
            return speechService.isRecording ? "正在聆听…" : "⌥空格"
        }
        let maxChars = 16
        if text.count > maxChars {
            return "…" + String(text.suffix(maxChars))
        }
        return text
    }
}
