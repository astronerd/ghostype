# 实现计划：AI 润色功能

## 概述

将 AI 润色功能从偏好设置独立出来，实现润色配置文件系统和智能指令功能。

## 任务

- [ ] 1. 扩展导航结构和数据模型
  - [x] 1.1 扩展 NavItem 枚举，新增 aiPolish case
    - 在 `NavItem.swift` 中添加 `case aiPolish = "AI 润色"`
    - 添加对应的 icon 返回 `"wand.and.stars"`
    - 确保 aiPolish 在 memo 和 preferences 之间
    - _Requirements: 1.1, 1.2_

  - [x] 1.2 创建 PolishProfile 枚举
    - 创建 `AIInputMethod/Sources/Features/AI/PolishProfile.swift`
    - 定义 6 种预设配置：standard, professional, casual, concise, creative, custom
    - 为每种配置添加 description 和 prompt 属性
    - _Requirements: 3.1_

  - [x] 1.3 扩展 AppSettings，添加新设置项
    - 添加 defaultProfile、appProfileMapping、customProfilePrompt
    - 添加 enableInSentencePatterns、enableTriggerCommands、triggerWord
    - 添加对应的 UserDefaults Keys 和持久化逻辑
    - 设置正确的默认值
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8_

  - [ ]* 1.4 编写 Property 8 属性测试：设置持久化 Round-Trip
    - **Property 8: 设置持久化 Round-Trip**
    - **Validates: Requirements 3.4, 8.1-8.8**

- [ ] 2. 实现 Prompt 构建服务
  - [x] 2.1 创建 PromptTemplates 常量
    - 创建 `AIInputMethod/Sources/Features/AI/PromptTemplates.swift`
    - 定义各 Profile 的 Block 1 Prompt
    - 定义 Block 2（句内模式识别）Prompt
    - 定义 Block 3（句尾唤醒指令）Prompt，包含 {{trigger_word}} 占位符
    - _Requirements: 5.3-5.10, 6.5-6.10_

  - [x] 2.2 创建 PromptBuilder 服务
    - 创建 `AIInputMethod/Sources/Features/AI/PromptBuilder.swift`
    - 实现 buildPrompt 方法，根据配置动态拼接 Block 1/2/3
    - 实现 {{trigger_word}} 替换逻辑
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [ ]* 2.3 编写 Property 5 属性测试：Prompt 包含 Block 1
    - **Property 5: Prompt 包含 Block 1**
    - **Validates: Requirements 7.1**

  - [ ]* 2.4 编写 Property 6 属性测试：Prompt 条件包含 Block 2
    - **Property 6: Prompt 条件包含 Block 2**
    - **Validates: Requirements 5.2, 7.2**

  - [ ]* 2.5 编写 Property 7 属性测试：Prompt 条件包含 Block 3 并替换唤醒词
    - **Property 7: Prompt 条件包含 Block 3 并替换唤醒词**
    - **Validates: Requirements 6.3, 6.4, 7.3, 7.4**

- [x] 3. Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [ ] 4. 实现 AIPolishViewModel
  - [x] 4.1 创建 AIPolishViewModel
    - 创建 `AIInputMethod/Sources/Features/Dashboard/AIPolishViewModel.swift`
    - 绑定 AppSettings 中的相关属性
    - 实现 addAppMapping、removeAppMapping 方法
    - 实现 getProfileForApp 方法
    - _Requirements: 4.3, 4.4, 4.5, 4.6, 4.7_

  - [ ]* 4.2 编写 Property 3 属性测试：应用映射的添加和删除
    - **Property 3: 应用映射的添加和删除**
    - **Validates: Requirements 4.3, 4.4**

  - [ ]* 4.3 编写 Property 4 属性测试：Profile 查找逻辑
    - **Property 4: Profile 查找逻辑**
    - **Validates: Requirements 4.6, 4.7**

- [ ] 5. 扩展 DoubaoLLMService
  - [x] 5.1 添加 polishWithProfile 方法
    - 在 `DoubaoLLMService.swift` 中添加新方法
    - 集成 PromptBuilder 构建动态 Prompt
    - 实现短文本跳过逻辑
    - 实现禁用润色时直接返回原文
    - _Requirements: 2.3, 2.4_

  - [ ]* 5.2 编写 Property 1 属性测试：禁用润色时直接返回原文
    - **Property 1: 禁用润色时直接返回原文**
    - **Validates: Requirements 2.3**

  - [ ]* 5.3 编写 Property 2 属性测试：短文本跳过润色
    - **Property 2: 短文本跳过润色**
    - **Validates: Requirements 2.4**

- [x] 6. Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [ ] 7. 实现 AI 润色页面 UI
  - [x] 7.1 创建 AIPolishPage 视图
    - 创建 `AIInputMethod/Sources/UI/Dashboard/Pages/AIPolishPage.swift`
    - 使用 MinimalSettingsSection 组织设置区块
    - 实现基础设置区块（开关、阈值）
    - _Requirements: 2.1, 2.2, 9.1, 9.2, 9.3, 9.4_

  - [x] 7.2 实现润色配置区块
    - 添加默认配置下拉选择器
    - 添加应用专属配置列表
    - 添加「添加应用」按钮和应用选择器
    - 实现自定义 Prompt 编辑区域（选择自定义时展开）
    - _Requirements: 3.2, 3.3, 4.1, 4.2_

  - [x] 7.3 实现智能指令区块
    - 添加句内模式识别开关和示例说明
    - 添加句尾唤醒指令开关
    - 添加唤醒词输入框和示例说明
    - 使用 SF Symbols 作为图标
    - _Requirements: 5.1, 6.1, 6.2, 9.5_

- [ ] 8. 集成到 Dashboard
  - [x] 8.1 更新 DashboardView
    - 在 `DashboardView.swift` 中添加 AIPolishPage 的路由
    - 确保点击侧边栏「AI 润色」时显示正确页面
    - _Requirements: 1.3_

  - [x] 8.2 从 PreferencesPage 移除 AI 润色相关设置
    - 移除 aiPolishSection
    - 移除 promptEditorSection 中的润色 Prompt 编辑
    - 保留其他设置不变
    - _Requirements: 1.1_

- [ ] 9. 集成润色逻辑到输入流程
  - [x] 9.1 更新语音输入处理流程
    - 在语音转录完成后，调用 polishWithProfile 而非原有 polish 方法
    - 传入当前应用 BundleID 以获取正确的 Profile
    - _Requirements: 4.5_

- [x] 10. 最终 Checkpoint
  - 确保所有测试通过，如有问题请询问用户。
  - 手动测试完整流程：导航、设置、润色效果

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加快 MVP 开发
- 每个任务都引用了具体的需求编号以便追溯
- Checkpoint 用于确保增量验证
- 属性测试验证通用正确性属性
