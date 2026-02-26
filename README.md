<p align="center">
  <img src="AIInputMethod/Sources/Resources/GhosTYPELogo.svg" alt="GHOSTYPE Logo" width="120">
</p>

<h1 align="center">GHOSTYPE 鬼才打字</h1>

<p align="center">
  macOS 语音输入 + AI 助手，用说的代替打字。
</p>

<p align="center">
  <a href="https://www.ghostype.one">官网</a> ·
  <a href="https://github.com/astronerd/ghostype/releases">下载</a>
</p>

---

## 什么是 GHOSTYPE？

GHOSTYPE 是一个 macOS 菜单栏应用，通过语音识别（ASR）将你说的话转成文字，再用 AI 帮你润色、翻译、生成回复。它常驻后台，随时按快捷键唤起，说完自动输入到当前光标位置。

核心理念：**用说的代替打字，让 AI 帮你把话说得更好。**

## 功能

**🎙️ 语音输入** — 按住快捷键说话，松开即输入。基于豆包流式 ASR，低延迟，支持中英混合。

**🤖 AI Skills** — 内置润色、翻译、备忘录等技能，支持用 Markdown 自定义 Skill。

**👻 Ghost Twin** — 学习你的语言习惯，用你的口吻帮你回复消息。自动识别不同 app 的语境差异。

**🎨 Dashboard** — CRT 复古风格界面，管理技能、偏好设置、Ghost Twin 孵化。

**🔄 自动更新** — 基于 Sparkle，DMG 拖拽安装。

## 系统要求

- macOS 14.0 (Sonoma)+
- 麦克风权限（语音识别）
- 辅助功能权限（检测文本输入框）

## 构建

```bash
# 克隆
git clone https://github.com/astronerd/ghostype.git
cd ghostype/AIInputMethod

# Debug 构建（ad-hoc 签名）
bash ghostype.sh debug

# Release 构建（需要 Developer ID）
bash ghostype.sh release

# 发布（编译 + 签名 + 公证 + DMG + GitHub Release）
bash ghostype.sh publish
```

需要在 `AIInputMethod/` 目录下创建 `.env` 文件，参考 `.env.example`。

## 项目结构

```
AIInputMethod/
├── Sources/
│   ├── AIInputMethodApp.swift          # 入口
│   ├── Features/
│   │   ├── AI/                         # AI 引擎、Skill 系统
│   │   ├── Speech/                     # 语音识别（豆包 ASR）
│   │   ├── VoiceInput/                 # 语音输入协调器
│   │   ├── Hotkey/                     # 快捷键管理
│   │   ├── Dashboard/                  # 数据层、ViewModel
│   │   ├── Settings/                   # 设置、本地化
│   │   ├── Auth/                       # 认证
│   │   ├── Accessibility/              # 辅助功能、上下文检测
│   │   └── Contacts/                   # 通讯录（ASR 热词）
│   ├── UI/
│   │   ├── Dashboard/                  # Dashboard 界面
│   │   ├── OverlayView.swift           # 语音输入浮层
│   │   └── OnboardingWindow.swift      # 引导页
│   └── Resources/                      # 图标、图片
├── Frameworks/
│   └── Sparkle.framework               # 自动更新
├── ghostype.sh                         # 统一构建脚本
└── Package.swift
```

## 技术栈

- Swift 5.9 / SwiftUI + AppKit
- Swift Package Manager
- Sparkle（自动更新）
- WebSocket（流式 ASR）
- CoreData（本地数据）
- Keychain（凭证存储）

## License

MIT
