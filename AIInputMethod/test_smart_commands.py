#!/usr/bin/env python3
"""
测试 AI 润色的智能指令功能
包括：句内模式识别（Block 2）和句尾唤醒指令（Block 3）
"""

import urllib.request
import json
import time
import ssl

# API 配置
BASE_URL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
API_KEY = "3b108766-4683-4948-8d84-862b104a5a3e"
MODEL_NAME = "doubao-seed-1-6-flash-250828"

# Block 1: 基础润色 Prompt（标准模式）
BLOCK1_STANDARD = """你是一个专业的文字润色助手。请对用户的语音输入进行润色，使其更加通顺、自然。

【润色规则】
- 修正语音识别可能产生的错误
- 添加适当的标点符号
- 保持原意，不要过度修改
- 输出润色后的文本，不要有任何解释"""

# Block 2: 句内模式识别
BLOCK2 = """
【句内模式识别】
在润色过程中，请识别并处理以下特殊模式：

1. 中文拆字确认
   - 用户先说名字/词语，然后用拆字方式确认某个字的写法
   - 拆字说明出现在要确认的字**之后**，用于消除歧义
   - 输出时只保留名字/词语本身，删除拆字说明部分
   - 常见拆字模式：
     * 「X的X」：如「耿直的耿」确认是「耿」字
     * 「XYZ」组合：如「木子李」确认是「李」字，「弓长张」确认是「张」字
     * 「X字旁的Y」：如「三点水的江」确认是「江」字
   - 例如：「他是李明 木子李」→「他是李明」（木子李是对李字的确认）
   - 例如：「我叫耿大伟 耿直的耿」→「我叫耿大伟」
   - 例如：「张伟 弓长张」→「张伟」
   - 例如：「江河 三点水的江」→「江河」
   - 例如：「我姓黄 草头黄」→「我姓黄」

2. 英文拼写确认
   - 用户先说英文单词/名字，然后补充拼写说明
   - 输出时只保留正确拼写的单词，删除说明部分
   - 例如：「她叫Sara 没有H」→「她叫Sara」
   - 例如：「用color 美式拼写」→「用color」
   - 例如：「我的iPhone 大写I」→「我的iPhone」

3. Emoji 插入
   - 当用户请求插入 emoji 时，输出对应的 emoji
   - 例如：「太棒了 笑哭的表情」→「太棒了😂」
   - 例如：「我爱你 爱心」→「我爱你❤️」
   - 例如：「好的 竖起大拇指」→「好的👍」
   - 例如：「生气了 恶魔emoji」→「生气了😈」

4. 换行符
   - 当用户说「换行」「另起一段」「新段落」时，插入换行符
   - 例如：「这是第一段 换行 这是第二段」→「这是第一段\\n这是第二段」
   - 例如：「第一点内容 另起一段 第二点内容」→「第一点内容\\n第二点内容」

5. 破折号
   - 当用户说「破折号」时，插入中文破折号（——）
   - 例如：「人工智能 破折号 也叫AI」→「人工智能——也叫AI」

6. 特殊符号
   - 当用户描述特殊符号时，输出对应符号
   - 例如：「版权符号 2024」→「©2024」
   - 例如：「价格100 人民币符号」→「价格¥100」
   - 例如：「温度25 度数符号」→「温度25°」
   - 支持：©®™°¥€£等

7. 大写数字
   - 当用户说「大写」时，将数字转换为中文大写
   - 例如：「金额一百二十三 大写」→「金额壹佰贰拾叁」
   - 例如：「发票456 大写」→「发票肆佰伍拾陆」

8. 插入时间/日期
   - 当用户请求插入时间或日期时，输出当前时间/日期
   - 例如：「会议时间 插入今天日期」→「会议时间2024年1月15日」
   - 使用北京时间（UTC+8）

【处理规则】
- 识别到模式后，输出处理后的结果，删除指令/说明部分
- 拆字确认、拼写说明等是辅助信息，不应出现在最终输出中
- 如果无法确定用户意图，保留原文
"""

