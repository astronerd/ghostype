//
//  ParseToolCallPropertyTests.swift
//  AIInputMethod
//
//  Property-based tests for parseToolCall stability
//  Feature: decoupling-refactor
//

import XCTest
import Foundation

// MARK: - Test Copy of ToolCallResult

private struct TestToolCallResult: Equatable {
    let tool: String
    let content: String
}

// MARK: - Test Copy of parseToolCall Logic

/// Exact copy of SkillExecutor.parseToolCall logic
private enum TestParser {

    static func parseToolCall(from text: String) -> TestToolCallResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let result = tryParseJSON(trimmed) {
            return result
        }

        if let jsonRange = findJSONObject(in: trimmed),
           let result = tryParseJSON(String(trimmed[jsonRange])) {
            return result
        }

        return nil
    }

    private static func tryParseJSON(_ text: String) -> TestToolCallResult? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = json["tool"] as? String,
              let content = json["content"] as? String else {
            return nil
        }
        return TestToolCallResult(tool: tool, content: content)
    }

    private static func findJSONObject(in text: String) -> Range<String.Index>? {
        guard let openBrace = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var index = openBrace

        while index < text.endIndex {
            let char = text[index]

            if escaped {
                escaped = false
            } else if char == "\\" && inString {
                escaped = true
            } else if char == "\"" {
                inString.toggle()
            } else if !inString {
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        let afterClose = text.index(after: index)
                        return openBrace..<afterClose
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }
}

// MARK: - Random Generators

private enum ParseTestGenerators {

    /// Generate a random tool name (alphanumeric + underscore)
    static func randomToolName() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz_"
        let length = Int.random(in: 1...20)
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    /// Generate random content text (may contain special chars)
    static func randomContent() -> String {
        PropertyTest.randomString(minLength: 1, maxLength: 100)
    }

    /// Build a valid JSON tool call string
    static func buildValidJSON(tool: String, content: String) -> String {
        // Use JSONSerialization to properly escape strings
        let dict: [String: Any] = ["tool": tool, "content": content]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"tool\":\"\(tool)\",\"content\":\"\(content)\"}"
        }
        return str
    }

    /// Generate random prefix/suffix noise
    static func randomNoise() -> String {
        let noiseChars = "abcdefghijklmnopqrstuvwxyz 0123456789\n\t"
        let length = Int.random(in: 0...30)
        return String((0..<length).map { _ in noiseChars.randomElement()! })
    }
}

// MARK: - Property Tests

/// Property-based tests for parseToolCall
/// Feature: decoupling-refactor, Property 3: parseToolCall 稳定性
/// **Validates: Requirements 8.4**
final class ParseToolCallPropertyTests: XCTestCase {

    // MARK: - Property 3: Valid JSON always parsed correctly

    /// For any valid tool call JSON, parseToolCall extracts tool and content
    func testProperty3_ValidJSONAlwaysParsed() {
        PropertyTest.verify(
            "Valid tool call JSON is always parsed correctly",
            iterations: 100
        ) {
            let tool = ParseTestGenerators.randomToolName()
            let content = ParseTestGenerators.randomContent()
            let json = ParseTestGenerators.buildValidJSON(tool: tool, content: content)

            guard let result = TestParser.parseToolCall(from: json) else {
                return false
            }

            return result.tool == tool && result.content == content
        }
    }

    // MARK: - Property 3: Valid JSON with surrounding noise

    /// For any valid JSON embedded in noise text, parseToolCall still extracts correctly
    func testProperty3_ValidJSONWithNoiseParsed() {
        PropertyTest.verify(
            "Valid tool call JSON with surrounding noise is parsed correctly",
            iterations: 100
        ) {
            let tool = ParseTestGenerators.randomToolName()
            let content = ParseTestGenerators.randomContent()
            let json = ParseTestGenerators.buildValidJSON(tool: tool, content: content)

            // Add noise before and after
            let prefix = ParseTestGenerators.randomNoise()
            let suffix = ParseTestGenerators.randomNoise()
            let noisyText = "\(prefix)\(json)\(suffix)"

            guard let result = TestParser.parseToolCall(from: noisyText) else {
                return false
            }

            return result.tool == tool && result.content == content
        }
    }

    // MARK: - Property 3: Non-JSON text returns nil

