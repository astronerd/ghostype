import Foundation
import Cocoa
import IOKit
import IOKit.hid

// MARK: - HIDMapping Data Model

/// 外接 HID 设备按键映射配置
/// 存储 HID usagePage + usage（仅支持 Keyboard page=7）
struct HIDMapping: Codable, Identifiable, Equatable {
    let id: UUID
    let deviceName: String
    let vendorID: Int
    let productID: Int
    /// 源按键 HID usage page（7=Keyboard）
    let sourceUsagePage: UInt32
    /// 源按键 HID usage
    let sourceUsage: UInt32
    let sourceKeyName: String
    /// 目标 macOS keyCode（如 58=Option）
    var targetKeyCode: UInt16
    var isConnected: Bool

    enum CodingKeys: String, CodingKey {
        case id, deviceName, vendorID, productID
        case sourceUsagePage, sourceUsage, sourceKeyName, targetKeyCode
    }

    init(id: UUID = UUID(), deviceName: String, vendorID: Int, productID: Int,
         sourceUsagePage: UInt32, sourceUsage: UInt32, sourceKeyName: String,
         targetKeyCode: UInt16, isConnected: Bool = true) {
        self.id = id
        self.deviceName = deviceName
        self.vendorID = vendorID
        self.productID = productID
        self.sourceUsagePage = sourceUsagePage
        self.sourceUsage = sourceUsage
        self.sourceKeyName = sourceKeyName
        self.targetKeyCode = targetKeyCode
        self.isConnected = isConnected
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        deviceName = try c.decode(String.self, forKey: .deviceName)
        vendorID = try c.decode(Int.self, forKey: .vendorID)
        productID = try c.decode(Int.self, forKey: .productID)
        sourceUsagePage = try c.decode(UInt32.self, forKey: .sourceUsagePage)
        sourceUsage = try c.decode(UInt32.self, forKey: .sourceUsage)
        sourceKeyName = try c.decode(String.self, forKey: .sourceKeyName)
        targetKeyCode = try c.decode(UInt16.self, forKey: .targetKeyCode)
        isConnected = false
    }
}

// MARK: - HIDDeviceInfo

/// 表示一个已连接的 HID 键盘设备
struct HIDDeviceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let vendorID: Int
    let productID: Int
    let registryEntryID: UInt64
    var isActive: Bool = false

    static func == (lhs: HIDDeviceInfo, rhs: HIDDeviceInfo) -> Bool {
        lhs.id == rhs.id && lhs.isActive == rhs.isActive
    }
}


// MARK: - macOS keyCode → HID Usage 映射表

