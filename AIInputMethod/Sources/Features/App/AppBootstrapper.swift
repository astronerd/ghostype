import Foundation
import Combine
import AppKit

// MARK: - App Bootstrapper

/// 应用启动协调器
/// 职责：按正确顺序初始化所有核心服务，从 AppDelegate.startApp() 提取
/// 分阶段：Skill 系统 → UI 服务 → 输入服务 → 观察者注册
final class AppBootstrapper {
    private(set) var cancellables = Set<AnyCancellable>()

    func bootstrap(delegate: AppDelegate) {
        bootstrapSkillSystem()
        bootstrapUI(delegate: delegate)
        bootstrapInputServices(delegate: delegate)
        bootstrapObservers(delegate: delegate)
        print("[App] ========== APP STARTED ==========")
        print("[App] AI Polish: \(AppSettings.shared.enableAIPolish ? "ON" : "OFF")")
    }

    // MARK: - Phase 1: Skill System

    private func bootstrapSkillSystem() {
        SkillMigrationService.migrateIfNeeded()
        SkillManager.shared.ensureBuiltinSkills()
        SkillManager.shared.loadAllSkills()
        FileLogger.log("[App] Skill system initialized, \(SkillManager.shared.skills.count) skills loaded")
    }

    // MARK: - Phase 2: UI Services

    private func bootstrapUI(delegate: AppDelegate) {
        // 菜单栏
        delegate.menuBarManager.setup(permissionManager: delegate.permissionManager)
        delegate.menuBarManager.onToggleDashboard = { [weak delegate] in
            delegate?.dashboardController.toggle()
        }
        delegate.menuBarManager.onShowDashboard = { [weak delegate] in
            delegate?.dashboardController.show()
        }
        delegate.menuBarManager.onCheckForUpdates = { [weak delegate] in
            delegate?.updaterController.checkForUpdates(nil)
        }
        NotificationCenter.default.addObserver(
            forName: .checkForUpdates, object: nil, queue: .main
        ) { [weak delegate] _ in
            delegate?.updaterController.checkForUpdates(nil)
        }
        delegate.menuBarManager.onShowOverlayTest = {
            OverlayTestWindowController.shared.show()
        }
        delegate.menuBarManager.onShowSizeDebug = {
            OverlaySizeTestWindowController.shared.show()
        }
        delegate.statusItem = delegate.menuBarManager.statusItem

        // Overlay 窗口
        delegate.overlayManager.setup(speechService: delegate.speechService)
        delegate.overlayWindow = delegate.overlayManager.overlayWindow
        delegate.overlayManager.hide()
        print("[App] UI setup done")
    }

    // MARK: - Phase 3: Input Services

    private func bootstrapInputServices(delegate: AppDelegate) {
        delegate.focusObserver.startObserving()
        print("[App] FocusObserver started")

        // 语音输入协调器（hotkey、speech、auth、tool registry）
        delegate.voiceCoordinator.setup()

        // HID 映射
        delegate.hidMappingManager.hotkeyManager = delegate.hotkeyManager
        delegate.hidMappingManager.restoreAndMonitor()
    }

    // MARK: - Phase 4: Observers

    private func bootstrapObservers(delegate: AppDelegate) {
        // 监听主快捷键变更（keyCode 或 modifiers），同步所有 HID 映射的 targetKeyCode
        Publishers.CombineLatest(AppSettings.shared.$hotkeyKeyCode, AppSettings.shared.$hotkeyModifiers)
            .dropFirst()
            .sink { [weak delegate] newKeyCode, _ in
                delegate?.hidMappingManager.syncTargetKeyCode(UInt32(newKeyCode))
            }
            .store(in: &cancellables)

        // 监听快捷键模式变更，切换 HID 映射策略
        AppSettings.shared.$hotkeyMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak delegate] _ in
                delegate?.hidMappingManager.applyMappingsForCurrentMode()
            }
            .store(in: &cancellables)

        // 启动 Hotkey
        print("[App] Starting hotkey manager...")
        delegate.hotkeyManager.start()
        print("[App] Hotkey manager started")

        // 预加载通讯录热词缓存
        if AppSettings.shared.enableContactsHotwords {
            ContactsManager.shared.refreshCache()
        }
    }
}
