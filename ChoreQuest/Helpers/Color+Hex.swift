import SwiftUI

extension Color {
    /// Creates a color from a hex string such as "#7C5CFF", "7C5CFF", "#FFF",
    /// or "#FF7C5CFF" (ARGB). Falls back to the brand violet on a bad string.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (value >> 16, value >> 8 & 0xFF, value & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF, value >> 24)
        default: // brand violet fallback
            (r, g, b, a) = (124, 92, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
