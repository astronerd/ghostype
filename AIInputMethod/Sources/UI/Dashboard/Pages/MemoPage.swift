//
//  MemoPage.swift
//  AIInputMethod
//
//  随心记页面 - Flomo 风格瀑布流卡片布局
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
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private let contentPadding: CGFloat = 24
    
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
            Divider().padding(.horizontal, contentPadding)
            
            if filteredMemos.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredMemos, id: \.objectID) { memo in
                            MemoCard(
                                memo: memo,
                                isSelected: selectedMemo?.objectID == memo.objectID,
                                onDelete: { deleteMemo(memo) }
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMemo = memo
                                }
                            }
                            .onAppear {
                                if memo.objectID == filteredMemos.last?.objectID && hasMoreData && !isLoading {
                                    loadMemos()
                                }
                            }
                        }
                    }
                    .padding(contentPadding)
                    
                    if hasMoreData && !isLoading {
                        Color.clear.frame(height: 1).onAppear { loadMemos() }
                    }
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView().scaleEffect(0.8)
                            Text("加载中...").font(.system(size: 12)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))
        .onAppear { loadMemos(reset: true) }
        .sheet(item: $selectedMemo) { memo in
            MemoDetailSheet(
                memo: memo,
                onSave: { updatedContent in
                    updateMemo(memo, content: updatedContent)
                    selectedMemo = nil
                },
                onCancel: { selectedMemo = nil },
                onDelete: {
                    deleteMemo(memo)
                    selectedMemo = nil
                }
            )
        }
    }
    
    private var memoHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("随心记")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "note.text").font(.system(size: 14))
                    Text("\(memos.count) 条笔记").font(.system(size: 14))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                TextField("搜索笔记...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .frame(width: 200)
        }
        .padding(contentPadding)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
            Text(searchText.isEmpty ? "暂无笔记" : "未找到匹配的笔记")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "按住快捷键 + Command 键说话\n即可创建语音便签" : "尝试使用其他关键词搜索")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
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

// MARK: - MemoDetailSheet

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
                Button("取消") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                Spacer()
                Text("编辑便签").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("保存") { onSave(editedContent) }
                    .buttonStyle(.plain)
                    .foregroundColor(isEmpty ? .secondary : .accentColor)
                    .disabled(isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider()
            
            // Content
            TextEditor(text: $editedContent)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Footer
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("创建于").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(formatDate(memo.timestamp)).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(editedContent.count) 字")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 16)
                Button(role: .destructive) { showDeleteConfirmation = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 12))
                        Text("删除").font(.system(size: 13))
                    }
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 450, height: 350)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) { onDelete() }
        } message: {
            Text("删除后无法恢复，确定要删除这条笔记吗？")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - MemoCard

struct MemoCard: View {
    let memo: UsageRecord
    let isSelected: Bool
    let onDelete: () -> Void
    
    private static let cardColors: [Color] = [
        Color(red: 1.0, green: 0.976, blue: 0.769),
        Color(red: 1.0, green: 0.925, blue: 0.702),
        Color(red: 1.0, green: 0.878, blue: 0.698),
        Color(red: 0.973, green: 0.733, blue: 0.851),
        Color(red: 0.882, green: 0.745, blue: 0.906),
        Color(red: 0.784, green: 0.902, blue: 0.788),
        Color(red: 0.702, green: 0.898, blue: 0.988),
    ]
    
    private var cardColor: Color {
        let index = abs(memo.id.hashValue) % Self.cardColors.count
        return Self.cardColors[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(memo.content)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.85))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 8)
            
            HStack {
                Text(formatDate(memo.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.5))
                Spacer()
                Menu {
                    Button(action: { copyToClipboard(memo.content) }) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.4))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(16)
        .background(cardColor)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
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

// MARK: - MemoPageWithData

struct MemoPageWithData: View {
    var body: some View { MemoPage() }
}
