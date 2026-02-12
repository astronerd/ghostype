# 需求文档：Ghost Morph

## 简介

Ghost Morph 是 GHOSTYPE macOS 语音输入法的核心功能升级，将现有的硬编码 InputMode 枚举（polish/translate/memo）替换为动态的 Skill 系统。用户可以通过修饰键组合激活不同的 Skill，每个 Skill 拥有独立的 prompt 模板和行为配置。Skill 以 Markdown 文件（YAML frontmatter + markdown body）存储在本地，支持用户自定义创建、编辑、删除和按键绑定。系统根据光标/选中状态自动选择四种上下文行为之一，并在无法直接输入时通过悬浮结果卡片展示 AI 输出。

## 术语表

- **Skill**：一个可激活的 AI 功能单元，包含名称、描述、图标、prompt 模板、修饰键绑定和行为配置，以 SKILL.md 文件存储
- **SKILL.md**：Skill 的存储文件格式，包含 YAML frontmatter（id、name、description、icon、modifier_key、behavior 等元数据）和 markdown body（prompt 模板/说明）
- **Modifier_Key**：用户在按住主触发键（如 Option）的同时按下的附加按键，用于激活对应的 Skill
- **Context_Behavior**：系统根据光标和选中状态自动选择的四种行为模式之一
- **Direct_Output**：上下文行为之一，光标在可输入区域且无选中文字时，AI 处理结果直接插入光标位置
- **Rewrite**：上下文行为之一，光标在可输入区域且有选中文字时，AI 结合语音和选中文字进行改写并替换选中内容
- **Explain**：上下文行为之一，光标在不可输入区域且有选中文字时，AI 结合语音和选中文字生成解释，通过悬浮卡片展示
- **No_Input**：上下文行为之一，光标在不可输入区域且无选中文字时，AI 处理语音后通过悬浮卡片展示结果
- **Floating_Result_Card**：悬浮结果卡片，用于在无法直接插入文字的场景下展示 Skill 名称、用户语音原文和 AI 输出
- **Builtin_Skill**：应用内置的 Skill，prompt 不可编辑，但部分配置项（如翻译语言）可编辑
- **Custom_Skill**：用户自定义创建的 Skill，所有字段均可编辑
- **Ghost_Twin**：GHOSTYPE 的 AI 人格分身，拥有独立的等级系统和人格档案，使用独立的 API 端点
- **Ghost_Command**：内置 Skill 之一，用户说出任意指令，AI 直接生成内容输出
- **Skill_Storage_Directory**：Skill 文件的本地存储目录，位于 `~/Library/Application Support/GHOSTYPE/skills/`
- **OverlayView**：现有的录音/处理状态浮层，与 Floating_Result_Card 是不同的 UI 组件
- **AppDelegate**：应用主委托，负责快捷键回调、AI 处理分发和文字插入

## 需求

### 需求 1：Skill 数据模型与存储

**用户故事：** 作为开发者，我希望有一个灵活的 Skill 数据模型和本地文件存储系统，以便支持内置和自定义 Skill 的管理。

#### 验收标准

1. THE Skill_Model SHALL 包含以下字段：id（UUID 字符串）、name（显示名称）、description（功能描述）、icon（SF Symbol 名称）、modifier_key（绑定的按键标识）、prompt_template（prompt 模板文本）、behavior_config（行为配置字典）、is_builtin（是否内置）、is_editable（是否可编辑 prompt）
2. WHEN 应用首次启动且 Skill_Storage_Directory 不存在时，THE Skill_Manager SHALL 创建该目录并写入所有 Builtin_Skill 的 SKILL.md 文件
3. THE SKILL.md_Parser SHALL 将 SKILL.md 文件解析为 Skill_Model 对象，文件格式为 YAML frontmatter（以 `---` 分隔）加 markdown body
4. THE SKILL.md_Printer SHALL 将 Skill_Model 对象序列化为合法的 SKILL.md 文件内容
5. FOR ALL 合法的 Skill_Model 对象，解析（parse）然后打印（print）再解析（parse）SHALL 产生等价的 Skill_Model 对象（round-trip 属性）
6. WHEN 从 Skill_Storage_Directory 加载 Skill 列表时，THE Skill_Manager SHALL 读取目录下所有子文件夹中的 SKILL.md 文件并解析为 Skill_Model 数组
7. THE Skill_Manager SHALL 提供默认的四个 Builtin_Skill：随心记（Memo）、Ghost Command、Call Ghost Twin、翻译（Translate）

### 需求 2：修饰键绑定系统

**用户故事：** 作为用户，我希望能将任意按键绑定到 Skill 上，以便通过快捷键快速激活不同的 AI 功能。

