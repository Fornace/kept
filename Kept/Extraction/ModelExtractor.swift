import Foundation
import FoundationModels
import KeptKit

@Generable
struct ModelReceiptItem {
    @Guide(description: "Item description exactly as printed, at most six words.")
    var name: String

    @Guide(description: "Line total for this item as digits with one decimal point, no currency symbol.")
    var total: Double
}

@Generable
struct ModelReceipt {
    @Guide(description: "Shop or merchant name as printed, without street address or legal suffix.")
    var merchant: String

    @Guide(description: "Purchase date as YYYY-MM-DD. Empty string when the receipt shows no date.")
    var purchaseDate: String

    @Guide(description: "Final amount paid, digits with one decimal point, no currency symbol or thousands separator. 0 when unreadable.")
    var total: Double

    @Guide(description: "ISO 4217 currency code such as EUR, USD or GBP, inferred from the printed symbol.")
    var currency: String

    @Guide(description: "The kind of purchase.", .anyOf(ReceiptCategory.allCases.map(\.title)))
    var category: String

    @Guide(description: "Return window in days the receipt explicitly states. 0 when it states none.", .range(0...365))
    var returnDays: Int

    @Guide(description: "Warranty length in months the receipt explicitly states. 0 when it states none.", .range(0...120))
    var warrantyMonths: Int

    @Guide(description: "Up to twelve purchased items with their own line totals. Empty when the lines are not legible.")
    var items: [ModelReceiptItem]
}

/// Apple's on-device model, used when the device has it. Nothing leaves the phone.
enum ModelExtractor {
    /// Probed once: asking the system model for availability touches the model bundle and
    /// must never happen inside a view body or an animation frame.
    static let availability: SystemLanguageModel.Availability = SystemLanguageModel.default.availability

    static var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    static var unavailableExplanation: String? {
        switch availability {
        case .available:
            nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: "This device does not run Apple Intelligence, so Kept reads receipts with its document scanner."
            case .appleIntelligenceNotEnabled: "Turn on Apple Intelligence to let Kept read receipt wording, such as a stated return window."
            case .modelNotReady: "Apple Intelligence is still preparing its model on this device."
            @unknown default: "The on-device language model is not available right now."
            }
        }
    }

    static func draft(from document: ScannedDocument, now: Date = .now) async throws -> ReceiptDraft {
        let session = LanguageModelSession(instructions: """
            You read photographed shop receipts and return them as structured data.
            Read only what is printed. Never invent a merchant, a date, an amount, a return window or a warranty.
            When a field is not printed, return an empty string or 0 for it.
            The total is the final amount the customer paid, not a subtotal and not the tax line.
            """)

        let prompt = """
            Receipt text, in reading order:

            \(document.promptText)
            """

        let response = try await withDeadline(seconds: 20) {
            try await session.respond(
                to: prompt,
                generating: ModelReceipt.self,
                options: GenerationOptions(temperature: 0.2)
            )
        }
        return merge(response.content, now: now)
    }

    static func merge(_ model: ModelReceipt, now: Date = .now) -> ReceiptDraft {
        var draft = ReceiptDraft()
        draft.engine = .languageModel

        let merchant = model.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty { draft.merchant = merchant }

        if let date = parseDate(model.purchaseDate, now: now) {
            draft.purchaseDate = date
            draft.dateSource = .receipt
        }

        if model.total > 0, model.total < 10_000_000 {
            draft.amountMinor = Int((model.total * 100).rounded())
            draft.amountSource = .receipt
        }

        let code = model.currency.uppercased().trimmingCharacters(in: .whitespaces)
        if code.count == 3, code.allSatisfy(\.isLetter) {
            draft.currencyCode = code
        }

        if let category = ReceiptCategory.allCases.first(where: { $0.title.caseInsensitiveCompare(model.category) == .orderedSame }) {
            draft.category = category
        }

        if model.returnDays > 0 {
            draft.returnDays = model.returnDays
            draft.returnSource = .receipt
        }
        if model.warrantyMonths > 0 {
            draft.warrantyMonths = model.warrantyMonths
            draft.warrantySource = .receipt
        }

        draft.items = model.items.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, item.total > 0 else { return nil }
            return DraftItem(name: name, amountMinor: Int((item.total * 100).rounded()))
        }

        draft.applyCategoryDefaults()
        return draft
    }

    private static func parseDate(_ raw: String, now: Date) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return nil }
        if let date = try? Date(trimmed, strategy: Date.ISO8601FormatStyle().year().month().day()) {
            return date
        }
        for format in ["dd/MM/yyyy", "MM/dd/yyyy", "dd.MM.yyyy", "dd-MM-yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed), date <= now.addingTimeInterval(86_400) {
                return date
            }
        }
        return nil
    }
}
