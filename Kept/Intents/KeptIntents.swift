import AppIntents
import Foundation
import SwiftData
import UniformTypeIdentifiers
import KeptKit

/// "What can I still return?" answered without opening the app.
struct ExpiringSoonIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "What expires soon"
    nonisolated static let description = IntentDescription(
        "Reads the nearest return windows and warranty endings from Kept.",
        categoryName: "Deadlines"
    )
    nonisolated static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipts = ReceiptStore.shared.allReceipts()
        let summary = DeskSummary(receipts: receipts)

        guard !summary.isEmpty else {
            return .result(dialog: "Kept is empty. Photograph a receipt and its deadlines start counting.")
        }

        if summary.returnableCount == 0 && summary.warrantyCount == 0 {
            return .result(dialog: "Nothing is still returnable and no warranty is running.")
        }

        var parts: [String] = []
        if summary.returnableCount > 0 {
            let money = KeptFormat.compactMoney(summary.returnableMinor, currency: summary.currency)
            let nearest = summary.nearestReturn.map { ", nearest \($0.naturalDeadline)" } ?? ""
            parts.append("\(money) is still returnable\(nearest).")
        }
        if let next = summary.nextWarrantyEnd {
            parts.append("Warranties run to \(KeptFormat.monthYear.string(from: next.endsOn)) at the latest.")
        }
        return .result(dialog: IntentDialog(stringLiteral: parts.joined(separator: " ")))
    }
}

/// Share sheet and Shortcuts entry point: hand Kept a photo or a PDF and it opens the check sheet.
struct AddReceiptIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Add a receipt"
    nonisolated static let description = IntentDescription(
        "Reads a photographed or shared receipt and opens Kept to check what it found.",
        categoryName: "Capture"
    )
    nonisolated static let openAppWhenRun: Bool = true

    @Parameter(title: "Receipt", supportedContentTypes: [.image, .pdf])
    var file: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult {
        var data = file.data
        if file.fileURL?.pathExtension.lowercased() == "pdf", let pdf = PDFRaster.firstPage(of: data) {
            data = pdf
        }
        NotificationCenter.default.post(name: .keptImportRequest, object: data)
        return .result()
    }
}

struct KeptShortcuts: AppShortcutsProvider {
    nonisolated static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ExpiringSoonIntent(),
            phrases: [
                "What can I still return in \(.applicationName)",
                "What expires soon in \(.applicationName)"
            ],
            shortTitle: "Expiring soon",
            systemImageName: "arrow.uturn.backward"
        )
        AppShortcut(
            intent: AddReceiptIntent(),
            phrases: [
                "Add a receipt to \(.applicationName)",
                "Scan a receipt with \(.applicationName)"
            ],
            shortTitle: "Add receipt",
            systemImageName: "doc.viewfinder"
        )
    }
}
