# 实施计划：润色风格卡片 & 共享应用选择器

## 概述

按增量方式实现：先改数据模型和枚举，再改 ViewModel 和 PromptBuilder，然后实现 UI 组件，最后集成和清理。每步确保编译通过。

## 任务

- [x] 1. 数据模型和枚举重构
  - [x] 1.1 创建 CustomProfile 数据模型
    - 创建 `AIInputMethod/Sources/Features/AI/CustomProfile.swift`
    - 定义 `CustomProfile` 结构体：id (UUID)、name (String)、prompt (String)
    - 实现 Codable、Identifiable、Equatable 协议
    - _Requirements: 3.1_

  - [x] 1.2 移除 PolishProfile.custom case
    - 修改 `AIInputMethod/Sources/Features/AI/PolishProfile.swift`
    - 移除 `.custom` case 及其相关的 description、prompt 分支
    - 为每个预设风格添加 `icon` 属性（SF Symbol 名称）
    - _Requirements: 4.1_

  - [x] 1.3 更新 PromptTemplates.toneForProfile
    - 修改 `AIInputMethod/Sources/Features/AI/PromptTemplates.swift`
    - 移除 `toneForProfile` 中的 `.custom` 分支
    - _Requirements: 4.1_

  - [ ]* 1.4 编写 CustomProfile JSON 往返属性测试
    - **Property 5: CustomProfile JSON 往返一致性**
    - **Validates: Requirements 3.2, 3.3, 3.5**

- [x] 2. AppSettings 持久化层更新
  - [x] 2.1 新增 AppSettings 字段
    - 修改 `AIInputMethod/Sources/Features/Settings/AppSettings.swift`
    - 新增 `customProfiles: [CustomProfile]` 属性（JSON 编码存储到 UserDefaults）
    - 新增 `selectedProfileId: String` 属性（替代 `defaultProfile`）
    - 保留 `defaultProfile` 作为兼容读取，但写入使用 `selectedProfileId`
    - 移除 `customProfilePrompt` 字段
    - 新增 UserDefaults Keys：`customProfiles`、`selectedProfileId`
    - 实现 customProfiles 的 JSON encode/decode 逻辑
    - _Requirements: 3.2, 3.3, 3.4_

- [x] 3. Checkpoint - 确保编译通过
  - 修复了 PromptBuilder.swift（移除 .custom 判断，改为检查 customPrompt 非空）
  - 重写了 AIPolishViewModel.swift（selectedProfileId、customProfiles、CRUD、resolveProfile）
  - 修复了 AIInputMethodApp.swift（使用 resolveProfile(for:)）
  - 重写了 AIPolishPage.swift（移除 .custom 和 customProfilePrompt 引用）
  - swift build -c release 编译通过 ✅

- [x] 4. ViewModel 层重构
  - [x] 4.1 重构 AIPolishViewModel
    - 修改 `AIInputMethod/Sources/Features/Dashboard/AIPolishViewModel.swift`
    - 替换 `defaultProfile: PolishProfile` 为 `selectedProfileId: String`
    - 替换 `customProfilePrompt: String` 为 `customProfiles: [CustomProfile]`
    - 实现 `selectProfile(id:)` 方法
    - 实现 `addCustomProfile(name:prompt:)` 方法
    - 实现 `updateCustomProfile(id:name:prompt:)` 方法
    - 实现 `deleteCustomProfile(id:)` 方法（含级联逻辑：重置 selectedProfileId 和 appProfileMapping）
    - 修改 `appProfileMapping` 值类型为 `[String: String]`（BundleID → ProfileID）
    - 修改 `getProfileForApp(bundleId:)` → `resolveProfile(for:)` 返回 `(profile: PolishProfile?, customPrompt: String?)`
    - _Requirements: 1.3, 2.3, 2.6, 2.7, 7.2, 7.3_

  - [ ]* 4.2 编写 ViewModel 属性测试
    - **Property 1: 单选不变量**
    - **Property 2: 创建自定义风格后可查询**
    - **Property 3: 删除自定义风格后不可查询**
    - **Property 4: 删除选中的自定义风格回退为默认**
    - **Property 9: 应用配置映射存储**
    - **Property 10: 级联删除重置应用映射**
    - **Validates: Requirements 1.3, 2.3, 2.6, 2.7, 6.3, 7.2, 7.3**

- [x] 5. PromptBuilder 适配
  - [x] 5.1 修改 PromptBuilder 调用方式
    - 修改 `AIInputMethod/Sources/Features/AI/PromptBuilder.swift`
    - 移除对 `profile == .custom` 的判断，改为检查 `customPrompt` 是否非空
    - 当 `customPrompt` 非空时，使用它作为 Block 4 Tone；否则使用 `profile.prompt`
    - _Requirements: 4.2, 4.3_

  - [ ]* 5.2 编写 PromptBuilder 属性测试
    - **Property 7: PromptBuilder 使用正确的 Tone**
    - **Validates: Requirements 4.2, 4.3**