/// macOS keyCode 到 HID Keyboard Usage 的转换
/// hidutil 使用 HID usage，不是 macOS keyCode
private let keyCodeToHIDUsage: [UInt16: UInt32] = [
    // 字母键 A-Z
    0: 0x04,   // A
    1: 0x16,   // S
    2: 0x07,   // D
    3: 0x09,   // F
    4: 0x0B,   // H
    5: 0x0A,   // G
    6: 0x1D,   // Z
    7: 0x1B,   // X
    8: 0x06,   // C
    9: 0x19,   // V
    11: 0x05,  // B
    12: 0x14,  // Q
    13: 0x1A,  // W
    14: 0x08,  // E
    15: 0x15,  // R
    16: 0x1C,  // Y
    17: 0x17,  // T
    31: 0x12,  // O
    32: 0x18,  // U
    34: 0x0C,  // I
    35: 0x13,  // P
    37: 0x0F,  // L
    38: 0x0D,  // J
    40: 0x0E,  // K
    45: 0x11,  // N
    46: 0x10,  // M
    // 数字键 0-9
    18: 0x1E,  // 1
    19: 0x1F,  // 2
    20: 0x20,  // 3
    21: 0x21,  // 4
    23: 0x22,  // 5
    22: 0x23,  // 6
    26: 0x24,  // 7
    28: 0x25,  // 8
    25: 0x26,  // 9
    29: 0x27,  // 0
    // 符号键
    10: 0x64,  // § (ISO keyboards) / ` (JIS) — keyCode 10
    24: 0x2D,  // - (Minus/Equals)
    27: 0x2E,  // = (Equal)
    30: 0x2F,  // [ (Left Bracket)
    33: 0x30,  // ] (Right Bracket)
    39: 0x34,  // ' (Quote)
    41: 0x33,  // ; (Semicolon)
    42: 0x31,  // \ (Backslash)
    43: 0x36,  // , (Comma)
    44: 0x38,  // / (Slash)
    47: 0x37,  // . (Period)
    50: 0x35,  // ` (Grave Accent / Tilde)
    // 常用键
    36: 0x28,  // Return
    48: 0x2B,  // Tab
    49: 0x2C,  // Space
    51: 0x2A,  // Delete (Backspace)
    53: 0x29,  // Escape
    71: 0x53,  // Clear (Numpad)
    76: 0x58,  // Numpad Enter
    // 修饰键
    54: 0xE7,  // Right Command
    55: 0xE3,  // Left Command
    56: 0xE1,  // Left Shift
    57: 0x39,  // Caps Lock
    58: 0xE2,  // Left Option
    59: 0xE0,  // Left Control
    60: 0xE5,  // Right Shift
    61: 0xE6,  // Right Option
    62: 0xE4,  // Right Control
    // Fn 键 — macOS 特殊处理，映射到 HID 0x00FF（Apple Fn）
    // hidutil 使用 0xFF00000003 作为 Fn 的 src/dst
    63: 0x03,  // Function (Apple Fn, usagePage=0xFF)
    // 箭头键
    123: 0x50, // Left Arrow
    124: 0x4F, // Right Arrow
    125: 0x51, // Down Arrow
    126: 0x52, // Up Arrow
    // F1-F12
    122: 0x3A, // F1
    120: 0x3B, // F2
    99: 0x3C,  // F3
    118: 0x3D, // F4
    96: 0x3E,  // F5
    97: 0x3F,  // F6
    98: 0x40,  // F7
    100: 0x41, // F8
    101: 0x42, // F9
    109: 0x43, // F10
    103: 0x44, // F11
    111: 0x45, // F12
    // F13-F20
    105: 0x68, // F13
    107: 0x69, // F14
    113: 0x6A, // F15
    106: 0x6B, // F16
    64: 0x6C,  // F17
    79: 0x6D,  // F18
    80: 0x6E,  // F19
    90: 0x6F,  // F20
    // 小键盘
    65: 0x63,  // Numpad .
    67: 0x55,  // Numpad *
    69: 0x57,  // Numpad +
    75: 0x54,  // Numpad /
    78: 0x56,  // Numpad -
    81: 0x67,  // Numpad =
    82: 0x62,  // Numpad 0
    83: 0x59,  // Numpad 1
    84: 0x5A,  // Numpad 2
    85: 0x5B,  // Numpad 3
    86: 0x5C,  // Numpad 4
    87: 0x5D,  // Numpad 5
    88: 0x5E,  // Numpad 6
    89: 0x5F,  // Numpad 7
    91: 0x60,  // Numpad 8
    92: 0x61,  // Numpad 9
    // 其他
    114: 0x49, // Insert / Help
    115: 0x4A, // Home
    116: 0x4B, // Page Up
    117: 0x4C, // Forward Delete
    119: 0x4D, // End
    121: 0x4E, // Page Down
]

// MARK: - HIDMappingManager

/// 管理外接 HID 设备的键值映射
/// - 设备枚举：hidutil list -n
/// - 按键录制：IOHIDManager input value callback
/// - 映射执行：hidutil property --matching（系统级 remap，CGEvent tap 直接收到目标键）
class HIDMappingManager: ObservableObject {
    @Published var mappings: [HIDMapping] = []
    @Published var connectedDevices: [HIDDeviceInfo] = []

