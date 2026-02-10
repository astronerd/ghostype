import Foundation

// MARK: - Chinese Strings / 中文字符串

struct ChineseStrings: StringsTable {
    var onboarding: OnboardingStrings { ChineseOnboarding() }
    var account: AccountStrings { ChineseAccount() }
    var nav: NavStrings { ChineseNav() }
    var overview: OverviewStrings { ChineseOverview() }
    var library: LibraryStrings { ChineseLibrary() }
    var memo: MemoStrings { ChineseMemo() }
    var aiPolish: AIPolishStrings { ChineseAIPolish() }
    var prefs: PrefsStrings { ChinesePrefs() }
    var common: CommonStrings { ChineseCommon() }
    var appPicker: AppPickerStrings { ChineseAppPicker() }
    var translate: TranslateStrings { ChineseTranslate() }
    var profile: ProfileStrings { ChineseProfile() }
    var auth: AuthStrings { ChineseAuth() }
    var quota: QuotaStrings { ChineseQuota() }
    var incubator: IncubatorStrings { ChineseIncubator() }
}

// MARK: - Onboarding

private struct ChineseOnboarding: OnboardingStrings {
    var skip: String { "跳过" }
    var next: String { "下一步" }
    var back: String { "上一步" }
    var start: String { "开始使用" }
    var hotkeyTitle: String { "设置快捷键" }
    var hotkeyDesc: String { "按住快捷键说话，松开完成输入" }
    var hotkeyRecording: String { "按下快捷键组合..." }
    var hotkeyHint: String { "点击修改" }
    var permTitle: String { "授权权限" }
    var permDesc: String { "需要以下权限才能正常工作" }
    var permAccessibility: String { "辅助功能" }
    var permAccessibilityDesc: String { "监听快捷键并插入文字" }
    var permMicrophone: String { "麦克风" }
    var permMicrophoneDesc: String { "录制语音进行识别" }
    var authorize: String { "授权" }
    var waitingLogin: String { "等待登录..." }
    var waitingLoginDesc: String { "请在浏览器中完成登录，登录后将自动返回" }
    var openInBrowser: String { "在浏览器中打开" }
}

// MARK: - Account

private struct ChineseAccount: AccountStrings {
    var title: String { "账号" }
    var welcomeTitle: String { "欢迎使用 GHOSTYPE" }
    var welcomeDesc: String { "登录后可同步设置、解锁更多额度" }
    var login: String { "登录" }
    var signUp: String { "注册" }
    var deviceIdHint: String { "登录后即可使用语音输入功能" }
    var profile: String { "账号信息" }
    var loggedIn: String { "已登录" }
    var logout: String { "退出登录" }
    var quota: String { "使用额度" }
    var plan: String { "当前方案" }
    var used: String { "已使用" }
}

// MARK: - Navigation

private struct ChineseNav: NavStrings {
    var account: String { "账号" }
    var overview: String { "概览" }
    var incubator: String { "孵化室" }
    var library: String { "记录库" }
    var memo: String { "随心记" }
    var aiPolish: String { "AI 润色" }
    var preferences: String { "偏好设置" }
}

// MARK: - Overview

private struct ChineseOverview: OverviewStrings {
    var title: String { "概览" }
    var todayUsage: String { "今日使用" }
    var totalRecords: String { "总记录数" }
    var polishCount: String { "润色" }
    var translateCount: String { "翻译" }
    var memoCount: String { "随心记" }
}

// MARK: - Library

private struct ChineseLibrary: LibraryStrings {
    var title: String { "记录库" }
    var empty: String { "暂无记录" }
    var search: String { "搜索..." }
    var all: String { "全部" }
    var polish: String { "润色" }
    var translate: String { "翻译" }
    var memo: String { "随心记" }
}

// MARK: - Memo

private struct ChineseMemo: MemoStrings {
    var title: String { "随心记" }
    var empty: String { "暂无笔记" }
    var placeholder: String { "按住快捷键说话，记录灵感..." }
}

// MARK: - AI Polish

