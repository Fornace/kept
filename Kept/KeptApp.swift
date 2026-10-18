import SwiftUI
import SwiftData
import KeptKit

@main
struct KeptApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        #if os(macOS)
        macWindow
        Settings {
            SettingsView()
                .modelContainer(KeptStorage.container)
        }
        #else
        phoneWindow
        #endif
    }

    private var root: some View {
        RootView()
            .environment(app)
            .modelContainer(KeptStorage.container)
            .task { await app.bootstrap() }
            .onOpenURL { app.handle($0) }
            .onReceive(NotificationCenter.default.publisher(for: .keptImportRequest)) { note in
                guard let data = note.object as? Data else { return }
                Task { await app.handleImport(data) }
            }
    }

    #if os(macOS)
    private var macWindow: some Scene {
        WindowGroup { root }
            .defaultSize(width: 1120, height: 780)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Scan a Receipt") { app.startScan() }
                        .keyboardShortcut("n", modifiers: .command)
                    Button("Add Manually") { app.startManualEntry() }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                    Button("Import a Receipt…") { app.importReceipt() }
                        .keyboardShortcut("i", modifiers: .command)
                }
                CommandMenu("Kept") {
                    Button("Desk") { app.tab = .desk }
                        .keyboardShortcut("1", modifiers: .command)
                    Button("Library") { app.tab = .library }
                        .keyboardShortcut("2", modifiers: .command)
                }
            }
    }
    #else
    private var phoneWindow: some Scene {
        WindowGroup { root }
    }
    #endif
}

extension Notification.Name {
    /// Posted by the "Add a receipt" App Intent with the shared image as the object.
    static let keptImportRequest = Notification.Name("kept.import.request")
}

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        #if os(iOS)
        TabView(selection: $app.tab) {
            Tab("Desk", systemImage: "tray.full", value: AppModel.Tab.desk) {
                NavigationStack(path: $app.deskPath) { DeskView() }
            }
            Tab("Library", systemImage: "book.closed", value: AppModel.Tab.library) {
                NavigationStack(path: $app.libraryPath) { LibraryView() }
            }
            Tab("Settings", systemImage: "gearshape", value: AppModel.Tab.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tint(KeptTheme.signal)
        .sheet(item: $app.scan) { scan in
            ScanSheet(scan: scan)
        }
        #else
        NavigationSplitView {
            List(selection: $app.tab) {
                Label("Desk", systemImage: "tray.full").tag(AppModel.Tab.desk)
                Label("Library", systemImage: "book.closed").tag(AppModel.Tab.library)
                Label("Settings", systemImage: "gearshape").tag(AppModel.Tab.settings)
            }
            .navigationSplitViewColumnWidth(min: 186, ideal: 204, max: 240)
        } detail: {
            switch app.tab {
            case .desk:
                NavigationStack(path: $app.deskPath) { DeskView() }
            case .library:
                NavigationStack(path: $app.libraryPath) { LibraryView() }
            case .settings:
                NavigationStack { SettingsView() }
            }
        }
        .sheet(item: $app.scan) { scan in
            ScanSheet(scan: scan)
        }
        #endif
    }
}