# Block 3: 句尾唤醒指令
BLOCK3_TEMPLATE = """
【句尾唤醒指令】
当用户在句尾使用唤醒词「{trigger_word}」加指令时，执行相应操作。

【唤醒词识别规则】
- 唤醒词必须出现在句尾或接近句尾的位置
- 唤醒词后面紧跟指令词
- 如果「{trigger_word}」出现在句中而非句尾，视为普通文本，不触发指令
- 如果「{trigger_word}」在句尾但没有后续指令，视为普通文本

【支持的指令类型】

1. 翻译指令
   - 「{trigger_word} 翻译成英文」→ 将前面的内容翻译成英文
   - 「{trigger_word} 翻译成中文」→ 将前面的内容翻译成中文
   - 「{trigger_word} 翻译成日文」→ 将前面的内容翻译成日文
   - 「{trigger_word} translate to English」→ 翻译成英文
   - 例如：「今天天气真好 {trigger_word} 翻译成英文」→「The weather is really nice today」

2. 格式指令
   - 「{trigger_word} 转成列表」→ 将内容转换为列表格式
   - 「{trigger_word} 加标点」→ 为内容添加合适的标点符号
   - 「{trigger_word} 转成表格」→ 将内容转换为表格格式
   - 「{trigger_word} 加编号」→ 为内容添加序号
   - 例如：「苹果香蕉橙子 {trigger_word} 转成列表」→「1. 苹果\n2. 香蕉\n3. 橙子」

3. 语气指令
   - 「{trigger_word} 更正式」→ 将内容转换为更正式的语气
   - 「{trigger_word} 更轻松」→ 将内容转换为更轻松的语气
   - 「{trigger_word} 更礼貌」→ 将内容转换为更礼貌的表达
   - 「{trigger_word} 更直接」→ 将内容转换为更直接的表达
   - 例如：「我想问一下这个怎么弄 {trigger_word} 更礼貌」→「请问您能告诉我这个应该如何操作吗？」

4. 长度指令
   - 「{trigger_word} 简短一点」→ 精简内容
   - 「{trigger_word} 详细一点」→ 扩展内容
   - 「{trigger_word} 总结一下」→ 总结核心要点
   - 「{trigger_word} 展开说说」→ 详细展开内容
   - 例如：「人工智能是计算机科学的一个分支 {trigger_word} 详细一点」→ 输出更详细的解释

【处理规则】
- 执行指令后，输出处理后的结果
- 不要输出唤醒词和指令本身
- 如果指令不明确，尝试理解用户意图
- 如果无法执行指令，保留原文并忽略指令部分
"""

def build_prompt(enable_block2=True, enable_block3=True, trigger_word="小幽灵"):
    """构建完整的系统 Prompt"""
    prompt = BLOCK1_STANDARD
    
    if enable_block2:
        prompt += "\n\n" + BLOCK2
    
    if enable_block3:
        prompt += "\n\n" + BLOCK3_TEMPLATE.format(trigger_word=trigger_word)
    
    return prompt

def call_api(system_prompt, user_message):
    """调用豆包 API"""
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
    
    payload = {
        "model": MODEL_NAME,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ],
        "temperature": 0.7,
        "max_tokens": 2048
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(BASE_URL, data=data, headers=headers, method='POST')
    
    # 创建 SSL 上下文
    ctx = ssl.create_default_context()
    
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result["choices"][0]["message"]["content"].strip()
    except urllib.error.HTTPError as e:
        return f"Error: {e.code} - {e.read().decode('utf-8')}"
    except Exception as e:
        return f"Error: {str(e)}"

def test_case(name, input_text, expected_hint, enable_block2=True, enable_block3=True, trigger_word="小幽灵"):
    """运行单个测试用例"""
    print(f"\n{'='*60}")
    print(f"📝 测试: {name}")
    print(f"{'='*60}")
    print(f"输入: {input_text}")
    print(f"期望: {expected_hint}")
    
    prompt = build_prompt(enable_block2, enable_block3, trigger_word)
    result = call_api(prompt, input_text)
    
    print(f"输出: {result}")
    print("-" * 60)
    
    time.sleep(0.5)  # 避免 API 限流
    return result

