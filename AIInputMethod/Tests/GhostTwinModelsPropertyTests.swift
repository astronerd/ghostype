//
//  GhostTwinModelsPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for Ghost Twin API models serialization round-trip
//  Feature: ghost-twin-incubator
//

import XCTest
import Foundation

// Uses shared PropertyTest from AuthManagerPropertyTests.swift

// MARK: - Test Copies of Models (Equatable)

/// Since the test target cannot import the executable target,
/// we create test copies of the models that conform to Equatable for comparison.

/// 校准挑战类型 (Test Copy)
private enum TestChallengeType: String, Codable, Equatable, CaseIterable {
    case dilemma                            // 灵魂拷问，500 XP
    case reverseTuring = "reverse_turing"   // 找鬼游戏，300 XP
    case prediction                         // 预判赌局，200 XP
    
    /// 该类型挑战的 XP 奖励
    var xpReward: Int {
        switch self {
        case .dilemma: return 500
        case .reverseTuring: return 300
        case .prediction: return 200
        }
    }
}

/// Ghost Twin 状态响应 (Test Copy)
/// GET /api/v1/ghost-twin/status 返回
private struct TestGhostTwinStatusResponse: Codable, Equatable {
    let level: Int                          // 当前等级 1~10
    let total_xp: Int                       // 总经验值
    let current_level_xp: Int               // 当前等级内的经验值 (0~9999)
    let personality_tags: [String]          // 已捕捉的人格特征标签
    let challenges_remaining_today: Int     // 今日剩余校准挑战次数
    let personality_profile_version: Int    // 人格档案版本号
    
    /// Generate a random instance for property testing
    static func random() -> TestGhostTwinStatusResponse {
        let level = Int.random(in: 1...10)
        let total_xp = Int.random(in: 0...100000)
        let current_level_xp = Int.random(in: 0...9999)
        let personality_tags = generateRandomTags()
        let challenges_remaining_today = Int.random(in: 0...3)
        let personality_profile_version = Int.random(in: 1...100)
        
        return TestGhostTwinStatusResponse(
            level: level,
            total_xp: total_xp,
            current_level_xp: current_level_xp,
            personality_tags: personality_tags,
            challenges_remaining_today: challenges_remaining_today,
            personality_profile_version: personality_profile_version
        )
    }
    
    /// Generate random personality tags
    private static func generateRandomTags() -> [String] {
        let possibleTags = [
            "直接", "委婉", "效率至上", "冷幽默", "热情",
            "理性", "感性", "简洁", "详细", "正式",
            "casual", "professional", "creative", "analytical", "empathetic"
        ]
        let count = Int.random(in: 0...5)
        return Array(possibleTags.shuffled().prefix(count))
    }
}

/// 校准挑战 (Test Copy)
/// GET /api/v1/ghost-twin/challenge 返回
private struct TestCalibrationChallenge: Codable, Equatable, Identifiable {
    let id: String              // challenge_id
    let type: TestChallengeType // dilemma / reverse_turing / prediction
    let scenario: String        // 场景描述文本
    let options: [String]       // 2~3 个选项
    let xp_reward: Int          // 该类型的 XP 奖励
    
    /// Generate a random instance for property testing
    static func random() -> TestCalibrationChallenge {
        let id = UUID().uuidString
        let type = TestChallengeType.allCases.randomElement()!
        let scenario = generateRandomScenario(for: type)
        let options = generateRandomOptions(for: type)
        let xp_reward = type.xpReward
        
        return TestCalibrationChallenge(
            id: id,
            type: type,
            scenario: scenario,
            options: options,
            xp_reward: xp_reward
        )
    }
    
