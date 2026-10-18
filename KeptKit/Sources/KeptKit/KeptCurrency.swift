import Foundation

public enum KeptCurrency {
    /// The currency most of the store uses; totals are meaningless across currencies.
    public static func dominant(_ codes: [String]) -> String {
        let fallback = Locale.current.currency?.identifier ?? "EUR"
        guard !codes.isEmpty else { return fallback }
        let counts = Dictionary(codes.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { lhs, rhs in lhs.value < rhs.value }?.key ?? fallback
    }
}
