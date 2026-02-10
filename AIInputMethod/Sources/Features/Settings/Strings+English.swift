import Foundation

// MARK: - English Strings / 英文字符串

struct EnglishStrings: StringsTable {
    var onboarding: OnboardingStrings { EnglishOnboarding() }
    var account: AccountStrings { EnglishAccount() }
    var nav: NavStrings { EnglishNav() }
    var overview: OverviewStrings { EnglishOverview() }
    var library: LibraryStrings { EnglishLibrary() }
    var memo: MemoStrings { EnglishMemo() }
    var aiPolish: AIPolishStrings { EnglishAIPolish() }
    var prefs: PrefsStrings { EnglishPrefs() }
    var common: CommonStrings { EnglishCommon() }
    var appPicker: AppPickerStrings { EnglishAppPicker() }
    var translate: TranslateStrings { EnglishTranslate() }
    var profile: ProfileStrings { EnglishProfile() }
    var auth: AuthStrings { EnglishAuth() }
    var quota: QuotaStrings { EnglishQuota() }
}

// MARK: - Onboarding

private struct EnglishOnboarding: OnboardingStrings {
    var skip: String { "Skip" }
    var next: String { "Next" }
    var back: String { "Back" }
    var start: String { "Get Started" }
    var hotkeyTitle: String { "Set Hotkey" }
    var hotkeyDesc: String { "Hold hotkey to speak, release to finish" }
    var hotkeyRecording: String { "Press hotkey combination..." }
    var hotkeyHint: String { "Click to change" }
    var permTitle: String { "Grant Permissions" }
    var permDesc: String { "These permissions are required to work properly" }
    var permAccessibility: String { "Accessibility" }
    var permAccessibilityDesc: String { "Listen for hotkeys and insert text" }
    var permMicrophone: String { "Microphone" }
    var permMicrophoneDesc: String { "Record voice for recognition" }
    var authorize: String { "Authorize" }
    var waitingLogin: String { "Waiting for sign in..." }
    var waitingLoginDesc: String { "Complete sign in in your browser, it will return automatically" }
    var openInBrowser: String { "Open in Browser" }
}

// MARK: - Account

private struct EnglishAccount: AccountStrings {
    var title: String { "Account" }
    var welcomeTitle: String { "Welcome to GHOSTYPE" }
    var welcomeDesc: String { "Sign in to sync settings and unlock more quota" }
    var login: String { "Sign In" }
    var signUp: String { "Sign Up" }
    var deviceIdHint: String { "Sign in to use voice input features" }
    var profile: String { "Profile" }
    var loggedIn: String { "Signed In" }
    var logout: String { "Sign Out" }
    var quota: String { "Usage Quota" }
    var plan: String { "Current Plan" }
    var used: String { "Used" }
}

// MARK: - Navigation

private struct EnglishNav: NavStrings {
    var account: String { "Account" }
    var overview: String { "Overview" }
    var library: String { "Library" }
    var memo: String { "Memo" }
    var aiPolish: String { "AI Polish" }
    var preferences: String { "Preferences" }
}

// MARK: - Overview

private struct EnglishOverview: OverviewStrings {
    var title: String { "Overview" }
    var todayUsage: String { "Today's Usage" }
    var totalRecords: String { "Total Records" }
    var polishCount: String { "Polish" }
    var translateCount: String { "Translate" }
    var memoCount: String { "Memo" }
}

// MARK: - Library

private struct EnglishLibrary: LibraryStrings {
    var title: String { "Library" }
    var empty: String { "No records yet" }
    var search: String { "Search..." }
    var all: String { "All" }
    var polish: String { "Polish" }
    var translate: String { "Translate" }
    var memo: String { "Memo" }
}

// MARK: - Memo

private struct EnglishMemo: MemoStrings {
    var title: String { "Memo" }
    var empty: String { "No notes yet" }
    var placeholder: String { "Hold hotkey to speak, capture your thoughts..." }
}

// MARK: - AI Polish

private struct EnglishAIPolish: AIPolishStrings {
    var title: String { "AI Polish" }
    var basicSettings: String { "Basic Settings" }
    var enable: String { "Enable AI Polish" }
    var enableDesc: String { "When disabled, outputs raw transcription" }
    var threshold: String { "Polish Threshold" }
    var thresholdDesc: String { "Minimum text length to trigger polishing" }
    var thresholdUnit: String { "chars" }
    var profile: String { "Polish Style" }
    var profileDesc: String { "Select default polish style" }
    var styleSection: String { "AI Polish Style" }
    var createCustomStyle: String { "Create Custom Style" }
    var editCustomStyle: String { "Edit Custom Style" }
    var styleName: String { "Name" }
    var styleNamePlaceholder: String { "e.g. Email, Social Media" }
    var promptLabel: String { "Prompt" }
    var appProfile: String { "Per-App Configuration" }
    var appProfileDesc: String { "Set different polish styles for different apps" }
    var noAppProfile: String { "No per-app config yet, click button above to add" }
    var smartCommands: String { "Smart Commands" }
    var inSentence: String { "In-Sentence Patterns" }
    var inSentenceDesc: String { "Auto-handle spelling, line breaks, Emoji, etc." }
    var examples: String { "Examples" }
    var trigger: String { "Trigger Commands" }
    var triggerDesc: String { "Use trigger word for translation, formatting, etc." }
    var triggerWord: String { "Trigger Word" }
    var triggerWordDesc: String { "Say trigger word at end followed by command" }
    var triggerExamplesTitle: String { "Examples (using trigger word \"%@\")" }
}

// MARK: - Preferences

