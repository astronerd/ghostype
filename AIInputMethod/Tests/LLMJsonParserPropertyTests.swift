//
//  LLMJsonParserPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for LLMJsonParser JSON parsing equivalence
//  Feature: ghost-twin-on-device, Property 12: LLM JSON parsing equivalence
//

import XCTest
import Foundation

// Uses shared PropertyTest from AuthManagerPropertyTests.swift

// MARK: - Test Copy of LLMJsonParser

/// Since the test target cannot import the executable target,
/// we create a test copy of the parser functions.
private enum TestLLMJsonParser {
    static func parse<T: Decodable>(_ raw: String) throws -> T {
        let cleaned = stripMarkdownCodeBlock(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw TestLLMParseError.invalidEncoding
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TestLLMParseError.invalidJSON(underlying: error)
        }
    }

    static func stripMarkdownCodeBlock(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(
                of: #"^```(?:json|JSON)?\s*\n?"#, with: "", options: .regularExpression
            )
            cleaned = cleaned.replacingOccurrences(
                of: #"\n?```\s*$"#, with: "", options: .regularExpression
            )
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum TestLLMParseError: Error {
    case invalidEncoding
    case invalidJSON(underlying: Error)
}

// MARK: - Test Helper: Random JSON Generator

/// A simple Codable struct used as the decode target for property tests.
private struct SimplePayload: Codable, Equatable {
    let key: String
    let value: String
    let number: Int
    let flag: Bool
}

/// Generate random valid JSON strings that decode to SimplePayload.
private func randomSimplePayload() -> (json: String, payload: SimplePayload) {
    let key = randomSafeString(minLength: 1, maxLength: 20)
    let value = randomSafeString(minLength: 0, maxLength: 50)
    let number = Int.random(in: -100_000...100_000)
    let flag = Bool.random()

    let payload = SimplePayload(key: key, value: value, number: number, flag: flag)
    // Build JSON manually to ensure it's valid
    let json = """
    {"key":"\(escapeJSON(key))","value":"\(escapeJSON(value))","number":\(number),"flag":\(flag)}
    """
    return (json, payload)
}

/// Generate a random string safe for JSON (no unescaped control chars or backslashes).
private func randomSafeString(minLength: Int = 1, maxLength: Int = 20) -> String {
    let length = Int.random(in: minLength...maxLength)
    // Use safe ASCII chars that don't need JSON escaping
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-.,!?:;"
    return String((0..<length).map { _ in chars.randomElement()! })
}

/// Escape a string for embedding in JSON.
private func escapeJSON(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\r", with: "\\r")
     .replacingOccurrences(of: "\t", with: "\\t")
}

/// Wrap a JSON string in markdown code block.
private func wrapInMarkdown(_ json: String, tag: String = "json") -> String {
    return "```\(tag)\n\(json)\n```"
}

// MARK: - Property Tests

/// Property-based tests for LLM JSON parsing equivalence
/// Feature: ghost-twin-on-device, Property 12: LLM JSON parsing equivalence
final class LLMJsonParserPropertyTests: XCTestCase {

    // MARK: - Property 12: LLM JSON parsing equivalence

    /// Property 12: LLM JSON parsing equivalence
    /// *For any* valid JSON string `s`, `LLMJsonParser.parse("```json\n" + s + "\n```")`
    /// and `LLMJsonParser.parse(s)` should produce equivalent decoded results.
    /// Additionally, `stripMarkdownCodeBlock` applied to a markdown-wrapped JSON
    /// should produce the same string as the unwrapped JSON.
    /// Feature: ghost-twin-on-device, Property 12: LLM JSON parsing equivalence
    /// **Validates: Requirements 10.1, 10.2, 10.4**
    func testProperty12_LLMJsonParsingEquivalence() {
        PropertyTest.verify(
            "LLM JSON parsing equivalence",
            iterations: 100
        ) {
            let (json, _) = randomSimplePayload()

            // Parse raw JSON
            guard let directResult: SimplePayload = try? TestLLMJsonParser.parse(json) else {
                return false
            }

            // Parse markdown-wrapped JSON
            let wrapped = wrapInMarkdown(json)
            guard let wrappedResult: SimplePayload = try? TestLLMJsonParser.parse(wrapped) else {
                return false
            }

            // Both should produce equivalent results
            guard directResult == wrappedResult else {
                return false
            }

            // stripMarkdownCodeBlock on wrapped should produce same as trimmed raw
            let stripped = TestLLMJsonParser.stripMarkdownCodeBlock(wrapped)
            let trimmedRaw = json.trimmingCharacters(in: .whitespacesAndNewlines)
            guard stripped == trimmedRaw else {
                return false
            }

            return true
        }
    }

    /// Property 12 variant: markdown with uppercase JSON tag
    /// **Validates: Requirements 10.1, 10.4**
    func testProperty12_UppercaseJSONTag() throws {
        try PropertyTest.verify(
            "LLM JSON parsing equivalence (uppercase tag)",
            iterations: 100
        ) {
            let (json, _) = randomSimplePayload()

            let directResult: SimplePayload = try TestLLMJsonParser.parse(json)
            let wrapped = wrapInMarkdown(json, tag: "JSON")
            let wrappedResult: SimplePayload = try TestLLMJsonParser.parse(wrapped)

            return directResult == wrappedResult
        }
    }

    /// Property 12 variant: markdown with no language tag (bare ```)
    /// **Validates: Requirements 10.1, 10.4**
    func testProperty12_BareCodeBlock() throws {
        try PropertyTest.verify(
            "LLM JSON parsing equivalence (bare code block)",
            iterations: 100
        ) {
            let (json, _) = randomSimplePayload()

            let directResult: SimplePayload = try TestLLMJsonParser.parse(json)
            let wrapped = wrapInMarkdown(json, tag: "")
            let wrappedResult: SimplePayload = try TestLLMJsonParser.parse(wrapped)

            return directResult == wrappedResult
        }
    }

    // MARK: - Edge Cases

    /// Edge case: stripMarkdownCodeBlock on plain JSON returns it unchanged
    /// **Validates: Requirements 10.2**
    func testEdgeCase_PlainJsonUnchanged() {
        let json = "{\"key\":\"hello\",\"value\":\"world\",\"number\":42,\"flag\":true}"
        let result = TestLLMJsonParser.stripMarkdownCodeBlock(json)
        XCTAssertEqual(result, json, "Plain JSON should pass through stripMarkdownCodeBlock unchanged")
    }

    /// Edge case: JSON with surrounding whitespace
    /// **Validates: Requirements 10.2**
    func testEdgeCase_WhitespaceAroundJson() {
        let json = "{\"key\":\"a\",\"value\":\"b\",\"number\":1,\"flag\":false}"
        let padded = "  \n  \(json)  \n  "
        let result = TestLLMJsonParser.stripMarkdownCodeBlock(padded)
        XCTAssertEqual(result, json, "Whitespace-padded JSON should be trimmed correctly")
    }

    /// Edge case: invalid JSON should throw
    /// **Validates: Requirements 10.3**
    func testEdgeCase_InvalidJsonThrows() {
        let invalidInputs = [
            "not json at all",
            "{broken",
            "```json\n{invalid}\n```",
            ""
        ]

        for input in invalidInputs {
            XCTAssertThrowsError(
                try TestLLMJsonParser.parse(input) as SimplePayload,
                "Should throw for invalid JSON: \(input.prefix(30))"
            )
        }
    }

    /// Edge case: markdown-wrapped JSON with extra whitespace around fences
    /// **Validates: Requirements 10.1, 10.4**
    func testEdgeCase_MarkdownWithExtraWhitespace() {
        let json = "{\"key\":\"test\",\"value\":\"data\",\"number\":99,\"flag\":true}"
        let wrapped = "  \n```json\n\(json)\n```  \n  "

        let directResult: SimplePayload? = try? TestLLMJsonParser.parse(json)
        let wrappedResult: SimplePayload? = try? TestLLMJsonParser.parse(wrapped)

        XCTAssertNotNil(directResult)
        XCTAssertNotNil(wrappedResult)
        XCTAssertEqual(directResult, wrappedResult,
                       "Markdown-wrapped JSON with extra whitespace should parse equivalently")
    }
}
