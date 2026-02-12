# Implementation Plan: Ghost Morph

## Overview

将 GHOSTYPE 的硬编码 InputMode 系统渐进式替换为动态 Skill 系统。按照依赖关系从底层数据模型开始，逐步向上构建到 UI 层，每一步都保持应用可编译运行。

## Tasks

- [x] 1. Skill 数据模型与文件解析器
  - [x] 1.1 创建 SkillModel 数据模型
  - [x] 1.2 实现 SKILL.md 文件解析器和打印器
  - [ ]* 1.3 编写 SKILL.md round-trip 属性测试

- [x] 2. SkillManager 核心管理器
  - [x] 2.1 实现 SkillManager 单例与文件系统操作
  - [x] 2.2 实现内置 Skill 初始化
  - [ ]* 2.3 编写 Skill CRUD 持久化属性测试
  - [ ]* 2.4 编写 Skill 加载完整性属性测试
  - [ ]* 2.5 编写内置 Skill 删除保护属性测试
  - [ ]* 2.6 编写 Skill 删除清理属性测试

- [x] 3. 修饰键绑定系统
  - [x] 3.1 实现按键绑定管理
  - [ ]* 3.2 编写按键绑定查找属性测试
  - [ ]* 3.3 编写按键冲突检测属性测试
  - [ ]* 3.4 编写按键重绑定持久化属性测试

- [x] 4. Checkpoint（跳过，属性测试为可选项）

- [x] 5. 上下文检测与 Skill 路由
  - [x] 5.1 实现 ContextDetector
  - [x] 5.2 实现 SkillRouter
  - [x] 5.3 在 GhostypeAPIClient 中添加 Ghost Twin chat 端点
  - [x] 5.4 在 GhostypeAPIClient 中添加 Ghost Command 支持
  - [ ]* 5.5 编写上下文行为路由属性测试
  - [ ]* 5.6 编写 Skill 类型路由属性测试
  - [ ]* 5.7 编写错误处理属性测试

- [x] 6. Floating Result Card UI
  - [x] 6.1 实现 FloatingResultCard 视图和控制器
  - [ ]* 6.2 编写悬浮卡片数据完整性属性测试

- [x] 7. HotkeyManager 与 AppDelegate 改造
  - [x] 7.1 改造 HotkeyManager 支持 Skill 系统
  - [x] 7.2 改造 AppDelegate 使用 SkillRouter
  - [x] 7.3 更新 OverlayView 支持 Skill 显示

- [x] 8. Checkpoint - 核心功能验证（release build 通过）

- [x] 9. Dashboard Skill 管理页面
  - [x] 9.1 添加 Skill 导航项和页面框架
  - [x] 9.2 实现 Skill 卡片列表和详情
  - [x] 9.3 实现添加自定义 Skill 流程

- [x] 10. 迁移服务
  - [x] 10.1 实现 SkillMigrationService
  - [ ]* 10.2 编写迁移幂等性属性测试

- [x] 11. Final checkpoint - release build 通过 ✅

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- 保持 `processWithMode()` 暂不删除，确保向后兼容，待 Skill 系统稳定后再清理
- 所有 UI 文案必须通过 L.xxx 本地化访问，不可硬编码
