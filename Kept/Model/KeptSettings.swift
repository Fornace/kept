import Foundation
import Observation

@Observable
final class KeptSettings {
    static let shared = KeptSettings()

    private enum Key {
        static let remindersEnabled = "kept.reminders.enabled"
        static let returnLeadDays = "kept.reminders.returnLead"
        static let warrantyLeadDays = "kept.reminders.warrantyLead"
        static let notifyHour = "kept.reminders.hour"
    }

    private let defaults: UserDefaults

    var remindersEnabled: Bool {
        didSet { defaults.set(remindersEnabled, forKey: Key.remindersEnabled) }
    }

    /// Days before a return window closes that Kept speaks up.
    var returnLeadDays: Int {
        didSet { defaults.set(returnLeadDays, forKey: Key.returnLeadDays) }
    }

    /// Days before a warranty ends.
    var warrantyLeadDays: Int {
        didSet { defaults.set(warrantyLeadDays, forKey: Key.warrantyLeadDays) }
    }

    var notifyHour: Int {
        didSet { defaults.set(notifyHour, forKey: Key.notifyHour) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.remindersEnabled) == nil {
            defaults.set(true, forKey: Key.remindersEnabled)
        }
        if defaults.object(forKey: Key.returnLeadDays) == nil {
            defaults.set(3, forKey: Key.returnLeadDays)
        }
        if defaults.object(forKey: Key.warrantyLeadDays) == nil {
            defaults.set(30, forKey: Key.warrantyLeadDays)
        }
        if defaults.object(forKey: Key.notifyHour) == nil {
            defaults.set(9, forKey: Key.notifyHour)
        }
        remindersEnabled = defaults.bool(forKey: Key.remindersEnabled)
        returnLeadDays = defaults.integer(forKey: Key.returnLeadDays)
        warrantyLeadDays = defaults.integer(forKey: Key.warrantyLeadDays)
        notifyHour = defaults.integer(forKey: Key.notifyHour)
    }
}
