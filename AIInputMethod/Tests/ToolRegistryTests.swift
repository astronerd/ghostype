//
//  ToolRegistryTests.swift
//  AIInputMethod
//
//  Unit tests for ToolRegistry protocol callback and error handling
//  Feature: decoupling-refactor
//

import XCTest
import Foundation

// MARK: - Test Copies of Production Types

/// Exact copy of ToolContext from ToolRegistry.swift
private struct TestToolContext {
    let text: String
    let skillName: String
    let speechText: String
}

/// Exact copy of ToolError from ToolRegistry.swift
private enum TestToolError: Error, Equatable {
    case unknownTool(name: String)
}

/// Tool handler type
private typealias TestToolHandler = (TestToolContext) -> Void

// MARK: - Test ToolRegistry (exact logic copy)

/// Replicates ToolRegistry logic for testing without importing executable
private class TestToolRegistry {
    private var handlers: [String: TestToolHandler] = [:]
    weak var outputHandler: TestToolOutputHandler?

    func register(name: String, handler: @escaping TestToolHandler) {
        handlers[name] = handler
    }

    func execute(name: String, context: TestToolContext) throws {
        guard let handler = handlers[name] else {
            throw TestToolError.unknownTool(name: name)
        }
        handler(context)
    }

    /// Register builtins using protocol callback (no closure capture)
    func registerBuiltins() {
        register(name: "provide_text") { [weak self] context in
            self?.outputHandler?.handleTextOutput(text: context.text, skillName: context.skillName, speechText: context.speechText)
        }

        register(name: "save_memo") { [weak self] context in
            self?.outputHandler?.handleMemoSave(text: context.text)
        }
    }
}

// MARK: - Test ToolOutputHandler Protocol

private protocol TestToolOutputHandler: AnyObject {
    func handleTextOutput(text: String, skillName: String, speechText: String)
    func handleMemoSave(text: String)
}

// MARK: - Mock ToolOutputHandler

private class MockToolOutputHandler: TestToolOutputHandler {
    var textOutputCalls: [(text: String, skillName: String, speechText: String)] = []
    var memoSaveCalls: [String] = []

    func handleTextOutput(text: String, skillName: String, speechText: String) {
        textOutputCalls.append((text: text, skillName: skillName, speechText: speechText))
    }

    func handleMemoSave(text: String) {
        memoSaveCalls.append(text)
    }
}

// MARK: - Tests

/// Unit tests for ToolRegistry
/// Feature: decoupling-refactor, Tasks 6.5, 6.11
/// **Validates: Requirements 6.1, 6.2, 6.3, 6.4**
final class ToolRegistryTests: XCTestCase {

    // MARK: - provide_text callback

    /// Executing "provide_text" calls ToolOutputHandler.handleTextOutput
    /// **Validates: Requirements 6.3**
    func testProvideText_CallsHandleTextOutput() {
        let registry = TestToolRegistry()
        let mock = MockToolOutputHandler()
        registry.outputHandler = mock
        registry.registerBuiltins()

        let context = TestToolContext(text: "polished text", skillName: "polish", speechText: "raw speech")
        try? registry.execute(name: "provide_text", context: context)

        XCTAssertEqual(mock.textOutputCalls.count, 1, "handleTextOutput should be called once")
        XCTAssertEqual(mock.textOutputCalls.first?.text, "polished text")
        XCTAssertEqual(mock.textOutputCalls.first?.skillName, "polish")
        XCTAssertEqual(mock.textOutputCalls.first?.speechText, "raw speech")
    }

    // MARK: - save_memo callback

    /// Executing "save_memo" calls ToolOutputHandler.handleMemoSave
    /// **Validates: Requirements 6.4**
    func testSaveMemo_CallsHandleMemoSave() {
        let registry = TestToolRegistry()
        let mock = MockToolOutputHandler()
        registry.outputHandler = mock
        registry.registerBuiltins()

        let context = TestToolContext(text: "memo content", skillName: "memo", speechText: "raw speech")
        try? registry.execute(name: "save_memo", context: context)

        XCTAssertEqual(mock.memoSaveCalls.count, 1, "handleMemoSave should be called once")
        XCTAssertEqual(mock.memoSaveCalls.first, "memo content")
    }

