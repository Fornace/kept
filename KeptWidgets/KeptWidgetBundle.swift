import WidgetKit
import SwiftUI
import KeptKit

struct KeptEntry: TimelineEntry {
    let date: Date
    let snapshot: KeptSnapshot
}

struct KeptProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeptEntry {
        KeptEntry(date: .now, snapshot: Self.preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (KeptEntry) -> Void) {
        completion(KeptEntry(date: .now, snapshot: SnapshotStore.read() ?? Self.preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeptEntry>) -> Void) {
        let snapshot = SnapshotStore.read() ?? .empty
        let entry = KeptEntry(date: .now, snapshot: snapshot)
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextHour)))
    }

    static let preview = KeptSnapshot(
        entries: [
            .init(id: UUID(), merchant: "Bose", category: .electronics, kind: .returns, endsOn: .now.addingTimeInterval(86_400 * 2), amountMinor: 27900, currency: "EUR"),
            .init(id: UUID(), merchant: "Muji", category: .home, kind: .returns, endsOn: .now.addingTimeInterval(86_400 * 9), amountMinor: 8400, currency: "EUR")
        ],
        returnableMinor: 36300,
        warrantyMinor: 27900,
        currency: "EUR"
    )
}

struct KeptWidgetView: View {
    var entry: KeptEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                KeptTheme.paper
            }
            .widgetURL(URL(string: "kept://library"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        default:
            small
        }
    }

    // MARK: - Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 9, weight: .semibold))
                Text("RETURNING")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.1)
            }
            .foregroundStyle(KeptTheme.inkTertiary)

            Spacer(minLength: 4)

            if let next = entry.snapshot.upcoming().first {
                Text(next.merchant)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KeptTheme.ink)
                    .lineLimit(2)
                Spacer(minLength: 2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(daysLabel(for: next))
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .monospacedDigit()
                    Text("days")
                        .font(.system(size: 11))
                        .foregroundStyle(KeptTheme.inkSecondary)
                }
                .foregroundStyle(KeptTheme.color(for: next.status(reference: entry.date).phase))
                Text(next.kind == .returns ? "left to return" : "of warranty")
                    .font(.system(size: 10))
                    .foregroundStyle(KeptTheme.inkTertiary)
            } else {
                Text("Nothing to return")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KeptTheme.ink)
                Spacer(minLength: 2)
                Text("Add a receipt")
                    .font(.system(size: 10))
                    .foregroundStyle(KeptTheme.inkTertiary)
            }

            Spacer(minLength: 0)
            if entry.snapshot.entries.count > 1 {
                Text("+\(entry.snapshot.entries.count - 1) more")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(KeptTheme.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("RETURNABLE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(KeptTheme.inkTertiary)
                Text(KeptFormat.compactMoney(entry.snapshot.returnableMinor, currency: entry.snapshot.currency))
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(KeptTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(countLine)
                    .font(.system(size: 10))
                    .foregroundStyle(KeptTheme.inkSecondary)
                Spacer(minLength: 0)
                Text("Kept")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(KeptTheme.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(KeptTheme.hairline)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(entry.snapshot.upcoming().prefix(3)) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.category.symbol)
                            .font(.system(size: 9))
                            .foregroundStyle(KeptTheme.tint(for: item.category))
                            .frame(width: 13)
                        Text(item.merchant)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(KeptTheme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(daysLabel(for: item))
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(KeptTheme.color(for: item.status(reference: entry.date).phase))
                    }
                }
                if entry.snapshot.upcoming().isEmpty {
                    Text("No open windows. Add a receipt in Kept.")
                        .font(.system(size: 10))
                        .foregroundStyle(KeptTheme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Lock screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Kept")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
            if let next = entry.snapshot.upcoming().first {
                Text("\(next.merchant), \(daysLabel(for: next)) days")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(next.kind == .returns ? "left to return" : "of warranty left")
                    .font(.system(size: 11))
            } else {
                Text("Nothing closing")
                    .font(.system(size: 13, weight: .medium))
            }
        }
    }

    private var circular: some View {
        VStack(spacing: 0) {
            if let next = entry.snapshot.upcoming().first {
                Text(daysLabel(for: next))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                Text("days")
                    .font(.system(size: 8))
            } else {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16))
            }
        }
    }

    private var inlineText: String {
        guard let next = entry.snapshot.upcoming().first else { return "Kept: nothing closing" }
        return "Kept: \(next.merchant) \(daysLabel(for: next)) days"
    }

    // MARK: - Helpers

    private func daysLabel(for entry: KeptSnapshot.Entry) -> String {
        let status = entry.status(reference: self.entry.date)
        if status.daysLeft < 0 { return "0" }
        return "\(status.daysLeft)"
    }

    private var countLine: String {
        let count = entry.snapshot.upcoming().count
        if count == 0 { return "nothing open" }
        return count == 1 ? "1 receipt open" : "\(count) receipts open"
    }
}

struct KeptWidget: Widget {
    let kind = "KeptDeadlines"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeptProvider()) { entry in
            KeptWidgetView(entry: entry)
        }
        .configurationDisplayName("Deadlines")
        .description("Return windows and warranties, counted down.")
        .supportedFamilies(families)
    }

    private var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }
}

@main
struct KeptWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeptWidget()
    }
}
