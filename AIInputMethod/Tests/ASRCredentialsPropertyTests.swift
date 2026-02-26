import XCTest
import Foundation

// Feature: api-online-auth, Property 12: ASR 凭证获取响应解析正确性
// Feature: api-online-auth, Property 13: ASR 凭证获取失败保持空状态
// **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

// MARK: - Test Copy of ASRCredentialsResponse
// Since the test target cannot import the executable target,
// we duplicate the relevant struct here for testing.

private struct TestASRCredentialsResponse: Codable, Equatable {
    let app_id: String
    let access_token: String
}

// MARK: - Testable Credentials Holder
// Replicates the credential caching and hasCredentials() logic
// from DoubaoSpeechService without requiring the full service.

private class TestableCredentialsHolder {
    var cachedAppId: String = ""
    var cachedAccessToken: String = ""

    func hasCredentials() -> Bool {
        return !cachedAppId.isEmpty && !cachedAccessToken.isEmpty
    }

    /// Simulates the credential update logic from fetchCredentials()
    func applyCredentials(from response: TestASRCredentialsResponse) {
        self.cachedAppId = response.app_id
        self.cachedAccessToken = response.access_token
    }
}

// MARK: - Random Generators for ASR Credential Tests

private struct ASRTestGenerators {

    /// Generate a random app_id string (non-empty, alphanumeric)
    static func randomAppId() -> String {
        return PropertyTest.randomString(minLength: 1, maxLength: 64)
    }

    /// Generate a random access_token string (non-empty, alphanumeric)
    static func randomAccessToken() -> String {
        return PropertyTest.randomString(minLength: 1, maxLength: 128)
    }

    /// Generate random bytes that are NOT valid JSON
    static func randomNonJSONData() -> Data {
        let length = Int.random(in: 1...256)
        var bytes = [UInt8](repeating: 0, count: length)
        for i in 0..<length {
            // Use bytes that are unlikely to form valid JSON
            bytes[i] = UInt8.random(in: 0...255)
        }
        return Data(bytes)
    }

    /// Generate a random JSON object that is missing required fields
    static func randomIncompleteJSON() -> Data {
        let variant = Int.random(in: 0...4)
        let json: [String: Any]
        switch variant {
        case 0:
            // Only app_id, missing access_token
            json = ["app_id": randomAppId()]
        case 1:
            // Only access_token, missing app_id
            json = ["access_token": randomAccessToken()]
        case 2:
            // Empty object
            json = [:]
        case 3:
            // Completely unrelated fields
            json = [
                "name": PropertyTest.randomString(),
                "value": Int.random(in: 0...1000)
            ]
        default:
            // Array instead of object
            let data = try! JSONSerialization.data(withJSONObject: [1, 2, 3])
            return data
        }
        return try! JSONSerialization.data(withJSONObject: json)
    }
}

// MARK: - Property Tests

/// Property-based tests for ASR credential fetching logic
/// Feature: api-online-auth
/// **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**
final class ASRCredentialsPropertyTests: XCTestCase {

    // MARK: - Property 12: ASR 凭证获取响应解析正确性

    /// Feature: api-online-auth, Property 12: ASR 凭证获取响应解析正确性
    /// For any valid ASR credentials response JSON (containing app_id and access_token fields),
    /// JSON encode/decode round-trip should preserve the values exactly.
    /// **Validates: Requirements 11.1, 11.2**
    func testProperty12_validCredentialsRoundTrip() throws {
        PropertyTest.verify(
            "ASRCredentialsResponse JSON round-trip preserves app_id and access_token",
            iterations: 100
        ) {
            let appId = ASRTestGenerators.randomAppId()
            let accessToken = ASRTestGenerators.randomAccessToken()

            let original = TestASRCredentialsResponse(
                app_id: appId,
                access_token: accessToken
            )

            // Encode to JSON
            let encoder = JSONEncoder()
            guard let encoded = try? encoder.encode(original) else { return false }

            // Decode back
            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(TestASRCredentialsResponse.self, from: encoded) else {
                return false
            }

            // Values should be preserved exactly
            guard decoded.app_id == appId else { return false }
            guard decoded.access_token == accessToken else { return false }
            guard decoded == original else { return false }

            return true
        }
    }

    /// For any valid ASR credentials response JSON built from raw dictionary,
    /// decoding should produce the correct app_id and access_token values.
    /// **Validates: Requirements 11.1, 11.2**
    func testProperty12_validCredentialsFromRawJSON() throws {
        PropertyTest.verify(
            "ASRCredentialsResponse from raw JSON dictionary preserves values",
            iterations: 100
        ) {
            let appId = ASRTestGenerators.randomAppId()
            let accessToken = ASRTestGenerators.randomAccessToken()

            // Build raw JSON (simulating server response)
            let jsonDict: [String: Any] = [
                "app_id": appId,
                "access_token": accessToken
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict) else {
                return false
            }

            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(TestASRCredentialsResponse.self, from: jsonData) else {
                return false
            }

            guard decoded.app_id == appId else { return false }
            guard decoded.access_token == accessToken else { return false }

            return true
        }
    }