    /// Generate a random scenario based on challenge type
    private static func generateRandomScenario(for type: TestChallengeType) -> String {
        let scenarios: [TestChallengeType: [String]] = [
            .dilemma: [
                "你的同事在会议上抢了你的功劳，你会怎么做？",
                "朋友借钱不还，但他最近遇到了困难，你会怎么处理？",
                "老板让你加班完成一个不合理的任务，你会如何回应？"
            ],
            .reverseTuring: [
                "以下哪段回复最像你的风格？",
                "选出最符合你说话方式的一段文字：",
                "哪个回复听起来最像你会说的话？"
            ],
            .prediction: [
                "当有人说「你这样做不对」时，你最可能的回应是：",
                "收到一封措辞强硬的邮件，你的第一反应是：",
                "朋友突然取消约会，你会说："
            ]
        ]
        return scenarios[type]?.randomElement() ?? "默认场景描述"
    }
    
    /// Generate random options based on challenge type
    private static func generateRandomOptions(for type: TestChallengeType) -> [String] {
        let optionSets: [TestChallengeType: [[String]]] = [
            .dilemma: [
                ["直接指出", "私下沟通", "忍气吞声"],
                ["硬刚", "委婉提醒", "算了"],
                ["当面对质", "找领导反映", "默默记下"]
            ],
            .reverseTuring: [
                ["好的，我知道了。", "收到！马上处理～", "OK，没问题"],
                ["这个方案不错", "我觉得可以试试看", "挺好的，就这么办"],
                ["谢谢你的建议", "感谢反馈！", "好的，我会考虑的"]
            ],
            .prediction: [
                ["「我觉得你说得有道理」", "「为什么这么说？」", "「我不同意」"],
                ["立刻回复", "先冷静一下", "找人商量"],
                ["「没关系，下次吧」", "「怎么了？」", "「好吧...」"]
            ]
        ]
        return optionSets[type]?.randomElement() ?? ["选项A", "选项B"]
    }
}

/// 校准答案响应 (Test Copy)
/// POST /api/v1/ghost-twin/challenge/answer 返回
private struct TestCalibrationAnswerResponse: Codable, Equatable {
    let xp_earned: Int                      // 本次获得的 XP
    let new_total_xp: Int                   // 新的总 XP
    let new_level: Int                      // 新的等级
    let ghost_response: String              // Ghost 的俏皮反馈语
    let personality_tags_updated: [String]  // 更新后的人格特征标签
    
    /// Generate a random instance for property testing
    static func random() -> TestCalibrationAnswerResponse {
        let xp_earned = [200, 300, 500].randomElement()!
        let new_total_xp = Int.random(in: 0...100000)
        let new_level = Int.random(in: 1...10)
        let ghost_response = generateRandomGhostResponse()
        let personality_tags_updated = generateRandomTags()
        
        return TestCalibrationAnswerResponse(
            xp_earned: xp_earned,
            new_total_xp: new_total_xp,
            new_level: new_level,
            ghost_response: ghost_response,
            personality_tags_updated: personality_tags_updated
        )
    }
    
    /// Generate a random ghost response
    private static func generateRandomGhostResponse() -> String {
        let responses = [
            "哈哈，我就知道你会选这个！",
            "有意思，这很像你的风格。",
            "嗯...让我想想这意味着什么。",
            "果然如此！我越来越了解你了。",
            "这个选择很有趣，记下了！",
            "Interesting choice! Noted.",
            "I knew it! You're so predictable.",
            "Hmm, that's unexpected. Let me recalibrate."
        ]
        return responses.randomElement()!
    }
    
    /// Generate random personality tags
    private static func generateRandomTags() -> [String] {
        let possibleTags = [
            "直接", "委婉", "效率至上", "冷幽默", "热情",
            "理性", "感性", "简洁", "详细", "正式",
            "casual", "professional", "creative", "analytical", "empathetic"
        ]
        let count = Int.random(in: 0...5)
        return Array(possibleTags.shuffled().prefix(count))
    }
}

// MARK: - Property Tests