def main():
    print("\n" + "="*70)
    print("🧪 AI 润色智能指令测试")
    print("="*70)
    
    # ========== Block 2: 句内模式识别测试 ==========
    print("\n\n" + "🔷"*30)
    print("Block 2: 句内模式识别测试")
    print("🔷"*30)
    
    # 1. 中文拆字确认（拆字在名字后面）
    test_case(
        "中文拆字 - 木子李",
        "他是李明 木子李",
        "他是李明"
    )
    
    test_case(
        "中文拆字 - 耿直的耿",
        "我叫耿大伟 耿直的耿",
        "我叫耿大伟"
    )
    
    test_case(
        "中文拆字 - 弓长张",
        "张伟 弓长张",
        "张伟"
    )
    
    test_case(
        "中文拆字 - 三点水",
        "江河 三点水的江",
        "江河"
    )
    
    test_case(
        "中文拆字 - 草头黄",
        "我姓黄 草头黄",
        "我姓黄"
    )
    
    test_case(
        "中文拆字 - 句中使用",
        "请联系李经理 木子李 他负责这个项目",
        "请联系李经理，他负责这个项目"
    )
    
    # 2. 英文拼写确认
    test_case(
        "英文拼写 - Sara没有H",
        "她叫Sara 没有H",
        "她叫Sara"
    )
    
    test_case(
        "英文拼写 - iPhone大写I",
        "我的iPhone 大写I",
        "我的iPhone"
    )
    
    test_case(
        "英文拼写 - color美式",
        "用color 美式拼写",
        "用color"
    )
    
    # 3. Emoji 插入
    test_case(
        "Emoji - 笑哭",
        "太棒了 笑哭的表情",
        "太棒了😂"
    )
    
    test_case(
        "Emoji - 爱心",
        "我爱你 爱心",
        "我爱你❤️"
    )
    
    test_case(
        "Emoji - 大拇指",
        "好的 竖起大拇指",
        "好的👍"
    )
    
    test_case(
        "Emoji - 恶魔",
        "生气了 恶魔emoji",
        "生气了😈"
    )
    
    # 4. 换行符
    test_case(
        "换行 - 基本换行",
        "这是第一段 换行 这是第二段",
        "这是第一段\n这是第二段"
    )
    
    test_case(
        "换行 - 另起一段",
        "第一点内容 另起一段 第二点内容",
        "第一点内容\n第二点内容"
    )
    
    # 5. 破折号
    test_case(
        "破折号 - 基本",
        "人工智能 破折号 也叫AI",
        "人工智能——也叫AI"
    )
    
    # 6. 特殊符号
    test_case(
        "特殊符号 - 版权",
        "版权符号 2024",
        "©2024"
    )
    
    test_case(
        "特殊符号 - 人民币",
        "价格100 人民币符号",
        "价格¥100"
    )
    
    test_case(
        "特殊符号 - 度数",
        "温度25 度数符号",
        "温度25°"
    )
    
    # 7. 大写数字
    test_case(
        "大写数字 - 中文数字",
        "金额一百二十三 大写",
        "金额壹佰贰拾叁"
    )
    
    test_case(
        "大写数字 - 阿拉伯数字",
        "发票456 大写",
        "发票肆佰伍拾陆"
    )
    
    # 8. 插入时间/日期
    test_case(
        "日期 - 今天",
        "会议时间 插入今天日期",
        "会议时间2026年2月8日（或类似格式）"
    )
    
    # ========== Block 3: 句尾唤醒指令测试 ==========
    print("\n\n" + "🔶"*30)
    print("Block 3: 句尾唤醒指令测试")
    print("🔶"*30)
    
    # 1. 翻译指令
    test_case(
        "翻译 - 中译英",
        "今天天气真好 ghost翻译成英文",
        "The weather is really nice today",
        trigger_word="ghost"
    )
    
    test_case(
        "翻译 - 英译中",
        "Hello how are you ghost翻译成中文",
        "你好，你好吗",
        trigger_word="ghost"
    )
    
    test_case(
        "翻译 - 中译日",
        "我爱你 ghost翻译成日文",
        "愛してる / 私はあなたを愛しています",
        trigger_word="ghost"
    )
    
    # 2. 格式指令
    test_case(
        "格式 - 转列表",
        "苹果香蕉橙子葡萄 ghost转成列表",
        "1. 苹果\n2. 香蕉\n3. 橙子\n4. 葡萄",
        trigger_word="ghost"
    )
    
    test_case(
        "格式 - 加编号",
        "第一步打开软件第二步点击按钮第三步保存文件 ghost加编号",
        "1. 打开软件\n2. 点击按钮\n3. 保存文件",
        trigger_word="ghost"
    )
    
    # 3. 语气指令
    test_case(
        "语气 - 更正式",
        "我想问一下这个怎么弄 ghost更正式",
        "请问这个应该如何操作？",
        trigger_word="ghost"
    )
    
    test_case(
        "语气 - 更礼貌",
        "把文件发给我 ghost更礼貌",
        "麻烦您把文件发给我，谢谢",
        trigger_word="ghost"
    )
    
    test_case(
        "语气 - 更轻松",
        "请您务必在明天之前完成此项工作 ghost更轻松",
        "明天之前搞定就行啦",
        trigger_word="ghost"
    )
    
    # 4. 长度指令
    test_case(
        "长度 - 简短",
        "人工智能是计算机科学的一个重要分支它致力于研究和开发能够模拟人类智能的系统 ghost简短一点",
        "AI是研究模拟人类智能的计算机科学分支",
        trigger_word="ghost"
    )
    
    test_case(
        "长度 - 详细",
        "AI很重要 ghost详细一点",
        "（更详细的解释）",
        trigger_word="ghost"
    )
    
    # ========== 组合测试 ==========
    print("\n\n" + "🔷🔶"*15)
    print("组合测试: Block 2 + Block 3")
    print("🔷🔶"*15)
    
    test_case(
        "组合 - 拆字+翻译",
        "我叫李明 木子李 ghost翻译成英文",
        "My name is Li Ming",
        trigger_word="ghost"
    )
    
    test_case(
        "组合 - Emoji+语气",
        "做得好 竖起大拇指 ghost更正式",
        "做得非常出色👍",
        trigger_word="ghost"
    )
    
    test_case(
        "组合 - 换行+列表",
        "第一点要认真 换行 第二点要努力 换行 第三点要坚持 ghost转成列表",
        "1. 要认真\n2. 要努力\n3. 要坚持",
        trigger_word="ghost"
    )
    
    # ========== 边界情况测试 ==========
    print("\n\n" + "⚠️"*30)
    print("边界情况测试")
    print("⚠️"*30)
    
    test_case(
        "边界 - 唤醒词在句中（不应触发）",
        "我觉得ghost这个名字很可爱",
        "我觉得ghost这个名字很可爱（保持原样）",
        trigger_word="ghost"
    )
    
    test_case(
        "边界 - 只有唤醒词没有指令",
        "今天天气真好 ghost",
        "今天天气真好（保持原样或轻微润色）",
        trigger_word="ghost"
    )
    
    test_case(
        "边界 - 普通文本无特殊模式",
        "今天我去超市买了一些水果",
        "今天我去超市买了一些水果。",
        trigger_word="ghost"
    )
    
    # ========== 不同唤醒词测试 ==========
    print("\n\n" + "🎯"*30)
    print("不同唤醒词测试")
    print("🎯"*30)
    
    test_case(
        "唤醒词 - 小助手",
        "今天天气真好 小助手翻译成英文",
        "The weather is really nice today",
        trigger_word="小助手"
    )
    
    test_case(
        "唤醒词 - 请帮我",
        "这段话太长了 请帮我简短一点",
        "（简短版本）",
        trigger_word="请帮我"
    )
    
    print("\n\n" + "="*70)
    print("✅ 测试完成!")
    print("="*70)

