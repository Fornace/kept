import SwiftUI
import SwiftData
import KeptKit

struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showPhoto = false
    @State private var confirmReturned = false
    @State private var confirmDelete = false

    private var now: Date { .now }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let data = receipt.imageData {
                    Button {
                        showPhoto = true
                    } label: {
                        ReceiptPhotoView(data: data, maxHeight: 300)
                    }
                    .buttonStyle(.plain)
                }

                header

                HStack(spacing: 12) {
                    DeadlineTile(kind: .returns, status: receipt.returnStatus(reference: now), purchased: receipt.purchaseDate)
                    DeadlineTile(kind: .warranty, status: receipt.warrantyStatus(reference: now), purchased: receipt.purchaseDate)
                }

                if !receipt.items.isEmpty { itemsCard }
                if !receipt.note.isEmpty { noteCard }
                actionsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 44)
        }
        .background(KeptTheme.paper)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle(receipt.merchant)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit receipt", systemImage: "square.and.pencil") { app.edit(receipt) }
                    if receipt.status != .active {
                        Button("Mark as kept again", systemImage: "arrow.uturn.backward") {
                            ReceiptStore.shared.setStatus(receipt, .active)
                        }
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showPhoto) {
            PhotoSheet(data: receipt.imageData, title: receipt.merchant)
        }
        .confirmationDialog("Mark this as returned?", isPresented: $confirmReturned, titleVisibility: .visible) {
            Button("Returned", role: .destructive) { ReceiptStore.shared.setStatus(receipt, .returned) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(receipt.merchant) leaves the return countdown. The receipt and its warranty stay.")
        }
        .confirmationDialog("Delete this receipt?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                ReceiptStore.shared.delete(receipt)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The photo and every deadline for \(receipt.merchant) are removed from this device.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                Text(receipt.merchant)
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(KeptTheme.ink)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if receipt.status != .active {
                    Text(receipt.status == .returned ? "Returned" : "Claimed")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(KeptTheme.raised, in: Capsule())
                        .foregroundStyle(KeptTheme.inkSecondary)
                }
            }

            HStack(spacing: 8) {
                Text(receipt.money)
                    .font(.system(size: 17, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(KeptTheme.ink)
                Text("·")
                    .foregroundStyle(KeptTheme.inkTertiary)
                Text(receipt.category.title)
                    .font(.system(size: 13))
                    .foregroundStyle(KeptTheme.inkSecondary)
                Text("·")
                    .foregroundStyle(KeptTheme.inkTertiary)
                Text(purchaseLine)
                    .font(.system(size: 13))
                    .foregroundStyle(KeptTheme.inkSecondary)
            }
        }
    }

    private var purchaseLine: String {
        let day = receipt.purchaseDate.formatted(.dateTime.day().month(.wide).year())
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: receipt.purchaseDate),
            to: Calendar.current.startOfDay(for: now)
        ).day ?? 0
        if days <= 0 { return "bought today" }
        if days == 1 { return "bought yesterday" }
        if days < 45 { return "bought \(days) days ago" }
        return "bought \(day)"
    }

    // MARK: - Cards

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel("What was bought", trailing: "\(receipt.items.count)")
            ForEach(receipt.sortedItems) { item in
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.system(size: 14))
                        .foregroundStyle(KeptTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(KeptFormat.money(item.amountMinor, currency: receipt.currencyCode))
                        .font(.system(size: 14))
                        .monospacedDigit()
                        .foregroundStyle(KeptTheme.inkSecondary)
                }
            }
        }
        .paperCard(padding: 16)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel("Note")
            Text(receipt.note)
                .font(.system(size: 14))
                .foregroundStyle(KeptTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 16)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            if receipt.status == .active {
                ActionRow(title: "Mark as returned", icon: "arrow.uturn.backward") {
                    confirmReturned = true
                }
                if let warranty = receipt.warrantyStatus(reference: now), warranty.phase != .expired {
                    Hairline().padding(.leading, 34)
                    ActionRow(title: "Record a warranty claim", icon: "wrench.and.screwdriver") {
                        ReceiptStore.shared.setStatus(receipt, .claimed)
                    }
                }
                Hairline().padding(.leading, 34)
                ActionRow(title: "Add a year of warranty", icon: "calendar.badge.plus") {
                    ReceiptStore.shared.extendWarranty(receipt, byMonths: 12)
                }
            } else {
                ActionRow(title: "Keep it again", icon: "arrow.uturn.backward") {
                    ReceiptStore.shared.setStatus(receipt, .active)
                }
            }
            Hairline().padding(.leading, 34)
            ActionRow(title: "Edit details", icon: "square.and.pencil") {
                app.edit(receipt)
            }
            Hairline().padding(.leading, 34)
            ActionRow(title: "Delete receipt", icon: "trash", isDestructive: true) {
                confirmDelete = true
            }
        }
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).fill(KeptTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
    }
}

struct PhotoSheet: View {
    let data: Data?
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if let data {
                ScrollView([.horizontal, .vertical]) {
                    if let image = Photo.cgImage(from: data, maxEdge: 2600) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .padding(18)
                    }
                }
            } else {
                Spacer()
            }
        }
        .background(KeptTheme.paper)
    }
}
