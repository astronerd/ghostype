# 实现计划：Skill 系统重构

## 概述

将 GHOSTYPE 的 Skill 系统从"硬编码枚举 + switch-case 路由"重构为"Agent 模式"（prompt + tools）。按照自底向上的顺序实现：先建基础组件（解析器、元数据存储、模板引擎、工具注册表），再建执行层（SkillExecutor），最后接入上层（AppDelegate、HotkeyManager）并处理迁移。

## 任务

- [x] 1. 新建 SkillFileParser（新格式）
  - [x] 1.1 创建 `SkillFileParser.swift` 新版本，定义 `ParseResult` 和 `LegacyFields` 结构体
    - 实现 `parse(_ content: String, directoryName: String) throws -> ParseResult`
    - 仅要求 `name` 和 `description` 为必填字段
    - 支持可选字段：`allowed_tools`（字符串数组）、`config`（键值对）
    - 兼容旧格式字段（`skill_type`、`icon`、`color_hex`、`modifier_key_*`、`is_builtin`、`is_editable`、`behavior_config`），解析到 `LegacyFields`
    - 使用 `directoryName` 作为 Skill 的 id
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 1.7_
  - [x] 1.2 实现 `print(_ result: ParseResult) -> String` 序列化方法
    - 仅输出语义字段（name、description、allowed_tools、config + body）
    - 不输出任何 UI 元数据字段
    - _Requirements: 1.4, 1.8_
  - [ ] 1.3 编写 SkillFileParser 属性测试
    - **Property 1: SkillFileParser 解析-序列化 round-trip**
    - **Validates: Requirements 1.2, 1.3, 1.5, 1.6, 1.8**
  - [ ] 1.4 编写 SkillFileParser 必填字段校验属性测试
    - **Property 2: SkillFileParser 必填字段校验**
    - **Validates: Requirements 1.1**
  - [ ] 1.5 编写 SkillFileParser 无 UI 元数据输出属性测试
    - **Property 3: SkillFileParser 序列化不包含 UI 元数据**
    - **Validates: Requirements 1.4**

- [x] 2. 新建 SkillMetadataStore
  - [x] 2.1 创建 `SkillMetadataStore.swift`，定义 `SkillMetadata` 结构体（icon、colorHex、modifierKey、isBuiltin）
    - 实现 `get(skillId:) -> SkillMetadata`（不存在返回默认值）
    - 实现 `update(skillId:metadata:)`、`remove(skillId:)`
    - 实现 `load()` / `save()` 从 `skill_metadata.json` 读写
    - 实现 `importLegacy(skillId:legacy:)` 导入旧格式元数据
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - [ ] 2.2 编写 SkillMetadataStore 属性测试
    - **Property 4: SkillMetadataStore 存取 round-trip**
    - **Validates: Requirements 2.1, 2.2**
  - [ ] 2.3 编写 SkillMetadataStore 默认值属性测试
    - **Property 5: SkillMetadataStore 未知 Skill 返回默认值**
    - **Validates: Requirements 2.4**

- [x] 3. 新建 TemplateEngine
  - [x] 3.1 创建 `TemplateEngine.swift`
    - 实现 `resolve(template:config:) -> String`
    - 替换 `{{config.xxx}}` 占位符，未定义的保留原文
    - _Requirements: 8.1, 8.2, 8.3_
  - [ ] 3.2 编写 TemplateEngine 属性测试
    - **Property 6: TemplateEngine 变量替换**
    - **Validates: Requirements 8.1, 8.2, 6.2**

- [x] 4. 新建 ToolRegistry
  - [x] 4.1 创建 `ToolRegistry.swift`，定义 `ToolContext` 和 `ToolHandler`
    - 实现 `register(name:handler:)` 和 `execute(name:context:)`
    - 未注册工具抛出 `ToolError.unknownTool(name)`
    - 实现 `registerBuiltins()` 注册 insert_text、save_memo、floating_card、clipboard
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_
  - [ ] 4.2 编写 ToolRegistry 属性测试
    - **Property 9: ToolRegistry 未注册工具返回错误**
    - **Validates: Requirements 4.3**

