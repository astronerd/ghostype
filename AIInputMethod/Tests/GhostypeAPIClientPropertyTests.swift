import XCTest
import Foundation

// MARK: - Testable Copies of Production Types
// Since the test target cannot import the executable target,
// we duplicate the relevant structs/logic here for testing.

// MARK: - GhostypeRequest (Test Copy)

/// Exact copy of GhostypeRequest from GhostypeModels.swift
private struct TestGhostypeRequest: Codable {
    let mode: String              // "polish" | "translate"
    let message: String
    var profile: String?          // 仅 polish 模式
    var custom_prompt: String?    // 仅 profile == "custom" 时
    var enable_in_sentence: Bool?
    var enable_trigger: Bool?
    var trigger_word: String?
    var translate_language: String? // 仅 translate 模式
}

// MARK: - GhostypeResponse (Test Copy)

/// Exact copy of GhostypeResponse from GhostypeModels.swift
private struct TestGhostypeResponse: Codable, Equatable {
    let text: String
    let usage: Usage

    struct Usage: Codable, Equatable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

// MARK: - Testable buildRequest Function

/// Replicates the logic of GhostypeAPIClient.buildRequest()
/// but accepts a token parameter instead of reading from AuthManager singleton.
private func testableBuildRequest(
    url: URL,
    method: String,
    timeout: TimeInterval,
    deviceId: String,
    token: String?
) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = timeout

    // 公共 Header
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")

    // 有 JWT 时添加 Authorization Header
    if let token = token {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    return request
}

// MARK: - Testable Polish Request Builder

/// Replicates the logic of GhostypeAPIClient.polish() request body construction
private func buildPolishRequestBody(
    text: String,
    profile: String,
    customPrompt: String?,
    enableInSentence: Bool,
    enableTrigger: Bool,
    triggerWord: String
) -> TestGhostypeRequest {
    return TestGhostypeRequest(
        mode: "polish",
        message: text,
        profile: profile,
        custom_prompt: profile == "custom" ? customPrompt : nil,
        enable_in_sentence: enableInSentence,
        enable_trigger: enableTrigger,
        trigger_word: enableTrigger ? triggerWord : nil
    )
}

// MARK: - Testable Translate Request Builder

/// Replicates the logic of GhostypeAPIClient.translate() request body construction
private func buildTranslateRequestBody(
    text: String,
    language: String
) -> TestGhostypeRequest {
    return TestGhostypeRequest(
        mode: "translate",
        message: text,
        translate_language: language
    )
}

// MARK: - Random Generators for Property Tests

private struct APITestGenerators {

    /// Generate a random device ID (UUID format)
    static func randomDeviceId() -> String {
        return UUID().uuidString
    }

    /// Generate a random polish profile
    static func randomPolishProfile() -> String {
        let profiles = ["standard", "professional", "casual", "concise", "creative", "custom"]
        return profiles.randomElement()!
    }

    /// Generate a random translate language
    static func randomTranslateLanguage() -> String {
        let languages = ["chineseEnglish", "chineseJapanese", "auto"]
        return languages.randomElement()!
    }

    /// Generate a random message text (non-empty)
    static func randomMessage() -> String {
        return PropertyTest.randomString(minLength: 1, maxLength: 200)
    }

    /// Generate a random custom prompt (may be nil)
    static func randomCustomPrompt() -> String? {
        if Bool.random() {
            return PropertyTest.randomString(minLength: 1, maxLength: 100)
        }
        return nil
    }

    /// Generate a random trigger word
    static func randomTriggerWord() -> String {
        return PropertyTest.randomString(minLength: 1, maxLength: 20)
    }

    /// Generate a random HTTP method
    static func randomHTTPMethod() -> String {
        let methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]
        return methods.randomElement()!
    }

    /// Generate a random timeout
    static func randomTimeout() -> TimeInterval {
        return TimeInterval(Int.random(in: 5...60))
    }

    /// Generate a random URL
    static func randomURL() -> URL {
        let paths = ["/api/v1/llm/chat", "/api/v1/user/profile", "/api/v1/asr/credentials"]
        let base = "https://ghostype.com"
        return URL(string: "\(base)\(paths.randomElement()!)")!
    }

