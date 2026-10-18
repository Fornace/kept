import SwiftUI
import KeptKit

/// One clock on the receipt: the return window or the warranty.
struct DeadlineTile: View {
    let kind: CoverageKind
    let status: CoverageStatus?
    let purchased: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(kind.title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
            }
            .foregroundStyle(KeptTheme.inkTertiary)

            if let status {
                Text(status.countdown)
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(KeptTheme.color(for: status.phase))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(caption(for: status))
                    .font(.system(size: 11))
                    .foregroundStyle(KeptTheme.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                DeadlineMeter(status: status, purchased: purchased)
                    .padding(.top, 2)
            } else {
                Text("Not tracked")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(KeptTheme.inkTertiary)
                Text(kind == .returns ? "No return window on this receipt." : "No warranty recorded.")
                    .font(.system(size: 11))
                    .foregroundStyle(KeptTheme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle()
                    .fill(KeptTheme.hairline)
                    .frame(height: 1)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 15, radius: 18)
    }

    private func caption(for status: CoverageStatus) -> String {
        let day = KeptFormat.dayMonth.string(from: status.endsOn)
        if status.phase == .expired {
            return kind == .returns ? "Closed \(day)" : "Ended \(day)"
        }
        return kind == .returns ? "Return by \(day)" : "Covered to \(day) \(Calendar.current.component(.year, from: status.endsOn))"
    }
}

/// A row that reads like a sentence and acts like a button.
struct ActionRow: View {
    let title: String
    let icon: String
    var isDestructive = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isDestructive ? KeptTheme.expired : KeptTheme.ink)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
