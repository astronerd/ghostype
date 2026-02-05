import Cocoa
import Carbon

/// 全局快捷键管理器 - 按住说话，松开插入文字
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?
    
    private var isHotkeyPressed = false
    
    // 从 AppSettings 读取配置
    private var targetModifiers: NSEvent.ModifierFlags {
        AppSettings.shared.hotkeyModifiers
    }
    private var targetKeyCode: UInt16 {
        AppSettings.shared.hotkeyKeyCode
    }
    
    // 修饰键的 keyCode 列表
    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    
    func start() {
        print("[Hotkey] Starting event tap...")
        print("[Hotkey] Target: modifiers=\(targetModifiers), keyCode=\(targetKeyCode)")
        
        // 检查辅助功能权限
        guard AXIsProcessTrusted() else {
            print("[Hotkey] ❌ No accessibility permission, skipping event tap")
            return
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | 
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[Hotkey] ❌ Failed to create event tap.")
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("[Hotkey] ✅ Event tap started - \(AppSettings.shared.hotkeyDisplay) to record")
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // 转换 CGEventFlags 到 NSEvent.ModifierFlags
        var modifiers: NSEvent.ModifierFlags = []
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        
        let isTargetKey = keyCode == targetKeyCode
        let isModifierKey = modifierKeyCodes.contains(targetKeyCode)
        
        // 检查修饰键匹配
        let targetMods = targetModifiers.intersection([.command, .option, .control, .shift, .function])
        let currentMods = modifiers.intersection([.command, .option, .control, .shift, .function])
        let hasTargetModifiers = targetMods.isEmpty || currentMods == targetMods
        
        // 处理修饰键作为快捷键的情况（比如只按 Option）
        if isModifierKey && type == .flagsChanged {
            let isModifierPressed = isModifierKeyPressed(keyCode: targetKeyCode, modifiers: modifiers)
            
            if isModifierPressed && !isHotkeyPressed {
                isHotkeyPressed = true
                DispatchQueue.main.async {
                    self.onHotkeyDown?()
                }
                return nil
            } else if !isModifierPressed && isHotkeyPressed {
                isHotkeyPressed = false
                DispatchQueue.main.async {
                    self.onHotkeyUp?()
                }
                return nil
            }
            return Unmanaged.passRetained(event)
        }
        
        // 处理普通按键（如 Option+Space）
        // keyDown: 只有在修饰键匹配时才触发
        if type == .keyDown && isTargetKey && hasTargetModifiers {
            if !isHotkeyPressed {
                isHotkeyPressed = true
                print("[Hotkey] ✅ DOWN: keyCode=\(keyCode), mods=\(modifiers)")
                DispatchQueue.main.async {
                    self.onHotkeyDown?()
                }
            }
            return nil // 吃掉事件
        }
        
        // keyUp: 只要是目标键且正在按住状态，就拦截
        if type == .keyUp && isTargetKey && isHotkeyPressed {
            isHotkeyPressed = false
            print("[Hotkey] ✅ UP: keyCode=\(keyCode)")
            DispatchQueue.main.async {
                self.onHotkeyUp?()
            }
            return nil // 吃掉事件
        }
        
        // 修饰键变化：如果正在按住且修饰键松开了，也触发 up
        if type == .flagsChanged && isHotkeyPressed && !hasTargetModifiers {
            isHotkeyPressed = false
            print("[Hotkey] ✅ Modifier released, triggering UP")
            DispatchQueue.main.async {
                self.onHotkeyUp?()
            }
            // 不吃掉 flagsChanged 事件
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func isModifierKeyPressed(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 55, 54: return modifiers.contains(.command)
        case 56, 60: return modifiers.contains(.shift)
        case 58, 61: return modifiers.contains(.option)
        case 59, 62: return modifiers.contains(.control)
        case 63: return modifiers.contains(.function)
        default: return false
        }
    }
}
