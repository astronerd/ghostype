import SwiftUI
import Combine
import Sparkle

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
        print("[Onboarding] Creating onboarding window...")
        
        let contentView = OnboardingWindow(permissionManager: permissionManager) {
            self.window?.close()
            onComplete()
        }
        
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AppConstants.Window.onboardingSize),
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
        
        print("[Onboarding] Window created, showing...")
        window.makeKeyAndOrderFront(nil)
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        self.window = window
        print("[Onboarding] Window should be visible now. Frame: \(window.frame)")
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
    
    // MARK: - Extracted Services
    let textInserter = TextInsertionService()
    let overlayManager = OverlayWindowManager()
    let menuBarManager = MenuBarManager()
    
    // MARK: - HID
    let hidMappingManager = HIDMappingManager()
    private var cancellables = Set<AnyCancellable>()
    private var bootstrapper: AppBootstrapper?
    
    // Sparkle 自动更新
    var updaterController: SPUStandardUpdaterController!
    
    // Ghost Morph: Skill 执行引擎
    var toolRegistry = ToolRegistry()
    lazy var skillExecutor: SkillExecutor = SkillExecutor(toolRegistry: toolRegistry)
    
    // 语音输入协调器（核心业务逻辑）
    lazy var voiceCoordinator: VoiceInputCoordinator = VoiceInputCoordinator(
        speechService: speechService,
        skillExecutor: skillExecutor,
        toolRegistry: toolRegistry,
        textInserter: textInserter,
        overlayManager: overlayManager,
        hotkeyManager: hotkeyManager
    )
    
    @Published var currentMode: InputMode = .polish
    
    // MARK: - URL Scheme Handling
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        print("[App] ✅ Registered URL scheme handler via NSAppleEventManager")
    }
    
    @objc func handleGetURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("[Auth] ⚠️ Failed to parse URL from Apple Event")
            return
        }
        
        print("[Auth] 📥 Received URL via Apple Event: \(url)")
        
        if url.scheme == "ghostype" && url.host == "auth" {
            AuthManager.shared.handleAuthURL(url)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[App] Launching...")
        
        // 单实例保护
        let bundleID = Bundle.main.bundleIdentifier ?? "com.gengdawei.ghostype"
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningInstances.count > 1 {
            print("[App] ⚠️ Another instance is already running, activating it and exiting...")
            if let existing = runningInstances.first(where: { $0 != NSRunningApplication.current }) {
                existing.activate(options: [.activateAllWindows])
            }
            NSApp.terminate(nil)
            return
        }
        
        // 数据迁移
        MigrationService.runIfNeeded()
        
        // Sparkle 自动更新
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        print("[App] ✅ Sparkle updater initialized")
        
        // 从服务器获取 ASR 凭证
        Task {
            do {
                try await speechService.fetchCredentials()
                FileLogger.log("[App] ASR credentials fetched successfully")
            } catch {
                FileLogger.log("[App] ⚠️ Failed to fetch ASR credentials: \(error)")
            }
        }
        
        permissionManager.checkAccessibilityStatus()
        permissionManager.checkMicrophoneStatus()
        
        print("[App] Accessibility: \(permissionManager.isAccessibilityTrusted)")
        print("[App] Microphone: \(permissionManager.isMicrophoneGranted)")
        
        // 检查是否需要显示 onboarding
        let onboardingRequiredVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let lastOnboardingVersion = UserDefaults.standard.string(forKey: "lastOnboardingVersion") ?? "0.0"
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        let needsOnboarding = !hasCompletedOnboarding || lastOnboardingVersion.compare(onboardingRequiredVersion, options: .numeric) == .orderedAscending
        
        if !needsOnboarding {
            print("[App] Onboarding not required, starting app directly...")
            startApp()
        } else {
            print("[App] Showing onboarding...")
            showPermissionWindow()
        }
    }
    
    func showPermissionWindow() {
        onboardingController.show(permissionManager: permissionManager) { [weak self] in
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(currentVersion, forKey: "lastOnboardingVersion")
            self?.startApp()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                DashboardWindowController.shared.show()
            }
        }
    }
    
    func startApp() {
        print("[App] ========== STARTING APP ==========")
        let b = AppBootstrapper()
        b.bootstrap(delegate: self)
        bootstrapper = b  // retain to keep Combine subscriptions alive
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 退出时清除所有 hidutil remap，恢复外接设备正常
        hidMappingManager.shutdown()
    }

    // MARK: - Permissions
    func requestPermissions() {
        if !permissionManager.isAccessibilityTrusted {
            permissionManager.promptForAccessibility()
        }
        permissionManager.requestMicrophoneAccess()
    }
    
    // MARK: - Overlay (convenience, delegates to OverlayWindowManager)
    
    func moveOverlay(to bounds: CGRect) {
        overlayManager.moveTo(bounds: bounds)
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
        overlayManager.show()
    }
    
    func hideOverlay() {
        overlayManager.hide()
    }
}
