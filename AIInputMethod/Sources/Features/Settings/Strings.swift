import Foundation

// MARK: - Localized Strings
// 所有 UI 字符串的中英文翻译表
// 添加新字符串时，在对应分类下添加 case，并在 zh/en 两个 computed property 中添加翻译

enum L {
    
    // MARK: - Navigation / 导航
    enum Nav {
        static var overview: String { current.nav.overview }
        static var library: String { current.nav.library }
        static var memo: String { current.nav.memo }
        static var aiPolish: String { current.nav.aiPolish }
        static var preferences: String { current.nav.preferences }
    }
    
    // MARK: - Overview Page / 概览页
    enum Overview {
        static var title: String { current.overview.title }
        static var todayUsage: String { current.overview.todayUsage }
        static var totalRecords: String { current.overview.totalRecords }
        static var polishCount: String { current.overview.polishCount }
        static var translateCount: String { current.overview.translateCount }
        static var memoCount: String { current.overview.memoCount }
    }
    
    // MARK: - Library Page / 记录库页
    enum Library {
        static var title: String { current.library.title }
        static var empty: String { current.library.empty }
        static var search: String { current.library.search }
        static var all: String { current.library.all }
        static var polish: String { current.library.polish }
        static var translate: String { current.library.translate }
        static var memo: String { current.library.memo }
    }
    
    // MARK: - Memo Page / 随心记页
    enum Memo {
        static var title: String { current.memo.title }
        static var empty: String { current.memo.empty }
        static var placeholder: String { current.memo.placeholder }
    }
    
    // MARK: - AI Polish Page / AI润色页
    enum AIPolish {
        static var title: String { current.aiPolish.title }
        static var enable: String { current.aiPolish.enable }
        static var enableDesc: String { current.aiPolish.enableDesc }
        static var threshold: String { current.aiPolish.threshold }
        static var thresholdDesc: String { current.aiPolish.thresholdDesc }
        static var thresholdUnit: String { current.aiPolish.thresholdUnit }
        static var profile: String { current.aiPolish.profile }
        static var profileDesc: String { current.aiPolish.profileDesc }
        static var inSentence: String { current.aiPolish.inSentence }
        static var inSentenceDesc: String { current.aiPolish.inSentenceDesc }
        static var trigger: String { current.aiPolish.trigger }
        static var triggerDesc: String { current.aiPolish.triggerDesc }
        static var triggerWord: String { current.aiPolish.triggerWord }
        static var triggerWordDesc: String { current.aiPolish.triggerWordDesc }
    }
    
