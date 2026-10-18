import Foundation

/// What the widget needs to know, written by the app after every change and read by the widget.
///
/// The store itself stays private to the app; only the handful of deadlines that the widget
/// renders ever leave it, and only into the shared container on the same device.
public struct KeptSnapshot: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Identifiable, Equatable {
        public var id: UUID
        public var merchant: String
        public var category: ReceiptCategory
        public var kind: CoverageKind
        public var endsOn: Date
        public var amountMinor: Int
        public var currency: String

        public init(
            id: UUID,
            merchant: String,
            category: ReceiptCategory,
            kind: CoverageKind,
            endsOn: Date,
            amountMinor: Int,
            currency: String
        ) {
            self.id = id
            self.merchant = merchant
            self.category = category
            self.kind = kind
            self.endsOn = endsOn
            self.amountMinor = amountMinor
            self.currency = currency
        }

        public func status(reference: Date, calendar: Calendar = .current) -> CoverageStatus {
            CoverageStatus(kind: kind, endsOn: endsOn, reference: reference, calendar: calendar)
        }
    }

    public var entries: [Entry]
    public var returnableMinor: Int
    public var warrantyMinor: Int
    public var currency: String
    public var updatedAt: Date

    public init(
        entries: [Entry] = [],
        returnableMinor: Int = 0,
        warrantyMinor: Int = 0,
        currency: String = Locale.current.currency?.identifier ?? "EUR",
        updatedAt: Date = .now
    ) {
        self.entries = entries
        self.returnableMinor = returnableMinor
        self.warrantyMinor = warrantyMinor
        self.currency = currency
        self.updatedAt = updatedAt
    }

    public static let empty = KeptSnapshot()

    public var isEmpty: Bool { entries.isEmpty }

    /// Still-open deadlines first, nearest first.
    public func upcoming(reference: Date = .now) -> [Entry] {
        entries
            .filter { $0.endsOn >= Calendar.current.startOfDay(for: reference) }
            .sorted { $0.endsOn < $1.endsOn }
    }
}

/// The one place that knows where the shared container lives.
public enum StoreLocation {
    public static let appGroupID = "group.it.fornace.kept"

    /// The App Group container when this build can actually write to it, the app's own
    /// support directory when it cannot (unsigned local builds, unprovisioned Mac App IDs).
    public static var directory: URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
           canWrite(in: group) {
            return group
        }
        return URL.applicationSupportDirectory.appending(path: "Kept", directoryHint: .isDirectory)
    }

    /// Presence of a container URL proves nothing about the entitlement, so ask the file system.
    private static func canWrite(in url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let probe = url.appending(path: ".kept-write-probe")
            try Data().write(to: probe)
            try FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    public static func ensureDirectory() throws -> URL {
        let url = directory
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

public enum SnapshotStore {
    public static let fileName = "kept-snapshot.json"

    public static var url: URL { StoreLocation.directory.appending(path: fileName) }

    public static func read() -> KeptSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(KeptSnapshot.self, from: data)
    }

    public static func write(_ snapshot: KeptSnapshot) throws {
        _ = try StoreLocation.ensureDirectory()
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
