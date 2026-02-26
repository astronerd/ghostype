import XCTest

// Feature: ghost-twin-on-device, Property 15: Whitespace custom answer rejection

/// Validates custom answer text (mirrors ReceiptSlipView logic)
private func isValidCustomAnswer(_ text: String) -> Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

final class CustomAnswerPropertyTests: XCTestCase {

    // MARK: - Property 15: Whitespace custom answer rejection

    func testProperty15_whitespaceOnlyStringsAreRejected() {
        // Pure whitespace strings should always be rejected
        PropertyTest.verify("whitespace-only strings are rejected", iterations: 100) {
            let whitespaceChars: [Character] = [" ", "\t", "\n", "\r", "\u{00A0}", "\u{2003}"]
            let length = Int.random(in: 0...20)
            let whitespaceString = String((0..<length).map { _ in whitespaceChars.randomElement()! })
            return !isValidCustomAnswer(whitespaceString)
        }
    }

    func testProperty15_nonWhitespaceStringsAreAccepted() {
        // Strings with at least one non-whitespace character should be accepted
        PropertyTest.verify("non-whitespace strings are accepted", iterations: 100) {
            let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
            let nonWS = String((0..<Int.random(in: 1...10)).map { _ in chars.randomElement()! })
            let prefix = String(repeating: " ", count: Int.random(in: 0...5))
            let suffix = String(repeating: "\t", count: Int.random(in: 0...3))
            let testString = prefix + nonWS + suffix
            return isValidCustomAnswer(testString)
        }
    }

    func testProperty15_emptyStringIsRejected() {
        XCTAssertFalse(isValidCustomAnswer(""), "Empty string should be rejected")
    }
}
