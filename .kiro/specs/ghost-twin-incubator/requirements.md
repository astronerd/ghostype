# Ghost Twin 孵化室 — 需求文档

## 简介

GHOSTYPE（鬼才打字）macOS 桌面应用新增「孵化室 (The Incubator)」功能模块。孵化室是 Ghost Twin 的核心前端界面，以赛博朋克点阵屏的形式展示用户数字分身的成长过程。用户通过持续使用语音输入（每万字升一级，共 10 级），逐步点亮 160×120 的 CRT 风格点阵屏，最终在屏幕上显现完整的 Ghost Logo。

孵化室作为 Dashboard 中的独立导航模块，位于侧边栏「账号」和「概览」下方，带有「LAB」徽章，需要登录才能访问。

## 术语表

- **Incubator（孵化室）**：Ghost Twin 的养成界面，Dashboard 中的独立页面
- **Dot_Matrix（点阵屏）**：160×120 分辨率的 CRT 风格像素显示区域，4px 颗粒，物理尺寸 640×480px
- **Ghost_Logo**：预定义的像素 Logo 图案（小鬼按键盘），由点阵屏中特定坐标的像素点组成
- **Pixel_Point（像素点）**：点阵屏上的单个显示单元，4×4px 圆角矩形，模拟 CRT 显像管
- **Level（等级）**：Ghost Twin 的成长等级，Lv.1 ~ Lv.10，每级需要 10,000 字输入
- **XP（经验值）**：用户输入的累计字数，每字 = 1 XP，每 10,000 XP 升一级
- **Activation_Order（点亮序列）**：预先随机打乱的像素坐标数组，决定本级内像素点亮的先后顺序
- **Ghost_Opacity（幽灵透明度）**：Ghost Logo 像素的基础亮度，随等级递增（Lv.1=10% → Lv.10=100%）
- **Breath_Animation（呼吸动效）**：Ghost Logo 像素的明暗正弦波动，模拟生命体呼吸
- **CRT_Container（CRT 容器）**：承载点阵屏的深色容器，带有扫描线、暗角等复古滤镜效果
- **Receipt_Slip（热敏纸条）**：从 CRT 屏幕上方滑出的交互卡片，用像素字体显示校准任务文本
- **Calibration（校准）**：通过交互式问答训练 Ghost Twin 的机制，独立于 AI 润色的 LLM 调用链路，包括灵魂拷问、找鬼游戏、预判赌局
- **Shenxing_Engine（神形法引擎）**：后端核心技术，前端不暴露，包含 Form（形）、Spirit（神）、Method（法）三层
- **Personality_Profile（人格档案）**：Ghost Twin 的数字人格数据，存储在云端，包含语言 DNA（形）、价值观/决策逻辑（神）、情境规则（法），随等级渐进式生成和修正
- **Calibration_Challenge（校准挑战）**：服务端基于当前人格档案和等级生成的情境问答题，用户回答后服务端更新人格档案并返回 XP 奖励
- **Calibration_XP（校准经验值）**：完成校准挑战获得的额外 XP，独立于打字 XP，用于加速升级
- **API_Spec_Doc（API 需求文档）**：开发完成后输出给服务端团队的接口规范文档，包含端点定义、请求/响应格式、Prompt 初稿

## 需求

### 需求 1：侧边栏导航项

**用户故事：** 作为用户，我希望在 Dashboard 侧边栏看到「孵化室」入口，以便快速访问 Ghost Twin 养成界面。

#### 验收标准

1. THE NavItem enum SHALL 新增 `.incubator` case，icon 为 `flask.fill`，title 使用 `L.Nav.incubator` 本地化字符串
2. THE NavItem.groups SHALL 将 `.incubator` 放在第一组，位于 `.account` 和 `.overview` 之后：`[.account, .overview, .incubator]`
3. THE `.incubator` 的 `requiresAuth` SHALL 返回 `true`（需要登录才能访问）
4. THE SidebarNavItem SHALL 支持在导航项右侧显示文字徽章（badge），`.incubator` 显示 "LAB" 徽章
5. THE "LAB" 徽章 SHALL 使用 `DS.Typography.mono(8, weight: .medium)` 字体，`DS.Colors.text2` 文字色，`DS.Colors.highlight` 背景色，圆角 2px
6. THE DashboardView 的 contentArea SHALL 在 `.incubator` case 下显示 `IncubatorPage()`

