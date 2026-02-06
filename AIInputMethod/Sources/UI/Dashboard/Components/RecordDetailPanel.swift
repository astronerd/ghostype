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
    
    @State private var showCopiedToast: Bool = false
    
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
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            appIconView
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(record.sourceApp.isEmpty ? "未知应用" : record.sourceApp)
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
        Text(categoryDisplayName)
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.text2)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 2)
            .background(DS.Colors.highlight)
            .cornerRadius(DS.Layout.cornerRadius)
    }
    
    private var contentSection: some View {
        ScrollView {
            Text(record.content)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var toolbarSection: some View {
        HStack {
            Spacer()
            
            Button(action: copyToClipboard) {
                Label("复制", systemImage: "doc.on.doc")
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
                    Text("已复制到剪贴板")
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
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: record.timestamp)
    }
    
    private var formattedDuration: String {
        let seconds = Int(record.duration)
        if seconds < 60 { return "\(seconds)秒" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 { return "\(minutes)分钟" }
        return "\(minutes)分\(remainingSeconds)秒"
    }
    
    private var categoryDisplayName: String {
        switch record.category {
        case "polish": return "润色"
        case "translate": return "翻译"
        case "memo": return "随心记"
        default: return "通用"
        }
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
            
            Text("选择一条记录查看详情")
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
