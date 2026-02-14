//
//  GhostTwinProfilePropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for GhostTwinProfile JSON round-trip consistency
//  Feature: ghost-twin-on-device, Property 1: Profile round-trip consistency
//

import XCTest
import Foundation

// Uses shared PropertyTest from AuthManagerPropertyTests.swift

// MARK: - Test Copy of GhostTwinProfile (Equatable)

/// Since the test target cannot import the executable target,
/// we create a test copy of the model that conforms to Equatable for comparison.
private struct TestGhostTwinProfile: Codable, Equatable {
    var version: Int
    var level: Int
    var totalXP: Int
    var personalityTags: [String]
    var profileText: String
    var createdAt: Date
    var updatedAt: Date

    /// Generate a random instance for property testing
    static func random() -> TestGhostTwinProfile {
        let version = Int.random(in: 0...1000)
        let level = Int.random(in: 1...10)
        let totalXP = Int.random(in: 0...200_000)
        let personalityTags = generateRandomTags()
        let profileText = generateRandomProfileText()
        // Use dates with integer seconds to avoid sub-second precision loss in ISO 8601
        let createdAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))
        let updatedAt = Date(timeIntervalSince1970: Double(Int.random(in: 0...2_000_000_000)))

        return TestGhostTwinProfile(
            version: version,
            level: level,
            totalXP: totalXP,
            personalityTags: personalityTags,
            profileText: profileText,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Generate random personality tags
    private static func generateRandomTags() -> [String] {
        let possibleTags = [
            "直率", "理性", "幽默", "体面", "独立思考",
            "效率至上", "冷幽默", "热情", "感性", "简洁",
            "casual", "professional", "creative", "analytical", "empathetic"
        ]
        let count = Int.random(in: 0...6)
        return Array(possibleTags.shuffled().prefix(count))
    }

    /// Generate random profile text (simulating 形/神/法 content)
    private static func generateRandomProfileText() -> String {
        let templates = [
            "",
            "Speaker 全息分析报告\n\nI. 口语 DNA 分析（「形」）\n偏向短句爆发型...",
            "人格档案 v3\n\n形层：口癖「嗯...」「就是说」\n神层：理性主义者\n法层：同意词「行」「好的」",
            "这是一段包含 emoji 🎭 和特殊字符 <>&\"' 的档案文本\n换行测试\n\t制表符测试",
            String(repeating: "长文本测试。", count: Int.random(in: 1...50)),
            "Mixed 中英文 content with numbers 12345 and symbols !@#$%"
        ]
        return templates.randomElement()!
    }
}

// MARK: - Property Tests

/// Property-based tests for GhostTwinProfile JSON round-trip consistency
/// Feature: ghost-twin-on-device, Property 1: Profile round-trip consistency
final class GhostTwinProfilePropertyTests: XCTestCase {

    // MARK: - Property 1: Profile round-trip consistency

    /// Property 1: Profile round-trip consistency
    /// *For any* valid GhostTwinProfile (with arbitrary version, level 1-10,
    /// totalXP >= 0, any personalityTags, any profileText, and valid dates),
    /// encoding to JSON then decoding should produce an object equal to the original.
    /// Feature: ghost-twin-on-device, Property 1: Profile round-trip consistency
    /// **Validates: Requirements 1.7**
    func testProperty1_ProfileRoundTripConsistency() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        PropertyTest.verify(
            "GhostTwinProfile JSON round-trip",
            iterations: 100
        ) {
            let original = TestGhostTwinProfile.random()

            guard let data = try? encoder.encode(original) else {
                return false
            }

            guard let decoded = try? decoder.decode(TestGhostTwinProfile.self, from: data) else {
                return false
            }

            return original == decoded
        }
    }

    // MARK: - Edge Cases

    /// Edge case: Initial empty profile round-trip
    /// **Validates: Requirements 1.5, 1.7**
    func testEdgeCase_InitialProfileRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let now = Date(timeIntervalSince1970: Double(Int(Date().timeIntervalSince1970)))
        let original = TestGhostTwinProfile(
            version: 0,
            level: 1,
            totalXP: 0,
            personalityTags: [],
            profileText: "",
            createdAt: now,
            updatedAt: now
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode initial profile")
            return
        }

        guard let decoded = try? decoder.decode(TestGhostTwinProfile.self, from: data) else {
            XCTFail("Failed to decode initial profile")
            return
        }

        XCTAssertEqual(original, decoded, "Initial empty profile should round-trip correctly")
        XCTAssertEqual(decoded.version, 0)
        XCTAssertEqual(decoded.level, 1)
        XCTAssertEqual(decoded.totalXP, 0)
        XCTAssertTrue(decoded.personalityTags.isEmpty)
        XCTAssertEqual(decoded.profileText, "")
    }

    /// Edge case: Profile with max values
    /// **Validates: Requirements 1.7**
    func testEdgeCase_MaxValuesRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestGhostTwinProfile(
            version: 999,
            level: 10,
            totalXP: 200_000,
            personalityTags: ["直率", "理性", "幽默", "体面", "独立思考", "效率至上"],
            profileText: String(repeating: "长文本。", count: 100),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 2_000_000_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode max-values profile")
            return
        }

        guard let decoded = try? decoder.decode(TestGhostTwinProfile.self, from: data) else {
            XCTFail("Failed to decode max-values profile")
            return
        }

        XCTAssertEqual(original, decoded, "Max-values profile should round-trip correctly")
        XCTAssertEqual(decoded.level, 10)
        XCTAssertEqual(decoded.totalXP, 200_000)
        XCTAssertEqual(decoded.personalityTags.count, 6)
    }

    /// Edge case: Profile with unicode and special characters in profileText
    /// **Validates: Requirements 1.7**
    func testEdgeCase_UnicodeProfileTextRoundTrip() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = TestGhostTwinProfile(
            version: 5,
            level: 3,
            totalXP: 22500,
            personalityTags: ["emoji-lover 🤖", "中文标签"],
            profileText: "包含 emoji 🎭🛡️ 和特殊字符 <>&\"'\n换行\t制表符\n日本語テスト",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000)
        )

        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode unicode profile")
            return
        }

        guard let decoded = try? decoder.decode(TestGhostTwinProfile.self, from: data) else {
            XCTFail("Failed to decode unicode profile")
            return
        }

        XCTAssertEqual(original, decoded, "Unicode profile should round-trip correctly")
        XCTAssertTrue(decoded.profileText.contains("🎭"))
        XCTAssertTrue(decoded.profileText.contains("日本語テスト"))
    }
}
