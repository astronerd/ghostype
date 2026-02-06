//
//  PersistenceController.swift
//  AIInputMethod
//
//  CoreData stack management for Dashboard data persistence.
//  Provides shared container and context for UsageRecord and QuotaRecord entities.
//

import Foundation
import CoreData

/// PersistenceController manages the CoreData stack for the Dashboard.
/// Provides a shared instance for app-wide data access and supports preview/testing configurations.
final class PersistenceController {
    
    /// Shared singleton instance for production use
    static let shared = PersistenceController()
    
    /// Preview instance with in-memory store for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Create sample data for previews
        for i in 0..<5 {
            let record = UsageRecord(context: viewContext)
            record.id = UUID()
            record.content = "Sample content \(i + 1) - This is a preview record for testing purposes."
            record.category = ["polish", "translate", "memo", "general"][i % 4]
            record.sourceApp = ["Safari", "Notes", "Mail", "Slack", "VS Code"][i % 5]
            record.sourceAppBundleId = "com.example.app\(i)"
            record.timestamp = Date().addingTimeInterval(Double(-i * 3600))
            record.duration = Int32((i + 1) * 30)
            record.deviceId = "preview-device-id"
        }
        
        let quota = QuotaRecord(context: viewContext)
        quota.deviceId = "preview-device-id"
        quota.usedSeconds = 1800 // 30 minutes
        quota.resetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        quota.lastUpdated = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()
    
    /// The persistent container for the CoreData stack
    let container: NSPersistentContainer
    
    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Initialize the persistence controller
    /// - Parameter inMemory: If true, uses an in-memory store (for previews/testing)
    init(inMemory: Bool = false) {
        // Create the managed object model programmatically
        let model = Self.createManagedObjectModel()
        
        container = NSPersistentContainer(name: "DashboardModel", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use Application Support directory for persistent storage
            let storeURL = Self.storeURL()
            container.persistentStoreDescriptions.first?.url = storeURL
        }
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // In production, handle this more gracefully
                print("CoreData error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Creates the managed object model programmatically
    /// This avoids issues with .xcdatamodeld bundle loading in certain build configurations
    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // UsageRecord Entity
        let usageRecordEntity = NSEntityDescription()
        usageRecordEntity.name = "UsageRecord"
        usageRecordEntity.managedObjectClassName = "UsageRecord"
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let contentAttribute = NSAttributeDescription()
        contentAttribute.name = "content"
        contentAttribute.attributeType = .stringAttributeType
        contentAttribute.isOptional = false
        
        let categoryAttribute = NSAttributeDescription()
        categoryAttribute.name = "category"
        categoryAttribute.attributeType = .stringAttributeType
        categoryAttribute.isOptional = false
        
        let sourceAppAttribute = NSAttributeDescription()
        sourceAppAttribute.name = "sourceApp"
        sourceAppAttribute.attributeType = .stringAttributeType
        sourceAppAttribute.isOptional = false
        
        let sourceAppBundleIdAttribute = NSAttributeDescription()
        sourceAppBundleIdAttribute.name = "sourceAppBundleId"
        sourceAppBundleIdAttribute.attributeType = .stringAttributeType
        sourceAppBundleIdAttribute.isOptional = false
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        
        let durationAttribute = NSAttributeDescription()
        durationAttribute.name = "duration"
        durationAttribute.attributeType = .integer32AttributeType
        durationAttribute.isOptional = false
        durationAttribute.defaultValue = 0
        
        let deviceIdAttribute = NSAttributeDescription()
        deviceIdAttribute.name = "deviceId"
        deviceIdAttribute.attributeType = .stringAttributeType
        deviceIdAttribute.isOptional = false
        
        usageRecordEntity.properties = [
            idAttribute,
            contentAttribute,
            categoryAttribute,
            sourceAppAttribute,
            sourceAppBundleIdAttribute,
            timestampAttribute,
            durationAttribute,
            deviceIdAttribute
        ]
        
        // QuotaRecord Entity
        let quotaRecordEntity = NSEntityDescription()
        quotaRecordEntity.name = "QuotaRecord"
        quotaRecordEntity.managedObjectClassName = "QuotaRecord"
        
        let quotaDeviceIdAttribute = NSAttributeDescription()
        quotaDeviceIdAttribute.name = "deviceId"
        quotaDeviceIdAttribute.attributeType = .stringAttributeType
        quotaDeviceIdAttribute.isOptional = false
        
        let usedSecondsAttribute = NSAttributeDescription()
        usedSecondsAttribute.name = "usedSeconds"
        usedSecondsAttribute.attributeType = .integer32AttributeType
        usedSecondsAttribute.isOptional = false
        usedSecondsAttribute.defaultValue = 0
        
        let resetDateAttribute = NSAttributeDescription()
        resetDateAttribute.name = "resetDate"
        resetDateAttribute.attributeType = .dateAttributeType
        resetDateAttribute.isOptional = false
        
        let lastUpdatedAttribute = NSAttributeDescription()
        lastUpdatedAttribute.name = "lastUpdated"
        lastUpdatedAttribute.attributeType = .dateAttributeType
        lastUpdatedAttribute.isOptional = false
        
        quotaRecordEntity.properties = [
            quotaDeviceIdAttribute,
            usedSecondsAttribute,
            resetDateAttribute,
            lastUpdatedAttribute
        ]
        
        model.entities = [usageRecordEntity, quotaRecordEntity]
        
        return model
    }
    
    /// Returns the URL for the CoreData store file
    private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AIInputMethod", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        return appDirectory.appendingPathComponent("DashboardModel.sqlite")
    }
    
    // MARK: - CRUD Operations
    
    /// Save the view context if there are changes
    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("CoreData save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// Create a new UsageRecord with the given parameters
    func createUsageRecord(
        content: String,
        category: String,
        sourceApp: String,
        sourceAppBundleId: String,
        duration: Int32,
        deviceId: String
    ) -> UsageRecord {
        let record = UsageRecord(context: viewContext)
        record.id = UUID()
        record.content = content
        record.category = category
        record.sourceApp = sourceApp
        record.sourceAppBundleId = sourceAppBundleId
        record.timestamp = Date()
        record.duration = duration
        record.deviceId = deviceId
        return record
    }
    
    /// Fetch all UsageRecords for a device, sorted by timestamp descending
    func fetchUsageRecords(deviceId: String) -> [UsageRecord] {
        let request = UsageRecord.fetchRequest()
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UsageRecord.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
    
    /// Fetch or create QuotaRecord for a device
    func fetchOrCreateQuotaRecord(deviceId: String) -> QuotaRecord {
        let request = QuotaRecord.fetchRequest()
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId)
        request.fetchLimit = 1
        
        do {
            if let existing = try viewContext.fetch(request).first {
                return existing
            }
        } catch {
            print("Fetch error: \(error)")
        }
        
        // Create new quota record
        let quota = QuotaRecord(context: viewContext)
        quota.deviceId = deviceId
        quota.usedSeconds = 0
        quota.resetDate = Self.nextMonthResetDate()
        quota.lastUpdated = Date()
        return quota
    }
    
    /// Calculate the next monthly reset date
    private static func nextMonthResetDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return now
        }
        return nextMonth
    }
}
