# Implementation Plan: Ghost Morph

## Overview

将 GHOSTYPE 的硬编码 InputMode 系统渐进式替换为动态 Skill 系统。按照依赖关系从底层数据模型开始，逐步向上构建到 UI 层，每一步都保持应用可编译运行。

## Tasks

- [x] 1. Skill 数据模型与文件解析器
  - [ ] 1.1 创建 SkillModel 数据模型
    - 创建 `Sources/Features/AI/Skill/SkillModel.swift`
    - 定义 `SkillModel` struct（id, name, description, icon, modifierKey, promptTemplate, behaviorConfig, isBuiltin, isEditable, skillType）
    - 定义 `SkillType` enum（polish, memo, translate, ghostCommand, ghostTwin, custom）
    - 定义 `ModifierKeyBinding` struct（keyCode, isSystemModifier, displayName）
    - 实现 Codable, Equatable, Identifiable 协议
    - _Requirements: 1.1_

  - [ ] 1.2 实现 SKILL.md 文件解析器和打印器
    - 创建 `Sources/Features/AI/Skill/SkillFileParser.swift`
    - 实现 `parse(_ content: String) throws -> SkillModel`：解析 YAML frontmatter（`---` 分隔）+ markdown body
    - 实现 `print(_ skill: SkillModel) -> String`：将 SkillModel 序列化为 SKILL.md 格式
    - YAML frontmatter 手动解析（key: value 格式，支持嵌套 behavior_config），不引入第三方 YAML 库
    - _Requirements: 1.3, 1.4_

  - [ ]* 1.3 编写 SKILL.md round-trip 属性测试
    - **Property 1: SKILL.md round-trip**
    - 创建随机 SkillModel 生成器（随机名称、图标、SkillType、behaviorConfig）
    - 验证 parse(print(skill)) == skill
    - 最少 100 次迭代
    - **Validates: Requirements 1.5, 1.3, 1.4**

- [x] 2. SkillManager 核心管理器
  - [ ] 2.1 实现 SkillManager 单例与文件系统操作
    - 创建 `Sources/Features/AI/Skill/SkillManager.swift`
    - 实现 storageDirectory 指向 `~/Library/Application Support/GHOSTYPE/skills/`
    - 实现 `loadAllSkills()`：遍历子文件夹，解析每个 SKILL.md
    - 实现 `createSkill(_ skill:)`：创建子文件夹 + 写入 SKILL.md
    - 实现 `updateSkill(_ skill:)`：更新对应 SKILL.md 文件
    - 实现 `deleteSkill(id:)`：删除子文件夹，内置 Skill 抛出错误
    - 使用 @Observable 使 skills 数组可观察
    - _Requirements: 1.6, 6.1, 6.2, 6.3, 6.5_

  - [ ] 2.2 实现内置 Skill 初始化
    - 实现 `ensureBuiltinSkills()`：检查并创建四个内置 Skill 的 SKILL.md
    - 定义内置 Skill 模板：随心记（Memo）、Ghost Command、Call Ghost Twin、翻译（Translate）
    - 默认绑定：Shift(keyCode 56) → Memo, Command(keyCode 55) → Ghost Command
    - Call Ghost Twin 和 Translate 默认不绑定按键
    - _Requirements: 1.2, 1.7, 5.7_

  - [ ]* 2.3 编写 Skill CRUD 持久化属性测试
    - **Property 8: Skill CRUD 持久化一致性**
    - 使用临时目录，随机创建 Skill → loadAllSkills → 验证一致性
    - 随机更新 Skill 字段 → 重新加载 → 验证更新生效
    - **Validates: Requirements 6.1, 6.2**

  - [ ]* 2.4 编写 Skill 加载完整性属性测试
    - **Property 2: Skill 加载完整性**
    - 在临时目录写入 N 个随机 SKILL.md → loadAllSkills → 验证返回 N 个 Skill
    - **Validates: Requirements 1.6**

  - [ ]* 2.5 编写内置 Skill 删除保护属性测试
    - **Property 10: 内置 Skill 删除保护**
    - 对任意 Builtin_Skill 调用 deleteSkill → 验证抛出错误且文件仍存在
    - **Validates: Requirements 6.5**

  - [ ]* 2.6 编写 Skill 删除清理属性测试
    - **Property 9: Skill 删除清理**
    - 创建随机 Custom_Skill → deleteSkill → 验证文件夹不存在且 keyCode 未绑定
    - **Validates: Requirements 6.3**

