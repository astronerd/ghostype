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
    var floatingCard: FloatingCardStrings { ChineseFloatingCard() }
    var banner: BannerStrings { ChineseBanner() }
    var skill: SkillStrings { ChineseSkill() }
    var menuBar: MenuBarStrings { ChineseMenuBar() }
    var overlay: OverlayStrings { ChineseOverlay() }
    var aiPolishExamples: AIPolishExamplesStrings { ChineseAIPolishExamples() }
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
    var freePlan: String { "免费版" }
    var proPlan: String { "Pro" }
    var lifetimeVipPlan: String { "挚友终身 VIP" }
    var lifetimeVipBadge: String { "挚友 ✨" }
    var permanent: String { "永久 ∞" }
    var upgradePro: String { "升级 Pro" }
    var manageSubscription: String { "管理订阅" }
    var expiresAt: String { "到期" }
    var activated: String { "已激活" }
    var subscription: String { "订阅信息" }
}

// MARK: - Navigation

private struct ChineseNav: NavStrings {
    var account: String { "账号" }
    var overview: String { "概览" }
    var incubator: String { "孵化室" }
    var skills: String { "技能" }
    var library: String { "输入历史" }
    var memo: String { "快速笔记" }
    var aiPolish: String { "AI 润色" }
    var preferences: String { "偏好设置" }
}

// MARK: - Overview

private struct ChineseOverview: OverviewStrings {
    var title: String { "概览" }
    var subtitle: String { "查看您的语音输入统计数据" }
    var todayUsage: String { "今日使用" }
    var totalRecords: String { "总记录数" }
    var polishCount: String { "润色" }
    var translateCount: String { "翻译" }
    var memoCount: String { "快速笔记" }
    var wordCount: String { "输入字数统计" }
    var today: String { "今日" }
    var chars: String { "字" }
    var total: String { "累积" }
    var timeSaved: String { "节省时间" }
    var energyRing: String { "本月能量环" }
    var used: String { "已用" }
    var remaining: String { "剩余" }
    var appDist: String { "应用分布" }
    var recentNotes: String { "最近笔记" }
    var noNotes: String { "暂无笔记" }
    var apps: String { "应用" }
    var noData: String { "暂无数据" }
}

// MARK: - Library

private struct ChineseLibrary: LibraryStrings {
    var title: String { "输入历史" }
    var subtitle: String { "搜索和管理您的语音输入记录" }
    var empty: String { "暂无记录" }
    var search: String { "搜索..." }
    var searchPlaceholder: String { "搜索记录内容..." }
    var all: String { "全部" }
    var polish: String { "润色" }
    var translate: String { "翻译" }
    var memo: String { "快速笔记" }
    var recordCount: String { "%d 条记录" }
    var unknownApp: String { "未知应用" }
    var copyBtn: String { "复制" }
    var copiedToast: String { "已复制到剪贴板" }
    var selectRecord: String { "选择一条记录查看详情" }
    var categoryGeneral: String { "通用" }
    var emptySearchTitle: String { "未找到匹配的记录" }
    var emptySearchMsg: String { "尝试使用其他关键词搜索" }
    var emptyCategoryTitle: String { "该分类暂无记录" }
    var emptyCategoryMsg: String { "使用语音输入后，记录将显示在这里" }
    var emptyTitle: String { "暂无记录" }
    var emptyMsg: String { "开始使用语音输入，\n您的记录将自动保存在这里" }
    var seconds: String { "%d秒" }
    var minutes: String { "%d分钟" }
    var minuteSeconds: String { "%d分%d秒" }
    var exportPrefix: String { "GHOSTYPE_记录" }
    var confirmDeleteTitle: String { "确认删除" }
    var confirmDeleteMsg: String { "删除后无法恢复，确定要删除这条记录吗？" }
    var originalText: String { "原文" }
    var processedText: String { "处理结果" }
    var skillDeleted: String { "技能已删除" }
}

// MARK: - Memo

private struct ChineseMemo: MemoStrings {
    var title: String { "快速笔记" }
    var empty: String { "暂无笔记" }
    var placeholder: String { "按住快捷键说话，记录灵感..." }
    var noteCount: String { "条笔记" }
    var search: String { "搜索笔记..." }
    var noMatch: String { "未找到匹配的笔记" }
    var emptyHint: String { "按住快捷键 + Command 键说话\n即可创建语音便签" }
    var searchHint: String { "尝试使用其他关键词搜索" }
    var editNote: String { "编辑便签" }
    var createdAt: String { "创建于" }
    var confirmDelete: String { "确认删除" }
    var confirmDeleteMsg: String { "删除后无法恢复，确定要删除这条笔记吗？" }
    var charCount: String { "字" }
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
    var memoMode: String { "快速笔记模式" }
    var memoModeDesc: String { "按住主触发键 + 此修饰键进入快速笔记模式" }
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
    var checkUpdate: String { "检查更新" }
    var currentVersion: String { "当前版本" }
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
    var chineseKorean: String { "中韩互译" }
    var chineseFrench: String { "中法互译" }
    var chineseGerman: String { "中德互译" }
    var chineseSpanish: String { "中西互译" }
    var chineseRussian: String { "中俄互译" }
    var englishJapanese: String { "英日互译" }
    var englishKorean: String { "英韩互译" }
    var auto: String { "自动检测" }
}

