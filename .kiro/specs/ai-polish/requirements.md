# 需求文档

## 简介

将 AI 润色功能从偏好设置中独立出来，作为 Dashboard 侧边栏的独立 Section。提供润色配置文件（Profile）系统支持多种润色风格，并实现智能指令功能（句内模式识别和句尾唤醒指令）。

## 术语表

- **Dashboard**：GhosTYPE 应用的主控制台界面
- **Sidebar**：Dashboard 左侧的导航栏
- **Profile**：润色配置文件，定义特定的润色风格和 Prompt
- **BundleID**：macOS 应用的唯一标识符
- **Block_1**：基础润色 Prompt，根据 Profile 选择
- **Block_2**：句内模式识别 Prompt，处理拆字、换行等即时替换
- **Block_3**：句尾唤醒指令 Prompt，处理翻译、格式转换等指令
- **Trigger_Word**：唤醒词，用于触发句尾指令
- **LLM_Service**：大语言模型服务，负责文本润色和指令处理

## 需求

### 需求 1：导航结构变更

**用户故事：** 作为用户，我希望在侧边栏看到独立的 AI 润色入口，以便快速访问和配置润色功能。

#### 验收标准

1. THE Sidebar SHALL 在「随心记」和「偏好设置」之间新增「AI 润色」导航项
2. THE NavItem SHALL 使用 SF Symbol「wand.and.stars」作为图标
3. WHEN 用户点击「AI 润色」导航项 THEN THE Dashboard SHALL 显示 AI 润色配置页面

### 需求 2：基础设置

**用户故事：** 作为用户，我希望控制 AI 润色的开关和阈值，以便根据需要启用或禁用润色功能。

#### 验收标准

1. THE AI_Polish_Page SHALL 提供「启用 AI 润色」开关（enableAIPolish，默认 false）
2. THE AI_Polish_Page SHALL 提供「自动润色阈值」滑块（polishThreshold，默认 20 字符）
3. WHEN enableAIPolish 为 false THEN THE LLM_Service SHALL 直接输出原始转录文本
4. WHEN 文本长度小于 polishThreshold THEN THE LLM_Service SHALL 跳过 AI 润色

### 需求 3：润色配置文件系统

**用户故事：** 作为用户，我希望选择不同的润色风格，以便在不同场景下获得合适的文本输出。

#### 验收标准

1. THE Profile_System SHALL 提供 6 种预设配置：默认、专业/商务、轻松/社交、简洁、创意/文学、自定义
2. THE AI_Polish_Page SHALL 提供「默认配置」下拉选择器（defaultProfile，默认「默认」）
3. WHEN 用户选择「自定义」配置 THEN THE AI_Polish_Page SHALL 展开 Prompt 编辑区域
4. THE AppSettings SHALL 持久化 customProfilePrompt 设置

### 需求 4：应用专属配置

**用户故事：** 作为用户，我希望为不同应用设置不同的润色配置，以便在邮件中使用正式语气、在微信中使用轻松语气。

#### 验收标准

1. THE AI_Polish_Page SHALL 显示应用专属配置列表（appProfileMapping）
2. THE AI_Polish_Page SHALL 提供「添加应用」按钮，弹出应用选择器
3. WHEN 用户添加应用 THEN THE System SHALL 记录 BundleID 与 Profile 的映射关系
4. WHEN 用户删除应用映射 THEN THE System SHALL 从 appProfileMapping 中移除该条目
5. WHEN 进行润色时 THE LLM_Service SHALL 检测当前活跃应用的 BundleID
6. IF appProfileMapping 包含当前 BundleID THEN THE LLM_Service SHALL 使用对应 Profile
7. IF appProfileMapping 不包含当前 BundleID THEN THE LLM_Service SHALL 使用 defaultProfile

### 需求 5：句内模式识别（Block 2）

**用户故事：** 作为用户，我希望在说话时自动处理拆字、换行等模式，以便更自然地输入特殊内容。

#### 验收标准

