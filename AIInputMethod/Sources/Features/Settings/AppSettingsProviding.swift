import AppKit

// MARK: - AppSettings Providing Protocol

/// AppSettings 协议抽象
/// 为外部消费方提供可测试的设置接口
protocol AppSettingsProviding: AnyObject {
    var enableAIPolish: Bool { get }
    var polishThreshold: Int { get }
    var translateLanguage: TranslateLanguage { get }
    var enableInSentencePatterns: Bool { get }
    var enableTriggerCommands: Bool { get }
    var triggerWord: String { get }
    var enableContactsHotwords: Bool { get }
    var hotkeyModifiers: NSEvent.ModifierFlags { get }
    var hotkeyKeyCode: UInt16 { get }
    var hotkeyDisplay: String { get }
    func shouldAutoEnter(for bundleId: String?) -> Bool
    func sendMethod(for bundleId: String?) -> SendMethod
}

// MARK: - AppSettings Conformance

extension AppSettings: AppSettingsProviding {}
