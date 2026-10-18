import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Emailed receipts arrive as PDFs. Rasterise the first page so the same document reader sees it.
enum PDFRaster {
    static func firstPage(of url: URL, maxEdge: CGFloat = 2200) -> Data? {
        guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) else {
            return nil
        }
        return rasterize(page: page, maxEdge: maxEdge)
    }

    static func firstPage(of data: Data, maxEdge: CGFloat = 2200) -> Data? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: 1) else {
            return nil
        }
        return rasterize(page: page, maxEdge: maxEdge)
    }

    private static func rasterize(page: CGPDFPage, maxEdge: CGFloat) -> Data? {
        let box = page.getBoxRect(.mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }

        let scale = min(maxEdge / max(box.width, box.height), 3)
        let width = Int(box.width * scale)
        let height = Int(box.height * scale)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.concatenate(page.getDrawingTransform(.mediaBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)

        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
