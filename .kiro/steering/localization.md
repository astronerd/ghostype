# 多语言本地化规范

## 产品名称

- 英文名：**GHOSTYPE**（全大写）
- 中文名：**「鬼才打字」**

## 文件结构

```
Sources/Features/Settings/
├── Localization.swift      # 语言枚举、LocalizationManager
├── Strings.swift           # 字符串 key 定义（L.xxx 访问器）
├── Strings+Chinese.swift   # 中文翻译
├── Strings+English.swift   # 英文翻译
└── Strings+[Language].swift # 未来新语言
```

## 禁止硬编码

**所有 UI 文案必须使用 `L.xxx` 访问**，禁止在代码中直接写中文或英文字符串。

```swift
// ❌ 错误
Text("偏好设置")
Button("保存")

// ✅ 正确
Text(L.Prefs.title)
Button(L.Common.save)
```

## 添加新文案

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

## 添加新语言

1. 创建 `Strings+[Language].swift`
2. 实现所有 `*Strings` protocol
3. 在 `Localization.swift` 的 `AppLanguage` 枚举添加新 case
4. 在 `Strings.swift` 的 `current` 计算属性添加新分支

## 修改现有文案

直接修改对应语言文件中的字符串值即可，无需改动其他文件。

## 当前已本地化页面

- [x] PreferencesPage.swift
- [ ] SidebarView.swift
- [ ] OverviewPage.swift
- [ ] LibraryPage.swift
- [ ] MemoPage.swift
- [ ] AIPolishPage.swift
- [ ] OnboardingWindow.swift