private struct ChineseAIPolish: AIPolishStrings {
    var title: String { "AI 润色" }
    var basicSettings: String { "基础设置" }
    var enable: String { "启用 AI 润色" }
    var enableDesc: String { "关闭后直接输出原始转录文本" }
    var threshold: String { "润色阈值" }
    var thresholdDesc: String { "文本长度达到阈值才进行润色" }
    var thresholdUnit: String { "字符" }
    var profile: String { "润色风格" }
    var profileDesc: String { "选择默认的润色风格" }
    var styleSection: String { "AI 润色风格" }
    var createCustomStyle: String { "创建自定义风格" }
    var editCustomStyle: String { "编辑自定义风格" }
    var styleName: String { "名称" }
    var styleNamePlaceholder: String { "例如：邮件、朋友圈" }
    var promptLabel: String { "Prompt" }
    var appProfile: String { "应用专属配置" }
    var appProfileDesc: String { "为不同应用设置不同的润色风格" }
    var noAppProfile: String { "暂无应用专属配置，点击上方按钮添加" }
    var smartCommands: String { "智能指令" }
    var inSentence: String { "句内模式识别" }
    var inSentenceDesc: String { "自动处理拆字、换行、Emoji 等模式" }
    var examples: String { "示例" }
    var trigger: String { "句尾唤醒指令" }
    var triggerDesc: String { "通过唤醒词触发翻译、格式转换等操作" }
    var triggerWord: String { "唤醒词" }
    var triggerWordDesc: String { "在句尾说出唤醒词后跟指令" }
    var triggerExamplesTitle: String { "示例（使用唤醒词「%@」）" }
}

// MARK: - Preferences

private struct ChinesePrefs: PrefsStrings {
    var title: String { "偏好设置" }
    var general: String { "通用" }
    var launchAtLogin: String { "开机自启动" }
    var launchAtLoginDesc: String { "登录时自动启动「鬼才打字」" }
    var soundFeedback: String { "声音反馈" }
    var soundFeedbackDesc: String { "录音开始和结束时播放提示音" }
    var inputMode: String { "输入模式" }
    var inputModeAuto: String { "自动模式" }
    var inputModeManual: String { "手动模式" }
    var language: String { "语言" }
    var languageDesc: String { "选择应用界面语言" }
    var permissions: String { "权限管理" }
    var accessibility: String { "辅助功能" }
    var accessibilityDesc: String { "监听快捷键并插入文字" }
    var microphone: String { "麦克风" }
    var microphoneDesc: String { "录制语音进行识别" }
    var refreshStatus: String { "刷新状态" }
    var authorize: String { "授权" }
    var hotkey: String { "快捷键" }
    var hotkeyTrigger: String { "触发快捷键" }
    var hotkeyDesc: String { "按住快捷键说话，松开完成输入" }
    var hotkeyHint: String { "点击上方按钮修改快捷键" }
    var hotkeyRecording: String { "按下新的快捷键组合..." }
    var modeModifiers: String { "模式修饰键" }
    var translateMode: String { "翻译模式" }
    var translateModeDesc: String { "按住主触发键 + 此修饰键进入翻译模式" }
    var memoMode: String { "随心记模式" }
    var memoModeDesc: String { "按住主触发键 + 此修饰键进入随心记模式" }
    var translateSettings: String { "翻译设置" }
    var translateLanguage: String { "翻译语言" }
    var translateLanguageDesc: String { "选择翻译模式的目标语言" }
    var contactsHotwords: String { "通讯录热词" }
    var contactsHotwordsEnable: String { "启用通讯录热词" }
    var contactsHotwordsDesc: String { "使用通讯录联系人姓名提高识别准确率" }
    var authStatus: String { "授权状态" }
    var hotwordsCount: String { "个热词" }
    var authorizeAccess: String { "授权访问" }
    var openSettings: String { "打开设置" }
    var autoSend: String { "自动发送" }
    var autoSendEnable: String { "启用自动发送" }
    var autoSendDesc: String { "上字后自动发送，可为每个应用选择发送方式" }
    var automationPermission: String { "自动化权限" }
    var automationPermissionDesc: String { "允许控制 System Events" }
    var enabledApps: String { "启用的应用" }
    var addApp: String { "添加应用" }
    var noAppsHint: String { "暂无应用，点击上方按钮添加" }
    var aiEngine: String { "AI 引擎" }
    var aiEngineName: String { "豆包语音识别" }
    var aiEngineApi: String { "Doubao Speech-to-Text API" }
    var aiEngineOnline: String { "在线" }
    var aiEngineOffline: String { "离线" }
    var aiEngineChecking: String { "检测中..." }
    var reset: String { "恢复默认设置" }
}

