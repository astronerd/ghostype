//
//  RecordDetailPanel.swift
//  AIInputMethod
//
//  详情面板组件 - Radical Minimalist 极简风格
//

import SwiftUI
import AppKit

// MARK: - RecordDetailPanel

struct RecordDetailPanel: View {
    
    let record: UsageRecord
    var onDelete: (() -> Void)? = nil
    
    @State private var showCopiedToast: Bool = false
    @State private var showDeleteConfirm: Bool = false
    
    private let iconSize: CGFloat = 36
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            MinimalDivider()
                .padding(.horizontal, DS.Spacing.lg)
            contentSection
            toolbarSection
        }
        .background(DS.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
        .overlay(copiedToastOverlay)
        .alert(L.Library.confirmDeleteTitle, isPresented: $showDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) { }
            Button(L.Common.delete, role: .destructive) { onDelete?() }
        } message: {
            Text(L.Library.confirmDeleteMsg)
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            appIconView
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(record.sourceApp.isEmpty ? L.Library.unknownApp : record.sourceApp)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text1)
                
                categoryBadge
                
                HStack(spacing: DS.Spacing.sm) {
                    Label(formattedTimestamp, systemImage: "clock")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    
                    if record.duration > 0 {
                        Label(formattedDuration, systemImage: "waveform")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                    }
                }
            }
            
            Spacer()
        }
        .padding(DS.Spacing.lg)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let icon = getAppIcon(bundleId: record.sourceAppBundleId) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
        } else {
            Image(systemName: "app")
                .font(.system(size: iconSize * 0.4))
                .foregroundColor(DS.Colors.icon)
                .frame(width: iconSize, height: iconSize)
                .background(DS.Colors.bg1)
                .cornerRadius(DS.Layout.cornerRadius)
        }
    }
    
    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Text(skillDisplayName)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text2)
            
            if isSkillDeleted {
                Text("(\(L.Library.skillDeleted))")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.statusWarning)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 2)
        .background(DS.Colors.highlight)
        .cornerRadius(DS.Layout.cornerRadius)
    }
    
    private var contentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let original = record.originalContent, !original.isEmpty {
                    // 原文
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L.Library.originalText)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                        Text(original)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text2)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                    
                    MinimalDivider()
                    
                    // 处理结果
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L.Library.processedText)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                        Text(record.content)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text1)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                } else {
                    Text(record.content)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.lg)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var toolbarSection: some View {
        HStack {
            if onDelete != nil {
                Button(action: { showDeleteConfirm = true }) {
                    Label(L.Common.delete, systemImage: "trash")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.statusError)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.statusError.opacity(0.1))
                .cornerRadius(DS.Layout.cornerRadius)
            }
            
            Spacer()
            
            Button(action: copyToClipboard) {
                Label(L.Library.copyBtn, systemImage: "doc.on.doc")
                    .font(DS.Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(DS.Colors.text2)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.highlight)
            .cornerRadius(DS.Layout.cornerRadius)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.bg1.opacity(0.5))
    }
    
    @ViewBuilder
    private var copiedToastOverlay: some View {
        if showCopiedToast {
            VStack {
                Spacer()
                HStack(spacing: DS.Spacing.sm) {
                    StatusDot(status: .success)
                    Text(L.Library.copiedToast)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text1)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.bg2)
                .overlay(
                    Capsule()
                        .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                )
                .clipShape(Capsule())
                .padding(.bottom, 50)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
        }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        let lang = LocalizationManager.shared.currentLanguage
        formatter.locale = lang == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = lang == .chinese ? "yyyy年M月d日 HH:mm" : "MMM d, yyyy HH:mm"
        return formatter.string(from: record.timestamp)
    }
    
    private var formattedDuration: String {
        let seconds = Int(record.duration)
        if seconds < 60 { return String(format: L.Library.seconds, seconds) }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 { return String(format: L.Library.minutes, minutes) }
        return String(format: L.Library.minuteSeconds, minutes, remainingSeconds)
    }
    
    private var skillDisplayName: String {
        // New records with skillName
        if let name = record.skillName, !name.isEmpty {
            return name
        }
        // Legacy records: derive from category
        switch record.category {
        case "polish": return L.Library.polish
        case "translate": return L.Library.translate
        case "memo": return L.Library.memo
        default: return L.Library.categoryGeneral
        }
    }
    
    private var isSkillDeleted: Bool {
        guard let skillId = record.skillId, !skillId.isEmpty else { return false }
        return SkillManager.shared.skill(byId: skillId) == nil
    }
    
    private func getAppIcon(bundleId: String) -> NSImage? {
        guard !bundleId.isEmpty else { return nil }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.content, forType: .string)
        
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }
}

// MARK: - RecordDetailEmptyView

struct RecordDetailEmptyView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(DS.Colors.text3)
            
            Text(L.Library.selectRecord)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg2.opacity(0.5))
    }
}

// MARK: - Preview

#if DEBUG
struct RecordDetailPanel_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let record = UsageRecord(context: context)
        record.id = UUID()
        record.content = "这是一条测试记录内容。"
        record.category = "memo"
        record.sourceApp = "Notes"
        record.sourceAppBundleId = "com.apple.Notes"
        record.timestamp = Date()
        record.duration = 15
        record.deviceId = "test"
        
        return RecordDetailPanel(record: record)
            .frame(width: 350, height: 400)
            .padding()
    }
}
#endif
