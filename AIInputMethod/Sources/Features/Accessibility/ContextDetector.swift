import ApplicationServices
import Foundation

// MARK: - Context Behavior

/// 上下文行为：根据光标可编辑状态和选中文字决定
enum ContextBehavior {
    case directOutput                       // 可输入 + 无选中
    case rewrite(selectedText: String)      // 可输入 + 有选中
    case explain(selectedText: String)      // 不可输入 + 有选中
    case noInput                            // 不可输入 + 无选中
}

// MARK: - Context Detector

/// 上下文检测器：通过 Accessibility API 检测当前焦点元素状态
class ContextDetector {

    /// 检测当前上下文行为
    func detect() -> ContextBehavior {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard error == .success, let element = focusedElement else {
            // 无法获取焦点元素，视为不可输入 + 无选中
            return .noInput
        }

        let axElement = element as! AXUIElement
        let isEditable = checkIfEditable(element: axElement)
        let selectedText = getSelectedText(element: axElement)

        switch (isEditable, selectedText) {
        case (true, nil), (true, .some("")):
            return .directOutput
        case (true, .some(let text)):
            return .rewrite(selectedText: text)
        case (false, .some(let text)) where !text.isEmpty:
            return .explain(selectedText: text)
        default:
            return .noInput
        }
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
