import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import KeptKit

struct ScanSheet: View {
    @Bindable var scan: ScanController
    @Environment(\.dismiss) private var dismiss

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(KeptTheme.paper)
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { toolbar }
        }
        .background(KeptTheme.paper.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 560, idealHeight: 700)
        #endif
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await scan.ingest(data)
                }
                photoItem = nil
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.image, .pdf]) { result in
            handleFile(result)
        }
        .onAppear {
            if scan.wantsFilePicker {
                scan.wantsFilePicker = false
                showFilePicker = true
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { data in
                showCamera = false
                Task { await scan.ingest(data) }
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        #endif
    }

    private var title: String {
        switch scan.phase {
        case .choose: "Add a receipt"
        case .reading: "Reading"
        case .review: scan.editingReceiptID == nil ? "Check the receipt" : "Edit receipt"
        case .failed: "Not readable"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch scan.phase {
        case .choose:
            SourceChooser(
                canUseCamera: cameraAvailable,
                onCamera: { showCamera = true },
                onPhotos: { showPhotoPicker = true },
                onFiles: { showFilePicker = true },
                onManual: { manual() }
            )
        case .reading:
            ReadingReceiptView()
        case .review:
            ReviewForm(scan: scan)
        case .failed(let message):
            ScanFailureView(message: message) {
                scan.retry()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(scan.phase == .review ? "Back" : "Cancel") {
                if scan.phase == .review, scan.editingReceiptID == nil, scan.isManual == false {
                    scan.retry()
                } else {
                    dismiss()
                }
            }
        }
        if scan.phase == .review {
            ToolbarItem(placement: .confirmationAction) {
                Button("Keep") { save() }
                    .fontWeight(.semibold)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!scan.draft.isPlausible)
            }
        }
    }

    private func manual() {
        scan.isManual = true
        scan.draft.applyCategoryDefaults()
        scan.phase = .review
    }

    private func save() {
        let store = ReceiptStore.shared
        if let id = scan.editingReceiptID,
           let receipt = store.allReceipts().first(where: { $0.id == id }) {
            store.update(receipt, with: scan.draft, imageData: scan.imageData)
        } else {
            store.add(scan.draft, imageData: scan.imageData)
        }
        Task { await authorizeRemindersIfNeeded() }
        dismiss()
    }

    private func authorizeRemindersIfNeeded() async {
        guard KeptSettings.shared.remindersEnabled else { return }
        guard await ReminderScheduler.shared.authorizationStatus() == .notDetermined else { return }
        _ = await ReminderScheduler.shared.requestAuthorization()
        await ReminderScheduler.shared.refresh(receipts: ReceiptStore.shared.allReceipts(), settings: .shared)
    }

    private func handleFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data: Data?
        if url.pathExtension.lowercased() == "pdf" {
            data = PDFRaster.firstPage(of: url)
        } else {
            data = try? Data(contentsOf: url)
        }
        guard let data else { return }
        Task { await scan.ingest(data) }
    }

    private var cameraAvailable: Bool {
        #if os(iOS)
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #else
        false
        #endif
    }
}

// MARK: - Source chooser

private struct SourceChooser: View {
    let canUseCamera: Bool
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onFiles: () -> Void
    let onManual: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Point at the paper.")
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(KeptTheme.ink)
                    Text("Kept reads the shop, the date and the total on this device, then counts down the return window and the warranty for you.")
                        .font(.system(size: 14))
                        .foregroundStyle(KeptTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

                if canUseCamera {
                    SourceButton(
                        icon: "camera",
                        title: "Take a photo",
                        detail: "Straight on, whole receipt in frame",
                        action: onCamera
                    )
                }
                SourceButton(
                    icon: "photo.on.rectangle",
                    title: "Choose a photo",
                    detail: "From the photo library",
                    action: onPhotos
                )
                SourceButton(
                    icon: "doc.text",
                    title: "Choose a file",
                    detail: "A PDF or an image from Mail or Files",
                    action: onFiles
                )
                SourceButton(
                    icon: "keyboard",
                    title: "Type it in",
                    detail: "For when there is no paper left",
                    action: onManual
                )
            }
            .padding(22)
        }
    }
}

private struct SourceButton: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(KeptTheme.signal)
                    .frame(width: 42, height: 42)
                    .background(KeptTheme.signal.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(KeptTheme.ink)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(KeptTheme.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KeptTheme.inkTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(KeptTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reading and failure

private struct ReadingReceiptView: View {
    @State private var phase = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(KeptTheme.surface)
                    .frame(width: 132, height: 172)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
                VStack(spacing: 7) {
                    ForEach(0..<6, id: \.self) { index in
                        Capsule()
                            .fill(index == phase % 6 ? KeptTheme.signal : KeptTheme.raised)
                            .frame(width: index % 2 == 0 ? 72 : 52, height: 5)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: phase)

            VStack(spacing: 6) {
                Text("Reading the receipt")
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(KeptTheme.ink)
                Text(ModelExtractor.isAvailable
                     ? "Apple Intelligence is reading it on this device."
                     : "The document scanner is reading it on this device.")
                    .font(.system(size: 13))
                    .foregroundStyle(KeptTheme.inkSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                phase += 1
            }
        }
    }
}

private struct ScanFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(KeptTheme.inkTertiary)
            Text(message)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(KeptTheme.inkSecondary)
                .frame(maxWidth: 320)
            Button("Try another photo", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(KeptTheme.signal)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
