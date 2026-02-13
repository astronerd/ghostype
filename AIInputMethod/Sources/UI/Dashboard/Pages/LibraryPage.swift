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
                    Text(L.Library.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text1)
                    
                    Text(L.Library.subtitle)
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
            Text(String(format: L.Library.recordCount, viewModel.filteredRecords.count))
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
            
            TextField(L.Library.searchPlaceholder, text: $viewModel.searchText)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(viewModel.availableTabs) { tab in
                    SkillTabButton(
                        tab: tab,
                        isSelected: viewModel.selectedTabId == tab.id,
                        action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.selectTab(tab.id)
                            }
                        }
                    )
                }
                Spacer()
            }
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
        else if viewModel.selectedTabId != "all" { return "folder" }
        else { return "doc.text" }
    }
    
    private var emptyStateTitle: String {
        if !viewModel.searchText.isEmpty { return L.Library.emptySearchTitle }
        else if viewModel.selectedTabId != "all" { return L.Library.emptyCategoryTitle }
        else { return L.Library.emptyTitle }
    }
    
    private var emptyStateMessage: String {
        if !viewModel.searchText.isEmpty { return L.Library.emptySearchMsg }
        else if viewModel.selectedTabId != "all" { return L.Library.emptyCategoryMsg }
        else { return L.Library.emptyMsg }
    }
    
    private var detailPanelSection: some View {
        Group {
            if let selectedRecord = viewModel.selectedRecord {
                RecordDetailPanel(
                    record: selectedRecord,
                    onDelete: { viewModel.deleteRecord(selectedRecord) }
                )
            } else {
                RecordDetailEmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
    }
}

// MARK: - SkillTabButton

struct SkillTabButton: View {
    let tab: SkillTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if tab.id == "all" {
                    Image(systemName: tab.icon)
                        .font(.system(size: 11))
                } else {
                    Text(tab.icon)
                        .font(.system(size: 11))
                }
                
                Text(tab.displayName)
                    .font(DS.Typography.body)
                
                if tab.isDeleted {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(DS.Colors.statusWarning)
                }
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
