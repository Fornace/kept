import Foundation
import KeptKit

/// Reads a receipt with the best reader this device has, and says which one it used.
enum ReceiptInterpreter {
    static func draft(from document: ScannedDocument, now: Date = .now) async -> ReceiptDraft {
        var pattern = PatternExtractor.draft(from: document, now: now)
        pattern.applyCategoryDefaults()

        guard ModelExtractor.isAvailable else { return pattern }

        do {
            var model = try await ModelExtractor.draft(from: document, now: now)
            if model.merchant.isEmpty { model.merchant = pattern.merchant }
            if model.amountMinor == 0 {
                model.amountMinor = pattern.amountMinor
                model.amountSource = pattern.amountSource
            }
            if model.dateSource == .empty, let date = PatternExtractor.purchaseDate(in: document.text, now: now) {
                model.purchaseDate = date
                model.dateSource = .receipt
            }
            if model.items.isEmpty { model.items = pattern.items }
            if model.returnSource != .receipt { model.returnDays = pattern.returnDays }
            if model.warrantySource != .receipt { model.warrantyMonths = pattern.warrantyMonths }
            model.applyCategoryDefaults()
            return model
        } catch {
            // The scanner already produced a usable draft; the model is an upgrade, not the base.
            pattern.note = ""
            return pattern
        }
    }
}
