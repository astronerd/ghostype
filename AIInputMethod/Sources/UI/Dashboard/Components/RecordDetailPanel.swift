//
//  RecordDetailPanel.swift
//  AIInputMethod
//
//  详情面板组件
//  显示 UsageRecord 的完整内容和元数据
//
//  Requirements:
//  - 6.7: WHEN a list item is clicked, THE Library SHALL display full content in a detail panel
//

import SwiftUI
import AppKit

// MARK: - RecordDetailPanel

/// 记录详情面板组件
/// 显示选中 UsageRecord 的完整内容和元数据
/// - Requirement 6.7: 点击列表项时显示完整内容
struct RecordDetailPanel: View {
    
    // MARK: - Properties
    
    /// 要显示的使用记录
    let record: UsageRecord
    
    // MARK: - State
    
    /// 复制成功提示状态
    @State private var showCopiedToast: Bool = false
    
    // MARK: - Constants
    
    /// 圆角半径
    private let cornerRadius: CGFloat = 12
    
    /// 图标尺寸
    private let iconSize: CGFloat = 40
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: 头部区域（元数据）
            headerSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // MARK: 内容区域（完整内容）
            contentSection
            
            // MARK: 底部工具栏
            toolbarSection
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            // 复制成功提示
            copiedToastOverlay
        )
    }
    
    // MARK: - Header Section
    
    /// 头部区域：显示应用图标、应用名称、分类、时间戳、时长
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // 应用图标
            appIconView
            
            // 元数据信息
            VStack(alignment: .leading, spacing: 4) {
                // 应用名称
                Text(record.sourceApp.isEmpty ? "未知应用" : record.sourceApp)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                // 分类标签
                categoryBadge
                
                // 时间戳和时长
                HStack(spacing: 8) {
                    // 时间戳
                    Label(formattedTimestamp, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    // 时长
                    if record.duration > 0 {
                        Label(formattedDuration, systemImage: "waveform")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    // MARK: - App Icon View
    
    /// 应用图标视图
    private var appIconView: some View {
        Group {
            if let icon = getAppIcon(bundleId: record.sourceAppBundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // 默认图标
                Image(systemName: "app.fill")
                    .font(.system(size: iconSize * 0.5))
                    .foregroundColor(.secondary)
                    .frame(width: iconSize, height: iconSize)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            }
        }
        .frame(width: iconSize, height: iconSize)
    }
    
    // MARK: - Category Badge
    
    /// 分类标签
    private var categoryBadge: some View {
        Text(categoryDisplayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(categoryColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(categoryColor.opacity(0.15))
            )
    }
    
    // MARK: - Content Section
    
    /// 内容区域：使用 ScrollView 显示完整内容
    private var contentSection: some View {
        ScrollView {
            Text(record.content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Section
    
    /// 底部工具栏
    private var toolbarSection: some View {
        HStack(spacing: 12) {
            Spacer()
            
            // 复制按钮
            Button(action: copyToClipboard) {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.5)
        )
    }
    
    // MARK: - Copied Toast Overlay
    
    /// 复制成功提示覆盖层
    private var copiedToastOverlay: some View {
        Group {
            if showCopiedToast {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已复制到剪贴板")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    )
                    .padding(.bottom, 60)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
    }
    
    // MARK: - Background
    
    /// 面板背景
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    /// 格式化的时间戳
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: record.timestamp)
    }
    
    /// 格式化的时长
    private var formattedDuration: String {
        let seconds = Int(record.duration)
        if seconds < 60 {
            return "\(seconds)秒"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)分钟"
            } else {
                return "\(minutes)分\(remainingSeconds)秒"
            }
        }
    }
    
    /// 分类显示名称
    private var categoryDisplayName: String {
        switch record.category {
        case "polish":
            return "润色"
        case "translate":
            return "翻译"
        case "memo":
            return "随心记"
        default:
            return "通用"
        }
    }
    
    /// 分类颜色
    private var categoryColor: Color {
        switch record.category {
        case "polish":
            return .blue
        case "translate":
            return .purple
        case "memo":
            return .orange
        default:
            return .gray
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取应用图标
    /// - Parameter bundleId: 应用的 bundle identifier
    /// - Returns: 应用图标，如果无法获取则返回 nil
    private func getAppIcon(bundleId: String) -> NSImage? {
        guard !bundleId.isEmpty else { return nil }
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        
        return nil
    }
    
    /// 复制内容到剪贴板
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.content, forType: .string)
        
        // 显示复制成功提示
        showCopiedToast = true
        
        // 2秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }
}

// MARK: - Empty State View

/// 空状态视图
/// 当没有选中记录时显示
struct RecordDetailEmptyView: View {
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("选择一条记录查看详情")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
}

// MARK: - Preview

#if DEBUG
struct RecordDetailPanel_Previews: PreviewProvider {
    static var previews: some View {
        // 创建模拟数据用于预览
        let context = PersistenceController.preview.container.viewContext
        
        // 创建测试记录 - 短内容
        let shortRecord = UsageRecord(context: context)
        shortRecord.id = UUID()
        shortRecord.content = "这是一条简短的测试记录。"
        shortRecord.category = "memo"
        shortRecord.sourceApp = "Notes"
        shortRecord.sourceAppBundleId = "com.apple.Notes"
        shortRecord.timestamp = Date()
        shortRecord.duration = 15
        shortRecord.deviceId = "test-device"
        
        // 创建测试记录 - 长内容
        let longRecord = UsageRecord(context: context)
        longRecord.id = UUID()
        longRecord.content = """
        这是一条非常长的测试记录，用于展示详情面板的滚动功能。
        
        当内容超过面板高度时，用户应该能够滚动查看完整内容。这是 GhosTYPE 语音输入工具的核心功能之一。
        
        主要特点：
        1. 支持语音转文字
        2. 智能润色功能
        3. 多语言翻译
        4. 随心记录笔记
        
        这段文字会继续延长，以确保我们能够测试滚动功能是否正常工作。用户体验是我们最关注的方面，因此我们需要确保所有功能都能流畅运行。
        
        感谢您使用 GhosTYPE！
        """
        longRecord.category = "polish"
        longRecord.sourceApp = "Safari"
        longRecord.sourceAppBundleId = "com.apple.Safari"
        longRecord.timestamp = Date().addingTimeInterval(-3600)
        longRecord.duration = 120
        longRecord.deviceId = "test-device"
        
        // 创建测试记录 - 翻译类型
        let translateRecord = UsageRecord(context: context)
        translateRecord.id = UUID()
        translateRecord.content = "Hello, this is a translation test. 你好，这是一个翻译测试。"
        translateRecord.category = "translate"
        translateRecord.sourceApp = "Unknown App"
        translateRecord.sourceAppBundleId = ""
        translateRecord.timestamp = Date().addingTimeInterval(-86400)
        translateRecord.duration = 30
        translateRecord.deviceId = "test-device"
        
        return Group {
            // 短内容预览
            RecordDetailPanel(record: shortRecord)
                .frame(width: 350, height: 400)
                .padding()
                .previewDisplayName("Short Content")
            
            // 长内容预览
            RecordDetailPanel(record: longRecord)
                .frame(width: 350, height: 400)
                .padding()
                .previewDisplayName("Long Content")
            
            // 翻译类型预览
            RecordDetailPanel(record: translateRecord)
                .frame(width: 350, height: 400)
                .padding()
                .previewDisplayName("Translate Category")
            
            // 空状态预览
            RecordDetailEmptyView()
                .frame(width: 350, height: 400)
                .padding()
                .previewDisplayName("Empty State")
            
            // 深色模式预览
            RecordDetailPanel(record: shortRecord)
                .frame(width: 350, height: 400)
                .padding()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
