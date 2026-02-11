import Foundation

// MARK: - Localized Strings
// 所有 UI 字符串的中英文翻译表
// 添加新字符串时，在对应分类下添加 case，并在 zh/en 两个 computed property 中添加翻译

enum L {
    
    // MARK: - Account Page / 账号页
    enum Account {
        static var title: String { current.account.title }
        static var welcomeTitle: String { current.account.welcomeTitle }
        static var welcomeDesc: String { current.account.welcomeDesc }
        static var login: String { current.account.login }
        static var signUp: String { current.account.signUp }
        static var deviceIdHint: String { current.account.deviceIdHint }
        static var profile: String { current.account.profile }
        static var loggedIn: String { current.account.loggedIn }
        static var logout: String { current.account.logout }
        static var quota: String { current.account.quota }
        static var plan: String { current.account.plan }
        static var used: String { current.account.used }
    }
    
    // MARK: - Onboarding / 引导
    enum Onboarding {
        static var skip: String { current.onboarding.skip }
        static var next: String { current.onboarding.next }
        static var back: String { current.onboarding.back }
        static var start: String { current.onboarding.start }
        static var hotkeyTitle: String { current.onboarding.hotkeyTitle }
        static var hotkeyDesc: String { current.onboarding.hotkeyDesc }
        static var hotkeyRecording: String { current.onboarding.hotkeyRecording }
        static var hotkeyHint: String { current.onboarding.hotkeyHint }
        static var permTitle: String { current.onboarding.permTitle }
        static var permDesc: String { current.onboarding.permDesc }
        static var permAccessibility: String { current.onboarding.permAccessibility }
        static var permAccessibilityDesc: String { current.onboarding.permAccessibilityDesc }
        static var permMicrophone: String { current.onboarding.permMicrophone }
        static var permMicrophoneDesc: String { current.onboarding.permMicrophoneDesc }
        static var authorize: String { current.onboarding.authorize }
        static var waitingLogin: String { current.onboarding.waitingLogin }
        static var waitingLoginDesc: String { current.onboarding.waitingLoginDesc }
        static var openInBrowser: String { current.onboarding.openInBrowser }
    }
    
    // MARK: - Navigation / 导航
    enum Nav {
        static var account: String { current.nav.account }
        static var overview: String { current.nav.overview }
        static var incubator: String { current.nav.incubator }
        static var library: String { current.nav.library }
        static var memo: String { current.nav.memo }
        static var aiPolish: String { current.nav.aiPolish }
        static var preferences: String { current.nav.preferences }
    }
    
    // MARK: - Incubator / 孵化室
    enum Incubator {
        static var title: String { current.incubator.title }
        static var level: String { current.incubator.level }
        static var syncRate: String { current.incubator.syncRate }
        static var wordsProgress: String { current.incubator.wordsProgress }
        static var levelUp: String { current.incubator.levelUp }
        static var ghostStatus: String { current.incubator.ghostStatus }
        static var subtitle: String { current.incubator.subtitle }
        static var incoming: String { current.incubator.incoming }
        static var tapToCalibrate: String { current.incubator.tapToCalibrate }
        static var noMoreSignals: String { current.incubator.noMoreSignals }
        static var statusLevel: String { current.incubator.statusLevel }
        static var statusXP: String { current.incubator.statusXP }
        static var statusSync: String { current.incubator.statusSync }
        static var statusChallenges: String { current.incubator.statusChallenges }
        static var statusPersonality: String { current.incubator.statusPersonality }
        static var statusNone: String { current.incubator.statusNone }
        static var idleTextsLevel1to3: [String] { current.incubator.idleTextsLevel1to3 }
        static var idleTextsLevel4to6: [String] { current.incubator.idleTextsLevel4to6 }
        static var idleTextsLevel7to9: [String] { current.incubator.idleTextsLevel7to9 }
        static var idleTextsLevel10: [String] { current.incubator.idleTextsLevel10 }
        
        /// 根据等级返回对应的闲置文案数组
        static func idleTexts(forLevel level: Int) -> [String] {
            switch level {
            case 1...3: return idleTextsLevel1to3
            case 4...6: return idleTextsLevel4to6
            case 7...9: return idleTextsLevel7to9
            case 10: return idleTextsLevel10
            default: return idleTextsLevel1to3
            }
        }
    }
    
