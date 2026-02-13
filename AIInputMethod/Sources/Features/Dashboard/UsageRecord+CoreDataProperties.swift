//
//  UsageRecord+CoreDataProperties.swift
//  AIInputMethod
//
//  CoreData properties extension for UsageRecord entity.
//

import Foundation
import CoreData

extension UsageRecord {
    
    /// Fetch request for UsageRecord entities
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UsageRecord> {
        return NSFetchRequest<UsageRecord>(entityName: "UsageRecord")
    }
    
    /// Unique identifier for the record
    @NSManaged public var id: UUID
    
    /// The actual content/text of the voice input
    @NSManaged public var content: String
    
    /// Category of the input: "polish", "translate", "memo", "general"
    @NSManaged public var category: String
    
    /// Display name of the source application
    @NSManaged public var sourceApp: String
    
    /// Bundle identifier of the source application
    @NSManaged public var sourceAppBundleId: String
    
    /// Timestamp when the record was created
    @NSManaged public var timestamp: Date
    
    /// Duration of the voice input in seconds
    @NSManaged public var duration: Int32
    
    /// Device identifier for associating records with a specific device
    @NSManaged public var deviceId: String
    
    /// Original voice transcription before AI processing (nil if no processing was done)
    @NSManaged public var originalContent: String?
    
    /// The skill ID used to process this record (nil for legacy records)
    @NSManaged public var skillId: String?
    
    /// The skill display name at the time of recording (nil for legacy records)
    @NSManaged public var skillName: String?
}

extension UsageRecord: Identifiable {
    
}
