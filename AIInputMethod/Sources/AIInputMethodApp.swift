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
    var testWindow: NSWindow?
    
    // Sparkle 自动更新
    var updaterController: SPUStandardUpdaterController!
    
    // Ghost Morph: Skill 路由器和上下文检测器
    var skillRouter = SkillRouter()
    var contextDetector = ContextDetector()
    
    @Published var currentMode: InputMode = .polish
    @Published var currentSkill: SkillModel? = nil
    @Published var isVoiceInputEnabled: Bool = false
    private var currentRawText: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    // 等待最终结果的状态
    private var pendingSkill: SkillModel?
    private var waitingForFinalResult = false
    
    // MARK: - URL Scheme Handling
    
    /// 在 applicationWillFinishLaunching 中注册 Apple Event handler
    /// 这是 macOS 上处理 URL scheme 最可靠的方式，比 application(_:open:) 更早注册
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        print("[App] ✅ Registered URL scheme handler via NSAppleEventManager")
    }
    
    /// 处理 ghostype://auth?token={jwt} 回调
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
        
        // 单实例保护：如果已有实例在运行，激活已有实例并退出自己
        let bundleID = Bundle.main.bundleIdentifier ?? "com.gengdawei.ghostype"
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningInstances.count > 1 {
            print("[App] ⚠️ Another instance is already running, activating it and exiting...")
            // 激活已有实例
            if let existing = runningInstances.first(where: { $0 != NSRunningApplication.current }) {
                existing.activate(options: [.activateAllWindows])
            }
            NSApp.terminate(nil)
            return
        }
        
        // 执行数据迁移（枚举 rawValue 中文→英文）
        MigrationService.runIfNeeded()
        
        // 初始化 Sparkle 自动更新
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        print("[App] ✅ Sparkle updater initialized")
        
        // 🔥 先订阅登录/登出通知，确保 Onboarding 期间登录也能正确更新状态
        setupAuthNotifications()
        
        // 从服务器获取 ASR 凭证
        Task {
            do {
                try await speechService.fetchCredentials()
                FileLogger.log("[App] ASR credentials fetched successfully")
            } catch {
                FileLogger.log("[App] ⚠️ Failed to fetch ASR credentials: \(error)")
                // 不崩溃，用户触发录音时会看到"请先配置凭证"提示
            }
        }
        
        permissionManager.checkAccessibilityStatus()
        permissionManager.checkMicrophoneStatus()
        
        print("[App] Accessibility: \(permissionManager.isAccessibilityTrusted)")
        print("[App] Microphone: \(permissionManager.isMicrophoneGranted)")
        
        // 根据登录状态初始化语音输入开关
        isVoiceInputEnabled = AuthManager.shared.isLoggedIn
        print("[App] Voice input enabled: \(isVoiceInputEnabled) (logged in: \(AuthManager.shared.isLoggedIn))")
        
        // 检查是否需要显示 onboarding
        let onboardingRequiredVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let lastOnboardingVersion = UserDefaults.standard.string(forKey: "lastOnboardingVersion") ?? "0.0"
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
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
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(currentVersion, forKey: "lastOnboardingVersion")
            self?.startApp()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                DashboardWindowController.shared.show()
            }
        }
    }
    
    // MARK: - Auth Notifications
    
    func setupAuthNotifications() {
        NotificationCenter.default.publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isVoiceInputEnabled = true
                print("[App] ✅ User logged in, voice input enabled")
                Task { try? await self.speechService.fetchCredentials() }
                Task { await QuotaManager.shared.refresh() }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isVoiceInputEnabled = false
                print("[App] ⚠️ User logged out, voice input disabled")
            }
            .store(in: &cancellables)
        
        print("[App] ✅ Auth notifications subscribed")
    }
    
    func startApp() {
        print("[App] ========== STARTING APP ==========")
        
        // 🔥 Ghost Morph: 初始化 Skill 系统
        SkillMigrationService.migrateIfNeeded()
        SkillManager.shared.ensureBuiltinSkills()
        SkillManager.shared.loadAllSkills()
        FileLogger.log("[App] Skill system initialized, \(SkillManager.shared.skills.count) skills loaded")
        
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
            if self.waitingForFinalResult, let skill = self.pendingSkill {
                FileLogger.log("[Speech] Processing immediately after final result")
                self.waitingForFinalResult = false
                self.pendingSkill = nil
                self.processWithSkill(skill, speechText: text)
            } else if self.waitingForFinalResult {
                // pendingSkill == nil 表示默认润色
                FileLogger.log("[Speech] Processing immediately after final result (default polish)")
                self.waitingForFinalResult = false
                self.pendingSkill = nil
                self.processWithSkill(nil, speechText: text)
            }
        }
        
        speechService.onPartialResult = { text in
            FileLogger.log("[Speech] Partial result (流式): \(text)")
        }
        
        // 🔥 启动时预加载通讯录热词缓存
        if AppSettings.shared.enableContactsHotwords {
            ContactsManager.shared.refreshCache()
        }
        
        print("[App] ========== APP STARTED ==========")
        print("[App] AI Polish: \(AppSettings.shared.enableAIPolish ? "ON" : "OFF")")
    }
    
    // MARK: - Hotkey
    func setupHotkey() {
        hotkeyManager.onHotkeyDown = { [weak self] in
            guard let self = self else { return }
            
            // 登录状态守卫：未登录时显示提示并拒绝录音
            guard self.isVoiceInputEnabled else {
                print("[Hotkey] ⚠️ Voice input disabled (not logged in)")
                self.showOverlayNearCursor()
                OverlayStateManager.shared.setLoginRequired()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.hideOverlay()
                }
                return
            }
            
            print("[Hotkey] ========== DOWN ==========")
            let skill = self.hotkeyManager.currentSkill
            let skillName = skill?.name ?? "润色"
            print("[Hotkey] Starting recording, skill: \(skillName)")
            self.currentSkill = skill
            self.currentRawText = ""
            self.waitingForFinalResult = false
            self.pendingSkill = nil
            self.showOverlayNearCursor()
            self.speechService.startRecording()
            
            // 设置录音状态（使用 Skill 信息）
            OverlayStateManager.shared.setRecording(skill: skill)
        }
        
        hotkeyManager.onSkillChanged = { [weak self] skill in
            guard let self = self else { return }
            let skillName = skill?.name ?? "润色"
            print("[Hotkey] Skill changed to: \(skillName)")
            self.currentSkill = skill
            
            // 更新录音状态
            OverlayStateManager.shared.setRecording(skill: skill)
        }
        
        hotkeyManager.onHotkeyUp = { [weak self] skill in
            guard let self = self else { return }
            print("[Hotkey] ========== UP ==========")
            let skillName = skill?.name ?? "润色"
            print("[Hotkey] Stopping recording, final skill: \(skillName)")
            self.speechService.stopRecording()
            
            // 设置处理状态
            OverlayStateManager.shared.setProcessing(skill: skill)
            
            // 🔥 等待二遍识别完成后再处理
            if !self.currentRawText.isEmpty {
                FileLogger.log("[Hotkey] Final result already available, processing now")
                self.processWithSkill(skill, speechText: self.currentRawText)
            } else {
                FileLogger.log("[Hotkey] Waiting for final result (二遍识别)...")
                self.waitingForFinalResult = true
                self.pendingSkill = skill
                
                // 超时保护：最多等 3 秒
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, self.waitingForFinalResult else { return }
                    FileLogger.log("[Hotkey] ⚠️ Timeout waiting for final result")
                    self.waitingForFinalResult = false
                    let pendingSkill = self.pendingSkill
                    self.pendingSkill = nil
                    self.processWithSkill(pendingSkill, speechText: self.currentRawText)
                }
            }
        }
        
        print("[App] Starting hotkey manager...")
        hotkeyManager.start()
        print("[App] Hotkey manager started")
    }
    
    // MARK: - AI Processing (Skill-based)
    
    /// 通过 Skill 系统处理语音文本
    /// nil skill = 默认润色行为
    func processWithSkill(_ skill: SkillModel?, speechText: String) {
        let text = speechText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            FileLogger.log("[Process] Empty text, skipping")
            hideOverlay()
            return
        }
        
        // nil skill = 默认润色，走原有 processWithMode(.polish) 逻辑
        guard let skill = skill else {
            FileLogger.log("[Process] No skill (default polish)")
            processWithMode(.polish)
            return
        }
        
        let skillName = skill.name
        FileLogger.log("[Process] Processing with skill: \(skillName), type: \(skill.skillType.rawValue)")
        FileLogger.log("[Process] Raw text: \(text)")
        
        // Memo 特殊处理：直接保存，不走 SkillRouter
        if skill.skillType == .memo {
            processMemo(text)
            return
        }
        
        // 通过 SkillRouter 执行
        Task { @MainActor in
            await self.skillRouter.execute(
                skill: skill,
                speechText: text,
                onDirectOutput: { [weak self] result in
                    guard let self = self else { return }
                    self.insertTextAtCursor(result)
                    self.saveUsageRecord(content: result, category: self.categoryForSkill(skill))
                    Task { await QuotaManager.shared.reportAndRefresh(characters: result.count) }
                    NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
                    OverlayStateManager.shared.setCommitting(type: .textInput)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.hideOverlay()
                    }
                },
                onRewrite: { [weak self] result in
                    guard let self = self else { return }
                    // Rewrite: 替换选中文字（目前用 insertTextAtCursor 实现）
                    self.insertTextAtCursor(result)
                    self.saveUsageRecord(content: result, category: self.categoryForSkill(skill))
                    Task { await QuotaManager.shared.reportAndRefresh(characters: result.count) }
                    NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
                    OverlayStateManager.shared.setCommitting(type: .textInput)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.hideOverlay()
                    }
                },
                onFloatingCard: { [weak self] result, speechText, skill in
                    guard let self = self else { return }
                    self.hideOverlay()
                    FloatingResultCardController.shared.show(
                        skill: skill,
                        speechText: speechText,
                        result: result,
                        near: nil
                    )
                },
                onError: { [weak self] error, behavior in
                    guard let self = self else { return }
                    FileLogger.log("[Process] Skill error: \(error.localizedDescription)")
                    // 错误已在 SkillRouter 内部处理（回退原文或显示错误卡片）
                    OverlayStateManager.shared.setCommitting(type: .textInput)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.hideOverlay()
                    }
                }
            )
        }
    }
    
    /// Skill 类型 → RecordCategory 映射
    private func categoryForSkill(_ skill: SkillModel) -> RecordCategory {
        switch skill.skillType {
        case .polish, .ghostCommand, .ghostTwin, .custom: return .polish
        case .translate: return .translate
        case .memo: return .memo
        }
    }
    
    // MARK: - AI Processing (Legacy - backward compatible)
    
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
                processPolish(text)
            } else {
                FileLogger.log("[Process] AI Polish OFF, inserting raw text")
                insertTextAtCursor(text)
                saveUsageRecord(content: text, category: .polish)
                Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
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
        print("[Polish] Starting AI polish with GhostypeAPI...")
        
        let settings = AppSettings.shared
        
        let polishThreshold = settings.polishThreshold
        if text.count < polishThreshold {
            print("[Polish] Text too short (\(text.count) < \(polishThreshold)), skipping AI")
            FileLogger.log("[Polish] Text too short (\(text.count) < \(polishThreshold)), returning original")
            insertTextAtCursor(text)
            saveUsageRecord(content: text, category: .polish)
            Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.hideOverlay()
            }
            return
        }
        
        let currentBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        FileLogger.log("[Polish] Current app BundleID: \(currentBundleId ?? "nil")")
        
        let viewModel = AIPolishViewModel()
        let resolved = viewModel.resolveProfile(for: currentBundleId)
        FileLogger.log("[Polish] Using profile: \(resolved.profile.rawValue), customPrompt: \(resolved.customPrompt != nil)")
        
        Task { @MainActor in
            do {
                let polishedText = try await GhostypeAPIClient.shared.polish(
                    text: text,
                    profile: resolved.profile.rawValue,
                    customPrompt: resolved.customPrompt,
                    enableInSentence: settings.enableInSentencePatterns,
                    enableTrigger: settings.enableTriggerCommands,
                    triggerWord: settings.triggerWord
                )
                print("[Polish] Success: \(polishedText)")
                self.insertTextAtCursor(polishedText)
                self.saveUsageRecord(content: polishedText, category: .polish)
                Task { await QuotaManager.shared.reportAndRefresh(characters: polishedText.count) }
                NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
            } catch {
                print("[Polish] Error: \(error.localizedDescription)")
                FileLogger.log("[Polish] API error: \(error.localizedDescription), falling back to original text")
                self.insertTextAtCursor(text)
            }
            
            OverlayStateManager.shared.setCommitting(type: .textInput)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.hideOverlay()
            }
        }
    }
    
    private func processTranslate(_ text: String) {
        print("[Translate] Starting AI translate with GhostypeAPI...")
        
        let settings = AppSettings.shared
        
        Task { @MainActor in
            do {
                let translatedText = try await GhostypeAPIClient.shared.translate(
                    text: text,
                    language: settings.translateLanguage.rawValue
                )
                print("[Translate] Success: \(translatedText)")
                self.insertTextAtCursor(translatedText)
                self.saveUsageRecord(content: translatedText, category: .translate)
                Task { await QuotaManager.shared.reportAndRefresh(characters: translatedText.count) }
                NotificationCenter.default.post(name: .ghostTwinStatusShouldRefresh, object: nil)
            } catch {
                print("[Translate] Error: \(error.localizedDescription)")
                FileLogger.log("[Translate] API error: \(error.localizedDescription), falling back to original text")
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
        Task { await QuotaManager.shared.reportAndRefresh(characters: text.count) }
        
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
        
        let frontAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let shouldAutoEnter = AppSettings.shared.shouldAutoEnter(for: frontAppBundleId)
        let sendMethod = AppSettings.shared.sendMethod(for: frontAppBundleId)
        FileLogger.log("[Insert] Front app: \(frontAppBundleId ?? "unknown"), Auto-enter: \(shouldAutoEnter), Method: \(sendMethod.rawValue)")
        
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
                
                if shouldAutoEnter {
                    self?.sendKey(method: sendMethod)
                }
                
                print("[Insert] ========== DONE ==========")
            }
        }
    }
    
    private func sendKey(method: SendMethod) {
        print("[Insert] Sending \(method.displayName) via osascript...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let script: String
            switch method {
            case .enter:
                script = "tell application \"System Events\" to key code 36"
            case .cmdEnter:
                script = "tell application \"System Events\" to key code 36 using command down"
            case .shiftEnter:
                script = "tell application \"System Events\" to key code 36 using shift down"
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            do {
                try process.run()
                process.waitUntilExit()
                print("[Insert] \(method.displayName) sent via osascript, exit code: \(process.terminationStatus)")
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
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "GHOSTYPE")
            }
            
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "GHOSTYPE", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        let hotkeyItem = NSMenuItem(title: "快捷键: \(AppSettings.shared.hotkeyDisplay)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let dashboardItem = NSMenuItem(title: "打开 Dashboard", action: #selector(showDashboard), keyEquivalent: "d")
        dashboardItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        menu.addItem(dashboardItem)
        
        let checkUpdateItem = NSMenuItem(title: "检查更新...", action: #selector(checkForUpdates), keyEquivalent: "u")
        checkUpdateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(checkUpdateItem)
        
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
    
    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
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
