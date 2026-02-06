import SwiftUI
import Combine

@main
struct AIInputMethodApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// 引导窗口控制器
class OnboardingWindowController {
    var window: NSWindow?
    
    func show(permissionManager: PermissionManager, onComplete: @escaping () -> Void) {
        let contentView = OnboardingWindow(permissionManager: permissionManager) {
            self.window?.close()
            onComplete()
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        self.window = window
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var overlayWindow: NSPanel!
    var statusItem: NSStatusItem!
    var focusObserver = FocusObserver()
    var cursorManager = CursorManager()
    var permissionManager = PermissionManager()
    var speechService = DoubaoSpeechService()
    var hotkeyManager = HotkeyManager()
    var onboardingController = OnboardingWindowController()
    var dashboardController: DashboardWindowController { DashboardWindowController.shared }
    var testWindow: NSWindow?
    
    /// 当前输入模式
    @Published var currentMode: InputMode = .polish
    
    /// 当前录音的原始文本
    private var currentRawText: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[App] Launching...")
        
        // 检查权限
        permissionManager.checkAccessibilityStatus()
        permissionManager.checkMicrophoneStatus()
        
        print("[App] Accessibility: \(permissionManager.isAccessibilityTrusted)")
        print("[App] Microphone: \(permissionManager.isMicrophoneGranted)")
        
        // 如果没有辅助功能权限，触发系统弹窗
        if !permissionManager.isAccessibilityTrusted {
            print("[App] Requesting accessibility permission...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        
        // 显示引导窗口
        print("[App] Showing permission window...")
        showPermissionWindow()
        print("[App] Permission window shown")
    }
    
    func showPermissionWindow() {
        onboardingController.show(permissionManager: permissionManager) { [weak self] in
            self?.startApp()
        }
    }
    
    func startApp() {
        print("[App] ========== STARTING APP ==========")
        
        // 1. Setup UI
        setupMenuBar()
        setupOverlayWindow()
        hideOverlay()
        print("[App] UI setup done")
        
        // 2. 启动 FocusObserver
        focusObserver.startObserving()
        print("[App] FocusObserver started")
        
        // 3. Setup hotkey
        setupHotkey()
        
        // 4. Setup speech result callback
        speechService.onFinalResult = { [weak self] text in
            guard let self = self else { return }
            print("[Speech] Final result received: \(text)")
            self.currentRawText = text
            // 注意：不再直接插入，等待 onHotkeyUp 时根据模式处理
        }
        
        speechService.onPartialResult = { text in
            print("[Speech] Partial result: \(text)")
        }
        
        print("[App] ========== APP STARTED ==========")
    }
    
    // MARK: - Hotkey
    func setupHotkey() {
        // 按下快捷键：开始录音
        hotkeyManager.onHotkeyDown = { [weak self] in
            guard let self = self else { return }
            print("[Hotkey] ========== DOWN ==========")
            print("[Hotkey] Starting recording, mode: \(self.hotkeyManager.currentMode.displayName)")
            self.currentMode = self.hotkeyManager.currentMode
            self.currentRawText = ""
            self.showOverlayNearCursor()
            self.speechService.startRecording()
        }
        
        // 录音过程中模式变化
        hotkeyManager.onModeChanged = { [weak self] mode in
            guard let self = self else { return }
            print("[Hotkey] Mode changed to: \(mode.displayName)")
            self.currentMode = mode
            // TODO: 更新 Overlay UI 颜色
        }
        
        // 松开快捷键：停止录音，根据模式处理
        hotkeyManager.onHotkeyUp = { [weak self] mode in
            guard let self = self else { return }
            print("[Hotkey] ========== UP ==========")
            print("[Hotkey] Stopping recording, final mode: \(mode.displayName)")
            self.speechService.stopRecording()
            
            // 等待语音识别完成后处理
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.processWithMode(mode)
            }
        }
        
        print("[App] Starting hotkey manager...")
        hotkeyManager.start()
        print("[App] Hotkey manager started")
        print("[App] Modes: Default=润色, Shift=翻译, Cmd=随心记")
    }
    
    // MARK: - AI Processing
    
    /// 根据模式处理文本
    func processWithMode(_ mode: InputMode) {
        let text = currentRawText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            print("[Process] Empty text, skipping")
            hideOverlay()
            return
        }
        
        print("[Process] Processing with mode: \(mode.displayName)")
        print("[Process] Raw text: \(text)")
        
        // TODO: 更新 Overlay 显示 "AI 处理中..."
        
        switch mode {
        case .polish:
            // 润色模式：AI 润色后上屏
            processPolish(text)
            
        case .translate:
            // 翻译模式：翻译后上屏
            processTranslate(text)
            
        case .memo:
            // 随心记模式：整理后保存到笔记，不上屏
            processMemo(text)
        }
    }
    
    /// 润色处理
    private func processPolish(_ text: String) {
        print("[Polish] Starting AI polish...")
        
        MiniMaxService.shared.polish(text: text) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let polishedText):
                print("[Polish] Success: \(polishedText)")
                self.insertTextAtCursor(polishedText)
                self.saveUsageRecord(content: polishedText, category: .polish)
                
            case .failure(let error):
                print("[Polish] Error: \(error.localizedDescription)")
                // 失败时直接使用原文
                self.insertTextAtCursor(text)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.hideOverlay()
            }
        }
    }
    
    /// 翻译处理
    private func processTranslate(_ text: String) {
        print("[Translate] Starting AI translate...")
        
        MiniMaxService.shared.translate(text: text) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let translatedText):
                print("[Translate] Success: \(translatedText)")
                self.insertTextAtCursor(translatedText)
                self.saveUsageRecord(content: translatedText, category: .translate)
                
            case .failure(let error):
                print("[Translate] Error: \(error.localizedDescription)")
                // 失败时直接使用原文
                self.insertTextAtCursor(text)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.hideOverlay()
            }
        }
    }
    
    /// 随心记处理
    private func processMemo(_ text: String) {
        print("[Memo] Starting AI organize...")
        
        MiniMaxService.shared.organizeMemo(text: text) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let organizedText):
                print("[Memo] Success: \(organizedText)")
                // 保存到笔记，不上屏
                self.saveUsageRecord(content: organizedText, category: .memo)
                // TODO: 显示保存成功的动画
                print("[Memo] Saved to notes (not inserted)")
                
            case .failure(let error):
                print("[Memo] Error: \(error.localizedDescription)")
                // 失败时保存原文
                self.saveUsageRecord(content: text, category: .memo)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.hideOverlay()
            }
        }
    }
    
    /// 保存使用记录到 CoreData
    private func saveUsageRecord(content: String, category: RecordCategory) {
        let context = PersistenceController.shared.container.viewContext
        let record = UsageRecord(context: context)
        record.id = UUID()
        record.content = content
        record.category = category.rawValue
        record.timestamp = Date()
        record.deviceId = DeviceIdManager.shared.deviceId
        
        // 获取当前前台应用信息
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            record.sourceApp = frontApp.localizedName ?? "Unknown"
            record.sourceAppBundleId = frontApp.bundleIdentifier ?? ""
        } else {
            record.sourceApp = "Unknown"
            record.sourceAppBundleId = ""
        }
        record.duration = 0 // TODO: 计算实际录音时长
        
        do {
            try context.save()
            print("[Record] Saved: \(category.rawValue) - \(content.prefix(30))...")
        } catch {
            print("[Record] Save error: \(error)")
        }
    }
    
    // MARK: - Text Insertion (使用剪贴板 + Cmd+V)
    func insertTextAtCursor(_ text: String) {
        print("[Insert] ========== INSERTING ==========")
        print("[Insert] Text: \(text)")
        
        guard !text.isEmpty else {
            print("[Insert] Empty text, skipping")
            return
        }
        
        // 使用剪贴板 + Cmd+V 粘贴
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("[Insert] Clipboard set: \(success)")
        
        // 模拟 Cmd+V 粘贴
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            print("[Insert] Sending Cmd+V...")
            let source = CGEventSource(stateID: .hidSystemState)
            
            // Key down: V with Command
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) {
                keyDown.flags = .maskCommand
                keyDown.post(tap: .cghidEventTap)
                print("[Insert] Cmd+V keyDown sent")
            } else {
                print("[Insert] ERROR: Failed to create keyDown event")
            }
            
            // Key up: V with Command
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
                    keyUp.flags = .maskCommand
                    keyUp.post(tap: .cghidEventTap)
                    print("[Insert] Cmd+V keyUp sent")
                } else {
                    print("[Insert] ERROR: Failed to create keyUp event")
                }
                print("[Insert] ========== DONE ==========")
            }
        }
    }
    
    func showOverlayNearCursor() {
        print("[Overlay] Showing overlay at bottom center...")
        positionOverlayAtBottom()
        showOverlay()
    }
    
    func moveOverlayToMouse() {
        // 不再使用，保留兼容
        positionOverlayAtBottom()
    }
    
    // MARK: - Permissions
    func requestPermissions() {
        // Accessibility
        if !permissionManager.isAccessibilityTrusted {
            permissionManager.promptForAccessibility()
        }
        
        // Microphone
        permissionManager.requestMicrophoneAccess()
    }
    
    // MARK: - Menu Bar
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // 尝试加载自定义图标
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "pdf"),
               let icon = NSImage(contentsOfFile: iconPath) {
                // 菜单栏图标标准尺寸是 22x22 点（@2x 是 44x44 像素）
                icon.size = NSSize(width: 22, height: 22)
                icon.isTemplate = true  // 让图标适应深色/浅色模式
                button.image = icon
                button.imageScaling = .scaleProportionallyDown
            } else {
                // 回退到系统图标
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "GhosTYPE")
            }
            
            // 左键点击打开 Dashboard
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 创建右键菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "GhosTYPE", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "快捷键: \(AppSettings.shared.hotkeyDisplay)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // 模式说明
        menu.addItem(NSMenuItem(title: "🟢 默认: 润色上屏", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "🟣 +Shift: 翻译上屏", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "🟠 +Cmd: 随心记", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let accessibilityItem = NSMenuItem(title: permissionManager.isAccessibilityTrusted ? "✅ 辅助功能权限" : "❌ 辅助功能权限 (点击开启)", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(accessibilityItem)
        
        let micItem = NSMenuItem(title: permissionManager.isMicrophoneGranted ? "✅ 麦克风权限" : "❌ 麦克风权限 (点击开启)", action: #selector(requestMic), keyEquivalent: "")
        menu.addItem(micItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "📊 打开 Dashboard", action: #selector(showDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "🧪 测试窗口", action: #selector(showTestWindow), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // 右键显示菜单
            statusItem.button?.performClick(nil)
        } else {
            // 左键打开 Dashboard
            dashboardController.toggle()
        }
    }
    
    @objc func showDashboard() {
        dashboardController.show()
    }
    
    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    
    @objc func requestMic() {
        permissionManager.requestMicrophoneAccess()
    }
    
    @objc func terminateApp() {
        NSApp.terminate(nil)
    }
    
    @objc func showTestWindow() {
        if testWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "语音识别测试"
            window.contentView = NSHostingView(rootView: TestWindow(speechService: speechService))
            window.center()
            testWindow = window
        }
        testWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Overlay Window
    func setupOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        
        // 窗口大小：足够容纳最大30%宽度的胶囊
        let windowWidth = screen.frame.width * 0.35
        let windowHeight: CGFloat = 60
        
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
        
        // 定位到屏幕底部居中
        positionOverlayAtBottom()
    }
    
    func positionOverlayAtBottom() {
        guard let screen = NSScreen.main else { return }
        
        let windowWidth = overlayWindow.frame.width
        let _ = overlayWindow.frame.height
        
        // 水平居中
        let x = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
        
        // 垂直：Dock上方20px，或屏幕底部上方20px
        // visibleFrame.origin.y 就是 Dock 的高度（如果 Dock 在底部）
        let dockHeight = screen.visibleFrame.origin.y - screen.frame.origin.y
        let y = screen.frame.origin.y + dockHeight + 20
        
        overlayWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func moveOverlay(to bounds: CGRect) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) }) ?? NSScreen.main else { return }
        
        // AX 坐标系：原点在屏幕左上角
        // Cocoa 坐标系：原点在屏幕左下角
        let screenHeight = screen.frame.height + screen.frame.origin.y
        
        let overlayHeight: CGFloat = 44
        let overlayWidth: CGFloat = 320
        let gap: CGFloat = 8
        
        // 转换 Y 坐标
        let cocoaY = screenHeight - bounds.origin.y + gap
        let targetX = bounds.origin.x
        
        // 确保不超出屏幕
        let clampedX = max(screen.frame.minX, min(targetX, screen.frame.maxX - overlayWidth))
        let clampedY = max(screen.frame.minY + overlayHeight, min(cocoaY, screen.frame.maxY - overlayHeight))
        
        overlayWindow.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
    
    func getElementFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        if let positionVal = positionValue, CFGetTypeID(positionVal as CFTypeRef) == AXValueGetTypeID() {
            AXValueGetValue(positionVal as! AXValue, .cgPoint, &position)
        }
        if let sizeVal = sizeValue, CFGetTypeID(sizeVal as CFTypeRef) == AXValueGetTypeID() {
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        }
        
        return CGRect(origin: position, size: size)
    }
    
    @objc func showOverlay() {
        overlayWindow.orderFront(nil)
    }
    
    func hideOverlay() {
        overlayWindow.orderOut(nil)
    }
}
