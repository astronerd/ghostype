import Cocoa
import Carbon

/// 全局快捷键管理器 - 按住说话，松开插入文字
/// 支持动态修饰键检测：
/// - 默认：润色模式
/// - Shift：翻译模式
/// - Cmd：随心记模式
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // MARK: - Callbacks
    
    /// 快捷键按下回调
    var onHotkeyDown: (() -> Void)?
    
    /// 快捷键松开回调，传入当前模式
    var onHotkeyUp: ((InputMode) -> Void)?
    
    /// 模式变化回调（录音过程中修饰键变化）
    var onModeChanged: ((InputMode) -> Void)?
    
    // MARK: - State
    
    private var isHotkeyPressed = false
    
    /// 当前输入模式
    private(set) var currentMode: InputMode = .polish
    
    // 从 AppSettings 读取配置
    private var targetModifiers: NSEvent.ModifierFlags {
        AppSettings.shared.hotkeyModifiers
    }
    private var targetKeyCode: UInt16 {
        AppSettings.shared.hotkeyKeyCode
    }
    
    // 修饰键的 keyCode 列表
    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    
    // MARK: - Public Methods
    
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
        print("[Hotkey] ✅ Modifiers: Shift=翻译, Cmd=随心记")
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
    
    // MARK: - Private Methods
    
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
        let hasTargetModifiers = targetMods.isEmpty || currentMods.contains(targetMods)
        
        // 录音过程中监听修饰键变化
        if type == .flagsChanged && isHotkeyPressed {
            let newMode = InputMode.fromModifiers(modifiers)
            if newMode != currentMode {
                currentMode = newMode
                print("[Hotkey] 🔄 Mode changed to: \(newMode.displayName)")
                DispatchQueue.main.async {
                    self.onModeChanged?(newMode)
                }
            }
        }
        
        // 处理修饰键作为快捷键的情况（比如只按 Option）
        if isModifierKey && type == .flagsChanged {
            let isModifierPressed = isModifierKeyPressed(keyCode: targetKeyCode, modifiers: modifiers)
            
            if isModifierPressed && !isHotkeyPressed {
                isHotkeyPressed = true
                currentMode = InputMode.fromModifiers(modifiers)
                print("[Hotkey] ✅ DOWN (modifier key), mode: \(currentMode.displayName)")
                DispatchQueue.main.async {
                    self.onHotkeyDown?()
                }
                return nil
            } else if !isModifierPressed && isHotkeyPressed {
                isHotkeyPressed = false
                print("[Hotkey] ✅ UP (modifier key), final mode: \(currentMode.displayName)")
                let finalMode = currentMode
                DispatchQueue.main.async {
                    self.onHotkeyUp?(finalMode)
                }
                currentMode = .polish // 重置
                return nil
            }
            return Unmanaged.passRetained(event)
        }
        
        // 处理普通按键（如 Option+Space）
        // keyDown: 只有在修饰键匹配时才触发
        if type == .keyDown && isTargetKey && hasTargetModifiers {
            if !isHotkeyPressed {
                isHotkeyPressed = true
                currentMode = InputMode.fromModifiers(modifiers)
                print("[Hotkey] ✅ DOWN: keyCode=\(keyCode), mods=\(modifiers), mode: \(currentMode.displayName)")
                DispatchQueue.main.async {
                    self.onHotkeyDown?()
                }
            }
            return nil // 吃掉事件
        }
        
        // keyUp: 只要是目标键且正在按住状态，就拦截
        if type == .keyUp && isTargetKey && isHotkeyPressed {
            isHotkeyPressed = false
            print("[Hotkey] ✅ UP: keyCode=\(keyCode), final mode: \(currentMode.displayName)")
            let finalMode = currentMode
            DispatchQueue.main.async {
                self.onHotkeyUp?(finalMode)
            }
            currentMode = .polish // 重置
            return nil // 吃掉事件
        }
        
        // 修饰键变化：如果正在按住且主触发修饰键松开了，也触发 up
        if type == .flagsChanged && isHotkeyPressed && !hasTargetModifiers {
            isHotkeyPressed = false
            print("[Hotkey] ✅ Modifier released, triggering UP, final mode: \(currentMode.displayName)")
            let finalMode = currentMode
            DispatchQueue.main.async {
                self.onHotkeyUp?(finalMode)
            }
            currentMode = .polish // 重置
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
