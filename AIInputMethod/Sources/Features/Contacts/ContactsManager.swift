import Contacts
import Foundation

/// 通讯录管理器 - 获取联系人姓名作为热词
class ContactsManager {
    static let shared = ContactsManager()
    
    private let store = CNContactStore()
    
    /// 授权状态
    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }
    
    /// 是否已授权
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }
    
    /// 缓存的联系人姓名
    private(set) var cachedNames: [String] = []
    
    /// 上次更新时间
    private(set) var lastUpdated: Date?
    
    private init() {}
    
    // MARK: - Authorization
    
    /// 请求通讯录访问权限
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                completion(granted, error)
            }
        }
    }
    
    // MARK: - Fetch Contacts
    
    /// 获取所有联系人姓名
    func fetchContactNames(completion: @escaping ([String]) -> Void) {
        guard isAuthorized else {
            FileLogger.log("[Contacts] Not authorized")
            completion([])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var names: Set<String> = []
            
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactNicknameKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]
            
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            
            do {
                try self.store.enumerateContacts(with: request) { contact, _ in
                    // 姓名
                    let fullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
                    if !fullName.isEmpty && fullName.count >= 2 {
                        names.insert(fullName)
                    }
                    
                    // 单独的姓和名（如果长度足够）
                    if contact.familyName.count >= 2 {
                        names.insert(contact.familyName)
                    }
                    if contact.givenName.count >= 2 {
                        names.insert(contact.givenName)
                    }
                    
                    // 昵称
                    if !contact.nickname.isEmpty && contact.nickname.count >= 2 {
                        names.insert(contact.nickname)
                    }
                    
                    // 公司名
                    if !contact.organizationName.isEmpty && contact.organizationName.count >= 2 {
                        names.insert(contact.organizationName)
                    }
                }
                
                let sortedNames = Array(names).sorted()
                
                DispatchQueue.main.async {
                    self.cachedNames = sortedNames
                    self.lastUpdated = Date()
                    FileLogger.log("[Contacts] Fetched \(sortedNames.count) names")
                    completion(sortedNames)
                }
                
            } catch {
                FileLogger.log("[Contacts] Fetch error: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    /// 获取热词字符串（用于语音识别 API）
    func getHotwordsString() -> String {
        // 豆包 API 热词格式：每个词用逗号分隔
        return cachedNames.joined(separator: ",")
    }
    
    /// 刷新缓存
    func refreshCache(completion: @escaping () -> Void = {}) {
        fetchContactNames { _ in
            completion()
        }
    }
}
