//
//  LibraryViewModel.swift
//  AIInputMethod
//
//  ViewModel for the Library page, managing search and category filtering.
//  Provides filtered UsageRecords based on user input.
//
//  Requirements:
//  - 6.3: WHEN a filter tab is selected, THE Library SHALL display only Usage_Records matching that category
//  - 6.4: WHEN search text is entered, THE Library SHALL filter Usage_Records containing the search text
//

import Foundation
import CoreData
import Combine

/// LibraryViewModel manages the state and filtering logic for the Library page.
/// Uses @Observable for reactive state management (macOS 14+).
@Observable
class LibraryViewModel {
    
    // MARK: - Published Properties
    
    /// Search text entered by the user for full-text search
    var searchText: String = ""
    
    /// Currently selected category filter (nil means "all")
    var selectedCategory: RecordCategory? = .all
    
    /// Currently selected record for detail view
    var selectedRecord: UsageRecord?
    
    // MARK: - Private Properties
    
    /// All records loaded from CoreData
    private var allRecords: [UsageRecord] = []
    
    /// PersistenceController for data access
    private let persistenceController: PersistenceController
    
    /// DeviceIdManager for getting current device ID
    private let deviceIdManager: DeviceIdManager
    
    // MARK: - Computed Properties
    
    /// Filtered records based on category and search text
    /// Combines both filters: category filter AND search filter
    var filteredRecords: [UsageRecord] {
        var result = allRecords
        
        // Apply category filter (except for "all" which shows everything)
        result = filterByCategory(result)
        
        // Apply search filter
        result = filterBySearchText(result)
        
        return result
    }
    
    // MARK: - Initialization
    
    /// Initialize the LibraryViewModel
    /// - Parameters:
    ///   - persistenceController: PersistenceController for data access, defaults to shared instance
    ///   - deviceIdManager: DeviceIdManager for device ID, defaults to shared instance
    init(
        persistenceController: PersistenceController = .shared,
        deviceIdManager: DeviceIdManager = .shared
    ) {
        self.persistenceController = persistenceController
        self.deviceIdManager = deviceIdManager
        loadRecords()
    }
    
    // MARK: - Public Methods
    
    /// Reload records from CoreData
    func loadRecords() {
        allRecords = persistenceController.fetchUsageRecords(deviceId: deviceIdManager.deviceId)
    }
    
    /// Select a category filter
    /// - Parameter category: The category to filter by, or .all to show all records
    func selectCategory(_ category: RecordCategory) {
        selectedCategory = category
    }
    
    /// Clear the search text
    func clearSearch() {
        searchText = ""
    }
    
    /// Select a record for detail view
    /// - Parameter record: The record to select
    func selectRecord(_ record: UsageRecord?) {
        selectedRecord = record
    }
    
    // MARK: - Filtering Logic
    
    /// Filter records by category
    /// - Parameter records: The records to filter
    /// - Returns: Filtered records matching the selected category
    ///
    /// **Property 10: Category Filter Correctness**
    /// *For any* RecordCategory filter (except .all) and any set of UsageRecords,
    /// the filtered result shall contain only records where record.category equals the filter's rawValue.
    /// **Validates: Requirements 6.3**
    func filterByCategory(_ records: [UsageRecord]) -> [UsageRecord] {
        guard let category = selectedCategory, category != .all else {
            // "all" category shows everything
            return records
        }
        
        // Map RecordCategory to the stored category string
        let categoryString = categoryToStoredValue(category)
        
        return records.filter { record in
            record.category == categoryString
        }
    }
    
    /// Filter records by search text (case-insensitive contains match)
    /// - Parameter records: The records to filter
    /// - Returns: Filtered records containing the search text
    ///
    /// **Property 11: Search Filter Correctness**
    /// *For any* non-empty search string and any set of UsageRecords,
    /// the filtered result shall contain only records where record.content contains the search string (case-insensitive).
    /// **Validates: Requirements 6.4**
    func filterBySearchText(_ records: [UsageRecord]) -> [UsageRecord] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedSearch.isEmpty else {
            // Empty search shows all records
            return records
        }
        
        return records.filter { record in
            record.content.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert RecordCategory enum to the stored string value in CoreData
    /// - Parameter category: The RecordCategory enum value
    /// - Returns: The string value stored in CoreData
    private func categoryToStoredValue(_ category: RecordCategory) -> String {
        switch category {
        case .all:
            return "" // Should not be used for filtering
        case .polish:
            return "polish"
        case .translate:
            return "translate"
        case .memo:
            return "memo"
        }
    }
}

// MARK: - Testing Support

extension LibraryViewModel {
    
    /// Filter records by category (static version for testing)
    /// - Parameters:
    ///   - records: The records to filter
    ///   - category: The category to filter by
    /// - Returns: Filtered records matching the category
    static func filterByCategory(_ records: [UsageRecord], category: RecordCategory?) -> [UsageRecord] {
        guard let category = category, category != .all else {
            return records
        }
        
        let categoryString: String
        switch category {
        case .all:
            return records
        case .polish:
            categoryString = "polish"
        case .translate:
            categoryString = "translate"
        case .memo:
            categoryString = "memo"
        }
        
        return records.filter { $0.category == categoryString }
    }
    
    /// Filter records by search text (static version for testing)
    /// - Parameters:
    ///   - records: The records to filter
    ///   - searchText: The search text to filter by
    /// - Returns: Filtered records containing the search text
    static func filterBySearchText(_ records: [UsageRecord], searchText: String) -> [UsageRecord] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedSearch.isEmpty else {
            return records
        }
        
        return records.filter { record in
            record.content.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }
}
