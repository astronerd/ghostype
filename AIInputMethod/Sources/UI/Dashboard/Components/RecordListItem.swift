//
//  RecordListItem.swift
//  AIInputMethod
//
//  历史库列表项组件 - Radical Minimalist 极简风格
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - RecordListItem

struct RecordListItem: View {
    
    let record: UsageRecord
    var isSelected: Bool = false
    
    @State private var isHovered: Bool = false
    
    private let maxPreviewLength: Int = 100
    private let iconSize: CGFloat = 28
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            appIconView
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                contentPreviewView
                timestampView
            }
            
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(backgroundColor)
        .cornerRadius(DS.Layout.cornerRadius)
        .onHover { hovering in isHovered = hovering }
        .onDrag { createDragItemProvider() }
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
                .font(.system(size: iconSize * 0.5))
                .foregroundColor(DS.Colors.icon)
                .frame(width: iconSize, height: iconSize)
                .background(DS.Colors.bg2)
                .cornerRadius(DS.Layout.cornerRadius)
        }
    }
    
    private var contentPreviewView: some View {
        Text(truncatedContent)
            .font(DS.Typography.body)
            .foregroundColor(DS.Colors.text1)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    private var timestampView: some View {
        Text(formattedTimestamp)
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.text2)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return DS.Colors.highlight
        } else if isHovered {
            return DS.Colors.highlight.opacity(0.5)
        }
        return Color.clear
    }
    
    var truncatedContent: String {
        RecordListItem.truncateContent(record.content, maxLength: maxPreviewLength)
    }
    
    private var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: record.timestamp, relativeTo: Date())
    }
    
    private func getAppIcon(bundleId: String) -> NSImage? {
        guard !bundleId.isEmpty else { return nil }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
    
    private func createDragItemProvider() -> NSItemProvider {
        let content = record.content
        let fileName = generateExportFileName()
        
        let itemProvider = NSItemProvider()
        
        itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
            let data = content.data(using: .utf8) ?? Data()
            completion(data, nil)
            return nil
        }
        
        itemProvider.registerFileRepresentation(forTypeIdentifier: UTType.plainText.identifier, fileOptions: [], visibility: .all) { completion in
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                completion(fileURL, true, nil)
            } catch {
                completion(nil, false, error)
            }
            return nil
        }
        
        itemProvider.suggestedName = fileName
        return itemProvider
    }
    
    private func generateExportFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: record.timestamp)
        return "GHOSTYPE_记录_\(dateString).txt"
    }
    
    static func truncateContent(_ content: String, maxLength: Int = 100) -> String {
        let cleanedContent = content
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanedContent.count > maxLength else { return cleanedContent }
        return String(cleanedContent.prefix(maxLength)) + "…"
    }
}

// MARK: - Preview

#if DEBUG
struct RecordListItem_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let record = UsageRecord(context: context)
        record.id = UUID()
        record.content = "这是一条测试记录"
        record.category = "memo"
        record.sourceApp = "Notes"
        record.sourceAppBundleId = "com.apple.Notes"
        record.timestamp = Date()
        record.duration = 30
        record.deviceId = "test"
        
        return RecordListItem(record: record, isSelected: false)
            .frame(width: 300)
            .padding()
    }
}
#endif
