//
//  QuotaRecord+CoreDataProperties.swift
//  AIInputMethod
//
//  CoreData properties extension for QuotaRecord entity.
//

import Foundation
import CoreData

extension QuotaRecord {
    
    /// Fetch request for QuotaRecord entities
    @nonobjc public class func fetchRequest() -> NSFetchRequest<QuotaRecord> {
        return NSFetchRequest<QuotaRecord>(entityName: "QuotaRecord")
    }
    
    /// Device identifier for associating quota with a specific device
    @NSManaged public var deviceId: String
    
    /// Total seconds of voice input used in the current period
    @NSManaged public var usedSeconds: Int32
    
    /// Date when the quota will reset (typically monthly)
    @NSManaged public var resetDate: Date
    
    /// Timestamp of the last quota update
    @NSManaged public var lastUpdated: Date
}

extension QuotaRecord: Identifiable {
    public var id: String { deviceId }
}