    // MARK: - Unknown tool error

    /// Executing unknown tool throws ToolError.unknownTool
    /// **Validates: Requirements 6.3**
    func testUnknownTool_ThrowsError() {
        let registry = TestToolRegistry()
        registry.registerBuiltins()

        let context = TestToolContext(text: "text", skillName: "skill", speechText: "speech")

        XCTAssertThrowsError(try registry.execute(name: "nonexistent_tool", context: context)) { error in
            guard let toolError = error as? TestToolError else {
                XCTFail("Expected TestToolError, got \(error)")
                return
            }
            XCTAssertEqual(toolError, .unknownTool(name: "nonexistent_tool"))
        }
    }

    // MARK: - Property test: random tool names

    /// For any random unregistered tool name, execute throws unknownTool
    func testProperty_RandomUnknownToolThrows() {
        PropertyTest.verify(
            "Random unregistered tool name throws unknownTool",
            iterations: 100
        ) {
            let registry = TestToolRegistry()
            registry.registerBuiltins()

            // Generate random tool name that is NOT provide_text or save_memo
            var toolName = PropertyTest.randomString(minLength: 1, maxLength: 30)
            while toolName == "provide_text" || toolName == "save_memo" {
                toolName = PropertyTest.randomString(minLength: 1, maxLength: 30)
            }

            let context = TestToolContext(text: "t", skillName: "s", speechText: "sp")

            do {
                try registry.execute(name: toolName, context: context)
                return false // Should have thrown
            } catch let error as TestToolError {
                guard case .unknownTool(let name) = error else { return false }
                return name == toolName
            } catch {
                return false
            }
        }
    }

    // MARK: - Weak reference test

    /// outputHandler is weak — setting it to nil prevents callbacks
    func testWeakOutputHandler_NilPreventsCallbacks() {
        let registry = TestToolRegistry()
        var mock: MockToolOutputHandler? = MockToolOutputHandler()
        registry.outputHandler = mock
        registry.registerBuiltins()

        // Release the mock
        mock = nil

        let context = TestToolContext(text: "text", skillName: "skill", speechText: "speech")
        // Should not crash, just silently do nothing
        try? registry.execute(name: "provide_text", context: context)
        try? registry.execute(name: "save_memo", context: context)

        // If we get here without crashing, the weak reference works correctly
        XCTAssertNil(registry.outputHandler, "outputHandler should be nil after mock is released")
    }

    // MARK: - Custom tool registration

    /// Custom tools can be registered and executed
    func testCustomToolRegistration() {
        let registry = TestToolRegistry()
        var customCalled = false

        registry.register(name: "custom_tool") { _ in
            customCalled = true
        }

        let context = TestToolContext(text: "text", skillName: "skill", speechText: "speech")
        try? registry.execute(name: "custom_tool", context: context)

        XCTAssertTrue(customCalled, "Custom tool handler should be called")
    }

    // MARK: - Multiple executions

    /// Multiple executions accumulate calls correctly
    func testMultipleExecutions() {
        let registry = TestToolRegistry()
        let mock = MockToolOutputHandler()
        registry.outputHandler = mock
        registry.registerBuiltins()

        for i in 0..<5 {
            let context = TestToolContext(text: "text_\(i)", skillName: "skill", speechText: "speech")
            try? registry.execute(name: "provide_text", context: context)
        }

        XCTAssertEqual(mock.textOutputCalls.count, 5, "handleTextOutput should be called 5 times")
        for i in 0..<5 {
            XCTAssertEqual(mock.textOutputCalls[i].text, "text_\(i)")
        }
    }
}