- [x] 6. 更新 AppDelegate 调用链
  - [x] 6.1 修改 processPolish 方法
    - 修改 `AIInputMethod/Sources/AIInputMethodApp.swift` 中的 `processPolish` 方法
    - 使用 `AIPolishViewModel.resolveProfile(for:)` 获取 profile 和 customPrompt
    - 传递给 `GeminiService.polishWithProfile`
    - _Requirements: 4.2, 4.3_

- [x] 7. Checkpoint - 确保编译通过
  - Task 3 checkpoint 已覆盖所有改动，编译通过 ✅

- [x] 8. 共享应用选择器组件
  - [x] 8.1 创建 AppPickerSheet 组件
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Components/AppPickerSheet.swift`
    - 扫描 /Applications、~/Applications、/System/Applications
    - 搜索过滤、onSelect 回调、InstalledAppInfo 结构体
    - 从 PreferencesPage 移除旧 AppPickerSheet 和 RunningAppInfo
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Components/AppPickerSheet.swift`
    - 替换现有 PreferencesPage 中的 AppPickerSheet（删除旧实现）
    - 实现已安装应用扫描逻辑（/Applications、~/Applications、/System/Applications）
    - 实现搜索过滤（localizedCaseInsensitiveContains）
    - 使用 `onSelect: (String) -> Void` 回调返回 bundleId
    - 定义 `InstalledAppInfo` 结构体
    - 遵循 DS 设计系统样式
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.4_

  - [ ]* 8.2 编写搜索过滤属性测试
    - **Property 8: 应用名称搜索过滤**
    - **Validates: Requirements 5.3, 5.5**

- [x] 9. AI 润色风格卡片 UI
  - [x] 9.1 实现风格卡片布局
    - LazyVGrid 展示预设风格卡片（图标 + 名称 + 描述）
    - 选中卡片高亮边框，末尾「+」虚线卡片
    - 自定义风格卡片显示编辑和删除按钮
  - [x] 9.2 实现自定义风格创建/编辑 UI
    - .sheet 弹窗，名称输入框 + Prompt 文本编辑器
    - 空名称或空 Prompt 时禁用保存按钮
  - [x] 9.3 更新应用专属配置的风格选择器
    - Picker 展示预设风格 + 自定义风格，使用 profileId 字符串
    - 修改 `AIInputMethod/Sources/UI/Dashboard/Pages/AIPolishPage.swift`
    - 将 `profileSettingsSection` 重构为卡片式布局
    - 区块标题改为「AI 润色风格」
    - 使用 LazyVGrid 展示预设风格卡片（图标 + 名称 + 描述）
    - 选中卡片使用高亮边框
    - 末尾添加「+」卡片
    - 自定义风格卡片显示编辑和删除按钮
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.4_

  - [ ] 9.2 实现自定义风格创建/编辑 UI
    - 在 AIPolishPage 中添加创建/编辑自定义风格的弹窗或内联表单
    - 包含名称输入框和 Prompt 文本编辑器
    - 空名称或空 Prompt 时禁用保存按钮
    - _Requirements: 2.2, 2.3, 2.5_

  - [ ] 9.3 更新应用专属配置的风格选择器
    - 修改 `appProfileRow` 中的 Picker，展示预设风格 + 自定义风格
    - 使用 profileId 字符串作为选择值
    - _Requirements: 7.1, 7.2_

- [x] 10. 集成应用选择器
  - [x] 10.1 AIPolishPage 集成 AppPickerSheet
    - 替换 NSOpenPanel 为 AppPickerSheet .sheet
  - [x] 10.2 PreferencesPage 集成 AppPickerSheet
    - 更新 .sheet 调用使用新 AppPickerSheet(onSelect:isPresented:)
    - 删除旧 AppPickerSheet 和 RunningAppInfo
    - 替换 `showAppPicker()` 中的 NSOpenPanel 为 AppPickerSheet
    - 使用 `.sheet` modifier 展示
    - _Requirements: 6.1, 6.3_

  - [ ] 10.2 PreferencesPage 集成 AppPickerSheet
    - 修改 `autoEnterSection` 使用新的 AppPickerSheet
    - 删除旧的 `RunningAppInfo` 和 `loadRunningApps` 逻辑
    - _Requirements: 6.2, 6.3_

- [x] 11. 本地化
  - [x] 11.1 添加新的本地化字符串
    - 在 Strings.swift 中添加新的 key（风格卡片相关文案）
    - 在 Strings+Chinese.swift 和 Strings+English.swift 中添加翻译
    - 包括：搜索占位符、创建自定义风格、编辑、确认删除等文案
    - _Requirements: 所有 UI 相关需求_

- [x] 12. 最终 Checkpoint
  - 确保所有测试通过，如有问题请询问用户。

## 备注

- 标记 `*` 的任务为可选测试任务，可跳过以加速 MVP
- 每个任务引用具体需求以确保可追溯性
- Checkpoint 确保增量验证
- 属性测试验证通用正确性属性
- 单元测试验证具体示例和边界情况
