import Foundation
import AppKit
import SwiftUI

// MARK: - Overlay Window Manager

/// Overlay 窗口管理器
/// 从 AppDelegate 提取的 Overlay 窗口创建、定位、显示、隐藏逻辑
class OverlayWindowManager {

    private(set) var overlayWindow: NSPanel!

    // MARK: - Setup

    func setup(speechService: DoubaoSpeechService) {
        guard let screen = NSScreen.main else { return }

        // 窗口占满屏幕宽度（透明），capsule 在内部自动居中
        let windowWidth = screen.frame.width
        let windowHeight: CGFloat = 100

        overlayWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.isMovableByWindowBackground = false
        overlayWindow.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: OverlayView(speechService: speechService))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor.clear
        overlayWindow.contentView = hostingView

        positionAtBottom()
    }

    // MARK: - Show / Hide

    func show() {
        overlayWindow.orderFront(nil)
    }

    func hide() {
        overlayWindow.orderOut(nil)
    }

    // MARK: - Positioning

    func positionAtBottom() {
        guard let screen = NSScreen.main else { return }

        let windowWidth = overlayWindow.frame.width
        let x = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
        let dockHeight = screen.visibleFrame.origin.y - screen.frame.origin.y
        let y = screen.frame.origin.y + dockHeight + 20

        overlayWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showNearCursor() {
        print("[Overlay] Showing overlay at bottom center...")
        positionAtBottom()
        show()
    }

    func moveTo(bounds: CGRect) {
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY))
        }) ?? NSScreen.main else { return }

        let screenHeight = screen.frame.height + screen.frame.origin.y
        let overlayHeight: CGFloat = 44
        let overlayWidth: CGFloat = 320
        let gap: CGFloat = 8

        let cocoaY = screenHeight - bounds.origin.y + gap
        let targetX = bounds.origin.x

        let clampedX = max(screen.frame.minX, min(targetX, screen.frame.maxX - overlayWidth))
        let clampedY = max(screen.frame.minY + overlayHeight, min(cocoaY, screen.frame.maxY - overlayHeight))

        overlayWindow.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
}