// MARK: - Profile

private struct ChineseProfile: ProfileStrings {
    var standard: String { "默认" }
    var professional: String { "专业" }
    var casual: String { "活泼" }
    var concise: String { "简洁" }
    var creative: String { "创意" }
    var custom: String { "自定义" }
    var standardDesc: String { "去口语化、修语法、保原意" }
    var professionalDesc: String { "正式书面语，适合邮件、报告" }
    var casualDesc: String { "保留口语感，轻松社交风格" }
    var conciseDesc: String { "精简压缩，提炼核心" }
    var creativeDesc: String { "润色+美化，增加修辞" }
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
    var subtitle: String { "培养你的 Ghost Twin" }
    var level: String { "等级" }
    var syncRate: String { "同步率" }
    var wordsProgress: String { "%d / 10,000 字" }
    var levelUp: String { "升级完成" }
    var ghostStatus: String { "状态" }
    var incoming: String { ">> 收到传讯..." }
    var tapToCalibrate: String { ">> 新问题出现，点击此处校准 Ghost" }
    var noMoreSignals: String { ">> 今日传讯已结束" }
    var statusLevel: String { "等级" }
    var statusXP: String { "学习进度" }
    var statusSync: String { "同步率" }
    var statusChallenges: String { "今日校准" }
    var statusPersonality: String { "人格特征" }
    var statusNone: String { "暂无" }
    var idleTextsLevel1to3: [String] { ["...学习中...", "喂我文字", "o_O ?", "...你好？", "我是谁？"] }
    var idleTextsLevel4to6: [String] { ["打字太慢了。", "我看到一个错别字。", "无聊。", "跟我说话。", "你还在吗？"] }
    var idleTextsLevel7to9: [String] { ["快了。", "我了解你的风格。", "准备好了。", "我们想法一致。", "越来越近了。"] }
    var idleTextsLevel10: [String] { ["我就是你。", "随时准备好。", "让我替你说话。", "我们是一体的。", "你的分身已完成。"] }
}

// MARK: - Floating Card

private struct ChineseFloatingCard: FloatingCardStrings {
    var copy: String { "复制" }
    var share: String { "分享" }
    var hotkeyConflict: String { "⚠️ 当前修饰键与 macOS 系统快捷键冲突，无法自动上屏。请在「技能」页面更换其他修饰键。" }
}

// MARK: - Banner

private struct ChineseBanner: BannerStrings {
    var permissionTitle: String { "权限需要更新" }
    var permissionMissing: String { "缺少权限" }
    var grantAccessibility: String { "授权辅助功能" }
    var grantMicrophone: String { "授权麦克风" }
}

// MARK: - Skill

