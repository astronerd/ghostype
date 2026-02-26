import XCTest
import Foundation
import Security

// MARK: - Lightweight Property-Based Testing Helper

/// A simple property-based testing engine that generates random inputs
/// and checks that a property holds for all of them.
/// Inspired by QuickCheck/SwiftCheck but self-contained.
struct PropertyTest {
    
    /// Run a property test with the given number of iterations.
    /// - Parameters:
    ///   - name: Description of the property being tested
    ///   - iterations: Number of random inputs to test (default 100)
    ///   - property: A closure that returns true if the property holds
    /// - Throws: XCTFail if any iteration fails
    static func verify(
        _ name: String,
        iterations: Int = 100,
        file: StaticString = #file,
        line: UInt = #line,
        property: () throws -> Bool
    ) rethrows {
        for i in 0..<iterations {
            let result = try property()
            if !result {
                XCTFail("Property '\(name)' failed on iteration \(i + 1)", file: file, line: line)
                return
            }
        }
    }
    
    /// Generate a random alphanumeric string of given length range
    static func randomString(minLength: Int = 1, maxLength: Int = 64) -> String {
        let length = Int.random(in: minLength...maxLength)
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    /// Generate a random JWT-like token string
    static func randomJWT() -> String {
        // JWT format: header.payload.signature (base64url encoded segments)
        let base64Chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        func segment(length: Int) -> String {
            String((0..<length).map { _ in base64Chars.randomElement()! })
        }
        return "\(segment(length: Int.random(in: 10...40))).\(segment(length: Int.random(in: 20...100))).\(segment(length: Int.random(in: 20...60)))"
    }
    
    /// Generate a random URL scheme (not "ghostype")
    static func randomNonGhostypeScheme() -> String {
        let schemes = ["http", "https", "ftp", "ssh", "myapp", "custom", "test", "foo", "bar"]
        return schemes.randomElement()!
    }
    
    /// Generate a random host (not "auth")
    static func randomNonAuthHost() -> String {
        let hosts = ["callback", "login", "oauth", "redirect", "home", "main", "app", "test"]
        return hosts.randomElement()!
    }
}

// MARK: - Keychain Helper (Test Copy)
// Exact copy of KeychainHelper from the main target, used for testing
// since we cannot import the executable target.

private struct TestKeychainHelper {
    
    // Use a separate service name to avoid interfering with production Keychain
    private static let service = "com.gengdawei.ghostype.tests"
    
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
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
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    static func exists(key: String) -> Bool {
        return get(key: key) != nil
    }
}

// MARK: - Testable AuthManager
// A testable version of AuthManager that uses the test Keychain service
// and is not a singleton, allowing fresh instances per test.

private class TestableAuthManager {
    
    private enum Keys {
        static let jwtToken = "clerk_jwt_test"
    }
    
    var isLoggedIn: Bool = false
    
    init() {
        // Restore login state from Keychain (same logic as production AuthManager.init)
        if TestKeychainHelper.exists(key: Keys.jwtToken) {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }
    }
    
    /// Handle auth URL callback - exact same logic as AuthManager.handleAuthURL
    func handleAuthURL(_ url: URL) {
        // Validate scheme and host
        guard url.scheme == "ghostype", url.host == "auth" else {
            return
        }
        
        // Extract token parameter
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            return
        }
        
        // Store in Keychain
        TestKeychainHelper.save(key: Keys.jwtToken, value: token)
        
        // Update login state
        isLoggedIn = true
    }
    
    /// Logout - exact same logic as AuthManager.logout
    func logout() {
        TestKeychainHelper.delete(key: Keys.jwtToken)
        isLoggedIn = false
    }
    
    /// Get current token from Keychain
    func getToken() -> String? {
        return TestKeychainHelper.get(key: Keys.jwtToken)
    }
    
    /// Clean up test Keychain data
    func cleanup() {
        TestKeychainHelper.delete(key: Keys.jwtToken)
    }
}

// MARK: - Property Tests

