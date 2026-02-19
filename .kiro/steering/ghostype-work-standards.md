---
inclusion: always
---

# GHOSTYPE 工作规范

---

## 一、构建指南

所有命令在 `AIInputMethod/` 目录下执行（`cwd: AIInputMethod`）。
唯一的构建脚本是 `ghostype.sh`。

### 用户说「build debug」

```bash
bash ghostype.sh debug [--clean]
```

编译 debug → 打包 .app → 启动。`--clean` 清除所有本地数据（全新安装状态）。

### 用户说「build release」

```bash
bash ghostype.sh release [--clean]
```

编译 release → 打包 .app（正式版本号、自动更新开启）→ 启动。

### 用户说「publish」

```bash
bash ghostype.sh publish [version]
```

完整发布：编译 release → 打包 → zip → EdDSA 签名 → appcast.xml → GitHub Release。
不传版本号则自动生成 `0.1.MMDDHHmm`。

### --clean 清除范围

- `defaults delete com.gengdawei.ghostype`（UserDefaults）
- `~/Library/Application Support/GHOSTYPE/`（Skills、Ghost Twin 数据）
- `~/Library/Application Support/AIInputMethod/`（CoreData）

### 关键规则

- 修改代码后必须重新编译再打包，不能只 bundle
- ad-hoc 签名的 app 无法读取 Developer ID 签名 app 的 Keychain 数据（需重新登录）
- publish 前确保 EdDSA 私钥在 Keychain、`gh` CLI 已安装并登录

---

## 二、CRT 显示器框架图替换

### 文件

- `AIInputMethod/Sources/Resources/CRTFrame.png`

### 流程

1. 新图裁掉外围 alpha=0 的透明区域（只保留有内容的部分）
2. 用分析脚本对比新旧图的屏幕开口位置（alpha≠255 在不透明外壳内部的区域）
3. 如果缩放到 530×482 后屏幕开口还是 320×240 @ (85,83) → 直接替换，代码不用改
4. 如果不一致 → 更新 `IncubatorPage.swift` 里的 `crtFrameWidth/Height`、`screenWidth/Height`、`screenOffsetX/Y`
5. `bash ghostype.sh release` 验证

### 裁图

```python
from PIL import Image
import numpy as np

img = Image.open('new_frame.png').convert('RGBA')
alpha = np.array(img)[:,:,3]
rows, cols = np.any(alpha > 0, axis=1), np.any(alpha > 0, axis=0)
rmin, rmax = np.where(rows)[0][[0, -1]]
cmin, cmax = np.where(cols)[0][[0, -1]]
img.crop((cmin, rmin, cmax+1, rmax+1)).save('Sources/Resources/CRTFrame.png')
```

---

## 三、文件同步问题

### 问题描述

`strReplace` 和 `readFile` 工具操作的是编辑器内存缓存，不是磁盘上的实际文件。
当使用 `swift build` 或其他外部编译命令时，编译器读取的是磁盘文件，不是缓存。

### 症状

- `strReplace` 显示替换成功
- `readFile` 显示新内容
- 但 `grep` 或 `cat` 显示旧内容
- 编译后运行的还是旧代码

### 解决方案

修改文件后，使用 `executeBash` 运行 `cat` 或 `grep` 验证磁盘文件是否真的更新了。
如果没更新，用 `fsWrite` 直接覆盖整个文件，而不是用 `strReplace`。

---

## 四、多语言本地化规范

### 产品名称

- 英文名：**GHOSTYPE**（全大写）
- 中文名：**「鬼才打字」**

### 文件结构

```
Sources/Features/Settings/
├── Localization.swift      # 语言枚举、LocalizationManager
├── Strings.swift           # 字符串 key 定义（L.xxx 访问器）
├── Strings+Chinese.swift   # 中文翻译
├── Strings+English.swift   # 英文翻译
└── Strings+[Language].swift # 未来新语言
```

### 禁止硬编码

**所有 UI 文案必须使用 `L.xxx` 访问**，禁止在代码中直接写中文或英文字符串。

```swift
// ❌ 错误
Text("偏好设置")
Button("保存")

// ✅ 正确
Text(L.Prefs.title)
Button(L.Common.save)
```

### 添加新文案

1. **Strings.swift** - 添加静态属性
```swift
enum L {
    enum NewSection {
        static var newKey: String { current.newSection.newKey }
    }
}
```

2. **Strings.swift** - 添加 protocol
```swift
protocol NewSectionStrings {
    var newKey: String { get }
}
```

3. **Strings+Chinese.swift** - 添加中文
```swift
private struct ChineseNewSection: NewSectionStrings {
    var newKey: String { "新文案" }
}
```

4. **Strings+English.swift** - 添加英文
```swift
private struct EnglishNewSection: NewSectionStrings {
    var newKey: String { "New Text" }
}
```

### 添加新语言

1. 创建 `Strings+[Language].swift`
2. 实现所有 `*Strings` protocol
3. 在 `Localization.swift` 的 `AppLanguage` 枚举添加新 case
4. 在 `Strings.swift` 的 `current` 计算属性添加新分支

### 修改现有文案

直接修改对应语言文件中的字符串值即可，无需改动其他文件。

### 当前已本地化页面

- [x] PreferencesPage.swift
- [ ] SidebarView.swift
- [ ] OverviewPage.swift
- [ ] LibraryPage.swift
- [ ] MemoPage.swift
- [ ] AIPolishPage.swift
- [ ] OnboardingWindow.swift
