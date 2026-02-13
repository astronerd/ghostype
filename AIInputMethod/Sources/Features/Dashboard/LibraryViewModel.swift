//
//  LibraryViewModel.swift
//  AIInputMethod
//
//  ViewModel for the Library page, managing search and dynamic skill-based filtering.
//  Provides filtered UsageRecords based on user input.
//

import Foundation
import CoreData
import Combine

// MARK: - SkillTab

/// Represents a dynamic tab in the Library page
struct SkillTab: Identifiable, Equatable {
    let id: String          // "all" or skillId
    let displayName: String
    let icon: String        // emoji or SF Symbol name
    let colorHex: String
    let isDeleted: Bool     // true if skill no longer exists

    static let allTab = SkillTab(
        id: "all",
        displayName: L.Library.all,
        icon: "square.grid.2x2",
        colorHex: "#8E8E93",
        isDeleted: false
    )
}

// MARK: - LibraryViewModel

@Observable
class LibraryViewModel {
    
    // MARK: - Published Properties
    
    var searchText: String = ""
    var selectedTabId: String = "all"
    var selectedRecord: UsageRecord?
    
    // MARK: - Private Properties
    
    private var allRecords: [UsageRecord] = []
    private let persistenceController: PersistenceController
    private let deviceIdManager: DeviceIdManager
    
    // MARK: - Computed Properties
    
    /// Dynamic tabs derived from records' skillId/skillName + legacy category
    var availableTabs: [SkillTab] {
        var tabs: [SkillTab] = [.allTab]
        var seen = Set<String>()
        
        for record in allRecords {
            let tabId: String
            let tabName: String
            let tabIcon: String
            let tabColor: String
            let isDeleted: Bool
            
            if let skillId = record.skillId, !skillId.isEmpty {
                tabId = skillId
                // Use stored skillName, fallback to skillId
                tabName = record.skillName ?? skillId
                
                // Check if skill still exists
                if let skill = SkillManager.shared.skill(byId: skillId) {
                    tabIcon = skill.icon
                    tabColor = skill.colorHex
                    isDeleted = false
                } else {
                    // Skill was deleted
                    tabIcon = "⚠️"
                    tabColor = "#8E8E93"
                    isDeleted = true
                }
            } else {
                // Legacy record: derive from category field
                switch record.category {
                case "polish":
                    tabId = "__legacy_polish"
                    tabName = L.Library.polish
                    tabIcon = "✨"
                    tabColor = "#34C759"
                    isDeleted = false
                case "translate":
                    tabId = "__legacy_translate"
                    tabName = L.Library.translate
                    tabIcon = "🌐"
                    tabColor = "#AF52DE"
                    isDeleted = false
                case "memo":
                    tabId = "__legacy_memo"
                    tabName = L.Library.memo
                    tabIcon = "📝"
                    tabColor = "#FF9500"
                    isDeleted = false
                default:
                    tabId = "__legacy_general"
                    tabName = L.Library.categoryGeneral
                    tabIcon = "⚡"
                    tabColor = "#007AFF"
                    isDeleted = false
                }
            }
            
            guard !seen.contains(tabId) else { continue }
            seen.insert(tabId)
            tabs.append(SkillTab(id: tabId, displayName: tabName, icon: tabIcon, colorHex: tabColor, isDeleted: isDeleted))
        }
        
        return tabs
    }
    
    var filteredRecords: [UsageRecord] {
        var result = allRecords
        result = filterByTab(result)
        result = filterBySearchText(result)
        return result
    }
    
    // MARK: - Initialization
    
    init(
        persistenceController: PersistenceController = .shared,
        deviceIdManager: DeviceIdManager = .shared
    ) {
        self.persistenceController = persistenceController
        self.deviceIdManager = deviceIdManager
        loadRecords()
    }
    
    // MARK: - Public Methods
    
    func loadRecords() {
        allRecords = persistenceController.fetchUsageRecords(deviceId: deviceIdManager.deviceId)
    }
    
    func selectTab(_ tabId: String) {
        selectedTabId = tabId
    }
    
    func clearSearch() {
        searchText = ""
    }
    
    func selectRecord(_ record: UsageRecord?) {
        selectedRecord = record
    }
    
    func deleteRecord(_ record: UsageRecord) {
        let recordId = record.id
        if selectedRecord?.id == recordId {
            selectedRecord = nil
        }
        persistenceController.deleteUsageRecord(id: recordId)
        allRecords.removeAll { $0.id == recordId }
    }
    
    // MARK: - Filtering Logic
    
    func filterByTab(_ records: [UsageRecord]) -> [UsageRecord] {
        guard selectedTabId != "all" else { return records }
        
        return records.filter { record in
            if let skillId = record.skillId, !skillId.isEmpty {
                return skillId == selectedTabId
            } else {
                // Legacy records: match by derived tab id
                switch record.category {
                case "polish": return selectedTabId == "__legacy_polish"
                case "translate": return selectedTabId == "__legacy_translate"
                case "memo": return selectedTabId == "__legacy_memo"
                default: return selectedTabId == "__legacy_general"
                }
            }
        }
    }
    
    func filterBySearchText(_ records: [UsageRecord]) -> [UsageRecord] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return records }
        
        return records.filter { record in
            record.content.localizedCaseInsensitiveContains(trimmedSearch) ||
            (record.originalContent?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
        }
    }
}
