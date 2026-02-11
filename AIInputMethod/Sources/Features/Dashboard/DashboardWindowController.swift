import AppKit
import SwiftUI

/// Dashboard 窗口控制器
/// 管理 Dashboard 主窗口的创建、显示、隐藏和位置持久化
/// Requirements: 12.1, 12.2, 12.3, 12.4, 3.6
class DashboardWindowController {
    
    // MARK: - Properties
    
    /// Dashboard 窗口实例
    var window: NSWindow?
    
    /// 窗口最小尺寸 (Requirement 3.6: 900x600pt)
    static let minimumSize = NSSize(width: 900, height: 600)
    
    /// 窗口默认尺寸
    static let defaultSize = NSSize(width: 1000, height: 700)
    
    /// UserDefaults key for window frame persistence
    private static let windowFrameKey = "dashboardWindowFrame"
    
    // MARK: - Singleton
    
    /// 共享实例
    static let shared = DashboardWindowController()
    
    private init() {}
    
    // MARK: - Window Management
    
    /// 显示 Dashboard 窗口
    /// Requirement 12.1: Dashboard window SHALL be accessible from menu bar icon click
    func show() {
        if window == nil {
            createWindow()
        }
        
        guard let window = window else { return }
        
        // 恢复窗口位置
        restoreWindowFrame()
        
        // 显示窗口并激活应用
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 显示 Dock 图标
        NSApp.setActivationPolicy(.regular)
    }
    
    /// 隐藏 Dashboard 窗口
    func hide() {
        guard let window = window else { return }
        
        // 保存窗口位置
        saveWindowFrame()
        
        // 关闭窗口
        window.orderOut(nil)
        
        // 检查是否还有其他可见窗口（不包括 overlay panel）
        let hasVisibleWindows = NSApp.windows.contains { w in
            w.isVisible && w != window && !(w is NSPanel)
        }
        
        // 如果没有其他可见窗口，隐藏 Dock 图标
        if !hasVisibleWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    /// 切换 Dashboard 窗口显示状态
    /// Requirement 12.5: WHEN menu bar icon is clicked while Dashboard is visible, THE Dashboard SHALL come to front
    func toggle() {
        guard let window = window else {
            show()
            return
        }
        
        if window.isVisible {
            // 如果窗口可见但不在最前面，则将其带到前面
            if !window.isKeyWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                hide()
            }
        } else {
            show()
        }
    }
    
    // MARK: - Window Frame Persistence
    
    /// 保存窗口位置和尺寸到 UserDefaults
    /// Requirement 12.2: Dashboard window SHALL remember its last position and size
    func saveWindowFrame() {
        guard let window = window else { return }
        
        let frame = window.frame
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        
        UserDefaults.standard.set(frameDict, forKey: Self.windowFrameKey)
    }
    
    /// 从 UserDefaults 恢复窗口位置（尺寸始终使用默认值）
    /// Requirement 12.2: Dashboard window SHALL remember its last position
    func restoreWindowFrame() {
        guard let window = window else { return }
        
        // 始终使用默认尺寸
        let width = Self.defaultSize.width
        let height = Self.defaultSize.height
        
        if let frameDict = UserDefaults.standard.dictionary(forKey: Self.windowFrameKey) as? [String: CGFloat],
           let x = frameDict["x"],
           let y = frameDict["y"] {
            
            let frame = NSRect(x: x, y: y, width: width, height: height)
            
            // 确保窗口在可见屏幕范围内
            if isFrameOnScreen(frame) {
                window.setFrame(frame, display: true)
            } else {
                centerWindow()
            }
        } else {
            centerWindow()
        }
    }
    
    // MARK: - Private Methods
    
    /// 创建 Dashboard 窗口
    private func createWindow() {
        // 创建窗口
        // Requirement 12.4: Dashboard window SHALL support standard window controls (close, minimize, zoom)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable
        ]
        
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口属性
        window.title = "GHOSTYPE"
        
        // Requirement 3.6: THE Dashboard window SHALL have minimum size of 900x600pt
        window.minSize = Self.minimumSize
        
        // Requirement 12.3: WHEN Dashboard window loses focus, THE window SHALL remain visible (not auto-hide)
        // 使用 .regular 级别，窗口失去焦点时不会自动隐藏
        window.level = .normal
        window.isReleasedWhenClosed = false
        
        // 设置窗口外观
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.backgroundColor = NSColor.windowBackgroundColor
        
        // 设置窗口代理以处理关闭和移动事件
        window.delegate = WindowDelegate.shared
        
        // 创建 SwiftUI 内容视图 - 使用实际的 DashboardView
        let contentView = DashboardView()
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        self.window = window
    }
    
    /// 将窗口居中显示
    private func centerWindow() {
        guard let window = window,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        
        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - windowSize.height) / 2
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    /// 检查窗口 frame 是否在可见屏幕范围内
    private func isFrameOnScreen(_ frame: NSRect) -> Bool {
        for screen in NSScreen.screens {
            if screen.visibleFrame.intersects(frame) {
                return true
            }
        }
        return false
    }
}

// MARK: - Window Delegate

/// 窗口代理，处理窗口事件
private class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    private override init() {
        super.init()
    }
    
    /// 窗口即将关闭时保存位置
    func windowWillClose(_ notification: Notification) {
        DashboardWindowController.shared.saveWindowFrame()
    }
    
    /// 窗口移动结束时保存位置
    func windowDidMove(_ notification: Notification) {
        DashboardWindowController.shared.saveWindowFrame()
    }
    
    /// 窗口调整大小结束时保存位置
    func windowDidResize(_ notification: Notification) {
        DashboardWindowController.shared.saveWindowFrame()
    }
}
