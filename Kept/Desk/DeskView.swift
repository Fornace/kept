import SwiftUI
import SwiftData
import KeptKit

struct DeskView: View {
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if summary.isEmpty {
                emptyLayout
            } else {
                populatedLayout
            }
        }
        .background(KeptTheme.paper)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(for: Receipt.self) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
        .onAppear { ReceiptStore.shared.publishSnapshot() }
    }

    private var emptyLayout: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                masthead
                EmptyDesk(
                    onScan: { app.startScan() },
                    onManual: { app.startManualEntry() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                footnote
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .frame(maxWidth: 720)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private var populatedLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                masthead
                hero
                closingSoon
                warrantyStrip
                warrantyEndings
                footnote
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private var summary: DeskSummary {
        DeskSummary(receipts: receipts)
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kept")
                    .font(.system(size: 27, weight: .semibold, design: .serif))
                    .foregroundStyle(KeptTheme.ink)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 12))
                    .foregroundStyle(KeptTheme.inkTertiary)
            }
            Spacer()
            Button {
                app.startScan()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(KeptTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(KeptTheme.surface))
                    .overlay(Circle().strokeBorder(KeptTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a receipt")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel("Still returnable")
            MoneyValue(minorUnits: summary.returnableMinor, currency: summary.currency, size: 52)
            Text(heroSentence)
                .font(.system(size: 14))
                .foregroundStyle(KeptTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroSentence: String {
        guard summary.returnableCount > 0 else {
            return summary.warrantyCount > 0
                ? "No return windows are open. Warranties are still running."
                : "No return windows are open right now."
        }
        let count = summary.returnableCount == 1 ? "1 receipt" : "\(summary.returnableCount) receipts"
        guard let nearest = summary.nearestReturn else { return count }
        return "\(count), nearest \(nearest.naturalDeadline)."
    }

    // MARK: - Closing soon

    private var closingSoon: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel("Closing soon", trailing: summary.returnableCount > 3 ? "\(summary.returnableCount) open" : nil)
            if summary.closingSoon.isEmpty {
                Text("Nothing to take back this week.")
                    .font(.system(size: 14))
                    .foregroundStyle(KeptTheme.inkTertiary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.closingSoon.enumerated()), id: \.element.id) { index, deadline in
                        if index > 0 { Hairline().padding(.leading, 56) }
                        NavigationLink(value: deadline.receipt) {
                            DeadlineRow(
                                title: deadline.receipt.merchant,
                                subtitle: "\(deadline.receipt.money) · bought \(KeptFormat.dayMonth.string(from: deadline.receipt.purchaseDate))",
                                category: deadline.receipt.category,
                                status: deadline.status
                            )
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).fill(KeptTheme.surface))
                .overlay(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
            }
        }
    }

    // MARK: - Warranty

    private var warrantyStrip: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                SectionLabel("Under warranty")
                MoneyValue(minorUnits: summary.warrantyMinor, currency: summary.currency, size: 30)
                Text(summary.warrantyCount == 1 ? "1 receipt covered" : "\(summary.warrantyCount) receipts covered")
                    .font(.system(size: 12))
                    .foregroundStyle(KeptTheme.inkTertiary)
            }
            Spacer(minLength: 0)
            if let next = summary.nextWarrantyEnd {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("NEAREST TO LAPSE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(KeptTheme.inkTertiary)
                    Text(next.phase == .urgent ? next.countdown : KeptFormat.monthYear.string(from: next.endsOn))
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(next.phase == .urgent ? KeptTheme.urgent : KeptTheme.ink)
                }
                .padding(.bottom, 3)
            }
        }
        .paperCard(padding: 17)
    }

    private var warrantyEndings: some View {
        Group {
            if !summary.warrantyEndings.isEmpty {
                VStack(alignment: .leading, spacing: 11) {
                    SectionLabel("Warranty endings")
                    VStack(spacing: 0) {
                        ForEach(Array(summary.warrantyEndings.enumerated()), id: \.element.id) { index, deadline in
                            if index > 0 { Hairline().padding(.leading, 56) }
                            NavigationLink(value: deadline.receipt) {
                                DeadlineRow(
                                    title: deadline.receipt.merchant,
                                    subtitle: "\(deadline.receipt.money) · \(warrantyLength(deadline.receipt)) cover",
                                    category: deadline.receipt.category,
                                    status: deadline.status
                                )
                                .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).fill(KeptTheme.surface))
                    .overlay(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
                }
            }
        }
    }

    private func warrantyLength(_ receipt: Receipt) -> String {
        guard let months = receipt.warrantyMonths, months > 0 else { return "no" }
        if months % 12 == 0 { return months == 12 ? "12 months" : "\(months / 12) years" }
        return "\(months) months"
    }

    private var footnote: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .medium))
            Text(privacyLine)
                .font(.system(size: 11))
        }
        .foregroundStyle(KeptTheme.inkTertiary)
        .padding(.top, 2)
    }

    private var privacyLine: String {
        #if os(iOS)
        "Receipts are read on this iPhone and stay in it."
        #else
        "Receipts are read on this Mac and stay in it."
        #endif
    }
}

// MARK: - Empty desk

struct EmptyDesk: View {
    let onScan: () -> Void
    let onManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Photograph the receipt.\nForget the deadline.")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(KeptTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Kept reads the shop, the date and the total on this device, keeps the photo, and warns you before the return window or the warranty lapses.")
                    .font(.system(size: 14))
                    .foregroundStyle(KeptTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button(action: onScan) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.viewfinder")
                        Text("Scan a receipt")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(KeptTheme.surface)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(KeptTheme.signal))
                }
                .buttonStyle(.plain)

                Button(action: onManual) {
                    Text("Add one by hand")
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(KeptTheme.ink)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(KeptTheme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                step(icon: "text.viewfinder", title: "Read on device", detail: "Apple Intelligence or the document scanner, never a server.")
                step(icon: "arrow.uturn.backward", title: "Return windows", detail: "The last day to take it back, counted down.")
                step(icon: "bell.badge", title: "One warning", detail: "A notification before each deadline, three days early by default.")
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 8)
    }

    private func step(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KeptTheme.signal)
                .frame(width: 30, height: 30)
                .background(KeptTheme.signal.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(KeptTheme.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(KeptTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
