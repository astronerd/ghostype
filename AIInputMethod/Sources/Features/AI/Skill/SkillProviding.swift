import Foundation

// MARK: - Skill Providing Protocol

/// SkillManager 协议抽象
/// 为外部消费方提供可测试的 Skill 管理接口
protocol SkillProviding: AnyObject {
    var skills: [SkillModel] { get }
    func loadAllSkills()
    func skillForKeyCode(_ keyCode: UInt16) -> SkillModel?
    func ensureBuiltinSkills()
}

// MARK: - SkillManager Conformance

extension SkillManager: SkillProviding {}