### 需求 2：孵化室页面布局（屏中屏）

**用户故事：** 作为用户，我希望孵化室页面呈现一个嵌入式的复古 CRT 显示屏，营造赛博朋克的沉浸感。

#### 验收标准

1. THE IncubatorPage SHALL 使用 DS.Colors.bg1 作为页面背景（与 Dashboard 其他页面一致）
2. THE IncubatorPage SHALL 在页面中央放置一个 CRT_Container，背景为纯黑色（Color.black）
3. THE CRT_Container 的内部显示区域 SHALL 为 640×480px（160×120 像素 × 4px 颗粒）
4. THE CRT_Container SHALL 带有 DS.Colors.border 的 1px 边框和 DS.Layout.cornerRadius 圆角，与 DS 设计系统一致
5. THE CRT_Container 上方 SHALL 显示等级信息（如 "Lv.3"）和进度条（当前字数 / 10,000）
6. THE CRT_Container 下方 SHALL 显示 Ghost 状态文字（使用等宽像素风格字体），如 "SYNC RATE: 30%" 或 Ghost 的俏皮短句

### 需求 3：点阵屏渲染

**用户故事：** 作为用户，我希望看到一个由 19,200 个微小像素点组成的点阵屏，每个点都有 CRT 显像管的质感。

#### 验收标准

1. THE Dot_Matrix SHALL 使用 SwiftUI Canvas 进行高性能渲染，分辨率为 160 列 × 120 行（共 19,200 个像素点）
2. EACH Pixel_Point SHALL 渲染为 4×4px 的圆角矩形（cornerRadius 约 0.5~1px），像素间留 0.5px 间隙模拟晶格感
3. THE 未激活的像素点 SHALL 渲染为极暗的灰色（opacity 约 0.03~0.05），模拟熄灭的显像管底噪
4. THE 已激活的背景像素点 SHALL 渲染为暗绿色（opacity 约 0.2~0.3）
5. THE 已激活的 Ghost_Logo 像素点 SHALL 渲染为高亮绿色，亮度由当前等级的 Ghost_Opacity 决定
6. THE Canvas SHALL 使用 `.drawingGroup()` 修饰符启用离屏渲染，确保 19,200 个点的绘制性能

### 需求 4：CRT 视觉滤镜

**用户故事：** 作为用户，我希望点阵屏有复古 CRT 显示器的质感，增强赛博朋克氛围。

#### 验收标准

1. THE CRT_Container SHALL 叠加扫描线效果（Scanlines）：每隔 2~3px 一条半透明黑色横线（opacity 约 0.15）
2. THE 已激活像素 SHALL 通过双层 Canvas 实现辉光效果（Bloom）：底层 Canvas 带 `.blur(radius: 1~2)` + `.blendMode(.screen)` 做光晕，上层 Canvas 保持锐利
3. THE CRT_Container 四角 SHALL 有轻微暗角效果（Vignette），使用径向渐变从透明到黑色 opacity 0.3
4. THE 扫描线和暗角 SHALL 作为不可交互的覆盖层（`.allowsHitTesting(false)`）

### 需求 5：Ghost Logo 数据与洗牌算法

**用户故事：** 作为开发者，我需要一个高效的数据模型来管理 19,200 个像素点的状态和点亮顺序。

#### 验收标准

1. THE GhostMatrixModel SHALL 存储一个 160×120 的 Bool 二维数组（ghostMask），标记哪些坐标属于 Ghost_Logo
2. THE GhostMatrixModel SHALL 在每次升级时生成新的 Activation_Order：将所有 19,200 个像素索引随机打乱（Fisher-Yates shuffle）
3. THE GhostMatrixModel SHALL 提供 `getActivePixels(wordCount: Int) -> Set<Int>` 方法：根据当前字数计算需要点亮的像素数量（每字点亮约 2 个像素，即 wordCount × 19200 / 10000），从 Activation_Order 取前 N 个索引
4. THE Activation_Order SHALL 在升级时持久化到 UserDefaults 或本地文件，确保用户重启 App 后点亮状态一致
5. THE ghostMask 数据 SHALL 从一张 160×120 的黑白 PNG 位图解析生成（白色=Logo，黑色=背景），位图文件存放在 Resources 目录

