import Foundation

public enum Accent: String, Codable, CaseIterable {
    case maroon, gold, blue, green, purple, orange

    public var displayName: String { rawValue.capitalized }

    /// Fill colour for buttons / headers (hex RRGGBB) in the light or dark theme.
    public func hex(dark: Bool) -> String {
        switch (self, dark) {
        case (.maroon, false): return "7B1E3A"   // brand
        case (.maroon, true): return "A63B5F"
        case (.gold, _): return "F7B500"         // brand
        case (.blue, false): return "1565C0"
        case (.blue, true): return "2F6FC4"
        case (.green, false): return "2E7D32"
        case (.green, true): return "2E8B3A"
        case (.purple, false): return "6A1B9A"
        case (.purple, true): return "8E47BF"
        case (.orange, false): return "E65100"
        case (.orange, true): return "E8761F"
        }
    }

    /// Readable text colour on top of the accent fill: black or white, whichever contrasts more.
    public func onAccentHex(dark: Bool) -> String {
        let fill = hex(dark: dark)
        return Contrast.ratio(fill, "FFFFFF") >= Contrast.ratio(fill, "000000") ? "FFFFFF" : "000000"
    }
}

extension Accent {
    /// Accent used for *text, icons and thin highlights* on the page background: the fill colour, shifted
    /// towards black (light theme) or white (dark theme) until it reaches a 4.5:1 contrast on both background and surface.
    public func inkHex(dark: Bool) -> String {
        let p = Palette.of(dark: dark)
        var hex = self.hex(dark: dark)
        var step = 0
        while step < 20 && (Contrast.ratio(hex, p.background) < 4.5 || Contrast.ratio(hex, p.surface) < 4.5) {
            hex = Contrast.mix(hex, dark ? "FFFFFF" : "000000", 0.08)
            step += 1
        }
        return hex
    }
}

public struct Palette: Equatable {
    public let background: String
    public let surface: String
    public let text: String
    public let secondaryText: String

    public static let light = Palette(background: "F6F2F3", surface: "FFFFFF", text: "1C1B1F", secondaryText: "5C5A60")
    public static let dark = Palette(background: "121013", surface: "1F1C21", text: "F2EEF0", secondaryText: "B5B0B6")
    public static func of(dark: Bool) -> Palette { dark ? .dark : .light }
}

public enum Contrast {
    private static func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }

    public static func luminance(_ hex: String) -> Double {
        let n = UInt32(hex, radix: 16) ?? 0
        let r = Double((n >> 16) & 0xff) / 255, g = Double((n >> 8) & 0xff) / 255, b = Double(n & 0xff) / 255
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// Linear mix of two RRGGBB colours (t = 0 -> a, t = 1 -> b).
    public static func mix(_ a: String, _ b: String, _ t: Double) -> String {
        let x = UInt32(a, radix: 16) ?? 0, y = UInt32(b, radix: 16) ?? 0
        func ch(_ s: UInt32) -> (Double, Double, Double) { (Double((s >> 16) & 0xff), Double((s >> 8) & 0xff), Double(s & 0xff)) }
        let (r1, g1, b1) = ch(x), (r2, g2, b2) = ch(y)
        func m(_ p: Double, _ q: Double) -> UInt32 { UInt32(max(0, min(255, (p + (q - p) * t).rounded()))) }
        return String(format: "%02X%02X%02X", m(r1, r2), m(g1, g2), m(b1, b2))
    }

    /// WCAG contrast ratio (1...21).
    public static func ratio(_ a: String, _ b: String) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