/// Property-based tests for Ghost Twin API models serialization round-trip
/// Feature: ghost-twin-incubator
final class GhostTwinModelsPropertyTests: XCTestCase {
    
    // MARK: - Property 6: API model serialization round-trip
    
    /// Property 6: API model serialization round-trip - GhostTwinStatusResponse
    /// *For any* valid GhostTwinStatusResponse instance, encoding to JSON
    /// and then decoding back shall produce an equivalent object.
    /// Feature: ghost-twin-incubator
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_GhostTwinStatusResponseRoundTrip() {
        PropertyTest.verify(
            "GhostTwinStatusResponse JSON round-trip",
            iterations: 100
        ) {
            // Generate random instance
            let original = TestGhostTwinStatusResponse.random()
            
            // Encode to JSON
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original) else {
                return false
            }
            
            // Decode back
            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(TestGhostTwinStatusResponse.self, from: data) else {
                return false
            }
            
            // Verify equivalence
            return original == decoded
        }
    }
    
    /// Property 6: API model serialization round-trip - CalibrationChallenge
    /// *For any* valid CalibrationChallenge instance, encoding to JSON
    /// and then decoding back shall produce an equivalent object.
    /// Feature: ghost-twin-incubator
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_CalibrationChallengeRoundTrip() {
        PropertyTest.verify(
            "CalibrationChallenge JSON round-trip",
            iterations: 100
        ) {
            // Generate random instance
            let original = TestCalibrationChallenge.random()
            
            // Encode to JSON
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original) else {
                return false
            }
            
            // Decode back
            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(TestCalibrationChallenge.self, from: data) else {
                return false
            }
            
            // Verify equivalence
            return original == decoded
        }
    }
    
    /// Property 6: API model serialization round-trip - CalibrationAnswerResponse
    /// *For any* valid CalibrationAnswerResponse instance, encoding to JSON
    /// and then decoding back shall produce an equivalent object.
    /// Feature: ghost-twin-incubator
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_CalibrationAnswerResponseRoundTrip() {
        PropertyTest.verify(
            "CalibrationAnswerResponse JSON round-trip",
            iterations: 100
        ) {
            // Generate random instance
            let original = TestCalibrationAnswerResponse.random()
            
            // Encode to JSON
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original) else {
                return false
            }
            
            // Decode back
            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(TestCalibrationAnswerResponse.self, from: data) else {
                return false
            }
            
            // Verify equivalence
            return original == decoded
        }
    }
    
    /// Property 6: API model serialization round-trip - ChallengeType enum
    /// *For any* valid ChallengeType value, encoding to JSON
    /// and then decoding back shall produce an equivalent value.
    /// Feature: ghost-twin-incubator
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_ChallengeTypeRoundTrip() {
        PropertyTest.verify(
            "ChallengeType JSON round-trip",
            iterations: 100
        ) {
            // Generate random ChallengeType
            let original = TestChallengeType.allCases.randomElement()!
            
            // Encode to JSON
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original) else {
                return false
            }
            
            // Decode back
            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(TestChallengeType.self, from: data) else {
                return false
            }
            
            // Verify equivalence
            return original == decoded
        }
    }
    
    // MARK: - Additional Property Tests
    
    /// Property 6 (JSON structure): Encoded JSON contains expected keys
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_GhostTwinStatusResponseJSONStructure() {
        PropertyTest.verify(
            "GhostTwinStatusResponse JSON contains expected keys",
            iterations: 100
        ) {
            let original = TestGhostTwinStatusResponse.random()
            
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            
            // Verify all expected keys are present
            let expectedKeys = ["level", "total_xp", "current_level_xp", 
                               "personality_tags", "challenges_remaining_today", 
                               "personality_profile_version"]
            
            for key in expectedKeys {
                guard json[key] != nil else {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Property 6 (JSON structure): CalibrationChallenge JSON contains expected keys
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_CalibrationChallengeJSONStructure() {
        PropertyTest.verify(
            "CalibrationChallenge JSON contains expected keys",
            iterations: 100
        ) {
            let original = TestCalibrationChallenge.random()
            
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            
            // Verify all expected keys are present
            let expectedKeys = ["id", "type", "scenario", "options", "xp_reward"]
            
            for key in expectedKeys {
                guard json[key] != nil else {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Property 6 (JSON structure): CalibrationAnswerResponse JSON contains expected keys
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_CalibrationAnswerResponseJSONStructure() {
        PropertyTest.verify(
            "CalibrationAnswerResponse JSON contains expected keys",
            iterations: 100
        ) {
            let original = TestCalibrationAnswerResponse.random()
            
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            
            // Verify all expected keys are present
            let expectedKeys = ["xp_earned", "new_total_xp", "new_level", 
                               "ghost_response", "personality_tags_updated"]
            
            for key in expectedKeys {
                guard json[key] != nil else {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Property 6 (type preservation): ChallengeType raw values are preserved
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testProperty6_ChallengeTypeRawValuePreservation() {
        PropertyTest.verify(
            "ChallengeType raw values are preserved in JSON",
            iterations: 100
        ) {
            let original = TestChallengeType.allCases.randomElement()!
            
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(original),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return false
            }
            
            // Verify the raw value is in the JSON
            // JSON string will be like "\"dilemma\"" or "\"reverse_turing\""
            let expectedRawValue = "\"\(original.rawValue)\""
            guard jsonString == expectedRawValue else {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Edge Case Tests
    
    /// Edge case: Empty personality_tags array round-trip
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testEdgeCase_EmptyPersonalityTagsRoundTrip() {
        let original = TestGhostTwinStatusResponse(
            level: 1,
            total_xp: 0,
            current_level_xp: 0,
            personality_tags: [],
            challenges_remaining_today: 3,
            personality_profile_version: 1
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode GhostTwinStatusResponse with empty tags")
            return
        }
        
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TestGhostTwinStatusResponse.self, from: data) else {
            XCTFail("Failed to decode GhostTwinStatusResponse with empty tags")
            return
        }
        
        XCTAssertEqual(original, decoded, "Empty personality_tags should round-trip correctly")
        XCTAssertTrue(decoded.personality_tags.isEmpty, "personality_tags should be empty")
    }
    
    /// Edge case: Maximum level and XP values
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testEdgeCase_MaxLevelAndXPRoundTrip() {
        let original = TestGhostTwinStatusResponse(
            level: 10,
            total_xp: 100000,
            current_level_xp: 9999,
            personality_tags: ["直接", "效率至上", "冷幽默", "理性", "简洁"],
            challenges_remaining_today: 0,
            personality_profile_version: 999
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode GhostTwinStatusResponse with max values")
            return
        }
        
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TestGhostTwinStatusResponse.self, from: data) else {
            XCTFail("Failed to decode GhostTwinStatusResponse with max values")
            return
        }
        
        XCTAssertEqual(original, decoded, "Max level/XP values should round-trip correctly")
        XCTAssertEqual(decoded.level, 10)
        XCTAssertEqual(decoded.total_xp, 100000)
    }
    
    /// Edge case: Minimum values (level 1, 0 XP)
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testEdgeCase_MinValuesRoundTrip() {
        let original = TestGhostTwinStatusResponse(
            level: 1,
            total_xp: 0,
            current_level_xp: 0,
            personality_tags: [],
            challenges_remaining_today: 3,
            personality_profile_version: 1
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode GhostTwinStatusResponse with min values")
            return
        }
        
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TestGhostTwinStatusResponse.self, from: data) else {
            XCTFail("Failed to decode GhostTwinStatusResponse with min values")
            return
        }
        
        XCTAssertEqual(original, decoded, "Min values should round-trip correctly")
        XCTAssertEqual(decoded.level, 1)
        XCTAssertEqual(decoded.total_xp, 0)
    }
    
    /// Edge case: CalibrationChallenge with 2 options
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testEdgeCase_ChallengeWith2OptionsRoundTrip() {
        let original = TestCalibrationChallenge(
            id: "test-challenge-001",
            type: .dilemma,
            scenario: "你的同事在会议上抢了你的功劳，你会怎么做？",
            options: ["直接指出", "私下沟通"],
            xp_reward: 500
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode CalibrationChallenge with 2 options")
            return
        }
        
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TestCalibrationChallenge.self, from: data) else {
            XCTFail("Failed to decode CalibrationChallenge with 2 options")
            return
        }
        
        XCTAssertEqual(original, decoded, "Challenge with 2 options should round-trip correctly")
        XCTAssertEqual(decoded.options.count, 2)
    }
    
    /// Edge case: CalibrationChallenge with 3 options
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testEdgeCase_ChallengeWith3OptionsRoundTrip() {
        let original = TestCalibrationChallenge(
            id: "test-challenge-002",
            type: .prediction,
            scenario: "当有人说「你这样做不对」时，你最可能的回应是：",
            options: ["「我觉得你说得有道理」", "「为什么这么说？」", "「我不同意」"],
            xp_reward: 200
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode CalibrationChallenge with 3 options")
            return
        }
        
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TestCalibrationChallenge.self, from: data) else {
            XCTFail("Failed to decode CalibrationChallenge with 3 options")
            return
        }
        
        XCTAssertEqual(original, decoded, "Challenge with 3 options should round-trip correctly")
        XCTAssertEqual(decoded.options.count, 3)
    }
    
    /// Edge case: ChallengeType.reverseTuring raw value encoding
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testEdgeCase_ReverseTuringRawValueEncoding() {
        let original = TestChallengeType.reverseTuring
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original),
              let jsonString = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to encode reverseTuring")
            return
        }
        
        // Verify the raw value uses snake_case
        XCTAssertEqual(jsonString, "\"reverse_turing\"", 
                       "reverseTuring should encode as 'reverse_turing'")
        
        // Verify round-trip
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TestChallengeType.self, from: data) else {
            XCTFail("Failed to decode reverseTuring")
            return
        }
        
        XCTAssertEqual(original, decoded)
    }
    
    /// Edge case: Unicode characters in strings
    /// **Validates: Requirements 7.1, 8.2, 8.5**
    func testEdgeCase_UnicodeCharactersRoundTrip() {
        let original = TestCalibrationAnswerResponse(
            xp_earned: 500,
            new_total_xp: 5000,
            new_level: 2,
            ghost_response: "哈哈，我就知道你会选这个！🎉 Very interesting choice~",
            personality_tags_updated: ["直接", "效率至上", "冷幽默", "emoji-lover 🤖"]
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            XCTFail("Failed to encode CalibrationAnswerResponse with unicode")
            return
        }
        
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TestCalibrationAnswerResponse.self, from: data) else {
            XCTFail("Failed to decode CalibrationAnswerResponse with unicode")
            return
        }
        
        XCTAssertEqual(original, decoded, "Unicode characters should round-trip correctly")
        XCTAssertTrue(decoded.ghost_response.contains("🎉"))
        XCTAssertTrue(decoded.personality_tags_updated.contains("emoji-lover 🤖"))
    }
    
    /// Edge case: XP reward values match ChallengeType
    /// **Validates: Requirements 8.3**
    func testEdgeCase_XPRewardMatchesChallengeType() {
        // Dilemma = 500 XP
        XCTAssertEqual(TestChallengeType.dilemma.xpReward, 500)
        
        // Reverse Turing = 300 XP
        XCTAssertEqual(TestChallengeType.reverseTuring.xpReward, 300)
        
        // Prediction = 200 XP
        XCTAssertEqual(TestChallengeType.prediction.xpReward, 200)
    }
}