### 需求 6：万字升级机制

**用户故事：** 作为用户，我希望每输入 10,000 字就能升一级，看到 Ghost 变得更加清晰和稳定。

#### 验收标准

1. EACH Level SHALL 需要 10,000 字输入（10,000 XP）才能升级，共 10 级（Lv.1 ~ Lv.10），总计 100,000 字
2. WHEN 当前等级的字数达到 10,000，THE system SHALL 触发升级仪式：全屏像素闪烁 → 背景像素熄灭 → Ghost 亮度提升 → 重置进度开始下一级
3. THE Ghost_Opacity SHALL 按等级线性递增：Lv.1=10%, Lv.2=20%, ..., Lv.10=100%
4. THE Ghost 动效 SHALL 按等级演进：
   - Lv.1~3（幽灵态）：高频 glitch 闪烁，opacity 在 0~Ghost_Opacity 间随机跳变，模拟信号不稳定
   - Lv.4~6（呼吸态）：低频正弦呼吸，opacity 在 Ghost_Opacity×0.7 ~ Ghost_Opacity 间平滑波动
   - Lv.7~9（觉醒态）：稳定呼吸 + 微弱辉光溢出
   - Lv.10（完全体）：常亮 100% + 强力 Bloom 光效，Ghost 像素比背景像素明显更亮
5. WHEN 用户升级后重新开始下一级，THE 背景像素 SHALL 全部重置为未激活状态，但 Ghost_Logo 像素 SHALL 保持当前等级的基础亮度

### 需求 7：XP 数据来源与同步

**用户故事：** 作为用户，我希望我的语音输入字数和校准互动都能累积为 Ghost Twin 的经验值。

#### 验收标准

1. THE Ghost Twin 状态 SHALL 通过 `GET /api/v1/ghost-twin/status` 从后端获取，响应包含 `level`、`total_xp`、`current_level_xp`、`personality_profile_version` 等字段
2. THE XP 来源 SHALL 包含两部分：
   - **打字 XP**：用户每次通过 GHOSTYPE 发送文本时，服务端根据字数自动累加（1 字 = 1 XP），此逻辑复用现有 `POST /api/v1/llm/chat` 的字数统计
   - **校准 XP**：用户完成校准挑战后，服务端根据挑战类型返回 XP 奖励（灵魂拷问 500 XP、找鬼游戏 300 XP、预判赌局 200 XP）
3. THE IncubatorPage SHALL 在 onAppear 时调用 status API，获取最新等级和进度
4. THE 等级计算逻辑 SHALL 由服务端负责：`level = min(total_xp / 10000, 10)`，`current_level_xp = total_xp % 10000`，客户端仅展示
5. IF 后端 API 不可用，THEN THE system SHALL 使用本地缓存的最后已知值（UserDefaults），不影响页面显示
6. THE 客户端 SHALL 在每次 LLM 调用成功后主动刷新 Ghost Twin status，以反映最新 XP 变化

### 需求 8：校准系统（独立 LLM 调用链路）

**用户故事：** 作为用户，我希望通过有趣的互动问答来训练我的 Ghost Twin，让它越来越像我。

#### 验收标准

1. THE 校准系统 SHALL 独立于 AI 润色的 LLM 调用链路，使用专用的后端接口和 Prompt
2. THE 客户端 SHALL 通过 `GET /api/v1/ghost-twin/challenge` 获取当日校准挑战，服务端基于用户当前等级和人格档案版本，调用 LLM 生成情境问答题
3. THE 校准挑战 SHALL 包含三种类型（服务端根据等级和档案完整度自动选择）：
   - **灵魂拷问 (Dilemma)**：价值观冲突场景 + 2~3 个选项（校准「神」层），奖励 500 XP
   - **找鬼游戏 (Reverse Turing Test)**：3 段回复文本，用户选出最像自己的（校准「形」层），奖励 300 XP
   - **预判赌局 (Prediction Bet)**：给出半句话，用户选择最可能的续写（校准「法」层），奖励 200 XP