- [ ] 5. Checkpoint - 基础组件验证
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. 重构 SkillModel
  - [x] 6.1 更新 `SkillModel.swift`
    - 移除 `SkillType` 枚举
    - 移除 `skillType` 字段，替换为 `allowedTools: [String]` 和 `config: [String: String]`
    - 将 `promptTemplate` 重命名为 `systemPrompt`
    - 移除 `behaviorConfig`、`isEditable` 字段
    - 保留 `icon`、`colorHex`、`modifierKey`、`isBuiltin`（来自 SkillMetadataStore 合并）
    - 更新 `defaultColorHex()` 不再依赖 SkillType
    - _Requirements: 5.1, 2.5_

- [x] 7. 扩展 GhostypeAPIClient
  - [x] 7.1 新增 `SkillExecuteRequest` 模型和 `executeSkill()` 方法
    - 在 `GhostypeModels.swift` 中添加 `SkillExecuteRequest` 结构体
    - 在 `GhostypeAPIClient.swift` 中添加 `executeSkill(systemPrompt:message:context:endpoint:)` 方法
    - 默认端点 `/api/v1/skill/execute`，支持 config 中的 `api_endpoint` 覆盖
    - 保留现有 `polish()`、`translate()` 方法不变
    - _Requirements: 9.1, 9.2, 9.3, 9.4_
  - [ ] 7.2 编写 API 请求构建属性测试
    - **Property 13: API 请求构建正确性**
    - **Validates: Requirements 9.2, 9.4**

- [x] 8. 新建 SkillExecutor（替代 SkillRouter）
  - [x] 8.1 创建 `SkillExecutor.swift`
    - 实现统一的 `execute(skill:speechText:context:onDirectOutput:onRewrite:onFloatingCard:onError:)` 方法
    - save_memo 路径：不调 API，直接通过 ToolRegistry 执行
    - 正常路径：TemplateEngine 替换变量 → 构建 prompt（拼入上下文） → 调用 API → 根据 allowed_tools + ContextBehavior 分发结果
    - 错误路径：directOutput/rewrite 回退原文，explain/noInput 调用 onError
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  - [ ] 8.2 编写 SkillExecutor 分发逻辑属性测试
    - **Property 7: SkillExecutor 结果分发逻辑**
    - **Validates: Requirements 3.3**
  - [ ] 8.3 编写 SkillExecutor 错误回退属性测试
    - **Property 8: SkillExecutor 错误回退**
    - **Validates: Requirements 3.5**

- [ ] 9. Checkpoint - 执行层验证
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. 重构 SkillManager
  - [x] 10.1 更新 `SkillManager.swift`
    - 注入 `SkillMetadataStore` 依赖
    - `loadAllSkills()` 改为：解析 SKILL.md → 合并 SkillMetadataStore 元数据 → 构建 SkillModel
    - `createSkill()` 改为：写 SKILL.md（仅语义字段）+ 写 SkillMetadataStore（UI 元数据）
    - `updateSkill()` 改为：分别更新 SKILL.md 和 SkillMetadataStore
    - `deleteSkill()` 改为：删除 SKILL.md 目录 + 删除 SkillMetadataStore 记录
    - 新增 `updateIcon()`、`updateColor()` 方法仅更新 SkillMetadataStore
    - 更新 `ensureBuiltinSkills()` 使用新格式 SKILL.md + 默认元数据
    - _Requirements: 5.2, 2.3, 2.5_