private struct EnglishPrefs: PrefsStrings {
    var title: String { "Preferences" }
    var general: String { "General" }
    var launchAtLogin: String { "Launch at Login" }
    var launchAtLoginDesc: String { "Start GHOSTYPE when you log in" }
    var soundFeedback: String { "Sound Feedback" }
    var soundFeedbackDesc: String { "Play sounds when recording starts/stops" }
    var inputMode: String { "Input Mode" }
    var inputModeAuto: String { "Auto Mode" }
    var inputModeManual: String { "Manual Mode" }
    var language: String { "Language" }
    var languageDesc: String { "Select app interface language" }
    var permissions: String { "Permissions" }
    var accessibility: String { "Accessibility" }
    var accessibilityDesc: String { "Listen for hotkeys and insert text" }
    var microphone: String { "Microphone" }
    var microphoneDesc: String { "Record voice for recognition" }
    var refreshStatus: String { "Refresh Status" }
    var authorize: String { "Authorize" }
    var hotkey: String { "Hotkey" }
    var hotkeyTrigger: String { "Trigger Hotkey" }
    var hotkeyDesc: String { "Hold hotkey to speak, release to finish" }
    var hotkeyHint: String { "Click button above to change hotkey" }
    var hotkeyRecording: String { "Press new hotkey combination..." }
    var modeModifiers: String { "Mode Modifiers" }
    var translateMode: String { "Translate Mode" }
    var translateModeDesc: String { "Hold main hotkey + this modifier for translate" }
    var memoMode: String { "Memo Mode" }
    var memoModeDesc: String { "Hold main hotkey + this modifier for memo" }
    var translateSettings: String { "Translation Settings" }
    var translateLanguage: String { "Translation Language" }
    var translateLanguageDesc: String { "Select target language for translation" }
    var contactsHotwords: String { "Contacts Hotwords" }
    var contactsHotwordsEnable: String { "Enable Contacts Hotwords" }
    var contactsHotwordsDesc: String { "Use contact names to improve recognition" }
    var authStatus: String { "Authorization Status" }
    var hotwordsCount: String { "hotwords" }
    var authorizeAccess: String { "Authorize Access" }
    var openSettings: String { "Open Settings" }
    var autoSend: String { "Auto Send" }
    var autoSendEnable: String { "Enable Auto Send" }
    var autoSendDesc: String { "Auto send after text input, choose method per app" }
    var automationPermission: String { "Automation Permission" }
    var automationPermissionDesc: String { "Allow control of System Events" }
    var enabledApps: String { "Enabled Apps" }
    var addApp: String { "Add App" }
    var noAppsHint: String { "No apps yet, click button above to add" }
    var aiEngine: String { "AI Engine" }
    var aiEngineName: String { "Doubao Speech Recognition" }
    var aiEngineApi: String { "Doubao Speech-to-Text API" }
    var aiEngineOnline: String { "Online" }
    var aiEngineOffline: String { "Offline" }
    var aiEngineChecking: String { "Checking..." }
    var reset: String { "Reset to Defaults" }
}

// MARK: - Common

private struct EnglishCommon: CommonStrings {
    var cancel: String { "Cancel" }
    var done: String { "Done" }
    var save: String { "Save" }
    var delete: String { "Delete" }
    var edit: String { "Edit" }
    var add: String { "Add" }
    var copy: String { "Copy" }
    var close: String { "Close" }
    var ok: String { "OK" }
    var yes: String { "Yes" }
    var no: String { "No" }
    var on: String { "On" }
    var off: String { "Off" }
    var enabled: String { "Enabled" }
    var disabled: String { "Disabled" }
    var defaultText: String { "Default" }
    var custom: String { "Custom" }
    var none: String { "None" }
    var unknown: String { "Unknown" }
    var loading: String { "Loading..." }
    var error: String { "Error" }
    var success: String { "Success" }
    var warning: String { "Warning" }
    var characters: String { "characters" }
}

// MARK: - App Picker

private struct EnglishAppPicker: AppPickerStrings {
    var title: String { "Select App" }
    var noApps: String { "No apps available to add" }
}

// MARK: - Translate Language

private struct EnglishTranslate: TranslateStrings {
    var chineseEnglish: String { "Chinese ↔ English" }
    var chineseJapanese: String { "Chinese ↔ Japanese" }
    var auto: String { "Auto Detect" }
}

// MARK: - Profile

private struct EnglishProfile: ProfileStrings {
    var standard: String { "Standard" }
    var professional: String { "Professional" }
    var casual: String { "Casual" }
    var concise: String { "Concise" }
    var creative: String { "Creative" }
    var custom: String { "Custom" }
}

// MARK: - Auth

private struct EnglishAuth: AuthStrings {
    var unknown: String { "Unknown" }
    var notDetermined: String { "Not Requested" }
    var authorized: String { "Authorized" }
    var denied: String { "Denied" }
    var restricted: String { "Restricted" }
    var sessionExpiredTitle: String { "Session Expired" }
    var sessionExpiredDesc: String { "Please sign in again to continue" }
    var reLogin: String { "Sign In Again" }
    var later: String { "Later" }
    var loginRequired: String { "Please Sign In" }
}

// MARK: - Quota

private struct EnglishQuota: QuotaStrings {
    var monthlyQuota: String { "Monthly Quota" }
    var characters: String { "characters" }
    var unlimited: String { "Unlimited" }
    var resetPrefix: String { "Resets in " }
    var resetSuffix: String { "" }
    var daysUnit: String { " days" }
    var hoursUnit: String { " hours" }
    var expired: String { "Expired" }
}
