import Foundation
import KeptKit

/// The always-available reader. It does not guess language: it anchors on printed totals,
/// reads dates with the system data detector, and takes line items from the document table
/// Vision already segmented.
enum PatternExtractor {
    private static let totalAnchors = [
        "totale", "total", "importo", "amount due", "balance due", "da pagare",
        "gesamt", "summe", "montant", "total ttc", "to pay", "amount paid"
    ]

    private static let noiseAnchors = [
        "subtotale", "subtotal", "iva ", "vat", " tax", "sconto", "discount", "change",
        "resto", "contanti", "cash", "carta", "card", "pagato con", "rounding", "arrotond",
        "sconto", "coupon", "buono"
    ]

    private static let dateAnchors = ["data", "date", "datum", "fecha", "emissione"]

    static func draft(from document: ScannedDocument, now: Date = .now, calendar: Calendar = .current) -> ReceiptDraft {
        var draft = ReceiptDraft()
        draft.engine = .documentScan
        draft.currencyCode = currency(in: document.text) ?? draft.currencyCode

        if let merchant = merchant(from: document.lines) {
            draft.merchant = merchant
        }

        if let date = purchaseDate(in: document.text, now: now) {
            draft.purchaseDate = date
            draft.dateSource = .receipt
        }

        if let total = total(in: document.lines) {
            draft.amountMinor = total
            draft.amountSource = .receipt
        }

        draft.items = lineItems(from: document, totalMinor: draft.amountMinor)
        draft.returnSource = .suggestion
        draft.warrantySource = .suggestion
        return draft
    }

    // MARK: - Merchant

    static func merchant(from lines: [String]) -> String? {
        let candidates = lines.prefix(6).enumerated().filter { index, line in
            let letters = line.filter(\.isLetter).count
            guard letters >= 3, letters <= 48 else { return false }
            guard !isDateLine(line) else { return false }
            let digits = line.filter(\.isNumber).count
            guard digits <= max(1, letters / 5) else { return false }
            let lowered = line.lowercased()
            return !Self.totalAnchors.contains(where: lowered.contains) && !Self.noiseAnchors.contains(where: lowered.contains)
        }

        // A shop name carries no street number: prefer clean lines, then the earliest and longest.
        let best = candidates.max { lhs, rhs in
            let lhsDigits = lhs.element.filter(\.isNumber).count
            let rhsDigits = rhs.element.filter(\.isNumber).count
            if lhsDigits != rhsDigits { return lhsDigits > rhsDigits }
            if lhs.offset != rhs.offset { return lhs.offset > rhs.offset }
            return lhs.element.count < rhs.element.count
        }
        return best.map { tidy($0.element) }
    }

