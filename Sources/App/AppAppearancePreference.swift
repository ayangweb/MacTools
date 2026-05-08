import AppKit

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    static let userDefaultsKey = "app.appearancePreference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "自动"
        case .dark:
            return "深色"
        case .light:
            return "浅色"
        }
    }

    @MainActor
    func apply() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    static func stored(in userDefaults: UserDefaults = .standard) -> AppAppearancePreference {
        guard
            let rawValue = userDefaults.string(forKey: userDefaultsKey),
            let preference = AppAppearancePreference(rawValue: rawValue)
        else {
            return .system
        }

        return preference
    }

    @MainActor
    static func applyStoredPreference(userDefaults: UserDefaults = .standard) {
        stored(in: userDefaults).apply()
    }
}
