import Foundation
import AppKit
import Combine

// MARK: - Notification Names

extension Notification.Name {
    /// 用户登录成功通知
    static let userDidLogin = Notification.Name("userDidLogin")
    /// 用户登出通知
    static let userDidLogout = Notification.Name("userDidLogout")
}

// MARK: - Auth Manager

/// 用户认证管理器
/// 负责 Clerk 登录流程、JWT 存储、登录状态管理
class AuthManager: ObservableObject {
    
    static let shared = AuthManager()
    
    // MARK: - Keys
    
    private enum Keys {
        static let jwtToken = "clerk_jwt"
    }
    
    // MARK: - Published State
    
    /// 是否已登录
    @Published var isLoggedIn: Bool = false
    
    /// 当前用户信息（从 JWT 解析）
    @Published var userId: String?
    @Published var userEmail: String?
    
    // MARK: - Configuration
    
    /// Clerk 登录页 URL
    /// 生产环境用 ghostype.com，开发环境用 localhost
    private var signInURL: String {
        let base = baseURL
        let redirect = "/auth/callback?scheme=ghostype://auth"
        let encoded = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirect
        return "\(base)/sign-in?redirect_url=\(encoded)"
    }
    
    private var signUpURL: String {
        let base = baseURL
        let redirect = "/auth/callback?scheme=ghostype://auth"
        let encoded = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirect
        return "\(base)/sign-up?redirect_url=\(encoded)"
    }
    
    private var baseURL: String {
        #if DEBUG
        return "http://localhost:3000"
        #else
        return "https://www.ghostype.one"
        #endif
    }
    
    // MARK: - Init
    
    /// 初始化时从 Keychain 检查已有 JWT，恢复登录状态
    private init() {
        if KeychainHelper.exists(key: Keys.jwtToken) {
            isLoggedIn = true
            print("[Auth] ✅ Restored login state from Keychain")
        } else {
            isLoggedIn = false
            print("[Auth] ℹ️ No existing JWT found, user is logged out")
        }
    }
    
    // MARK: - Login / Signup
    
    /// 打开系统浏览器进行登录
    func openLogin() {
        guard let url = URL(string: signInURL) else {
            print("[Auth] ❌ Invalid sign-in URL: \(signInURL)")
            return
        }
        NSWorkspace.shared.open(url)
        print("[Auth] 🌐 Opened sign-in URL in browser")
    }
    
    /// 打开系统浏览器进行注册
    func openSignUp() {
        guard let url = URL(string: signUpURL) else {
            print("[Auth] ❌ Invalid sign-up URL: \(signUpURL)")
            return
        }
        NSWorkspace.shared.open(url)
        print("[Auth] 🌐 Opened sign-up URL in browser")
    }
    
    // MARK: - URL Scheme Callback
    
    /// 处理 ghostype://auth?token={jwt} 回调
    /// - Parameter url: 从浏览器重定向回来的 URL
    func handleAuthURL(_ url: URL) {
        // 校验 scheme 和 host
        guard url.scheme == "ghostype", url.host == "auth" else {
            print("[Auth] ⚠️ Ignored URL with mismatched scheme/host: \(url)")
            return
        }
        
        // 提取 token 参数
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            print("[Auth] ⚠️ Ignored URL without valid token parameter: \(url)")
            return
        }
        
        // 存入 Keychain
        KeychainHelper.save(key: Keys.jwtToken, value: token)
        
        // 更新登录状态
        isLoggedIn = true
        
        // 发送登录成功通知
        NotificationCenter.default.post(name: .userDidLogin, object: nil)
        
        print("[Auth] ✅ Login successful, JWT stored in Keychain")
    }
    
    // MARK: - Logout
    
    /// 登出：删除 Keychain JWT，重置状态
    func logout() {
        KeychainHelper.delete(key: Keys.jwtToken)
        isLoggedIn = false
        userId = nil
        userEmail = nil
        
        // 发送登出通知
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
        
        print("[Auth] ✅ Logged out, JWT removed from Keychain")
    }
    
    // MARK: - Token Access
    
    /// 从 Keychain 读取当前 JWT Token
    /// - Returns: JWT 字符串，未登录时返回 nil
    func getToken() -> String? {
        return KeychainHelper.get(key: Keys.jwtToken)
    }
    
    // MARK: - Unauthorized Handling
    
    /// 处理 401 未授权响应：清除 JWT、发送登出通知、弹窗提示重新登录
    func handleUnauthorized() {
        KeychainHelper.delete(key: Keys.jwtToken)
        isLoggedIn = false
        userId = nil
        userEmail = nil
        
        // 发送登出通知（触发 AppDelegate 禁用语音输入）
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
        
        print("[Auth] ⚠️ Unauthorized (401), JWT cleared, reverted to logged-out state")
        
        // 弹窗提示
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L.Auth.sessionExpiredTitle
            alert.informativeText = L.Auth.sessionExpiredDesc
            alert.alertStyle = .warning
            alert.addButton(withTitle: L.Auth.reLogin)
            alert.addButton(withTitle: L.Auth.later)
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.openLogin()
            }
        }
    }
}