    // MARK: - Preferences Page / 偏好设置页
    enum Prefs {
        static var title: String { current.prefs.title }
        static var general: String { current.prefs.general }
        static var launchAtLogin: String { current.prefs.launchAtLogin }
        static var launchAtLoginDesc: String { current.prefs.launchAtLoginDesc }
        static var soundFeedback: String { current.prefs.soundFeedback }
        static var soundFeedbackDesc: String { current.prefs.soundFeedbackDesc }
        static var inputMode: String { current.prefs.inputMode }
        static var inputModeAuto: String { current.prefs.inputModeAuto }
        static var inputModeManual: String { current.prefs.inputModeManual }
        static var language: String { current.prefs.language }
        static var languageDesc: String { current.prefs.languageDesc }
        static var permissions: String { current.prefs.permissions }
        static var accessibility: String { current.prefs.accessibility }
        static var accessibilityDesc: String { current.prefs.accessibilityDesc }
        static var microphone: String { current.prefs.microphone }
        static var microphoneDesc: String { current.prefs.microphoneDesc }
        static var refreshStatus: String { current.prefs.refreshStatus }
        static var authorize: String { current.prefs.authorize }
        static var hotkey: String { current.prefs.hotkey }
        static var hotkeyTrigger: String { current.prefs.hotkeyTrigger }
        static var hotkeyDesc: String { current.prefs.hotkeyDesc }
        static var hotkeyHint: String { current.prefs.hotkeyHint }
        static var hotkeyRecording: String { current.prefs.hotkeyRecording }
        static var modeModifiers: String { current.prefs.modeModifiers }
        static var translateMode: String { current.prefs.translateMode }
        static var translateModeDesc: String { current.prefs.translateModeDesc }
        static var memoMode: String { current.prefs.memoMode }
        static var memoModeDesc: String { current.prefs.memoModeDesc }
        static var translateSettings: String { current.prefs.translateSettings }
        static var translateLanguage: String { current.prefs.translateLanguage }
        static var translateLanguageDesc: String { current.prefs.translateLanguageDesc }
        static var contactsHotwords: String { current.prefs.contactsHotwords }
        static var contactsHotwordsEnable: String { current.prefs.contactsHotwordsEnable }
        static var contactsHotwordsDesc: String { current.prefs.contactsHotwordsDesc }
        static var authStatus: String { current.prefs.authStatus }
        static var hotwordsCount: String { current.prefs.hotwordsCount }
        static var authorizeAccess: String { current.prefs.authorizeAccess }
        static var openSettings: String { current.prefs.openSettings }
        static var autoSend: String { current.prefs.autoSend }
        static var autoSendEnable: String { current.prefs.autoSendEnable }
        static var autoSendDesc: String { current.prefs.autoSendDesc }
        static var automationPermission: String { current.prefs.automationPermission }
        static var automationPermissionDesc: String { current.prefs.automationPermissionDesc }
        static var enabledApps: String { current.prefs.enabledApps }
        static var addApp: String { current.prefs.addApp }
        static var noAppsHint: String { current.prefs.noAppsHint }
        static var aiEngine: String { current.prefs.aiEngine }
        static var aiEngineName: String { current.prefs.aiEngineName }
        static var aiEngineApi: String { current.prefs.aiEngineApi }
        static var aiEngineOnline: String { current.prefs.aiEngineOnline }
        static var aiEngineOffline: String { current.prefs.aiEngineOffline }
        static var aiEngineChecking: String { current.prefs.aiEngineChecking }
        static var reset: String { current.prefs.reset }
    }
    
    // MARK: - Common / 通用
    enum Common {
        static var cancel: String { current.common.cancel }
        static var done: String { current.common.done }
        static var save: String { current.common.save }
        static var delete: String { current.common.delete }
        static var edit: String { current.common.edit }
        static var add: String { current.common.add }
        static var copy: String { current.common.copy }
        static var close: String { current.common.close }
        static var ok: String { current.common.ok }
        static var yes: String { current.common.yes }
        static var no: String { current.common.no }
        static var on: String { current.common.on }
        static var off: String { current.common.off }
        static var enabled: String { current.common.enabled }
        static var disabled: String { current.common.disabled }
        static var defaultText: String { current.common.defaultText }
        static var custom: String { current.common.custom }
        static var none: String { current.common.none }
        static var unknown: String { current.common.unknown }
        static var loading: String { current.common.loading }
        static var error: String { current.common.error }
        static var success: String { current.common.success }
        static var warning: String { current.common.warning }
        static var characters: String { current.common.characters }
    }
    
    // MARK: - App Picker / 应用选择器
    enum AppPicker {
        static var title: String { current.appPicker.title }
        static var noApps: String { current.appPicker.noApps }
    }
    
    // MARK: - Polish Profiles / 润色风格
    enum Profile {
        static var standard: String { current.profile.standard }
        static var professional: String { current.profile.professional }
        static var casual: String { current.profile.casual }
        static var concise: String { current.profile.concise }
        static var creative: String { current.profile.creative }
        static var custom: String { current.profile.custom }
    }
    
    // MARK: - Auth Status / 授权状态
    enum Auth {
        static var unknown: String { current.auth.unknown }
        static var notDetermined: String { current.auth.notDetermined }
        static var authorized: String { current.auth.authorized }
        static var denied: String { current.auth.denied }
        static var restricted: String { current.auth.restricted }
    }
    
    // MARK: - Private Implementation
    
    private static var current: StringsTable {
        switch LocalizationManager.shared.currentLanguage {
        case .chinese: return ChineseStrings()
        case .english: return EnglishStrings()
        }
    }
}

// MARK: - Strings Table Protocol

protocol StringsTable {
    var nav: NavStrings { get }
    var overview: OverviewStrings { get }
    var library: LibraryStrings { get }
    var memo: MemoStrings { get }
    var aiPolish: AIPolishStrings { get }
    var prefs: PrefsStrings { get }
    var common: CommonStrings { get }
    var appPicker: AppPickerStrings { get }
    var profile: ProfileStrings { get }
    var auth: AuthStrings { get }
}

