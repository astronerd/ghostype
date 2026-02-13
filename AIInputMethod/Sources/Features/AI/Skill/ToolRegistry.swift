import Foundation

// MARK: - Tool Output Handler Protocol

/// Tool 输出处理协议
/// 消除 ToolRegistry 对 AppDelegate 的循环依赖
protocol ToolOutputHandler: AnyObject {
    func handleTextOutput(context: ToolContext)
    func handleMemoSave(text: String)
}

// MARK: - Tool Context

/// Tool 执行上下文
struct ToolContext {
    let text: String
    let skill: SkillModel
    let speechText: String
    let behavior: ContextBehavior
}

// MARK: - Tool Handler

/// Tool 处理器类型
typealias ToolHandler = (ToolContext) -> Void

// MARK: - Tool Error

enum ToolError: Error, Equatable {
    case unknownTool(name: String)
}

extension ToolError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: '\(name)' is not registered in ToolRegistry"
        }
    }
}

// MARK: - Tool Registry

class ToolRegistry {
    private var handlers: [String: ToolHandler] = [:]
    weak var outputHandler: ToolOutputHandler?

    /// 注册新的 Tool
    func register(name: String, handler: @escaping ToolHandler) {
        handlers[name] = handler
    }

    /// 执行指定名称的 Tool
    func execute(name: String, context: ToolContext) throws {
        guard let handler = handlers[name] else {
            throw ToolError.unknownTool(name: name)
        }
        handler(context)
    }

    /// 注册内置 Tool（使用协议回调，无闭包捕获）
    func registerBuiltins() {
        register(name: "provide_text") { [weak self] context in
            self?.outputHandler?.handleTextOutput(context: context)
        }

        register(name: "save_memo") { [weak self] context in
            self?.outputHandler?.handleMemoSave(text: context.text)
        }
    }


}
