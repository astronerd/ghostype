import Foundation

// MARK: - Device ID Manager

/// 设备标识管理器
/// 使用 UserDefaults 存储设备唯一标识符
class DeviceIdManager {
    
    static let shared = DeviceIdManager()
    
    private let userDefaultsKey = "ghostype_device_id"
    
    private var cachedDeviceId: String?
    
    var deviceId: String {
        if let cached = cachedDeviceId {
            return cached
        }
        
        if let storedId = UserDefaults.standard.string(forKey: userDefaultsKey) {
            cachedDeviceId = storedId
            return storedId
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: userDefaultsKey)
        cachedDeviceId = newId
        return newId
    }
    
    private init() {}
    
    func truncatedId(length: Int = 8) -> String {
        return String(deviceId.prefix(length))
    }
    
    func resetId() {
        cachedDeviceId = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