    /// Generate a random positive integer for token counts
    static func randomTokenCount() -> Int {
        return Int.random(in: 0...10000)
    }

    /// Generate a random response text
    static func randomResponseText() -> String {
        return PropertyTest.randomString(minLength: 1, maxLength: 500)
    }
}

// MARK: - Property Tests

/// Property-based tests for GhostypeAPIClient
/// Feature: api-online-auth
/// **Validates: Requirements 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2**
final class GhostypeAPIClientPropertyTests: XCTestCase {

    // MARK: - Property 4: 请求 Header 与登录状态一致

    /// Feature: api-online-auth, Property 4: 请求 Header 与登录状态一致
    /// For any API request, the Authorization header should be present only when logged in
    /// (with Bearer {jwt}), and X-Device-Id should always be present.
    /// **Validates: Requirements 3.1, 3.2, 3.3**
    func testProperty4_AuthorizationHeaderPresentWhenLoggedIn() {
        PropertyTest.verify(
            "When token is provided, Authorization header should be 'Bearer {jwt}'",
            iterations: 100
        ) {
            let token = PropertyTest.randomJWT()
            let deviceId = APITestGenerators.randomDeviceId()
            let url = APITestGenerators.randomURL()
            let method = APITestGenerators.randomHTTPMethod()
            let timeout = APITestGenerators.randomTimeout()

            let request = testableBuildRequest(
                url: url,
                method: method,
                timeout: timeout,
                deviceId: deviceId,
                token: token
            )

            // Authorization header should be present with Bearer prefix
            guard let authHeader = request.value(forHTTPHeaderField: "Authorization") else {
                return false
            }
            guard authHeader == "Bearer \(token)" else { return false }

            // X-Device-Id should always be present
            guard let deviceIdHeader = request.value(forHTTPHeaderField: "X-Device-Id") else {
                return false
            }
            guard deviceIdHeader == deviceId else { return false }

            // Content-Type should always be present
            guard let contentType = request.value(forHTTPHeaderField: "Content-Type") else {
                return false
            }
            guard contentType == "application/json" else { return false }

            return true
        }
    }

    /// **Validates: Requirements 3.1, 3.3**
    func testProperty4_NoAuthorizationHeaderWhenNotLoggedIn() {
        PropertyTest.verify(
            "When token is nil, Authorization header should be absent",
            iterations: 100
        ) {
            let deviceId = APITestGenerators.randomDeviceId()
            let url = APITestGenerators.randomURL()
            let method = APITestGenerators.randomHTTPMethod()
            let timeout = APITestGenerators.randomTimeout()

            let request = testableBuildRequest(
                url: url,
                method: method,
                timeout: timeout,
                deviceId: deviceId,
                token: nil
            )

            // Authorization header should NOT be present
            guard request.value(forHTTPHeaderField: "Authorization") == nil else {
                return false
            }

            // X-Device-Id should always be present
            guard let deviceIdHeader = request.value(forHTTPHeaderField: "X-Device-Id") else {
                return false
            }
            guard deviceIdHeader == deviceId else { return false }

            // Content-Type should always be present
            guard let contentType = request.value(forHTTPHeaderField: "Content-Type") else {
                return false
            }
            guard contentType == "application/json" else { return false }

            return true
        }
    }

    /// Combined: For any login state (random token or nil), headers are consistent
    /// **Validates: Requirements 3.1, 3.2, 3.3**
    func testProperty4_HeaderConsistencyForAnyLoginState() {
        PropertyTest.verify(
            "For any login state, headers are consistent with that state",
            iterations: 100
        ) {
            let isLoggedIn = Bool.random()
            let token: String? = isLoggedIn ? PropertyTest.randomJWT() : nil
            let deviceId = APITestGenerators.randomDeviceId()
            let url = APITestGenerators.randomURL()
            let method = APITestGenerators.randomHTTPMethod()
            let timeout = APITestGenerators.randomTimeout()

            let request = testableBuildRequest(
                url: url,
                method: method,
                timeout: timeout,
                deviceId: deviceId,
                token: token
            )

            // X-Device-Id should ALWAYS be present
            guard let deviceIdHeader = request.value(forHTTPHeaderField: "X-Device-Id") else {
                return false
            }
            guard deviceIdHeader == deviceId else { return false }

            // Authorization header presence should match login state
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            if isLoggedIn {
                guard authHeader == "Bearer \(token!)" else { return false }
            } else {
                guard authHeader == nil else { return false }
            }

            return true
        }
    }

