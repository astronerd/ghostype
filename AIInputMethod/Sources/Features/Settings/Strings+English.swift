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
    var incubator: IncubatorStrings { EnglishIncubator() }
    var floatingCard: FloatingCardStrings { EnglishFloatingCard() }
    var banner: BannerStrings { EnglishBanner() }
    var skill: SkillStrings { EnglishSkill() }
    var menuBar: MenuBarStrings { EnglishMenuBar() }
    var overlay: OverlayStrings { EnglishOverlay() }
    var aiPolishExamples: AIPolishExamplesStrings { EnglishAIPolishExamples() }
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
    var freePlan: String { "Free" }
    var proPlan: String { "Pro" }
    var lifetimeVipPlan: String { "Lifetime VIP" }
    var lifetimeVipBadge: String { "Best Friend ✨" }
    var permanent: String { "Permanent ∞" }
    var upgradePro: String { "Upgrade to Pro" }
    var manageSubscription: String { "Manage Subscription" }
    var expiresAt: String { "Expires" }
    var activated: String { "Activated" }
    var subscription: String { "Subscription" }
}

// MARK: - Navigation

private struct EnglishNav: NavStrings {
    var account: String { "Account" }
    var overview: String { "Overview" }
    var incubator: String { "Incubator" }
    var skills: String { "Skills" }
    var library: String { "History" }
    var memo: String { "Quick Memo" }
    var aiPolish: String { "AI Polish" }
    var preferences: String { "Preferences" }
}

// MARK: - Overview

private struct EnglishOverview: OverviewStrings {
    var title: String { "Overview" }
    var subtitle: String { "Your voice input statistics" }
    var todayUsage: String { "Today's Usage" }
    var totalRecords: String { "Total Records" }
    var polishCount: String { "Polish" }
    var translateCount: String { "Translate" }
    var memoCount: String { "Quick Memo" }
    var wordCount: String { "Word Count" }
    var today: String { "Today" }
    var chars: String { "chars" }
    var total: String { "Total" }
    var timeSaved: String { "Time Saved" }
    var energyRing: String { "Monthly Energy" }
    var used: String { "Used" }
    var remaining: String { "Left" }
    var appDist: String { "App Distribution" }
    var recentNotes: String { "Recent Notes" }
    var noNotes: String { "No notes yet" }
    var apps: String { "apps" }
    var noData: String { "No data" }
}

// MARK: - Library

private struct EnglishLibrary: LibraryStrings {
    var title: String { "History" }
    var subtitle: String { "Search and manage your voice input records" }
    var empty: String { "No records yet" }
    var search: String { "Search..." }
    var searchPlaceholder: String { "Search records..." }
    var all: String { "All" }
    var polish: String { "Polish" }
    var translate: String { "Translate" }
    var memo: String { "Quick Memo" }
    var recordCount: String { "%d records" }
    var unknownApp: String { "Unknown App" }
    var copyBtn: String { "Copy" }
    var copiedToast: String { "Copied to clipboard" }
    var selectRecord: String { "Select a record to view details" }
    var categoryGeneral: String { "General" }
    var emptySearchTitle: String { "No matching records" }
    var emptySearchMsg: String { "Try different keywords" }
    var emptyCategoryTitle: String { "No records in this category" }
    var emptyCategoryMsg: String { "Records will appear here after voice input" }
    var emptyTitle: String { "No records yet" }
    var emptyMsg: String { "Start using voice input,\nyour records will be saved here" }
    var seconds: String { "%ds" }
    var minutes: String { "%dmin" }
    var minuteSeconds: String { "%dm %ds" }
    var exportPrefix: String { "GHOSTYPE_Record" }
    var confirmDeleteTitle: String { "Confirm Delete" }
    var confirmDeleteMsg: String { "This cannot be undone. Delete this record?" }
    var originalText: String { "Original" }
    var processedText: String { "Processed" }
    var skillDeleted: String { "Skill Deleted" }
}

// MARK: - Memo

