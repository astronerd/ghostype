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
    
    /// 当前选中的配置 ID（预设 rawValue 或自定义 UUID 字符串）
    var selectedProfileId: String {
        didSet {
            AppSettings.shared.selectedProfileId = selectedProfileId
            // 同步写入 defaultProfile 以保持兼容
            AppSettings.shared.defaultProfile = selectedProfileId
        }
    }
    
    /// 自定义润色风格列表
    var customProfiles: [CustomProfile] {
        didSet {
            AppSettings.shared.customProfiles = customProfiles
        }
    }
    
    /// 应用专属配置映射 [BundleID: ProfileID]
    var appProfileMapping: [String: String] {
        didSet {
            AppSettings.shared.appProfileMapping = appProfileMapping
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
        self.selectedProfileId = settings.selectedProfileId
        self.customProfiles = settings.customProfiles
        self.appProfileMapping = settings.appProfileMapping
        
        // 加载智能指令设置
        self.enableInSentencePatterns = settings.enableInSentencePatterns
        self.enableTriggerCommands = settings.enableTriggerCommands
        self.triggerWord = settings.triggerWord
    }
    
    // MARK: - Profile Selection
    
    /// 选择配置（预设 rawValue 或自定义 UUID 字符串）
    func selectProfile(id: String) {
        selectedProfileId = id
    }
    
    // MARK: - Custom Profile CRUD
    
    /// 添加自定义润色风格
    func addCustomProfile(name: String, prompt: String) {
        let profile = CustomProfile(name: name, prompt: prompt)
        customProfiles.append(profile)
    }
    
    /// 更新自定义润色风格
    func updateCustomProfile(id: UUID, name: String, prompt: String) {
        if let index = customProfiles.firstIndex(where: { $0.id == id }) {
            customProfiles[index].name = name
            customProfiles[index].prompt = prompt
        }
    }
    
    /// 删除自定义润色风格（含级联逻辑）
    func deleteCustomProfile(id: UUID) {
        let idString = id.uuidString
        
        // 如果删除的是当前选中的风格，回退为默认
        if selectedProfileId == idString {
            selectedProfileId = PolishProfile.standard.rawValue
        }
        
        // 级联重置引用该风格的应用映射
        for (bundleId, profileId) in appProfileMapping {
            if profileId == idString {
                appProfileMapping[bundleId] = PolishProfile.standard.rawValue
            }
        }
        
        // 从列表中移除
        customProfiles.removeAll { $0.id == id }
    }
    
    // MARK: - Profile Resolution
    
    /// 解析指定应用应使用的配置
    /// - Parameter bundleId: 应用的 Bundle ID，nil 则使用全局默认
    /// - Returns: (profile: 预设风格, customPrompt: 自定义 Prompt)
    ///   - 预设风格时：profile 有值，customPrompt 为 nil
    ///   - 自定义风格时：profile 为 .standard（fallback），customPrompt 为自定义 Prompt
    func resolveProfile(for bundleId: String?) -> (profile: PolishProfile, customPrompt: String?) {
        // 确定要使用的 profileId
        let profileId: String
        if let bundleId = bundleId, let appProfileId = appProfileMapping[bundleId] {
            profileId = appProfileId
        } else {
            profileId = selectedProfileId
        }
        
        // 尝试解析为预设风格
        if let preset = PolishProfile(rawValue: profileId) {
            return (profile: preset, customPrompt: nil)
        }
        
        // 尝试解析为自定义风格
        if let customProfile = customProfiles.first(where: { $0.id.uuidString == profileId }) {
            return (profile: .standard, customPrompt: customProfile.prompt)
        }
        
        // 无法解析，回退为默认
        return (profile: .standard, customPrompt: nil)
    }
    
    // MARK: - 应用映射管理方法
    
    /// 添加应用专属配置映射
    func addAppMapping(bundleId: String, profileId: String) {
        appProfileMapping[bundleId] = profileId
    }
    
    /// 移除应用专属配置映射
    func removeAppMapping(bundleId: String) {
        appProfileMapping.removeValue(forKey: bundleId)
    }
    
    // MARK: - Helper Methods
    
    /// 获取应用信息（用于 UI 显示）
    func getAppInfo(for bundleId: String) -> (name: String, icon: NSImage?) {
        if let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let appName = FileManager.default.displayName(atPath: appPath.path)
            let icon = NSWorkspace.shared.icon(forFile: appPath.path)
            return (appName, icon)
        }
        return (bundleId, nil)
    }
    
    /// 获取所有已配置的应用列表（用于 UI 显示）
    func getConfiguredApps() -> [AppProfileInfo] {
        return appProfileMapping.map { bundleId, profileId in
            let (name, icon) = getAppInfo(for: bundleId)
            return AppProfileInfo(bundleId: bundleId, name: name, icon: icon, profileId: profileId)
        }.sorted { $0.name < $1.name }
    }
    
    /// 重置为默认设置
    func resetToDefaults() {
        enableAIPolish = false
        polishThreshold = 20
        selectedProfileId = PolishProfile.standard.rawValue
        customProfiles = []
        appProfileMapping = [:]
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
    let profileId: String
}
