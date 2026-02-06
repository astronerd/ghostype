import SwiftUI
import AppKit

// MARK: - 透明窗口辅助 View
class TransparentWindowView: NSView {
    override func viewDidMoveToWindow() {
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.hasShadow = false
        super.viewDidMoveToWindow()
    }
}

struct TransparentWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return TransparentWindowView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - 主视图
struct OverlayView: View {
    @ObservedObject var speechService: DoubaoSpeechService
    
    private let iconSize: CGFloat = 22
    private let horizontalPadding: CGFloat = 14
    private let verticalPadding: CGFloat = 10
    private let spacing: CGFloat = 10
    
    private var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1440
    }
    
    // 动态宽度：10% ~ 30%
    private var capsuleWidth: CGFloat {
        let minWidth = screenWidth * 0.10
        let maxWidth = screenWidth * 0.30
        
        let text = displayText
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let contentWidth = iconSize + spacing + textWidth + horizontalPadding * 2 + 20
        
        return min(max(contentWidth, minWidth), maxWidth)
    }
    
    private var maxTextWidth: CGFloat {
        capsuleWidth - iconSize - spacing - horizontalPadding * 2
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            GhostIconView(isRecording: speechService.isRecording)
                .frame(width: iconSize, height: iconSize)
            
            textArea
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(width: capsuleWidth)
        .background(
            Capsule()
                .fill(Color(white: 0.10))
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TransparentWindowBackground())
    }
    
    // 文字区域 - 从右往左流动
    private var textArea: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 3) {
                Spacer(minLength: 0)
                
                Text(displayText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                if speechService.isRecording {
                    CursorView()
                }
            }
        }
        .frame(width: maxTextWidth, alignment: .trailing)
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
                Rectangle().fill(Color.black)
            }
        )
    }
    
    private var displayText: String {
        let text = speechService.transcript
        if text.isEmpty || text == "正在听..." {
            return speechService.isRecording ? "正在聆听…" : "⌥ Space"
        }
        return text
    }
}

// MARK: - 闪烁光标
struct CursorView: View {
    @State private var visible = true
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - 小幽灵图标
struct GhostIconView: View {
    let isRecording: Bool
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        Image(nsImage: loadGhostIcon())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .colorInvert()
            .opacity(0.9)
            .offset(y: floatOffset)
            .onAppear { if isRecording { startAnimation() } }
            .onChange(of: isRecording) { _, rec in
                if rec { startAnimation() } else { stopAnimation() }
            }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            floatOffset = -3
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.2)) { floatOffset = 0 }
    }
    
    private func loadGhostIcon() -> NSImage {
        if let path = Bundle.main.path(forResource: "GhostIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: path) { return image }
        let devPath = "/Users/gengdawei/ghostype/AIInputMethod/Sources/Resources/GhostIcon.png"
        if let image = NSImage(contentsOfFile: devPath) { return image }
        return NSImage(systemSymbolName: "waveform", accessibilityDescription: nil) ?? NSImage()
    }
}