#### 验收标准

1. WHEN 用户按住主触发键并按下已绑定的 Modifier_Key 时，THE HotkeyManager SHALL 识别该按键并激活对应的 Skill
2. THE Modifier_Key_Binding SHALL 支持系统修饰键（Shift、Command、Control、Fn）和任意普通按键（如 CapsLock、字母键等）
3. WHEN 用户尝试将一个按键绑定到 Skill 且该按键已被其他 Skill 绑定时，THE Skill_Manager SHALL 显示冲突警告并要求用户确认或取消
4. WHEN 用户修改 Skill 的 Modifier_Key 绑定时，THE Skill_Manager SHALL 将更新后的绑定持久化到对应的 SKILL.md 文件
5. THE HotkeyManager SHALL 在启动时从 Skill_Manager 加载所有 Skill 的按键绑定映射，替代现有的 AppSettings.modeFromModifiers() 逻辑
6. WHEN 没有按下任何 Modifier_Key 时（仅按住主触发键说话），THE HotkeyManager SHALL 使用默认的润色（polish）行为

### 需求 3：上下文行为检测与分发

**用户故事：** 作为用户，我希望系统能根据当前光标和选中状态自动选择合适的行为，以便在不同场景下获得最佳体验。

#### 验收标准

1. WHEN 用户松开主触发键时，THE Context_Detector SHALL 检测当前光标是否在可输入区域以及是否有选中文字
2. WHEN 光标在可输入区域且无选中文字时，THE AppDelegate SHALL 执行 Direct_Output 行为：将 AI 处理结果插入光标位置
3. WHEN 光标在可输入区域且有选中文字时，THE AppDelegate SHALL 执行 Rewrite 行为：将语音文本和选中文字一起发送给 AI，用返回结果替换选中内容
4. WHEN 光标在不可输入区域且有选中文字时，THE AppDelegate SHALL 执行 Explain 行为：将语音文本和选中文字一起发送给 AI，通过 Floating_Result_Card 展示结果
5. WHEN 光标在不可输入区域且无选中文字时，THE AppDelegate SHALL 执行 No_Input 行为：将语音文本发送给 AI，通过 Floating_Result_Card 展示结果
6. THE Context_Detector SHALL 通过 macOS Accessibility API 获取当前焦点元素的可编辑状态和选中文字内容

### 需求 4：Floating Result Card（悬浮结果卡片）

**用户故事：** 作为用户，我希望在无法直接输入文字的场景下，能通过悬浮卡片查看 AI 输出并复制内容。

#### 验收标准

1. THE Floating_Result_Card SHALL 是一个独立于 OverlayView 的新 UI 组件
2. WHEN Explain 或 No_Input 行为触发时，THE Floating_Result_Card SHALL 显示以下内容：Skill 图标和名称、用户语音原文、AI 处理结果
3. THE Floating_Result_Card SHALL 提供复制到剪贴板按钮，点击后将 AI 处理结果复制到系统剪贴板
4. THE Floating_Result_Card SHALL 提供分享按钮
5. THE Floating_Result_Card SHALL 出现在光标附近位置，如果无法获取光标位置则显示在屏幕中央
6. WHEN 用户点击 Floating_Result_Card 外部区域或按下 Escape 键时，THE Floating_Result_Card SHALL 关闭并释放资源
7. THE Floating_Result_Card SHALL 使用毛玻璃背景效果，与 GHOSTYPE 整体设计风格保持一致

### 需求 5：内置 Skill 定义

**用户故事：** 作为用户，我希望应用自带常用的 AI 功能，以便开箱即用。

#### 验收标准

1. THE Memo_Skill SHALL 将用户语音文本保存到 CoreData，不调用 AI API，行为配置支持设置是否先润色再保存
2. THE Ghost_Command_Skill SHALL 将用户语音文本作为指令发送给 AI（通过 /api/v1/llm/chat），AI 生成内容后输出，prompt 为固定内容不可由用户编辑
3. THE Call_Ghost_Twin_Skill SHALL 将用户语音文本发送到独立的 Ghost Twin API 端点（非 /api/v1/llm/chat），该端点使用用户的人格档案作为系统 prompt
4. THE Call_Ghost_Twin_Skill 的 Dashboard 卡片 SHALL 显示当前 Ghost Twin 等级，格式为 "Ghost Twin Lv.{level}"
5. THE Translate_Skill SHALL 将用户语音文本发送给翻译 API（/api/v1/llm/chat，mode="translate"），行为配置支持设置目标翻译语言
6. WHEN 默认润色模式（无 Modifier_Key）激活时，THE AppDelegate SHALL 使用现有的 polish 逻辑处理语音文本，保持与当前系统完全一致的行为
7. THE Builtin_Skill 的默认 Modifier_Key 绑定 SHALL 为：Shift → 随心记（Memo）、Command → Ghost Command，Call Ghost Twin 和 Translate 由用户自行绑定