/// Property-based tests for AuthManager
/// Feature: api-online-auth
/// **Validates: Requirements 1.2, 1.3, 1.4, 1.6**
final class AuthManagerPropertyTests: XCTestCase {
    
    private var authManager: TestableAuthManager!
    
    override func setUp() {
        super.setUp()
        // Start each test with a clean state
        authManager = TestableAuthManager()
        authManager.cleanup()
        authManager = TestableAuthManager() // Re-init after cleanup
    }
    
    override func tearDown() {
        authManager.cleanup()
        authManager = nil
        super.tearDown()
    }
    
    // MARK: - Property 1: Auth URL 解析与状态转换
    
    /// Feature: api-online-auth, Property 1: Auth URL 解析与状态转换
    /// For any valid auth callback URL (scheme "ghostype", host "auth", non-empty token parameter),
    /// AuthManager should set isLoggedIn to true and store the JWT in Keychain.
    /// **Validates: Requirements 1.2, 1.3**
    func testProperty1_ValidAuthURLSetsLoggedInAndStoresJWT() {
        PropertyTest.verify(
            "Valid auth URL → isLoggedIn=true and JWT stored in Keychain",
            iterations: 100
        ) { [self] in
            // Clean state before each iteration
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            // Generate a random JWT token
            let token = PropertyTest.randomJWT()
            
            // Build a valid auth URL: ghostype://auth?token={jwt}
            var components = URLComponents()
            components.scheme = "ghostype"
            components.host = "auth"
            components.queryItems = [URLQueryItem(name: "token", value: token)]
            
            guard let url = components.url else {
                // If URL construction fails, skip this iteration (not a valid test case)
                return true
            }
            
            // Pre-condition: not logged in
            let wasLoggedIn = authManager.isLoggedIn
            XCTAssertFalse(wasLoggedIn, "Pre-condition: should start logged out")
            
            // Act
            authManager.handleAuthURL(url)
            
            // Property assertions:
            // 1. isLoggedIn should be true
            guard authManager.isLoggedIn else { return false }
            
            // 2. Keychain should contain the JWT
            guard let storedToken = authManager.getToken() else { return false }
            
            // 3. Stored token should match the input token
            guard storedToken == token else { return false }
            
            return true
        }
    }
    
    /// Additional sub-property: Valid auth URLs with extra query parameters should still work
    /// **Validates: Requirements 1.2, 1.3**
    func testProperty1_ValidAuthURLWithExtraParams() {
        PropertyTest.verify(
            "Valid auth URL with extra query params → still logs in correctly",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let token = PropertyTest.randomJWT()
            
            var components = URLComponents()
            components.scheme = "ghostype"
            components.host = "auth"
            
            // Add token plus random extra parameters
            var queryItems = [URLQueryItem(name: "token", value: token)]
            let extraParamCount = Int.random(in: 0...3)
            for _ in 0..<extraParamCount {
                let key = PropertyTest.randomString(minLength: 1, maxLength: 10)
                let value = PropertyTest.randomString(minLength: 1, maxLength: 20)
                queryItems.append(URLQueryItem(name: key, value: value))
            }
            // Shuffle to ensure token isn't always first
            queryItems.shuffle()
            components.queryItems = queryItems
            
            guard let url = components.url else { return true }
            
            authManager.handleAuthURL(url)
            
            guard authManager.isLoggedIn else { return false }
            guard authManager.getToken() == token else { return false }
            
            return true
        }
    }
    
    // MARK: - Property 2: 无效 URL 不改变认证状态
    
    /// Feature: api-online-auth, Property 2: 无效 URL 不改变认证状态
    /// For any URL where scheme is not "ghostype", host is not "auth", or token parameter is missing,
    /// AuthManager should not change isLoggedIn state.
    /// **Validates: Requirements 1.6**
    func testProperty2_InvalidSchemeDoesNotChangeState() {
        PropertyTest.verify(
            "URL with non-ghostype scheme → isLoggedIn unchanged",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let initialState = authManager.isLoggedIn
            let token = PropertyTest.randomJWT()
            let scheme = PropertyTest.randomNonGhostypeScheme()
            
            var components = URLComponents()
            components.scheme = scheme
            components.host = "auth"
            components.queryItems = [URLQueryItem(name: "token", value: token)]
            
            guard let url = components.url else { return true }
            
            authManager.handleAuthURL(url)
            
            // State should not change
            guard authManager.isLoggedIn == initialState else { return false }
            
            return true
        }
    }
    
