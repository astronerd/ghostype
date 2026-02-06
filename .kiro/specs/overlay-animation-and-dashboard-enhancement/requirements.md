# Requirements Document

## Introduction

本需求文档定义 GhosTYPE macOS 语音输入法的跑道圆动画系统增强和 Dashboard 功能补全。主要包含三大模块：

1. **跑道圆动画系统 (Overlay Animation)**: 在现有 OverlayView 基础上增量添加动画效果，包括光晕环、状态 Badge、上屏动画等
2. **随心记保存提示**: 在随心记模式保存完成后显示"已保存"动画反馈
3. **Dashboard 功能补全**: 完善概览页数据展示和偏好设置页配置项

## ⚠️ 重要约束：保持现有 OverlayView 结构

**所有动画效果必须在现有跑道圆基础上增量添加，不得修改：**
- 现有的 Capsule 形状和颜色 (`Color(white: 0.10)`)
- 现有的布局结构 (`HStack`, `padding`, `frame`)
- 现有的 GhostIconView 组件
- 现有的 textArea 文字区域
- 现有的阴影效果

**允许添加的内容：**
- 在 Capsule 背景外层添加光晕环效果
- 在 HStack 内部添加条件显示的 Badge
- 添加整体的 offset/opacity 动画
- 添加新的状态属性

## Glossary

- **Overlay_View**: 悬浮跑道圆窗口，显示录音状态和转录文字
- **Capsule_Shape**: 跑道条形状，OverlayView 的默认形态（必须保持）
- **Glow_Ring**: 周边光晕环，围绕跑道圆旋转的发光效果（新增）
- **Result_Badge**: 结果状态标签，显示"已润色"/"已翻译"/"已保存"（新增）
- **Input_Mode**: 输入模式枚举（polish/translate/memo）
- **Dashboard**: 主控制台界面
- **Overview_Page**: 概览页，显示使用统计和数据可视化
- **Preferences_Page**: 偏好设置页，管理应用配置
- **Bento_Card**: 便当盒风格的数据展示卡片
- **Energy_Ring**: 圆环图组件，显示配额使用情况
- **Memo_Page**: 随心记页面，Flomo 风格便签展示
- **App_Settings**: 全局应用设置管理器

## Requirements

### Requirement 1: 跑道圆动画状态

**User Story:** As a user, I want to see visual feedback for different states, so that I understand what the app is doing at any moment.

#### Acceptance Criteria

1. THE OverlayView SHALL track four states: recording, processing, result, and committing
2. WHEN transitioning between states, THE Overlay_View SHALL animate with 300ms duration using easeInOut timing
3. THE state SHALL be exposed as observable property for UI binding
4. WHEN user presses the hotkey, THE state SHALL immediately enter recording state
5. WHEN speech recognition completes and AI processing begins, THE state SHALL transition to processing
6. WHEN AI processing completes, THE state SHALL transition to result
7. WHEN text is committed, THE state SHALL transition to committing, then hide

### Requirement 2: 录音状态视觉效果

**User Story:** As a user, I want to see active visual feedback while recording, so that I know the app is listening to me.

#### Acceptance Criteria

1. WHILE in recording state, THE Overlay_View SHALL maintain existing Capsule_Shape (不修改)
2. WHILE in recording state, THE Overlay_View SHALL display streaming text with cursor animation (现有功能)
3. WHILE in recording state, THE Glow_Ring SHALL rotate continuously around the capsule at 2 seconds per rotation (新增)
4. WHILE in recording state, THE Ghost_Icon SHALL display floating animation (现有功能)
5. THE Glow_Ring color SHALL match the current Input_Mode color

### Requirement 3: AI 处理状态视觉效果

**User Story:** As a user, I want to see a distinct animation during AI processing, so that I know the app is thinking.

#### Acceptance Criteria

1. WHILE in processing state, THE Glow_Ring SHALL rotate faster (1 second per rotation)
2. WHILE in processing state, THE Overlay_View SHALL maintain existing Capsule_Shape (不修改)
3. WHILE in processing state, THE Overlay_View MAY display a subtle pulse animation on the capsule
4. THE processing state visual feedback SHALL be clearly distinguishable from recording state

### Requirement 4: 结果展示状态

**User Story:** As a user, I want to see the processed result clearly with status badge, so that I can verify the AI output before committing.

#### Acceptance Criteria

1. WHILE in result state, THE Overlay_View SHALL maintain existing Capsule_Shape (不修改)
2. WHEN result is displayed, THE Overlay_View SHALL show the processed text (现有功能)
3. WHILE in result state, THE Glow_Ring SHALL stop rotating and display static glow
4. WHILE in result state, THE Overlay_View SHALL display a Result_Badge indicating completion status (新增)
5. THE Result_Badge SHALL display "已润色" for polish mode (green color)
6. THE Result_Badge SHALL display "已翻译" for translate mode (purple color)
7. THE Result_Badge SHALL display "已保存" for memo mode (orange color)

### Requirement 5: 上屏动画

**User Story:** As a user, I want to see a satisfying animation when text is committed, so that I have clear feedback of successful input.

