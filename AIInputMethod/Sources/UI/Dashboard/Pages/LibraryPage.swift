//
//  LibraryPage.swift
//  AIInputMethod
//
//  历史库页面 - 管理和搜索语音输入历史记录
//  实现搜索框 + 分类 Tabs + 列表 + 详情面板布局
//
//  Requirements:
//  - 6.1: THE Library page SHALL display a search field at the top for full-text search
//  - 6.2: THE Library page SHALL display filter tabs: 全部, 润色, 翻译, 随心记
//

import SwiftUI

// MARK: - LibraryPage

/// 历史库页面视图
/// 提供搜索、分类过滤和记录详情查看功能
/// - Requirement 6.1: 顶部搜索框用于全文搜索
/// - Requirement 6.2: 分类标签页：全部, 润色, 翻译, 随心记
struct LibraryPage: View {
    
    // MARK: - Properties
    
    /// LibraryViewModel 用于状态管理
    @State private var viewModel: LibraryViewModel
    
    // MARK: - Constants
    
    /// 内边距
    private let contentPadding: CGFloat = 24
    
    /// 列表和详情面板之间的间距
    private let panelSpacing: CGFloat = 16
    
    /// 列表最小宽度
    private let listMinWidth: CGFloat = 300
    
    /// 详情面板最小宽度
    private let detailMinWidth: CGFloat = 280
    
    // MARK: - Initialization
    
    init(viewModel: LibraryViewModel = LibraryViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: 顶部区域：标题 + 搜索框
            headerSection
                .padding(.horizontal, contentPadding)
                .padding(.top, contentPadding)
                .padding(.bottom, 16)
            
            // MARK: 分类标签页
            // Requirement 6.2: THE Library page SHALL display filter tabs: 全部, 润色, 翻译, 随心记
            categoryTabsSection
                .padding(.horizontal, contentPadding)
                .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, contentPadding)
            
            // MARK: 主内容区域：列表 + 详情面板
            mainContentSection
                .padding(contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - Header Section
    
    /// 头部区域：标题和搜索框
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 页面标题
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("历史库")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("搜索和管理您的语音输入记录")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 记录数量统计
                recordCountBadge
            }
            
            // MARK: 搜索框
            // Requirement 6.1: THE Library page SHALL display a search field at the top for full-text search
            searchField
        }
    }
    
    /// 记录数量徽章
    private var recordCountBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
            Text("\(viewModel.filteredRecords.count) 条记录")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    /// 搜索框
    /// Requirement 6.1: THE Library page SHALL display a search field at the top for full-text search
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            TextField("搜索记录内容...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
            
            // 清除按钮
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Category Tabs Section
    
    /// 分类标签页区域
    /// Requirement 6.2: THE Library page SHALL display filter tabs: 全部, 润色, 翻译, 随心记
    private var categoryTabsSection: some View {
        HStack(spacing: 8) {
            ForEach(RecordCategory.allCases) { category in
                CategoryTabButton(
                    category: category,
                    isSelected: viewModel.selectedCategory == category,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectCategory(category)
                        }
                    }
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - Main Content Section
    
    /// 主内容区域：列表 + 详情面板
    private var mainContentSection: some View {
        HStack(spacing: panelSpacing) {
            // MARK: 记录列表
            recordListSection
                .frame(minWidth: listMinWidth)
            
            // MARK: 详情面板
            detailPanelSection
                .frame(minWidth: detailMinWidth)
        }
    }
    
    // MARK: - Record List Section
    
    /// 记录列表区域
    private var recordListSection: some View {
        Group {
            if viewModel.filteredRecords.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredRecords, id: \.id) { record in
                            RecordListItem(
                                record: record,
                                isSelected: viewModel.selectedRecord?.id == record.id
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    viewModel.selectRecord(record)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(emptyStateTitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// 空状态图标
    private var emptyStateIcon: String {
        if !viewModel.searchText.isEmpty {
            return "magnifyingglass"
        } else if viewModel.selectedCategory != .all {
            return "folder"
        } else {
            return "doc.text"
        }
    }
    
    /// 空状态标题
    private var emptyStateTitle: String {
        if !viewModel.searchText.isEmpty {
            return "未找到匹配的记录"
        } else if viewModel.selectedCategory != .all {
            return "该分类暂无记录"
        } else {
            return "暂无记录"
        }
    }
    
    /// 空状态消息
    private var emptyStateMessage: String {
        if !viewModel.searchText.isEmpty {
            return "尝试使用其他关键词搜索"
        } else if viewModel.selectedCategory != .all {
            return "使用语音输入后，记录将显示在这里"
        } else {
            return "开始使用语音输入，\n您的记录将自动保存在这里"
        }
    }
    
    // MARK: - Detail Panel Section
    
    /// 详情面板区域
    /// Requirement 6.7: WHEN a list item is clicked, THE Library SHALL display full content in a detail panel
    private var detailPanelSection: some View {
        Group {
            if let selectedRecord = viewModel.selectedRecord {
                RecordDetailPanel(record: selectedRecord)
            } else {
                RecordDetailEmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - CategoryTabButton

/// 分类标签按钮组件
struct CategoryTabButton: View {
    
    // MARK: - Properties
    
    /// 分类
    let category: RecordCategory
    
    /// 是否选中
    let isSelected: Bool
    
    /// 点击动作
    let action: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // 分类图标
                Image(systemName: categoryIcon)
                    .font(.system(size: 12, weight: .medium))
                
                // 分类名称
                Text(category.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
    
    /// 分类图标
    private var categoryIcon: String {
        switch category {
        case .all:
            return "square.grid.2x2"
        case .polish:
            return "wand.and.stars"
        case .translate:
            return "globe"
        case .memo:
            return "note.text"
        }
    }
}

// MARK: - LibraryPageWithData

/// 带数据加载的历史库页面视图
/// 自动创建 LibraryViewModel 并加载数据
struct LibraryPageWithData: View {
    
    // MARK: - State
    
    @State private var viewModel = LibraryViewModel()
    
    // MARK: - Body
    
    var body: some View {
        LibraryPage(viewModel: viewModel)
            .onAppear {
                viewModel.loadRecords()
            }
    }
}

// MARK: - Preview

#if DEBUG
struct LibraryPage_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 默认状态预览
            LibraryPage()
                .frame(width: 800, height: 600)
                .previewDisplayName("Default State")
            
            // 深色模式预览
            LibraryPage()
                .frame(width: 800, height: 600)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