protocol NavStrings {
    var overview: String { get }
    var library: String { get }
    var memo: String { get }
    var aiPolish: String { get }
    var preferences: String { get }
}

protocol OverviewStrings {
    var title: String { get }
    var todayUsage: String { get }
    var totalRecords: String { get }
    var polishCount: String { get }
    var translateCount: String { get }
    var memoCount: String { get }
}

protocol LibraryStrings {
    var title: String { get }
    var empty: String { get }
    var search: String { get }
    var all: String { get }
    var polish: String { get }
    var translate: String { get }
    var memo: String { get }
}

protocol MemoStrings {
    var title: String { get }
    var empty: String { get }
    var placeholder: String { get }
}

protocol AIPolishStrings {
    var title: String { get }
    var enable: String { get }
    var enableDesc: String { get }
    var threshold: String { get }
    var thresholdDesc: String { get }
    var thresholdUnit: String { get }
    var profile: String { get }
    var profileDesc: String { get }
    var inSentence: String { get }
    var inSentenceDesc: String { get }
    var trigger: String { get }
    var triggerDesc: String { get }
    var triggerWord: String { get }
    var triggerWordDesc: String { get }
}

protocol PrefsStrings {
    var title: String { get }
    var general: String { get }
    var launchAtLogin: String { get }
    var launchAtLoginDesc: String { get }
    var soundFeedback: String { get }
    var soundFeedbackDesc: String { get }
    var inputMode: String { get }
    var inputModeAuto: String { get }
    var inputModeManual: String { get }
    var language: String { get }
    var languageDesc: String { get }
    var permissions: String { get }
    var accessibility: String { get }
    var accessibilityDesc: String { get }
    var microphone: String { get }
    var microphoneDesc: String { get }
    var refreshStatus: String { get }
    var authorize: String { get }
    var hotkey: String { get }
    var hotkeyTrigger: String { get }
    var hotkeyDesc: String { get }
    var hotkeyHint: String { get }
    var hotkeyRecording: String { get }
    var modeModifiers: String { get }
    var translateMode: String { get }
    var translateModeDesc: String { get }
    var memoMode: String { get }
    var memoModeDesc: String { get }
    var translateSettings: String { get }
    var translateLanguage: String { get }
    var translateLanguageDesc: String { get }
    var contactsHotwords: String { get }
    var contactsHotwordsEnable: String { get }
    var contactsHotwordsDesc: String { get }
    var authStatus: String { get }
    var hotwordsCount: String { get }
    var authorizeAccess: String { get }
    var openSettings: String { get }
    var autoSend: String { get }
    var autoSendEnable: String { get }
    var autoSendDesc: String { get }
    var automationPermission: String { get }
    var automationPermissionDesc: String { get }
    var enabledApps: String { get }
    var addApp: String { get }
    var noAppsHint: String { get }
    var aiEngine: String { get }
    var aiEngineName: String { get }
    var aiEngineApi: String { get }
    var aiEngineOnline: String { get }
    var aiEngineOffline: String { get }
    var aiEngineChecking: String { get }
    var reset: String { get }
}

protocol CommonStrings {
    var cancel: String { get }
    var done: String { get }
    var save: String { get }
    var delete: String { get }
    var edit: String { get }
    var add: String { get }
    var copy: String { get }
    var close: String { get }
    var ok: String { get }
    var yes: String { get }
    var no: String { get }
    var on: String { get }
    var off: String { get }
    var enabled: String { get }
    var disabled: String { get }
    var defaultText: String { get }
    var custom: String { get }
    var none: String { get }
    var unknown: String { get }
    var loading: String { get }
    var error: String { get }
    var success: String { get }
    var warning: String { get }
    var characters: String { get }
}

protocol AppPickerStrings {
    var title: String { get }
    var noApps: String { get }
}

protocol ProfileStrings {
    var standard: String { get }
    var professional: String { get }
    var casual: String { get }
    var concise: String { get }
    var creative: String { get }
    var custom: String { get }
}

protocol AuthStrings {
    var unknown: String { get }
    var notDetermined: String { get }
    var authorized: String { get }
    var denied: String { get }
    var restricted: String { get }
}
