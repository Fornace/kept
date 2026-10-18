import Foundation
import SwiftData
import CoreGraphics
import KeptKit

/// Builds a Kept store from real receipt photographs using the app's own reader and models.
/// Usage: seed <store-directory>
@main
struct Seed {
    struct Fixture {
        let image: String
        let category: ReceiptCategory
        let returnDays: Int?
        let warrantyMonths: Int?
        let note: String
    }

    static let fixtures: [Fixture] = [
        Fixture(image: "receipt-merlini.png", category: .electronics, returnDays: 14, warrantyMonths: 24,
                note: "Serial 4471-BX. Charging case inside the box."),
        Fixture(image: "receipt-verdi.png", category: .clothing, returnDays: 14, warrantyMonths: 24,
                note: "Case included. Ask for Marta at the counter."),
        Fixture(image: "receipt-bellini.png", category: .home, returnDays: 30, warrantyMonths: 24,
                note: "Delivered assembled. Bulb is E27."),
        Fixture(image: "receipt-nove.png", category: .clothing, returnDays: 30, warrantyMonths: 12,
                note: "Alteration included, collect by 4 November.")
    ]

    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count > 1 else {
            print("usage: seed <store-directory> [fixture-directory]")
            exit(2)
        }
        let storeDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let fixtureDirectory = URL(fileURLWithPath: arguments.count > 2 ? arguments[2] : ".probe", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        } catch {
            print("cannot create store directory: \(error)")
            exit(1)
        }

        let storeURL = storeDirectory.appending(path: "kept.store")
        let configuration = ModelConfiguration(url: storeURL)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Receipt.self, LineItem.self, configurations: configuration)
        } catch {
            print("cannot open store: \(error)")
            exit(1)
        }
        let context = ModelContext(container)

        for fixture in fixtures {
            let imageURL = fixtureDirectory.appending(path: fixture.image)
            guard let data = try? Data(contentsOf: imageURL) else {
                print("missing fixture \(fixture.image)")
                continue
            }
            let normalized = ReceiptImage.normalized(data) ?? data
            do {
                let scanned = try await ReceiptReader.read(imageData: normalized)
                var draft = await ReceiptInterpreter.draft(from: scanned)
                draft.category = fixture.category
                draft.returnDays = fixture.returnDays
                draft.warrantyMonths = fixture.warrantyMonths
                draft.note = fixture.note

                let receipt = Receipt(
                    merchant: draft.merchant,
                    purchaseDate: draft.purchaseDate,
                    amountMinor: draft.amountMinor,
                    currencyCode: draft.currencyCode,
                    category: draft.category,
                    returnDays: draft.returnDays,
                    warrantyMonths: draft.warrantyMonths,
                    note: draft.note,
                    imageData: normalized
                )
                receipt.items = draft.items.enumerated().map { index, item in
                    LineItem(name: item.name, amountMinor: item.amountMinor, order: index)
                }
                context.insert(receipt)
                let day = draft.purchaseDate.formatted(.dateTime.day().month().year())
                print(String(format: "%-22s %10s  %@  items=%d  engine=%@",
                             (draft.merchant as NSString).utf8String!,
                             (KeptFormat.money(draft.amountMinor, currency: draft.currencyCode) as NSString).utf8String!,
                             day, draft.items.count, draft.engine.rawValue))
            } catch {
                print("failed on \(fixture.image): \(error)")
            }
        }

        do {
            try context.save()
            print("saved \(fixtures.count) receipts to \(storeURL.path)")
        } catch {
            print("save failed: \(error)")
            exit(1)
        }
    }
}
