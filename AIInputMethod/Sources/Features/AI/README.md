# AI 模块

## 概述

AI 模块负责与大语言模型（LLM）交互，提供文本润色和翻译功能。

## 文件结构

```
Features/AI/
├── README.md                 # 本文档
├── DoubaoLLMService.swift    # 豆包 LLM 服务（主要）
├── MiniMaxService.swift      # MiniMax LLM 服务（备用）
├── PromptBuilder.swift       # Prompt 动态构建器
├── PromptTemplates.swift     # Prompt 模板常量
├── InputMode.swift           # 输入模式枚举
└── PolishProfile.swift       # 润色配置文件枚举
```

## 文件说明

### DoubaoLLMService.swift
豆包大模型服务，单例模式。

**职责**：
- 文本润色（polish）
- 文本翻译（translate）
- 随心记处理（organizeMemo）

**关键方法**：
- `polish(text:customPrompt:completion:)` - 基础润色
- `polishWithProfile(text:profile:...)` - 使用配置文件润色
- `translate(text:language:completion:)` - 翻译

**依赖**：
- `AppSettings` - 读取润色开关、阈值等设置
- `PromptBuilder` - 构建动态 Prompt

**⚠️ 问题**：API Key 硬编码在第 24 行

### MiniMaxService.swift
MiniMax 2.1 AI 服务，作为备用服务商。

**职责**：
- 与 DoubaoLLMService 功能相同
- 使用 Anthropic 兼容 API 格式

**⚠️ 问题**：API Key 使用 Base64 编码存储（伪安全）

### PromptBuilder.swift
Prompt 动态构建服务。

**职责**：
- 根据配置拼接 Block 1/2/3 生成最终 Prompt
- Block 1: 基础润色（根据 Profile 选择）
- Block 2: 句内模式识别（可选）
- Block 3: 句尾唤醒指令（可选）

**关键方法**：
- `buildPrompt(profile:customPrompt:enableInSentencePatterns:enableTriggerCommands:triggerWord:)` - 构建完整 Prompt

### PromptTemplates.swift
Prompt 模板常量定义。

**内容**：
- `block2` - 句内模式识别 Prompt（中英文双语）
- `block3` - 句尾唤醒指令 Prompt（使用 `{{trigger_word}}` 占位符）

### InputMode.swift
输入模式枚举。

**模式**：
- `.polish` - AI 润色后上屏（默认）
- `.translate` - 中英互译后上屏
- `.memo` - 记录到笔记本，不上屏

**属性**：
- `displayName` - 显示名称
- `icon` - SF Symbol 图标
- `color` - 模式颜色

### PolishProfile.swift
润色配置文件枚举。

**配置**：
- `.standard` - 默认：去口语化、修语法、保原意
- `.professional` - 专业/商务：正式书面语
- `.casual` - 轻松/社交：保留口语感
- `.concise` - 简洁：精简压缩
- `.creative` - 创意/文学：润色+美化
- `.custom` - 自定义 Prompt

## 数据流

```
用户输入 → InputMode 判断
    ↓
PromptBuilder.buildPrompt() 构建 Prompt
    ↓
DoubaoLLMService.polishWithProfile() 调用 LLM
    ↓
返回润色/翻译结果
```

## 待重构项

1. **API Key 安全存储**：移到 Keychain 或环境变量
2. **统一服务接口**：定义 `LLMServiceProtocol`，消除重复代码
3. **错误类型统一**：`DoubaoError` 和 `MiniMaxError` 应统一为 `LLMError`
