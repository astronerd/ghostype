# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GHOSTYPE (鬼才打字) is a macOS voice input application built with Swift 5.9+ and SwiftUI, targeting macOS 14+ (Sonoma). It provides voice-to-text with AI polish, translation, memo capture, and a "Ghost Twin" personality system. The app runs as a menu bar agent (`LSUIElement`), uses CoreData for persistence, and Sparkle for auto-updates.

## Build Commands

All commands run from the `AIInputMethod/` directory. The unified build script is `ghostype.sh`.

```bash
# Debug build → bundle .app → launch
bash ghostype.sh debug

# Debug build with clean local data (simulates fresh install)
bash ghostype.sh debug --clean

# Release build → bundle .app → launch
bash ghostype.sh release

# Full publish: release build → zip → EdDSA sign → appcast.xml → GitHub Release
bash ghostype.sh publish [version]
```

Under the hood, `ghostype.sh` calls `swift build -c debug|release`, then bundles the executable into `GHOSTYPE.app` with frameworks, resources, skills, and a generated `Info.plist`.

## Testing

Tests use Swift Package Manager's test target. Run from `AIInputMethod/`:

```bash
# Run all tests
swift test

# Run a single test class
swift test --filter AIInputMethodTests.ToolRegistryTests

# Run a single test method
swift test --filter AIInputMethodTests.ToolRegistryTests/testRegisteredTools
```

Test files live in `AIInputMethod/Tests/` and follow the naming convention `*PropertyTests.swift` or `*Tests.swift`.

## Architecture

### Entry Point & Core Flow

`AIInputMethodApp.swift` → `AppDelegate` is the central coordinator. The core voice input pipeline:

```
HotkeyManager (captures shortcut) → DoubaoSpeechService (records + ASR)
  → VoiceInputCoordinator (orchestrates) → SkillExecutor (LLM processing)
  → TextInsertionService (pastes to cursor) → PersistenceController (saves to CoreData)
```

### Directory Structure (AIInputMethod/Sources/)

- **Features/** — Business logic modules, each with its own domain:
  - `AI/` — API client (`GhostypeAPIClient`), models, polish/translate profiles
  - `AI/Skill/` — Skill system: `SkillExecutor`, `SkillManager`, `SkillFileParser`, `TemplateEngine`, `ToolRegistry`
  - `Dashboard/` — ViewModels, CoreData models, Ghost Twin profile/XP, calibration flows
  - `VoiceInput/` — `VoiceInputCoordinator`, `OverlayWindowManager`, `TextInsertionService`
  - `Speech/` — `DoubaoSpeechService` (豆包 ASR)
  - `Auth/` — `AuthManager`, `KeychainHelper`
  - `MemoSync/` — Sync memos to Obsidian/Apple Notes/Notion/Bear
  - `Settings/` — `AppSettings`, `AppConfig`, `Logger`, localization (`L.xxx`)
  - `Hotkey/` — Global hotkey registration
  - `Accessibility/` — `CursorManager`, `FocusObserver`, `ContextDetector`
  - `Permissions/` — `PermissionManager` (accessibility, microphone, contacts)
  - `MenuBar/` — Status bar menu management
  - `Update/` — Sparkle update checker
- **UI/** — SwiftUI views:
  - `Dashboard/` — Main settings/dashboard window with sidebar navigation
  - `OverlayView.swift` — Voice input overlay HUD
  - `FloatingResultCard.swift` — Result display card
  - `OnboardingWindow.swift` — First-launch setup

### Skill System

Skills are markdown-driven AI behaviors. Each skill is a `SKILL.md` file with YAML frontmatter and a prompt body. Key principles:

- **SKILL.md is the single source of truth** — no prompts in Swift code
- **SkillExecutor is a generic pipeline** — loads SKILL.md → TemplateEngine variable substitution → LLM call → parse tool call JSON → ToolRegistry dispatch
- **No per-skill branching in executor** — runtime data injected via `{{context.xxx}}` template variables
- Built-in skills in `default_skills/builtin-*` and `internal-*`; user skills in `~/Library/Application Support/GHOSTYPE/skills/`
- Tool calling uses prompt-internal JSON (`{"tool": "provide_text", "content": "..."}`) not Claude native tool use

### Localization

All UI strings use the `L.xxx` accessor pattern. No hardcoded Chinese/English in views.

- `Strings.swift` — Key definitions and protocol declarations
- `Strings+Chinese.swift` / `Strings+English.swift` — Translations
- `Localization.swift` — `AppLanguage` enum and `LocalizationManager`

### Key Singletons

`AppSettings.shared`, `GhostypeAPIClient.shared`, `PersistenceController.shared`, `DashboardWindowController.shared`, `DeviceIdManager.shared`, `LocalizationManager.shared`, `ContactsManager.shared`

### Data Storage

- **CoreData** (`DashboardModel.xcdatamodeld`) — Usage records, quota records
- **UserDefaults** (`com.gengdawei.ghostype`) — App settings
- **File system** (`~/Library/Application Support/GHOSTYPE/`) — Skills, Ghost Twin data

## Important Conventions

- The `--clean` flag on build commands wipes UserDefaults, CoreData, and GHOSTYPE app support directory
- After modifying code, always recompile before bundling — the build script reads from `.build/`
- Ad-hoc signed builds cannot read Keychain data from Developer ID signed builds
- ZIP archives for release must use `ditto`, not `zip` (preserves framework symlinks)
- Credentials are fetched from the server at runtime; `.env` is reserved for future use
