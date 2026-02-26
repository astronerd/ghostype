import Foundation

// MARK: - OverlayState Providing Protocol

/// OverlayStateManager 协议抽象
/// 为外部消费方提供可测试的 Overlay 状态管理接口
protocol OverlayStateProviding: AnyObject {
    func setRecording(skill: SkillModel?)
    func setProcessing(skill: SkillModel?)
    func setCommitting(type: OverlayPhase.CommitType)
    func setLoginRequired()
}

// MARK: - OverlayStateManager Conformance

extension OverlayStateManager: OverlayStateProviding {}
