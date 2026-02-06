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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
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
        window.level = .normal
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
    
    @Published var currentMode: InputMode = .polish
    private var currentRawText: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    // 等待最终结果的状态
    private var pendingMode: InputMode?
    private var waitingForFinalResult = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[App] Launching...")
        
        permissionManager.checkAccessibilityStatus()
        permissionManager.checkMicrophoneStatus()
        
        print("[App] Accessibility: \(permissionManager.isAccessibilityTrusted)")
        print("[App] Microphone: \(permissionManager.isMicrophoneGranted)")
        
        // 检查是否需要显示 onboarding
        // onboardingRequiredVersion: 需要强制显示 onboarding 的最低版本
        // 只有当用户的 lastOnboardingVersion 低于这个版本时才显示
        let onboardingRequiredVersion = "1.1"  // 需要重新 onboarding 的版本，后续更新如不需要可保持不变
        let lastOnboardingVersion = UserDefaults.standard.string(forKey: "lastOnboardingVersion") ?? "0.0"
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // 比较版本号
        let needsOnboarding = !hasCompletedOnboarding || lastOnboardingVersion.compare(onboardingRequiredVersion, options: .numeric) == .orderedAscending
        
        if !needsOnboarding {
            print("[App] Onboarding not required, starting app directly...")
            startApp()
        } else {
            print("[App] Showing onboarding (required version: \(onboardingRequiredVersion), last: \(lastOnboardingVersion))...")
            showPermissionWindow()
        }
    }
    
    func showPermissionWindow() {
        onboardingController.show(permissionManager: permissionManager) { [weak self] in
            // 标记 onboarding 已完成，并记录版本号
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(currentVersion, forKey: "lastOnboardingVersion")
            self?.startApp()
            
            // Onboarding 完成后自动打开 Dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                DashboardWindowController.shared.show()
            }
        }
    }
    
    func startApp() {
        print("[App] ========== STARTING APP ==========")
        
        setupMenuBar()
        setupOverlayWindow()
        hideOverlay()
        print("[App] UI setup done")
        
        focusObserver.startObserving()
        print("[App] FocusObserver started")
        
        setupHotkey()
        
        // 🔥 关键：收到最终结果后立即处理（二遍识别完成）
        speechService.onFinalResult = { [weak self] text in
            guard let self = self else { return }
            FileLogger.log("[Speech] ✅ Final result (二遍识别完成): \(text)")
            self.currentRawText = text
            
            // 如果正在等待最终结果，立即处理
            if self.waitingForFinalResult, let mode = self.pendingMode {
                FileLogger.log("[Speech] Processing immediately after final result")
                self.waitingForFinalResult = false
                self.pendingMode = nil
                self.processWithMode(mode)
            }
        }
        
        speechService.onPartialResult = { text in
            FileLogger.log("[Speech] Partial result (流式): \(text)")
        }
        
        print("[App] ========== APP STARTED ==========")
        print("[App] AI Polish: \(AppSettings.shared.enableAIPolish ? "ON" : "OFF")")
    }
    
    // MARK: - Hotkey
    func setupHotkey() {
        hotkeyManager.onHotkeyDown = { [weak self] in
            guard let self = self else { return }
            print("[Hotkey] ========== DOWN ==========")
            print("[Hotkey] Starting recording, mode: \(self.hotkeyManager.currentMode.displayName)")
            self.currentMode = self.hotkeyManager.currentMode
            self.currentRawText = ""
            self.waitingForFinalResult = false
            self.pendingMode = nil
            self.showOverlayNearCursor()
            self.speechService.startRecording()
            
            // 设置录音状态
            OverlayStateManager.shared.setRecording(mode: self.currentMode)
        }
        
        hotkeyManager.onModeChanged = { [weak self] mode in
            guard let self = self else { return }
            print("[Hotkey] Mode changed to: \(mode.displayName)")
            self.currentMode = mode
            
            // 更新录音状态的模式
            OverlayStateManager.shared.setRecording(mode: mode)
        }
        
        hotkeyManager.onHotkeyUp = { [weak self] mode in
            guard let self = self else { return }
            print("[Hotkey] ========== UP ==========")
            print("[Hotkey] Stopping recording, final mode: \(mode.displayName)")
            self.speechService.stopRecording()
            
            // 设置处理状态
            OverlayStateManager.shared.setProcessing(mode: mode)
            
            // 🔥 等待二遍识别完成后再处理
            // 如果已经有最终结果（短音频可能已经返回），直接处理
            // 否则设置等待状态，等 onFinalResult 回调
            if !self.currentRawText.isEmpty {
                FileLogger.log("[Hotkey] Final result already available, processing now")
                self.processWithMode(mode)
            } else {
                FileLogger.log("[Hotkey] Waiting for final result (二遍识别)...")
                self.waitingForFinalResult = true
                self.pendingMode = mode
                
                // 超时保护：最多等 3 秒
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, self.waitingForFinalResult else { return }
                    FileLogger.log("[Hotkey] ⚠️ Timeout waiting for final result")
                    self.waitingForFinalResult = false
                    if let mode = self.pendingMode {
                        self.pendingMode = nil
                        self.processWithMode(mode)
                    }
                }
            }
        }
        
        print("[App] Starting hotkey manager...")
        hotkeyManager.start()
        print("[App] Hotkey manager started")
    }
    
    // MARK: - AI Processing
    
    func processWithMode(_ mode: InputMode) {
        let text = currentRawText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            FileLogger.log("[Process] Empty text, skipping")
            hideOverlay()
            return
        }
        
        FileLogger.log("[Process] Processing with mode: \(mode.displayName)")
        FileLogger.log("[Process] Raw text: \(text)")
        FileLogger.log("[Process] AI Polish enabled: \(AppSettings.shared.enableAIPolish)")
        
        switch mode {
        case .polish:
            if AppSettings.shared.enableAIPolish {
                // 检查阈值：文本长度 >= 阈值时才进行 AI 润色
                let threshold = AppSettings.shared.polishThreshold
                let textLength = text.count
                FileLogger.log("[Polish] Text length: \(textLength), Threshold: \(threshold)")
                
                if textLength >= threshold {
                    processPolish(text)
                } else {
                    FileLogger.log("[Polish] Text too short (< \(threshold)), inserting raw text")
                    insertTextAtCursor(text)
                    saveUsageRecord(content: text, category: .polish)
                    OverlayStateManager.shared.setCommitting(type: .textInput)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.hideOverlay()
                    }
                }
            } else {
                FileLogger.log("[Process] AI Polish OFF, inserting raw text")
                insertTextAtCursor(text)
                saveUsageRecord(content: text, category: .polish)
                OverlayStateManager.shared.setCommitting(type: .textInput)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.hideOverlay()
                }
            }
            
        case .translate:
            processTranslate(text)
            
        case .memo:
            processMemo(text)
        }
    }
    
    private func processPolish(_ text: String) {
        print("[Polish] Starting AI polish with Doubao...")
        
        DoubaoLLMService.shared.polish(text: text) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let polishedText):
                print("[Polish] Success: \(polishedText)")
                self.insertTextAtCursor(polishedText)
                self.saveUsageRecord(content: polishedText, category: .polish)
                
            case .failure(let error):
                print("[Polish] Error: \(error.localizedDescription)")
                self.insertTextAtCursor(text)
            }
            
            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.hideOverlay()
            }
        }
    }
    
    private func processTranslate(_ text: String) {
        print("[Translate] Starting AI translate with Doubao...")
        
        let language = AppSettings.shared.translateLanguage
        
        DoubaoLLMService.shared.translate(text: text, language: language) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let translatedText):
                print("[Translate] Success: \(translatedText)")
                self.insertTextAtCursor(translatedText)
                self.saveUsageRecord(content: translatedText, category: .translate)
                
            case .failure(let error):
                print("[Translate] Error: \(error.localizedDescription)")
                self.insertTextAtCursor(text)
            }
            
            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.hideOverlay()
            }
        }
    }
    
    private func processMemo(_ text: String) {
        FileLogger.log("[Memo] Saving memo directly (no AI processing)...")
        
        self.saveUsageRecord(content: text, category: .memo)
        FileLogger.log("[Memo] Saved to notes")
        
        OverlayStateManager.shared.setCommitting(type: .memoSaved)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.hideOverlay()
        }
    }
    
    private func saveUsageRecord(content: String, category: RecordCategory) {
        let context = PersistenceController.shared.container.viewContext
        let record = UsageRecord(context: context)
        record.id = UUID()
        record.content = content
        record.category = category.rawValue
        record.timestamp = Date()
        record.deviceId = DeviceIdManager.shared.deviceId
        
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            record.sourceApp = frontApp.localizedName ?? "Unknown"
            record.sourceAppBundleId = frontApp.bundleIdentifier ?? ""
        } else {
            record.sourceApp = "Unknown"
            record.sourceAppBundleId = ""
        }
        record.duration = 0
        
        do {
            try context.save()
            FileLogger.log("[Record] Saved: \(category.rawValue) - \(content.prefix(30))...")
        } catch {
            FileLogger.log("[Record] Save error: \(error)")
        }
    }
    
    // MARK: - Text Insertion
    func insertTextAtCursor(_ text: String) {
        print("[Insert] ========== INSERTING ==========")
        print("[Insert] Text: \(text)")
        
        guard !text.isEmpty else {
            print("[Insert] Empty text, skipping")
            return
        }
        
        // 获取当前前台应用的 bundleId，用于判断是否需要自动回车
        let frontAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let shouldAutoEnter = AppSettings.shared.shouldAutoEnter(for: frontAppBundleId)
        FileLogger.log("[Insert] Front app: \(frontAppBundleId ?? "unknown"), Auto-enter: \(shouldAutoEnter)")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("[Insert] Clipboard set: \(success)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            print("[Insert] Sending Cmd+V...")
            let source = CGEventSource(stateID: .hidSystemState)
            
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) {
                keyDown.flags = .maskCommand
                
                keyDown.post(tap: .cghidEventTap)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
                    keyUp.flags = .maskCommand
                    
                    keyUp.post(tap: .cghidEventTap)
                }
                print("[Insert] Paste done")
                
                // 自动回车功能
                if shouldAutoEnter {
                    self?.sendEnterKey()
                }
                
                print("[Insert] ========== DONE ==========")
            }
        }
    }
    
    /// 发送 Cmd+Enter（微信、飞书等应用用 Cmd+Enter 发送消息）
    private func sendEnterKey() {
        print("[Insert] Sending Enter via osascript...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Use osascript command to simulate Enter key - more reliable for Electron apps
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"System Events\" to key code 36"]
            
            do {
                try process.run()
                process.waitUntilExit()
                print("[Insert] Enter sent via osascript, exit code: \(process.terminationStatus)")
            } catch {
                print("[Insert] osascript error: \(error)")
            }
        }
    }
    
    func showOverlayNearCursor() {
        print("[Overlay] Showing overlay at bottom center...")
        positionOverlayAtBottom()
        showOverlay()
    }
    
    func moveOverlayToMouse() {
        positionOverlayAtBottom()
    }
    
    // MARK: - Permissions
    func requestPermissions() {
        if !permissionManager.isAccessibilityTrusted {
            permissionManager.promptForAccessibility()
        }
        permissionManager.requestMicrophoneAccess()
    }
    
    // MARK: - Menu Bar
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "pdf"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
                button.imageScaling = .scaleProportionallyDown
            } else {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "GhosTYPE")
            }
            
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "GhosTYPE", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        let hotkeyItem = NSMenuItem(title: "快捷键: \(AppSettings.shared.hotkeyDisplay)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let dashboardItem = NSMenuItem(title: "打开 Dashboard", action: #selector(showDashboard), keyEquivalent: "d")
        dashboardItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        menu.addItem(dashboardItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let accessibilityItem = NSMenuItem(
            title: permissionManager.isAccessibilityTrusted ? "辅助功能权限" : "辅助功能权限 (点击开启)",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.image = NSImage(systemSymbolName: permissionManager.isAccessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle", accessibilityDescription: nil)
        menu.addItem(accessibilityItem)
        
        let micItem = NSMenuItem(
            title: permissionManager.isMicrophoneGranted ? "麦克风权限" : "麦克风权限 (点击开启)",
            action: #selector(requestMic),
            keyEquivalent: ""
        )
        micItem.image = NSImage(systemSymbolName: permissionManager.isMicrophoneGranted ? "checkmark.circle.fill" : "xmark.circle", accessibilityDescription: nil)
        menu.addItem(micItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let devMenu = NSMenu(title: "开发者工具")
        let devItem = NSMenuItem(title: "开发者工具", action: nil, keyEquivalent: "")
        devItem.submenu = devMenu
        
        let overlayTestItem = NSMenuItem(title: "Overlay 动画测试", action: #selector(showOverlayTestWindow), keyEquivalent: "t")
        overlayTestItem.keyEquivalentModifierMask = [.command, .shift]
        devMenu.addItem(overlayTestItem)
        
        menu.addItem(devItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            statusItem.button?.performClick(nil)
        } else {
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
    
    @objc func showOverlayTestWindow() {
        OverlayTestWindowController.shared.show()
    }
    
    // MARK: - Overlay Window
    func setupOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        
        let windowWidth = screen.frame.width * 0.35
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
        
        positionOverlayAtBottom()
    }
    
    func positionOverlayAtBottom() {
        guard let screen = NSScreen.main else { return }
        
        let windowWidth = overlayWindow.frame.width
        let x = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
        let dockHeight = screen.visibleFrame.origin.y - screen.frame.origin.y
        let y = screen.frame.origin.y + dockHeight + 20
        
        overlayWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func moveOverlay(to bounds: CGRect) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) }) ?? NSScreen.main else { return }
        
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
