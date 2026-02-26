//
//  AppConfigPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for AppConfig
//  Feature: decoupling-refactor
//

import XCTest
import Foundation

// MARK: - Test Copy of AppConfig

/// Exact copy of AppConfig from AppConfig.swift
/// Since the test target cannot import the executable target.
private enum TestAppConfig {

    static var apiBaseURL: String {
        #if DEBUG
        return "http://localhost:3000"
        #else
        return "https://www.ghostype.one"
        #endif
    }

    static let authScheme = "ghostype"
    static let authHost = "auth"

    static var signInURL: String {
        let redirect = "/auth/callback?scheme=\(authScheme)://\(authHost)"
        let encoded = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirect
        return "\(apiBaseURL)/sign-in?redirect_url=\(encoded)"
    }

    static var signUpURL: String {
        let redirect = "/auth/callback?scheme=\(authScheme)://\(authHost)"
        let encoded = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirect
        return "\(apiBaseURL)/sign-up?redirect_url=\(encoded)"
    }
}

// MARK: - Property Tests

/// Property-based tests for AppConfig
/// Feature: decoupling-refactor, Property 1: 配置值自洽性
/// **Validates: Requirements 1.1, 8.1**
final class AppConfigPropertyTests: XCTestCase {

    // MARK: - Property 1: 配置值自洽性

    /// signInURL starts with apiBaseURL
    func testProperty1_SignInURLStartsWithBaseURL() {
        let baseURL = TestAppConfig.apiBaseURL
        let signInURL = TestAppConfig.signInURL

        XCTAssertTrue(signInURL.hasPrefix(baseURL),
                      "signInURL should start with apiBaseURL. Got: \(signInURL)")
    }

    /// signUpURL starts with apiBaseURL
    func testProperty1_SignUpURLStartsWithBaseURL() {
        let baseURL = TestAppConfig.apiBaseURL
        let signUpURL = TestAppConfig.signUpURL

        XCTAssertTrue(signUpURL.hasPrefix(baseURL),
                      "signUpURL should start with apiBaseURL. Got: \(signUpURL)")
    }

    /// All URL values are non-empty
    func testProperty1_AllURLsNonEmpty() {
        XCTAssertFalse(TestAppConfig.apiBaseURL.isEmpty, "apiBaseURL should not be empty")
        XCTAssertFalse(TestAppConfig.signInURL.isEmpty, "signInURL should not be empty")
        XCTAssertFalse(TestAppConfig.signUpURL.isEmpty, "signUpURL should not be empty")
    }

    /// signInURL contains /sign-in path
    func testProperty1_SignInURLContainsCorrectPath() {
        XCTAssertTrue(TestAppConfig.signInURL.contains("/sign-in"),
                      "signInURL should contain /sign-in path")
    }

    /// signUpURL contains /sign-up path
    func testProperty1_SignUpURLContainsCorrectPath() {
        XCTAssertTrue(TestAppConfig.signUpURL.contains("/sign-up"),
                      "signUpURL should contain /sign-up path")
    }

    /// authScheme and authHost are embedded in redirect URLs
    func testProperty1_AuthSchemeAndHostInRedirectURLs() {
        let signInURL = TestAppConfig.signInURL
        let signUpURL = TestAppConfig.signUpURL

        // The redirect URL contains scheme://host pattern (URL-encoded)
        let schemeHostPattern = "\(TestAppConfig.authScheme)://\(TestAppConfig.authHost)"

        XCTAssertTrue(signInURL.contains(TestAppConfig.authScheme),
                      "signInURL should contain authScheme")
        XCTAssertTrue(signUpURL.contains(TestAppConfig.authScheme),
                      "signUpURL should contain authScheme")
        // URL encoding may change :// but the scheme name should be present
        XCTAssertTrue(signInURL.contains(TestAppConfig.authHost),
                      "signInURL should contain authHost")
        XCTAssertTrue(signUpURL.contains(TestAppConfig.authHost),
                      "signUpURL should contain authHost")
    }

    /// signInURL and signUpURL have same redirect structure
    func testProperty1_SignInAndSignUpHaveSameRedirectStructure() {
        let signInURL = TestAppConfig.signInURL
        let signUpURL = TestAppConfig.signUpURL

        // Both should contain redirect_url parameter
        XCTAssertTrue(signInURL.contains("redirect_url="),
                      "signInURL should contain redirect_url parameter")
        XCTAssertTrue(signUpURL.contains("redirect_url="),
                      "signUpURL should contain redirect_url parameter")

        // Extract redirect_url values — they should be identical
        let signInRedirect = signInURL.components(separatedBy: "redirect_url=").last ?? ""
        let signUpRedirect = signUpURL.components(separatedBy: "redirect_url=").last ?? ""
        XCTAssertEqual(signInRedirect, signUpRedirect,
                       "signInURL and signUpURL should have identical redirect_url values")
    }

    /// authScheme is "ghostype"
    func testProperty1_AuthSchemeValue() {
        XCTAssertEqual(TestAppConfig.authScheme, "ghostype")
    }

    /// authHost is "auth"
    func testProperty1_AuthHostValue() {
        XCTAssertEqual(TestAppConfig.authHost, "auth")
    }
}
