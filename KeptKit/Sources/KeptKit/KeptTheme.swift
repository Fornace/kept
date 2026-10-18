import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
/// Flat, printed-paper palette. No gradients anywhere, in line with house style.
public enum KeptTheme {
    public static let paper = dynamic(light: 0xF5F2EA, dark: 0x14130F)
    public static let surface = dynamic(light: 0xFFFDF7, dark: 0x1D1B16)
    public static let raised = dynamic(light: 0xEBE6DA, dark: 0x272420)
    public static let ink = dynamic(light: 0x191712, dark: 0xF3EFE4)
    public static let inkSecondary = dynamic(light: 0x6C6659, dark: 0xA39C8C)
    public static let inkTertiary = dynamic(light: 0x9A9384, dark: 0x76705F)
    public static let hairline = dynamic(light: 0xDDD6C6, dark: 0x312D26)

    public static let signal = dynamic(light: 0x1E5B4C, dark: 0x74BFA6)
    public static let urgent = dynamic(light: 0xA35A0B, dark: 0xE0A052)
    public static let expired = dynamic(light: 0x8E3626, dark: 0xD88373)

    public static func tint(for category: ReceiptCategory) -> Color {
        switch category {
        case .electronics: dynamic(light: 0x2F4858, dark: 0x8FB0C4)
        case .appliances: dynamic(light: 0x584737, dark: 0xC0A488)
        case .clothing: dynamic(light: 0x5E4551, dark: 0xC69AAC)
        case .home: dynamic(light: 0x5A5540, dark: 0xC0B790)
        case .health: dynamic(light: 0x3E5E52, dark: 0x92C4B1)
        case .travel: dynamic(light: 0x414A63, dark: 0x9FAAC9)
        case .food: dynamic(light: 0x6B5327, dark: 0xD2B273)
        case .other: dynamic(light: 0x55514A, dark: 0xB3ADA1)
        }
    }

    public static func color(for phase: CoveragePhase) -> Color {
        switch phase {
        case .open: signal
        case .urgent: urgent
        case .expired: expired
        }
    }

    public static let cornerRadius: CGFloat = 14
    public static let cardRadius: CGFloat = 20

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            UIColor(keptHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(keptHex: isDark ? dark : light)
        })
        #else
        return Color(red: 0, green: 0, blue: 0)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(keptHex value: UInt32) {
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(keptHex value: UInt32) {
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
#endif
