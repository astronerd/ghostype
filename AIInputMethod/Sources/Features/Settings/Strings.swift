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
        static var freePlan: String { current.account.freePlan }
        static var proPlan: String { current.account.proPlan }
        static var lifetimeVipPlan: String { current.account.lifetimeVipPlan }
        static var lifetimeVipBadge: String { current.account.lifetimeVipBadge }
        static var permanent: String { current.account.permanent }
        static var upgradePro: String { current.account.upgradePro }
        static var manageSubscription: String { current.account.manageSubscription }
        static var expiresAt: String { current.account.expiresAt }
        static var activated: String { current.account.activated }
        static var subscription: String { current.account.subscription }
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
        static var skills: String { current.nav.skills }
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
        
        static var coldStartGuide: String { current.incubator.coldStartGuide }
        static var customAnswerButton: String { current.incubator.customAnswerButton }
        static var customAnswerPlaceholder: String { current.incubator.customAnswerPlaceholder }
        static var customAnswerSubmit: String { current.incubator.customAnswerSubmit }
        
        /// 根据等级返回对应的闲置文案数组
        static func idleTexts(forLevel level: Int) -> [String] {
            switch level {
            case 0...3: return idleTextsLevel1to3
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
        static var subtitle: String { current.library.subtitle }
        static var empty: String { current.library.empty }
        static var search: String { current.library.search }
        static var searchPlaceholder: String { current.library.searchPlaceholder }
        static var all: String { current.library.all }
        static var polish: String { current.library.polish }
        static var translate: String { current.library.translate }
        static var memo: String { current.library.memo }
        static var recordCount: String { current.library.recordCount }
        static var unknownApp: String { current.library.unknownApp }
        static var copyBtn: String { current.library.copyBtn }
        static var copiedToast: String { current.library.copiedToast }
        static var selectRecord: String { current.library.selectRecord }
        static var categoryGeneral: String { current.library.categoryGeneral }
        static var emptySearchTitle: String { current.library.emptySearchTitle }
        static var emptySearchMsg: String { current.library.emptySearchMsg }
        static var emptyCategoryTitle: String { current.library.emptyCategoryTitle }
        static var emptyCategoryMsg: String { current.library.emptyCategoryMsg }
        static var emptyTitle: String { current.library.emptyTitle }
        static var emptyMsg: String { current.library.emptyMsg }
        static var seconds: String { current.library.seconds }
        static var minutes: String { current.library.minutes }
        static var minuteSeconds: String { current.library.minuteSeconds }
        static var exportPrefix: String { current.library.exportPrefix }
        static var confirmDeleteTitle: String { current.library.confirmDeleteTitle }
        static var confirmDeleteMsg: String { current.library.confirmDeleteMsg }
        static var originalText: String { current.library.originalText }
        static var processedText: String { current.library.processedText }
        static var skillDeleted: String { current.library.skillDeleted }
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
        static var checkUpdate: String { current.prefs.checkUpdate }
        static var currentVersion: String { current.prefs.currentVersion }
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
        static var chineseKorean: String { current.translate.chineseKorean }
        static var chineseFrench: String { current.translate.chineseFrench }
        static var chineseGerman: String { current.translate.chineseGerman }
        static var chineseSpanish: String { current.translate.chineseSpanish }
        static var chineseRussian: String { current.translate.chineseRussian }
        static var englishJapanese: String { current.translate.englishJapanese }
        static var englishKorean: String { current.translate.englishKorean }
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
        static var standardDesc: String { current.profile.standardDesc }
        static var professionalDesc: String { current.profile.professionalDesc }
        static var casualDesc: String { current.profile.casualDesc }
        static var conciseDesc: String { current.profile.conciseDesc }
        static var creativeDesc: String { current.profile.creativeDesc }
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
    
    // MARK: - Floating Card / 悬浮卡片
    enum FloatingCard {
        static var copy: String { current.floatingCard.copy }
        static var share: String { current.floatingCard.share }
        static var hotkeyConflict: String { current.floatingCard.hotkeyConflict }
    }

    // MARK: - Banner / 权限横幅
    enum Banner {
        static var permissionTitle: String { current.banner.permissionTitle }
        static var permissionMissing: String { current.banner.permissionMissing }
        static var grantAccessibility: String { current.banner.grantAccessibility }
        static var grantMicrophone: String { current.banner.grantMicrophone }
    }

    // MARK: - Skill / 技能
    enum Skill {
        static var title: String { current.skill.title }
        static var subtitle: String { current.skill.subtitle }
        static var addSkill: String { current.skill.addSkill }
        static var editSkill: String { current.skill.editSkill }
        static var deleteSkill: String { current.skill.deleteSkill }
        static var cannotDeleteBuiltin: String { current.skill.cannotDeleteBuiltin }
        static var keyConflict: String { current.skill.keyConflict }
        static var unboundKey: String { current.skill.unboundKey }
        static var bindKey: String { current.skill.bindKey }
        static var pressKey: String { current.skill.pressKey }
        static var promptTemplate: String { current.skill.promptTemplate }
        static var skillName: String { current.skill.skillName }
        static var skillDescription: String { current.skill.skillDescription }
        static var skillIcon: String { current.skill.skillIcon }
        static var builtin: String { current.skill.builtin }
        static var custom: String { current.skill.custom }
        static var confirmDelete: String { current.skill.confirmDelete }
        static var confirmDeleteMsg: String { current.skill.confirmDeleteMsg }
        static var createSkill: String { current.skill.createSkill }
        static var namePlaceholder: String { current.skill.namePlaceholder }
        static var descPlaceholder: String { current.skill.descPlaceholder }
        static var promptPlaceholder: String { current.skill.promptPlaceholder }
        static var skillColor: String { current.skill.skillColor }
        static var translateLanguage: String { current.skill.translateLanguage }
        static var searchEmoji: String { current.skill.searchEmoji }
        static var sourceLang: String { current.skill.sourceLang }
        static var targetLang: String { current.skill.targetLang }
        static var autoDetect: String { current.skill.autoDetect }
        static var hexPlaceholder: String { current.skill.hexPlaceholder }
        static var generatingPrompt: String { current.skill.generatingPrompt }
        static var skillInstruction: String { current.skill.skillInstruction }
        static var instructionPlaceholder: String { current.skill.instructionPlaceholder }
        static var hotkeyConflictNote: String { current.skill.hotkeyConflictNote }
        static var emojiInputHint: String { current.skill.emojiInputHint }
        static var openEmojiPanel: String { current.skill.openEmojiPanel }
        static var builtinGhostCommandName: String { current.skill.builtinGhostCommandName }
        static var builtinGhostCommandDesc: String { current.skill.builtinGhostCommandDesc }
        static var builtinGhostTwinName: String { current.skill.builtinGhostTwinName }
        static var builtinGhostTwinDesc: String { current.skill.builtinGhostTwinDesc }
        static var builtinMemoName: String { current.skill.builtinMemoName }
        static var builtinMemoDesc: String { current.skill.builtinMemoDesc }
        static var builtinTranslateName: String { current.skill.builtinTranslateName }
        static var builtinTranslateDesc: String { current.skill.builtinTranslateDesc }
        static var langChinese: String { current.skill.langChinese }
        static var langEnglish: String { current.skill.langEnglish }
        static var langJapanese: String { current.skill.langJapanese }
        static var langKorean: String { current.skill.langKorean }
        static var langFrench: String { current.skill.langFrench }
        static var langGerman: String { current.skill.langGerman }
        static var langSpanish: String { current.skill.langSpanish }
        static var langRussian: String { current.skill.langRussian }
    }

    // MARK: - Menu Bar / 菜单栏
    enum MenuBar {
        static var hotkeyPrefix: String { current.menuBar.hotkeyPrefix }
        static var openDashboard: String { current.menuBar.openDashboard }
        static var checkUpdate: String { current.menuBar.checkUpdate }
        static var accessibilityPerm: String { current.menuBar.accessibilityPerm }
        static var accessibilityPermClick: String { current.menuBar.accessibilityPermClick }
        static var micPerm: String { current.menuBar.micPerm }
        static var micPermClick: String { current.menuBar.micPermClick }
        static var devTools: String { current.menuBar.devTools }
        static var overlayTest: String { current.menuBar.overlayTest }
        static var quit: String { current.menuBar.quit }
    }

    // MARK: - Overlay / 悬浮窗
    enum Overlay {
        static var thinking: String { current.overlay.thinking }
        static var listening: String { current.overlay.listening }
        static var listeningPlaceholder: String { current.overlay.listeningPlaceholder }
        static var badgePolished: String { current.overlay.badgePolished }
        static var badgeTranslated: String { current.overlay.badgeTranslated }
        static var badgeSaved: String { current.overlay.badgeSaved }
        static var defaultSkillName: String { current.overlay.defaultSkillName }
    }

    // MARK: - AI Polish Examples / AI润色示例
    enum AIPolishExamples {
        static var inSentenceInput1: String { current.aiPolishExamples.inSentenceInput1 }
        static var inSentenceOutput1: String { current.aiPolishExamples.inSentenceOutput1 }
        static var inSentenceInput2: String { current.aiPolishExamples.inSentenceInput2 }
        static var inSentenceOutput2: String { current.aiPolishExamples.inSentenceOutput2 }
        static var inSentenceInput3: String { current.aiPolishExamples.inSentenceInput3 }
        static var inSentenceOutput3: String { current.aiPolishExamples.inSentenceOutput3 }
        static var triggerInput1: String { current.aiPolishExamples.triggerInput1 }
        static var triggerOutput1: String { current.aiPolishExamples.triggerOutput1 }
        static var triggerInput2: String { current.aiPolishExamples.triggerInput2 }
        static var triggerOutput2: String { current.aiPolishExamples.triggerOutput2 }
        static var triggerInput3: String { current.aiPolishExamples.triggerInput3 }
        static var triggerOutput3: String { current.aiPolishExamples.triggerOutput3 }
    }

    // MARK: - Skill Context / Skill 上下文 Provider
    enum SkillContext {
        static var profileHeader: String { current.skillContext.profileHeader }
        static var profileLevel: String { current.skillContext.profileLevel }
        static var profileFullText: String { current.skillContext.profileFullText }
        static var noCalibrationRecords: String { current.skillContext.noCalibrationRecords }
        static var customAnswer: String { current.skillContext.customAnswer }
        static var optionPrefix: String { current.skillContext.optionPrefix }
        static var noNewCorpus: String { current.skillContext.noNewCorpus }
    }

    // MARK: - MemoSync / 笔记同步
    enum MemoSync {
        // Settings page
        static var title: String { current.memoSync.title }
        static var subtitle: String { current.memoSync.subtitle }
        static var enableSync: String { current.memoSync.enableSync }
        // Adapter names
        static var obsidian: String { current.memoSync.obsidian }
        static var appleNotes: String { current.memoSync.appleNotes }
        static var notion: String { current.memoSync.notion }
        static var bear: String { current.memoSync.bear }
        // Grouping modes
        static var perNote: String { current.memoSync.perNote }
        static var perDay: String { current.memoSync.perDay }
        static var perWeek: String { current.memoSync.perWeek }
        // Config labels
        static var groupingMode: String { current.memoSync.groupingMode }
        static var titleTemplate: String { current.memoSync.titleTemplate }
        static var titleTemplatePlaceholder: String { current.memoSync.titleTemplatePlaceholder }
        static var templateVariables: String { current.memoSync.templateVariables }
        static var templateExample: String { current.memoSync.templateExample }
        static var vaultPath: String { current.memoSync.vaultPath }
        static var selectVault: String { current.memoSync.selectVault }
        static var folderName: String { current.memoSync.folderName }
        static var databaseId: String { current.memoSync.databaseId }
        static var defaultTag: String { current.memoSync.defaultTag }
        static var token: String { current.memoSync.token }
        // Connection status
        static var testConnection: String { current.memoSync.testConnection }
        static var connected: String { current.memoSync.connected }
        static var disconnected: String { current.memoSync.disconnected }
        static var testing: String { current.memoSync.testing }
        // Sync status
        static var synced: String { current.memoSync.synced }
        static var syncFailed: String { current.memoSync.syncFailed }
        static var notSynced: String { current.memoSync.notSynced }
        static var syncSuccess: String { current.memoSync.syncSuccess }
        // Error messages
        static var errorPathNotFound: String { current.memoSync.errorPathNotFound }
        static var errorNoPermission: String { current.memoSync.errorNoPermission }
        static var errorBookmarkExpired: String { current.memoSync.errorBookmarkExpired }
        static var errorAppleScript: String { current.memoSync.errorAppleScript }
        static var errorTokenInvalid: String { current.memoSync.errorTokenInvalid }
        static var errorDatabaseNotFound: String { current.memoSync.errorDatabaseNotFound }
        static var errorRateLimited: String { current.memoSync.errorRateLimited }
        static var errorBearNotInstalled: String { current.memoSync.errorBearNotInstalled }
        static var errorNetwork: String { current.memoSync.errorNetwork }
        static var errorUnknown: String { current.memoSync.errorUnknown }
        // Notion setup wizard
        static var notionSetupTitle: String { current.memoSync.notionSetupTitle }
        static var notionStep1: String { current.memoSync.notionStep1 }
        static var notionStep2: String { current.memoSync.notionStep2 }
        static var notionStep3: String { current.memoSync.notionStep3 }
        static var notionStep4: String { current.memoSync.notionStep4 }
        static var notionStep5: String { current.memoSync.notionStep5 }
        static var openNotionPortal: String { current.memoSync.openNotionPortal }
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
    var floatingCard: FloatingCardStrings { get }
    var banner: BannerStrings { get }
    var skill: SkillStrings { get }
    var menuBar: MenuBarStrings { get }
    var overlay: OverlayStrings { get }
    var aiPolishExamples: AIPolishExamplesStrings { get }
    var skillContext: SkillContextStrings { get }
    var memoSync: MemoSyncStrings { get }
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
    var freePlan: String { get }
    var proPlan: String { get }
    var lifetimeVipPlan: String { get }
    var lifetimeVipBadge: String { get }
    var permanent: String { get }
    var upgradePro: String { get }
    var manageSubscription: String { get }
    var expiresAt: String { get }
    var activated: String { get }
    var subscription: String { get }
}

protocol NavStrings {
    var account: String { get }
    var overview: String { get }
    var incubator: String { get }
    var skills: String { get }
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
    var subtitle: String { get }
    var empty: String { get }
    var search: String { get }
    var searchPlaceholder: String { get }
    var all: String { get }
    var polish: String { get }
    var translate: String { get }
    var memo: String { get }
    var recordCount: String { get }
    var unknownApp: String { get }
    var copyBtn: String { get }
    var copiedToast: String { get }
    var selectRecord: String { get }
    var categoryGeneral: String { get }
    var emptySearchTitle: String { get }
    var emptySearchMsg: String { get }
    var emptyCategoryTitle: String { get }
    var emptyCategoryMsg: String { get }
    var emptyTitle: String { get }
    var emptyMsg: String { get }
    var seconds: String { get }
    var minutes: String { get }
    var minuteSeconds: String { get }
    var exportPrefix: String { get }
    var confirmDeleteTitle: String { get }
    var confirmDeleteMsg: String { get }
    var originalText: String { get }
    var processedText: String { get }
    var skillDeleted: String { get }
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
    var checkUpdate: String { get }
    var currentVersion: String { get }
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
    var standardDesc: String { get }
    var professionalDesc: String { get }
    var casualDesc: String { get }
    var conciseDesc: String { get }
    var creativeDesc: String { get }
}

protocol TranslateStrings {
    var chineseKorean: String { get }
    var chineseFrench: String { get }
    var chineseGerman: String { get }
    var chineseSpanish: String { get }
    var chineseRussian: String { get }
    var englishJapanese: String { get }
    var englishKorean: String { get }
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
    var coldStartGuide: String { get }
    var customAnswerButton: String { get }
    var customAnswerPlaceholder: String { get }
    var customAnswerSubmit: String { get }
}

protocol FloatingCardStrings {
    var copy: String { get }
    var share: String { get }
    var hotkeyConflict: String { get }
}

protocol BannerStrings {
    var permissionTitle: String { get }
    var permissionMissing: String { get }
    var grantAccessibility: String { get }
    var grantMicrophone: String { get }
}

protocol SkillStrings {
    var title: String { get }
    var subtitle: String { get }
    var addSkill: String { get }
    var editSkill: String { get }
    var deleteSkill: String { get }
    var cannotDeleteBuiltin: String { get }
    var keyConflict: String { get }
    var unboundKey: String { get }
    var bindKey: String { get }
    var pressKey: String { get }
    var promptTemplate: String { get }
    var skillName: String { get }
    var skillDescription: String { get }
    var skillIcon: String { get }
    var builtin: String { get }
    var custom: String { get }
    var confirmDelete: String { get }
    var confirmDeleteMsg: String { get }
    var createSkill: String { get }
    var namePlaceholder: String { get }
    var descPlaceholder: String { get }
    var promptPlaceholder: String { get }
    var skillColor: String { get }
    var translateLanguage: String { get }
    var searchEmoji: String { get }
    var sourceLang: String { get }
    var targetLang: String { get }
    var autoDetect: String { get }
    var hexPlaceholder: String { get }
    var generatingPrompt: String { get }
    var skillInstruction: String { get }
    var instructionPlaceholder: String { get }
    var hotkeyConflictNote: String { get }
    var emojiInputHint: String { get }
    var openEmojiPanel: String { get }
    var builtinGhostCommandName: String { get }
    var builtinGhostCommandDesc: String { get }
    var builtinGhostTwinName: String { get }
    var builtinGhostTwinDesc: String { get }
    var builtinMemoName: String { get }
    var builtinMemoDesc: String { get }
    var builtinTranslateName: String { get }
    var builtinTranslateDesc: String { get }
    var langChinese: String { get }
    var langEnglish: String { get }
    var langJapanese: String { get }
    var langKorean: String { get }
    var langFrench: String { get }
    var langGerman: String { get }
    var langSpanish: String { get }
    var langRussian: String { get }
}

protocol MenuBarStrings {
    var hotkeyPrefix: String { get }
    var openDashboard: String { get }
    var checkUpdate: String { get }
    var accessibilityPerm: String { get }
    var accessibilityPermClick: String { get }
    var micPerm: String { get }
    var micPermClick: String { get }
    var devTools: String { get }
    var overlayTest: String { get }
    var quit: String { get }
}

protocol OverlayStrings {
    var thinking: String { get }
    var listening: String { get }
    var listeningPlaceholder: String { get }
    var badgePolished: String { get }
    var badgeTranslated: String { get }
    var badgeSaved: String { get }
    var defaultSkillName: String { get }
}

protocol AIPolishExamplesStrings {
    var inSentenceInput1: String { get }
    var inSentenceOutput1: String { get }
    var inSentenceInput2: String { get }
    var inSentenceOutput2: String { get }
    var inSentenceInput3: String { get }
    var inSentenceOutput3: String { get }
    var triggerInput1: String { get }
    var triggerOutput1: String { get }
    var triggerInput2: String { get }
    var triggerOutput2: String { get }
    var triggerInput3: String { get }
    var triggerOutput3: String { get }
}

protocol SkillContextStrings {
    var profileHeader: String { get }
    var profileLevel: String { get }
    var profileFullText: String { get }
    var noCalibrationRecords: String { get }
    var customAnswer: String { get }
    var optionPrefix: String { get }
    var noNewCorpus: String { get }
}

protocol MemoSyncStrings {
    // Settings page
    var title: String { get }
    var subtitle: String { get }
    var enableSync: String { get }
    // Adapter names
    var obsidian: String { get }
    var appleNotes: String { get }
    var notion: String { get }
    var bear: String { get }
    // Grouping modes
    var perNote: String { get }
    var perDay: String { get }
    var perWeek: String { get }
    // Config labels
    var groupingMode: String { get }
    var titleTemplate: String { get }
    var titleTemplatePlaceholder: String { get }
    var templateVariables: String { get }
    var templateExample: String { get }
    var vaultPath: String { get }
    var selectVault: String { get }
    var folderName: String { get }
    var databaseId: String { get }
    var defaultTag: String { get }
    var token: String { get }
    // Connection status
    var testConnection: String { get }
    var connected: String { get }
    var disconnected: String { get }
    var testing: String { get }
    // Sync status
    var synced: String { get }
    var syncFailed: String { get }
    var notSynced: String { get }
    var syncSuccess: String { get }
    // Error messages
    var errorPathNotFound: String { get }
    var errorNoPermission: String { get }
    var errorBookmarkExpired: String { get }
    var errorAppleScript: String { get }
    var errorTokenInvalid: String { get }
    var errorDatabaseNotFound: String { get }
    var errorRateLimited: String { get }
    var errorBearNotInstalled: String { get }
    var errorNetwork: String { get }
    var errorUnknown: String { get }
    // Notion setup wizard
    var notionSetupTitle: String { get }
    var notionStep1: String { get }
    var notionStep2: String { get }
    var notionStep3: String { get }
    var notionStep4: String { get }
    var notionStep5: String { get }
    var openNotionPortal: String { get }
}