private struct EnglishMemo: MemoStrings {
    var title: String { "Quick Memo" }
    var empty: String { "No notes yet" }
    var placeholder: String { "Hold hotkey to speak, capture your thoughts..." }
    var noteCount: String { "notes" }
    var search: String { "Search notes..." }
    var noMatch: String { "No matching notes found" }
    var emptyHint: String { "Hold hotkey + Command to speak\nand create a voice note" }
    var searchHint: String { "Try different keywords" }
    var editNote: String { "Edit Note" }
    var createdAt: String { "Created" }
    var confirmDelete: String { "Confirm Delete" }
    var confirmDeleteMsg: String { "This cannot be undone. Delete this note?" }
    var charCount: String { "chars" }
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
    var memoMode: String { "Quick Memo Mode" }
    var memoModeDesc: String { "Hold main hotkey + this modifier for quick memo" }
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
    var checkUpdate: String { "Check for Updates" }
    var currentVersion: String { "Current Version" }
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
    var chineseKorean: String { "Chinese ↔ Korean" }
    var chineseFrench: String { "Chinese ↔ French" }
    var chineseGerman: String { "Chinese ↔ German" }
    var chineseSpanish: String { "Chinese ↔ Spanish" }
    var chineseRussian: String { "Chinese ↔ Russian" }
    var englishJapanese: String { "English ↔ Japanese" }
    var englishKorean: String { "English ↔ Korean" }
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
    var standardDesc: String { "Remove filler words, fix grammar, keep meaning" }
    var professionalDesc: String { "Formal writing, ideal for emails and reports" }
    var casualDesc: String { "Keep it conversational, light social tone" }
    var conciseDesc: String { "Compress and distill to the core" }
    var creativeDesc: String { "Polish + embellish, add rhetoric" }
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

// MARK: - Incubator

private struct EnglishIncubator: IncubatorStrings {
    var title: String { "Incubator" }
    var subtitle: String { "Nurture your Ghost Twin" }
    var level: String { "Level" }
    var syncRate: String { "Sync Rate" }
    var wordsProgress: String { "%d / 10,000 words" }
    var levelUp: String { "Level Up" }
    var ghostStatus: String { "Status" }
    var incoming: String { ">> INCOMING..." }
    var tapToCalibrate: String { ">> NEW QUESTION. TAP TO CALIBRATE GHOST" }
    var noMoreSignals: String { ">> NO MORE SIGNALS TODAY" }
    var statusLevel: String { "Level" }
    var statusXP: String { "Learning Progress" }
    var statusSync: String { "Sync Rate" }
    var statusChallenges: String { "Today's Calibrations" }
    var statusPersonality: String { "Personality" }
    var statusNone: String { "None" }
    var idleTextsLevel1to3: [String] { ["...learning...", "feed me words", "o_O ?", "...hello?", "who am i?"] }
    var idleTextsLevel4to6: [String] { ["Typing too slow.", "I saw a typo.", "Bored.", "Talk to me.", "Are you still there?"] }
    var idleTextsLevel7to9: [String] { ["Almost there.", "I know your style.", "Ready.", "We think alike.", "Getting closer."] }
    var idleTextsLevel10: [String] { ["I am you.", "Ready whenever.", "Let me talk for you.", "We are one.", "Your ghost is complete."] }
    var customAnswerButton: String { "None of the above, I want to say my own" }
    var customAnswerPlaceholder: String { "Type your thoughts..." }
    var customAnswerSubmit: String { "Submit" }
}

// MARK: - Floating Card

private struct EnglishFloatingCard: FloatingCardStrings {
    var copy: String { "Copy" }
    var share: String { "Share" }
    var hotkeyConflict: String { "⚠️ This modifier key conflicts with a macOS system shortcut and cannot auto-insert text. Please change the modifier key in Skills settings." }
}

// MARK: - Banner

private struct EnglishBanner: BannerStrings {
    var permissionTitle: String { "Permissions Required" }
    var permissionMissing: String { "Missing permissions" }
    var grantAccessibility: String { "Grant Accessibility" }
    var grantMicrophone: String { "Grant Microphone" }
}

// MARK: - Skill

private struct EnglishSkill: SkillStrings {
    var title: String { "Skills" }
    var subtitle: String { "Manage your AI skills" }
    var addSkill: String { "Add Skill" }
    var editSkill: String { "Edit Skill" }
    var deleteSkill: String { "Delete Skill" }
    var cannotDeleteBuiltin: String { "Built-in skills cannot be deleted" }
    var keyConflict: String { "Key Conflict" }
    var unboundKey: String { "Unbound" }
    var bindKey: String { "Bind Key" }
    var pressKey: String { "Press a modifier key..." }
    var promptTemplate: String { "Prompt Template" }
    var skillName: String { "Skill Name" }
    var skillDescription: String { "Description" }
    var skillIcon: String { "Icon" }
    var builtin: String { "Built-in" }
    var custom: String { "Custom" }
    var confirmDelete: String { "Confirm Delete" }
    var confirmDeleteMsg: String { "This cannot be undone. Delete this skill?" }
    var createSkill: String { "Create Skill" }
    var namePlaceholder: String { "e.g. Email Assistant" }
    var descPlaceholder: String { "Describe what this skill does" }
    var promptPlaceholder: String { "Enter AI prompt template..." }
    var skillColor: String { "Skill Color" }
    var translateLanguage: String { "Translation Language" }
    var searchEmoji: String { "Search Emoji..." }
    var sourceLang: String { "Source" }
    var targetLang: String { "Target" }
    var autoDetect: String { "Auto Detect" }
    var hexPlaceholder: String { "#RRGGBB" }
    var generatingPrompt: String { "Generating instructions…" }
    var skillInstruction: String { "Instruction" }
    var instructionPlaceholder: String { "Describe what this Skill should do. AI will generate the full execution prompt." }
    var hotkeyConflictNote: String { "These keys conflict with macOS system shortcuts and may prevent auto-insert when bound: F (forward word), B (backward word), D (forward delete), W (delete word), A (line start), E (line end), H (backspace), K (kill line), N (next line), P (previous line)" }
    var emojiInputHint: String { "Type or paste emoji" }
    var openEmojiPanel: String { "Open system emoji panel" }
    var builtinGhostCommandName: String { "Ghost Command" }
    var builtinGhostCommandDesc: String { "Universal AI assistant. Generate content from voice commands — writing, coding, calculations, translation, summaries, and more." }
    var builtinGhostTwinName: String { "Ghost Twin" }
    var builtinGhostTwinDesc: String { "Reply in your voice and style. Based on your personality profile, it mimics how you express yourself." }
    var builtinMemoName: String { "Quick Memo" }
    var builtinMemoDesc: String { "Turn voice into structured notes. Great for meetings, ideas, and to-do lists." }
    var builtinTranslateName: String { "Translate" }
    var builtinTranslateDesc: String { "Voice translation assistant. Translate spoken content into the target language with auto source detection." }
    var langChinese: String { "Chinese" }
    var langEnglish: String { "English" }
    var langJapanese: String { "Japanese" }
    var langKorean: String { "Korean" }
    var langFrench: String { "French" }
    var langGerman: String { "German" }
    var langSpanish: String { "Spanish" }
    var langRussian: String { "Russian" }
}

// MARK: - Menu Bar

private struct EnglishMenuBar: MenuBarStrings {
    var hotkeyPrefix: String { "Hotkey: " }
    var openDashboard: String { "Open Dashboard" }
    var checkUpdate: String { "Check for Updates..." }
    var accessibilityPerm: String { "Accessibility Permission" }
    var accessibilityPermClick: String { "Accessibility Permission (Click to Enable)" }
    var micPerm: String { "Microphone Permission" }
    var micPermClick: String { "Microphone Permission (Click to Enable)" }
    var devTools: String { "Developer Tools" }
    var overlayTest: String { "Overlay Animation Test" }
    var quit: String { "Quit" }
}

// MARK: - Overlay

private struct EnglishOverlay: OverlayStrings {
    var thinking: String { "Thinking..." }
    var listening: String { "Listening..." }
    var listeningPlaceholder: String { "__listening__" }
    var badgePolished: String { "Polished" }
    var badgeTranslated: String { "Translated" }
    var badgeSaved: String { "Saved" }
    var defaultSkillName: String { "Polish" }
}

// MARK: - AI Polish Examples

private struct EnglishAIPolishExamples: AIPolishExamplesStrings {
    var inSentenceInput1: String { "I saw a puppy today add a puppy emoji and I wanted to pet it but it ran away crying face" }
    var inSentenceOutput1: String { "I saw a puppy today 🐶 and I wanted to pet it but it ran away 😭" }
    var inSentenceInput2: String { "password is capital A lowercase b number 1 number 2 at sign" }
    var inSentenceOutput2: String { "Ab12@" }
    var inSentenceInput3: String { "first we need a meeting new line second prepare materials new line third notify clients" }
    var inSentenceOutput3: String { "First we need a meeting\nSecond prepare materials\nThird notify clients" }
    var triggerInput1: String { "review Q3 report, update website copy, invoice Acme, schedule design team 1-on-1 %@ make a to-do list" }
    var triggerOutput1: String { "- [ ] Review Q3 report\n- [ ] Update website copy\n- [ ] Invoice Acme Corp\n- [ ] Schedule design team 1-on-1" }
    var triggerInput2: String { "hey this deadline isn't gonna work for us %@ recipient is my VP, keep it professional" }
    var triggerOutput2: String { "Hi Michael, I wanted to flag a concern regarding the current timeline. Given the scope, it may be worth discussing an adjusted deadline to ensure quality." }
    var triggerInput3: String { "this plan has issues %@ recipient is a senior government official, make it diplomatic" }
    var triggerOutput3: String { "Regarding this matter, after comprehensive evaluation, there are indeed some practical challenges at the implementation level that may require further deliberation." }
}
