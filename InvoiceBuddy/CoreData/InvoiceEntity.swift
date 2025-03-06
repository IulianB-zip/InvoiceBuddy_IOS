//
//  InvoiceEntity.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// InvoiceEntity+CoreDataClass.swift
import Foundation
import CoreData

@objc(InvoiceEntity)
public class InvoiceEntity: NSManagedObject {
}

// InvoiceEntity+CoreDataProperties.swift
import Foundation
import CoreData

extension InvoiceEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<InvoiceEntity> {
        return NSFetchRequest<InvoiceEntity>(entityName: "InvoiceEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var invoiceDescription: String?
    @NSManaged public var amount: Double
    @NSManaged public var dueDate: Date?
    @NSManaged public var status: String?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var reminderDate: Date?
    @NSManaged public var barcode: String?
    @NSManaged public var qrData: String?
    @NSManaged public var notes: String?
    @NSManaged public var priority: Int16
    @NSManaged public var isPaid: Bool
    @NSManaged public var paymentDate: Date?
    @NSManaged public var associatedCardId: String?
}

// CardEntity+CoreDataClass.swift
import Foundation
import CoreData

@objc(CardEntity)
public class CardEntity: NSManagedObject {
}

// CardEntity+CoreDataProperties.swift
import Foundation
import CoreData

extension CardEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CardEntity> {
        return NSFetchRequest<CardEntity>(entityName: "CardEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var type: String?
    @NSManaged public var lastFourDigits: String?
    @NSManaged public var expiryDate: Date?
    @NSManaged public var isDefault: Bool
}

// MonthSettingEntity+CoreDataClass.swift
import Foundation
import CoreData

@objc(MonthSettingEntity)
public class MonthSettingEntity: NSManagedObject {
}

// MonthSettingEntity+CoreDataProperties.swift
import Foundation
import CoreData

extension MonthSettingEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MonthSettingEntity> {
        return NSFetchRequest<MonthSettingEntity>(entityName: "MonthSettingEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var year: Int16
    @NSManaged public var month: Int16
    @NSManaged public var isCritical: Bool
    @NSManaged public var isLowIncome: Bool
    @NSManaged public var note: String?
    @NSManaged public var annualExpenses: NSSet?
}

// MARK: Generated accessors for annualExpenses
extension MonthSettingEntity {
    @objc(addAnnualExpensesObject:)
    @NSManaged public func addToAnnualExpenses(_ value: AnnualExpenseEntity)

    @objc(removeAnnualExpensesObject:)
    @NSManaged public func removeFromAnnualExpenses(_ value: AnnualExpenseEntity)

    @objc(addAnnualExpenses:)
    @NSManaged public func addToAnnualExpenses(_ values: NSSet)

    @objc(removeAnnualExpenses:)
    @NSManaged public func removeFromAnnualExpenses(_ values: NSSet)
}

// AnnualExpenseEntity+CoreDataClass.swift
import Foundation
import CoreData

@objc(AnnualExpenseEntity)
public class AnnualExpenseEntity: NSManagedObject {
}

// AnnualExpenseEntity+CoreDataProperties.swift
import Foundation
import CoreData

extension AnnualExpenseEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AnnualExpenseEntity> {
        return NSFetchRequest<AnnualExpenseEntity>(entityName: "AnnualExpenseEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var amount: Double
    @NSManaged public var dueDate: Date?
    @NSManaged public var monthSetting: MonthSettingEntity?
}

// PaydayEntity+CoreDataClass.swift
import Foundation
import CoreData

@objc(PaydayEntity)
public class PaydayEntity: NSManagedObject {
}

// PaydayEntity+CoreDataProperties.swift
import Foundation
import CoreData

extension PaydayEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PaydayEntity> {
        return NSFetchRequest<PaydayEntity>(entityName: "PaydayEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
}

// CoreDataModel.xcdatamodeld
/*
This is the Core Data model file structure in Xcode. You would set this up
in the Xcode Core Data model editor, not in code, but here's the structure:

Entity: InvoiceEntity
- id: UUID
- title: String
- invoiceDescription: String (changed from description due to reserved keyword)
- amount: Double
- dueDate: Date
- status: String
- paymentMethod: String
- reminderDate: Date (optional)
- barcode: String (optional)
- qrData: String (optional)
- notes: String (optional)
- priority: Int16
- isPaid: Bool
- paymentDate: Date (optional)
- associatedCardId: String (optional)

Entity: CardEntity
- id: UUID
- name: String
- type: String
- lastFourDigits: String
- expiryDate: Date
- isDefault: Bool

Entity: MonthSettingEntity
- id: UUID
- year: Int16
- month: Int16
- isCritical: Bool
- isLowIncome: Bool
- note: String (optional)
- Relationship: annualExpenses (to-many) -> AnnualExpenseEntity

Entity: AnnualExpenseEntity
- id: UUID
- title: String
- amount: Double
- dueDate: Date
- Relationship: monthSetting (to-one) -> MonthSettingEntity

Entity: PaydayEntity
- id: UUID
- date: Date
*/

// Instructions for adding the Core Data model to your Xcode project:
/*
1. In Xcode, go to File > New > File...
2. Select "Data Model" under the "Core Data" section
3. Name it "InvoiceManager" and save it to your project
4. Open the InvoiceManager.xcdatamodeld file
5. Add the entities and attributes as described above
6. For MonthSettingEntity, add a relationship named "annualExpenses"
   - Set to to-many relationship to AnnualExpenseEntity
   - Set delete rule to Cascade
7. For AnnualExpenseEntity, add a relationship named "monthSetting"
   - Set to to-one relationship to MonthSettingEntity
   - Set inverse relationship to "annualExpenses"
   - Set delete rule to Nullify

8. Make sure to add these imports to your application:
   - import CoreData
   - import UserNotifications (for reminders)

9. Add the following to your Info.plist:
   - Privacy - Camera Usage Description: "This app uses your camera to scan invoice barcodes and QR codes"
   
10. Create the Core Data model entities and properties as shown above
*/