import Foundation
import Security

// MARK: - Keychain Error

/// Keychain 操作错误类型
enum KeychainError: Error {
    case unhandledError(status: OSStatus)
    case itemNotFound
    case duplicateItem
    case invalidData
}

// MARK: - Device ID Manager

/// 设备标识管理器
/// 负责生成、存储和管理设备唯一标识符 (Device_ID)
/// Device_ID 使用 UUID 格式，存储在 Keychain 中以确保安全性和跨重装持久化
class DeviceIdManager {
    
    // MARK: - Singleton
    
    /// 共享实例
    static let shared = DeviceIdManager()
    
    // MARK: - Constants
    
    /// Keychain 服务标识符
    private let keychainService = "com.ghostype.deviceid"
    
    /// Keychain 账户标识符
    private let keychainAccount = "device_id"
    
    // MARK: - Properties
    
    /// 缓存的设备 ID（避免重复读取 Keychain）
    private var cachedDeviceId: String?
    
    /// 设备唯一标识符
    /// 首次访问时会从 Keychain 读取，如果不存在则生成新的 UUID 并存储
    var deviceId: String {
        // 如果已缓存，直接返回
        if let cached = cachedDeviceId {
            return cached
        }
        
        // 尝试从 Keychain 读取
        if let storedId = readFromKeychain() {
            cachedDeviceId = storedId
            return storedId
        }
        
        // Keychain 中不存在，生成新的 ID
        let newId = generateNewId()
        
        // 存储到 Keychain
        do {
            try saveToKeychain(newId)
            cachedDeviceId = newId
        } catch {
            // Keychain 存储失败，使用 UserDefaults 作为后备方案
            print("DeviceIdManager: Failed to save to Keychain, using UserDefaults fallback. Error: \(error)")
            UserDefaults.standard.set(newId, forKey: "fallback_device_id")
            cachedDeviceId = newId
        }
        
        return newId
    }
    
    // MARK: - Initialization
    
    /// 私有初始化方法（单例模式）
    private init() {}
    
    /// 用于测试的初始化方法
    /// - Parameter testMode: 是否为测试模式（不使用单例）
    init(testMode: Bool) {
        // 测试模式下允许创建新实例
    }
    
    // MARK: - Public Methods
    
    /// 生成新的设备 ID
    /// - Returns: 新生成的 UUID 字符串
    func generateNewId() -> String {
        return UUID().uuidString
    }
    
    /// 重置设备 ID
    /// 删除当前存储的 ID，下次访问 deviceId 时会生成新的
    func resetId() {
        // 清除缓存
        cachedDeviceId = nil
        
        // 从 Keychain 删除
        deleteFromKeychain()
        
        // 同时清除 UserDefaults 后备存储
        UserDefaults.standard.removeObject(forKey: "fallback_device_id")
    }
    
    /// 获取截断的设备 ID
    /// - Parameter length: 截断长度，默认为 8
    /// - Returns: 截断后的设备 ID 字符串
    func truncatedId(length: Int = 8) -> String {
        let id = deviceId
        
        // 确保长度有效
        guard length > 0 else {
            return ""
        }
        
        // 如果请求长度大于等于 ID 长度，返回完整 ID
        guard length < id.count else {
            return id
        }
        
        // 返回前 N 个字符
        return String(id.prefix(length))
    }
    
    // MARK: - Keychain Operations
    
    /// 从 Keychain 读取设备 ID
    /// - Returns: 存储的设备 ID，如果不存在则返回 nil
    private func readFromKeychain() -> String? {
        // 首先检查 UserDefaults 后备存储
        if let fallbackId = UserDefaults.standard.string(forKey: "fallback_device_id") {
            // 尝试迁移到 Keychain
            do {
                try saveToKeychain(fallbackId)
                UserDefaults.standard.removeObject(forKey: "fallback_device_id")
            } catch {
                // 迁移失败，继续使用 UserDefaults
            }
            return fallbackId
        }
        
        // 构建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            print("DeviceIdManager: Keychain read error: \(status)")
            return nil
        }
        
        guard let data = result as? Data,
              let deviceId = String(data: data, encoding: .utf8) else {
            print("DeviceIdManager: Invalid data in Keychain")
            return nil
        }
        
        return deviceId
    }
    
    /// 保存设备 ID 到 Keychain
    /// - Parameter deviceId: 要保存的设备 ID
    /// - Throws: KeychainError 如果保存失败
    private func saveToKeychain(_ deviceId: String) throws {
        guard let data = deviceId.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // 构建添加字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // 先尝试删除已存在的项
        deleteFromKeychain()
        
        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// 从 Keychain 删除设备 ID
    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