4. WHEN 用户选择答案，THE 客户端 SHALL 调用 `POST /api/v1/ghost-twin/challenge/answer`，请求体包含 `challenge_id` 和 `selected_option`
5. THE 服务端 SHALL 处理答案后返回：`xp_earned`（本次获得的 XP）、`new_total_xp`、`new_level`、`ghost_response`（Ghost 的俏皮反馈语，如 "哈哈，我就知道你会选这个！"）
6. THE 每日校准挑战 SHALL 限制为 3 次（服务端控制），客户端显示剩余次数
7. THE 校准挑战的 Prompt 和答案处理逻辑 SHALL 全部在服务端执行，客户端仅负责展示题目和提交答案，不接触任何 Prompt 内容

### 需求 8a：热敏纸条交互（校准 UI）

**用户故事：** 作为用户，我希望校准挑战以热敏纸条的形式从 CRT 屏幕上方滑出，保持赛博朋克的沉浸感。

#### 验收标准

1. WHEN 有校准任务可用时，THE CRT_Container 上方 SHALL 显示一个可点击的提示（闪烁的 ">> INCOMING..." 文字）
2. WHEN 用户点击提示，THE system SHALL 调用 challenge API 获取题目，然后从 CRT 屏幕上方滑出一张 Receipt_Slip（热敏纸条），覆盖在点阵屏上层
3. THE Receipt_Slip SHALL 使用等宽像素字体显示任务内容，背景为米白色（模拟热敏纸），带有轻微的纸张纹理
4. THE Receipt_Slip SHALL 支持显示场景描述和 2~3 个选项按钮（如 [A] 硬刚 [B] 委婉）
5. WHEN 用户选择一个选项，THE 客户端 SHALL 提交答案到服务端，等待返回后：
   - Receipt_Slip 以收回动画（向上滑出）消失
   - 显示 Ghost 的反馈语（ghost_response）
   - 触发数据注入动效（像素粒子飞向 Ghost）
   - 更新 XP 进度条
6. WHEN 当日 3 次挑战已用完，THE 提示文字 SHALL 变为 ">> NO MORE SIGNALS TODAY"，不可点击

### 需求 8b：人格档案渐进式生成

**用户故事：** 作为用户，我希望 Ghost Twin 随着我的使用和校准互动，逐渐形成独特的人格特征。

#### 验收标准

1. THE 人格档案 SHALL 存储在云端，由服务端管理，客户端不直接读写档案内容
2. THE 人格档案 SHALL 分三层渐进式生成（对应神形法三层，但前端不暴露此概念）：
   - **Lv.1~3 解锁「形」层**：通过用户的打字习惯和校准回答，提取语言 DNA（口癖、句式、标点习惯、句长偏好）
   - **Lv.4~6 解锁「神」层**：通过灵魂拷问类校准，建立价值观模型（核心价值观、决策倾向、社交策略）
   - **Lv.7~10 解锁「法」层**：通过预判赌局类校准，建立情境规则（不同对象/场景下的语体切换逻辑）
3. THE 服务端 SHALL 在每次校准回答后，调用 LLM 对人格档案进行增量更新（而非全量重建）
4. THE 服务端 SHALL 在每次升级时，调用 LLM 对人格档案进行一次「阶段性总结」，整合该等级内所有校准数据，生成更精炼的档案版本
5. THE 客户端 SHALL 通过 `GET /api/v1/ghost-twin/status` 获取人格档案的摘要信息（如已捕捉的特征标签列表），用于在孵化室展示（如 "已捕捉: [直接] [效率至上] [冷幽默]"），但不获取完整档案
6. THE 人格档案的完整内容 SHALL 仅在服务端用于 Prompt 构建，永远不传输到客户端（隐私 + 保护核心技术）

### 需求 9：本地化字符串

