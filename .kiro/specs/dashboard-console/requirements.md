# Requirements Document

## Introduction

GhosTYPE Dashboard Console 是 macOS 原生语音输入工具的主界面控制台，提供数据可视化、历史管理和商业化转化功能。采用 Sidebar + Content 双栏布局，结合 Glassmorphism 毛玻璃材质和 Bento Grid 便当盒风格卡片，打造现代 AI 产品的视觉体验。Dashboard 采用状态机设计，将 Onboarding 流程融入主界面，首次启动时引导用户完成权限设置，完成后切换到正常功能视图。

## Glossary

- **Dashboard**: 主控制台界面，包含 Sidebar 导航和 Content 内容区
- **Dashboard_State**: Dashboard 状态机，管理 Onboarding 和 Normal 两种状态
- **Onboarding_State**: 初次启动状态，显示权限申请和初始设置流程
- **Normal_State**: 正常使用状态，显示完整功能模块
- **Sidebar**: 左侧导航栏，包含功能模块入口和用户信息
- **Bento_Card**: 便当盒风格的数据展示卡片组件
- **Energy_Ring**: 圆环图组件，用于显示额度使用情况
- **Usage_Record**: 语音输入使用记录，包含原文、时间戳、来源应用等信息
- **Quota_System**: 额度管理系统，追踪免费/付费用户的语音时长消耗
- **Device_ID**: 设备唯一标识符，用于关联本地数据和历史记录
- **Floating_Overlay**: 悬浮录音窗口，额度耗尽时显示警告状态

## Requirements

### Requirement 1: Dashboard 状态机架构

**User Story:** As a new user, I want to complete onboarding within the dashboard, so that I have a seamless first-run experience without separate windows.

#### Acceptance Criteria

1. THE Dashboard_State SHALL manage two states: Onboarding_State and Normal_State
2. WHEN the app launches for the first time, THE Dashboard SHALL enter Onboarding_State
3. WHEN all required permissions are granted and setup is complete, THE Dashboard SHALL transition to Normal_State
4. THE Dashboard SHALL persist current state to UserDefaults
5. WHEN the app launches subsequently, THE Dashboard SHALL restore to Normal_State if onboarding was completed
6. IF user revokes required permissions, THEN THE Dashboard SHALL display a permission reminder banner in Normal_State (not revert to Onboarding_State)

### Requirement 2: Onboarding 流程集成

**User Story:** As a new user, I want to set up permissions and preferences in the dashboard, so that I can start using the app quickly.

#### Acceptance Criteria

1. WHILE in Onboarding_State, THE Dashboard SHALL display only the onboarding section in Content area
2. THE Onboarding section SHALL display step indicators showing current progress (e.g., 1/3, 2/3, 3/3)
3. THE Onboarding section SHALL include: hotkey configuration step, input mode selection step, permissions request step
4. WHEN user completes all onboarding steps, THE Dashboard SHALL animate transition to Normal_State
5. THE Sidebar SHALL be visible but with navigation items disabled during Onboarding_State
6. WHEN transitioning to Normal_State, THE Dashboard SHALL hide onboarding section with fade-out animation

### Requirement 3: Dashboard 主布局架构

**User Story:** As a user, I want a clean sidebar navigation with content area, so that I can easily access different features of the application.

#### Acceptance Criteria

1. THE Dashboard SHALL display a Sidebar on the left side with fixed width of 220pt
2. THE Dashboard SHALL display a Content area on the right side that fills remaining space
3. THE Sidebar SHALL use NSVisualEffectView with .sidebar material for translucent glass effect
4. THE Content area SHALL use NSVisualEffectView with .contentBackground material
5. WHEN the window is resized, THE Content area SHALL adapt responsively while Sidebar maintains fixed width
6. THE Dashboard window SHALL have minimum size of 900x600pt

### Requirement 4: Sidebar 导航组件

**User Story:** As a user, I want clear navigation options in the sidebar, so that I can switch between different functional modules.

#### Acceptance Criteria

1. THE Sidebar SHALL display navigation items: 概览(Dashboard), 历史库(Library), 偏好设置(Preferences)
2. WHEN a navigation item is clicked, THE Dashboard SHALL switch Content area to corresponding view
3. THE Sidebar SHALL highlight the currently selected navigation item with accent color background
4. THE Sidebar SHALL display SF Symbols icons alongside navigation item labels
5. THE Sidebar bottom section SHALL display Device_ID (truncated) and quota progress bar
6. WHILE in Onboarding_State, THE Sidebar navigation items SHALL be visually disabled and non-interactive

### Requirement 5: 概览页 (Overview) 数据展示

**User Story:** As a user, I want to see my usage statistics at a glance, so that I can understand my voice input productivity.

#### Acceptance Criteria

