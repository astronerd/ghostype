//
//  RecordListItem.swift
//  AIInputMethod
//
//  历史库列表项组件
//  显示应用图标、内容预览 (2行截断)、时间戳
//
//  Requirements:
//  - 6.5: THE Library list item SHALL display: source app icon, content preview (truncated to 2 lines), timestamp
//  - 6.6: WHEN a list item is dragged outside the window, THE Dashboard SHALL export the content as .txt file
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - RecordListItem

/// 历史库列表项组件
/// 显示单条 UsageRecord 的预览信息
/// - Requirement 6.5: 显示应用图标、内容预览 (2行截断)、时间戳
struct RecordListItem: View {
    
    // MARK: - Properties
    
    /// 要显示的使用记录
    let record: UsageRecord
    
    /// 是否被选中
    var isSelected: Bool = false
    
    // MARK: - State
    
    /// 悬停状态
    @State private var isHovered: Bool = false
    
    // MARK: - Constants
    
    /// 内容预览最大字符数（约2行）
    private let maxPreviewLength: Int = 100
    
    /// 圆角半径
    private let cornerRadius: CGFloat = 8
    
    /// 图标尺寸
    private let iconSize: CGFloat = 32
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // MARK: 应用图标
            appIconView
            
            // MARK: 内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 内容预览 (2行截断)
                contentPreviewView
                
                // 时间戳
                timestampView
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onHover { hovering in
            isHovered = hovering
        }
        // MARK: 拖拽导出功能
        // **Property 13: Export File Content**
        // *For any* UsageRecord, exporting to .txt file shall create a file containing exactly the record's content string.
        // **Validates: Requirements 6.6**
        .onDrag {
            createDragItemProvider()
        }
    }
    
    // MARK: - App Icon View
    
    /// 应用图标视图
    /// 使用 NSWorkspace 从 bundle ID 获取应用图标
    private var appIconView: some View {
        Group {
            if let icon = getAppIcon(bundleId: record.sourceAppBundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // 默认图标（当无法获取应用图标时）
                Image(systemName: "app.fill")
                    .font(.system(size: iconSize * 0.6))
                    .foregroundColor(.secondary)
                    .frame(width: iconSize, height: iconSize)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            }
        }
        .frame(width: iconSize, height: iconSize)
    }
    
    // MARK: - Content Preview View
    
    /// 内容预览视图
    /// **Property 12: Content Preview Truncation**
    /// *For any* UsageRecord content, the preview shall be truncated to at most 2 lines
    /// (approximately 100 characters) with ellipsis if original content is longer.
    /// **Validates: Requirements 6.5**
    private var contentPreviewView: some View {
        Text(truncatedContent)
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    // MARK: - Timestamp View
    
    /// 时间戳视图
    /// 使用 RelativeDateTimeFormatter 显示相对时间
    private var timestampView: some View {
        Text(formattedTimestamp)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }
    
    // MARK: - Background View
    
    /// 背景视图
    /// 根据选中和悬停状态显示不同背景
    private var backgroundView: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.accentColor.opacity(0.15))
            } else if isHovered {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            } else {
                Color.clear
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// 截断后的内容预览
    /// 如果内容超过 maxPreviewLength 字符，则截断并添加省略号
    var truncatedContent: String {
        RecordListItem.truncateContent(record.content, maxLength: maxPreviewLength)
    }
    
    /// 格式化的时间戳
    /// 使用相对时间格式（如"5分钟前"、"昨天"）
    private var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: record.timestamp, relativeTo: Date())
    }
    
    // MARK: - Helper Methods
    
    /// 获取应用图标
    /// - Parameter bundleId: 应用的 bundle identifier
    /// - Returns: 应用图标，如果无法获取则返回 nil
    private func getAppIcon(bundleId: String) -> NSImage? {
        guard !bundleId.isEmpty else { return nil }
        
        // 尝试通过 bundle ID 获取应用路径
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        
        return nil
    }
    
    // MARK: - Drag Export Methods
    
    /// 创建拖拽导出的 NSItemProvider
    /// **Property 13: Export File Content**
    /// *For any* UsageRecord, exporting to .txt file shall create a file containing exactly the record's content string.
    /// **Validates: Requirements 6.6**
    /// - Returns: 包含记录内容的 NSItemProvider
    private func createDragItemProvider() -> NSItemProvider {
        let content = record.content
        let fileName = generateExportFileName()
        
        // 创建 NSItemProvider，使用 plainText 类型
        let itemProvider = NSItemProvider()
        
        // 注册为纯文本类型
        itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
            let data = content.data(using: .utf8) ?? Data()
            completion(data, nil)
            return nil
        }
        
        // 注册为文件类型，支持拖拽到 Finder 等应用
        itemProvider.registerFileRepresentation(forTypeIdentifier: UTType.plainText.identifier, fileOptions: [], visibility: .all) { completion in
            // 创建临时文件
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
        
        // 设置建议的文件名
        itemProvider.suggestedName = fileName
        
        return itemProvider
    }
    
    /// 生成导出文件名
    /// 格式: "GhosTYPE_记录_YYYYMMDD_HHmmss.txt"
    /// - Returns: 文件名字符串
    private func generateExportFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: record.timestamp)
        return "GhosTYPE_记录_\(dateString).txt"
    }
    
    // MARK: - Static Methods (for Testing)
    
    /// 截断内容到指定长度
    /// - Parameters:
    ///   - content: 原始内容
    ///   - maxLength: 最大长度
    /// - Returns: 截断后的内容，如果超过最大长度则添加省略号
    ///
    /// **Property 12: Content Preview Truncation**
    /// *For any* UsageRecord content, the preview shall be truncated to at most 2 lines
    /// (approximately 100 characters) with ellipsis if original content is longer.
    /// **Validates: Requirements 6.5**
    static func truncateContent(_ content: String, maxLength: Int = 100) -> String {
        // 移除多余的空白字符和换行
        let cleanedContent = content
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果内容长度在限制内，直接返回
        guard cleanedContent.count > maxLength else {
            return cleanedContent
        }
        
        // 截断并添加省略号
        let truncated = String(cleanedContent.prefix(maxLength))
        return truncated + "…"
    }
}

