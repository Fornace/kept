import SwiftUI
import KeptKit

// MARK: - Labels

struct SectionLabel: View {
    let text: String
    var trailing: String?

    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(KeptTheme.inkTertiary)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(KeptTheme.inkTertiary)
            }
        }
    }
}

// MARK: - Money

struct MoneyValue: View {
    let minorUnits: Int
    let currency: String
    var size: CGFloat = 40
    var compact = true

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .serif))
            .monospacedDigit()
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .foregroundStyle(KeptTheme.ink)
    }

    private var text: String {
        if compact && minorUnits % 100 == 0 {
            return KeptFormat.compactMoney(minorUnits, currency: currency)
        }
        return KeptFormat.money(minorUnits, currency: currency)
    }
}

// MARK: - Status

struct PhaseChip: View {
    let status: CoverageStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(status.countdown)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.13), in: Capsule())
        .foregroundStyle(tint)
    }

    private var tint: Color { KeptTheme.color(for: status.phase) }
}

struct CategoryMark: View {
    let category: ReceiptCategory
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(KeptTheme.tint(for: category).opacity(0.22))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: category.symbol)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundStyle(KeptTheme.tint(for: category))
            }
    }
}

// MARK: - Surfaces

struct PaperCard: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = KeptTheme.cardRadius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(KeptTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(KeptTheme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func paperCard(padding: CGFloat = 18, radius: CGFloat = KeptTheme.cardRadius) -> some View {
        modifier(PaperCard(padding: padding, radius: radius))
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(KeptTheme.hairline)
            .frame(height: 1)
    }
}

// MARK: - Deadline meter

/// How much of the window is already gone.
struct DeadlineMeter: View {
    let status: CoverageStatus
    let purchased: Date
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(KeptTheme.raised)
                Capsule()
                    .fill(KeptTheme.color(for: status.phase))
                    .frame(width: max(2, proxy.size.width * fraction))
            }
        }
        .frame(height: height)
    }

    private var fraction: CGFloat {
        let start = Calendar.current.startOfDay(for: purchased)
        let total = status.endsOn.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let elapsed = Date.now.timeIntervalSince(start)
        return min(1, max(0.02, elapsed / total))
    }
}

// MARK: - Rows

struct DeadlineRow: View {
    let title: String
    let subtitle: String
    let category: ReceiptCategory
    let status: CoverageStatus

    var body: some View {
        HStack(spacing: 14) {
            CategoryMark(category: category, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KeptTheme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(KeptTheme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            PhaseChip(status: status)
        }
        .contentShape(Rectangle())
    }
}
