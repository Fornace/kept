import Foundation
import SwiftData
import KeptKit
import os

/// One pass through the scanner: choose, read, check, keep.
@MainActor
@Observable
final class ScanController: Identifiable {
    enum Phase: Equatable {
        case choose
        case reading
        case review
        case failed(String)
    }

    private static let log = Logger(subsystem: "it.fornace.kept", category: "scan")

    let id = UUID()
    var phase: Phase = .choose
    var imageData: Data?
    var draft = ReceiptDraft()
    var editingReceiptID: UUID?
    var isManual = false
    var wantsFilePicker = false

    init() {}

    init(manual: Bool) {
        self.isManual = manual
        draft.amountSource = .empty
        draft.dateSource = .suggestion
        draft.returnSource = .suggestion
        draft.warrantySource = .suggestion
        draft.applyCategoryDefaults()
        phase = .review
    }

    init(editing receipt: Receipt) {
        editingReceiptID = receipt.id
        imageData = receipt.imageData
        draft.merchant = receipt.merchant
        draft.purchaseDate = receipt.purchaseDate
        draft.amountMinor = receipt.amountMinor
        draft.currencyCode = receipt.currencyCode
        draft.category = receipt.category
        draft.returnDays = receipt.returnDays
        draft.warrantyMonths = receipt.warrantyMonths
        draft.note = receipt.note
        draft.items = receipt.sortedItems.map { DraftItem(name: $0.name, amountMinor: $0.amountMinor) }
        draft.dateSource = .receipt
        draft.amountSource = .receipt
        draft.returnSource = receipt.returnDays == nil ? .empty : .receipt
        draft.warrantySource = receipt.warrantyMonths == nil ? .empty : .receipt
        phase = .review
    }

    func ingest(_ data: Data) async {
        print("[kept] ingest called with \(data.count) bytes")
        phase = .reading
        let normalized = ReceiptImage.normalized(data) ?? data
        imageData = normalized

        do {
            print("[kept] ingest start \(normalized.count) bytes")
            Self.log.notice("ingest start, \(normalized.count, privacy: .public) bytes")
            let document = try await ReceiptReader.read(imageData: normalized)
            print("[kept] reader returned \(document.lines.count) lines")
            Self.log.notice("reader returned \(document.lines.count, privacy: .public) lines")
            let interpreted = await ReceiptInterpreter.draft(from: document)
            print("[kept] draft ready for \(interpreted.merchant)")
            Self.log.notice("draft ready for \(interpreted.merchant, privacy: .public)")
            draft = interpreted
            draft.applyCategoryDefaults()
            phase = .review
        } catch {
            print("[kept] scan failed: \(error.localizedDescription)")
            Self.log.error("scan failed: \(error.localizedDescription, privacy: .public)")
            phase = .failed(error.localizedDescription)
        }
    }

    func retry() {
        phase = .choose
        imageData = nil
        draft = ReceiptDraft()
    }
}
