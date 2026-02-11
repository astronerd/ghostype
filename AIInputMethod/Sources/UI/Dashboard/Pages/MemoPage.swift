//
//  MemoPage.swift
//  AIInputMethod
//
//  随心记页面 - Radical Minimalist 极简风格
//

import SwiftUI

// MARK: - MemoPage

struct MemoPage: View {
    
    @State private var memos: [UsageRecord] = []
    @State private var searchText: String = ""
    @State private var selectedMemo: UsageRecord?
    @State private var isLoading = false
    @State private var currentPage: Int = 0
    @State private var hasMoreData: Bool = true
    
    private let pageSize: Int = 20
    private let persistenceController: PersistenceController
    private let deviceIdManager: DeviceIdManager
    
    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg),
        GridItem(.flexible(), spacing: DS.Spacing.lg)
    ]
    
    init(
        persistenceController: PersistenceController = .shared,
        deviceIdManager: DeviceIdManager = .shared
    ) {
        self.persistenceController = persistenceController
        self.deviceIdManager = deviceIdManager
    }
    
    var filteredMemos: [UsageRecord] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty { return memos }
        return memos.filter { $0.content.localizedCaseInsensitiveContains(trimmedSearch) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            memoHeader
            MinimalDivider()
                .padding(.horizontal, DS.Spacing.xl)
            
            if filteredMemos.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                        ForEach(filteredMemos, id: \.objectID) { memo in
                            MemoCard(
                                memo: memo,
                                isSelected: false,
                                onDelete: { deleteMemo(memo) }
                            )
                            .onAppear {
                                if memo.objectID == filteredMemos.last?.objectID && hasMoreData && !isLoading {
                                    loadMemos()
                                }
                            }
                        }
                    }
                    .padding(DS.Spacing.xl)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView().scaleEffect(0.7)
                            Text(L.Common.loading)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.lg)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
        .onAppear { loadMemos(reset: true) }
    }

    private var memoHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L.Memo.title)
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text1)
                
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                    Text("\(memos.count) \(L.Memo.noteCount)")
                        .font(DS.Typography.caption)
                }
                .foregroundColor(DS.Colors.text2)
            }
            
            Spacer()
            
            // 搜索框
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.icon)
                
                TextField(L.Memo.search, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.body)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
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
            .frame(width: 200)
        }
        .padding(.top, 21)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xl)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.text3)
            
            Text(searchText.isEmpty ? L.Memo.empty : L.Memo.noMatch)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text2)
            
            Text(searchText.isEmpty ? L.Memo.emptyHint : L.Memo.searchHint)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadMemos(reset: Bool = false) {
        if reset {
            currentPage = 0
            memos = []
            hasMoreData = true
        }
        guard hasMoreData && !isLoading else { return }
        isLoading = true
        
        let allRecords = persistenceController.fetchUsageRecords(deviceId: deviceIdManager.deviceId)
        let memoRecords = allRecords.filter { $0.category == "memo" }.sorted { $0.timestamp > $1.timestamp }
        
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, memoRecords.count)
        
        if startIndex < memoRecords.count {
            let newMemos = Array(memoRecords[startIndex..<endIndex])
            memos.append(contentsOf: newMemos)
            currentPage += 1
            hasMoreData = endIndex < memoRecords.count
        } else {
            hasMoreData = false
        }
        isLoading = false
    }
    
    private func reloadMemos() { loadMemos(reset: true) }
    
    private func updateMemo(_ memo: UsageRecord, content: String) {
        persistenceController.updateUsageRecord(id: memo.id, content: content)
        reloadMemos()
    }
    
    private func deleteMemo(_ memo: UsageRecord) {
        let memoObjectID = memo.objectID
        persistenceController.deleteUsageRecord(id: memo.id)
        memos.removeAll { $0.objectID == memoObjectID }
    }
}

// MARK: - MemoCard (极简风格)

struct MemoCard: View {
    let memo: UsageRecord
    let isSelected: Bool
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // 内容
            Text(memo.content)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text1)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: DS.Spacing.sm)
            
            // 底部：时间 + 操作按钮
            HStack {
                Text(formatDate(memo.timestamp))
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
                
                Spacer()
                
                // 操作按钮组 - 只有图标
                HStack(spacing: DS.Spacing.xs) {
                    // 复制按钮
                    Button(action: {
                        copyToClipboard(memo.content)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    }) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colors.text2)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // 删除按钮
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colors.text2)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                    .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .opacity(isHovered ? 1 : 0.5)
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                .stroke(isSelected ? DS.Colors.text1 : DS.Colors.border, lineWidth: DS.Layout.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Layout.cornerRadius))
        .onHover { hovering in isHovered = hovering }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - MemoDetailSheet (极简风格)

struct MemoDetailSheet: View {
    let memo: UsageRecord
    let onSave: (String) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    @State private var editedContent: String
    @State private var showDeleteConfirmation = false
    
    init(memo: UsageRecord, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.memo = memo
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        self._editedContent = State(initialValue: memo.content)
    }
    
    private var isEmpty: Bool { editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(L.Common.cancel) { onCancel() }
                    .buttonStyle(.plain)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text2)
                
                Spacer()
                
                Text(L.Memo.editNote)
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text1)
                
                Spacer()
                
                Button(L.Common.save) { onSave(editedContent) }
                    .buttonStyle(.plain)
                    .font(DS.Typography.body)
                    .foregroundColor(isEmpty ? DS.Colors.text3 : DS.Colors.text1)
                    .disabled(isEmpty)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)
            
            MinimalDivider()
            
            // Content
            TextEditor(text: $editedContent)
                .font(DS.Typography.body)
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            MinimalDivider()
            
            // Footer
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Memo.createdAt)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                    Text(formatDate(memo.timestamp))
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                }
                
                Spacer()
                
                Text("\(editedContent.count) \(L.Memo.charCount)")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text2)
                    .padding(.trailing, DS.Spacing.lg)
                
                Button(role: .destructive) { showDeleteConfirmation = true } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text(L.Common.delete)
                            .font(DS.Typography.caption)
                    }
                    .foregroundColor(DS.Colors.statusError)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
        }
        .frame(width: 450, height: 350)
        .background(DS.Colors.bg1)
        .alert(L.Memo.confirmDelete, isPresented: $showDeleteConfirmation) {
            Button(L.Common.cancel, role: .cancel) { }
            Button(L.Common.delete, role: .destructive) { onDelete() }
        } message: {
            Text(L.Memo.confirmDeleteMsg)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if LocalizationManager.shared.currentLanguage == .chinese {
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        } else {
            formatter.dateFormat = "MMM d, yyyy HH:mm"
        }
        return formatter.string(from: date)
    }
}

// MARK: - MemoPageWithData

struct MemoPageWithData: View {
    var body: some View { MemoPage() }
}