    // MARK: - Property 5: 润色请求体结构正确性

    /// Feature: api-online-auth, Property 5: 润色请求体结构正确性
    /// For any polish parameters, the request body JSON should contain `mode: "polish"` and `message`,
    /// and `custom_prompt` should only be non-null when profile is "custom".
    /// **Validates: Requirements 4.1**
    func testProperty5_PolishRequestBodyStructure() {
        PropertyTest.verify(
            "Polish request body has mode='polish', message, and custom_prompt only when profile='custom'",
            iterations: 100
        ) {
            let message = APITestGenerators.randomMessage()
            let profile = APITestGenerators.randomPolishProfile()
            let customPrompt = APITestGenerators.randomCustomPrompt()
            let enableInSentence = Bool.random()
            let enableTrigger = Bool.random()
            let triggerWord = APITestGenerators.randomTriggerWord()

            let body = buildPolishRequestBody(
                text: message,
                profile: profile,
                customPrompt: customPrompt,
                enableInSentence: enableInSentence,
                enableTrigger: enableTrigger,
                triggerWord: triggerWord
            )

            // Encode to JSON and decode as dictionary for inspection
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(body) else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }

            // mode should be "polish"
            guard let mode = json["mode"] as? String, mode == "polish" else { return false }

            // message should be present and match input
            guard let jsonMessage = json["message"] as? String, jsonMessage == message else {
                return false
            }

            // profile should be present
            guard let jsonProfile = json["profile"] as? String, jsonProfile == profile else {
                return false
            }

            // custom_prompt should only be non-null when profile is "custom"
            if profile == "custom" {
                // custom_prompt should be the provided customPrompt (may still be nil if customPrompt was nil)
                let jsonCustomPrompt = json["custom_prompt"] as? String
                if customPrompt != nil {
                    guard jsonCustomPrompt == customPrompt else { return false }
                }
            } else {
                // custom_prompt should be null/absent when profile is not "custom"
                let hasCustomPrompt = json["custom_prompt"] is String
                guard !hasCustomPrompt else { return false }
            }

            return true
        }
    }

    /// Additional: trigger_word should only be present when enableTrigger is true
    /// **Validates: Requirements 4.1**
    func testProperty5_PolishTriggerWordConsistency() {
        PropertyTest.verify(
            "Polish request: trigger_word present only when enable_trigger is true",
            iterations: 100
        ) {
            let message = APITestGenerators.randomMessage()
            let profile = APITestGenerators.randomPolishProfile()
            let customPrompt = APITestGenerators.randomCustomPrompt()
            let enableInSentence = Bool.random()
            let enableTrigger = Bool.random()
            let triggerWord = APITestGenerators.randomTriggerWord()

            let body = buildPolishRequestBody(
                text: message,
                profile: profile,
                customPrompt: customPrompt,
                enableInSentence: enableInSentence,
                enableTrigger: enableTrigger,
                triggerWord: triggerWord
            )

            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(body) else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }

            let hasTriggerWord = json["trigger_word"] is String
            if enableTrigger {
                // trigger_word should be present
                guard hasTriggerWord else { return false }
            } else {
                // trigger_word should be null/absent
                guard !hasTriggerWord else { return false }
            }

            return true
        }
    }

    // MARK: - Property 6: 翻译请求体结构正确性

    /// Feature: api-online-auth, Property 6: 翻译请求体结构正确性
    /// For any translate parameters, the request body JSON should contain `mode: "translate"`,
    /// `message`, and `translate_language`, and should NOT contain polish-specific fields.
    /// **Validates: Requirements 5.1**
    func testProperty6_TranslateRequestBodyStructure() {
        PropertyTest.verify(
            "Translate request body has mode='translate', message, translate_language, and no polish fields",
            iterations: 100
        ) {
            let message = APITestGenerators.randomMessage()
            let language = APITestGenerators.randomTranslateLanguage()

            let body = buildTranslateRequestBody(
                text: message,
                language: language
            )

            // Encode to JSON and decode as dictionary for inspection
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(body) else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }

            // mode should be "translate"
            guard let mode = json["mode"] as? String, mode == "translate" else { return false }

            // message should be present and match input
            guard let jsonMessage = json["message"] as? String, jsonMessage == message else {
                return false
            }

            // translate_language should be present and match input
            guard let jsonLang = json["translate_language"] as? String, jsonLang == language else {
                return false
            }

            // Polish-specific fields should NOT be present (as non-null values)
            let hasProfile = json["profile"] is String
            let hasCustomPrompt = json["custom_prompt"] is String
            let hasEnableInSentence = json["enable_in_sentence"] is Bool
            let hasEnableTrigger = json["enable_trigger"] is Bool
            let hasTriggerWord = json["trigger_word"] is String

            guard !hasProfile else { return false }
            guard !hasCustomPrompt else { return false }
            guard !hasEnableInSentence else { return false }
            guard !hasEnableTrigger else { return false }
            guard !hasTriggerWord else { return false }

            return true
        }
    }

    // MARK: - Property 7: API 响应解析一致性（round-trip）

    /// Feature: api-online-auth, Property 7: API 响应解析一致性（round-trip）
    /// For any valid GhostypeResponse JSON, decode then re-encode should produce
    /// equivalent JSON structure.
    /// **Validates: Requirements 4.2, 5.2**
    func testProperty7_ResponseRoundTrip() {
        PropertyTest.verify(
            "GhostypeResponse decode → encode produces equivalent JSON",
            iterations: 100
        ) {
            // Generate a random valid GhostypeResponse
            let text = APITestGenerators.randomResponseText()
            let inputTokens = APITestGenerators.randomTokenCount()
            let outputTokens = APITestGenerators.randomTokenCount()

            let original = TestGhostypeResponse(
                text: text,
                usage: TestGhostypeResponse.Usage(
                    input_tokens: inputTokens,
                    output_tokens: outputTokens
                )
            )

            // Encode → Decode → Compare
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            guard let encoded = try? encoder.encode(original) else { return false }
            guard let decoded = try? decoder.decode(TestGhostypeResponse.self, from: encoded) else {
                return false
            }

            // The decoded object should be equal to the original
            guard decoded == original else { return false }

            // Also verify the round-trip: encode the decoded object and compare JSON
            guard let reEncoded = try? encoder.encode(decoded) else { return false }
            guard let reDecoded = try? decoder.decode(TestGhostypeResponse.self, from: reEncoded) else {
                return false
            }

            guard reDecoded == original else { return false }

            return true
        }
    }

    /// Additional: Round-trip from raw JSON string
    /// **Validates: Requirements 4.2, 5.2**
    func testProperty7_ResponseRoundTripFromJSON() {
        PropertyTest.verify(
            "GhostypeResponse from raw JSON → encode → decode produces same values",
            iterations: 100
        ) {
            let text = APITestGenerators.randomResponseText()
            let inputTokens = APITestGenerators.randomTokenCount()
            let outputTokens = APITestGenerators.randomTokenCount()

            // Build raw JSON (simulating server response)
            let jsonDict: [String: Any] = [
                "text": text,
                "usage": [
                    "input_tokens": inputTokens,
                    "output_tokens": outputTokens
                ]
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict) else {
                return false
            }

            let decoder = JSONDecoder()
            let encoder = JSONEncoder()

            // Decode from raw JSON
            guard let decoded = try? decoder.decode(TestGhostypeResponse.self, from: jsonData) else {
                return false
            }

            // Verify decoded values match input
            guard decoded.text == text else { return false }
            guard decoded.usage.input_tokens == inputTokens else { return false }
            guard decoded.usage.output_tokens == outputTokens else { return false }

            // Re-encode and re-decode
            guard let reEncoded = try? encoder.encode(decoded) else { return false }
            guard let reDecoded = try? decoder.decode(TestGhostypeResponse.self, from: reEncoded) else {
                return false
            }

            guard reDecoded == decoded else { return false }

            return true
        }
    }
}