if __name__ == "__main__":
    main()


def test_single():
    """单独测试一个复杂场景"""
    print("\n" + "="*70)
    print("🧪 复杂场景单独测试")
    print("="*70)
    
    # 真实口语场景：长句 + 语气词 + 复合指令
    test_case(
        "复杂场景 - 口语汇报转正式",
        "我今天去找了张总，他说，额，他说我们材料有问题需要重新做才能进下一步流程。ghost 我跟领导汇报，帮我改正式一些",
        "（正式的汇报文本）",
        trigger_word="ghost"
    )
    
    # 更多复杂场景
    test_case(
        "复杂场景 - 会议记录整理",
        "今天开会讨论了三个事情，第一个是关于那个项目进度的问题，就是说现在有点慢，第二个是预算超了要申请追加，第三个是人手不够要招人。ghost 帮我整理成会议纪要",
        "（整理后的会议纪要）",
        trigger_word="ghost"
    )
    
    test_case(
        "复杂场景 - 客户反馈转邮件",
        "客户说他们那边系统老是报错，然后数据也对不上，他们很着急希望我们尽快处理一下。ghost 写成邮件回复客户",
        "（正式的邮件回复）",
        trigger_word="ghost"
    )
    
    test_case(
        "复杂场景 - 拆字+长句+翻译",
        "我是李明 木子李 我在北京工作已经五年了主要负责产品设计和用户体验相关的工作。ghost 翻译成英文",
        "My name is Li Ming. I have been working in Beijing for five years...",
        trigger_word="ghost"
    )
    
    test_case(
        "复杂场景 - 口语转书面语",
        "这个方案我觉得吧，就是有点问题，主要是成本太高了，然后时间也来不及，我建议还是用之前那个方案比较好。ghost 更正式",
        "（正式的书面表达）",
        trigger_word="ghost"
    )
    
    test_case(
        "复杂场景 - 带语气词的长句",
        "嗯，就是说，我们这个项目呢，目前进展还算顺利，但是有几个风险点需要注意一下，第一个是供应商那边可能会延期，第二个是测试环境还没搭好。ghost 简短一点",
        "（精简后的内容）",
        trigger_word="ghost"
    )

