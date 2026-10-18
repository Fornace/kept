import Foundation

/// The two clocks that run on every purchase.
public enum CoverageKind: String, Codable, Sendable, CaseIterable {
    case returns
    case warranty

    public var title: String {
        switch self {
        case .returns: "Return window"
        case .warranty: "Warranty"
        }
    }

    public var symbol: String {
        switch self {
        case .returns: "arrow.uturn.backward"
        case .warranty: "checkmark.shield"
        }
    }

    /// How close to the end date the item starts asking for attention.
    public var warningDays: Int {
        switch self {
        case .returns: 3
        case .warranty: 30
        }
    }
}

public enum CoveragePhase: String, Codable, Sendable {
    case open
    case urgent
    case expired
}

/// One deadline, resolved against a reference date.
public struct CoverageStatus: Codable, Sendable, Hashable, Identifiable {
    public let kind: CoverageKind
    public let endsOn: Date
    /// Whole days from the reference day to the end day. Negative once passed.
    public let daysLeft: Int
    public let phase: CoveragePhase

    public var id: String { kind.rawValue }

    public init(kind: CoverageKind, endsOn: Date, reference: Date, calendar: Calendar = .current) {
        self.kind = kind
        self.endsOn = endsOn
        let today = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: endsOn)
        let days = calendar.dateComponents([.day], from: today, to: end).day ?? 0
        self.daysLeft = days
        if days < 0 {
            self.phase = .expired
        } else if days <= kind.warningDays {
            self.phase = .urgent
        } else {
            self.phase = .open
        }
    }

    /// "4 days left", "Last day", "Closed 3 days ago", "31 Jan 2028"
    public var countdown: String {
        if daysLeft == 0 { return phase == .expired ? "Closed" : "Last day" }
        if daysLeft == 1 { return "Tomorrow" }
        if daysLeft > 1 && daysLeft < 60 { return "\(daysLeft) days" }
        if daysLeft > 0 { return KeptFormat.monthYear.string(from: endsOn) }
        let ago = abs(daysLeft)
        if ago == 1 { return "Closed yesterday" }
        if ago < 60 { return "Closed \(ago) days ago" }
        return "Closed " + KeptFormat.monthYear.string(from: endsOn)
    }

    public var sentence: String {
        if phase == .expired {
            return kind == .returns ? "Return window closed" : "Warranty ended"
        }
        if daysLeft == 0 {
            return kind == .returns ? "Last day to return" : "Warranty ends today"
        }
        if daysLeft == 1 {
            return kind == .returns ? "Return window closes tomorrow" : "Warranty ends tomorrow"
        }
        let noun = kind == .returns ? "to return" : "under warranty"
        return "\(daysLeft) days \(noun)"
    }
}

public enum Coverage {
    /// Return windows run in calendar days from the purchase day and include that final day.
    public static func returnDate(purchased: Date, days: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: purchased)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }

    /// Warranties run in whole months from the purchase day.
    public static func warrantyDate(purchased: Date, months: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: purchased)
        return calendar.date(byAdding: .month, value: months, to: start) ?? start
    }

    /// Everything still open, soonest first, followed by what has lapsed most recently.
    public static func sorted(_ statuses: [CoverageStatus]) -> [CoverageStatus] {
        statuses.sorted { lhs, rhs in
            if (lhs.daysLeft < 0) != (rhs.daysLeft < 0) { return rhs.daysLeft < 0 }
            return lhs.daysLeft < rhs.daysLeft
        }
    }
}

public enum KeptFormat {
    public static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMyyyy")
        return formatter
    }()

    public static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()

    public static func money(_ minorUnits: Int, currency: String) -> String {
        let amount = Decimal(minorUnits) / 100
        return amount.formatted(.currency(code: currency).precision(.fractionLength(2)))
    }

    public static func compactMoney(_ minorUnits: Int, currency: String) -> String {
        let amount = Decimal(minorUnits) / 100
        return amount.formatted(.currency(code: currency).precision(.fractionLength(0)))
    }
}