- [x] 3. 修饰键绑定系统
  - [ ] 3.1 实现按键绑定管理
    - 在 SkillManager 中添加 `keyBindings: [UInt16: String]` 映射
    - 实现 `skillForKeyCode(_ keyCode:) -> SkillModel?`
    - 实现 `skillForModifiers(_ modifiers: NSEvent.ModifierFlags) -> SkillModel?`（系统修饰键查找）
    - 实现 `rebindKey(skillId:, newBinding:)`：更新绑定并持久化到 SKILL.md
    - 实现 `hasKeyConflict(_ binding:, excludingSkillId:) -> SkillModel?`：冲突检测
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ]* 3.2 编写按键绑定查找属性测试
    - **Property 3: 按键绑定查找正确性**
    - 随机生成 Skill 集合（各绑定不同 keyCode）→ 查询每个 keyCode → 验证返回正确 Skill
    - **Validates: Requirements 2.1, 2.2**

  - [ ]* 3.3 编写按键冲突检测属性测试
    - **Property 4: 按键冲突检测**
    - 随机两个 Skill 绑定相同 keyCode → hasKeyConflict 返回已占用的 Skill
    - **Validates: Requirements 2.3**

  - [ ]* 3.4 编写按键重绑定持久化属性测试
    - **Property 5: 按键重绑定持久化**
    - 随机 Skill + 随机新 keyCode → rebindKey → 重新加载 → 验证绑定一致
    - **Validates: Requirements 2.4**

- [ ] 4. Checkpoint - 确保所有测试通过
  - 确保所有测试通过，ask the user if questions arise.

- [x] 5. 上下文检测与 Skill 路由
  - [ ] 5.1 实现 ContextDetector
    - 创建 `Sources/Features/Accessibility/ContextDetector.swift`
    - 定义 `ContextBehavior` enum（directOutput, rewrite, explain, noInput）
    - 实现 `detect() -> ContextBehavior`：通过 Accessibility API 检测可编辑状态和选中文字
    - 复用 FocusObserver 中 `checkIfEditable` 的逻辑判断可编辑性
    - 通过 `kAXSelectedTextAttribute` 获取选中文字
    - _Requirements: 3.1, 3.6_

  - [ ] 5.2 实现 SkillRouter
    - 创建 `Sources/Features/AI/Skill/SkillRouter.swift`
    - 实现 `execute(skill:, speechText:, onDirectOutput:, onRewrite:, onFloatingCard:, onError:) async`
    - 根据 SkillType 路由到不同 API：
      - polish → GhostypeAPIClient.polish()
      - translate → GhostypeAPIClient.translate()（从 behaviorConfig 读取语言）
      - ghostCommand → GhostypeAPIClient（固定 prompt）
      - ghostTwin → 新的 Ghost Twin chat 端点
      - memo → CoreData 保存（复用现有 processMemo 逻辑）
      - custom → GhostypeAPIClient（使用 promptTemplate 作为 custom_prompt）
    - 根据 ContextBehavior 分发结果到对应回调
    - 错误处理：Direct/Rewrite 回退插入原文，Explain/NoInput 卡片显示错误
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [ ] 5.3 在 GhostypeAPIClient 中添加 Ghost Twin chat 端点
    - 添加 `ghostTwinChat(text: String) async throws -> String` 方法
    - 调用独立的 Ghost Twin API 端点（非 /api/v1/llm/chat）
    - _Requirements: 5.3_

  - [ ] 5.4 在 GhostypeAPIClient 中添加 Ghost Command 支持
    - 添加 `ghostCommand(text: String) async throws -> String` 方法
    - 使用固定的 Ghost Command prompt 调用 /api/v1/llm/chat
    - _Requirements: 5.2_

  - [ ]* 5.5 编写上下文行为路由属性测试
    - **Property 6: 上下文行为路由正确性**
    - 使用 mock ContextDetector，随机 SkillModel + 随机 ContextBehavior
    - 验证 directOutput/rewrite 调用文字回调，explain/noInput 调用卡片回调
    - **Validates: Requirements 3.2, 3.3, 3.4, 3.5**

  - [ ]* 5.6 编写 Skill 类型路由属性测试
    - **Property 11: Skill 类型路由正确性**
    - 使用 mock API client，随机 SkillType → 验证调用正确的 API 方法
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5, 8.6**

  - [ ]* 5.7 编写错误处理属性测试
    - **Property 12: 错误处理按上下文分发**
    - 随机 SkillModel + 随机 ContextBehavior + 模拟 API 错误
    - 验证 Direct/Rewrite 回退原文，Explain/NoInput 显示错误
    - **Validates: Requirements 8.7**

