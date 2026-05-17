import AppKit
import SwiftUI

enum MiddleClickSettingsStyle {
    static var cardBackground: Color {
        dynamic(light: 0xFFFFFF, dark: 0x2A2B2F)
    }

    static var cardBorder: Color {
        dynamic(light: 0xDDE1E7, dark: 0x3B3C42)
    }

    private static func dynamic(light lightHex: UInt32, dark darkHex: UInt32) -> Color {
        Color(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    appearance.middleClickSettingsStyleIsDark
                        ? .middleClickSettingsStyleRGB(darkHex)
                        : .middleClickSettingsStyleRGB(lightHex)
                }
            )
        )
    }
}

private extension NSAppearance {
    var middleClickSettingsStyleIsDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private extension NSColor {
    static func middleClickSettingsStyleRGB(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}
