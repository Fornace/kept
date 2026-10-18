import Foundation
import SwiftData
import WidgetKit
import KeptKit
import os

/// One container for the whole app. The store stays in the app's own support directory:
/// only the deadline snapshot is ever written to the shared container.
enum KeptStorage {
    static let storeDirectory = URL.applicationSupportDirectory.appending(path: "Kept", directoryHint: .isDirectory)
    static let storeURL = storeDirectory.appending(path: "kept.store")

    static let container: ModelContainer = {
        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: Receipt.self, LineItem.self, configurations: configuration)
        } catch {
            fatalError("Kept cannot open its store at \(storeURL.path): \(error)")
        }
    }()
}

@Observable
final class ReceiptStore {
    static let shared = ReceiptStore()

    private static let log = Logger(subsystem: "it.fornace.kept", category: "store")

    let context: ModelContext

    init(context: ModelContext = KeptStorage.container.mainContext) {
        self.context = context
    }

    @discardableResult
    func add(_ draft: ReceiptDraft, imageData: Data?) -> Receipt {
        let receipt = Receipt(
            merchant: draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            purchaseDate: draft.purchaseDate,
            amountMinor: draft.amountMinor,
            currencyCode: draft.currencyCode,
            category: draft.category,
            returnDays: draft.returnDays,
            warrantyMonths: draft.warrantyMonths,
            note: draft.note,
            imageData: imageData
        )
        receipt.items = draft.items.enumerated().map { index, item in
            LineItem(name: item.name, amountMinor: item.amountMinor, order: index)
        }
        context.insert(receipt)
        commit()
        return receipt
    }

    func update(_ receipt: Receipt, with draft: ReceiptDraft, imageData: Data?? = nil) {
        receipt.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.purchaseDate = draft.purchaseDate
        receipt.amountMinor = draft.amountMinor
        receipt.currencyCode = draft.currencyCode
        receipt.category = draft.category
        receipt.returnDays = draft.returnDays
        receipt.warrantyMonths = draft.warrantyMonths
        receipt.note = draft.note
        if let imageData, let data = imageData {
            receipt.imageData = data
        }
        for item in receipt.items { context.delete(item) }
        receipt.items = draft.items.enumerated().map { index, item in
            LineItem(name: item.name, amountMinor: item.amountMinor, order: index)
        }
        commit()
    }

    func setStatus(_ receipt: Receipt, _ status: ReceiptStatus) {
        receipt.status = status
        commit()
    }

    func extendWarranty(_ receipt: Receipt, byMonths months: Int) {
        receipt.warrantyMonths = (receipt.warrantyMonths ?? 0) + months
        commit()
    }

    func delete(_ receipt: Receipt) {
        context.delete(receipt)
        commit()
    }

    func deleteEverything() {
        try? context.delete(model: LineItem.self)
        try? context.delete(model: Receipt.self)
        commit()
    }

    func allReceipts() -> [Receipt] {
        (try? context.fetch(FetchDescriptor<Receipt>(sortBy: [SortDescriptor(\.purchaseDate, order: .reverse)]))) ?? []
    }

    /// Persist, then refresh everything that lives outside the store: widget snapshot and reminders.
    func commit(reference: Date = .now) {
        do {
            try context.save()
        } catch {
            Self.log.fault("Kept could not save: \(error.localizedDescription, privacy: .public)")
        }
        publishSnapshot(reference: reference)
        Task { await ReminderScheduler.shared.refresh(receipts: allReceipts(), settings: .shared) }
    }

    func publishSnapshot(reference: Date = .now) {
        let receipts = allReceipts().filter { $0.status == .active }
        let currency = dominantCurrency(in: receipts)
        let open = receipts.filter { !$0.currencyCode.isEmpty ? $0.currencyCode == currency : true }

        let entries = receipts.compactMap { $0.snapshotEntry(reference: reference) }.sorted { $0.endsOn < $1.endsOn }
        let returnable = open.filter { ($0.returnStatus(reference: reference)?.phase ?? .expired) != .expired }
        let covered = open.filter { ($0.warrantyStatus(reference: reference)?.phase ?? .expired) != .expired }

        let snapshot = KeptSnapshot(
            entries: entries,
            returnableMinor: returnable.reduce(0) { $0 + $1.amountMinor },
            warrantyMinor: covered.reduce(0) { $0 + $1.amountMinor },
            currency: currency,
            updatedAt: reference
        )
        do {
            try SnapshotStore.write(snapshot)
        } catch {
            Self.log.error("Kept could not write the widget snapshot: \(error.localizedDescription, privacy: .public)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func dominantCurrency(in receipts: [Receipt]) -> String {
        let fallback = Locale.current.currency?.identifier ?? "EUR"
        let counts = Dictionary(receipts.map(\.currencyCode).filter { !$0.isEmpty }.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { lhs, rhs in lhs.value < rhs.value }?.key ?? fallback
    }
}