- [ ] 6. Floating Result Card UI
  - [ ] 6.1 实现 FloatingResultCard 视图和控制器
    - 创建 `Sources/UI/FloatingResultCard.swift`
    - 实现 `FloatingResultCardView`：毛玻璃背景、Skill 图标+名称、语音原文、AI 结果、复制/分享按钮
    - 实现 `FloatingResultCardController`：NSPanel 管理（nonactivatingPanel）、定位逻辑、Escape 关闭
    - 使用 CursorManager 获取光标位置，无法获取时居中显示
    - 添加本地化字符串到 Strings.swift / Strings+Chinese.swift / Strings+English.swift
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [ ]* 6.2 编写悬浮卡片数据完整性属性测试
    - **Property 7: 悬浮卡片数据完整性**
    - 随机 SkillModel + 随机文本 → 验证展示数据包含图标、名称、语音原文、AI 结果
    - **Validates: Requirements 4.2, 7.2**

- [ ] 7. HotkeyManager 与 AppDelegate 改造
  - [ ] 7.1 改造 HotkeyManager 支持 Skill 系统
    - 修改 `HotkeyManager.swift`
    - 将 `currentMode: InputMode` 替换为 `currentSkill: SkillModel?`
    - 将 `onHotkeyUp: ((InputMode) -> Void)?` 改为 `onHotkeyUp: ((SkillModel?) -> Void)?`
    - 将 `onModeChanged` 改为 `onSkillChanged`
    - 修改 `getModeFromModifiers()` 为通过 SkillManager 查询按键绑定
    - 支持非修饰键的按键检测（在录音期间监听 keyDown 事件）
    - 保持 debounce 和 sticky 逻辑不变
    - nil Skill = 默认润色行为（需求 2.6）
    - _Requirements: 2.1, 2.5, 2.6_

  - [ ] 7.2 改造 AppDelegate 使用 SkillRouter
    - 修改 `AIInputMethodApp.swift`
    - 在 `startApp()` 中初始化 SkillManager（调用 ensureBuiltinSkills + loadAllSkills）
    - 添加 `SkillRouter` 实例和 `ContextDetector` 实例
    - 新增 `processWithSkill(_ skill: SkillModel?, speechText: String)` 方法
    - 在 `onHotkeyUp` 回调中调用 `processWithSkill` 替代 `processWithMode`
    - 保留 `processWithMode` 暂不删除（向后兼容）
    - 更新 OverlayStateManager 以支持 SkillModel（替代 InputMode 参数）
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 5.6_

  - [ ] 7.3 更新 OverlayView 支持 Skill 显示
    - 修改 `OverlayView.swift` 和 `OverlayStateManager`
    - 将 `OverlayPhase` 中的 `InputMode` 参数替换为 Skill 信息（名称、颜色）
    - 更新 `ModeColors` 支持动态 Skill 颜色
    - 更新 `ResultBadge` 支持动态 Skill 名称
    - 保持现有动画和布局不变
    - _Requirements: 5.6_

