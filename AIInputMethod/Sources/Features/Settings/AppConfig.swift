import Foundation

// MARK: - App Config

/// 环境配置统一管理
/// 收敛所有 `#if DEBUG` base URL 分支为单一配置源
enum AppConfig {

    /// API base URL（统一配置源）
    static var apiBaseURL: String {
        #if DEBUG
        return "http://localhost:3000"
        #else
        return "https://www.ghostype.one"
        #endif
    }

    /// 认证回调 URL scheme
    static let authScheme = "ghostype"
    static let authHost = "auth"

    /// 登录页 URL
    static var signInURL: String {
        let redirect = "/auth/callback?scheme=\(authScheme)://\(authHost)"
        let encoded = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirect
        return "\(apiBaseURL)/sign-in?redirect_url=\(encoded)"
    }

    /// 注册页 URL
    static var signUpURL: String {
        let redirect = "/auth/callback?scheme=\(authScheme)://\(authHost)"
        let encoded = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirect
        return "\(apiBaseURL)/sign-up?redirect_url=\(encoded)"
    }
}
