import Foundation
import Vision
import CoreGraphics
import ImageIO
import os

/// What the document reader pulled off the paper before any interpretation.
struct ScannedDocument: Sendable {
    /// Reading-order text as Vision laid it out.
    var text: String
    /// Tables the reader found, when it reports them.
    var tables: [[[String]]]
    var barcodes: [String]

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 }

    /// The text handed to a language model, capped so a photographed novel cannot blow the context.
    var promptText: String {
        var body = text
        if !barcodes.isEmpty {
            body += "\n\nBarcodes: " + barcodes.prefix(4).joined(separator: ", ")
        }
        if body.count > 3000 {
            body = String(body.prefix(3000))
        }
        return body
    }

    /// Flattened lines, useful for anchor searches.
    var lines: [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

enum ScanError: LocalizedError {
    case notAnImage
    case noTextFound
    case readerDidNotAnswer

    var errorDescription: String? {
        switch self {
        case .notAnImage: "That file is not an image Kept can read."
        case .noTextFound: "No readable text on this receipt. Try a straighter, brighter photo."
        case .readerDidNotAnswer: "The document reader did not answer. Try again, or type the receipt in."
        }
    }
}

enum ReceiptReader {
    private static let log = Logger(subsystem: "it.fornace.kept", category: "reader")

    /// Vision's text recognizer at the level this platform can serve. The accurate model is
    /// the better read on iOS; macOS serves accurate only when its assets are installed, and
    /// the fast model already reads a 2000 pixel receipt cleanly.
    private static var level: VNRequestTextRecognitionLevel {
        #if os(iOS)
        .accurate
        #else
        .fast
        #endif
    }

    static func read(imageData: Data) async throws -> ScannedDocument {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScanError.notAnImage
        }

        let orientation = source.orientation
        let recognitionLevel = level
        let started = Date()

        let lines: [String] = try await withDeadline(seconds: 15) {
            try await Task.detached(priority: .userInitiated) {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = recognitionLevel
                // Language correction pulls the linguistic-data asset set, which stalls the
                // recognizer on machines without it. The printed text needs no spell fixing.
                request.usesLanguageCorrection = false
                request.revision = VNRecognizeTextRequestRevision2

                let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
                try handler.perform([request])

                return (request.results ?? []).compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
            }.value
        }

        let document = ScannedDocument(
            text: lines.joined(separator: "\n"),
            tables: [],
            barcodes: []
        )
        log.debug("read \(lines.count) lines in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")
        guard !document.isEmpty else { throw ScanError.noTextFound }
        return document
    }
}

enum ReaderDeadlineError: Error {
    case expired
}

/// A reader that never answers must not hold the scanner hostage.
func withDeadline<T: Sendable>(
    seconds: Double,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw ReaderDeadlineError.expired
        }
        guard let first = try await group.next() else { throw ReaderDeadlineError.expired }
        group.cancelAll()
        return first
    }
}

extension CGImageSource {
    /// Orientation with the EXIF tag honoured, as Vision expects it.
    var orientation: CGImagePropertyOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(self, 0, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw) else {
            return .up
        }
        return orientation
    }
}