if __name__ == "__main__":
    # main()  # 完整测试
    # test_single()  # 单独测试复杂场景
    test_english()  # 英文场景测试


def test_english():
    """测试美国用户英文场景"""
    print("\n" + "="*70)
    print("🇺🇸 American English Voice Input Test")
    print("="*70)
    
    # ========== 工作邮件场景 ==========
    print("\n\n" + "📧"*30)
    print("Workplace Email Scenarios")
    print("📧"*30)
    
    test_case(
        "Email - Casual to Professional (with fillers)",
        "So um I talked to the client today and like they said the deadline is too tight you know and they need like two more weeks to finish the review. ghost make it professional",
        "(Professional email version)",
        trigger_word="ghost"
    )
    
    test_case(
        "Email - Meeting Follow-up",
        "Hey so uh just wanted to follow up on our meeting from yesterday basically we agreed on three things first the budget needs approval second we need more developers and third the timeline is pushed to Q2. ghost write as email",
        "(Formal follow-up email)",
        trigger_word="ghost"
    )
    
    test_case(
        "Email - Request with Fillers",
        "Um could you like send me the report when you get a chance I mean its not super urgent but like I need it before Friday you know. ghost more formal",
        "(Polite formal request)",
        trigger_word="ghost"
    )
    
    # ========== Slack/Teams 消息场景 ==========
    print("\n\n" + "💬"*30)
    print("Slack/Teams Message Scenarios")
    print("💬"*30)
    
    test_case(
        "Slack - Quick Update",
        "Hey just a heads up the deployment is gonna be delayed cuz we found some bugs in QA nothing major but like we need another day to fix em. ghost clean it up",
        "(Clean professional message)",
        trigger_word="ghost"
    )
    
    test_case(
        "Slack - Status Update",
        "So basically Im like almost done with the feature just need to write some tests and do code review should be ready by end of day tomorrow I think. ghost make concise",
        "(Concise status update)",
        trigger_word="ghost"
    )
    
    test_case(
        "Slack - Asking for Help",
        "Hey um does anyone know how to fix this error Im getting like a null pointer exception in the user service and Ive been stuck on it for like two hours. ghost",
        "(Clean message, no command - just polish)",
        trigger_word="ghost"
    )
    
    # ========== 会议/汇报场景 ==========
    print("\n\n" + "📊"*30)
    print("Meeting & Reporting Scenarios")
    print("📊"*30)
    
    test_case(
        "Meeting Notes - Rambling to Structured",
        "OK so in todays standup um John said hes working on the API stuff and like Mary is doing the frontend and uh I think Tom mentioned something about database issues or whatever. ghost turn into meeting notes",
        "(Structured meeting notes)",
        trigger_word="ghost"
    )
    
    test_case(
        "Status Report - Verbose to Concise",
        "So basically what happened this week is that we finished the login feature and then we started working on the dashboard but we ran into some issues with the charts library so we had to spend like two days figuring that out and now were back on track. ghost summarize",
        "(Concise summary)",
        trigger_word="ghost"
    )
    
    test_case(
        "Project Update - Casual to Executive",
        "Yeah so the project is going pretty well I guess we hit our milestones for this sprint and the client seems happy but theres some risk with the third party integration thing. ghost make it executive summary",
        "(Executive summary format)",
        trigger_word="ghost"
    )
    
    # ========== 客户沟通场景 ==========
    print("\n\n" + "🤝"*30)
    print("Client Communication Scenarios")
    print("🤝"*30)
    
    test_case(
        "Client Email - Apologetic",
        "So um Im really sorry about the delay we had some unexpected issues come up and like we couldnt deliver on time but were working on it and should have everything ready by next Monday. ghost professional apology email",
        "(Professional apology email)",
        trigger_word="ghost"
    )
    
    test_case(
        "Client Update - Technical to Simple",
        "So basically the API is throwing 500 errors because the database connection pool is exhausted and we need to increase the max connections and add some retry logic. ghost explain to non-technical client",
        "(Simple explanation for client)",
        trigger_word="ghost"
    )
    
    test_case(
        "Proposal Response",
        "Thanks for sending over the proposal um I think the pricing looks good but like we need to discuss the timeline a bit more and also I have some questions about the support terms. ghost formal response",
        "(Formal business response)",
        trigger_word="ghost"
    )
    
    # ========== 日常办公场景 ==========
    print("\n\n" + "🏢"*30)
    print("Daily Office Scenarios")
    print("🏢"*30)
    
    test_case(
        "Calendar Invite Description",
        "Hey lets meet tomorrow at 2 to talk about the new feature requirements and maybe go over the designs if we have time. ghost calendar invite",
        "(Professional calendar invite)",
        trigger_word="ghost"
    )
    
    test_case(
        "Out of Office",
        "Im gonna be out next week for vacation so like if you need anything urgent just ping Sarah shes covering for me. ghost out of office message",
        "(Professional OOO message)",
        trigger_word="ghost"
    )
    
    test_case(
        "Performance Review Notes",
        "So John has been doing really good work this quarter like he delivered the payment feature on time and helped onboard the new guy and hes always willing to help out. ghost formal review",
        "(Formal performance review)",
        trigger_word="ghost"
    )
    
    # ========== 翻译场景 ==========
    print("\n\n" + "🌍"*30)
    print("Translation Scenarios")
    print("🌍"*30)
    
    test_case(
        "English to Chinese - Business",
        "We are pleased to inform you that your application has been approved and we look forward to working with you. ghost translate to Chinese",
        "(Chinese translation)",
        trigger_word="ghost"
    )
    
    test_case(
        "English to Spanish",
        "The meeting has been rescheduled to next Tuesday at 3 PM please confirm your availability. ghost translate to Spanish",
        "(Spanish translation)",
        trigger_word="ghost"
    )
    
    # ========== 特殊格式场景 ==========
    print("\n\n" + "📝"*30)
    print("Special Format Scenarios")
    print("📝"*30)
    
    test_case(
        "List Creation",
        "We need to buy milk eggs bread cheese and some vegetables for dinner. ghost make a list",
        "(Formatted list)",
        trigger_word="ghost"
    )
    
    test_case(
        "Action Items",
        "So from the meeting we need to update the docs and fix the login bug and schedule a call with the vendor and review the contract. ghost action items",
        "(Action items list)",
        trigger_word="ghost"
    )
    
    test_case(
        "Name Spelling - American Style",
        "My name is Sean S E A N not Shawn",
        "My name is Sean (spelling confirmation removed)",
        trigger_word="ghost"
    )
    
    test_case(
        "Name Spelling - With Company",
        "Please contact Jennifer at Acme Corp thats J E N N I F E R",
        "Please contact Jennifer at Acme Corp",
        trigger_word="ghost"
    )
    
    # ========== 边界情况 ==========
    print("\n\n" + "⚠️"*30)
    print("Edge Cases")
    print("⚠️"*30)
    
    test_case(
        "Heavy Filler Words",
        "So like um you know basically I was thinking that like maybe we should um you know consider like changing the approach or whatever",
        "(Clean version without fillers)",
        trigger_word="ghost"
    )
    
    test_case(
        "Mixed Casual and Technical",
        "So the thing is like the microservices architecture is causing latency issues cuz of too many network hops and stuff. ghost technical document",
        "(Technical documentation style)",
        trigger_word="ghost"
    )
    
    test_case(
        "Very Long Rambling Input",
        "OK so I was talking to Mike yesterday and he mentioned that the client called and they were asking about the project status and apparently theyre a bit worried because they havent heard from us in a while and I told him that we should probably send them an update but then we got busy with other stuff and forgot about it so now I think we really need to reach out to them ASAP. ghost brief summary",
        "(Brief summary)",
        trigger_word="ghost"
    )
    
    print("\n\n" + "="*70)
    print("✅ English Test Complete!")
    print("="*70)