    /// **Validates: Requirements 1.6**
    func testProperty2_InvalidHostDoesNotChangeState() {
        PropertyTest.verify(
            "URL with non-auth host → isLoggedIn unchanged",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let initialState = authManager.isLoggedIn
            let token = PropertyTest.randomJWT()
            let host = PropertyTest.randomNonAuthHost()
            
            var components = URLComponents()
            components.scheme = "ghostype"
            components.host = host
            components.queryItems = [URLQueryItem(name: "token", value: token)]
            
            guard let url = components.url else { return true }
            
            authManager.handleAuthURL(url)
            
            guard authManager.isLoggedIn == initialState else { return false }
            
            return true
        }
    }
    
    /// **Validates: Requirements 1.6**
    func testProperty2_MissingTokenDoesNotChangeState() {
        PropertyTest.verify(
            "URL without token parameter → isLoggedIn unchanged",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let initialState = authManager.isLoggedIn
            
            // Build URL with correct scheme/host but no token parameter
            var components = URLComponents()
            components.scheme = "ghostype"
            components.host = "auth"
            
            // Add random query params that are NOT "token"
            let paramCount = Int.random(in: 0...3)
            var queryItems: [URLQueryItem] = []
            for _ in 0..<paramCount {
                var key = PropertyTest.randomString(minLength: 1, maxLength: 10)
                // Ensure key is never "token"
                while key == "token" {
                    key = PropertyTest.randomString(minLength: 1, maxLength: 10)
                }
                queryItems.append(URLQueryItem(name: key, value: PropertyTest.randomString()))
            }
            if !queryItems.isEmpty {
                components.queryItems = queryItems
            }
            
            guard let url = components.url else { return true }
            
            authManager.handleAuthURL(url)
            
            guard authManager.isLoggedIn == initialState else { return false }
            
            return true
        }
    }
    
    /// **Validates: Requirements 1.6**
    func testProperty2_EmptyTokenDoesNotChangeState() {
        PropertyTest.verify(
            "URL with empty token value → isLoggedIn unchanged",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let initialState = authManager.isLoggedIn
            
            var components = URLComponents()
            components.scheme = "ghostype"
            components.host = "auth"
            components.queryItems = [URLQueryItem(name: "token", value: "")]
            
            guard let url = components.url else { return true }
            
            authManager.handleAuthURL(url)
            
            guard authManager.isLoggedIn == initialState else { return false }
            
            return true
        }
    }
    
    /// Combined: For any URL that fails at least one validity check, state should not change
    /// **Validates: Requirements 1.6**
    func testProperty2_AnyInvalidURLDoesNotChangeState() {
        PropertyTest.verify(
            "Any invalid URL (wrong scheme, host, or missing token) → isLoggedIn unchanged",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let initialState = authManager.isLoggedIn
            
            // Randomly choose which validity condition to violate
            let violationType = Int.random(in: 0...3)
            
            var components = URLComponents()
            
            switch violationType {
            case 0:
                // Wrong scheme
                components.scheme = PropertyTest.randomNonGhostypeScheme()
                components.host = "auth"
                components.queryItems = [URLQueryItem(name: "token", value: PropertyTest.randomJWT())]
            case 1:
                // Wrong host
                components.scheme = "ghostype"
                components.host = PropertyTest.randomNonAuthHost()
                components.queryItems = [URLQueryItem(name: "token", value: PropertyTest.randomJWT())]
            case 2:
                // Missing token
                components.scheme = "ghostype"
                components.host = "auth"
                // No query items or non-token query items
                let key = PropertyTest.randomString(minLength: 2, maxLength: 10)
                if key != "token" {
                    components.queryItems = [URLQueryItem(name: key, value: PropertyTest.randomString())]
                }
            case 3:
                // Empty token
                components.scheme = "ghostype"
                components.host = "auth"
                components.queryItems = [URLQueryItem(name: "token", value: "")]
            default:
                break
            }
            
            guard let url = components.url else { return true }
            
            authManager.handleAuthURL(url)
            
            guard authManager.isLoggedIn == initialState else { return false }
            
            return true
        }
    }
    
