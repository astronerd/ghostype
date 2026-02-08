# GHOSTYPE 重构任务清单

## Phase 1: 安全与配置

### 1. 创建 Constants.swift
- [ ] 1.1 创建 `Features/Settings/Constants.swift` 文件
- [ ] 1.2 定义 Hotkey 常量 (stickyDelayMs, modifierDebounceMs)
- [ ] 1.3 定义 Audio 常量 (sendIntervalSeconds, sampleRate)
- [ ] 1.4 定义 Stats 常量 (typingSpeedPerSecond)
- [ ] 1.5 更新 HotkeyManager.swift 使用 Constants.Hotkey
- [ ] 1.6 更新 DoubaoSpeechService.swift 使用 Constants.Audio
- [ ] 1.7 更新 StatsCalculator.swift 使用 Constants.Stats
- [ ] 1.8 编译验证

### 2. 创建 SecretsManager
- [ ] 2.1 创建 `Features/Settings/SecretsManager.swift` 文件
- [ ] 2.2 定义 SecretsManagerProtocol 协议
- [ ] 2.3 定义 ServiceType 枚举
- [ ] 2.4 实现 KeychainSecretsManager (Keychain 存储)
- [ ] 2.5 实现 EnvironmentSecretsManager (环境变量 fallback)
- [ ] 2.6 创建 SecretsManager.shared 单例
- [ ] 2.7 更新 DoubaoLLMService.swift 使用 SecretsManager
- [ ] 2.8 更新 DoubaoSpeechService.swift 使用 SecretsManager
- [ ] 2.9 更新 MiniMaxService.swift 使用 SecretsManager
- [ ] 2.10 功能测试：润色、翻译、语音识别

---

## Phase 2: 拆分 AppDelegate

### 3. 提取 TextInsertionService
- [ ] 3.1 创建 `Features/Accessibility/TextInsertionService.swift`
- [ ] 3.2 从 AppDelegate 迁移 insertTextAtCursor 方法
- [ ] 3.3 从 AppDelegate 迁移 sendEnterKey 方法
- [ ] 3.4 在 AppDelegate 中创建 TextInsertionService 实例
- [ ] 3.5 更新 AppDelegate 调用 TextInsertionService
- [ ] 3.6 功能测试：文本上屏

### 4. 提取 OverlayWindowManager
- [ ] 4.1 创建 `Features/Overlay/OverlayWindowManager.swift`
- [ ] 4.2 从 AppDelegate 迁移 setupOverlayWindow 方法
- [ ] 4.3 从 AppDelegate 迁移 showOverlay/hideOverlay 方法
- [ ] 4.4 从 AppDelegate 迁移 positionOverlayAtBottom 方法
- [ ] 4.5 在 AppDelegate 中创建 OverlayWindowManager 实例
- [ ] 4.6 更新 AppDelegate 调用 OverlayWindowManager
- [ ] 4.7 功能测试：浮窗显示/隐藏

### 5. 提取 MenuBarManager
- [ ] 5.1 创建 `Features/MenuBar/MenuBarManager.swift`
- [ ] 5.2 定义 MenuBarManagerDelegate 协议
- [ ] 5.3 从 AppDelegate 迁移 setupMenuBar 方法
- [ ] 5.4 从 AppDelegate 迁移菜单项 action 方法
- [ ] 5.5 AppDelegate 实现 MenuBarManagerDelegate
- [ ] 5.6 更新 AppDelegate 调用 MenuBarManager
- [ ] 5.7 功能测试：菜单栏操作

### 6. 提取 VoiceInputCoordinator
- [ ] 6.1 创建 `Features/VoiceInput/VoiceInputCoordinator.swift`
- [ ] 6.2 定义 VoiceInputState 枚举
- [ ] 6.3 从 AppDelegate 迁移录音控制逻辑
- [ ] 6.4 从 AppDelegate 迁移 processWithMode 方法
- [ ] 6.5 从 AppDelegate 迁移 handlePolish/handleTranslate/handleMemo 方法
- [ ] 6.6 集成 TextInsertionService
- [ ] 6.7 在 AppDelegate 中创建 VoiceInputCoordinator 实例
- [ ] 6.8 更新 HotkeyManager 回调连接到 Coordinator
- [ ] 6.9 功能测试：完整录音→AI→上屏流程

### 7. 精简 AppDelegate
- [ ] 7.1 移除已迁移的代码
- [ ] 7.2 保留生命周期管理 (applicationDidFinishLaunching 等)
- [ ] 7.3 保留服务组装逻辑
- [ ] 7.4 保留权限检查逻辑
- [ ] 7.5 验证代码行数 < 150 行
- [ ] 7.6 完整功能回归测试

---

## Phase 3: 统一 LLM 服务层

