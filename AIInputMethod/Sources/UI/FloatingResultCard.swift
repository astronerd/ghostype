import SwiftUI
import AppKit

// MARK: - Floating Result Card View

/// 悬浮结果卡片：在不可输入场景下展示 AI 输出
/// 类似 iOS 截图效果，出现在屏幕角落，10 秒后自动消失
struct FloatingResultCardView: View {
    let skillIcon: String
    let skillName: String
    let userSpeechText: String
    let aiResult: String
    let debugInfo: String
    var onCopy: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // 顶部：Skill 图标 + 名称 + 关闭按钮
            HStack {
                Image(systemName: skillIcon)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.icon)
                Text(skillName)
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text1)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.text3)
                }
                .buttonStyle(.plain)
            }

            // 用户语音原文
            if !userSpeechText.isEmpty {
                Text(userSpeechText)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
                    .lineLimit(2)
            }

            // AI 结果
            Text(aiResult)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
                .textSelection(.enabled)
                .lineLimit(6)

            // 调试信息（检测到快捷键冲突时显示友好提示）
            if !debugInfo.isEmpty {
                let isHotkeyConflict = debugInfo.contains("-25212")

                VStack(alignment: .leading, spacing: 4) {
                    if isHotkeyConflict {
                        Text(L.FloatingCard.hotkeyConflict)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.statusWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                            Text("Debug")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(DS.Colors.text2)

                        Text(debugInfo)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(DS.Colors.text2)
                            .lineLimit(10)
                    }
                }
                .padding(DS.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isHotkeyConflict ? Color.yellow.opacity(0.1) : Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // 底部按钮：复制 + 关闭
            HStack(spacing: DS.Spacing.md) {
                Spacer()
                Button(action: onCopy) {
                    Label(L.FloatingCard.copy, systemImage: "doc.on.doc")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.text2)

                Button(action: onDismiss) {
                    Label(L.Common.close, systemImage: "xmark")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.text2)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Card Entry (for stacking)

/// 单张卡片的数据 + 窗口引用
private class CardEntry {
    let id: UUID
    let panel: NSPanel
    var autoCloseTimer: DispatchWorkItem?
    var escMonitor: Any?

    init(id: UUID, panel: NSPanel) {
        self.id = id
        self.panel = panel
    }

    func cleanup() {
        autoCloseTimer?.cancel()
        autoCloseTimer = nil
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        panel.orderOut(nil)
    }
}

// MARK: - Floating Result Card Controller

/// 悬浮结果卡片窗口控制器
/// 支持多卡片堆叠，出现在屏幕右下角，10 秒后自动消失
class FloatingResultCardController {
    static let shared = FloatingResultCardController()

    private var cards: [CardEntry] = []
    private let cardSpacing: CGFloat = 8
    private let screenMargin: CGFloat = 16
    private let autoCloseSeconds: TimeInterval = 10

    /// 显示悬浮卡片（支持堆叠）
    func show(skill: SkillModel, speechText: String, result: String, debugInfo: String = "", near: CGPoint?) {
        let cardId = UUID()

        let copyContent: String = {
            var parts = [result]
            if !debugInfo.isEmpty {
                parts.append("\n---\nDebug:\n\(debugInfo)")
            }
            return parts.joined()
        }()

        let view = FloatingResultCardView(
            skillIcon: skill.icon,
            skillName: skill.name,
            userSpeechText: speechText,
            aiResult: result,
            debugInfo: debugInfo,
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(copyContent, forType: .string)
                self?.dismissCard(id: cardId)
            },
            onDismiss: { [weak self] in
                self?.dismissCard(id: cardId)
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true

        let entry = CardEntry(id: cardId, panel: panel)

        // Escape 关闭当前最上面的卡片
        entry.escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismissCard(id: cardId)
                return nil
            }
            return event
        }

        cards.append(entry)
        repositionAllCards()
        panel.orderFront(nil)

        // 10 秒后自动消失
        let autoClose = DispatchWorkItem { [weak self] in
            self?.dismissCard(id: cardId)
        }
        entry.autoCloseTimer = autoClose
        DispatchQueue.main.asyncAfter(deadline: .now() + autoCloseSeconds, execute: autoClose)
    }

    /// 显示纯文本卡片（不依赖 Skill，用于 insertTextAtCursor 的 noInput 回退）
    func showText(text: String, debugInfo: String = "") {
        let cardId = UUID()

        let view = FloatingResultCardView(
            skillIcon: "text.bubble",
            skillName: "GHOSTYPE",
            userSpeechText: "",
            aiResult: text,
            debugInfo: debugInfo,
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                self?.dismissCard(id: cardId)
            },
            onDismiss: { [weak self] in
                self?.dismissCard(id: cardId)
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true

        let entry = CardEntry(id: cardId, panel: panel)

        entry.escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismissCard(id: cardId)
                return nil
            }
            return event
        }

        cards.append(entry)
        repositionAllCards()
        panel.orderFront(nil)

        let autoClose = DispatchWorkItem { [weak self] in
            self?.dismissCard(id: cardId)
        }
        entry.autoCloseTimer = autoClose
        DispatchQueue.main.asyncAfter(deadline: .now() + autoCloseSeconds, execute: autoClose)
    }

        /// 关闭指定卡片
    func dismissCard(id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let entry = cards.remove(at: index)
        entry.cleanup()
        repositionAllCards()
    }

    /// 关闭所有卡片
    func dismissAll() {
        for entry in cards {
            entry.cleanup()
        }
        cards.removeAll()
    }

    /// 重新排列所有卡片位置（从屏幕右下角向上堆叠）
    private func repositionAllCards() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        var currentY = visibleFrame.minY + screenMargin

        for entry in cards {
            let panelSize = entry.panel.frame.size
            let x = visibleFrame.maxX - panelSize.width - screenMargin
            let y = currentY

            entry.panel.setFrameOrigin(NSPoint(x: x, y: y))
            currentY += panelSize.height + cardSpacing
        }
    }
}
