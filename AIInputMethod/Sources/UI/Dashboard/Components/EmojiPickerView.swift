//
//  EmojiPickerView.swift
//  AIInputMethod
//
//  Emoji 选择器 - 输入框 + 系统 emoji 面板
//

import SwiftUI
import AppKit

// MARK: - Emoji Picker Button

/// 点击弹出 popover，输入或粘贴 emoji
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

    @State private var inputText = ""

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // 输入框
            HStack(spacing: DS.Spacing.sm) {
                TextField(L.Skill.emojiInputHint, text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24))
                    .frame(height: 40)
                    .onChange(of: inputText) { _, newValue in
                        let filtered = newValue.filter { $0.isEmoji }
                        if let first = filtered.first {
                            inputText = String(first)
                        } else if !newValue.isEmpty {
                            inputText = ""
                        }
                    }
                
                // 系统 emoji 面板按钮
                Button(action: { NSApp.orderFrontCharacterPalette(nil) }) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.text2)
                        .frame(width: 32, height: 32)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
                .help(L.Skill.openEmojiPanel)
            }
            
            // 确定按钮
            if !inputText.isEmpty {
                Button(action: {
                    selectedEmoji = inputText
                    isPresented = false
                }) {
                    Text(L.Common.save)
                        .font(DS.Typography.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.text1)
                        .foregroundColor(DS.Colors.bg1)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.md)
        .frame(minWidth: 200)
        .fixedSize()
        .background(DS.Colors.bg1)
        .onAppear { inputText = "" }
    }
}

// MARK: - Character Emoji Check

extension Character {
    /// 判断字符是否为 emoji
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
