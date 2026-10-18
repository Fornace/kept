import SwiftUI
import KeptKit
import CoreGraphics

enum Photo {
    static func cgImage(from data: Data, maxEdge: CGFloat = 1600) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// The photographed paper, shown as paper: no chrome, no crop, honest aspect.
struct ReceiptPhotoView: View {
    let data: Data
    var maxHeight: CGFloat = 280
    var cornerRadius: CGFloat = 16

    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(KeptTheme.raised)
                    .frame(height: maxHeight * 0.6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(KeptTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(KeptTheme.hairline, lineWidth: 1))
        .task(id: data.count) {
            image = Photo.cgImage(from: data)
        }
    }
}

// MARK: - Form pieces

struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KeptTheme.inkSecondary)
                .frame(width: 62, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }
}

struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isSelected ? KeptTheme.surface : KeptTheme.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? KeptTheme.ink : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.clear : KeptTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CategoryChips: View {
    @Binding var selection: ReceiptCategory
    var onChange: (ReceiptCategory) -> Void = { _ in }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(ReceiptCategory.allCases) { category in
                Button {
                    selection = category
                    onChange(category)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: category.symbol)
                            .font(.system(size: 12, weight: .medium))
                        Text(category.title)
                            .font(.system(size: 13, weight: selection == category ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == category ? KeptTheme.surface : KeptTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selection == category ? KeptTheme.tint(for: category) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selection == category ? Color.clear : KeptTheme.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