    /// For any text without valid JSON tool call structure, parseToolCall returns nil
    func testProperty3_NonJSONReturnsNil() {
        PropertyTest.verify(
            "Non-JSON text returns nil",
            iterations: 100
        ) {
            // Generate random text that doesn't contain { at all
            let chars = "abcdefghijklmnopqrstuvwxyz0123456789 \n\t!@#$%^&*()_+-=[]|;:',.<>?/"
            let length = Int.random(in: 1...100)
            let text = String((0..<length).map { _ in chars.randomElement()! })

            let result = TestParser.parseToolCall(from: text)
            return result == nil
        }
    }

    // MARK: - Property 3: JSON without "tool" key returns nil

    /// JSON with missing "tool" key returns nil
    func testProperty3_JSONWithoutToolKeyReturnsNil() {
        PropertyTest.verify(
            "JSON without 'tool' key returns nil",
            iterations: 100
        ) {
            let content = ParseTestGenerators.randomContent()
            // Build JSON with "content" but no "tool"
            let dict: [String: Any] = ["content": content, "other": "value"]
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let json = String(data: data, encoding: .utf8) else {
                return true // Skip if can't build JSON
            }

            let result = TestParser.parseToolCall(from: json)
            return result == nil
        }
    }

    // MARK: - Property 3: JSON without "content" key returns nil

    /// JSON with missing "content" key returns nil
    func testProperty3_JSONWithoutContentKeyReturnsNil() {
        PropertyTest.verify(
            "JSON without 'content' key returns nil",
            iterations: 100
        ) {
            let tool = ParseTestGenerators.randomToolName()
            // Build JSON with "tool" but no "content"
            let dict: [String: Any] = ["tool": tool, "other": "value"]
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let json = String(data: data, encoding: .utf8) else {
                return true
            }

            let result = TestParser.parseToolCall(from: json)
            return result == nil
        }
    }

    // MARK: - Property 3: Idempotency

    /// Parsing the same text twice gives the same result
    func testProperty3_ParseIdempotency() {
        PropertyTest.verify(
            "Parsing same text twice gives identical result",
            iterations: 100
        ) {
            let tool = ParseTestGenerators.randomToolName()
            let content = ParseTestGenerators.randomContent()
            let json = ParseTestGenerators.buildValidJSON(tool: tool, content: content)

            let result1 = TestParser.parseToolCall(from: json)
            let result2 = TestParser.parseToolCall(from: json)

            return result1 == result2
        }
    }

    // MARK: - Edge Cases

    /// Empty string returns nil
    func testEdgeCase_EmptyString() {
        XCTAssertNil(TestParser.parseToolCall(from: ""))
    }

    /// Whitespace-only string returns nil
    func testEdgeCase_WhitespaceOnly() {
        XCTAssertNil(TestParser.parseToolCall(from: "   \n\t  "))
    }

    /// Valid JSON with whitespace padding
    func testEdgeCase_WhitespacePadding() {
        let json = "  \n  {\"tool\": \"provide_text\", \"content\": \"hello\"}  \n  "
        let result = TestParser.parseToolCall(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tool, "provide_text")
        XCTAssertEqual(result?.content, "hello")
    }

    /// JSON with extra fields still parses tool and content
    func testEdgeCase_ExtraFields() {
        let json = "{\"tool\": \"save_memo\", \"content\": \"note\", \"extra\": 42}"
        let result = TestParser.parseToolCall(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tool, "save_memo")
        XCTAssertEqual(result?.content, "note")
    }

    /// Nested JSON in content doesn't break parsing
    func testEdgeCase_NestedJSONInContent() {
        let json = "{\"tool\": \"provide_text\", \"content\": \"result with {nested} braces\"}"
        let result = TestParser.parseToolCall(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tool, "provide_text")
        XCTAssertEqual(result?.content, "result with {nested} braces")
    }

    /// Chinese content
    func testEdgeCase_ChineseContent() {
        let json = "{\"tool\": \"provide_text\", \"content\": \"你好世界\"}"
        let result = TestParser.parseToolCall(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.content, "你好世界")
    }

    /// Escaped quotes in content
    func testEdgeCase_EscapedQuotes() {
        let json = "{\"tool\": \"provide_text\", \"content\": \"he said \\\"hello\\\"\"}"
        let result = TestParser.parseToolCall(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.content, "he said \"hello\"")
    }
}
