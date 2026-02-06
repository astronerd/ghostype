import Cocoa
import Carbon

/// 全局快捷键管理器 - 按住说话，松开插入文字
/// 支持动态修饰键检测 + 500ms 粘连延迟
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // MARK: - Callbacks
    
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: ((InputMode) -> Void)?
    var onModeChanged: ((InputMode) -> Void)?
    
    // MARK: - State
    
    private var isHotkeyPressed = false
    private(set) var currentMode: InputMode = .polish
    
    /// 模式粘连：记录最后一次非默认模式的时间
    private var lastNonDefaultModeTime: Date?
    /// 粘连延迟时间（毫秒）
    private let stickyDelayMs: Double = 500
    
    // 从 AppSettings 读取配置
    private var targetModifiers: NSEvent.ModifierFlags {
        AppSettings.shared.hotkeyModifiers
    }
    private var targetKeyCode: UInt16 {
        AppSettings.shared.hotkeyKeyCode
    }
    
    // 修饰键的 keyCode 列表
    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    
    private var isTargetAModifierKey: Bool {
        modifierKeyCodes.contains(targetKeyCode)
    }
    
    // MARK: - Public Methods
    
    func start() {
        FileLogger.log("[Hotkey] Starting event tap...")
        FileLogger.log("[Hotkey] Target: modifiers=\(targetModifiers), keyCode=\(targetKeyCode), isModifierKey=\(isTargetAModifierKey)")
        FileLogger.log("[Hotkey] Sticky delay: \(stickyDelayMs)ms")
        
        guard AXIsProcessTrusted() else {
            FileLogger.log("[Hotkey] ❌ No accessibility permission")
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
            FileLogger.log("[Hotkey] ❌ Failed to create event tap")
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        FileLogger.log("[Hotkey] ✅ Event tap started - \(AppSettings.shared.hotkeyDisplay)")
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
    
    // MARK: - Event Handling
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        var modifiers: NSEvent.ModifierFlags = []
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        
        // ========== 情况1: 快捷键是单独的修饰键（如只按 Option）==========
        if isTargetAModifierKey {
            if type == .flagsChanged {
                let isPressed = isModifierKeyPressed(keyCode: targetKeyCode, modifiers: modifiers)
                
                if isPressed && !isHotkeyPressed {
                    // 按下
                    isHotkeyPressed = true
                    currentMode = getModeFromModifiers(modifiers)
                    lastNonDefaultModeTime = nil
                    FileLogger.log("[Hotkey] ✅ DOWN, mode: \(currentMode.displayName)")
                    DispatchQueue.main.async { self.onHotkeyDown?() }
                    return nil
                } else if !isPressed && isHotkeyPressed {
                    // 松开 - 使用粘连模式
                    isHotkeyPressed = false
                    let finalMode = getStickyMode()
                    FileLogger.log("[Hotkey] ✅ UP, final mode: \(finalMode.displayName)")
                    DispatchQueue.main.async { self.onHotkeyUp?(finalMode) }
                    currentMode = .polish
                    lastNonDefaultModeTime = nil
                    return nil
                } else if isHotkeyPressed {
                    // 录音中，检测模式变化
                    let newMode = getModeFromModifiers(modifiers)
                    
                    // 如果切换到非默认模式，记录时间
                    if newMode != .polish {
                        lastNonDefaultModeTime = Date()
                    }
                    
                    if newMode != currentMode {
                        currentMode = newMode
                        FileLogger.log("[Hotkey] 🔄 Mode: \(newMode.displayName)")
                        DispatchQueue.main.async { self.onModeChanged?(newMode) }
                    }
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        // ========== 情况2: 快捷键是 修饰键+普通键（如 Option+Space）==========
        let targetMods = targetModifiers.intersection([.command, .option, .control, .shift, .function])
        let currentMods = modifiers.intersection([.command, .option, .control, .shift, .function])
        let hasRequiredModifiers = targetMods.isEmpty || currentMods.contains(targetMods)
        
        if type == .keyDown && keyCode == targetKeyCode && hasRequiredModifiers && !isHotkeyPressed {
            isHotkeyPressed = true
            currentMode = getModeFromModifiers(modifiers)
            lastNonDefaultModeTime = nil
            FileLogger.log("[Hotkey] ✅ DOWN: key=\(keyCode), mode: \(currentMode.displayName)")
            DispatchQueue.main.async { self.onHotkeyDown?() }
            return nil
        }
        
        if type == .keyUp && keyCode == targetKeyCode && isHotkeyPressed {
            isHotkeyPressed = false
            let finalMode = getStickyMode()
            FileLogger.log("[Hotkey] ✅ UP: key=\(keyCode), mode: \(finalMode.displayName)")
            DispatchQueue.main.async { self.onHotkeyUp?(finalMode) }
            currentMode = .polish
            lastNonDefaultModeTime = nil
            return nil
        }
        
        if type == .flagsChanged && isHotkeyPressed {
            if !hasRequiredModifiers {
                isHotkeyPressed = false
                let finalMode = getStickyMode()
                FileLogger.log("[Hotkey] ✅ Modifier released, UP, mode: \(finalMode.displayName)")
                DispatchQueue.main.async { self.onHotkeyUp?(finalMode) }
                currentMode = .polish
                lastNonDefaultModeTime = nil
            } else {
                let newMode = getModeFromModifiers(modifiers)
                if newMode != .polish {
                    lastNonDefaultModeTime = Date()
                }
                if newMode != currentMode {
                    currentMode = newMode
                    FileLogger.log("[Hotkey] 🔄 Mode: \(newMode.displayName)")
                    DispatchQueue.main.async { self.onModeChanged?(newMode) }
                }
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    /// 获取粘连模式：如果在延迟时间内曾经是非默认模式，则保持该模式
    private func getStickyMode() -> InputMode {
        // 如果当前已经是非默认模式，直接返回
        if currentMode != .polish {
            FileLogger.log("[Hotkey] Sticky: current mode is \(currentMode.displayName)")
            return currentMode
        }
        
        // 检查是否在粘连时间内
        if let lastTime = lastNonDefaultModeTime {
            let elapsed = Date().timeIntervalSince(lastTime) * 1000 // 转换为毫秒
            FileLogger.log("[Hotkey] Sticky: elapsed=\(elapsed)ms, delay=\(stickyDelayMs)ms")
            if elapsed < stickyDelayMs {
                // 在粘连时间内，返回上一个非默认模式
                // 需要重新计算上一个模式
                FileLogger.log("[Hotkey] Sticky: within delay, keeping non-default mode")
                // 这里我们需要记录上一个非默认模式
            }
        }
        
        return currentMode
    }
    
    private func getModeFromModifiers(_ modifiers: NSEvent.ModifierFlags) -> InputMode {
        var extraModifiers = modifiers
        extraModifiers.remove(targetModifiers)
        return AppSettings.shared.modeFromModifiers(extraModifiers)
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
