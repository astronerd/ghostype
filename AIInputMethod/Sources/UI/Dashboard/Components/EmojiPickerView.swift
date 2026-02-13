//
//  EmojiPickerView.swift
//  AIInputMethod
//
//  Emoji 选择器组件 - 点击弹出 popover，支持分类浏览和搜索
//

import SwiftUI

// MARK: - Emoji Data

struct EmojiCategory: Identifiable {
    let id: String
    let icon: String
    let emojis: [String]
}

enum EmojiData {
    static let categories: [EmojiCategory] = [
        EmojiCategory(id: "frequent", icon: "🕐", emojis: [
            "✨", "📝", "🌐", "👻", "🪞", "⚡", "🎯", "🔥", "💡", "🚀",
            "🎨", "🎵", "📧", "💬", "🤖", "🧠", "📊", "🔧", "📌", "⭐"
        ]),
        EmojiCategory(id: "smileys", icon: "😀", emojis: [
            "😀", "😃", "😄", "😁", "😆", "🥹", "😅", "🤣", "😂", "🙂",
            "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😎", "🤓", "🧐",
            "🤔", "🤗", "🤭", "😏", "😌", "😴", "🥱", "😷", "🤯", "🥳"
        ]),
        EmojiCategory(id: "animals", icon: "🐱", emojis: [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
            "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🦅", "🦉",
            "🦋", "🐛", "🐝", "🐞", "🦀", "🐙", "🐠", "🐳", "🦈", "🐊"
        ]),
        EmojiCategory(id: "food", icon: "🍎", emojis: [
            "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍒",
            "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🥑", "🌽", "🌶️", "🧄",
            "🍔", "🍕", "🌮", "🍜", "🍣", "🍰", "🧁", "☕", "🍵", "🧋"
        ]),
        EmojiCategory(id: "activities", icon: "⚽", emojis: [
            "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🎱", "🏓", "🏸", "🥊",
            "🎮", "🕹️", "🎲", "🧩", "🎭", "🎨", "🎬", "🎤", "🎧", "🎵",
            "🎹", "🥁", "🎷", "🎺", "🎸", "🪘", "🎻", "🏆", "🥇", "🎖️"
        ]),
        EmojiCategory(id: "travel", icon: "🚗", emojis: [
            "🚗", "🚕", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "✈️", "🚀",
            "🛸", "🚁", "⛵", "🚢", "🏠", "🏢", "🏰", "🗼", "🗽", "⛩️",
            "🌍", "🌎", "🌏", "🗺️", "🧭", "🏔️", "⛰️", "🌋", "🏝️", "🏖️"
        ]),
        EmojiCategory(id: "objects", icon: "💡", emojis: [
            "💡", "🔦", "🕯️", "📱", "💻", "⌨️", "🖥️", "🖨️", "📷", "🎥",
            "📺", "📻", "⏰", "⌚", "📡", "🔋", "🔌", "💾", "💿", "📀",
            "🔑", "🗝️", "🔒", "🔓", "📦", "📫", "📮", "🗑️", "🔧", "🔨"
        ]),
        EmojiCategory(id: "symbols", icon: "❤️", emojis: [
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
            "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "⭐", "🌟",
            "✨", "⚡", "🔥", "💥", "☀️", "🌙", "⛅", "🌈", "☁️", "❄️"
        ]),
    ]