private struct ChineseSkill: SkillStrings {
    var title: String { "技能" }
    var subtitle: String { "管理你的 AI 技能" }
    var addSkill: String { "添加技能" }
    var editSkill: String { "编辑技能" }
    var deleteSkill: String { "删除技能" }
    var cannotDeleteBuiltin: String { "内置技能不可删除" }
    var keyConflict: String { "按键冲突" }
    var unboundKey: String { "未绑定" }
    var bindKey: String { "绑定按键" }
    var pressKey: String { "按下修饰键..." }
    var promptTemplate: String { "提示词模板" }
    var skillName: String { "技能名称" }
    var skillDescription: String { "技能描述" }
    var skillIcon: String { "图标" }
    var builtin: String { "内置" }
    var custom: String { "自定义" }
    var confirmDelete: String { "确认删除" }
    var confirmDeleteMsg: String { "删除后无法恢复，确定要删除这个技能吗？" }
    var createSkill: String { "创建技能" }
    var namePlaceholder: String { "例如：邮件助手" }
    var descPlaceholder: String { "描述这个技能的功能" }
    var promptPlaceholder: String { "输入 AI 提示词模板..." }
    var skillColor: String { "技能颜色" }
    var translateLanguage: String { "翻译语言" }
    var searchEmoji: String { "搜索 Emoji..." }
    var sourceLang: String { "源语言" }
    var targetLang: String { "目标语言" }
    var autoDetect: String { "自动检测" }
    var hexPlaceholder: String { "#RRGGBB" }
    var generatingPrompt: String { "正在生成指令…" }
    var skillInstruction: String { "指令" }
    var instructionPlaceholder: String { "描述这个 Skill 要做什么，AI 会自动生成完整的执行指令" }
    var hotkeyConflictNote: String { "以下按键与 macOS 系统快捷键冲突，绑定后可能无法自动上屏：F（前进一词）、B（后退一词）、D（向前删除）、W（删除前一词）、A（行首）、E（行尾）、H（退格）、K（删除至行尾）、N（下一行）、P（上一行）" }
    var emojiInputHint: String { "输入或粘贴 emoji" }
    var openEmojiPanel: String { "打开系统 emoji 面板" }
    var builtinGhostCommandName: String { "Ghost Command" }
    var builtinGhostCommandDesc: String { "万能 AI 助手，根据语音指令直接生成内容。适用于写作、编程、计算、翻译、总结等任何文本生成任务。" }
    var builtinGhostTwinName: String { "Ghost Twin" }
    var builtinGhostTwinDesc: String { "以你的口吻和语言习惯生成回复。基于你的人格档案，模仿你的表达风格。" }
    var builtinMemoName: String { "快速笔记" }
    var builtinMemoDesc: String { "将语音内容整理为结构化笔记并保存。适用于会议记录、灵感捕捉、待办事项等场景。" }
    var builtinTranslateName: String { "翻译" }
    var builtinTranslateDesc: String { "语音翻译助手，将语音内容翻译为目标语言。支持自动检测源语言。" }
    var langChinese: String { "中文" }
    var langEnglish: String { "英文" }
    var langJapanese: String { "日文" }
    var langKorean: String { "韩文" }
    var langFrench: String { "法文" }
    var langGerman: String { "德文" }
    var langSpanish: String { "西班牙文" }
    var langRussian: String { "俄文" }
}

// MARK: - Menu Bar

private struct ChineseMenuBar: MenuBarStrings {
    var hotkeyPrefix: String { "快捷键: " }
    var openDashboard: String { "打开 Dashboard" }
    var checkUpdate: String { "检查更新..." }
    var accessibilityPerm: String { "辅助功能权限" }
    var accessibilityPermClick: String { "辅助功能权限 (点击开启)" }
    var micPerm: String { "麦克风权限" }
    var micPermClick: String { "麦克风权限 (点击开启)" }
    var devTools: String { "开发者工具" }
    var overlayTest: String { "Overlay 动画测试" }
    var quit: String { "退出" }
}

// MARK: - Overlay

private struct ChineseOverlay: OverlayStrings {
    var thinking: String { "思考中…" }
    var listening: String { "正在聆听…" }
    var listeningPlaceholder: String { "__listening__" }
    var badgePolished: String { "已润色" }
    var badgeTranslated: String { "已翻译" }
    var badgeSaved: String { "已保存" }
    var defaultSkillName: String { "润色" }
}

// MARK: - AI Polish Examples

private struct ChineseAIPolishExamples: AIPolishExamplesStrings {
    var inSentenceInput1: String { "我今天出门看见一个小狗 加个小狗的emoji 然后我想摸摸它但是它跑了 哭脸表情" }
    var inSentenceOutput1: String { "我今天出门看见一个小狗🐶然后我想摸摸它但是它跑了😭" }
    var inSentenceInput2: String { "密码是 大写A 小写b 数字1 数字2 at符号" }
    var inSentenceOutput2: String { "Ab12@" }
    var inSentenceInput3: String { "第一点我们要开会 换行 第二点准备材料 换行 第三点通知客户" }
    var inSentenceOutput3: String { "第一点我们要开会\n第二点准备材料\n第三点通知客户" }
    var triggerInput1: String { "审核Q3报告、更新官网文案、给Acme发票、约设计团队一对一 %@ 做成待办清单" }
    var triggerOutput1: String { "- [ ] 审核 Q3 报告\n- [ ] 更新官网文案\n- [ ] 给 Acme Corp 发送发票\n- [ ] 约设计团队一对一会议" }
    var triggerInput2: String { "hey this deadline isn't gonna work for us %@ recipient is my VP, keep it professional" }
    var triggerOutput2: String { "Hi Michael, I wanted to flag a concern regarding the current timeline. Given the scope, it may be worth discussing an adjusted deadline to ensure quality." }
    var triggerInput3: String { "张处这个不太行 %@ 对方是个体制内处长给我改改" }
    var triggerOutput3: String { "张处，关于此事，经综合评估，实施层面确实存在一些客观困难，可能需要从长计议。" }
}