    // MARK: - Overview Page / 概览页
    enum Overview {
        static var title: String { current.overview.title }
        static var subtitle: String { current.overview.subtitle }
        static var todayUsage: String { current.overview.todayUsage }
        static var totalRecords: String { current.overview.totalRecords }
        static var polishCount: String { current.overview.polishCount }
        static var translateCount: String { current.overview.translateCount }
        static var memoCount: String { current.overview.memoCount }
        static var wordCount: String { current.overview.wordCount }
        static var today: String { current.overview.today }
        static var chars: String { current.overview.chars }
        static var total: String { current.overview.total }
        static var timeSaved: String { current.overview.timeSaved }
        static var energyRing: String { current.overview.energyRing }
        static var used: String { current.overview.used }
        static var remaining: String { current.overview.remaining }
        static var appDist: String { current.overview.appDist }
        static var recentNotes: String { current.overview.recentNotes }
        static var noNotes: String { current.overview.noNotes }
        static var apps: String { current.overview.apps }
        static var noData: String { current.overview.noData }
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
        static var noteCount: String { current.memo.noteCount }
        static var search: String { current.memo.search }
        static var noMatch: String { current.memo.noMatch }
        static var emptyHint: String { current.memo.emptyHint }
        static var searchHint: String { current.memo.searchHint }
        static var editNote: String { current.memo.editNote }
        static var createdAt: String { current.memo.createdAt }
        static var confirmDelete: String { current.memo.confirmDelete }
        static var confirmDeleteMsg: String { current.memo.confirmDeleteMsg }
        static var charCount: String { current.memo.charCount }
    }
    
    // MARK: - AI Polish Page / AI润色页
    enum AIPolish {
        static var title: String { current.aiPolish.title }
        static var basicSettings: String { current.aiPolish.basicSettings }
        static var enable: String { current.aiPolish.enable }
        static var enableDesc: String { current.aiPolish.enableDesc }
        static var threshold: String { current.aiPolish.threshold }
        static var thresholdDesc: String { current.aiPolish.thresholdDesc }
        static var thresholdUnit: String { current.aiPolish.thresholdUnit }
        static var profile: String { current.aiPolish.profile }
        static var profileDesc: String { current.aiPolish.profileDesc }
        static var styleSection: String { current.aiPolish.styleSection }
        static var createCustomStyle: String { current.aiPolish.createCustomStyle }
        static var editCustomStyle: String { current.aiPolish.editCustomStyle }
        static var styleName: String { current.aiPolish.styleName }
        static var styleNamePlaceholder: String { current.aiPolish.styleNamePlaceholder }
        static var promptLabel: String { current.aiPolish.promptLabel }
        static var appProfile: String { current.aiPolish.appProfile }
        static var appProfileDesc: String { current.aiPolish.appProfileDesc }
        static var noAppProfile: String { current.aiPolish.noAppProfile }
        static var smartCommands: String { current.aiPolish.smartCommands }
        static var inSentence: String { current.aiPolish.inSentence }
        static var inSentenceDesc: String { current.aiPolish.inSentenceDesc }
        static var examples: String { current.aiPolish.examples }
        static var trigger: String { current.aiPolish.trigger }
        static var triggerDesc: String { current.aiPolish.triggerDesc }
        static var triggerWord: String { current.aiPolish.triggerWord }
        static var triggerWordDesc: String { current.aiPolish.triggerWordDesc }
        static var triggerExamplesTitle: String { current.aiPolish.triggerExamplesTitle }
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
    
    // MARK: - Translate Language / 翻译语言
    enum Translate {
        static var chineseEnglish: String { current.translate.chineseEnglish }
        static var chineseJapanese: String { current.translate.chineseJapanese }
        static var auto: String { current.translate.auto }
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
        static var sessionExpiredTitle: String { current.auth.sessionExpiredTitle }
        static var sessionExpiredDesc: String { current.auth.sessionExpiredDesc }
        static var reLogin: String { current.auth.reLogin }
        static var later: String { current.auth.later }
        static var loginRequired: String { current.auth.loginRequired }
    }
    
