import Cocoa
import Carbon
import Combine

/// 全局快捷键管理器 - 按住说话，松开插入文字
/// 修饰键切换逻辑：录音中按一次修饰键即切换 Skill，不需要按住
/// 连续按多个修饰键，最后一个生效
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Callbacks (Skill-based)

    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: ((SkillModel?) -> Void)?
    var onSkillChanged: ((SkillModel?) -> Void)?
    var onEscCancel: (() -> Void)?

    // MARK: - State

    private var isHotkeyPressed = false
    /// 外部可读：当前是否处于按住状态（HID toggle 模式需要）
    var isHotkeyCurrentlyPressed: Bool { isHotkeyPressed }
    private(set) var currentSkill: SkillModel? = nil

    // MARK: - Combo Key Mode State
    private var pressedKeys: Set<UInt16> = []
    private var activeCombo: ComboHotkey? = nil
    private var cancellables = Set<AnyCancellable>()

    /// 录制快捷键时抑制 hotkey 触发（设置页面录制新快捷键时使用）
    var isSuppressed: Bool = false

    private var pendingModifierDown: DispatchWorkItem?
    private let modifierDebounceMs: Double = AppConstants.Hotkey.modifierDebounceMs
    private var pendingModifiers: NSEvent.ModifierFlags = []

    private var targetModifiers: NSEvent.ModifierFlags {
        AppSettings.shared.hotkeyModifiers
    }
    private var targetKeyCode: UInt16 {
        AppSettings.shared.hotkeyKeyCode
    }

    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    private var isTargetAModifierKey: Bool {
        modifierKeyCodes.contains(targetKeyCode)
    }

    /// 录音中，记录哪些修饰键当前被按下（用于检测"按一次松开"）
    private var activeModifierKeys: Set<UInt16> = []

    // MARK: - Permission Retry
    private var permissionTimer: DispatchSourceTimer?

    // MARK: - Simulate (for HID device mapping — CGEvent post doesn't reach same-process tap)

    /// 外部设备映射触发：模拟快捷键按下
    func simulateHotkeyDown() {
        guard !isHotkeyPressed else { return }
        isHotkeyPressed = true
        currentSkill = nil
        activeModifierKeys = []
        FileLogger.log("[Hotkey] DOWN (HID simulate)")
        onHotkeyDown?()
    }

    /// 外部设备映射触发：模拟快捷键松开
    func simulateHotkeyUp() {
        guard isHotkeyPressed else { return }
        isHotkeyPressed = false
        let finalSkill = currentSkill
        let skillName = finalSkill?.name ?? "polish"
        FileLogger.log("[Hotkey] UP (HID simulate), skill: \(skillName)")
        onHotkeyUp?(finalSkill)
        currentSkill = nil
        activeModifierKeys = []
    }

    // MARK: - Public Methods

    func start() {
        FileLogger.log("[Hotkey] Starting event tap...")
        setupModeSwitchObserver()

        guard AXIsProcessTrusted() else {
            FileLogger.log("[Hotkey] No accessibility permission, starting retry timer...")
            startPermissionRetry()
            return
        }

        setupEventTap()
    }

    /// 权限轮询：每 2 秒检查一次，有权限后自动注册 event tap
    private func startPermissionRetry() {
        stopPermissionRetry()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + AppConstants.Hotkey.permissionRetryInterval, repeating: AppConstants.Hotkey.permissionRetryInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                FileLogger.log("[Hotkey] ✅ Permission granted via retry, setting up event tap")
                self.stopPermissionRetry()
                self.setupEventTap()
            } else {
                FileLogger.log("[Hotkey] Still no permission, retrying in 2s...")
            }
        }
        timer.resume()
        permissionTimer = timer
    }

    private func stopPermissionRetry() {
        permissionTimer?.cancel()
        permissionTimer = nil
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.tapDisabledByTimeout.rawValue)

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
            FileLogger.log("[Hotkey] Failed to create event tap")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        FileLogger.log("[Hotkey] Event tap started - \(AppSettings.shared.hotkeyDisplay)")
    }

    func stop() {
        stopPermissionRetry()
        cancellables.removeAll()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        cancelPendingModifier()
        pressedKeys.removeAll()
        activeCombo = nil
    }

    private func cancelPendingModifier() {
        pendingModifierDown?.cancel()
        pendingModifierDown = nil
        pendingModifiers = []
    }

    // MARK: - Mode Switch Observer

    private func setupModeSwitchObserver() {
        AppSettings.shared.$hotkeyMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleModeSwitchDuringRecording()
            }
            .store(in: &cancellables)
    }

    private func handleModeSwitchDuringRecording() {
        if isHotkeyPressed || activeCombo != nil {
            FileLogger.log("[Hotkey] Mode switched during active recording, cancelling")
            onEscCancel?()
        }
        isHotkeyPressed = false
        currentSkill = nil
        activeModifierKeys = []
        pressedKeys.removeAll()
        activeCombo = nil
        cancelPendingModifier()
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if system disabled it due to timeout
        if type == .tapDisabledByTimeout {
            FileLogger.log("[Hotkey] ⚠️ Event tap disabled by timeout, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // 录制快捷键时，放行所有事件，不触发 hotkey
        if isSuppressed {
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        var modifiers: NSEvent.ModifierFlags = []
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }

        // Branch on hotkey mode
        if AppSettings.shared.hotkeyMode == .comboKey {
            return handleComboKeyEvent(type: type, keyCode: keyCode, modifiers: modifiers, event: event)
        }

        // --- Single Key Mode (existing logic) ---

        // ESC cancel: when recording and ESC keyDown arrives, cancel and swallow the event
        if type == .keyDown && keyCode == 53 && isHotkeyPressed {
            FileLogger.log("[Hotkey] ESC pressed during recording, cancelling")
            isHotkeyPressed = false
            currentSkill = nil
            activeModifierKeys = []
            cancelPendingModifier()
            DispatchQueue.main.async { self.onEscCancel?() }
            return nil  // swallow ESC event
        }

        if isTargetAModifierKey {
            return handleModifierOnlyHotkey(type: type, keyCode: keyCode, modifiers: modifiers, event: event)
        }

        return handleModifierPlusKeyHotkey(type: type, keyCode: keyCode, modifiers: modifiers, event: event)
    }

    // MARK: - Modifier-Only Hotkey

    private func handleModifierOnlyHotkey(type: CGEventType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, event: CGEvent) -> Unmanaged<CGEvent>? {

        if type == .flagsChanged {
            let isTargetPressed = isModifierKeyPressed(keyCode: targetKeyCode, modifiers: modifiers)

            // Target modifier just pressed - start debounce
            if isTargetPressed && !isHotkeyPressed && pendingModifierDown == nil {
                pendingModifiers = modifiers
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.pendingModifierDown = nil
                    guard !self.isHotkeyPressed else { return }

                    self.isHotkeyPressed = true
                    self.currentSkill = nil
                    self.activeModifierKeys = []
                    self.pendingModifiers = []
                    FileLogger.log("[Hotkey] DOWN (after debounce)")
                    self.onHotkeyDown?()
                }
                pendingModifierDown = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + modifierDebounceMs / 1000, execute: workItem)
                return Unmanaged.passRetained(event)
            }

            // Target modifier released
            if !isTargetPressed {
                if pendingModifierDown != nil {
                    cancelPendingModifier()
                    return Unmanaged.passRetained(event)
                }

                if isHotkeyPressed {
                    isHotkeyPressed = false
                    let finalSkill = currentSkill
                    let skillName = finalSkill?.name ?? "polish"
                    FileLogger.log("[Hotkey] UP, final skill: \(skillName)")
                    DispatchQueue.main.async { self.onHotkeyUp?(finalSkill) }
                    currentSkill = nil
                    activeModifierKeys = []
                    return nil
                }
            }

            // During recording: detect modifier key tap for skill switching
            if isHotkeyPressed && modifierKeyCodes.contains(keyCode) && keyCode != targetKeyCode {
                let isDown = isModifierKeyDown(keyCode: keyCode, modifiers: modifiers)
                if isDown {
                    activeModifierKeys.insert(keyCode)
                } else if activeModifierKeys.contains(keyCode) {
                    // Modifier was pressed and now released = "tap" -> switch skill
                    activeModifierKeys.remove(keyCode)
                    if let skill = SkillManager.shared.skillForKeyCode(keyCode) {
                        if skill.id != currentSkill?.id {
                            currentSkill = skill
                            FileLogger.log("[Hotkey] Skill tap (keyCode=\(keyCode)): \(skill.name)")
                            DispatchQueue.main.async { self.onSkillChanged?(skill) }
                        }
                        return nil
                    }
                }
            }

            if pendingModifierDown != nil {
                pendingModifiers = modifiers
            }

            return Unmanaged.passRetained(event)
        }

        // keyDown
        if type == .keyDown {
            if pendingModifierDown != nil {
                cancelPendingModifier()
                return Unmanaged.passRetained(event)
            }

            if isHotkeyPressed {
                // Check if this key is bound to a skill → switch skill
                if let skill = getSkillFromKeyCode(keyCode) {
                    if skill.id != currentSkill?.id {
                        currentSkill = skill
                        FileLogger.log("[Hotkey] Skill via keyDown (keyCode=\(keyCode)): \(skill.name)")
                        DispatchQueue.main.async { self.onSkillChanged?(skill) }
                    }
                    return nil
                }
                // Non-skill key pressed while modifier hotkey held → user wants a shortcut (e.g. Cmd+C)
                // Cancel recording and pass through
                FileLogger.log("[Hotkey] Non-skill keyDown (keyCode=\(keyCode)) during modifier hotkey, cancelling")
                isHotkeyPressed = false
                currentSkill = nil
                activeModifierKeys = []
                DispatchQueue.main.async { self.onEscCancel?() }
                return Unmanaged.passRetained(event)
            }
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Modifier+Key Hotkey

    private func handleModifierPlusKeyHotkey(type: CGEventType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        let targetMods = targetModifiers.intersection([.command, .option, .control, .shift, .function])
        let currentMods = modifiers.intersection([.command, .option, .control, .shift, .function])
        let hasRequiredModifiers = targetMods.isEmpty || currentMods.contains(targetMods)

        if type == .keyDown && keyCode == targetKeyCode && hasRequiredModifiers && !isHotkeyPressed {
            isHotkeyPressed = true
            currentSkill = nil
            activeModifierKeys = []
            FileLogger.log("[Hotkey] DOWN: key=\(keyCode)")
            DispatchQueue.main.async { self.onHotkeyDown?() }
            return nil
        }

        if type == .keyUp && keyCode == targetKeyCode && isHotkeyPressed {
            isHotkeyPressed = false
            let finalSkill = currentSkill
            let skillName = finalSkill?.name ?? "polish"
            FileLogger.log("[Hotkey] UP: key=\(keyCode), skill: \(skillName)")
            DispatchQueue.main.async { self.onHotkeyUp?(finalSkill) }
            currentSkill = nil
            activeModifierKeys = []
            return nil
        }

        if type == .flagsChanged && isHotkeyPressed {
            if !hasRequiredModifiers {
                isHotkeyPressed = false
                let finalSkill = currentSkill
                FileLogger.log("[Hotkey] Modifier released, UP")
                DispatchQueue.main.async { self.onHotkeyUp?(finalSkill) }
                currentSkill = nil
                activeModifierKeys = []
            } else if modifierKeyCodes.contains(keyCode) && keyCode != targetKeyCode {
                // Detect modifier tap for skill switching
                let isDown = isModifierKeyDown(keyCode: keyCode, modifiers: modifiers)
                if isDown {
                    activeModifierKeys.insert(keyCode)
                } else if activeModifierKeys.contains(keyCode) {
                    activeModifierKeys.remove(keyCode)
                    if let skill = SkillManager.shared.skillForKeyCode(keyCode) {
                        if skill.id != currentSkill?.id {
                            currentSkill = skill
                            FileLogger.log("[Hotkey] Skill tap (keyCode=\(keyCode)): \(skill.name)")
                            DispatchQueue.main.async { self.onSkillChanged?(skill) }
                        }
                        return nil
                    }
                }
            }
        }

        // During recording, check keyDown for skill binding
        if type == .keyDown && isHotkeyPressed && keyCode != targetKeyCode {
            if let skill = getSkillFromKeyCode(keyCode) {
                if skill.id != currentSkill?.id {
                    currentSkill = skill
                    FileLogger.log("[Hotkey] Skill via keyDown (keyCode=\(keyCode)): \(skill.name)")
                    DispatchQueue.main.async { self.onSkillChanged?(skill) }
                }
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Combo Key Mode

    private func handleComboKeyEvent(type: CGEventType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        // ESC cancel during active combo recording
        if type == .keyDown && keyCode == 53 && activeCombo != nil {
            FileLogger.log("[Hotkey] ESC pressed during combo recording, cancelling")
            activeCombo = nil
            pressedKeys.removeAll()
            currentSkill = nil
            DispatchQueue.main.async { self.onEscCancel?() }
            return nil  // swallow ESC
        }

        // Determine if this is a key-down or key-up event
        let isKeyDown: Bool
        let isKeyUp: Bool

        if type == .keyDown {
            isKeyDown = true
            isKeyUp = false
        } else if type == .keyUp {
            isKeyDown = false
            isKeyUp = true
        } else if type == .flagsChanged {
            // For modifier keys, check if the key is currently pressed or released
            if modifierKeyCodes.contains(keyCode) {
                let down = isModifierKeyDown(keyCode: keyCode, modifiers: modifiers)
                isKeyDown = down
                isKeyUp = !down
            } else {
                return Unmanaged.passRetained(event)
            }
        } else {
            return Unmanaged.passRetained(event)
        }

        // Track key presses
        if isKeyDown {
            pressedKeys.insert(keyCode)

            // If combo already active, suppress combo key events
            if let combo = activeCombo {
                if keyCode == combo.key1 || keyCode == combo.key2 {
                    return nil
                }
                return Unmanaged.passRetained(event)
            }

            // Check if any registered combo matches (both keys pressed)
            for (combo, skillId) in SkillManager.shared.comboBindings {
                if pressedKeys.contains(combo.key1) && pressedKeys.contains(combo.key2) {
                    if let skill = SkillManager.shared.skills.first(where: { $0.id == skillId }) {
                        activeCombo = combo
                        currentSkill = skill
                        FileLogger.log("[Hotkey] COMBO DOWN: \(combo.key1)+\(combo.key2) → \(skill.name)")
                        DispatchQueue.main.async { self.onHotkeyDown?() }
                        return nil
                    }
                }
            }

            // Check default combo hotkey (triggers default polish, currentSkill = nil)
            if let defaultCombo = AppSettings.shared.defaultComboHotkey {
                FileLogger.log("[Hotkey] Checking default combo: \(defaultCombo.key1)+\(defaultCombo.key2), pressed: \(pressedKeys)")
                if pressedKeys.contains(defaultCombo.key1) && pressedKeys.contains(defaultCombo.key2) {
                    activeCombo = defaultCombo
                    currentSkill = nil
                    FileLogger.log("[Hotkey] DEFAULT COMBO DOWN: \(defaultCombo.key1)+\(defaultCombo.key2)")
                    DispatchQueue.main.async { self.onHotkeyDown?() }
                    return nil
                }
            }

            return Unmanaged.passRetained(event)
        }

        // Track key releases
        if isKeyUp {
            pressedKeys.remove(keyCode)

            // If active combo and either key released → end recording
            if let combo = activeCombo, (keyCode == combo.key1 || keyCode == combo.key2) {
                let skill = currentSkill
                FileLogger.log("[Hotkey] COMBO UP: \(combo.key1)+\(combo.key2), skill: \(skill?.name ?? "nil")")
                activeCombo = nil
                currentSkill = nil
                DispatchQueue.main.async { self.onHotkeyUp?(skill) }
                return nil
            }

            return Unmanaged.passRetained(event)
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Helpers

    private func getSkillFromKeyCode(_ keyCode: UInt16) -> SkillModel? {
        guard !modifierKeyCodes.contains(keyCode) else { return nil }
        return SkillManager.shared.skillForKeyCode(keyCode)
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

    /// Check if a specific modifier key is currently down (vs released)
    private func isModifierKeyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        return isModifierKeyPressed(keyCode: keyCode, modifiers: modifiers)
    }
}
