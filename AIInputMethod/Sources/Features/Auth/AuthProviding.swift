import Foundation

// MARK: - Auth Providing Protocol

/// 认证服务协议
/// 为 GhostypeAPIClient 等消费方提供可测试的认证抽象
protocol AuthProviding: AnyObject {
    var isLoggedIn: Bool { get }
    func getToken() -> String?
    func handleUnauthorized()
}

// MARK: - AuthManager Conformance

extension AuthManager: AuthProviding {}