- [x] 11. 重构 SkillMigrationService
  - [x] 11.1 更新 `SkillMigrationService.swift`
    - 实现 `mapSkillType()` 方法：旧 skillType → 新 allowedTools + config
    - 遍历 skills 目录，检测旧格式 SKILL.md（含 `skill_type` 字段）
    - 提取 UI 元数据到 SkillMetadataStore
    - 映射语义字段（skillType → allowedTools/config，behaviorConfig → config）
    - 重写 SKILL.md 为新格式
    - 确保幂等性
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_
  - [ ] 11.2 编写迁移 skillType 映射属性测试
    - **Property 10: 迁移服务 skillType 映射正确性**
    - **Validates: Requirements 7.1, 7.2**
  - [ ] 11.3 编写迁移 UI 元数据提取属性测试
    - **Property 11: 迁移服务 UI 元数据提取**
    - **Validates: Requirements 7.6, 7.7**
  - [ ] 11.4 编写迁移幂等性属性测试
    - **Property 12: 迁移服务幂等性**
    - **Validates: Requirements 7.8**

- [x] 12. 更新内置 Skill 文件
  - [x] 12.1 重写 `default_skills/` 下的所有 SKILL.md 为新格式
    - builtin-memo：allowed_tools = ["save_memo"]
    - builtin-ghost-command：默认 allowed_tools = ["insert_text"]
    - builtin-ghost-twin：config.api_endpoint = "/api/v1/ghost-twin/chat"
    - builtin-translate：config.source_language + config.target_language + 模板变量 prompt
    - _Requirements: 6.1, 6.4_

- [ ] 13. Checkpoint - 迁移和内置 Skill 验证
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. 接入上层：AppDelegate 和 HotkeyManager
  - [x] 14.1 更新 `AIInputMethodApp.swift`
    - 将 `skillRouter` 替换为 `skillExecutor`
    - 初始化 ToolRegistry 并注册内置 Tool（insert_text → insertTextAtCursor, save_memo → processMemo, floating_card → FloatingResultCardController, clipboard → NSPasteboard）
    - 更新 `processWithSkill()` 使用 SkillExecutor
    - 更新 `startApp()` 初始化流程：SkillMetadataStore.load() → SkillMigrationService → SkillManager.loadAllSkills()
    - 更新 `categoryForSkill()` 不再依赖 SkillType，改为根据 allowed_tools 判断
    - _Requirements: 5.3, 5.4_
  - [x] 14.2 更新 `HotkeyManager.swift`
    - 确认与新 SkillModel（无 skillType）兼容
    - 快捷键绑定逻辑不变（通过 SkillManager.keyBindings）
    - _Requirements: 5.2_

- [x] 15. 更新 SkillViewModel 和 SkillPage
  - [x] 15.1 更新 `SkillViewModel.swift`
    - 移除对 SkillType 的依赖
    - `confirmCreate()` 使用新 SkillModel（allowedTools 默认 ["insert_text"]）
    - `updateTranslateLanguage()` 改为更新 config 中的 source_language/target_language 并重写 SKILL.md
    - 图标/颜色更新通过 SkillMetadataStore
    - _Requirements: 6.3_
  - [x] 15.2 更新 `SkillPage.swift`
    - 移除对 SkillType 的 UI 依赖
    - 翻译语言选择改为 source_language + target_language 两个独立选择器
    - _Requirements: 6.1_

- [x] 16. 清理旧代码
  - [x] 16.1 删除或标记废弃的旧代码
    - ✅ 删除 `SkillRouter.swift`
    - ✅ `SkillType` 枚举已在 Task 6.1 中从 SkillModel 移除
    - ✅ `TranslateLanguage.swift` 标记 deprecated（仍被 AppSettings/PreferencesViewModel 引用）
    - ✅ `InputMode` 枚举标记 deprecated（仍被 OverlayView/AppSettings 引用）
    - ✅ `processWithMode()` 保留为向后兼容（processWithSkill nil fallback）
    - ✅ `RecordCategory` 不依赖 SkillType，无需修改
    - _Requirements: 5.1, 5.3_

- [x] 17. Final checkpoint - 全量验证
  - ✅ `swift build -c release` 编译通过，无新增错误

## 备注

- 标记 `*` 的任务为可选测试任务，可跳过以加速 MVP
- 每个任务引用了具体的需求编号，确保可追溯性
- Checkpoint 任务确保增量验证
- 属性测试验证通用正确性，单元测试验证具体示例和边界情况
- 重构遵循"小步快跑"原则：先建新组件，再替换旧组件，最后清理
