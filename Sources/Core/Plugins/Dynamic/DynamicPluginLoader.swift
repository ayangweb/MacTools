import Foundation
import MacToolsPluginKit

struct DynamicPluginLoadResult {
    let record: PluginPackageRecord
    let plugins: [any MacToolsPlugin]
    let errorMessage: String?
}

@MainActor
protocol DynamicPluginLoading {
    func loadInstalledPlugins(from records: [PluginPackageRecord]) -> [DynamicPluginLoadResult]
}

@MainActor
final class DynamicPluginLoader: DynamicPluginLoading {
    private let packageStore: PluginPackageStore
    private let trustValidator: PluginTrustValidating

    init(
        packageStore: PluginPackageStore,
        trustValidator: PluginTrustValidating = SameTeamPluginTrustValidator()
    ) {
        self.packageStore = packageStore
        self.trustValidator = trustValidator
    }

    func loadInstalledPlugins(from records: [PluginPackageRecord]) -> [DynamicPluginLoadResult] {
        records.map { record in
            guard case .enabled = record.state else {
                return DynamicPluginLoadResult(record: record, plugins: [], errorMessage: nil)
            }

            do {
                let provider = try loadProvider(for: record)
                let context = packageStore.runtimeContext(for: record)
                let plugins = provider.makePlugins()

                for plugin in plugins {
                    plugin.activate(context: context)
                }

                return DynamicPluginLoadResult(record: record, plugins: plugins, errorMessage: nil)
            } catch {
                return DynamicPluginLoadResult(
                    record: record,
                    plugins: [],
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    private func loadProvider(for record: PluginPackageRecord) throws -> any PluginProvider {
        try trustValidator.validatePluginBundle(at: record.bundleURL)

        guard let bundle = Bundle(url: record.bundleURL) else {
            throw DynamicPluginLoaderError.unreadableBundle(record.bundleURL)
        }

        guard bundle.load() else {
            throw DynamicPluginLoaderError.loadFailed(record.bundleURL)
        }

        let context = packageStore.runtimeContext(for: record)

        if let className = record.manifest.factoryClass,
           let factoryClass = NSClassFromString(className) as? MacToolsPluginBundleFactory.Type {
            return try factoryClass.makeProvider(context: context)
        }

        guard let factoryClass = bundle.principalClass as? MacToolsPluginBundleFactory.Type else {
            throw DynamicPluginLoaderError.missingFactory(record.manifest.displayName)
        }

        return try factoryClass.makeProvider(context: context)
    }
}

enum DynamicPluginLoaderError: LocalizedError {
    case unreadableBundle(URL)
    case loadFailed(URL)
    case missingFactory(String)

    var errorDescription: String? {
        switch self {
        case let .unreadableBundle(url):
            return "无法读取插件 bundle：\(url.path)"
        case let .loadFailed(url):
            return "插件代码加载失败：\(url.path)"
        case let .missingFactory(name):
            return "插件缺少入口工厂：\(name)"
        }
    }
}