    /// IOHIDManager — 仅用于设备枚举 + 按键录制
    private var hidManager: IOHIDManager?
    private var deviceMap: [IOHIDDevice: HIDDeviceInfo] = [:]

    /// 录制状态
    private var isRecording = false
    private var recordingDeviceID: String?
    private var recordingCompletion: ((UInt32, UInt32, String) -> Void)?

    /// HotkeyManager 引用（组合键模式下直接调用 simulate）
    weak var hotkeyManager: HotkeyManager?

    /// 组合键模式下：IOHIDManager 用于运行时直接监听映射按键
    private var runtimeHIDManager: IOHIDManager?
    private var runtimeDeviceMap: [IOHIDDevice: HIDDeviceInfo] = [:]
    /// 跟踪映射按键是否处于按下状态（防止重复触发）
    private var isMappedKeyDown = false

    // MARK: - Key Name Helpers

    static func keyName(usagePage: UInt32, usage: UInt32) -> String {
        if usagePage == 7 {
            switch usage {
            case 4...29: return String(UnicodeScalar(usage - 4 + 65)!)
            case 30...38: return "\(usage - 29)"
            case 39: return "0"
            case 40: return "Return"
            case 41: return "Escape"
            case 42: return "Backspace"
            case 43: return "Tab"
            case 44: return "Space"
            case 0x2D: return "-"
            case 0x2E: return "="
            case 0x2F: return "["
            case 0x30: return "]"
            case 0x31: return "\\"
            case 0x33: return ";"
            case 0x34: return "'"
            case 0x35: return "`"
            case 0x36: return ","
            case 0x37: return "."
            case 0x38: return "/"
            case 0x39: return "Caps Lock"
            case 58...69: return "F\(usage - 57)"
            case 104...115: return "F\(usage - 91)"
            case 0x49: return "Insert"
            case 0x4A: return "Home"
            case 0x4B: return "Page Up"
            case 0x4C: return "Forward Delete"
            case 0x4D: return "End"
            case 0x4E: return "Page Down"
            case 0x4F: return "→"
            case 0x50: return "←"
            case 0x51: return "↓"
            case 0x52: return "↑"
            case 0x53: return "Clear"
            case 0x54: return "Numpad /"
            case 0x55: return "Numpad *"
            case 0x56: return "Numpad -"
            case 0x57: return "Numpad +"
            case 0x58: return "Numpad Enter"
            case 0x59...0x61: return "Numpad \(usage - 0x59 + 1)"
            case 0x62: return "Numpad 0"
            case 0x63: return "Numpad ."
            case 0x67: return "Numpad ="
            case 0xE0: return "Control"
            case 0xE1: return "Shift"
            case 0xE2: return "Option"
            case 0xE3: return "Command"
            case 0xE4: return "Right Control"
            case 0xE5: return "Right Shift"
            case 0xE6: return "Right Option"
            case 0xE7: return "Right Command"
            default: return "Key \(usage)"
            }
        }
        if usagePage == 12 {
            switch usage {
            case 233: return "Volume Up"
            case 234: return "Volume Down"
            case 226: return "Mute"
            default: return "Consumer \(usage)"
            }
        }
        return "Page\(usagePage):\(usage)"
    }

    // MARK: - Device Enumeration (hidutil JSON)

    func enumerateDevices() {
        let devices = enumerateViaHidutil()
        FileLogger.log("[HID] enumerateDevices: \(devices.map { $0.name })")
        DispatchQueue.main.async { self.connectedDevices = devices }
    }

