import Foundation
import KeptKit

struct DraftItem: Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var amountMinor: Int

    var money: String { KeptFormat.money(amountMinor, currency: "") }
}

/// Where a field came from, so the review sheet never presents a guess as a reading.
enum ValueSource: String, Sendable {
    /// Printed on the receipt and read from it.
    case receipt
    /// Taken from what shops in this category usually offer.
    case suggestion
    /// Picked or typed by the person.
    case chosen
    /// Deliberately not tracked.
    case empty
}

/// The editable result of a scan, before it becomes a stored receipt.
struct ReceiptDraft: Identifiable, Sendable {
    var id = UUID()
    var merchant: String = ""
    var purchaseDate: Date = .now
    var amountMinor: Int = 0
    var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    var category: ReceiptCategory = .other
    var returnDays: Int? = 14
    var warrantyMonths: Int? = 12
    var note: String = ""
    var items: [DraftItem] = []

    var dateSource: ValueSource = .empty
    var amountSource: ValueSource = .empty
    var returnSource: ValueSource = .suggestion
    var warrantySource: ValueSource = .suggestion
    var engine: ExtractionEngine = .documentScan

    var trimmedMerchant: String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isPlausible: Bool {
        !trimmedMerchant.isEmpty && amountMinor > 0
    }

    mutating func applyCategoryDefaults() {
        if returnSource != .receipt {
            returnDays = category.typicalReturnDays ?? 14
        }
        if warrantySource != .receipt {
            warrantyMonths = category.typicalWarranty ?? 12
        }
    }
}

enum ExtractionEngine: String, Sendable {
    case languageModel
    case documentScan

    var label: String {
        switch self {
        case .languageModel: "Read by Apple Intelligence on this device"
        case .documentScan: "Read by the on-device document scanner"
        }
    }
}
