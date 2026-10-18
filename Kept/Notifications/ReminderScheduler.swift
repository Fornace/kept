import Foundation
import UserNotifications
import KeptKit

/// Schedules one notification per deadline, with the lead time the person chose.
/// Every schedule is rebuilt from the current store, so a change never leaves a stale reminder.
@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    private let center = UNUserNotificationCenter.current()
    private let prefix = "kept."

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func refresh(receipts: [Receipt], settings: KeptSettings, now: Date = .now) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard settings.remindersEnabled else { return }
        guard await authorizationStatus() == .authorized else { return }

        for receipt in receipts where receipt.status == .active {
            for request in requests(for: receipt, settings: settings, now: now) {
                try? await center.add(request)
            }
        }
    }

    private func requests(for receipt: Receipt, settings: KeptSettings, now: Date) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        if let returns = receipt.returnStatus(reference: now), returns.phase != .expired {
            let leadDate = Calendar.current.date(byAdding: .day, value: -settings.returnLeadDays, to: returns.endsOn) ?? returns.endsOn
            if let fire = fireDate(on: leadDate, hour: settings.notifyHour, now: now) {
                requests.append(request(
                    id: "\(prefix)\(receipt.id.uuidString).returns.lead",
                    title: "\(receipt.merchant): \(relativeDays(leadDate, from: now)) left to return",
                    body: "Return window closes \(KeptFormat.dayMonth.string(from: returns.endsOn)). \(receipt.money).",
                    date: fire
                ))
            }
            if let fire = fireDate(on: returns.endsOn, hour: settings.notifyHour, now: now) {
                requests.append(request(
                    id: "\(prefix)\(receipt.id.uuidString).returns.last",
                    title: "Last day to return from \(receipt.merchant)",
                    body: "The return window closes today. \(receipt.money).",
                    date: fire
                ))
            }
        }

        if let warranty = receipt.warrantyStatus(reference: now), warranty.phase != .expired {
            let leadDate = Calendar.current.date(byAdding: .day, value: -settings.warrantyLeadDays, to: warranty.endsOn) ?? warranty.endsOn
            if let fire = fireDate(on: leadDate, hour: settings.notifyHour, now: now) {
                requests.append(request(
                    id: "\(prefix)\(receipt.id.uuidString).warranty.lead",
                    title: "\(receipt.merchant) warranty ends \(KeptFormat.dayMonth.string(from: warranty.endsOn))",
                    body: "\(relativeDays(warranty.endsOn, from: now)) of cover left. Report a fault before it lapses.",
                    date: fire
                ))
            }
            if let fire = fireDate(on: warranty.endsOn, hour: settings.notifyHour, now: now) {
                requests.append(request(
                    id: "\(prefix)\(receipt.id.uuidString).warranty.end",
                    title: "\(receipt.merchant) warranty ends today",
                    body: "After today the repair is on you.",
                    date: fire
                ))
            }
        }

        return requests
    }

    private func request(id: String, title: String, body: String, date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "kept.deadlines"

        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.hour = Calendar.current.component(.hour, from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private func fireDate(on day: Date, hour: Int, now: Date) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components), date > now else { return nil }
        return date
    }

    private func relativeDays(_ date: Date, from now: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        if days <= 0 { return "No days" }
        return days == 1 ? "1 day" : "\(days) days"
    }
}
