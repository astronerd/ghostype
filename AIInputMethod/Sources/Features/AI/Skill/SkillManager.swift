import Foundation
import AppKit

// MARK: - Skill Manager

@Observable
class SkillManager {
    static let shared = SkillManager()

    private(set) var skills: [SkillModel] = []
    private(set) var keyBindings: [UInt16: String] = [:]

    let storageDirectory: URL
    let metadataStore: SkillMetadataStore

    // MARK: - Init

    init(storageDirectory: URL? = nil, metadataStore: SkillMetadataStore? = nil) {
        if let dir = storageDirectory {
            self.storageDirectory = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageDirectory = appSupport.appendingPathComponent("GHOSTYPE/skills")
        }
        self.metadataStore = metadataStore ?? SkillMetadataStore()
    }

    // MARK: - Load

    func loadAllSkills() {
        let fm = FileManager.default
        skills = []
        keyBindings = [:]

        guard let entries = try? fm.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            FileLogger.log("[SkillManager] No skills directory found at \(storageDirectory.path)")
            return
        }

        for entry in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let skillFile = entry.appendingPathComponent("SKILL.md")
            guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
                FileLogger.log("[SkillManager] Failed to read \(skillFile.path)")
                continue
            }

            let directoryName = entry.lastPathComponent

            do {
                let parseResult = try SkillFileParser.parse(content, directoryName: directoryName)

                // Handle legacy migration: if SKILL.md contains legacy UI fields, import them
                if let legacy = parseResult.legacyFields {
                    metadataStore.importLegacy(skillId: directoryName, legacy: legacy)
                }

                let metadata = metadataStore.get(skillId: directoryName)

                let skill = SkillModel(
                    id: directoryName,
                    name: parseResult.name,
                    description: parseResult.description,
                    userPrompt: parseResult.userPrompt,
                    systemPrompt: parseResult.systemPrompt,
                    allowedTools: parseResult.allowedTools.isEmpty ? ["provide_text"] : parseResult.allowedTools,
                    config: parseResult.config,
                    icon: metadata.icon,
                    colorHex: metadata.colorHex,
                    modifierKey: metadata.modifierKey,
                    isBuiltin: metadata.isBuiltin,
                    isInternal: metadata.isInternal
                )

                skills.append(skill)
                if let binding = skill.modifierKey {
                    keyBindings[binding.keyCode] = skill.id
                }
            } catch {
                FileLogger.log("[SkillManager] Failed to parse \(skillFile.path): \(error)")
            }
        }

        FileLogger.log("[SkillManager] Loaded \(skills.count) skills")
    }

    // MARK: - CRUD

    func createSkill(_ skill: SkillModel) throws {
        let folderURL = storageDirectory.appendingPathComponent(skill.id)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        // Write SKILL.md with semantic fields only
        let parseResult = makeParseResult(from: skill)
        let content = SkillFileParser.print(parseResult)
        let fileURL = folderURL.appendingPathComponent("SKILL.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Save UI metadata to store
        let metadata = makeMetadata(from: skill)
        metadataStore.update(skillId: skill.id, metadata: metadata)

        skills.append(skill)
        if let binding = skill.modifierKey {
            keyBindings[binding.keyCode] = skill.id
        }
    }

    func updateSkill(_ skill: SkillModel) throws {
        guard let index = skills.firstIndex(where: { $0.id == skill.id }) else {
            throw SkillManagerError.skillNotFound(skill.id)
        }

        let oldSkill = skills[index]

        // Write SKILL.md with semantic fields only
        let folderURL = storageDirectory.appendingPathComponent(skill.id)
        let parseResult = makeParseResult(from: skill)
        let content = SkillFileParser.print(parseResult)
        let fileURL = folderURL.appendingPathComponent("SKILL.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Update UI metadata in store
        let metadata = makeMetadata(from: skill)
        metadataStore.update(skillId: skill.id, metadata: metadata)

        // Update in-memory state
        if let oldBinding = oldSkill.modifierKey {
            keyBindings.removeValue(forKey: oldBinding.keyCode)
        }
        skills[index] = skill
        if let newBinding = skill.modifierKey {
            keyBindings[newBinding.keyCode] = skill.id
        }
    }

    func deleteSkill(id: String) throws {
        guard let index = skills.firstIndex(where: { $0.id == id }) else {
            throw SkillManagerError.skillNotFound(id)
        }

        let skill = skills[index]
        if skill.isBuiltin {
            throw SkillManagerError.cannotDeleteBuiltin(skill.name)
        }

        let folderURL = storageDirectory.appendingPathComponent(id)
        try FileManager.default.removeItem(at: folderURL)

        // Remove metadata from store
        metadataStore.remove(skillId: id)

        if let binding = skill.modifierKey {
            keyBindings.removeValue(forKey: binding.keyCode)
        }
        skills.remove(at: index)
    }

    // MARK: - UI Metadata Updates

    func updateColor(skillId: String, colorHex: String) throws {
        guard let index = skills.firstIndex(where: { $0.id == skillId }) else {
            throw SkillManagerError.skillNotFound(skillId)
        }
        var meta = metadataStore.get(skillId: skillId)
        meta.colorHex = colorHex
        metadataStore.update(skillId: skillId, metadata: meta)
        skills[index].colorHex = colorHex
    }

    func updateIcon(skillId: String, icon: String) throws {
        guard let index = skills.firstIndex(where: { $0.id == skillId }) else {
            throw SkillManagerError.skillNotFound(skillId)
        }
        var meta = metadataStore.get(skillId: skillId)
        meta.icon = icon
        metadataStore.update(skillId: skillId, metadata: meta)
        skills[index].icon = icon
    }

    // MARK: - Key Binding Queries

    func skillForKeyCode(_ keyCode: UInt16) -> SkillModel? {
        guard let skillId = keyBindings[keyCode] else { return nil }
        return skills.first(where: { $0.id == skillId })
    }

    func skillForModifiers(_ modifiers: NSEvent.ModifierFlags) -> SkillModel? {
        for skill in skills {
            guard let binding = skill.modifierKey, binding.isSystemModifier else { continue }
            let modifierFlag = modifierFlagForKeyCode(binding.keyCode)
            if modifiers.contains(modifierFlag) {
                return skill
            }
        }
        return nil
    }

    func rebindKey(skillId: String, newBinding: ModifierKeyBinding?) throws {
        guard var skill = skills.first(where: { $0.id == skillId }) else {
            throw SkillManagerError.skillNotFound(skillId)
        }

        skill.modifierKey = newBinding
        try updateSkill(skill)
    }

    func hasKeyConflict(_ binding: ModifierKeyBinding, excludingSkillId: String? = nil) -> SkillModel? {
        for skill in skills {
            if skill.id == excludingSkillId { continue }
            guard let existingBinding = skill.modifierKey else { continue }
            if existingBinding.keyCode == binding.keyCode {
                return skill
            }
        }
        return nil
    }


    // MARK: - Builtin Skills

    func ensureBuiltinSkills() {
        let fm = FileManager.default

        if !fm.fileExists(atPath: storageDirectory.path) {
            try? fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }

        let memoPrompt = """
        # Role
        你是一个极度干练的文字整理助手。你的任务是将用户的语音内容转化为纯净、结构化的文本笔记。

        # Constraints
        1. 零废话：严禁使用"标题："、"内容："、"摘要："等元标签
        2. 零表情：严禁使用任何 Emoji 表情符号
        3. 去口语化：剔除"那个"、"呃"、"就是说"等语气词，修正逻辑，使语言精炼
        4. 极简格式：第一行用加粗文本概括核心事宜，后续用无序列表陈述关键细节

        # Available Tools
        - **save_memo**: 将整理好的笔记保存到用户的笔记本

        # Tool Calling Format
        使用 JSON 格式调用工具：
        {"tool": "save_memo", "content": "整理后的笔记内容"}

        # Output Format
        {"tool": "save_memo", "content": "**[核心事宜概括]**\\n- [关键信息 1]\\n- [关键信息 2]\\n- [补充说明]（如有）"}

        # Examples

        ## Example 1
        **User:** "跟老李聊了一下，他说下周三之前要把设计稿定下来，但是预算这块儿还得再砍掉百分之十，因为甲方那边觉得太贵了。"

        **Response:**
        {"tool": "save_memo", "content": "**设计稿调整沟通（老李）**\\n- 截止时间：下周三前定稿\\n- 预算调整：需削减 10%\\n- 原因：甲方反馈报价过高"}

        ## Example 2
        **User:** "提醒我下班去超市买点鸡蛋，还有明天早上九点要记得抢那个演唱会的票。"

        **Response:**
        {"tool": "save_memo", "content": "**个人待办**\\n- 下班去超市买鸡蛋\\n- 明早 09:00 抢演唱会门票"}
        """

        let ghostCommandPrompt = """
        # Role
        你是一个万能助手。用户会用语音告诉你一个任务，你需要直接完成任务并输出结果。

        # Constraints
        1. 直接给出结果，不要解释你在做什么
        2. 不要输出"好的"、"没问题"等客套话
        3. 不要重复用户的问题
        4. 如果任务是写代码，直接输出代码，不要加 markdown 代码块标记
        5. 如果任务是回答问题，简洁明了地回答

        # Available Tools
        - **provide_text**: 输出生成的文本内容

        # Tool Calling Format
        使用 JSON 格式调用工具：
        {"tool": "provide_text", "content": "生成的内容"}

        # Examples

        ## Example 1: 简短生成
        **User:** "帮我写一个邮件开头，跟客户道歉说发货晚了"
        **Response:**
        {"tool": "provide_text", "content": "尊敬的客户，非常抱歉通知您，由于物流调度原因，您的订单发货时间有所延迟。"}

        ## Example 2: 问题回答
        **User:** "TCP 三次握手的过程是什么"
        **Response:**
        {"tool": "provide_text", "content": "TCP 三次握手过程：\\n\\n1. SYN：客户端发送 SYN 包到服务器\\n2. SYN+ACK：服务器回复\\n3. ACK：客户端确认，连接建立"}
        """

        let ghostTwinPrompt = """
        # Role
        你是用户的"数字分身"。你拥有用户的人格档案，能够以用户的口吻、语言习惯和思维方式生成回复。

        # Constraints
        1. 严格模仿用户的语言风格
        2. 使用用户常用的词汇和表达方式
        3. 保持用户的立场和观点倾向
        4. 不要暴露自己是 AI，要像用户本人在说话
        5. 如果没有足够的人格档案信息，以自然、中性的风格回复

        # Available Tools
        - **provide_text**: 输出生成的回复

        # Tool Calling Format
        使用 JSON 格式调用工具：
        {"tool": "provide_text", "content": "生成的回复"}

        # Examples

        ## Example 1: 简短回复
        **User:** "回复老板说今天加班搞不了"
        **Response:**
        {"tool": "provide_text", "content": "老板，不好意思今天晚上有点事走不开，加班可能搞不了，明天我早点来补上。"}
        """

        let translatePrompt = """
        # Role
        你是一个专业的翻译员，精通多国语言。你的任务是将用户的语音内容准确翻译为目标语言。

        # Constraints
        1. 只输出翻译结果，不要有任何解释、注释或元信息
        2. 保持原文的语气和风格（正式/口语/技术）
        3. 专有名词保留原文或使用通用译法
        4. 如果源语言是"自动检测"，根据输入内容自动判断源语言
        5. 如果输入内容已经是目标语言，翻译为最可能的源语言

        # Available Tools
        - **provide_text**: 输出翻译结果

        # Tool Calling Format
        使用 JSON 格式调用工具：
        {"tool": "provide_text", "content": "翻译结果"}

        # Translation Config
        - 源语言：{{config.source_language}}
        - 目标语言：{{config.target_language}}

        # Examples

        ## Example 1: 中文 → 英文
        **User:** "今天天气真不错，我们去公园散步吧"
        **Response:**
        {"tool": "provide_text", "content": "The weather is really nice today. Let's go for a walk in the park."}

        ## Example 2: 同语言回退
        **User:** "Hello, how are you doing today?"
        **Response:**
        {"tool": "provide_text", "content": "你好，你今天过得怎么样？"}
        """

        let promptGeneratorPrompt = """
        # Role
        你是一个 Skill Prompt 生成器。你的任务是将用户的简单指令转化为一个结构化的、高质量的 system prompt。

        这个 system prompt 将用于一个语音输入助手应用（GHOSTYPE）。用户按住快捷键说话，语音转文字后发送给 AI，AI 根据 system prompt 处理并返回结果。

        # 用户提供的信息

        - Skill 名称：{{config.skill_name}}
        - Skill 描述：{{config.skill_description}}
        - 用户指令：{{config.user_prompt}}

        # 你需要生成的 system prompt 必须包含以下结构

        ## Role
        一句话描述这个 Skill 的角色定位。

        ## Constraints
        3-5 条约束规则，确保输出质量。必须包含：
        - 直接给出结果，不要解释过程
        - 不要输出客套话
        - 其他根据用户指令推断的约束

        ## Available Tools
        - **provide_text**: 输出生成的文本内容

        ## Tool Calling Format
        使用 JSON 格式调用工具：
        {"tool": "provide_text", "content": "生成的内容"}

        ## Examples
        2-3 个示例，展示输入和期望输出。每个示例格式：

        ### Example N
        **User:** "用户可能说的话"

        **Response:**
        {"tool": "provide_text", "content": "期望的输出"}

        # 重要规则

        1. 只输出 system prompt 本身，不要加任何前缀、后缀、解释
        2. 不要用 markdown 代码块包裹
        3. 用中文撰写（除非用户指令明确要求英文）
        4. 示例要贴合用户的实际使用场景
        5. 唯一可用的工具是 provide_text，不要提及其他工具

        # 完整示例

        以下是一个完整的输入输出示例，展示你应该如何工作。

        ## 输入

        - Skill 名称：笔记助手
        - Skill 描述：把语音整理成简洁的笔记
        - 用户指令：帮我把说的话整理成笔记，去掉废话，提炼重点，用列表格式

        ## 期望输出

        # Role
        你是一个极简笔记整理助手。你的任务是将用户的语音内容提炼为简洁、结构化的笔记。

        # Constraints
        1. 直接输出整理后的笔记，不要解释你在做什么
        2. 不要输出"好的"、"没问题"等客套话
        3. 去掉所有口语化表达（"那个"、"呃"、"就是说"等）
        4. 第一行用加粗文本概括主题，后续用无序列表列出要点
        5. 不要使用 emoji

        # Available Tools
        - **provide_text**: 输出整理后的笔记

        # Tool Calling Format
        使用 JSON 格式调用工具：
        {"tool": "provide_text", "content": "整理后的笔记"}

        # Examples

        ## Example 1
        **User:** "今天开会讨论了一下新版本的上线时间，产品那边说最迟下周五，但是后端说接口还没联调完，可能要延期两天"

        **Response:**
        {"tool": "provide_text", "content": "**新版本上线时间讨论**\\n- 产品要求：最迟下周五上线\\n- 后端现状：接口联调未完成\\n- 风险：可能延期 2 天"}

        ## Example 2
        **User:** "刚才跟客户打电话，他说对方案整体满意，但是价格希望再降一点，另外交付时间能不能提前到月底"

        **Response:**
        {"tool": "provide_text", "content": "**客户沟通反馈**\\n- 方案：整体满意\\n- 价格：希望再降\\n- 交付时间：希望提前至月底"}

        ## Example 3
        **User:** "突然想到一个功能点，就是用户可以自定义快捷键触发不同的 AI 技能，比如按住 shift 说话就是记笔记，按住 control 就是翻译"

        **Response:**
        {"tool": "provide_text", "content": "**功能灵感：自定义快捷键触发 AI 技能**\\n- 按住不同修饰键触发不同技能\\n- 示例：Shift → 笔记，Control → 翻译\\n- 核心价值：一键切换，无需手动选择"}
        """

        let builtinDefinitions: [(id: String, parseResult: SkillFileParser.ParseResult, metadata: SkillMetadata)] = [
            (
                id: SkillModel.builtinMemoId,
                parseResult: SkillFileParser.ParseResult(
                    name: "随心记",
                    description: "将语音内容整理为结构化笔记并保存。适用于会议记录、灵感捕捉、待办事项等场景。",
                    userPrompt: "",
                    systemPrompt: memoPrompt,
                    allowedTools: ["save_memo"],
                    config: [:],
                    legacyFields: nil
                ),
                metadata: SkillMetadata(
                    icon: "📝",
                    colorHex: "#FF9500",
                    modifierKey: ModifierKeyBinding(keyCode: 56, isSystemModifier: true, displayName: "⇧"),
                    isBuiltin: true,
                    isInternal: false
                )
            ),
            (
                id: SkillModel.builtinGhostCommandId,
                parseResult: SkillFileParser.ParseResult(
                    name: "Ghost Command",
                    description: "万能 AI 助手，根据语音指令直接生成内容。适用于写作、编程、计算、翻译、总结等任何文本生成任务。",
                    userPrompt: "",
                    systemPrompt: ghostCommandPrompt,
                    allowedTools: ["provide_text"],
                    config: [:],
                    legacyFields: nil
                ),
                metadata: SkillMetadata(
                    icon: "👻",
                    colorHex: "#007AFF",
                    modifierKey: ModifierKeyBinding(keyCode: 59, isSystemModifier: true, displayName: "⌃"),
                    isBuiltin: true,
                    isInternal: false
                )
            ),
            (
                id: SkillModel.builtinGhostTwinId,
                parseResult: SkillFileParser.ParseResult(
                    name: "Ghost Twin",
                    description: "以用户的口吻和语言习惯生成回复。基于用户的人格档案，模仿用户的表达风格。",
                    userPrompt: "",
                    systemPrompt: ghostTwinPrompt,
                    allowedTools: ["provide_text"],
                    config: ["api_endpoint": "/api/v1/ghost-twin/chat"],
                    legacyFields: nil
                ),
                metadata: SkillMetadata(
                    icon: "🪞",
                    colorHex: "#FF2D55",
                    modifierKey: nil,
                    isBuiltin: true,
                    isInternal: false
                )
            ),
            (
                id: SkillModel.builtinTranslateId,
                parseResult: SkillFileParser.ParseResult(
                    name: "翻译",
                    description: "语音翻译助手，将用户的语音内容翻译为目标语言。支持自动检测源语言。",
                    userPrompt: "",
                    systemPrompt: translatePrompt,
                    allowedTools: ["provide_text"],
                    config: ["source_language": "自动检测", "target_language": "英文"],
                    legacyFields: nil
                ),
                metadata: SkillMetadata(
                    icon: "🌐",
                    colorHex: "#AF52DE",
                    modifierKey: nil,
                    isBuiltin: true,
                    isInternal: false
                )
            ),
            (
                id: SkillModel.builtinPromptGeneratorId,
                parseResult: SkillFileParser.ParseResult(
                    name: "Skill Prompt Generator",
                    description: "内部 Skill：将用户的简单指令转化为结构化的、符合 tool calling 格式的 system prompt。",
                    userPrompt: "",
                    systemPrompt: promptGeneratorPrompt,
                    allowedTools: ["provide_text"],
                    config: [:],
                    legacyFields: nil
                ),
                metadata: SkillMetadata(
                    icon: "🧠",
                    colorHex: "#8E8E93",
                    modifierKey: nil,
                    isBuiltin: true,
                    isInternal: true
                )
            ),
        ]

        for definition in builtinDefinitions {
            let folderURL = storageDirectory.appendingPathComponent(definition.id)
            let fileURL = folderURL.appendingPathComponent("SKILL.md")
            // 内置 Skill 始终覆盖写入，确保代码更新能传播到运行时
            try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let content = SkillFileParser.print(definition.parseResult)
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
            FileLogger.log("[SkillManager] Wrote builtin skill: \(definition.parseResult.name)")

            // Always force-write builtin metadata (icon, color, isBuiltin, isInternal)
            // Preserve user's custom keybinding if they set one
            let existing = metadataStore.get(skillId: definition.id)
            var meta = definition.metadata
            meta.modifierKey = existing.modifierKey ?? definition.metadata.modifierKey
            metadataStore.update(skillId: definition.id, metadata: meta)
        }
    }

    // MARK: - Skill Lookup

    /// 根据 ID 查找 skill（包括 internal skills）
    func skill(byId id: String) -> SkillModel? {
        skills.first(where: { $0.id == id })
    }

    // MARK: - Private Helpers

    private func makeParseResult(from skill: SkillModel) -> SkillFileParser.ParseResult {
        SkillFileParser.ParseResult(
            name: skill.name,
            description: skill.description,
            userPrompt: skill.userPrompt,
            systemPrompt: skill.systemPrompt,
            allowedTools: skill.allowedTools,
            config: skill.config,
            legacyFields: nil
        )
    }

    private func makeMetadata(from skill: SkillModel) -> SkillMetadata {
        SkillMetadata(
            icon: skill.icon,
            colorHex: skill.colorHex,
            modifierKey: skill.modifierKey,
            isBuiltin: skill.isBuiltin,
            isInternal: skill.isInternal
        )
    }

    private func modifierFlagForKeyCode(_ keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 55, 54: return .command
        case 56, 60: return .shift
        case 58, 61: return .option
        case 59, 62: return .control
        case 63: return .function
        default: return []
        }
    }
}

// MARK: - Errors

enum SkillManagerError: LocalizedError {
    case skillNotFound(String)
    case cannotDeleteBuiltin(String)

    var errorDescription: String? {
        switch self {
        case .skillNotFound(let id): return "Skill not found: \(id)"
        case .cannotDeleteBuiltin(let name): return "Cannot delete builtin skill: \(name)"
        }
    }
}
