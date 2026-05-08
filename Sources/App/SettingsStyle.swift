import AppKit
import SwiftUI

enum SettingsStyle {
    static var windowBackground: Color {
        dynamic(light: 0xF4F5F7, dark: 0x1E1F22)
    }

    static var sidebarBackground: Color {
        dynamic(light: 0xEEF0F3, dark: 0x25262A)
    }

    static var contentBackground: Color {
        dynamic(light: 0xF7F8FA, dark: 0x1F2023)
    }

    static var cardBackground: Color {
        dynamic(light: 0xFFFFFF, dark: 0x2A2B2F)
    }

    static var recessedControlBackground: Color {
        dynamic(light: 0xF1F3F6, dark: 0x222327)
    }

    static var fieldBackground: Color {
        dynamic(light: 0xFFFFFF, dark: 0x1C1D20)
    }

    static var keycapBackground: Color {
        dynamic(light: 0xF8F9FB, dark: 0x2F3035)
    }

    static var separator: Color {
        dynamic(light: 0xD9DDE4, dark: 0x3A3B40)
    }

    static var cardBorder: Color {
        dynamic(light: 0xDDE1E7, dark: 0x3B3C42)
    }

    static var sidebarHoverBackground: Color {
        Color.primary.opacity(0.05)
    }

    static var sidebarSelectionBackground: Color {
        Color.accentColor.opacity(0.12)
    }

    static var activeControlBackground: Color {
        Color.accentColor.opacity(0.12)
    }

    static var recordingBackground: Color {
        Color.accentColor.opacity(0.08)
    }

    private static func dynamic(light lightHex: UInt32, dark darkHex: UInt32) -> Color {
        Color(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    appearance.settingsStyleIsDark ? .settingsStyleRGB(darkHex) : .settingsStyleRGB(lightHex)
                }
            )
        )
    }
}

private extension NSAppearance {
    var settingsStyleIsDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private extension NSColor {
    static func settingsStyleRGB(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}
