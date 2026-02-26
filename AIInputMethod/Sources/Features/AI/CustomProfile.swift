import Foundation

// MARK: - Custom Profile

/// 自定义润色风格数据模型
/// 用户创建的润色风格，包含名称和 Prompt 文本
struct CustomProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var prompt: String
    
    init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }
}
