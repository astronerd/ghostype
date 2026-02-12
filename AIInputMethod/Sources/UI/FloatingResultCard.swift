import SwiftUI
import AppKit

// MARK: - Floating Result Card View

/// 悬浮结果卡片：在不可输入场景下展示 AI 输出
struct FloatingResultCardView: View {
    let skillIcon: String
    let skillName: String
    let userSpeechText: String
    let aiResult: String
    var onCopy: () -> Void
    var onShare: () -> Void
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
                    Image(systemName: "xmark")
                        .font(DS.Typography.caption)
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
                .fixedSize(horizontal: false, vertical: true)

            // 底部按钮
            HStack(spacing: DS.Spacing.sm) {
                Spacer()
                Button(action: onCopy) {
                    Label(L.FloatingCard.copy, systemImage: "doc.on.doc")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.text2)

                Button(action: onShare) {
                    Label(L.FloatingCard.share, systemImage: "square.and.arrow.up")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.text2)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Floating Result Card Controller

/// 悬浮结果卡片窗口控制器
/// 使用 NSPanel（nonactivatingPanel）实现，不抢焦点
class FloatingResultCardController {
    static let shared = FloatingResultCardController()

    private var panel: NSPanel?

    /// 显示悬浮卡片
    func show(skill: SkillModel, speechText: String, result: String, near: CGPoint?) {
        dismiss()

        let view = FloatingResultCardView(
            skillIcon: skill.icon,
            skillName: skill.name,
            userSpeechText: speechText,
            aiResult: result,
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
                self?.dismiss()
            },
            onShare: { [weak self] in
                let picker = NSSharingServicePicker(items: [result])
                if let panel = self?.panel {
                    picker.show(relativeTo: .zero, of: panel.contentView!, preferredEdge: .minY)
                }
            },
            onDismiss: { [weak self] in
                self?.dismiss()
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

        // 定位
        let origin = calculateOrigin(near: near, panelSize: hostingView.fittingSize)
        panel.setFrameOrigin(origin)

        // Escape 关闭
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    /// 关闭卡片
    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// 计算卡片位置
    private func calculateOrigin(near: CGPoint?, panelSize: NSSize) -> NSPoint {
        if let point = near, let screen = NSScreen.main {
            // 光标附近，向右下偏移
            let x = min(point.x + 10, screen.frame.maxX - panelSize.width - 10)
            let y = max(point.y - panelSize.height - 10, screen.frame.minY + 10)
            return NSPoint(x: x, y: y)
        }

        // 无光标位置，屏幕居中
        guard let screen = NSScreen.main else {
            return NSPoint(x: 100, y: 100)
        }
        let x = (screen.frame.width - panelSize.width) / 2 + screen.frame.origin.x
        let y = (screen.frame.height - panelSize.height) / 2 + screen.frame.origin.y
        return NSPoint(x: x, y: y)
    }
}