    // MARK: - Quota / 额度
    enum Quota {
        static var monthlyQuota: String { current.quota.monthlyQuota }
        static var characters: String { current.quota.characters }
        static var unlimited: String { current.quota.unlimited }
        static var resetPrefix: String { current.quota.resetPrefix }
        static var resetSuffix: String { current.quota.resetSuffix }
        static var daysUnit: String { current.quota.daysUnit }
        static var hoursUnit: String { current.quota.hoursUnit }
        static var expired: String { current.quota.expired }
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
    var onboarding: OnboardingStrings { get }
    var account: AccountStrings { get }
    var nav: NavStrings { get }
    var overview: OverviewStrings { get }
    var library: LibraryStrings { get }
    var memo: MemoStrings { get }
    var aiPolish: AIPolishStrings { get }
    var prefs: PrefsStrings { get }
    var common: CommonStrings { get }
    var appPicker: AppPickerStrings { get }
    var translate: TranslateStrings { get }
    var profile: ProfileStrings { get }
    var auth: AuthStrings { get }
    var quota: QuotaStrings { get }
    var incubator: IncubatorStrings { get }
}

protocol OnboardingStrings {
    var skip: String { get }
    var next: String { get }
    var back: String { get }
    var start: String { get }
    var hotkeyTitle: String { get }
    var hotkeyDesc: String { get }
    var hotkeyRecording: String { get }
    var hotkeyHint: String { get }
    var permTitle: String { get }
    var permDesc: String { get }
    var permAccessibility: String { get }
    var permAccessibilityDesc: String { get }
    var permMicrophone: String { get }
    var permMicrophoneDesc: String { get }
    var authorize: String { get }
    var waitingLogin: String { get }
    var waitingLoginDesc: String { get }
    var openInBrowser: String { get }
}

protocol AccountStrings {
    var title: String { get }
    var welcomeTitle: String { get }
    var welcomeDesc: String { get }
    var login: String { get }
    var signUp: String { get }
    var deviceIdHint: String { get }
    var profile: String { get }
    var loggedIn: String { get }
    var logout: String { get }
    var quota: String { get }
    var plan: String { get }
    var used: String { get }
}

protocol NavStrings {
    var account: String { get }
    var overview: String { get }
    var incubator: String { get }
    var library: String { get }
    var memo: String { get }
    var aiPolish: String { get }
    var preferences: String { get }
}

protocol OverviewStrings {
    var title: String { get }
    var subtitle: String { get }
    var todayUsage: String { get }
    var totalRecords: String { get }
    var polishCount: String { get }
    var translateCount: String { get }
    var memoCount: String { get }
    var wordCount: String { get }
    var today: String { get }
    var chars: String { get }
    var total: String { get }
    var timeSaved: String { get }
    var energyRing: String { get }
    var used: String { get }
    var remaining: String { get }
    var appDist: String { get }
    var recentNotes: String { get }
    var noNotes: String { get }
    var apps: String { get }
    var noData: String { get }
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
    var noteCount: String { get }
    var search: String { get }
    var noMatch: String { get }
    var emptyHint: String { get }
    var searchHint: String { get }
    var editNote: String { get }
    var createdAt: String { get }
    var confirmDelete: String { get }
    var confirmDeleteMsg: String { get }
    var charCount: String { get }
}

protocol AIPolishStrings {
    var title: String { get }
    var basicSettings: String { get }
    var enable: String { get }
    var enableDesc: String { get }
    var threshold: String { get }
    var thresholdDesc: String { get }
    var thresholdUnit: String { get }
    var profile: String { get }
    var profileDesc: String { get }
    var styleSection: String { get }
    var createCustomStyle: String { get }
    var editCustomStyle: String { get }
    var styleName: String { get }
    var styleNamePlaceholder: String { get }
    var promptLabel: String { get }
    var appProfile: String { get }
    var appProfileDesc: String { get }
    var noAppProfile: String { get }
    var smartCommands: String { get }
    var inSentence: String { get }
    var inSentenceDesc: String { get }
    var examples: String { get }
    var trigger: String { get }
    var triggerDesc: String { get }
    var triggerWord: String { get }
    var triggerWordDesc: String { get }
    var triggerExamplesTitle: String { get }
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

protocol TranslateStrings {
    var chineseEnglish: String { get }
    var chineseJapanese: String { get }
    var auto: String { get }
}

protocol AuthStrings {
    var unknown: String { get }
    var notDetermined: String { get }
    var authorized: String { get }
    var denied: String { get }
    var restricted: String { get }
    var sessionExpiredTitle: String { get }
    var sessionExpiredDesc: String { get }
    var reLogin: String { get }
    var later: String { get }
    var loginRequired: String { get }
}

protocol QuotaStrings {
    var monthlyQuota: String { get }
    var characters: String { get }
    var unlimited: String { get }
    var resetPrefix: String { get }
    var resetSuffix: String { get }
    var daysUnit: String { get }
    var hoursUnit: String { get }
    var expired: String { get }
}

protocol IncubatorStrings {
    var title: String { get }
    var subtitle: String { get }
    var level: String { get }
    var syncRate: String { get }
    var wordsProgress: String { get }
    var levelUp: String { get }
    var ghostStatus: String { get }
    var incoming: String { get }
    var tapToCalibrate: String { get }
    var noMoreSignals: String { get }
    var statusLevel: String { get }
    var statusXP: String { get }
    var statusSync: String { get }
    var statusChallenges: String { get }
    var statusPersonality: String { get }
    var statusNone: String { get }
    var idleTextsLevel1to3: [String] { get }
    var idleTextsLevel4to6: [String] { get }
    var idleTextsLevel7to9: [String] { get }
    var idleTextsLevel10: [String] { get }
}
