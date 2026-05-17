import Foundation
import MacToolsPluginKit

@MainActor
struct BuiltInPluginRegistry: PluginProvider {
    func makePlugins() -> [any MacToolsPlugin] {
        []
    }
}