    // MARK: - Property 3: 登录登出往返一致性
    
    /// Feature: api-online-auth, Property 3: 登录登出往返一致性
    /// For any valid JWT token, after login (handleAuthURL) then logout,
    /// isLoggedIn should be false and Keychain should not contain the JWT.
    /// **Validates: Requirements 1.4**
    func testProperty3_LoginThenLogoutResetsState() {
        PropertyTest.verify(
            "Login then logout → isLoggedIn=false and no JWT in Keychain",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let token = PropertyTest.randomJWT()
            
            // Step 1: Login via valid auth URL
            var components = URLComponents()
            components.scheme = "ghostype"
            components.host = "auth"
            components.queryItems = [URLQueryItem(name: "token", value: token)]
            
            guard let url = components.url else { return true }
            
            authManager.handleAuthURL(url)
            
            // Verify login succeeded
            guard authManager.isLoggedIn else { return false }
            guard authManager.getToken() == token else { return false }
            
            // Step 2: Logout
            authManager.logout()
            
            // Property assertions after logout:
            // 1. isLoggedIn should be false
            guard !authManager.isLoggedIn else { return false }
            
            // 2. Keychain should NOT contain the JWT
            guard authManager.getToken() == nil else { return false }
            
            return true
        }
    }
    
    /// Multiple login-logout cycles should be consistent
    /// **Validates: Requirements 1.4**
    func testProperty3_MultipleLoginLogoutCycles() {
        PropertyTest.verify(
            "Multiple login-logout cycles → always ends logged out with no JWT",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            // Perform 1-5 login/logout cycles
            let cycles = Int.random(in: 1...5)
            
            for _ in 0..<cycles {
                let token = PropertyTest.randomJWT()
                
                var components = URLComponents()
                components.scheme = "ghostype"
                components.host = "auth"
                components.queryItems = [URLQueryItem(name: "token", value: token)]
                
                guard let url = components.url else { return true }
                
                authManager.handleAuthURL(url)
                
                // After login: should be logged in
                guard authManager.isLoggedIn else { return false }
                
                authManager.logout()
                
                // After logout: should be logged out
                guard !authManager.isLoggedIn else { return false }
                guard authManager.getToken() == nil else { return false }
            }
            
            return true
        }
    }
    
    /// Login with new token should overwrite old token, then logout clears everything
    /// **Validates: Requirements 1.4**
    func testProperty3_LoginOverwriteThenLogout() {
        PropertyTest.verify(
            "Login with token A, login with token B, logout → no JWT in Keychain",
            iterations: 100
        ) { [self] in
            authManager.cleanup()
            authManager = TestableAuthManager()
            
            let tokenA = PropertyTest.randomJWT()
            let tokenB = PropertyTest.randomJWT()
            
            // Login with token A
            var componentsA = URLComponents()
            componentsA.scheme = "ghostype"
            componentsA.host = "auth"
            componentsA.queryItems = [URLQueryItem(name: "token", value: tokenA)]
            guard let urlA = componentsA.url else { return true }
            authManager.handleAuthURL(urlA)
            
            // Login with token B (overwrites A)
            var componentsB = URLComponents()
            componentsB.scheme = "ghostype"
            componentsB.host = "auth"
            componentsB.queryItems = [URLQueryItem(name: "token", value: tokenB)]
            guard let urlB = componentsB.url else { return true }
            authManager.handleAuthURL(urlB)
            
            // Should have token B
            guard authManager.getToken() == tokenB else { return false }
            
            // Logout
            authManager.logout()
            
            // Should be fully cleaned up
            guard !authManager.isLoggedIn else { return false }
            guard authManager.getToken() == nil else { return false }
            
            return true
        }
    }
}
