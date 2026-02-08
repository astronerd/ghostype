# GHOSTYPE 代码重构需求

## 背景

GHOSTYPE 项目经过快速迭代开发，积累了技术债务。本次重构旨在提高代码质量、可维护性和安全性，同时保持功能完全等效。

---

## 需求 1: 安全存储敏感信息

### 用户故事
作为开发者，我希望 API Key 等敏感信息不再硬编码在源码中，以避免密钥泄露风险。

### 验收标准
- 1.1 源码中不存在明文 API Key
- 1.2 源码中不存在 Base64 编码或 XOR 混淆的密钥
- 1.3 敏感信息通过 Keychain 或环境变量获取
- 1.4 首次运行时有密钥配置引导
- 1.5 密钥缺失时有友好的错误提示

### 涉及文件
- `DoubaoLLMService.swift` - 第 21 行明文存储
- `MiniMaxService.swift` - Base64 编码存储
- `DoubaoSpeechService.swift` - XOR 混淆存储

---

## 需求 2: 集中管理配置常量

### 用户故事
作为开发者，我希望魔法数字集中管理，以便于调整和维护。

### 验收标准
- 2.1 创建统一的 Constants 配置文件
- 2.2 HotkeyManager 中的延迟参数使用 Constants
- 2.3 DoubaoSpeechService 中的音频参数使用 Constants
- 2.4 StatsCalculator 中的统计参数使用 Constants
- 2.5 grep 搜索确认无散落的魔法数字

### 当前散落的魔法数字
- `HotkeyManager`: stickyDelayMs = 500, modifierDebounceMs = 300
- `DoubaoSpeechService`: 音频发送间隔 0.2, 采样率 16000
- `StatsCalculator`: typingSpeedPerSecond = 1.0

---

## 需求 3: 拆分 AppDelegate

### 用户故事
作为开发者，我希望 AppDelegate 职责单一，以提高可测试性和可维护性。

### 验收标准
- 3.1 AppDelegate 代码行数 < 150 行
- 3.2 录音控制逻辑提取到独立服务
- 3.3 AI 处理逻辑提取到独立服务
- 3.4 文本插入逻辑提取到独立服务
- 3.5 菜单栏管理提取到独立服务
- 3.6 浮窗管理提取到独立服务
- 3.7 AppDelegate 仅保留生命周期管理和服务组装
- 3.8 完整录音→AI→上屏流程功能正常

### 当前 AppDelegate 职责（需拆分）
- 应用生命周期管理 ✓ 保留
- 窗口管理 (Overlay, Dashboard, Onboarding) → 提取
- 录音控制 → 提取
- AI 处理分发 → 提取
- 文本插入 → 提取
- 菜单栏管理 → 提取
- 权限检查 ✓ 保留

---

## 需求 4: 统一 LLM 服务层

### 用户故事
作为开发者，我希望 LLM 服务有统一的接口和基类，以消除重复代码并支持扩展。

### 验收标准
- 4.1 定义 LLMServiceProtocol 统一接口
- 4.2 创建 BaseLLMService 抽象公共逻辑
- 4.3 DoubaoLLMService 继承基类并实现协议
- 4.4 MiniMaxService 继承基类并实现协议
- 4.5 润色功能正常
- 4.6 翻译功能正常
- 4.7 可通过配置切换服务商

### 当前重复代码
- sendRequest 模式
- 错误处理逻辑
- 响应解析逻辑

---

## 需求 5: 整理数据流

### 用户故事
作为开发者，我希望数据流向清晰，AppSettings 作为唯一数据源，避免双向绑定混乱。

### 验收标准
- 5.1 AppSettings 作为 Source of Truth
- 5.2 ViewModel 通过方法调用修改设置，不使用 didSet 同步
- 5.3 设置变更通过通知机制传播
- 5.4 无循环更新问题
- 5.5 设置页面功能正常

### 当前问题
- AIPolishViewModel 有 didSet 同步到 AppSettings
- PreferencesViewModel 有 didSet 同步到 AppSettings
- AppSettings 本身也有 didSet 保存到 UserDefaults
- 数据流向不清晰，可能产生循环更新

---

## 需求 6: 完善本地化

### 用户故事
作为用户，我希望所有界面文案都支持中英文切换。

### 验收标准
- 6.1 OverviewPage 完成本地化
- 6.2 LibraryPage 完成本地化
- 6.3 MemoPage 完成本地化
- 6.4 AIPolishPage 完成本地化
- 6.5 所有 UI 文案使用 L.xxx 访问
- 6.6 切换语言后文案正确显示

### 当前状态
- [x] PreferencesPage.swift - 已本地化
- [ ] OverviewPage.swift - 待本地化
- [ ] LibraryPage.swift - 待本地化
- [ ] MemoPage.swift - 待本地化
- [ ] AIPolishPage.swift - 待本地化

---

## 需求 7: 统一 UI 组件

### 用户故事
作为开发者，我希望相似功能的 UI 组件统一，避免重复定义。

### 验收标准
- 7.1 合并 BentoCard 和 MinimalBentoCard
- 7.2 统一组件 API
- 7.3 更新所有使用处
- 7.4 删除重复组件定义

### 当前问题
- MinimalBentoCard 在 OverviewPage.swift 定义
- BentoCard 在 Components/BentoCard.swift 定义
- 功能相似，应统一

---

## 约束条件

1. **等效性**: 重构后的逻辑必须与原逻辑完全等效
2. **向后兼容**: 不能改变现有 API 接口
3. **风格规范**: 遵循 Swift API Design Guidelines + 项目现有 @Observable 模式
4. **本地化规范**: 遵循 localization.md 规范
5. **备份策略**: 每次重构前必须备份原文件或使用 Git 分支

---

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 拆分 AppDelegate 可能破坏录音流程 | 高 | 每步后手动测试完整流程 |
| Keychain 存储可能在沙盒外失败 | 中 | 提供 fallback 到环境变量 |
| 本地化可能遗漏字符串 | 低 | grep 检查硬编码中文 |
| 数据流重构可能导致 UI 不刷新 | 中 | 保持 @Observable 模式 |
