import ApplicationServices
import AppKit
import Foundation

class CursorManager {
    
    /// 获取光标位置 - 多重回退策略
    func getCursorBounds(for element: AXUIElement? = nil) -> CGRect? {
        // 策略1: 从传入的元素获取
        if let element = element, let bounds = getBoundsFromElement(element) {
            print("[Cursor] ✅ Got bounds from element: \(bounds)")
            return bounds
        }
        
        // 策略2: 从系统焦点元素获取
        if let bounds = getBoundsFromFocusedElement() {
            print("[Cursor] ✅ Got bounds from focused element: \(bounds)")
            return bounds
        }
        
        // 策略3: 使用鼠标位置
        let mousePos = NSEvent.mouseLocation
        print("[Cursor] ⚠️ Fallback to mouse position: \(mousePos)")
        return CGRect(x: mousePos.x, y: convertToAXCoordinate(mousePos.y), width: 1, height: 20)
    }
    
    /// 从指定元素获取光标边界
    private func getBoundsFromElement(_ element: AXUIElement) -> CGRect? {
        // 方法1: kAXBoundsForRangeParameterizedAttribute
        var rangeValue: AnyObject?
        let rangeError = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        
        if rangeError == .success, let range = rangeValue {
            var boundsValue: AnyObject?
            let boundsError = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                range,
                &boundsValue
            )
            
            if boundsError == .success,
               let axValue = boundsValue,
               CFGetTypeID(axValue as CFTypeRef) == AXValueGetTypeID() {
                var rect = CGRect.zero
                if AXValueGetValue(axValue as! AXValue, .cgRect, &rect) {
                    // 验证坐标是否合理
                    if isValidBounds(rect) {
                        return rect
                    }
                }
            }
        }
        
        // 方法2: 使用 kAXInsertionPointLineNumber + 元素位置
        var lineNumber: AnyObject?
        let lineError = AXUIElementCopyAttributeValue(element, "AXInsertionPointLineNumber" as CFString, &lineNumber)
        
        if lineError == .success, let line = lineNumber as? Int {
            if let elementFrame = getElementFrame(element) {
                let lineHeight: CGFloat = 18.0
                let cursorY = elementFrame.origin.y + CGFloat(line) * lineHeight
                let cursorX = elementFrame.origin.x + 10
                return CGRect(x: cursorX, y: cursorY, width: 1, height: lineHeight)
            }
        }
        
        return nil
    }
    
    /// 从系统焦点元素获取
    private func getBoundsFromFocusedElement() -> CGRect? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard error == .success, let element = focusedElement else {
            print("[Cursor] No focused element")
            return nil
        }
        
        return getBoundsFromElement(element as! AXUIElement)
    }
    
    /// 获取元素框架
    private func getElementFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        if let posVal = positionValue, CFGetTypeID(posVal as CFTypeRef) == AXValueGetTypeID() {
            AXValueGetValue(posVal as! AXValue, .cgPoint, &position)
        }
        if let sizeVal = sizeValue, CFGetTypeID(sizeVal as CFTypeRef) == AXValueGetTypeID() {
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        }
        
        return CGRect(origin: position, size: size)
    }
    
    /// 验证边界是否合理
    private func isValidBounds(_ rect: CGRect) -> Bool {
        // 检查是否在屏幕范围内
        guard let screen = NSScreen.main else { return false }
        let screenFrame = screen.frame
        
        // 坐标不能是0,0（通常表示获取失败）
        if rect.origin.x == 0 && rect.origin.y == 0 {
            return false
        }
        
        // 坐标不能超出屏幕太多
        let maxY = screenFrame.height + screenFrame.origin.y + 100
        if rect.origin.y > maxY || rect.origin.y < -100 {
            return false
        }
        
        return true
    }
    
    /// 转换 Cocoa 坐标到 AX 坐标
    private func convertToAXCoordinate(_ y: CGFloat) -> CGFloat {
        guard let screen = NSScreen.main else { return y }
        return screen.frame.height - y
    }
    
    /// 插入文字
    func insertText(_ text: String, into element: AXUIElement) {
        let value = text as AnyObject
        let error = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, value)
        if error != .success {
            print("[Cursor] Failed to set selected text: \(error.rawValue)")
        }
    }
}