1. THE Overview page SHALL display Bento_Cards in a responsive grid layout
2. THE "今日战报" Bento_Card SHALL display today's input character count and estimated time saved
3. THE "本月能量环" Bento_Card SHALL display an Energy_Ring showing used/remaining quota percentage
4. THE "应用分布" Bento_Card SHALL display a pie chart showing usage distribution across applications
5. THE "最近笔记" Bento_Card SHALL display the 3 most recent voice memo entries with preview text
6. WHEN a Bento_Card is hovered, THE Dashboard SHALL apply subtle scale transform (1.02x) with 200ms transition
7. THE Bento_Cards SHALL use rounded corners (16pt radius) and subtle shadow

### Requirement 6: 历史库 (Library) 记录管理

**User Story:** As a user, I want to search and filter my voice input history, so that I can find and reuse previous content.

#### Acceptance Criteria

1. THE Library page SHALL display a search field at the top for full-text search
2. THE Library page SHALL display filter tabs: 全部, 润色, 翻译, 随心记
3. WHEN a filter tab is selected, THE Library SHALL display only Usage_Records matching that category
4. WHEN search text is entered, THE Library SHALL filter Usage_Records containing the search text
5. THE Library list item SHALL display: source app icon, content preview (truncated to 2 lines), timestamp
6. WHEN a list item is dragged outside the window, THE Dashboard SHALL export the content as .txt file
7. WHEN a list item is clicked, THE Library SHALL display full content in a detail panel

### Requirement 7: 偏好设置 (Preferences) 配置

**User Story:** As a user, I want to customize application settings, so that the app works according to my preferences.

#### Acceptance Criteria

1. THE Preferences page SHALL display a toggle for "开机自启动" (Launch at Login)
2. THE Preferences page SHALL display a toggle for "声音反馈" (Sound Feedback)
3. THE Preferences page SHALL display current hotkey configuration with option to modify
4. THE Preferences page SHALL display AI engine status indicator (online/offline) without exposing model details
5. WHEN a toggle is changed, THE Dashboard SHALL persist the setting immediately
6. THE Preferences page SHALL group settings into logical sections with headers

### Requirement 8: 设备标识与数据关联

**User Story:** As a user, I want my data to be associated with my device, so that my history and preferences persist across app restarts.

#### Acceptance Criteria

1. THE Dashboard SHALL generate a unique Device_ID on first launch using UUID
2. THE Device_ID SHALL be persisted to Keychain for security and persistence across reinstalls
3. THE Device_ID SHALL be used as the primary key for associating all local Usage_Records
4. THE Sidebar bottom section SHALL display truncated Device_ID (first 8 characters) for user reference
5. THE Device_ID SHALL remain constant unless user explicitly resets it from Preferences

### Requirement 9: 额度系统（预留）

**User Story:** As a product owner, I want quota tracking infrastructure in place, so that monetization can be enabled later.

#### Acceptance Criteria

1. THE Quota_System SHALL track voice input duration in seconds for each Device_ID
2. THE Quota_System SHALL store quota data locally with fields: usedSeconds, resetDate
3. THE Energy_Ring SHALL display current quota usage percentage based on local data
4. WHEN quota data structure changes in future, THE Dashboard SHALL support data migration
5. THE Quota_System SHALL expose APIs for future server-side quota validation integration

### Requirement 10: 数据持久化

**User Story:** As a user, I want my data to persist locally, so that I can access my history even when offline.

#### Acceptance Criteria

1. THE Dashboard SHALL use CoreData for local data persistence
2. THE Dashboard SHALL store Usage_Records with fields: id, content, category, sourceApp, sourceAppBundleId, timestamp, duration, deviceId
3. THE Dashboard SHALL store user preferences in UserDefaults
4. THE Dashboard SHALL store quota information with fields: usedSeconds, resetDate
5. WHEN the app launches, THE Dashboard SHALL load cached data immediately
6. THE Dashboard SHALL operate fully offline with all data stored locally

### Requirement 11: UI 视觉规范

**User Story:** As a user, I want a visually appealing interface, so that using the app is a pleasant experience.

#### Acceptance Criteria

1. THE Dashboard SHALL use SF Pro font family consistent with macOS system
2. THE Dashboard SHALL use SF Symbols for all icons (no emoji icons)
3. THE Dashboard SHALL support both light and dark mode with appropriate color adaptations
4. THE Dashboard SHALL use 150-300ms transition duration for all animations
5. THE Dashboard SHALL maintain WCAG AA contrast ratio (4.5:1 minimum) for text
6. THE Dashboard SHALL use the existing app color scheme: primary dark (#1E1E23), accent blue from system

### Requirement 12: 窗口管理

**User Story:** As a user, I want the dashboard window to behave like a native macOS app, so that it integrates well with my workflow.

#### Acceptance Criteria

1. THE Dashboard window SHALL be accessible from menu bar icon click
2. THE Dashboard window SHALL remember its last position and size
3. WHEN Dashboard window loses focus, THE window SHALL remain visible (not auto-hide)
4. THE Dashboard window SHALL support standard window controls (close, minimize, zoom)
5. WHEN menu bar icon is clicked while Dashboard is visible, THE Dashboard SHALL come to front
