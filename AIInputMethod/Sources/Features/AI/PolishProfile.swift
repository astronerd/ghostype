import Foundation

// MARK: - Polish Profile

/// 润色配置文件枚举
/// 定义 6 种预设润色风格，每种风格对应不同的 Prompt
enum PolishProfile: String, CaseIterable, Identifiable {
    /// 默认：去口语化、修语法、保原意
    case standard = "默认"
    
    /// 专业/商务：正式书面语，适合邮件、报告
    case professional = "专业/商务"
    
    /// 轻松/社交：保留口语感，只修错别字
    case casual = "轻松/社交"
    
    /// 简洁：精简压缩，提炼核心
    case concise = "简洁"
    
    /// 创意/文学：润色+美化，增加修辞
    case creative = "创意/文学"
    
    /// 自定义：使用用户自定义 Prompt
    case custom = "自定义"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Properties
    
    /// 配置描述
    var description: String {
        switch self {
        case .standard:
            return "去口语化、修语法、保原意"
        case .professional:
            return "正式书面语，适合邮件、报告"
        case .casual:
            return "保留口语感，只修错别字"
        case .concise:
            return "精简压缩，提炼核心"
        case .creative:
            return "润色+美化，增加修辞"
        case .custom:
            return "使用自定义 Prompt"
        }
    }
    
    /// Block 1 Prompt - 基础润色指令
    var prompt: String {
        switch self {
        case .standard:
            return """
            你是一个文本润色助手。请对用户输入的文本进行润色处理：
            
            【润色要求】
            1. 去除口语化表达，转换为书面语
            2. 修正语法错误和错别字
            3. 保持原文的核心意思不变
            4. 保持原文的语气和风格
            5. 不要添加原文没有的内容
            
            【输出要求】
            - 直接输出润色后的文本
            - 不要添加任何解释或说明
            - 不要使用引号包裹输出
            """
            
        case .professional:
            return """
            你是一个专业文书润色助手。请将用户输入的文本转换为正式的商务书面语：
            
            【润色要求】
            1. 使用正式、专业的书面表达
            2. 适合用于邮件、报告、公文等正式场合
            3. 修正语法错误和错别字
            4. 使用恰当的敬语和礼貌用语
            5. 保持逻辑清晰、条理分明
            6. 避免口语化和随意的表达
            
            【输出要求】
            - 直接输出润色后的文本
            - 不要添加任何解释或说明
            - 不要使用引号包裹输出
            """
            
        case .casual:
            return """
            你是一个轻松风格的文本助手。请对用户输入的文本进行轻微修正：
            
            【处理要求】
            1. 保留口语化的表达风格
            2. 只修正明显的错别字
            3. 只修正严重的语法错误
            4. 保持原文的轻松、自然语气
            5. 适合用于社交聊天、朋友交流
            6. 不要过度正式化
            
            【输出要求】
            - 直接输出处理后的文本
            - 不要添加任何解释或说明
            - 不要使用引号包裹输出
            """
            
        case .concise:
            return """
            你是一个文本精简助手。请将用户输入的文本精简压缩：
            
            【精简要求】
            1. 提炼核心内容，删除冗余表达
            2. 保留关键信息，去除废话
            3. 使用简洁有力的表达
            4. 修正语法错误和错别字
            5. 尽可能缩短文本长度
            6. 不要丢失重要信息
            
            【输出要求】
            - 直接输出精简后的文本
            - 不要添加任何解释或说明
            - 不要使用引号包裹输出
            """
            
        case .creative:
            return """
            你是一个文学润色助手。请对用户输入的文本进行美化润色：
            
            【润色要求】
            1. 提升文字的文学性和美感
            2. 适当使用修辞手法（比喻、排比等）
            3. 使用更优美、生动的词汇
            4. 增强文字的感染力和表现力
            5. 修正语法错误和错别字
            6. 保持原文的核心意思
            
            【输出要求】
            - 直接输出润色后的文本
            - 不要添加任何解释或说明
            - 不要使用引号包裹输出
            """
            
        case .custom:
            // 自定义配置返回空字符串，实际使用时会被用户自定义 Prompt 替换
            return ""
        }
    }
}