1. THE AI_Polish_Page SHALL 提供「句内模式识别」开关（enableInSentencePatterns，默认 true）
2. WHEN enableInSentencePatterns 为 true THEN THE LLM_Service SHALL 在 Prompt 中包含 Block_2
3. THE Block_2 SHALL 支持中文拆字纠正（「耿直的耿」→「耿」）
4. THE Block_2 SHALL 支持英文拼写纠正（「Sara，没有H」→「Sara」）
5. THE Block_2 SHALL 支持 Emoji 插入（「找一个恶魔的emoji」→ 😈）
6. THE Block_2 SHALL 支持换行（「换行」「另起一段」→ 换行符）
7. THE Block_2 SHALL 支持破折号（「破折号」→「——」）
8. THE Block_2 SHALL 支持特殊符号（「版权符号」→ ©）
9. THE Block_2 SHALL 支持大写数字（「一百二十三，大写」→「壹佰贰拾叁」）
10. THE Block_2 SHALL 支持插入时间（「插入今天的日期」→ 当前日期）

### 需求 6：句尾唤醒指令（Block 3）

**用户故事：** 作为用户，我希望通过唤醒词加指令来执行翻译、格式转换等操作，以便快速处理文本。

#### 验收标准

1. THE AI_Polish_Page SHALL 提供「句尾唤醒指令」开关（enableTriggerCommands，默认 true）
2. THE AI_Polish_Page SHALL 提供「唤醒词」输入框（triggerWord，默认「Ghost」）
3. WHEN enableTriggerCommands 为 true THEN THE LLM_Service SHALL 在 Prompt 中包含 Block_3
4. THE Block_3 SHALL 将 {{trigger_word}} 替换为用户设置的唤醒词
5. WHEN 句尾包含「唤醒词 + 翻译指令」THEN THE LLM_Service SHALL 执行翻译
6. WHEN 句尾包含「唤醒词 + 格式指令」THEN THE LLM_Service SHALL 执行格式转换
7. WHEN 句尾包含「唤醒词 + 语气指令」THEN THE LLM_Service SHALL 调整语气
8. WHEN 句尾包含「唤醒词 + 长度指令」THEN THE LLM_Service SHALL 调整长度
9. WHEN 唤醒词出现在句中而非句尾 THEN THE LLM_Service SHALL 将其视为普通文本
10. WHEN 唤醒词在句尾但无后续指令 THEN THE LLM_Service SHALL 将其视为普通文本

### 需求 7：Prompt 动态拼接

**用户故事：** 作为系统，我需要根据用户设置动态拼接最终 Prompt，以便正确执行润色和指令处理。

#### 验收标准

1. THE LLM_Service SHALL 始终包含 Block_1（根据当前 Profile 选择）
2. IF enableInSentencePatterns 为 true THEN THE LLM_Service SHALL 追加 Block_2
3. IF enableTriggerCommands 为 true THEN THE LLM_Service SHALL 追加 Block_3
4. THE LLM_Service SHALL 在 Block_3 中将 {{trigger_word}} 替换为实际唤醒词

### 需求 8：设置持久化

**用户故事：** 作为用户，我希望我的设置在应用重启后保持不变，以便无需重复配置。

#### 验收标准

1. THE AppSettings SHALL 持久化 enableAIPolish 到 UserDefaults
2. THE AppSettings SHALL 持久化 polishThreshold 到 UserDefaults
3. THE AppSettings SHALL 持久化 defaultProfile 到 UserDefaults
4. THE AppSettings SHALL 持久化 appProfileMapping 到 UserDefaults
5. THE AppSettings SHALL 持久化 customProfilePrompt 到 UserDefaults
6. THE AppSettings SHALL 持久化 enableInSentencePatterns 到 UserDefaults
7. THE AppSettings SHALL 持久化 enableTriggerCommands 到 UserDefaults
8. THE AppSettings SHALL 持久化 triggerWord 到 UserDefaults

### 需求 9：UI 设计规范

**用户故事：** 作为用户，我希望 AI 润色页面与现有 Dashboard 风格一致，以便获得统一的视觉体验。

#### 验收标准

1. THE AI_Polish_Page SHALL 遵循 DesignSystem (DS) 的颜色、字体和间距规范
2. THE AI_Polish_Page SHALL 使用 MinimalSettingsSection 组件组织设置区块
3. THE AI_Polish_Page SHALL 使用 MinimalToggleRow 组件显示开关设置
4. THE AI_Polish_Page SHALL 使用 SF Symbols 作为图标，不使用 emoji
5. THE AI_Polish_Page SHALL 在示例区域使用浅色背景区分