#### Acceptance Criteria

1. WHEN text is committed to input field, THE Overlay_View SHALL animate upward drift (向上漂移)
2. THE upward drift animation SHALL move the overlay 50pt upward while fading out
3. THE upward drift animation SHALL complete within 400ms
4. WHEN upward drift completes, THE Overlay_View SHALL hide and reset
5. THE upward drift animation SHALL use easeOut timing curve

### Requirement 6: 随心记保存提示 🔥

**User Story:** As a user, I want to see a special feedback when memo is saved, so that I know my note was captured successfully.

#### Acceptance Criteria

1. WHEN memo is saved in memo mode, THE Overlay_View SHALL display "已保存" Badge
2. THE "已保存" Badge SHALL be displayed for 1 second before fading out
3. THE "已保存" feedback SHALL only appear in memo mode, not in polish or translate modes
4. AFTER displaying "已保存", THE Overlay_View SHALL animate upward drift and hide
5. THE "已保存" Badge SHALL use orange color (#FF9500) consistent with memo mode

### Requirement 7: 模式颜色区分

**User Story:** As a user, I want to see different colors for different modes, so that I can quickly identify which mode I'm using.

#### Acceptance Criteria

1. THE Glow_Ring SHALL display blue color (#007AFF) when in default state
2. THE Glow_Ring SHALL display green color (#34C759) when in polish mode
3. THE Glow_Ring SHALL display purple color (#AF52DE) when in translate mode
4. THE Glow_Ring SHALL display orange color (#FF9500) when in memo mode
5. WHEN Input_Mode changes, THE Glow_Ring color SHALL transition smoothly within 200ms
6. THE mode color SHALL be consistent across Glow_Ring and Result_Badge

### Requirement 8: 小幽灵图标（现有功能保持）

**User Story:** As a user, I want to see the ghost icon properly, so that I have a friendly visual anchor in the overlay.

#### Acceptance Criteria

1. THE Ghost_Icon SHALL load from bundle resources (GhostIcon.png) - 现有功能
2. IF bundle resource is not found, THEN THE Ghost_Icon SHALL fall back to SF Symbol "waveform" - 现有功能
3. THE Ghost_Icon SHALL be displayed with color inversion for visibility - 现有功能
4. THE Ghost_Icon SHALL maintain 22pt size - 现有功能
5. WHILE in recording state, THE Ghost_Icon SHALL animate with subtle floating motion - 现有功能

### Requirement 9: Dashboard 概览页 - 今日战报卡片

**User Story:** As a user, I want to see my daily productivity stats, so that I can track my voice input usage.

#### Acceptance Criteria

1. THE Overview_Page SHALL display a "今日战报" Bento_Card
2. THE "今日战报" card SHALL display today's total input character count
3. THE "今日战报" card SHALL display estimated time saved (calculated as characters / 60 characters per minute)
4. THE "今日战报" card SHALL update in real-time when new records are added
5. THE "今日战报" card SHALL display "0 字" and "节省 0 分钟" when no records exist for today

### Requirement 10: Dashboard 概览页 - 本月能量环

**User Story:** As a user, I want to see my monthly quota usage visually, so that I can manage my usage effectively.

#### Acceptance Criteria

1. THE Overview_Page SHALL display a "本月能量环" Bento_Card with Energy_Ring component
2. THE Energy_Ring SHALL display used percentage as filled arc (0% to 100%)
3. THE Energy_Ring SHALL display remaining percentage as unfilled arc
4. WHEN usage exceeds 80%, THE Energy_Ring SHALL change to warning color (yellow)
5. WHEN usage exceeds 95%, THE Energy_Ring SHALL change to critical color (red)
6. THE Energy_Ring center SHALL display numeric percentage value

### Requirement 11: Dashboard 概览页 - 应用分布饼图

**User Story:** As a user, I want to see which apps I use voice input with most, so that I understand my usage patterns.

#### Acceptance Criteria

1. THE Overview_Page SHALL display an "应用分布" Bento_Card with pie chart
2. THE pie chart SHALL display usage distribution across different source applications
3. THE pie chart SHALL show app name and percentage on hover
4. THE pie chart SHALL display top 5 apps, grouping remaining as "其他"
5. IF no usage records exist, THEN THE pie chart SHALL display empty state message

### Requirement 12: Dashboard 随心记页面 (Flomo 风格)

**User Story:** As a user, I want a dedicated memo page with beautiful card layout, so that I can browse and manage my voice memos like a digital notebook.

#### Acceptance Criteria

1. THE Sidebar SHALL display "随心记" as an independent navigation item (between 概览 and 历史库)
2. THE MemoPage SHALL display memo entries in a waterfall/masonry card layout (类似 Flomo)
3. EACH memo card SHALL display: content preview, creation timestamp
4. THE memo cards SHALL use warm background colors (浅黄、淡橙、浅粉等便签色)
5. THE memo cards SHALL have subtle shadow and rounded corners for a paper-like appearance
6. WHEN a memo card is clicked, THE system SHALL expand it to show full content with edit capability
7. THE MemoPage SHALL support infinite scroll to load more memos
8. THE MemoPage header SHALL display total memo count and a search field

### Requirement 13: Dashboard 偏好设置 - 开机自启动

**User Story:** As a user, I want to configure the app to start automatically, so that it's always ready when I need it.

#### Acceptance Criteria

1. THE Preferences_Page SHALL display a "开机自启动" toggle switch
2. WHEN toggle is enabled, THE App_Settings SHALL register the app with macOS Login Items
3. WHEN toggle is disabled, THE App_Settings SHALL remove the app from macOS Login Items
4. THE toggle state SHALL persist across app restarts via UserDefaults
5. THE toggle SHALL reflect actual Login Items status on app launch

### Requirement 14: Dashboard 偏好设置 - 主触发键自定义

**User Story:** As a user, I want to customize the main trigger key, so that I can use a shortcut that fits my workflow.

#### Acceptance Criteria

1. THE Preferences_Page SHALL display current hotkey configuration with visual representation
2. THE Preferences_Page SHALL provide a "录制快捷键" button to capture new hotkey
3. WHEN capturing hotkey, THE system SHALL listen for next key combination pressed
4. THE captured hotkey SHALL be validated to avoid conflicts with system shortcuts
5. THE new hotkey SHALL be persisted to App_Settings and take effect immediately
6. THE Preferences_Page SHALL display hotkey in human-readable format (e.g., "⌥ Option")

### Requirement 15: Dashboard 偏好设置 - 模式修饰键自定义

**User Story:** As a user, I want to customize modifier keys for different modes, so that I can use shortcuts that feel natural to me.

#### Acceptance Criteria

1. THE Preferences_Page SHALL display current translate mode modifier key (default: Shift)
2. THE Preferences_Page SHALL display current memo mode modifier key (default: Command)
3. THE Preferences_Page SHALL provide dropdown or picker to change each modifier key
4. THE available modifier options SHALL include: Shift, Command, Control, Option
5. THE system SHALL prevent selecting the same modifier for both translate and memo modes
6. THE new modifier keys SHALL be persisted to App_Settings and take effect immediately

### Requirement 16: Dashboard 偏好设置 - AI 润色开关

**User Story:** As a user, I want to toggle AI polishing on or off, so that I can choose between raw transcription and polished output.

#### Acceptance Criteria

1. THE Preferences_Page SHALL display an "AI 润色" toggle switch
2. WHEN AI 润色 is disabled, THE system SHALL output raw transcription without AI processing
3. WHEN AI 润色 is enabled, THE system SHALL process transcription through AI before output
4. THE toggle state SHALL persist across app restarts via App_Settings
5. THE toggle SHALL be moved from menu bar to Preferences_Page (consolidate settings location)

### Requirement 17: Dashboard 偏好设置 - 自动润色长度阈值

**User Story:** As a user, I want AI polishing to activate only for longer texts, so that short inputs are not unnecessarily processed.

#### Acceptance Criteria

1. THE Preferences_Page SHALL display an "自动润色阈值" numeric input field
2. THE threshold value SHALL represent minimum character count to trigger AI polishing
3. THE default threshold value SHALL be 20 characters
4. WHEN transcription length is below threshold, THE system SHALL skip AI polishing even if enabled
5. WHEN transcription length meets or exceeds threshold, THE system SHALL apply AI polishing if enabled
6. THE threshold value SHALL be persisted to App_Settings

### Requirement 18: Dashboard 偏好设置 - 自定义 Prompt 编辑器

**User Story:** As a user, I want to customize the AI prompt, so that I can tailor the polishing behavior to my preferences.

#### Acceptance Criteria

1. THE Preferences_Page SHALL display a "自定义 Prompt" section with expandable editor
2. THE editor SHALL display current polish prompt with multi-line text editing capability
3. THE editor SHALL provide a "恢复默认" button to reset prompt to default value
4. THE custom prompt SHALL be persisted to App_Settings.polishPrompt
5. THE editor SHALL validate that prompt is not empty before saving
6. IF prompt is empty, THEN THE system SHALL display error message and prevent saving

## Animation References

本功能的动画设计参考了以下资源：

- **animation参考/Interactive Play and Pause button.json**: 光晕旋转效果参考
- **animation参考/Loader.json**: 旋转加载动画参考

## Non-Functional Requirements

### Performance

1. ALL animations SHALL maintain 60fps frame rate on supported hardware
2. THE Glow_Ring rotation SHALL use SwiftUI animation for smooth performance
3. THE animations SHALL not cause UI thread blocking

### Accessibility

1. THE Overlay_View animations SHALL respect "Reduce Motion" system preference
2. WHEN "Reduce Motion" is enabled, THE system SHALL use fade transitions instead of rotation
3. THE mode colors SHALL maintain WCAG AA contrast ratio against dark background

### Compatibility

1. THE animation system SHALL support macOS 13.0 and later
2. THE Dashboard enhancements SHALL integrate with existing CoreData schema
3. THE Preferences changes SHALL be backward compatible with existing UserDefaults keys
