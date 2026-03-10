import Foundation
import AppKit

// MARK: - Text Insertion Service

/// 文本插入服务
/// 从 AppDelegate 提取的文本插入逻辑，负责剪贴板→粘贴→自动回车
class TextInsertionService {

    private let clipboardService = ClipboardService()

    // MARK: - Public API

    /// 将文本插入到当前光标位置
    func insert(_ text: String) {
        print("[Insert] ========== INSERTING ==========")
        print("[Insert] Text: \(text)")

        guard !text.isEmpty else {
            print("[Insert] Empty text, skipping")
            return
        }

        // 不再做二次 ContextDetector 检测
        // 调用方（SkillExecutor / VoiceInputCoordinator）已经决定要插入文本
        // 这里直接执行剪贴板粘贴，避免 Overlay 窗口干扰 AX 焦点检测

        let frontAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let shouldAutoEnter = AppSettings.shared.shouldAutoEnter(for: frontAppBundleId)
        let sendMethod = AppSettings.shared.sendMethod(for: frontAppBundleId)
        FileLogger.log("[Insert] Front app: \(frontAppBundleId ?? "unknown"), Auto-enter: \(shouldAutoEnter), Method: \(sendMethod.rawValue)")

        // 1. 备份当前剪贴板内容
        let backup = clipboardService.backup()
        FileLogger.log("[Insert] Clipboard backed up (\(backup.items.count) items)")

        // 2. 写入要粘贴的文本 + TransientType 标记
        let changeCountAfterWrite = clipboardService.write(text)
        FileLogger.log("[Insert] Clipboard set with TransientType, changeCount: \(changeCountAfterWrite)")

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.TextInsertion.clipboardPasteDelay) { [weak self] in
            print("[Insert] Sending Cmd+V...")
            let source = CGEventSource(stateID: .hidSystemState)

            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) {
                keyDown.flags = .maskCommand
                keyDown.post(tap: .cghidEventTap)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.TextInsertion.keyUpDelay) {
                if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
                    keyUp.flags = .maskCommand
                    keyUp.post(tap: .cghidEventTap)
                }
                print("[Insert] Paste done")

                // 3. changeCount 轮询恢复剪贴板
                self?.scheduleClipboardRestore(
                    backup: backup,
                    expectedChangeCount: changeCountAfterWrite
                )

                if shouldAutoEnter {
                    self?.sendKey(method: sendMethod)
                }

                print("[Insert] ========== DONE ==========")
            }
        }
    }

    // MARK: - Clipboard Restore (changeCount polling)

    /// 等待目标应用读取剪贴板后恢复原始内容
    /// 策略：最小等待 0.5s 后开始轮询 changeCount，确认没有其他程序写入后恢复
    private func scheduleClipboardRestore(
        backup: ClipboardService.BackupToken,
        expectedChangeCount: Int
    ) {
        let minDelay = AppConstants.TextInsertion.clipboardRestoreMinDelay
        let maxTimeout = AppConstants.TextInsertion.clipboardRestoreMaxTimeout
        let startTime = Date()

        // 先等最小延迟，给目标应用足够时间读取
        DispatchQueue.main.asyncAfter(deadline: .now() + minDelay) { [weak self] in
            self?.pollAndRestore(
                backup: backup,
                expectedChangeCount: expectedChangeCount,
                startTime: startTime,
                maxTimeout: maxTimeout
            )
        }
    }

    private func pollAndRestore(
        backup: ClipboardService.BackupToken,
        expectedChangeCount: Int,
        startTime: Date,
        maxTimeout: TimeInterval
    ) {
        let elapsed = Date().timeIntervalSince(startTime)

        // 如果 changeCount 变了，说明其他程序写了剪贴板，不要覆盖
        if clipboardService.changeCount != expectedChangeCount {
            FileLogger.log("[Insert] Clipboard changed by another app (changeCount: \(clipboardService.changeCount) != \(expectedChangeCount)), skip restore")
            return
        }

        // 超时强制恢复
        if elapsed >= maxTimeout {
            FileLogger.log("[Insert] Clipboard restore timeout (\(String(format: "%.1f", elapsed))s), force restoring")
            clipboardService.restore(backup)
            FileLogger.log("[Insert] Clipboard restored")
            return
        }

        // changeCount 没变，说明目标应用已经读完了（或者还没读）
        // 最小延迟已过，可以安全恢复
        FileLogger.log("[Insert] Clipboard restore after \(String(format: "%.1f", elapsed))s")
        clipboardService.restore(backup)
        FileLogger.log("[Insert] Clipboard restored")
    }

    // MARK: - Private

    private func sendKey(method: SendMethod) {
        print("[Insert] Sending \(method.displayName) via osascript...")

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.TextInsertion.autoEnterDelay) {
            let script: String
            switch method {
            case .enter:
                script = "tell application \"System Events\" to key code 36"
            case .cmdEnter:
                script = "tell application \"System Events\" to key code 36 using command down"
            case .shiftEnter:
                script = "tell application \"System Events\" to key code 36 using shift down"
            }

            DispatchQueue.global(qos: .userInitiated).async {
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
    }
}