    private func enumerateViaHidutil() -> [HIDDeviceInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["list", "-n", "--matching", "{\"PrimaryUsagePage\":1,\"PrimaryUsage\":6}"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            FileLogger.log("[HID] hidutil list failed: \(error)")
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var devices: [HIDDeviceInfo] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("{"), let jsonData = trimmed.data(using: .utf8) else { continue }
            guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            let productName = dict["Product"] as? String ?? ""
            let vendorID = dict["VendorID"] as? Int ?? 0
            let productID = dict["ProductID"] as? Int ?? 0
            let transport = dict["Transport"] as? String ?? ""
            let regID = dict["IORegistryEntryID"] as? UInt64
                ?? UInt64(dict["IORegistryEntryID"] as? Int ?? 0)
            let type = dict["type"] as? String ?? ""

            guard type == "device" else { continue }
            let displayName: String
            if !productName.isEmpty {
                displayName = productName
            } else if vendorID != 0 || productID != 0 {
                displayName = "USB Device (\(vendorID):\(productID))"
            } else {
                continue
            }
            if displayName.lowercased().contains("internal") { continue }
            if vendorID == 1452 && transport.isEmpty { continue }
            // 过滤蓝牙设备（hidutil per-device remap 不支持 BLE）
            if transport.lowercased() == "bluetooth" { continue }

            let deviceID = "\(regID)"
            if !devices.contains(where: { $0.id == deviceID }) {
                devices.append(HIDDeviceInfo(
                    id: deviceID, name: displayName,
                    vendorID: vendorID, productID: productID,
                    registryEntryID: regID
                ))
            }
        }
        return devices
    }


    // MARK: - IOHIDManager (仅用于设备枚举面板 + 按键录制)