// MARK: - Preview

#if DEBUG
struct RecordListItem_Previews: PreviewProvider {
    static var previews: some View {
        // 创建模拟数据用于预览
        let context = PersistenceController.preview.container.viewContext
        
        // 创建测试记录
        let record1 = UsageRecord(context: context)
        record1.id = UUID()
        record1.content = "这是一条测试记录，用于展示内容预览的截断效果。当内容超过两行时，应该显示省略号。"
        record1.category = "memo"
        record1.sourceApp = "Notes"
        record1.sourceAppBundleId = "com.apple.Notes"
        record1.timestamp = Date()
        record1.duration = 30
        record1.deviceId = "test-device"
        
        let record2 = UsageRecord(context: context)
        record2.id = UUID()
        record2.content = "短内容"
        record2.category = "polish"
        record2.sourceApp = "Safari"
        record2.sourceAppBundleId = "com.apple.Safari"
        record2.timestamp = Date().addingTimeInterval(-3600) // 1小时前
        record2.duration = 15
        record2.deviceId = "test-device"
        
        let record3 = UsageRecord(context: context)
        record3.id = UUID()
        record3.content = "这是一条非常长的测试记录，用于展示内容预览的截断效果。当内容超过两行时，应该显示省略号。这段文字会被截断，因为它超过了100个字符的限制。我们需要确保截断逻辑正确工作。"
        record3.category = "translate"
        record3.sourceApp = "Unknown App"
        record3.sourceAppBundleId = "com.unknown.app"
        record3.timestamp = Date().addingTimeInterval(-86400) // 1天前
        record3.duration = 60
        record3.deviceId = "test-device"
        
        return VStack(spacing: 8) {
            RecordListItem(record: record1, isSelected: false)
            RecordListItem(record: record2, isSelected: true)
            RecordListItem(record: record3, isSelected: false)
        }
        .padding()
        .frame(width: 400)
        .previewDisplayName("Record List Items")
    }
}
#endif
