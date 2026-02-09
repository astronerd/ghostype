# 需求文档：润色风格卡片 & 共享应用选择器

## 简介

本功能包含两部分改造：
1. 将 AI 润色页面的「润色配置」下拉选择器重新设计为卡片式布局，支持多个自定义风格
2. 创建一个共享的应用选择器组件（AppPickerSheet），替换「应用专属配置」的 NSOpenPanel 和「自动回车」的运行中应用列表

## 术语表

- **Style_Card（风格卡片）**：展示润色风格名称和描述的可点击卡片 UI 元素
- **Preset_Style（预设风格）**：系统内置的 5 种润色风格（默认、专业、活泼、简洁、创意）
- **Custom_Style（自定义风格）**：用户创建的润色风格，包含名称和 Prompt 文本
- **CustomProfile**：存储自定义风格数据的结构体，包含 id（UUID）、name（String）、prompt（String）
- **Selected_Profile_ID（选中配置 ID）**：标识当前选中风格的字符串，预设风格使用 rawValue，自定义风格使用 UUID 字符串
- **AppPickerSheet（应用选择器）**：扫描已安装应用并提供搜索、选择功能的 SwiftUI Sheet 组件
- **App_Directory（应用目录）**：系统扫描已安装应用的路径，包括 `/Applications`、`~/Applications`、`/System/Applications`
- **PolishProfile**：润色配置枚举，保留 5 个预设 case，移除 `.custom` case
- **AIPolishPage**：AI 润色设置页面
- **PreferencesPage**：偏好设置页面
- **AppSettings**：全局设置单例，使用 UserDefaults 持久化

## 需求

### 需求 1：风格卡片布局

**用户故事：** 作为用户，我希望通过直观的卡片界面选择润色风格，以便快速切换不同的 AI 润色效果。

#### 验收标准

1. THE AIPolishPage SHALL 将「润色配置」区块标题更改为「AI 润色风格」
2. THE AIPolishPage SHALL 以水平排列的卡片形式展示 5 个 Preset_Style（默认、专业、活泼、简洁、创意）
3. WHEN 用户点击一个 Style_Card，THE AIPolishPage SHALL 将该卡片设为高亮选中状态，并取消其他卡片的选中状态
4. THE Style_Card SHALL 展示风格名称和简短描述文本

### 需求 2：自定义风格管理

**用户故事：** 作为用户，我希望创建、编辑和删除自定义润色风格，以便根据不同场景使用个性化的 AI 润色指令。

#### 验收标准

1. THE AIPolishPage SHALL 在预设风格卡片末尾展示一个「+」卡片，用于创建自定义风格
2. WHEN 用户点击「+」卡片，THE AIPolishPage SHALL 展示输入界面，允许用户填写风格名称和 Prompt 文本
3. WHEN 用户提交有效的名称和 Prompt，THE System SHALL 创建一个 CustomProfile 并持久化存储
4. THE Custom_Style 卡片 SHALL 展示编辑和删除按钮
5. WHEN 用户点击编辑按钮，THE AIPolishPage SHALL 展示编辑界面，允许修改名称和 Prompt
6. WHEN 用户点击删除按钮，THE System SHALL 移除该 CustomProfile 并更新 UI
7. WHEN 用户删除当前选中的自定义风格，THE System SHALL 将选中配置回退为「默认」预设风格

### 需求 3：自定义风格数据模型

**用户故事：** 作为开发者，我希望自定义风格有清晰的数据模型和持久化方案，以便可靠地存储和读取用户创建的风格。

#### 验收标准

1. THE CustomProfile SHALL 包含 id（UUID）、name（String）、prompt（String）三个字段
2. THE System SHALL 将 CustomProfile 数组以 JSON 格式存储在 UserDefaults 中
3. WHEN 应用启动时，THE System SHALL 从 UserDefaults 加载已保存的 CustomProfile 数组
4. THE System SHALL 使用字符串 ID 标识选中的配置：预设风格使用 PolishProfile 的 rawValue，自定义风格使用 UUID 字符串
5. FOR ALL 有效的 CustomProfile 对象，序列化为 JSON 再反序列化 SHALL 产生等价的对象（往返一致性）

### 需求 4：PolishProfile 枚举重构

**用户故事：** 作为开发者，我希望移除 PolishProfile 枚举中的 `.custom` case，以便数据模型更清晰地区分预设风格和自定义风格。

#### 验收标准

1. THE PolishProfile 枚举 SHALL 仅保留 5 个预设 case：standard、professional、casual、concise、creative
2. WHEN PromptBuilder 构建 Prompt 时，IF 选中的是自定义风格，THEN THE PromptBuilder SHALL 使用 CustomProfile 的 prompt 字段作为 Tone 配置
3. WHEN PromptBuilder 构建 Prompt 时，IF 选中的是预设风格，THEN THE PromptBuilder SHALL 使用 PromptTemplates 中对应的 Tone 配置
4. THE System SHALL 更新所有引用 `.custom` case 的代码，确保编译通过

### 需求 5：共享应用选择器组件

**用户故事：** 作为用户，我希望通过统一的应用选择器界面添加应用，以便在「应用专属配置」和「自动回车」中获得一致的体验。

#### 验收标准

1. THE AppPickerSheet SHALL 扫描 `/Applications`、`~/Applications`、`/System/Applications` 三个目录中的已安装应用
2. THE AppPickerSheet SHALL 展示每个应用的图标和名称
3. THE AppPickerSheet SHALL 在顶部提供搜索栏，支持按应用名称实时过滤
4. WHEN 用户点击一个应用，THE AppPickerSheet SHALL 通过回调返回该应用的 bundleId
5. WHEN 搜索关键词与应用名称匹配时，THE AppPickerSheet SHALL 仅展示匹配的应用（不区分大小写）

### 需求 6：应用选择器集成

**用户故事：** 作为用户，我希望「应用专属配置」和「自动回车」都使用新的应用选择器，以便替代旧的 NSOpenPanel 和不完整的运行中应用列表。

#### 验收标准

1. THE AIPolishPage SHALL 使用 AppPickerSheet 替代 NSOpenPanel 来添加应用专属配置
2. THE PreferencesPage SHALL 使用 AppPickerSheet 替代当前基于运行中应用的选择器
3. WHEN 用户通过 AppPickerSheet 选择应用后，THE System SHALL 将该应用添加到对应的配置列表中
4. IF AppPickerSheet 扫描目录时遇到无法读取的应用，THEN THE System SHALL 跳过该应用并继续扫描其余应用

### 需求 7：应用专属配置支持自定义风格

**用户故事：** 作为用户，我希望在应用专属配置中也能选择自定义风格，以便为不同应用设置个性化的润色效果。

#### 验收标准

1. THE 应用专属配置的风格选择器 SHALL 同时展示预设风格和用户创建的自定义风格
2. WHEN 用户为某个应用选择自定义风格，THE System SHALL 将该应用的配置映射存储为自定义风格的 UUID 字符串
3. WHEN 应用专属配置引用的自定义风格被删除，THE System SHALL 将该应用的配置回退为「默认」预设风格
