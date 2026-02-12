import Cocoa
import Carbon

/// 全局快捷键管理器 - 按住说话，松开插入文字
/// 支持动态修饰键检测 + 500ms 粘连延迟
/// 
/// 单独修饰键触发逻辑（类似 Karabiner-Elements 的 to_if_alone）：
/// - 按下修饰键时不立即触发，等待 debounce 时间
/// - 如果在 debounce 时间内：
///   - 松开了修饰键 → 不触发（太快，可能是误触）
///   - 按了其他普通键 → 不触发，让事件正常传递（是组合键）
///   - 按了其他修饰键 → 继续等待
/// - 如果 debounce 时间到且修饰键仍按着 → 触发录音
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // MARK: - Callbacks (Skill-based)
    
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: ((SkillModel?) -> Void)?
    var onSkillChanged: ((SkillModel?) -> Void)?
    
    // MARK: - State
    
    private var isHotkeyPressed = false
    private(set) var currentSkill: SkillModel? = nil
    
    /// 模式粘连：记录最后一次非默认 Skill 的时间
    private var lastNonDefaultSkillTime: Date?
    /// 粘连延迟时间（毫秒）
    private let stickyDelayMs: Double = 500
    
    /// 防止误触发：延迟确认单独修饰键按下
    private var pendingModifierDown: DispatchWorkItem?
    /// 延迟时间（毫秒）- 用于区分单独按修饰键和组合键
    private let modifierDebounceMs: Double = 300
    /// 记录修饰键按下时的状态，用于 debounce 后检查
    private var pendingModifiers: NSEvent.ModifierFlags = []
    
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
        FileLogger.log("[Hotkey] Sticky delay: \(stickyDelayMs)ms, Debounce: \(modifierDebounceMs)ms")
        
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
        cancelPendingModifier()
    }
    
    private func cancelPendingModifier() {
        pendingModifierDown?.cancel()
        pendingModifierDown = nil
        pendingModifiers = []
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
            return handleModifierOnlyHotkey(type: type, keyCode: keyCode, modifiers: modifiers, event: event)
        }
        
        // ========== 情况2: 快捷键是 修饰键+普通键（如 Option+Space）==========
        return handleModifierPlusKeyHotkey(type: type, keyCode: keyCode, modifiers: modifiers, event: event)
    }
    
    /// 处理单独修饰键作为快捷键的情况
    private func handleModifierOnlyHotkey(type: CGEventType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        
        // 处理 flagsChanged 事件（修饰键按下/松开）
        if type == .flagsChanged {
            let isTargetPressed = isModifierKeyPressed(keyCode: targetKeyCode, modifiers: modifiers)
            
            // 目标修饰键刚按下
            if isTargetPressed && !isHotkeyPressed && pendingModifierDown == nil {
                pendingModifiers = modifiers
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.pendingModifierDown = nil
                    
                    // debounce 时间到，确认触发录音
                    guard !self.isHotkeyPressed else { return }
                    
                    self.isHotkeyPressed = true
                    self.currentSkill = self.getSkillFromModifiers(self.pendingModifiers)
                    self.lastNonDefaultSkillTime = nil
                    self.pendingModifiers = []
                    let skillName = self.currentSkill?.name ?? "润色"
                    FileLogger.log("[Hotkey] ✅ DOWN (after \(self.modifierDebounceMs)ms debounce), skill: \(skillName)")
                    self.onHotkeyDown?()
                }
                pendingModifierDown = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + modifierDebounceMs / 1000, execute: workItem)
                FileLogger.log("[Hotkey] ⏳ Modifier down, waiting \(modifierDebounceMs)ms...")
                return Unmanaged.passRetained(event)
            }
            
            // 目标修饰键松开
            if !isTargetPressed {
                // 情况A: 在 debounce 期间松开 → 取消，不触发
                if pendingModifierDown != nil {
                    cancelPendingModifier()
                    FileLogger.log("[Hotkey] ⏭️ Modifier released within debounce, cancelled")
                    return Unmanaged.passRetained(event)
                }
                
                // 情况B: 已经在录音中 → 正常结束
                if isHotkeyPressed {
                    isHotkeyPressed = false
                    let finalSkill = getStickySkill()
                    let skillName = finalSkill?.name ?? "润色"
                    FileLogger.log("[Hotkey] ✅ UP, final skill: \(skillName)")
                    DispatchQueue.main.async { self.onHotkeyUp?(finalSkill) }
                    currentSkill = nil
                    lastNonDefaultSkillTime = nil
                    return nil
                }
            }
            
            // 录音中，其他修饰键变化 → 检测 Skill 切换
            if isHotkeyPressed {
                let newSkill = getSkillFromModifiers(modifiers)
                if newSkill != nil {
                    lastNonDefaultSkillTime = Date()
                }
                if newSkill?.id != currentSkill?.id {
                    currentSkill = newSkill
                    let skillName = newSkill?.name ?? "润色"
                    FileLogger.log("[Hotkey] 🔄 Skill: \(skillName)")
                    DispatchQueue.main.async { self.onSkillChanged?(newSkill) }
                }
            }
            
            // debounce 期间，其他修饰键变化 → 更新记录的修饰键状态
            if pendingModifierDown != nil {
                pendingModifiers = modifiers
            }
            
            return Unmanaged.passRetained(event)
        }
        
        // 处理 keyDown 事件（普通键按下）
        if type == .keyDown {
            // 在 debounce 期间按了其他普通键 → 取消触发，让事件正常传递
            if pendingModifierDown != nil {
                cancelPendingModifier()
                FileLogger.log("[Hotkey] ⏭️ Other key pressed (keyCode=\(keyCode)) during debounce, cancelled - passing through")
                // 不拦截事件，让它正常传递给其他应用
                return Unmanaged.passRetained(event)
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    /// 处理修饰键+普通键组合的快捷键
    private func handleModifierPlusKeyHotkey(type: CGEventType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        let targetMods = targetModifiers.intersection([.command, .option, .control, .shift, .function])
        let currentMods = modifiers.intersection([.command, .option, .control, .shift, .function])
        let hasRequiredModifiers = targetMods.isEmpty || currentMods.contains(targetMods)
        
        if type == .keyDown && keyCode == targetKeyCode && hasRequiredModifiers && !isHotkeyPressed {
            isHotkeyPressed = true
            currentSkill = getSkillFromModifiers(modifiers)
            lastNonDefaultSkillTime = nil
            let skillName = currentSkill?.name ?? "润色"
            FileLogger.log("[Hotkey] ✅ DOWN: key=\(keyCode), skill: \(skillName)")
            DispatchQueue.main.async { self.onHotkeyDown?() }
            return nil
        }
        
        if type == .keyUp && keyCode == targetKeyCode && isHotkeyPressed {
            isHotkeyPressed = false
            let finalSkill = getStickySkill()
            let skillName = finalSkill?.name ?? "润色"
            FileLogger.log("[Hotkey] ✅ UP: key=\(keyCode), skill: \(skillName)")
            DispatchQueue.main.async { self.onHotkeyUp?(finalSkill) }
            currentSkill = nil
            lastNonDefaultSkillTime = nil
            return nil
        }
        
        if type == .flagsChanged && isHotkeyPressed {
            if !hasRequiredModifiers {
                isHotkeyPressed = false
                let finalSkill = getStickySkill()
                let skillName = finalSkill?.name ?? "润色"
                FileLogger.log("[Hotkey] ✅ Modifier released, UP, skill: \(skillName)")
                DispatchQueue.main.async { self.onHotkeyUp?(finalSkill) }
                currentSkill = nil
                lastNonDefaultSkillTime = nil
            } else {
                let newSkill = getSkillFromModifiers(modifiers)
                if newSkill != nil {
                    lastNonDefaultSkillTime = Date()
                }
                if newSkill?.id != currentSkill?.id {
                    currentSkill = newSkill
                    let skillName = newSkill?.name ?? "润色"
                    FileLogger.log("[Hotkey] 🔄 Skill: \(skillName)")
                    DispatchQueue.main.async { self.onSkillChanged?(newSkill) }
                }
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    /// 获取粘连 Skill：如果在延迟时间内曾经是非默认 Skill，则保持该 Skill
    private func getStickySkill() -> SkillModel? {
        if currentSkill != nil {
            let skillName = currentSkill?.name ?? "润色"
            FileLogger.log("[Hotkey] Sticky: current skill is \(skillName)")
            return currentSkill
        }
        
        if let lastTime = lastNonDefaultSkillTime {
            let elapsed = Date().timeIntervalSince(lastTime) * 1000
            FileLogger.log("[Hotkey] Sticky: elapsed=\(elapsed)ms, delay=\(stickyDelayMs)ms")
            if elapsed < stickyDelayMs {
                FileLogger.log("[Hotkey] Sticky: within delay, keeping non-default skill")
            }
        }
        
        return currentSkill
    }
    
    /// 通过修饰键查询 SkillManager 获取对应 Skill
    /// nil = 默认润色行为
    private func getSkillFromModifiers(_ modifiers: NSEvent.ModifierFlags) -> SkillModel? {
        var extraModifiers = modifiers
        extraModifiers.remove(targetModifiers)
        
        // 通过 SkillManager 查询修饰键绑定
        return SkillManager.shared.skillForModifiers(extraModifiers)
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
