import Foundation
import AppKit

// MARK: - Menu Bar Manager

/// 菜单栏管理器
/// 从 AppDelegate 提取的菜单栏设置和交互逻辑
class MenuBarManager {

    private(set) var statusItem: NSStatusItem!

    // MARK: - Callbacks

    var onToggleDashboard: (() -> Void)?
    var onShowDashboard: (() -> Void)?
    var onCheckForUpdates: (() -> Void)?
    var onShowOverlayTest: (() -> Void)?
    var onShowSizeDebug: (() -> Void)?

    // MARK: - Setup

    func setup(permissionManager: PermissionManager) {
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
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "GHOSTYPE", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let hotkeyItem = NSMenuItem(title: "\(L.MenuBar.hotkeyPrefix)\(AppSettings.shared.hotkeyDisplay)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        menu.addItem(NSMenuItem.separator())

        let dashboardItem = NSMenuItem(title: L.MenuBar.openDashboard, action: #selector(showDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        dashboardItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        menu.addItem(dashboardItem)

        let checkUpdateItem = NSMenuItem(title: L.MenuBar.checkUpdate, action: #selector(checkForUpdates), keyEquivalent: "u")
        checkUpdateItem.target = self
        checkUpdateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(checkUpdateItem)

        menu.addItem(NSMenuItem.separator())

        let accessibilityItem = NSMenuItem(
            title: permissionManager.isAccessibilityTrusted ? L.MenuBar.accessibilityPerm : L.MenuBar.accessibilityPermClick,
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.image = NSImage(systemSymbolName: permissionManager.isAccessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle", accessibilityDescription: nil)
        menu.addItem(accessibilityItem)

        let micItem = NSMenuItem(
            title: permissionManager.isMicrophoneGranted ? L.MenuBar.micPerm : L.MenuBar.micPermClick,
            action: #selector(requestMic),
            keyEquivalent: ""
        )
        micItem.target = self
        micItem.image = NSImage(systemSymbolName: permissionManager.isMicrophoneGranted ? "checkmark.circle.fill" : "xmark.circle", accessibilityDescription: nil)
        menu.addItem(micItem)

        menu.addItem(NSMenuItem.separator())

        #if DEBUG
        let devMenu = NSMenu(title: L.MenuBar.devTools)
        let devItem = NSMenuItem(title: L.MenuBar.devTools, action: nil, keyEquivalent: "")
        devItem.submenu = devMenu

        let overlayTestItem = NSMenuItem(title: "Overlay Test", action: #selector(showOverlayTestWindow), keyEquivalent: "t")
        overlayTestItem.target = self
        overlayTestItem.keyEquivalentModifierMask = [.command, .shift]
        devMenu.addItem(overlayTestItem)

        let sizeDebugItem = NSMenuItem(title: "Size Debug", action: #selector(showSizeDebugWindow), keyEquivalent: "y")
        sizeDebugItem.target = self
        sizeDebugItem.keyEquivalentModifierMask = [.command, .shift]
        devMenu.addItem(sizeDebugItem)

        menu.addItem(devItem)
        #endif

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L.MenuBar.quit, action: #selector(terminateApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            statusItem.button?.performClick(nil)
        } else {
            onToggleDashboard?()
        }
    }

    @objc private func showDashboard() {
        onShowDashboard?()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates?()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func requestMic() {
        PermissionManager().requestMicrophoneAccess()
    }

    @objc private func showOverlayTestWindow() {
        onShowOverlayTest?()
    }

    @objc private func showSizeDebugWindow() {
        onShowSizeDebug?()
    }

    @objc private func terminateApp() {
        NSApp.terminate(nil)
    }
}
