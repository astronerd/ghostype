import Foundation
import AppKit

// MARK: - Text Insertion Service

/// 文本插入服务
/// 从 AppDelegate 提取的文本插入逻辑，负责剪贴板→粘贴→自动回车
class TextInsertionService {

    // MARK: - Public API

    /// 将文本插入到当前光标位置
    /// 逻辑与原 AppDelegate.insertTextAtCursor 完全等效
    func insert(_ text: String) {
        print("[Insert] ========== INSERTING ==========")
        print("[Insert] Text: \(text)")

        guard !text.isEmpty else {
            print("[Insert] Empty text, skipping")
            return
        }

        // 检测是否有可输入的光标，没有则弹 FloatingCard
        let context = ContextDetector().detect()
        if case .noInput = context {
            FileLogger.log("[Insert] No input target, showing FloatingCard instead")
            FloatingResultCardController.shared.showText(text: text)
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

                if shouldAutoEnter {
                    self?.sendKey(method: sendMethod)
                }

                print("[Insert] ========== DONE ==========")
            }
        }
    }

    /// 保存使用记录到 CoreData
    func saveUsageRecord(content: String, category: RecordCategory) {
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