- [ ] 8. Checkpoint - 核心功能验证
  - 确保所有测试通过，ask the user if questions arise.
  - 验证：按住 Option 说话 → 松手 → 润色上屏（默认行为不变）
  - 验证：按住 Option + Shift → 随心记
  - 验证：按住 Option + Command → Ghost Command

- [ ] 9. Dashboard Skill 管理页面
  - [x] 9.1 添加 Skill 导航项和页面框架
    - 在 `NavItem.swift` 中添加 `.skills` case（图标 "sparkles", 放在 incubator 之后）
    - 更新 `NavItem.groups` 分组
    - 创建 `Sources/Features/Dashboard/SkillViewModel.swift`：管理 Skill 列表状态、编辑状态
    - 创建 `Sources/UI/Dashboard/Pages/SkillPage.swift`：Skill 管理页面框架
    - 在 `DashboardView.swift` 的 `normalContentView` 中添加 `.skills` case
    - 添加本地化字符串
    - _Requirements: 7.1_

  - [x] 9.2 实现 Skill 卡片列表和详情
    - 实现 Skill 卡片组件：图标、名称、绑定按键、描述
    - Ghost Twin 卡片额外显示 "Ghost Twin Lv.{level}"（从 IncubatorViewModel 读取）
    - 内置 Skill 卡片：显示介绍 + 可编辑配置项（翻译语言选择、Memo 润色开关）
    - 自定义 Skill 卡片：完整编辑（名称、描述、图标、prompt、配置）+ 删除按钮
    - 按键绑定编辑：点击绑定区域 → 监听下一个按键 → 冲突检测 → 确认绑定
    - _Requirements: 7.2, 7.3, 7.4, 7.6, 5.4, 5.5_

  - [x] 9.3 实现添加自定义 Skill 流程
    - "添加 Skill" 按钮 → 打开创建表单（名称、描述、图标选择、prompt 模板编辑）
    - 表单提交 → SkillManager.createSkill() → 刷新列表
    - 按键绑定可在创建时设置或之后编辑
    - _Requirements: 7.5, 6.1, 6.4_

- [ ] 10. 迁移服务
  - [ ] 10.1 实现 SkillMigrationService
    - 创建 `Sources/Features/AI/Skill/SkillMigrationService.swift`
    - 检查 UserDefaults "skillMigrationCompleted" 标记
    - 读取旧 AppSettings.translateModifier / memoModifier
    - 将旧绑定写入对应 Builtin_Skill 的 SKILL.md
    - 迁移 translateLanguage 到 Translate_Skill 的 behaviorConfig
    - 标记迁移完成
    - 在 AppDelegate.applicationDidFinishLaunching 中调用（在 SkillManager 初始化之前）
    - _Requirements: 9.1, 9.2, 9.3_

  - [ ]* 10.2 编写迁移幂等性属性测试
    - **Property 13: 迁移幂等性**
    - 随机旧配置值 → migrateIfNeeded() 两次 → 验证结果与一次执行相同
    - **Validates: Requirements 9.2**

- [ ] 11. Final checkpoint - 全部测试通过
  - 确保所有测试通过，ask the user if questions arise.
  - 完整回归：录音 → AI → 上屏流程正常
  - Dashboard Skill 页面正常
  - 新用户首次启动：内置 Skill 自动创建
  - 老用户升级：旧配置正确迁移

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- 保持 `processWithMode()` 暂不删除，确保向后兼容，待 Skill 系统稳定后再清理
- 所有 UI 文案必须通过 L.xxx 本地化访问，不可硬编码
