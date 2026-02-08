import SwiftUI
import AppKit

// MARK: - AIPolishViewModel

/// AI 润色功能视图模型
/// 管理润色配置文件、应用专属配置和智能指令设置
@Observable
class AIPolishViewModel {
    
    // MARK: - 基础设置
    
    /// 是否启用 AI 润色
    var enableAIPolish: Bool {
        didSet {
            AppSettings.shared.enableAIPolish = enableAIPolish
        }
    }
    
    /// 自动润色阈值（字符数）
    var polishThreshold: Int {
        didSet {
            AppSettings.shared.polishThreshold = polishThreshold
        }
    }
    
    // MARK: - 配置文件
    
    /// 默认润色配置
    var defaultProfile: PolishProfile {
        didSet {
            AppSettings.shared.defaultProfile = defaultProfile.rawValue
        }
    }
    
    /// 应用专属配置映射 [BundleID: PolishProfile]
    var appProfileMapping: [String: PolishProfile] {
        didSet {
            // 转换为 [String: String] 存储到 AppSettings
            let stringMapping = appProfileMapping.mapValues { $0.rawValue }
            AppSettings.shared.appProfileMapping = stringMapping
        }
    }
    
    /// 自定义配置的 Prompt
    var customProfilePrompt: String {
        didSet {
            AppSettings.shared.customProfilePrompt = customProfilePrompt
        }
    }
    
    // MARK: - 智能指令
    
    /// 是否启用句内模式识别
    var enableInSentencePatterns: Bool {
        didSet {
            AppSettings.shared.enableInSentencePatterns = enableInSentencePatterns
        }
    }
    
    /// 是否启用句尾唤醒指令
    var enableTriggerCommands: Bool {
        didSet {
            AppSettings.shared.enableTriggerCommands = enableTriggerCommands
        }
    }
    
    /// 唤醒词
    var triggerWord: String {
        didSet {
            AppSettings.shared.triggerWord = triggerWord
        }
    }
    
    // MARK: - Initialization
    
    init() {
        let settings = AppSettings.shared
        
        // 加载基础设置
        self.enableAIPolish = settings.enableAIPolish
        self.polishThreshold = settings.polishThreshold
        
        // 加载配置文件设置
        self.defaultProfile = PolishProfile(rawValue: settings.defaultProfile) ?? .standard
        
        // 转换 [String: String] 为 [String: PolishProfile]
        var profileMapping: [String: PolishProfile] = [:]
        for (bundleId, profileName) in settings.appProfileMapping {
            if let profile = PolishProfile(rawValue: profileName) {
                profileMapping[bundleId] = profile
            }
        }
        self.appProfileMapping = profileMapping
        
        self.customProfilePrompt = settings.customProfilePrompt
        
        // 加载智能指令设置
        self.enableInSentencePatterns = settings.enableInSentencePatterns
        self.enableTriggerCommands = settings.enableTriggerCommands
        self.triggerWord = settings.triggerWord
    }
    
    // MARK: - 应用映射管理方法
    
    /// 添加应用专属配置映射
    /// - Parameters:
    ///   - bundleId: 应用的 Bundle ID
    ///   - profile: 润色配置文件
    /// - Note: 如果 bundleId 已存在，会更新为新的 profile
    /// - Validates: Requirements 4.3
    func addAppMapping(bundleId: String, profile: PolishProfile) {
        appProfileMapping[bundleId] = profile
    }
    
    /// 移除应用专属配置映射
    /// - Parameter bundleId: 要移除的应用 Bundle ID
    /// - Validates: Requirements 4.4
    func removeAppMapping(bundleId: String) {
        appProfileMapping.removeValue(forKey: bundleId)
    }
    
    /// 获取指定应用的润色配置
    /// - Parameter bundleId: 应用的 Bundle ID，如果为 nil 则返回默认配置
    /// - Returns: 对应的润色配置文件
    /// - Note: 如果 appProfileMapping 包含该 bundleId，返回对应配置；否则返回 defaultProfile
    /// - Validates: Requirements 4.5, 4.6, 4.7
    func getProfileForApp(bundleId: String?) -> PolishProfile {
        guard let bundleId = bundleId else {
            return defaultProfile
        }
        
        // 如果 appProfileMapping 包含当前 BundleID，使用对应 Profile
        // 否则使用 defaultProfile
        return appProfileMapping[bundleId] ?? defaultProfile
    }
    
    // MARK: - Helper Methods
    
    /// 获取应用信息（用于 UI 显示）
    /// - Parameter bundleId: 应用的 Bundle ID
    /// - Returns: 包含应用名称和图标的元组
    func getAppInfo(for bundleId: String) -> (name: String, icon: NSImage?) {
        if let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let appName = FileManager.default.displayName(atPath: appPath.path)
            let icon = NSWorkspace.shared.icon(forFile: appPath.path)
            return (appName, icon)
        }
        return (bundleId, nil)
    }
    
    /// 获取所有已配置的应用列表（用于 UI 显示）
    /// - Returns: 应用配置信息数组
    func getConfiguredApps() -> [AppProfileInfo] {
        return appProfileMapping.map { bundleId, profile in
            let (name, icon) = getAppInfo(for: bundleId)
            return AppProfileInfo(bundleId: bundleId, name: name, icon: icon, profile: profile)
        }.sorted { $0.name < $1.name }
    }
    
    /// 重置为默认设置
    func resetToDefaults() {
        enableAIPolish = false
        polishThreshold = 20
        defaultProfile = .standard
        appProfileMapping = [:]
        customProfilePrompt = ""
        enableInSentencePatterns = true
        enableTriggerCommands = true
        triggerWord = "Ghost"
    }
}

// MARK: - AppProfileInfo

/// 应用配置信息（用于 UI 显示）
struct AppProfileInfo: Identifiable {
    let id = UUID()
    let bundleId: String
    let name: String
    let icon: NSImage?
    let profile: PolishProfile
}