    private static func tidy(_ raw: String) -> String {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "*-–—:.,"))
        let letters = trimmed.filter(\.isLetter)
        let isShouting = !letters.isEmpty && letters.allSatisfy { $0.isUppercase }
        guard isShouting else { return trimmed }
        return trimmed.capitalized(with: Locale.current)
    }

    // MARK: - Total

    static func total(in lines: [String]) -> Int? {
        var anchored: [Int] = []
        var loose: [Int] = []

        for (index, line) in lines.enumerated() {
            if isDateLine(line) { continue }
            let lowered = line.lowercased()
            if noiseAnchors.contains(where: lowered.contains) { continue }

            let money = decimalAmounts(in: line)
            if totalAnchors.contains(where: lowered.contains) {
                if let last = money.last {
                    anchored.append(last)
                } else {
                    // Receipts put the label and the amount in separate columns.
                    for neighbour in lines[(index + 1)...].prefix(2) where !isDateLine(neighbour) {
                        if let amount = decimalAmounts(in: neighbour).last {
                            anchored.append(amount)
                            break
                        }
                    }
                }
            } else if !money.isEmpty {
                loose.append(contentsOf: money)
            }
        }

        if let best = anchored.max() { return best }
        return loose.max()
    }

    // MARK: - Amounts

    static func amounts(in line: String) -> [Int] {
        tokens(in: line).compactMap { AmountParser.minorUnits($0) }
    }

    /// Money as printed, with cents. Used for totals so a date's year is never mistaken for an amount.
    static func decimalAmounts(in line: String) -> [Int] {
        tokens(in: line).filter { $0.contains(",") || $0.contains(".") }
            .compactMap { AmountParser.minorUnits($0) }
    }

    private static func tokens(in line: String) -> [String] {
        let pattern = #"\d{1,3}(?:[ .]\d{3})*[.,]\d{2}|\d+[.,]\d{2}|\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let found = Range(match.range, in: line) else { return nil }
            let token = String(line[found])
            if !token.contains(","), !token.contains("."),
               let year = Int(token), (1900...2100).contains(year) {
                return nil
            }
            return token
        }
    }

    /// A line that is a printed date, not money.
    static func isDateLine(_ line: String) -> Bool {
        let pattern = #"\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}|\d{4}-\d{2}-\d{2}"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Currency

    static func currency(in text: String) -> String? {
        let lowered = text.lowercased()
        if lowered.contains("€") || lowered.contains("eur") { return "EUR" }
        if lowered.contains("£") || lowered.contains("gbp") { return "GBP" }
        if lowered.contains("$") || lowered.contains("usd") { return "USD" }
        if lowered.contains("chf") { return "CHF" }
        return nil
    }

    // MARK: - Date

    static func purchaseDate(in text: String, now: Date = .now) -> Date? {
        let sample = String(text.prefix(1200))
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(sample.startIndex..<sample.endIndex, in: sample)
        let earliest = Calendar.current.date(byAdding: .year, value: -15, to: now) ?? now
        let latest = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

        let dates: [(date: Date, anchored: Bool)] = detector.matches(in: sample, range: range).compactMap { match in
            guard let date = match.date, date >= earliest, date <= latest else { return nil }
            let line = (sample as NSString).substring(with: (sample as NSString).lineRange(for: match.range)).lowercased()
            return (date, dateAnchors.contains(where: line.contains))
        }
        return dates.first(where: \.anchored)?.date ?? dates.first?.date
    }

    // MARK: - Line items

    static func lineItems(from document: ScannedDocument, totalMinor: Int) -> [DraftItem] {
        var items: [DraftItem] = []
        var seen = Set<String>()

        for table in document.tables {
            for row in table {
                guard row.count >= 2 else { continue }
                let joined = row.joined(separator: " ").lowercased()
                if noiseAnchors.contains(where: joined.contains) || totalAnchors.contains(where: joined.contains) {
                    continue
                }
                guard let amountCell = row.reversed().first(where: { !amounts(in: $0).isEmpty }),
                      let amount = amounts(in: amountCell).last,
                      amount > 0 else { continue }
                guard let nameCell = row.first(where: { $0.filter(\.isLetter).count >= 3 }) else { continue }
                let name = tidy(nameCell)
                guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
                items.append(DraftItem(name: name, amountMinor: amount))
                if items.count == 12 { break }
            }
            if items.count >= 12 { break }
        }

        if items.isEmpty {
            let lines = document.lines
            for (index, line) in lines.enumerated() {
                let lowered = line.lowercased()
                guard line.filter(\.isLetter).count >= 3, amounts(in: line).isEmpty else { continue }
                if noiseAnchors.contains(where: lowered.contains) || totalAnchors.contains(where: lowered.contains) {
                    continue
                }
                guard index + 1 < lines.count, let amount = amounts(in: lines[index + 1]).last, amount > 0 else { continue }
                let name = tidy(line)
                guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
                items.append(DraftItem(name: name, amountMinor: amount))
                if items.count == 12 { break }
            }
        }

        if items.isEmpty {
            for line in document.lines {
                let lowered = line.lowercased()
                guard line.filter(\.isLetter).count >= 3 else { continue }
                if noiseAnchors.contains(where: lowered.contains) || totalAnchors.contains(where: lowered.contains) {
                    continue
                }
                guard let amount = amounts(in: line).last, amount > 0 else { continue }
                let name = tidy(line.replacingOccurrences(of: #"\d[\d.,\s]*$"#, with: "", options: .regularExpression))
                guard name.count >= 2, seen.insert(name.lowercased()).inserted else { continue }
                items.append(DraftItem(name: name, amountMinor: amount))
                if items.count == 10 { break }
            }
        }

        if totalMinor > 0, items.reduce(0, { $0 + $1.amountMinor }) > totalMinor * 2 {
            return []
        }
        return items
    }
}

enum AmountParser {
    /// Reads "1.234,56", "1,234.56", "42,90" and "42" into minor units, without a float round trip.
    static func minorUnits(_ raw: String) -> Int? {
        let chars = Array(raw.filter { $0.isNumber || $0 == "." || $0 == "," })
        guard !chars.isEmpty else { return nil }

        let lastComma = chars.lastIndex(of: ",")
        let lastDot = chars.lastIndex(of: ".")
        var separatorIndex: Int?
        var separator: Character?

        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            separatorIndex = max(comma, dot)
            separator = comma > dot ? "," : "."
        case let (comma?, nil):
            if trailingDigits(chars, after: comma) == 2 { separatorIndex = comma; separator = "," }
        case let (nil, dot?):
            if trailingDigits(chars, after: dot) == 2 { separatorIndex = dot; separator = "." }
        case (nil, nil):
            break
        }

        if let separatorIndex, separator != nil {
            let whole = String(chars[..<separatorIndex].filter(\.isNumber))
            let fraction = String(chars[(separatorIndex + 1)...].filter(\.isNumber))
            guard fraction.count == 2, whole.count <= 9 else { return nil }
            return Int(whole + fraction)
        }

        let whole = String(chars.filter(\.isNumber))
        guard !whole.isEmpty, whole.count <= 9, let value = Int(whole) else { return nil }
        return value * 100
    }

    private static func trailingDigits(_ chars: [Character], after index: Int) -> Int {
        chars.count - index - 1
    }
}
