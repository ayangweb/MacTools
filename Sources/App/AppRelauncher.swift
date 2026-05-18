import AppKit
import Foundation

@MainActor
protocol AppRelaunching {
    func relaunch()
}

@MainActor
struct AppRelauncher: AppRelaunching {
    var delay: TimeInterval = 0.25

    func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "sleep \(delay); open \(Bundle.main.bundleURL.path.quotedForShell)"
        ]
        try? process.run()
        NSApplication.shared.terminate(nil)
    }
}

private extension String {
    var quotedForShell: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
