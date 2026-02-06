//
//  LibraryPage.swift
//  AIInputMethod
//
//  历史库页面 - Radical Minimalist 极简风格
//

import SwiftUI

// MARK: - LibraryPage

struct LibraryPage: View {
    
    @State private var viewModel: LibraryViewModel
    
    private let contentPadding: CGFloat = DS.Spacing.xl
    private let panelSpacing: CGFloat = DS.Spacing.lg
    
    init(viewModel: LibraryViewModel = LibraryViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, contentPadding)
                .padding(.top, 21)
                .padding(.bottom, DS.Spacing.lg)
            
            categoryTabsSection
                .padding(.horizontal, contentPadding)
                .padding(.bottom, DS.Spacing.lg)
            
            MinimalDivider()
                .padding(.horizontal, contentPadding)
            
            mainContentSection
                .padding(contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
    }

    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("历史库")
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text1)
                    
                    Text("搜索和管理您的语音输入记录")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                recordCountBadge
            }
            
            searchField
        }
    }
    
    private var recordCountBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
            Text("\(viewModel.filteredRecords.count) 条记录")
                .font(DS.Typography.caption)
        }
        .foregroundColor(DS.Colors.text2)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.bg2)
        .overlay(
            Capsule()
                .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
        )
        .clipShape(Capsule())
    }
    
    private var searchField: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.icon)
            
            TextField("搜索记录内容...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(DS.Typography.body)
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(DS.Colors.icon)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
    }

    // MARK: - Category Tabs Section
    
    private var categoryTabsSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(RecordCategory.allCases) { category in
                CategoryTabButton(
                    category: category,
                    isSelected: viewModel.selectedCategory == category,
                    action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectCategory(category)
                        }
                    }
                )
            }
            Spacer()
        }
    }
    
    // MARK: - Main Content Section
    
    private var mainContentSection: some View {
        HStack(spacing: panelSpacing) {
            recordListSection
                .frame(minWidth: 300)
            
            detailPanelSection
                .frame(minWidth: 280)
        }
    }
    
    private var recordListSection: some View {
        Group {
            if viewModel.filteredRecords.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
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
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
        .background(DS.Colors.bg2.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 36))
                .foregroundColor(DS.Colors.text3)
            
            Text(emptyStateTitle)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
            
            Text(emptyStateMessage)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateIcon: String {
        if !viewModel.searchText.isEmpty { return "magnifyingglass" }
        else if viewModel.selectedCategory != .all { return "folder" }
        else { return "doc.text" }
    }
    
    private var emptyStateTitle: String {
        if !viewModel.searchText.isEmpty { return "未找到匹配的记录" }
        else if viewModel.selectedCategory != .all { return "该分类暂无记录" }
        else { return "暂无记录" }
    }
    
    private var emptyStateMessage: String {
        if !viewModel.searchText.isEmpty { return "尝试使用其他关键词搜索" }
        else if viewModel.selectedCategory != .all { return "使用语音输入后，记录将显示在这里" }
        else { return "开始使用语音输入，\n您的记录将自动保存在这里" }
    }
    
    private var detailPanelSection: some View {
        Group {
            if let selectedRecord = viewModel.selectedRecord {
                RecordDetailPanel(record: selectedRecord)
            } else {
                RecordDetailEmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
    }
}

// MARK: - CategoryTabButton

struct CategoryTabButton: View {
    let category: RecordCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 11))
                
                Text(category.displayName)
                    .font(DS.Typography.body)
            }
            .foregroundColor(isSelected ? DS.Colors.text1 : DS.Colors.text2)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.highlight : Color.clear)
            .overlay(
                Capsule()
                    .stroke(isSelected ? DS.Colors.border : Color.clear, lineWidth: DS.Layout.borderWidth)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var categoryIcon: String {
        switch category {
        case .all: return "square.grid.2x2"
        case .polish: return "wand.and.stars"
        case .translate: return "globe"
        case .memo: return "note.text"
        }
    }
}

// MARK: - LibraryPageWithData

struct LibraryPageWithData: View {
    @State private var viewModel = LibraryViewModel()
    
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
        LibraryPage()
            .frame(width: 800, height: 600)
    }
}
#endif