    private func createAndStartHIDManager() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = mgr

        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)

        let matchCB: IOHIDDeviceCallback = { ctx, _, _, device in
            let mgr = Unmanaged<HIDMappingManager>.fromOpaque(ctx!).takeUnretainedValue()
            mgr.hidDeviceConnected(device)
        }
        IOHIDManagerRegisterDeviceMatchingCallback(mgr, matchCB, Unmanaged.passUnretained(self).toOpaque())

        let inputCB: IOHIDValueCallback = { ctx, _, _, value in
            let mgr = Unmanaged<HIDMappingManager>.fromOpaque(ctx!).takeUnretainedValue()
            mgr.hidInputValueReceived(value)
        }
        IOHIDManagerRegisterInputValueCallback(mgr, inputCB, Unmanaged.passUnretained(self).toOpaque())

        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        FileLogger.log("[HID] IOHIDManager open: \(result == 0 ? "OK" : "FAIL(\(result))")")
    }

    private func destroyHIDManager() {
        if let mgr = hidManager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            hidManager = nil
        }
        deviceMap.removeAll()
    }

    // MARK: - Activity Monitoring (设备选择面板用)

    func startActivityMonitoring() {
        destroyHIDManager()
        let devices = enumerateViaHidutil()
        DispatchQueue.main.async { self.connectedDevices = devices }
        FileLogger.log("[HID] startActivityMonitoring: \(devices.map { "\($0.name) regID:\($0.registryEntryID)" })")
        createAndStartHIDManager()
    }

    func stopActivityMonitoring() {
        destroyHIDManager()
        isRecording = false
        recordingCompletion = nil
        recordingDeviceID = nil
        for i in connectedDevices.indices {
            connectedDevices[i].isActive = false
        }
        FileLogger.log("[HID] Activity monitoring stopped")
    }

    // MARK: - IOHIDManager Callbacks

    private func hidDeviceConnected(_ device: IOHIDDevice) {
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "(unknown)"
        let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0

        var entryID: UInt64 = 0
        let service = IOHIDDeviceGetService(device)
        IORegistryEntryGetRegistryEntryID(service, &entryID)

        let info = HIDDeviceInfo(
            id: "\(entryID)", name: name,
            vendorID: vid, productID: pid,
            registryEntryID: entryID
        )
        deviceMap[device] = info
        FileLogger.log("[HID] Device connected: \(name) VID:\(vid) PID:\(pid) RegID:\(entryID)")
    }

    private func hidInputValueReceived(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let usagePage = UInt32(IOHIDElementGetUsagePage(element))
        let usage = UInt32(IOHIDElementGetUsage(element))
        let intValue = IOHIDValueGetIntegerValue(value)

        guard usage > 0, usagePage == 7 else { return }
        let isDown = intValue == 1

        let info = deviceMap[device]
        let regID = info?.registryEntryID ?? 0
        let deviceID = "\(regID)"

        // 活动指示
        if isDown {
            DispatchQueue.main.async { [weak self] in
                self?.markDeviceActive(deviceID: deviceID)
            }
        }

        // 录制模式
        if isRecording && isDown {
            if let targetID = recordingDeviceID, targetID != deviceID { return }

            let keyName = Self.keyName(usagePage: usagePage, usage: usage)
            FileLogger.log("[HID] Recorded: page=\(usagePage) usage=\(usage) name=\(keyName) device=\(info?.name ?? "?")")

            let completion = recordingCompletion
            DispatchQueue.main.async { [weak self] in
                self?.isRecording = false
                self?.recordingCompletion = nil
                self?.recordingDeviceID = nil
                completion?(usagePage, usage, keyName)
            }
        }
    }

    // MARK: - Runtime HID Input (combo key mode direct trigger)

    private func runtimeHIDInputReceived(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let usagePage = UInt32(IOHIDElementGetUsagePage(element))
        let usage = UInt32(IOHIDElementGetUsage(element))
        let intValue = IOHIDValueGetIntegerValue(value)

        guard usage > 0, usagePage == 7 else { return }
        let isDown = intValue == 1

        // 检查这个按键是否是我们映射的按键（来自映射的设备）
        var entryID: UInt64 = 0
        let service = IOHIDDeviceGetService(device)
        IORegistryEntryGetRegistryEntryID(service, &entryID)

        let isMappedKey = mappings.contains { mapping in
            mapping.sourceUsagePage == usagePage &&
            mapping.sourceUsage == usage &&
            mapping.vendorID == (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0) &&
            mapping.productID == (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0)
        }

        guard isMappedKey else { return }

        if isDown && !isMappedKeyDown {
            isMappedKeyDown = true
            FileLogger.log("[HID] Combo mode: mapped key DOWN (usage=\(usage))")
            DispatchQueue.main.async { [weak self] in
                self?.hotkeyManager?.simulateHotkeyDown()
            }
        } else if !isDown && isMappedKeyDown {
            isMappedKeyDown = false
            FileLogger.log("[HID] Combo mode: mapped key UP (usage=\(usage))")
            DispatchQueue.main.async { [weak self] in
                self?.hotkeyManager?.simulateHotkeyUp()
            }
        }
    }

    private func markDeviceActive(deviceID: String) {
        guard let idx = connectedDevices.firstIndex(where: { $0.id == deviceID }) else { return }
        connectedDevices[idx].isActive = true
        let id = deviceID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if let idx = self.connectedDevices.firstIndex(where: { $0.id == id }) {
                self.connectedDevices[idx].isActive = false
            }
        }
    }

    // MARK: - Recording

    func startRecording(forDeviceID deviceID: String? = nil, completion: @escaping (UInt32, UInt32, String) -> Void) {
        guard !isRecording else { return }
        isRecording = true
        recordingDeviceID = deviceID
        recordingCompletion = completion
        FileLogger.log("[HID] Recording started (device: \(deviceID ?? "any"))")
    }

    func stopRecording() {
        isRecording = false
        recordingCompletion = nil
        recordingDeviceID = nil
    }

    // MARK: - hidutil property Remap（系统级，CGEvent tap 直接收到目标键）

    /// 获取当前快捷键对应的 HID usage 和 usagePage（从 AppSettings.hotkeyKeyCode 动态读取）
    /// 返回 (usagePage, usage)。Fn 键特殊：usagePage=0xFF, usage=0x03
    private func targetHIDUsageAndPage() -> (UInt32, UInt32) {
        let keyCode = AppSettings.shared.hotkeyKeyCode
        if keyCode == 63 {
            // Fn 键：Apple vendor page 0xFF, usage 0x03
            return (0xFF, 0x03)
        }
        if let usage = keyCodeToHIDUsage[keyCode] {
            return (0x07, usage)
        }
        // 默认 Option
        FileLogger.log("[HID] ⚠️ No HID usage for keyCode \(keyCode), defaulting to Option (0xE2)")
        return (0x07, 0xE2)
    }

    /// 对指定设备应用 hidutil property remap
    /// hidutil property --matching '{"VendorID":vid,"ProductID":pid}' --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":src,"HIDKeyboardModifierMappingDst":dst}]}'
    private func applyHidutilRemap(mapping: HIDMapping) {
        let srcUsage: UInt64
        if mapping.sourceUsagePage == 0xFF {
            // Fn 键特殊处理
            srcUsage = UInt64(0xFF) << 32 | UInt64(mapping.sourceUsage)
        } else {
            srcUsage = UInt64(mapping.sourceUsagePage) << 32 | UInt64(mapping.sourceUsage)
        }
        let (dstPage, dstUsg) = targetHIDUsageAndPage()
        let dstUsage = UInt64(dstPage) << 32 | UInt64(dstUsg)

        let matchingJSON = "{\"VendorID\":\(mapping.vendorID),\"ProductID\":\(mapping.productID)}"
        let remapJSON = "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":\(srcUsage),\"HIDKeyboardModifierMappingDst\":\(dstUsage)}]}"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--matching", matchingJSON, "--set", remapJSON]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            FileLogger.log("[HID] hidutil remap applied: \(mapping.deviceName) \(mapping.sourceKeyName) → 0x\(String(dstUsage, radix: 16)), exit=\(process.terminationStatus), output=\(output.prefix(200))")
        } catch {
            FileLogger.log("[HID] hidutil remap failed: \(error)")
        }
    }

    /// 清除指定设备的所有 remap（恢复正常）
    private func clearHidutilRemap(vendorID: Int, productID: Int) {
        let matchingJSON = "{\"VendorID\":\(vendorID),\"ProductID\":\(productID)}"
        let remapJSON = "{\"UserKeyMapping\":[]}"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--matching", matchingJSON, "--set", remapJSON]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            FileLogger.log("[HID] hidutil remap cleared for VID:\(vendorID) PID:\(productID), exit=\(process.terminationStatus)")
        } catch {
            FileLogger.log("[HID] hidutil clear failed: \(error)")
        }
    }

    /// 清除所有已映射设备的 remap（应用退出时调用）
    func clearAllRemaps() {
        var cleared = Set<String>()
        for mapping in mappings {
            let key = "\(mapping.vendorID):\(mapping.productID)"
            guard !cleared.contains(key) else { continue }
            clearHidutilRemap(vendorID: mapping.vendorID, productID: mapping.productID)
            cleared.insert(key)
        }
        FileLogger.log("[HID] Cleared all remaps (\(cleared.count) devices)")
    }

    // MARK: - Mapping Management

    @discardableResult
    func applyMapping(_ mapping: HIDMapping) -> Bool {
        // 先移除同设备的旧映射
        mappings.removeAll { $0.vendorID == mapping.vendorID && $0.productID == mapping.productID }
        mappings.append(mapping)
        // 根据当前模式应用
        if AppSettings.shared.hotkeyMode == .comboKey {
            // 组合键模式：确保运行时监听已启动
            startRuntimeMonitoring()
        } else {
            applyHidutilRemap(mapping: mapping)
        }
        FileLogger.log("[HID] Applied mapping: \(mapping.deviceName) \(mapping.sourceKeyName) → keyCode \(mapping.targetKeyCode)")
        return true
    }

    @discardableResult
    func removeMapping(_ mapping: HIDMapping) -> Bool {
        mappings.removeAll { $0.id == mapping.id }
        if AppSettings.shared.hotkeyMode == .comboKey {
            // 组合键模式：如果没有映射了，停止运行时监听
            if mappings.isEmpty {
                stopRuntimeMonitoring()
            }
        } else {
            // 清除该设备的 remap，恢复正常
            clearHidutilRemap(vendorID: mapping.vendorID, productID: mapping.productID)
        }
        FileLogger.log("[HID] Removed mapping: \(mapping.deviceName) \(mapping.sourceKeyName)")
        return true
    }

    // MARK: - Sync Target KeyCode

    /// 快捷键变更时，重新应用所有 remap（仅单键模式需要）
    func syncTargetKeyCode(_ newKeyCode: UInt32) {
        guard !mappings.isEmpty else { return }
        for i in mappings.indices {
            mappings[i].targetKeyCode = UInt16(newKeyCode)
        }
        save()
        // 仅单键模式需要重新应用 hidutil remap（组合键模式不用 hidutil）
        if AppSettings.shared.hotkeyMode == .singleKey {
            for mapping in mappings {
                applyHidutilRemap(mapping: mapping)
            }
        }
        FileLogger.log("[HID] Synced \(mappings.count) mappings to keyCode: \(newKeyCode)")
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(mappings) else {
            FileLogger.log("[HID] Failed to encode mappings")
            return
        }
        AppSettings.shared.hidMappingsData = data
        FileLogger.log("[HID] Saved \(mappings.count) mappings")
    }

    func load() {
        guard let data = AppSettings.shared.hidMappingsData else {
            FileLogger.log("[HID] No saved mappings found")
            return
        }
        guard let loaded = try? JSONDecoder().decode([HIDMapping].self, from: data) else {
            FileLogger.log("[HID] Failed to decode mappings (schema changed?), clearing")
            AppSettings.shared.hidMappingsData = nil
            return
        }
        mappings = loaded
        FileLogger.log("[HID] Loaded \(mappings.count) mappings")
    }

    // MARK: - Startup & Shutdown

    /// 启动时调用：加载映射 + 根据模式应用 hidutil remap 或启动直接监听
    func restoreAndMonitor() {
        load()
        applyMappingsForCurrentMode()
        FileLogger.log("[HID] Restored \(mappings.count) mappings, mode: \(AppSettings.shared.hotkeyMode.rawValue)")
    }

    /// 根据当前快捷键模式应用映射策略
    func applyMappingsForCurrentMode() {
        let mode = AppSettings.shared.hotkeyMode
        if mode == .comboKey {
            // 组合键模式：清除 hidutil remap，启动 IOHIDManager 直接监听
            clearAllRemaps()
            startRuntimeMonitoring()
        } else {
            // 单键模式：停止直接监听，应用 hidutil remap
            stopRuntimeMonitoring()
            for mapping in mappings {
                applyHidutilRemap(mapping: mapping)
            }
        }
    }

    // MARK: - Runtime IOHIDManager (combo key mode: direct key monitoring)

    /// 启动运行时 IOHIDManager，监听映射按键的 press/release
    private func startRuntimeMonitoring() {
        guard !mappings.isEmpty else {
            FileLogger.log("[HID] No mappings, skipping runtime monitoring")
            return
        }
        stopRuntimeMonitoring()

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        runtimeHIDManager = mgr

        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)

        let inputCB: IOHIDValueCallback = { ctx, _, _, value in
            let mgr = Unmanaged<HIDMappingManager>.fromOpaque(ctx!).takeUnretainedValue()
            mgr.runtimeHIDInputReceived(value)
        }
        IOHIDManagerRegisterInputValueCallback(mgr, inputCB, Unmanaged.passUnretained(self).toOpaque())

        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        FileLogger.log("[HID] Runtime IOHIDManager started for combo mode: \(result == 0 ? "OK" : "FAIL(\(result))")")
    }

    /// 停止运行时 IOHIDManager
    private func stopRuntimeMonitoring() {
        if let mgr = runtimeHIDManager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            runtimeHIDManager = nil
        }
        isMappedKeyDown = false
        FileLogger.log("[HID] Runtime monitoring stopped")
    }

    /// 退出时调用：清除所有 remap + 停止运行时监听，恢复设备正常
    func shutdown() {
        stopRuntimeMonitoring()
        clearAllRemaps()
    }
}
