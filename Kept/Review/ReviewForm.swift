import SwiftUI
import KeptKit

struct ReviewForm: View {
    @Bindable var scan: ScanController

    private let returnChoices: [Int?] = [nil, 7, 14, 30, 60, 90]
    private let warrantyChoices: [Int?] = [nil, 12, 24, 36, 60]
    private let currencies = ["EUR", "USD", "GBP", "CHF"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let data = scan.imageData {
                    ReceiptPhotoView(data: data)
                }

                engineLine

                VStack(spacing: 0) {
                    FieldRow(label: "Shop") {
                        TextField("Where you bought it", text: $scan.draft.merchant)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 16, weight: .medium))
                    }
                    Hairline()
                    FieldRow(label: "Date") {
                        DatePicker("", selection: $scan.draft.purchaseDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    Hairline()
                    FieldRow(label: "Total") {
                        HStack(spacing: 10) {
                            TextField("0", value: amountBinding, format: .currency(code: scan.draft.currencyCode))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .font(.system(size: 16, weight: .medium))
                            Menu(scan.draft.currencyCode) {
                                ForEach(currencies, id: \.self) { code in
                                    Button(code) { scan.draft.currencyCode = code }
                                }
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(KeptTheme.inkSecondary)
                        }
                    }
                }
                .paperCard(padding: 16)

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("What it is")
                    CategoryChips(selection: $scan.draft.category) { _ in
                        scan.draft.returnSource = .suggestion
                        scan.draft.warrantySource = .suggestion
                        scan.draft.applyCategoryDefaults()
                    }
                }
                .paperCard(padding: 16)

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Return window", trailing: "days")
                    chips(choices: returnChoices, selection: $scan.draft.returnDays, kind: .returns)
                    caption(for: scan.draft.returnSource, typical: typicalReturn)
                    Hairline().padding(.vertical, 4)
                    SectionLabel("Warranty", trailing: "months")
                    chips(choices: warrantyChoices, selection: $scan.draft.warrantyMonths, kind: .warranty)
                    caption(for: scan.draft.warrantySource, typical: typicalWarranty)
                }
                .paperCard(padding: 16)

                if !scan.draft.items.isEmpty {
                    itemsCard
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Note")
                    TextField("Serial number, who it is for, anything to remember", text: $scan.draft.note, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .lineLimit(2...5)
                }
                .paperCard(padding: 16)
            }
            .padding(18)
        }
    }

    private var amountBinding: Binding<Double> {
        Binding(
            get: { Double(scan.draft.amountMinor) / 100 },
            set: { scan.draft.amountMinor = Int(($0 * 100).rounded()) }
        )
    }

    private var typicalReturn: String {
        "typical for \(scan.draft.category.title.lowercased())"
    }

    private var typicalWarranty: String {
        "typical for \(scan.draft.category.title.lowercased())"
    }

    private var engineLine: some View {
        HStack(spacing: 7) {
            Image(systemName: scan.draft.engine == .languageModel ? "sparkles" : "doc.text.viewfinder")
                .font(.system(size: 11, weight: .semibold))
            Text(scan.engineCaption)
                .font(.system(size: 12))
            Spacer(minLength: 0)
        }
        .foregroundStyle(KeptTheme.inkTertiary)
        .padding(.horizontal, 2)
    }

    private func chips(choices: [Int?], selection: Binding<Int?>, kind: CoverageKind) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(choices, id: \.self) { choice in
                    ChoiceChip(
                        title: choice.map(String.init) ?? "None",
                        isSelected: selection.wrappedValue == choice
                    ) {
                        selection.wrappedValue = choice
                        setSource(choice == nil ? .empty : .chosen, for: kind)
                    }
                }
            }
        }
    }

    private func setSource(_ source: ValueSource, for kind: CoverageKind) {
        switch kind {
        case .returns: scan.draft.returnSource = source
        case .warranty: scan.draft.warrantySource = source
        }
    }

    private func caption(for source: ValueSource, typical: String) -> some View {
        Group {
            switch source {
            case .receipt:
                Text("Stated on the receipt.")
            case .suggestion:
                Text("Suggested, \(typical). Change it if the receipt says otherwise.")
            case .chosen:
                Text("Set by you.")
            case .empty:
                Text("Not tracked, so Kept will not remind you.")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(KeptTheme.inkTertiary)
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Line items", trailing: "\(scan.draft.items.count)")
            ForEach($scan.draft.items) { $item in
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.system(size: 14))
                        .foregroundStyle(KeptTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(KeptFormat.money(item.amountMinor, currency: scan.draft.currencyCode))
                        .font(.system(size: 14))
                        .monospacedDigit()
                        .foregroundStyle(KeptTheme.inkSecondary)
                    Button {
                        scan.draft.items.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(KeptTheme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let note = itemsMismatch {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(KeptTheme.urgent)
            }
        }
        .paperCard(padding: 16)
    }

    private var itemsMismatch: String? {
        let sum = scan.draft.items.reduce(0) { $0 + $1.amountMinor }
        guard scan.draft.amountMinor > 0, sum > 0 else { return nil }
        let delta = abs(sum - scan.draft.amountMinor)
        guard delta > max(100, scan.draft.amountMinor / 100) else { return nil }
        return "Items add to \(KeptFormat.money(sum, currency: scan.draft.currencyCode)), the total says \(KeptFormat.money(scan.draft.amountMinor, currency: scan.draft.currencyCode))."
    }
}

extension ScanController {
    var engineCaption: String {
        if isManual { return "Typed in by you." }
        switch draft.engine {
        case .languageModel: return "Read by Apple Intelligence on this device. Check it, then keep it."
        case .documentScan: return "Read by the on-device document scanner. Check it, then keep it."
        }
    }
}
