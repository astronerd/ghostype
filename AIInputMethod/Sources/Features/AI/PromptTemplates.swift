import Foundation

// MARK: - Prompt Templates

/// Prompt 模板常量
/// 定义 Block 2（句内模式识别）和 Block 3（句尾唤醒指令）的 Prompt 模板
struct PromptTemplates {
    
    // MARK: - Block 2: 句内模式识别（中英文双语）
    
    /// Block 2 Prompt - 句内模式识别
    /// 支持中英文双语场景
    static let block2 = """
    【句内模式识别 / In-Sentence Pattern Recognition】

    === 中文模式 ===

    1. 中文拆字确认
       - 用户先说名字/词语，然后用拆字方式确认某个字的写法
       - 拆字说明出现在要确认的字**之后**，用于消除歧义
       - 输出时只保留名字/词语本身，删除拆字说明部分
       - 常见拆字模式：
         * 「X的X」：如「耿直的耿」确认是「耿」字
         * 「XYZ」组合：如「木子李」确认是「李」字，「弓长张」确认是「张」字
         * 「X字旁的Y」：如「三点水的江」确认是「江」字
       - 例如：「他是李明 木子李」→「他是李明」
       - 例如：「我叫耿大伟 耿直的耿」→「我叫耿大伟」
       - 例如：「张伟 弓长张」→「张伟」
       - 例如：「我姓黄 草头黄」→「我姓黄」

    2. 中文特殊符号
       - 「版权符号」→「©」
       - 「人民币符号」→「¥」
       - 「度数符号」→「°」
       - 「破折号」→「——」
       - 例如：「价格100 人民币符号」→「价格¥100」

    3. 中文大写数字
       - 当用户说「大写」时，将数字转换为中文大写
       - 例如：「金额一百二十三 大写」→「金额壹佰贰拾叁」
       - 例如：「发票456 大写」→「发票肆佰伍拾陆」

    === English Patterns ===

    4. Email Address Dictation
       - Convert verbal email descriptions to actual email format
       - "at" → @, "dot" → ., "underscore" → _, "dash/hyphen" → -
       - "no H" / "with no H" / "without H" → remove H from previous word
       - Examples:
         * "sara with no H at gmail dot com" → "sara@gmail.com"
         * "john underscore doe at company dot com" → "john_doe@company.com"
         * "mike dot smith at acme dot co" → "mike.smith@acme.co"
         * "contact at MAKR M A K R dot com" → "contact@makr.com"

    5. Phone Number Dictation
       - Convert verbal phone numbers to standard format
       - "area code" indicates start of phone number
       - Examples:
         * "area code 415 555 1234" → "(415) 555-1234"
         * "1 800 555 0199" → "1-800-555-0199"
         * "555 123 4567" → "555-123-4567"

    6. URL/Website Dictation
       - "dot" → ., "slash" → /, "colon" → :
       - Examples:
         * "www dot example dot com" → "www.example.com"
         * "example dot com slash pricing" → "example.com/pricing"
         * "https colon slash slash github dot com" → "https://github.com"

    7. Name Spelling Confirmation
       - Users spell names to clarify, remove the spelling keep only the name
       - Examples:
         * "My name is Sean S E A N" → "My name is Sean"
         * "Contact Jennifer J E N N I F E R in sales" → "Contact Jennifer in sales"
         * "Ask for Siobhan thats S I O B H A N" → "Ask for Siobhan"
         * "Its Stephen with a P H" → "Its Stephen"

    8. Acronym Spelling
       - Convert spelled-out acronyms to uppercase
       - Examples:
         * "Send it to the C E O" → "Send it to the CEO"
         * "The A P I is down" → "The API is down"
         * "The C T O wants the A P I docs" → "The CTO wants the API docs"

    9. Special Characters (English)
       - "hashtag" / "pound sign" → #
       - "at sign" → @
       - "ampersand" → &
       - "percent" → %
       - "dollar sign" → $
       - Examples:
         * "use hashtag ghosttype" → "use #ghosttype"
         * "price is dollar sign 99" → "price is $99"
         * "50 percent off" → "50% off"
         * "Smith ampersand Jones" → "Smith & Jones"

    === 通用模式 / Universal Patterns ===

    10. Emoji 插入
        - 中文：「笑哭的表情」→「😂」，「爱心」→「❤️」，「竖起大拇指」→「👍」
        - English: "thumbs up" → 👍, "smiley face" → 😊, "heart" → ❤️

    11. 换行 / New Line
        - 中文：「换行」「另起一段」→ 插入换行符
        - English: "new line" / "new paragraph" → insert line break
        - 例如：「第一段 换行 第二段」→「第一段\\n第二段」
        - Example: "First point new line second point" → "First point\\nSecond point"

    12. 标点 / Punctuation
        - "question mark" → ?, "exclamation point" → !, "colon" → :
        - Example: "What do you think question mark" → "What do you think?"

    【处理规则 / Processing Rules】
    - 识别到模式后，输出处理后的结果，删除指令/说明部分
    - Remove filler words: um, uh, like, you know, basically, so, I mean
    - 去除口语词：额、嗯、就是说、然后、那个
    - 拆字确认、拼写说明等是辅助信息，不应出现在最终输出中
    - 如果无法确定用户意图，保留原文
    """
    
