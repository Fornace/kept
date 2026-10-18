import SwiftUI
import SwiftData
import KeptKit

@MainActor
@Observable
final class AppModel {
    enum Tab: String, Hashable {
        case desk
        case library
        case settings

        var storageKey: String { rawValue }

        init?(storageKey: String) {
            guard let tab = Tab(rawValue: storageKey) else { return nil }
            self = tab
        }
    }

    private static let tabKey = "kept.tab"

    var tab: Tab {
        didSet { UserDefaults.standard.set(tab.storageKey, forKey: Self.tabKey) }
    }
    var scan: ScanController?
    var libraryFilter: LibraryFilter = .all
    var deskPath = NavigationPath()
    var libraryPath = NavigationPath()

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.tabKey)
        tab = Tab(storageKey: stored ?? "") ?? .desk
    }

    /// Handoff from the "Add a receipt" App Intent or a shared file.
    var pendingImport: Data?

    func startScan() {
        scan = ScanController()
    }

    /// File ▸ Import: open the sheet with the file picker already up.
    func importReceipt() {
        let controller = ScanController()
        controller.wantsFilePicker = true
        scan = controller
    }

    func startManualEntry() {
        scan = ScanController(manual: true)
    }

    func edit(_ receipt: Receipt) {
        scan = ScanController(editing: receipt)
    }

    func bootstrap() async {
        let store = ReceiptStore.shared
        store.publishSnapshot()
        await ReminderScheduler.shared.refresh(receipts: store.allReceipts(), settings: .shared)

        if let data = pendingImport {
            pendingImport = nil
            scan = ScanController()
            await scan?.ingest(data)
        }
    }

    func handleImport(_ data: Data) async {
        scan = ScanController()
        await scan?.ingest(data)
    }

    func handle(_ url: URL) {
        switch url.host() {
        case "library":
            tab = .library
        case "settings":
            tab = .settings
        case "receipt":
            guard let raw = url.pathComponents.dropFirst().first,
                  let id = UUID(uuidString: raw),
                  let receipt = ReceiptStore.shared.allReceipts().first(where: { $0.id == id }) else {
                tab = .desk
                return
            }
            tab = .desk
            deskPath.append(receipt)
        default:
            tab = .desk
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case returnable
    case covered
    case lapsed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .returnable: "Returnable"
        case .covered: "Under warranty"
        case .lapsed: "Lapsed"
        }
    }
}