**用户故事：** 作为用户，我希望孵化室的所有文案支持中英文切换。

#### 验收标准

1. THE L.Nav enum SHALL 新增 `incubator` 属性，中文 "孵化室"，英文 "Incubator"
2. THE L enum SHALL 新增 `Incubator` 子枚举，包含以下本地化字符串：
   - `title`：中文 "孵化室" / 英文 "Incubator"
   - `level`：中文 "等级" / 英文 "Level"
   - `syncRate`：中文 "同步率" / 英文 "Sync Rate"
   - `wordsProgress`：中文 "%d / 10,000 字" / 英文 "%d / 10,000 words"
   - `levelUp`：中文 "升级完成" / 英文 "Level Up"
   - `ghostStatus`：中文 "状态" / 英文 "Status"
   - `incoming`：中文 ">> 收到传讯..." / 英文 ">> INCOMING..."
3. ALL UI text in IncubatorPage SHALL use `L.Incubator.*` accessors, no hardcoded strings

### 需求 10：Ghost 闲置状态文案

**用户故事：** 作为用户，我希望 Ghost 在闲置时会说一些俏皮的话，让它感觉像一个有生命的存在。

#### 验收标准

1. THE IncubatorPage SHALL 在 CRT 屏幕下方区域随机显示 Ghost 的闲置文案，使用等宽字体
2. THE 闲置文案 SHALL 根据等级分组：
   - Lv.1~3：简短、懵懂（如 "...learning...", "feed me words", "o_O ?"）
   - Lv.4~6：有个性（如 "Typing too slow.", "I saw a typo.", "Bored."）
   - Lv.7~9：自信（如 "Almost there.", "I know your style.", "Ready."）
   - Lv.10：完全体（如 "I am you.", "Ready whenever.", "Let me talk for you."）
3. THE 文案 SHALL 每 8~15 秒随机切换一条，使用打字机效果（逐字显示）
4. THE 闲置文案 SHALL 存储在本地化文件中，支持中英文

### 需求 11：输出服务端 API 需求文档

**用户故事：** 作为开发者，我需要在客户端开发完成后输出一份完整的 API 需求文档，供服务端团队实现 Ghost Twin 后端接口。

#### 验收标准

1. THE API 需求文档 SHALL 输出为 `GHOST_TWIN_API_SPEC.md`，存放在项目根目录
2. THE 文档 SHALL 包含以下端点定义（含请求/响应 JSON Schema）：
   - `GET /api/v1/ghost-twin/status`：获取 Ghost Twin 状态（level、total_xp、current_level_xp、personality_tags、challenges_remaining_today）
   - `GET /api/v1/ghost-twin/challenge`：获取当日校准挑战（challenge_id、type、scenario、options[]）
   - `POST /api/v1/ghost-twin/challenge/answer`：提交校准答案（challenge_id、selected_option → xp_earned、new_total_xp、new_level、ghost_response、personality_tags_updated）
3. THE 文档 SHALL 包含服务端 LLM 调用的 Prompt 初稿，分为三类：
   - **校准挑战生成 Prompt**：根据用户等级和当前人格档案，生成对应类型的情境问答题（灵魂拷问 / 找鬼游戏 / 预判赌局）
   - **人格档案增量更新 Prompt**：根据用户的校准回答，对人格档案的对应层（形/神/法）进行增量修正
   - **人格档案阶段性总结 Prompt**：在升级时，整合该等级内所有校准数据，生成精炼的档案版本
4. THE 文档 SHALL 包含数据模型定义：
   - `GhostTwinProfile`：人格档案结构（form_layer、spirit_layer、method_layer、version、updated_at）
   - `CalibrationChallenge`：校准挑战结构（id、type、scenario、options、target_layer、xp_reward）
   - `CalibrationAnswer`：校准回答记录（challenge_id、selected_option、xp_earned、profile_diff、created_at）
5. THE 文档 SHALL 明确标注：所有 Prompt 内容和人格档案完整数据仅存在于服务端，客户端永远不接触
6. THE 文档 SHALL 在客户端 UI 开发完成后、联调前输出