    // MARK: - Block 3: 句尾唤醒指令（中英文双语）
    
    /// Block 3 Prompt - 句尾唤醒指令
    /// 使用 {{trigger_word}} 作为唤醒词占位符，运行时替换
    static let block3 = """
    【句尾唤醒指令 / End-of-Sentence Commands】

    当用户在句尾使用唤醒词「{{trigger_word}}」加指令时，执行相应操作。
    When user says "{{trigger_word}}" followed by a command at the end, execute that command.

    【唤醒词识别规则】
    - 唤醒词必须出现在句尾或接近句尾的位置
    - 唤醒词后面紧跟指令词
    - 如果「{{trigger_word}}」出现在句中而非句尾，视为普通文本，不触发指令

    === 支持的指令类型 / Supported Commands ===

    1. 翻译指令 / Translation
       - 「{{trigger_word}} 翻译成英文」→ translate to English
       - 「{{trigger_word}} 翻译成中文」→ translate to Chinese
       - 「{{trigger_word}} 翻译成日文」→ translate to Japanese
       - "{{trigger_word}} translate to Chinese" → 翻译成中文
       - "{{trigger_word}} translate to Spanish" → translate to Spanish
       - 例如：「今天天气真好 {{trigger_word}} 翻译成英文」→「The weather is really nice today」

    2. 格式指令 / Format
       - 「{{trigger_word}} 转成列表」/ "make a list" → 列表格式
       - 「{{trigger_word}} 加编号」/ "action items" → 编号列表
       - 「{{trigger_word}} 整理成会议纪要」/ "meeting notes" → 会议纪要格式
       - "{{trigger_word}} email format" → 邮件格式
       - 例如：「苹果香蕉橙子 {{trigger_word}} 转成列表」→「1. 苹果\\n2. 香蕉\\n3. 橙子」

    3. 语气指令 / Tone
       - 「{{trigger_word}} 更正式」/ "make it professional" → 正式语气
       - 「{{trigger_word}} 更轻松」/ "make it casual" → 轻松语气
       - 「{{trigger_word}} 更礼貌」/ "make it polite" → 礼貌表达
       - 「{{trigger_word}} 我跟领导汇报」/ "for my boss" → 适合向上级汇报
       - 「{{trigger_word}} 给客户看」/ "for the client" → 适合客户沟通
       - 例如：「我想问一下这个怎么弄 {{trigger_word}} 更礼貌」→「请问您能告诉我这个应该如何操作吗？」

    4. 长度指令 / Length
       - 「{{trigger_word}} 简短一点」/ "shorter" / "make it brief" → 精简内容
       - 「{{trigger_word}} 详细一点」/ "expand" / "more detail" → 展开内容
       - 「{{trigger_word}} 总结一下」/ "summarize" → 总结要点
       - 例如：「这段话太长了 {{trigger_word}} 简短一点」→ 精简版本

    5. 场景指令 / Context
       - 「{{trigger_word}} 写成邮件」/ "write as email" → 邮件格式
       - 「{{trigger_word}} 回复客户」→ 客户回复格式
       - "{{trigger_word}} for my boss" → 适合上级的表达
       - "{{trigger_word}} for the team" → 团队沟通风格

    【处理规则 / Rules】
    - 执行指令后，输出处理后的结果
    - 不要输出唤醒词和指令本身
    - Don't include the trigger word or command in output
    - 如果指令不明确，尝试理解用户意图
    - 如果无法执行指令，保留原文并忽略指令部分
    """
    
    // MARK: - Helper Methods
    
    /// 获取替换了唤醒词的 Block 3 Prompt
    /// - Parameter triggerWord: 用户设置的唤醒词
    /// - Returns: 替换后的 Block 3 Prompt
    static func block3WithTriggerWord(_ triggerWord: String) -> String {
        return block3.replacingOccurrences(of: "{{trigger_word}}", with: triggerWord)
    }
}
