import Foundation
import SwiftData
import KeptKit

enum ReceiptStatus: String, Codable, Sendable {
    case active
    case returned
    case claimed
}

@Model
final class Receipt {
    var id: UUID = UUID()
    var merchant: String = ""
    var purchaseDate: Date = Date()
    var amountMinor: Int = 0
    var currencyCode: String = "EUR"
    var categoryRaw: String = ReceiptCategory.other.rawValue
    /// Days the shop allows for a return. Nil means the receipt carries no return window.
    var returnDays: Int?
    /// Months of manufacturer or shop warranty. Nil means unknown.
    var warrantyMonths: Int?
    var note: String = ""
    var statusRaw: String = ReceiptStatus.active.rawValue
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var imageData: Data?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)
    var items: [LineItem] = []

    init(
        id: UUID = UUID(),
        merchant: String,
        purchaseDate: Date,
        amountMinor: Int,
        currencyCode: String,
        category: ReceiptCategory,
        returnDays: Int?,
        warrantyMonths: Int?,
        note: String = "",
        status: ReceiptStatus = .active,
        createdAt: Date = .now,
        imageData: Data? = nil,
        items: [LineItem] = []
    ) {
        self.id = id
        self.merchant = merchant
        self.purchaseDate = purchaseDate
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.categoryRaw = category.rawValue
        self.returnDays = returnDays
        self.warrantyMonths = warrantyMonths
        self.note = note
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.imageData = imageData
        self.items = items
    }
}

@Model
final class LineItem {
    var id: UUID = UUID()
    var name: String = ""
    var amountMinor: Int = 0
    var order: Int = 0
    var receipt: Receipt?

    init(id: UUID = UUID(), name: String, amountMinor: Int, order: Int = 0) {
        self.id = id
        self.name = name
        self.amountMinor = amountMinor
        self.order = order
    }
}

extension Receipt {
    var category: ReceiptCategory {
        get { ReceiptCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var status: ReceiptStatus {
        get { ReceiptStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var sortedItems: [LineItem] {
        items.sorted { $0.order < $1.order }
    }

    var money: String {
        KeptFormat.money(amountMinor, currency: currencyCode)
    }

    func returnStatus(reference: Date = .now) -> CoverageStatus? {
        guard let returnDays, returnDays > 0 else { return nil }
        let end = Coverage.returnDate(purchased: purchaseDate, days: returnDays)
        return CoverageStatus(kind: .returns, endsOn: end, reference: reference)
    }

    func warrantyStatus(reference: Date = .now) -> CoverageStatus? {
        guard let warrantyMonths, warrantyMonths > 0 else { return nil }
        let end = Coverage.warrantyDate(purchased: purchaseDate, months: warrantyMonths)
        return CoverageStatus(kind: .warranty, endsOn: end, reference: reference)
    }

    func statuses(reference: Date = .now) -> [CoverageStatus] {
        [returnStatus(reference: reference), warrantyStatus(reference: reference)].compactMap { $0 }
    }

    /// The deadline that most deserves attention: the soonest one still open, else the latest lapsed.
    func headline(reference: Date = .now) -> CoverageStatus? {
        let all = statuses(reference: reference)
        let open = all.filter { $0.phase != .expired }.min { $0.daysLeft < $1.daysLeft }
        return open ?? all.max { $0.daysLeft < $1.daysLeft }
    }

    func snapshotEntry(reference: Date = .now) -> KeptSnapshot.Entry? {
        guard let headline = headline(reference: reference) else { return nil }
        guard headline.phase != .expired else { return nil }
        return KeptSnapshot.Entry(
            id: id,
            merchant: merchant,
            category: category,
            kind: headline.kind,
            endsOn: headline.endsOn,
            amountMinor: amountMinor,
            currency: currencyCode
        )
    }
}