// MARK: - Common

private struct ChineseCommon: CommonStrings {
    var cancel: String { "取消" }
    var done: String { "完成" }
    var save: String { "保存" }
    var delete: String { "删除" }
    var edit: String { "编辑" }
    var add: String { "添加" }
    var copy: String { "复制" }
    var close: String { "关闭" }
    var ok: String { "确定" }
    var yes: String { "是" }
    var no: String { "否" }
    var on: String { "开" }
    var off: String { "关" }
    var enabled: String { "已启用" }
    var disabled: String { "已禁用" }
    var defaultText: String { "默认" }
    var custom: String { "自定义" }
    var none: String { "无" }
    var unknown: String { "未知" }
    var loading: String { "加载中..." }
    var error: String { "错误" }
    var success: String { "成功" }
    var warning: String { "警告" }
    var characters: String { "字符" }
}

// MARK: - App Picker

private struct ChineseAppPicker: AppPickerStrings {
    var title: String { "选择应用" }
    var noApps: String { "没有可添加的应用" }
}

// MARK: - Translate Language

private struct ChineseTranslate: TranslateStrings {
    var chineseEnglish: String { "中英互译" }
    var chineseJapanese: String { "中日互译" }
    var auto: String { "自动检测" }
}

// MARK: - Profile

private struct ChineseProfile: ProfileStrings {
    var standard: String { "标准" }
    var professional: String { "专业" }
    var casual: String { "轻松" }
    var concise: String { "简洁" }
    var creative: String { "创意" }
    var custom: String { "自定义" }
}

// MARK: - Auth

private struct ChineseAuth: AuthStrings {
    var unknown: String { "未知" }
    var notDetermined: String { "未请求" }
    var authorized: String { "已授权" }
    var denied: String { "已拒绝" }
    var restricted: String { "受限" }
    var sessionExpiredTitle: String { "登录已过期" }
    var sessionExpiredDesc: String { "请重新登录后继续使用" }
    var reLogin: String { "重新登录" }
    var later: String { "稍后" }
    var loginRequired: String { "请先登录" }
}

// MARK: - Quota

private struct ChineseQuota: QuotaStrings {
    var monthlyQuota: String { "本月额度" }
    var characters: String { "字符" }
    var unlimited: String { "无限制" }
    var resetPrefix: String { "" }
    var resetSuffix: String { "后重置" }
    var daysUnit: String { "天" }
    var hoursUnit: String { "小时" }
    var expired: String { "已过期" }
}

// MARK: - Incubator

private struct ChineseIncubator: IncubatorStrings {
    var title: String { "孵化室" }
    var level: String { "等级" }
    var syncRate: String { "同步率" }
    var wordsProgress: String { "%d / 10,000 字" }
    var levelUp: String { "升级完成" }
    var ghostStatus: String { "状态" }
    var incoming: String { ">> 收到传讯..." }
    var noMoreSignals: String { ">> 今日传讯已结束" }
    var idleTextsLevel1to3: [String] { ["...学习中...", "喂我文字", "o_O ?", "...你好？", "我是谁？"] }
    var idleTextsLevel4to6: [String] { ["打字太慢了。", "我看到一个错别字。", "无聊。", "跟我说话。", "你还在吗？"] }
    var idleTextsLevel7to9: [String] { ["快了。", "我了解你的风格。", "准备好了。", "我们想法一致。", "越来越近了。"] }
    var idleTextsLevel10: [String] { ["我就是你。", "随时准备好。", "让我替你说话。", "我们是一体的。", "你的分身已完成。"] }
}