### 8. 定义 LLM 服务协议
- [ ] 8.1 创建 `Features/AI/LLMServiceProtocol.swift`
- [ ] 8.2 定义 LLMServiceProtocol 协议
- [ ] 8.3 定义 LLMError 错误类型
- [ ] 8.4 定义 TranslateLanguage 枚举 (如果不存在)
- [ ] 8.5 编译验证

### 9. 创建 BaseLLMService
- [ ] 9.1 创建 `Features/AI/BaseLLMService.swift`
- [ ] 9.2 实现通用 sendRequest 方法
- [ ] 9.3 实现通用 parseResponse 方法
- [ ] 9.4 实现通用错误处理
- [ ] 9.5 编译验证

### 10. 重构 DoubaoLLMService
- [ ] 10.1 让 DoubaoLLMService 继承 BaseLLMService
- [ ] 10.2 让 DoubaoLLMService 实现 LLMServiceProtocol
- [ ] 10.3 移除重复的 sendRequest 代码
- [ ] 10.4 移除重复的错误处理代码
- [ ] 10.5 功能测试：润色、翻译

### 11. 重构 MiniMaxService
- [ ] 11.1 让 MiniMaxService 继承 BaseLLMService
- [ ] 11.2 让 MiniMaxService 实现 LLMServiceProtocol
- [ ] 11.3 移除重复代码
- [ ] 11.4 功能测试

---

## Phase 4: 数据流整理

### 12. 重构 AppSettings
- [ ] 12.1 移除 AppSettings 中的 didSet 保存逻辑
- [ ] 12.2 添加显式 save() 方法
- [ ] 12.3 添加 setXxx() 更新方法
- [ ] 12.4 添加 SettingsDidChange 通知
- [ ] 12.5 编译验证

### 13. 重构 ViewModel
- [ ] 13.1 重构 AIPolishViewModel，移除 didSet 同步
- [ ] 13.2 改为调用 AppSettings.setXxx() 方法
- [ ] 13.3 重构 PreferencesViewModel，移除 didSet 同步
- [ ] 13.4 改为调用 AppSettings.setXxx() 方法
- [ ] 13.5 功能测试：设置页面

---

## Phase 5: 本地化完善

### 14. 本地化 OverviewPage
- [ ] 14.1 在 Strings.swift 添加 Overview 字符串定义
- [ ] 14.2 在 Strings+Chinese.swift 添加中文翻译
- [ ] 14.3 在 Strings+English.swift 添加英文翻译
- [ ] 14.4 更新 OverviewPage.swift 使用 L.Overview.xxx
- [ ] 14.5 功能测试：切换语言

### 15. 本地化 LibraryPage
- [ ] 15.1 在 Strings.swift 添加 Library 字符串定义
- [ ] 15.2 在 Strings+Chinese.swift 添加中文翻译
- [ ] 15.3 在 Strings+English.swift 添加英文翻译
- [ ] 15.4 更新 LibraryPage.swift 使用 L.Library.xxx
- [ ] 15.5 功能测试：切换语言

### 16. 本地化 MemoPage
- [ ] 16.1 在 Strings.swift 添加 Memo 字符串定义
- [ ] 16.2 在 Strings+Chinese.swift 添加中文翻译
- [ ] 16.3 在 Strings+English.swift 添加英文翻译
- [ ] 16.4 更新 MemoPage.swift 使用 L.Memo.xxx
- [ ] 16.5 功能测试：切换语言

### 17. 本地化 AIPolishPage
- [ ] 17.1 在 Strings.swift 添加 AIPolish 字符串定义
- [ ] 17.2 在 Strings+Chinese.swift 添加中文翻译
- [ ] 17.3 在 Strings+English.swift 添加英文翻译
- [ ] 17.4 更新 AIPolishPage.swift 使用 L.AIPolish.xxx
- [ ] 17.5 功能测试：切换语言

### 18. 统一 UI 组件
- [ ] 18.1 分析 BentoCard 和 MinimalBentoCard 的差异
- [ ] 18.2 设计统一的 BentoCard API
- [ ] 18.3 更新 BentoCard.swift 支持两种样式
- [ ] 18.4 更新 OverviewPage.swift 使用统一的 BentoCard
- [ ] 18.5 删除 MinimalBentoCard 定义
- [ ] 18.6 功能测试：Dashboard 页面显示

---

## 验收检查

### 19. 最终验收
- [ ] 19.1 编译无警告
- [ ] 19.2 AppDelegate 代码行数 < 150 行
- [ ] 19.3 grep 确认无硬编码 API Key
- [ ] 19.4 grep 确认无散落的魔法数字
- [ ] 19.5 grep 确认无硬编码中文 (UI 文案)
- [ ] 19.6 完整功能回归测试通过
- [ ] 19.7 更新 CHANGELOG.md
