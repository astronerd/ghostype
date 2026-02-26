import Foundation
import Security

// MARK: - Keychain Helper

/// Keychain 安全存储工具
/// 用于存储 Clerk JWT Token 等敏感信息
struct KeychainHelper {
    
    private static let service = "com.gengdawei.ghostype"
    
    // MARK: - Save
    
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 先删除旧值
        SecItemDelete(query as CFDictionary)
        
        // 写入新值
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("[Keychain] ✅ Saved: \(key)")
        } else {
            print("[Keychain] ❌ Save failed: \(key), status: \(status)")
        }
    }
    
    // MARK: - Get
    
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    // MARK: - Delete
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            print("[Keychain] ✅ Deleted: \(key)")
        } else {
            print("[Keychain] ❌ Delete failed: \(key), status: \(status)")
        }
    }
    
    // MARK: - Exists
    
    static func exists(key: String) -> Bool {
        return get(key: key) != nil
    }
}
