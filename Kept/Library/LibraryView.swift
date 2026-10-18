import SwiftUI
import SwiftData
import KeptKit

struct LibraryView: View {
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
    @Environment(AppModel.self) private var app
    @State private var search = ""

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.receipts) { receipt in
                        NavigationLink(value: receipt) {
                            LibraryRow(receipt: receipt)
                        }
                        .listRowBackground(KeptTheme.paper)
                        .listRowSeparatorTint(KeptTheme.hairline)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                ReceiptStore.shared.delete(receipt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    SectionLabel(section.title)
                        .padding(.top, 6)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(KeptTheme.paper)
        #if os(iOS)
        .toolbarBackground(KeptTheme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .searchable(text: $search, prompt: "Shop, note, category")
        .safeAreaInset(edge: .top, spacing: 0) {
            filterBar
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView {
                    Label(search.isEmpty ? "Nothing filed yet" : "No match", systemImage: search.isEmpty ? "square.stack" : "magnifyingglass")
                } description: {
                    Text(search.isEmpty ? "A receipt you keep appears here with its deadlines." : "Try another shop name.")
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { app.startScan() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a receipt")
            }
        }
        .navigationDestination(for: Receipt.self) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(LibraryFilter.allCases) { filter in
                    ChoiceChip(title: filter.title, isSelected: app.libraryFilter == filter) {
                        app.libraryFilter = filter
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
        }
        .background(KeptTheme.paper)
    }

    // MARK: - Rows

    private var filtered: [Receipt] {
        let now = Date.now
        let byFilter = receipts.filter { receipt in
            switch app.libraryFilter {
            case .all:
                true
            case .returnable:
                receipt.status == .active && (receipt.returnStatus(reference: now)?.phase ?? .expired) != .expired
            case .covered:
                receipt.status == .active && (receipt.warrantyStatus(reference: now)?.phase ?? .expired) != .expired
            case .lapsed:
                receipt.statuses(reference: now).allSatisfy { $0.phase == .expired }
            }
        }
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return byFilter }
        return byFilter.filter { receipt in
            receipt.merchant.localizedStandardContains(query)
                || receipt.category.title.localizedStandardContains(query)
                || receipt.note.localizedStandardContains(query)
        }
    }

    private var sections: [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { receipt in
            let parts = calendar.dateComponents([.year, .month], from: receipt.purchaseDate)
            return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        }
        return grouped.keys.sorted(by: >).map { key in
            MonthSection(
                id: key,
                title: Self.monthTitle(for: key),
                receipts: grouped[key]?.sorted { $0.purchaseDate > $1.purchaseDate } ?? []
            )
        }
    }

    private static func monthTitle(for key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return key }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return key }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

private struct MonthSection: Identifiable {
    let id: String
    let title: String
    let receipts: [Receipt]
}

private struct LibraryRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 13) {
            CategoryMark(category: receipt.category, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.merchant)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KeptTheme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(KeptTheme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(receipt.money)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(KeptTheme.ink)
                trailingBadge
            }
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        let day = KeptFormat.dayMonth.string(from: receipt.purchaseDate)
        if receipt.status == .returned { return "Returned · bought \(day)" }
        if receipt.status == .claimed { return "Claimed · bought \(day)" }
        return "\(receipt.category.title) · bought \(day)"
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if receipt.status != .active {
            Text(receipt.status == .returned ? "Returned" : "Claimed")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(KeptTheme.inkTertiary)
        } else if let status = receipt.headline() {
            PhaseChip(status: status)
        } else {
            Text("No deadline")
                .font(.system(size: 11))
                .foregroundStyle(KeptTheme.inkTertiary)
        }
    }
}
