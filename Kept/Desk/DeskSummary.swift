import Foundation
import KeptKit

struct DeskDeadline: Identifiable {
    let receipt: Receipt
    let status: CoverageStatus

    var id: String { receipt.id.uuidString + status.kind.rawValue }
}

/// Everything the desk shows, derived once per render from the store.
struct DeskSummary {
    let currency: String
    let returnableMinor: Int
    let returnableCount: Int
    let nearestReturn: CoverageStatus?
    let warrantyMinor: Int
    let warrantyCount: Int
    let nextWarrantyEnd: CoverageStatus?
    let closingSoon: [DeskDeadline]
    let warrantyEndings: [DeskDeadline]
    let totalCount: Int

    var isEmpty: Bool { totalCount == 0 }

    init(receipts: [Receipt], now: Date = .now) {
        let active = receipts.filter { $0.status == .active }
        totalCount = receipts.count

        let codes = active.map(\.currencyCode).filter { !$0.isEmpty }
        let dominant = KeptCurrency.dominant(codes)
        currency = dominant
        let inCurrency = active.filter { $0.currencyCode == dominant }

        let openReturns = inCurrency.compactMap { receipt -> DeskDeadline? in
            guard let status = receipt.returnStatus(reference: now), status.phase != .expired else { return nil }
            return DeskDeadline(receipt: receipt, status: status)
        }.sorted { $0.status.daysLeft < $1.status.daysLeft }

        let openWarranty = inCurrency.compactMap { receipt -> DeskDeadline? in
            guard let status = receipt.warrantyStatus(reference: now), status.phase != .expired else { return nil }
            return DeskDeadline(receipt: receipt, status: status)
        }.sorted { lhs, rhs in
            if lhs.status.endsOn != rhs.status.endsOn { return lhs.status.endsOn < rhs.status.endsOn }
            return lhs.receipt.merchant < rhs.receipt.merchant
        }

        returnableMinor = openReturns.reduce(0) { $0 + $1.receipt.amountMinor }
        returnableCount = openReturns.count
        nearestReturn = openReturns.first?.status
        warrantyMinor = openWarranty.reduce(0) { $0 + $1.receipt.amountMinor }
        warrantyCount = openWarranty.count
        nextWarrantyEnd = openWarranty.first?.status
        closingSoon = Array(openReturns.prefix(3))
        warrantyEndings = Array(openWarranty.prefix(2))
    }
}

extension CoverageStatus {
    /// "closes Friday" when it is this week, "closes 12 Mar" when it is further out.
    var naturalDeadline: String {
        let days = daysLeft
        if phase == .expired { return "closed \(KeptFormat.dayMonth.string(from: endsOn))" }
        if days == 0 { return "closes today" }
        if days == 1 { return "closes tomorrow" }
        if days < 7 {
            return "closes " + endsOn.formatted(.dateTime.weekday(.wide).locale(Locale.current))
        }
        return "closes " + KeptFormat.dayMonth.string(from: endsOn)
    }

    var endsRoughly: String {
        if phase == .expired { return "ended " + KeptFormat.monthYear.string(from: endsOn) }
        if daysLeft < 45 { return "ends in \(daysLeft) days" }
        return "ends " + KeptFormat.monthYear.string(from: endsOn)
    }
}