    /// For any non-empty app_id and access_token, after applying credentials,
    /// hasCredentials() should return true.
    /// **Validates: Requirements 11.2, 11.3**
    func testProperty12_nonEmptyCredentialsMeansHasCredentials() throws {
        PropertyTest.verify(
            "Non-empty app_id and access_token → hasCredentials() returns true",
            iterations: 100
        ) {
            let appId = ASRTestGenerators.randomAppId()
            let accessToken = ASRTestGenerators.randomAccessToken()

            let holder = TestableCredentialsHolder()

            // Pre-condition: fresh holder has no credentials
            guard !holder.hasCredentials() else { return false }

            // Apply credentials from a valid response
            let response = TestASRCredentialsResponse(
                app_id: appId,
                access_token: accessToken
            )
            holder.applyCredentials(from: response)

            // Post-condition: hasCredentials should be true
            guard holder.hasCredentials() else { return false }

            // Cached values should match
            guard holder.cachedAppId == appId else { return false }
            guard holder.cachedAccessToken == accessToken else { return false }

            return true
        }
    }

    // MARK: - Property 13: ASR 凭证获取失败保持空状态

    /// Feature: api-online-auth, Property 13: ASR 凭证获取失败保持空状态
    /// A fresh credentials holder should have empty credentials and hasCredentials() == false.
    /// **Validates: Requirements 11.4, 11.5**
    func testProperty13_freshServiceHasNoCredentials() throws {
        PropertyTest.verify(
            "Fresh credentials holder → hasCredentials() returns false",
            iterations: 100
        ) {
            let holder = TestableCredentialsHolder()

            // Fresh holder should have empty credentials
            guard holder.cachedAppId.isEmpty else { return false }
            guard holder.cachedAccessToken.isEmpty else { return false }
            guard !holder.hasCredentials() else { return false }

            return true
        }
    }

    /// For any random non-JSON data, ASRCredentialsResponse decoding should fail.
    /// This validates that invalid server responses don't corrupt credential state.
    /// **Validates: Requirements 11.4**
    func testProperty13_invalidJSONCannotDecode() throws {
        PropertyTest.verify(
            "Random non-JSON data → ASRCredentialsResponse decoding fails",
            iterations: 100
        ) {
            let invalidData = ASRTestGenerators.randomNonJSONData()

            let decoder = JSONDecoder()
            let result = try? decoder.decode(TestASRCredentialsResponse.self, from: invalidData)

            // Decoding should fail (return nil)
            guard result == nil else { return false }

            return true
        }
    }

    /// For any JSON missing required fields (app_id or access_token),
    /// ASRCredentialsResponse decoding should fail.
    /// **Validates: Requirements 11.4**
    func testProperty13_missingFieldsCannotDecode() throws {
        PropertyTest.verify(
            "JSON missing required fields → ASRCredentialsResponse decoding fails",
            iterations: 100
        ) {
            let incompleteData = ASRTestGenerators.randomIncompleteJSON()

            let decoder = JSONDecoder()
            let result = try? decoder.decode(TestASRCredentialsResponse.self, from: incompleteData)

            // Decoding should fail (return nil)
            guard result == nil else { return false }

            return true
        }
    }

    /// After a failed decode attempt, credentials holder should remain in empty state.
    /// This simulates the full failure flow: fetch fails → credentials stay empty.
    /// **Validates: Requirements 11.4, 11.5**
    func testProperty13_failedFetchKeepsEmptyState() throws {
        PropertyTest.verify(
            "Failed credential fetch → credentials remain empty, hasCredentials() == false",
            iterations: 100
        ) {
            let holder = TestableCredentialsHolder()

            // Simulate a failed fetch: try to decode invalid data
            let invalidData: Data
            if Bool.random() {
                invalidData = ASRTestGenerators.randomNonJSONData()
            } else {
                invalidData = ASRTestGenerators.randomIncompleteJSON()
            }

            let decoder = JSONDecoder()
            if let response = try? decoder.decode(TestASRCredentialsResponse.self, from: invalidData) {
                // If somehow it decoded (shouldn't happen for incomplete JSON), apply it
                holder.applyCredentials(from: response)
            }
            // If decode failed, credentials should remain empty (no update)

            // Credentials should still be empty after failed fetch
            guard !holder.hasCredentials() else { return false }
            guard holder.cachedAppId.isEmpty else { return false }
            guard holder.cachedAccessToken.isEmpty else { return false }

            return true
        }
    }
}
