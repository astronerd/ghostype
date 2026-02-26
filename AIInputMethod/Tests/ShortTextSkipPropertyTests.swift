import XCTest
import Foundation

// Feature: api-online-auth, Property 11: 短文本跳过 AI 处理
// **Validates: Requirements 4.4**
//
// Property: For any text, if its length is less than polishThreshold,
// processPolish should return the original text unchanged (skip AI processing).
//
// The threshold logic from AppDelegate.processPolish():
//   let polishThreshold = settings.polishThreshold
//   if text.count < polishThreshold {
//       // skip AI, insert original text
//   }
//
// We test this threshold decision logic independently using property-based testing.

// MARK: - Threshold Decision Logic (extracted for testing)

/// Represents the decision made by the polish threshold check.
/// This mirrors the logic in AppDelegate.processPolish().
private enum PolishDecision {
    case skipAI(originalText: String)   // text.count < threshold → return original
    case eligibleForAI                   // text.count >= threshold → proceed to AI
}

/// Pure function that encapsulates the threshold check logic from processPolish().
/// This is the exact logic: `if text.count < polishThreshold { skip } else { process }`
private func shouldSkipPolish(text: String, threshold: Int) -> PolishDecision {
    if text.count < threshold {
        return .skipAI(originalText: text)
    } else {
        return .eligibleForAI
    }
}

// MARK: - Random Text Generators

private extension PropertyTest {
    /// Generate a random Unicode string of exactly the given length (in Character count).
    /// Uses a mix of ASCII, CJK, and emoji characters to test with diverse inputs.
    static func randomUnicodeString(length: Int) -> String {
        guard length > 0 else { return "" }
        let charSets: [String] = [
            "abcdefghijklmnopqrstuvwxyz",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "0123456789",
            "你好世界测试文本润色翻译",
            "こんにちは世界テスト",
            "!@#$%^&*()_+-=[]{}|;':\",./<>?",
            " \t"
        ]
        let allChars = charSets.joined()
        let charArray = Array(allChars)
        return String((0..<length).map { _ in charArray.randomElement()! })
    }
}

// MARK: - Property Tests

final class ShortTextSkipPropertyTests: XCTestCase {
    
    // MARK: - Property 11: Short text below threshold should skip AI processing
    
    /// Feature: api-online-auth, Property 11: 短文本跳过 AI 处理
    /// For any text shorter than threshold, the decision should be to skip AI
    /// and the original text should be preserved unchanged.
    /// **Validates: Requirements 4.4**
    func testProperty11_shortTextBelowThresholdSkipsAI() throws {
        PropertyTest.verify("Short text below threshold is skipped and returned unchanged", iterations: 100) {
            // Generate a random threshold (realistic range: 1-100)
            let threshold = Int.random(in: 1...100)
            
            // Generate text strictly shorter than threshold
            let shortLength = Int.random(in: 0..<threshold)
            let text = PropertyTest.randomUnicodeString(length: shortLength)
            
            // Pre-condition: text is shorter than threshold
            guard text.count < threshold else { return false }
            
            // Apply the threshold logic
            let decision = shouldSkipPolish(text: text, threshold: threshold)
            
            // Property: decision should be skipAI with the original text preserved
            switch decision {
            case .skipAI(let originalText):
                // The original text must be returned unchanged
                return originalText == text
            case .eligibleForAI:
                // Should NOT be eligible for AI
                return false
            }
        }
    }
    
    /// For any text at or above threshold, the decision should be eligible for AI processing.
    /// **Validates: Requirements 4.4**
    func testProperty11_textAtOrAboveThresholdIsEligible() throws {
        PropertyTest.verify("Text at or above threshold is eligible for AI", iterations: 100) {
            // Generate a random threshold (realistic range: 1-50)
            let threshold = Int.random(in: 1...50)
            
            // Generate text at or above threshold
            let longLength = Int.random(in: threshold...threshold + 100)
            let text = PropertyTest.randomUnicodeString(length: longLength)
            
            // Pre-condition: text is at or above threshold
            guard text.count >= threshold else { return false }
            
            // Apply the threshold logic
            let decision = shouldSkipPolish(text: text, threshold: threshold)
            
            // Property: decision should be eligibleForAI
            switch decision {
            case .skipAI:
                return false
            case .eligibleForAI:
                return true
            }
        }
    }
    
    /// Boundary test: text with length exactly equal to threshold should be eligible for AI.
    /// This tests the boundary condition: `text.count < threshold` means exactly-at-threshold passes through.
    /// **Validates: Requirements 4.4**
    func testProperty11_textExactlyAtThresholdIsEligible() throws {
        PropertyTest.verify("Text exactly at threshold length is eligible for AI", iterations: 100) {
            let threshold = Int.random(in: 1...100)
            let text = PropertyTest.randomUnicodeString(length: threshold)
            
            // Pre-condition: text length equals threshold
            guard text.count == threshold else { return false }
            
            let decision = shouldSkipPolish(text: text, threshold: threshold)
            
            switch decision {
            case .skipAI:
                return false  // Should NOT skip when exactly at threshold
            case .eligibleForAI:
                return true
            }
        }
    }
    
    /// Empty text should always be skipped (for any positive threshold).
    /// **Validates: Requirements 4.4**
    func testProperty11_emptyTextAlwaysSkipped() throws {
        PropertyTest.verify("Empty text is always skipped for any positive threshold", iterations: 100) {
            let threshold = Int.random(in: 1...1000)
            let text = ""
            
            let decision = shouldSkipPolish(text: text, threshold: threshold)
            
            switch decision {
            case .skipAI(let originalText):
                return originalText == ""
            case .eligibleForAI:
                return false
            }
        }
    }
    
    /// The default polishThreshold is 20. Verify the threshold logic is consistent
    /// with the default value used in AppSettings.
    /// **Validates: Requirements 4.4**
    func testProperty11_defaultThresholdConsistency() throws {
        let defaultThreshold = 20  // AppSettings default
        
        PropertyTest.verify("Default threshold (20) correctly partitions short vs long text", iterations: 100) {
            let length = Int.random(in: 0...40)
            let text = PropertyTest.randomUnicodeString(length: length)
            
            let decision = shouldSkipPolish(text: text, threshold: defaultThreshold)
            
            switch decision {
            case .skipAI:
                // Should only skip if text is shorter than 20
                return text.count < defaultThreshold
            case .eligibleForAI:
                // Should only be eligible if text is 20 or longer
                return text.count >= defaultThreshold
            }
        }
    }
}
