import Foundation
import KeptKit

@main
struct Probe {
    static func main() async {
        let path = CommandLine.arguments[1]
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { exit(1) }
        do {
            let doc = try await ReceiptReader.read(imageData: data)
            for (index, line) in doc.lines.enumerated() {
                print(String(format: "%2d | %@", index, line))
            }
            let draft = PatternExtractor.draft(from: doc)
            print("--- merchant:", draft.merchant)
            print("--- total:", KeptFormat.money(draft.amountMinor, currency: draft.currencyCode))
            print("--- date:", draft.purchaseDate.formatted(.dateTime.day().month().year()))
            print("--- amounts per line:")
            for line in doc.lines { print("   ", PatternExtractor.amounts(in: line), "|", line) }
        } catch {
            print("error:", error)
        }
    }
}