### 需求 6：自定义 Skill 管理

**用户故事：** 作为用户，我希望能创建自己的 AI Skill，以便满足个性化需求。

#### 验收标准

1. WHEN 用户创建新的 Custom_Skill 时，THE Skill_Manager SHALL 在 Skill_Storage_Directory 下创建新的子文件夹并写入 SKILL.md 文件
2. WHEN 用户编辑 Custom_Skill 的名称、描述、图标、prompt 模板或行为配置时，THE Skill_Manager SHALL 将修改持久化到对应的 SKILL.md 文件
3. WHEN 用户删除一个 Skill 时，THE Skill_Manager SHALL 从 Skill_Storage_Directory 中移除对应的子文件夹，并释放该 Skill 绑定的 Modifier_Key
4. THE Custom_Skill SHALL 通过 /api/v1/llm/chat 端点发送请求，将 SKILL.md 中的 prompt 模板作为自定义 prompt
5. IF 用户尝试删除一个 Builtin_Skill，THEN THE Skill_Manager SHALL 阻止删除操作并提示用户内置 Skill 不可删除

### 需求 7：Dashboard Skill 管理界面

**用户故事：** 作为用户，我希望在 Dashboard 中有一个直观的界面来查看和管理所有 Skill。

#### 验收标准

1. THE Dashboard SHALL 包含一个 Skill 管理页面，展示所有已安装的 Skill 列表
2. WHEN 显示 Skill 列表时，THE Dashboard SHALL 以卡片形式展示每个 Skill 的图标、名称、绑定的 Modifier_Key 和简短描述
3. WHEN 用户点击 Custom_Skill 卡片的编辑按钮时，THE Dashboard SHALL 打开编辑界面，允许修改名称、描述、图标、prompt 模板和行为配置
4. WHEN 用户点击 Builtin_Skill 卡片时，THE Dashboard SHALL 显示 Skill 介绍信息，prompt 不可编辑，但可编辑的配置项（如翻译语言、随心记是否润色）SHALL 可修改
5. THE Dashboard SHALL 提供"添加 Skill"按钮，点击后引导用户创建新的 Custom_Skill
6. WHEN 用户在 Skill 卡片上修改 Modifier_Key 绑定时，THE Dashboard SHALL 实时检测按键冲突并显示警告

### 需求 8：API 集成与路由

**用户故事：** 作为开发者，我希望 Skill 系统能正确路由到不同的 API 端点，以便每个 Skill 获得正确的 AI 处理。

#### 验收标准

1. WHEN 一个 Skill 被激活且需要 AI 处理时，THE Skill_Router SHALL 根据 Skill 的类型选择正确的 API 端点和请求参数
2. THE Skill_Router SHALL 将 Memo_Skill 的请求路由到本地 CoreData 保存，不发送 API 请求
3. THE Skill_Router SHALL 将 Translate_Skill 的请求路由到 /api/v1/llm/chat（mode="translate"），附带用户配置的翻译语言参数
4. THE Skill_Router SHALL 将 Ghost_Command_Skill 的请求路由到 /api/v1/llm/chat，使用 Ghost Command 专用的固定 prompt
5. THE Skill_Router SHALL 将 Call_Ghost_Twin_Skill 的请求路由到独立的 Ghost Twin API 端点（区别于 /api/v1/llm/chat），该端点使用用户人格档案作为系统 prompt
6. THE Skill_Router SHALL 将 Custom_Skill 的请求路由到 /api/v1/llm/chat，使用 SKILL.md 中定义的 prompt 模板作为 custom_prompt
7. IF API 请求失败，THEN THE Skill_Router SHALL 在 Direct_Output 和 Rewrite 行为下回退插入原始语音文本，在 Explain 和 No_Input 行为下在 Floating_Result_Card 中显示错误信息

### 需求 9：从旧系统迁移

**用户故事：** 作为现有用户，我希望升级后原有的修饰键配置和功能能平滑过渡到新的 Skill 系统。

#### 验收标准

1. WHEN 应用升级且检测到旧版 AppSettings 中存在 translateModifier 和 memoModifier 配置时，THE Migration_Service SHALL 将这些配置迁移为对应 Builtin_Skill 的 Modifier_Key 绑定
2. WHEN 迁移完成后，THE Migration_Service SHALL 标记迁移状态为已完成，避免重复迁移
3. THE Migration_Service SHALL 保留用户在旧系统中设置的翻译语言偏好，将其写入 Translate_Skill 的行为配置中