    /// 搜索 emoji（基于关键词映射）
    static func search(_ query: String) -> [String] {
        let q = query.lowercased()
        if q.isEmpty { return [] }

        // 简单的关键词 → emoji 映射
        let keywordMap: [String: [String]] = [
            "star": ["⭐", "🌟", "✨", "💫", "🌠"],
            "heart": ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "💕", "💖"],
            "fire": ["🔥", "🧯", "🚒"],
            "smile": ["😀", "😃", "😄", "😁", "😊", "🙂"],
            "sad": ["😢", "😭", "😞", "😔", "🥺"],
            "cat": ["🐱", "😺", "😸", "😻", "🙀", "😿", "😾"],
            "dog": ["🐶", "🐕", "🦮", "🐩"],
            "music": ["🎵", "🎶", "🎤", "🎧", "🎹", "🎸", "🎷", "🎺"],
            "book": ["📖", "📚", "📕", "📗", "📘", "📙"],
            "write": ["✍️", "📝", "✏️", "🖊️", "🖋️"],
            "mail": ["📧", "📨", "📩", "📬", "📮", "✉️"],
            "phone": ["📱", "📞", "☎️", "📲"],
            "computer": ["💻", "🖥️", "⌨️", "🖱️"],
            "robot": ["🤖"],
            "brain": ["🧠"],
            "ghost": ["👻"],
            "magic": ["✨", "🪄", "🔮", "🧙"],
            "rocket": ["🚀"],
            "tool": ["🔧", "🔨", "⚙️", "🛠️"],
            "light": ["💡", "🔦", "🕯️", "☀️"],
            "flag": ["🏁", "🚩", "🎌", "🏴", "🏳️"],
            "money": ["💰", "💵", "💴", "💶", "💷", "🪙", "💎"],
            "time": ["⏰", "⌚", "⏱️", "⏳", "🕐"],
            "food": ["🍎", "🍕", "🍔", "🌮", "🍜", "🍣", "🍰"],
            "drink": ["☕", "🍵", "🧋", "🍺", "🍷", "🥤"],
            "weather": ["☀️", "🌙", "⛅", "🌈", "☁️", "❄️", "🌧️"],
            "plant": ["🌱", "🌿", "🍀", "🌸", "🌺", "🌻", "🌹"],
            "target": ["🎯", "🏹"],
            "pin": ["📌", "📍"],
            "lock": ["🔒", "🔓", "🔑", "🗝️"],
            "chat": ["💬", "💭", "🗨️", "🗯️"],
            "translate": ["🌐", "🗣️"],
            "art": ["🎨", "🖼️", "🖌️"],
            "game": ["🎮", "🕹️", "🎲", "🧩"],
            "sport": ["⚽", "🏀", "🏈", "⚾", "🎾"],
            // 中文关键词
            "笔": ["✏️", "🖊️", "🖋️", "📝"],
            "记": ["📝", "📒", "📓"],
            "翻译": ["🌐", "🗣️"],
            "火": ["🔥"],
            "星": ["⭐", "🌟", "✨"],
            "心": ["❤️", "💕", "💖", "💗"],
            "猫": ["🐱", "😺"],
            "狗": ["🐶", "🐕"],
            "音乐": ["🎵", "🎶", "🎤"],
            "书": ["📖", "📚"],
            "邮件": ["📧", "✉️"],
            "电脑": ["💻", "🖥️"],
            "手机": ["📱", "📲"],
            "机器人": ["🤖"],
            "大脑": ["🧠"],
            "幽灵": ["👻"],
            "魔法": ["✨", "🪄", "🔮"],
            "火箭": ["🚀"],
            "工具": ["🔧", "🔨", "⚙️"],
            "灯": ["💡", "🔦"],
            "钱": ["💰", "💵"],
            "时间": ["⏰", "⌚"],
            "天气": ["☀️", "🌙", "🌈"],
            "花": ["🌸", "🌺", "🌻", "🌹"],
            "目标": ["🎯"],
            "锁": ["🔒", "🔑"],
            "聊天": ["💬", "💭"],
            "画": ["🎨", "🖼️"],
            "游戏": ["🎮", "🕹️"],
            "运动": ["⚽", "🏀"],
        ]

        var results: [String] = []
        for (keyword, emojis) in keywordMap {
            if keyword.contains(q) || q.contains(keyword) {
                results.append(contentsOf: emojis)
            }
        }
        // 去重保持顺序
        var seen = Set<String>()
        return results.filter { seen.insert($0).inserted }
    }
}

// MARK: - Emoji Picker Button

/// 点击显示当前 emoji，弹出 popover 选择
struct EmojiPickerButton: View {
    @Binding var selectedEmoji: String
    var size: CGFloat = 36

    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker.toggle() }) {
            Text(selectedEmoji)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(DS.Colors.highlight)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Layout.cornerRadius + 2)
                        .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius + 2))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            EmojiPickerPopover(selectedEmoji: $selectedEmoji, isPresented: $showPicker)
        }
    }
}

// MARK: - Emoji Picker Popover

struct EmojiPickerPopover: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var selectedCategoryId = "frequent"

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.text2)
                TextField(L.Skill.searchEmoji, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.body)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colors.text2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.bg2)

            MinimalDivider()

            if searchText.isEmpty {
                // 分类标签栏
                HStack(spacing: 2) {
                    ForEach(EmojiData.categories) { cat in
                        Button(action: { selectedCategoryId = cat.id }) {
                            Text(cat.icon)
                                .font(.system(size: 14))
                                .frame(width: 28, height: 28)
                                .background(selectedCategoryId == cat.id ? DS.Colors.highlight : Color.clear)
                                .cornerRadius(DS.Layout.cornerRadius)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)

                MinimalDivider()
            }

            // Emoji 网格
            ScrollView {
                let emojis = searchText.isEmpty
                    ? (EmojiData.categories.first(where: { $0.id == selectedCategoryId })?.emojis ?? [])
                    : EmojiData.search(searchText)

                if emojis.isEmpty && !searchText.isEmpty {
                    Text(L.Memo.noMatch)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                        .padding(DS.Spacing.xl)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                                isPresented = false
                            }) {
                                Text(emoji)
                                    .font(.system(size: 20))
                                    .frame(width: 32, height: 32)
                                    .background(selectedEmoji == emoji ? DS.Colors.highlight : Color.clear)
                                    .cornerRadius(DS.Layout.cornerRadius)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
        .frame(width: 290, height: 320)
        .background(DS.Colors.bg1)
    }
}
