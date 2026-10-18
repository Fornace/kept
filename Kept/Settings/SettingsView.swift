import SwiftUI
import SwiftData
import UserNotifications
import KeptKit

struct SettingsView: View {
    @State private var settings = KeptSettings.shared
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmDeleteAll = false

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                remindersCard(settings: settings)
                onDeviceCard
                dataCard
                aboutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .background(KeptTheme.paper)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(KeptTheme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .navigationTitle("Settings")
        .task { await refreshStatus() }
        .confirmationDialog("Delete every receipt?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                ReceiptStore.shared.deleteEverything()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Photos, deadlines and notes go with them. This cannot be undone.")
        }
    }

    // MARK: - Reminders

    private func remindersCard(settings: KeptSettings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Reminders", trailing: authStatus == .denied ? "Off in Settings" : nil)

            Toggle(isOn: Binding(
                get: { settings.remindersEnabled },
                set: { newValue in
                    settings.remindersEnabled = newValue
                    Task { await enableReminders(newValue) }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Warn me before a deadline")
                        .font(.system(size: 15, weight: .medium))
                    Text("One notification per window, in the morning.")
                        .font(.system(size: 12))
                        .foregroundStyle(KeptTheme.inkSecondary)
                }
            }
            .tint(KeptTheme.signal)

            if settings.remindersEnabled {
                Hairline()
                stepperRow(
                    title: "Days before a return closes",
                    value: settings.returnLeadDays,
                    range: 1...14
                ) { settings.returnLeadDays = $0 }
                Hairline()
                stepperRow(
                    title: "Days before a warranty ends",
                    value: settings.warrantyLeadDays,
                    range: 7...90,
                    step: 7
                ) { settings.warrantyLeadDays = $0 }
                Hairline()
                HStack {
                    Text("Time of day")
                        .font(.system(size: 14))
                    Spacer()
                    Picker("Time of day", selection: Binding(
                        get: { settings.notifyHour },
                        set: { settings.notifyHour = $0; reschedule() }
                    )) {
                        ForEach(6..<21, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if authStatus == .denied {
                    Text("Notifications are off for Kept in system settings.")
                        .font(.system(size: 12))
                        .foregroundStyle(KeptTheme.urgent)
                }
            }
        }
        .paperCard(padding: 16)
    }

    private func stepperRow(title: String, value: Int, range: ClosedRange<Int>, step: Int = 1, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(KeptTheme.ink)
            Spacer()
            Text("\(value)")
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(KeptTheme.inkSecondary)
                .frame(minWidth: 26, alignment: .trailing)
            Stepper("", value: Binding(get: { value }, set: { set($0); reschedule() }), in: range, step: step)
                .labelsHidden()
        }
    }

    // MARK: - On device

    private var onDeviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("On this device")
            row(icon: "doc.text.viewfinder", title: "Document scanner", detail: "Apple Vision reads every line printed on the receipt.")
            Hairline()
            row(
                icon: "sparkles",
                title: "Apple Intelligence",
                detail: ModelExtractor.isAvailable
                    ? "Reading merchant, date, total and the terms printed on the receipt."
                    : (ModelExtractor.unavailableExplanation ?? "Not available.")
            )
            Hairline()
            row(icon: "lock", title: "No account, no upload", detail: "Receipts, photos and deadlines never leave this device.")
        }
        .paperCard(padding: 16)
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(KeptTheme.signal)
                .frame(width: 26, height: 26)
                .background(KeptTheme.signal.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(KeptTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Data

    private var dataCard: some View {
        VStack(spacing: 0) {
            ActionRow(title: "Delete every receipt", icon: "trash", isDestructive: true) {
                confirmDeleteAll = true
            }
        }
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).fill(KeptTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: KeptTheme.cardRadius, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Kept")
                .font(.system(size: 15, weight: .semibold, design: .serif))
            Text("Version \(version) · Fornace s.r.l.")
                .font(.system(size: 12))
                .foregroundStyle(KeptTheme.inkSecondary)
            Text("Keep the receipt, keep the deadline.")
                .font(.system(size: 12))
                .foregroundStyle(KeptTheme.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var version: String {
        let bundle = Bundle.main
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: - Actions

    private func refreshStatus() async {
        authStatus = await ReminderScheduler.shared.authorizationStatus()
    }

    private func enableReminders(_ enabled: Bool) async {
        if enabled {
            if await ReminderScheduler.shared.authorizationStatus() == .notDetermined {
                _ = await ReminderScheduler.shared.requestAuthorization()
            }
            await refreshStatus()
        }
        reschedule()
    }

    private func reschedule() {
        Task {
            await ReminderScheduler.shared.refresh(receipts: ReceiptStore.shared.allReceipts(), settings: .shared)
        }
    }
}
