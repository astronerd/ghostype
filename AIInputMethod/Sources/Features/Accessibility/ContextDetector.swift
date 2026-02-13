import ApplicationServices
import Cocoa
import Foundation

// MARK: - Context Behavior

/// 上下文行为：根据光标可编辑状态和选中文字决定
enum ContextBehavior {
    case directOutput                       // 可输入 + 无选中
    case rewrite(selectedText: String)      // 可输入 + 有选中
    case explain(selectedText: String)      // 不可输入 + 有选中
    case noInput                            // 不可输入 + 无选中
}

// MARK: - Context Detection Result

/// 上下文检测结果（含调试信息）
struct ContextDetectionResult {
    let behavior: ContextBehavior
    let debugInfo: String
}

// MARK: - Context Detector

/// 上下文检测器：通过 Accessibility API 检测当前焦点元素状态
class ContextDetector {

    /// 检测当前上下文行为
    func detect() -> ContextBehavior {
        return detectWithDebugInfo().behavior
    }

    /// 检测当前上下文行为（含调试信息）
    func detectWithDebugInfo() -> ContextDetectionResult {
        var debugLines: [String] = []

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard error == .success, let element = focusedElement else {
            debugLines.append("❌ 无法获取焦点元素（error: \(error.rawValue)）")
            return ContextDetectionResult(behavior: .noInput, debugInfo: debugLines.joined(separator: "\n"))
        }

        // CFTypeRef → AXUIElement 安全转换（避免崩溃）
        let axElement = element as! AXUIElement
        guard CFGetTypeID(axElement) == AXUIElementGetTypeID() else {
            debugLines.append("❌ 焦点元素类型不匹配")
            return ContextDetectionResult(behavior: .noInput, debugInfo: debugLines.joined(separator: "\n"))
        }

        // 获取 role
        var role: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role)
        let roleStr = (role as? String) ?? "unknown"
        debugLines.append("✅ 焦点元素 role: \(roleStr)")

        // 获取 app 信息
        var pid: pid_t = 0
        AXUIElementGetPid(axElement, &pid)
        if pid != 0 {
            if let app = NSRunningApplication(processIdentifier: pid) {
                debugLines.append("📱 App: \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?"))")
            }
        }

        let isEditable = checkIfEditable(element: axElement)
        debugLines.append("✏️ 可编辑: \(isEditable)")

        let selectedText = getSelectedText(element: axElement)
        if let sel = selectedText, !sel.isEmpty {
            debugLines.append("📝 选中文字: \(sel.prefix(30))...")
        } else {
            debugLines.append("📝 无选中文字")
        }

        let behavior: ContextBehavior
        switch (isEditable, selectedText) {
        case (true, nil), (true, .some("")):
            behavior = .directOutput
        case (true, .some(let text)):
            behavior = .rewrite(selectedText: text)
        case (false, .some(let text)) where !text.isEmpty:
            behavior = .explain(selectedText: text)
        default:
            behavior = .noInput
        }

        debugLines.append("🎯 behavior: \(behavior)")
        return ContextDetectionResult(behavior: behavior, debugInfo: debugLines.joined(separator: "\n"))
    }

    // MARK: - Private

    /// 检查元素是否可编辑（复用 FocusObserver 的逻辑）
    private func checkIfEditable(element: AXUIElement) -> Bool {
        // Check 1: Is Value Settable?
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        if settable.boolValue { return true }

        // Check 2: Check Role
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let roleStr = role as? String {
            if roleStr == kAXTextAreaRole || roleStr == kAXTextFieldRole || roleStr == kAXComboBoxRole {
                return true
            }
        }

        return false
    }

    /// 获取选中文字
    private func getSelectedText(element: AXUIElement) -> String? {
        var selectedText: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        guard error == .success, let text = selectedText as? String else {
            return nil
        }
        return text
    }
}
