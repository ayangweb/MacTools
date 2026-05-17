import Foundation

struct PluginCatalogStatus: Equatable {
    enum Source: Equatable {
        case production(URL)
        case localDevelopment(URL)
        case unavailable
    }

    var source: Source
    var lastUpdatedAt: Date?
    var errorMessage: String?
    var isRefreshing: Bool

    static let unavailable = PluginCatalogStatus(
        source: .unavailable,
        lastUpdatedAt: nil,
        errorMessage: nil,
        isRefreshing: false
    )

    var title: String {
        switch source {
        case .production:
            return "插件列表"
        case .localDevelopment:
            return "本地开发列表"
        case .unavailable:
            return "插件列表未配置"
        }
    }

    var detailText: String {
        if let errorMessage {
            return errorMessage
        }

        if isRefreshing {
            return "正在刷新插件列表..."
        }

        switch source {
        case let .production(url), let .localDevelopment(url):
            return url.absoluteString
        case .unavailable:
            return "已安装插件仍可继续管理。"
        }
    }
}

@MainActor
final class PluginCatalogManager {
    private let catalogProvider: (any PluginCatalogProviding)?
    private let packageResolver: any PluginPackageResolving
    private let dynamicPluginManager: DynamicPluginManager
    private let source: PluginCatalogSource?

    private var snapshot: PluginCatalogSnapshot?
    private(set) var status: PluginCatalogStatus

    init(
        catalogProvider: (any PluginCatalogProviding)?,
        packageResolver: any PluginPackageResolving,
        dynamicPluginManager: DynamicPluginManager,
        source: PluginCatalogSource?
    ) {
        self.catalogProvider = catalogProvider
        self.packageResolver = packageResolver
        self.dynamicPluginManager = dynamicPluginManager
        self.source = source

        if let source {
            switch source {
            case let .production(url):
                self.status = PluginCatalogStatus(
                    source: .production(url),
                    lastUpdatedAt: nil,
                    errorMessage: nil,
                    isRefreshing: false
                )
            case let .localDevelopment(url):
                self.status = PluginCatalogStatus(
                    source: .localDevelopment(url),
                    lastUpdatedAt: nil,
                    errorMessage: nil,
                    isRefreshing: false
                )
            }
        } else {
            self.status = .unavailable
        }
    }

    static func live(dynamicPluginManager: DynamicPluginManager) -> PluginCatalogManager {
        let source = PluginCatalogProviderConfiguration.defaultSource()
        let provider = PluginCatalogProviderFactory.makeProvider(source: source)
        let resolver = PluginPackageResolver(
            temporaryDirectory: dynamicPluginManager.temporaryDirectory
        )

        return PluginCatalogManager(
            catalogProvider: provider,
            packageResolver: resolver,
            dynamicPluginManager: dynamicPluginManager,
            source: source
        )
    }

    func refreshCatalog() async {
        guard let catalogProvider else {
            status = .unavailable
            return
        }

        status.isRefreshing = true
        status.errorMessage = nil

        do {
            let snapshot = try await catalogProvider.loadCatalog()
            self.snapshot = snapshot
            status = PluginCatalogStatus(
                source: statusSource(for: snapshot),
                lastUpdatedAt: snapshot.loadedAt,
                errorMessage: nil,
                isRefreshing: false
            )
        } catch {
            status.isRefreshing = false
            status.errorMessage = error.localizedDescription
        }

        dynamicPluginManager.rebuildManagementItems(catalogSnapshot: snapshot)
    }

    func installPlugin(id: String) async throws {
        let entry = try catalogEntry(id: id)
        let packageURL = try await packageResolver.resolvePackage(for: entry)
        try dynamicPluginManager.installPluginPackage(from: packageURL, catalogEntry: entry)
    }

    func updatePlugin(id: String) async throws {
        let entry = try catalogEntry(id: id)
        let packageURL = try await packageResolver.resolvePackage(for: entry)
        try dynamicPluginManager.updatePluginPackage(from: packageURL, catalogEntry: entry)
    }

    func rebuildManagementItems() {
        dynamicPluginManager.rebuildManagementItems(catalogSnapshot: snapshot)
    }

    private func catalogEntry(id: String) throws -> PluginCatalogEntry {
        guard let entry = snapshot?.catalog.plugins.first(where: { $0.id == id }) else {
            throw PluginCatalogManagerError.catalogEntryNotFound(id)
        }

        return entry
    }

    private func statusSource(for snapshot: PluginCatalogSnapshot) -> PluginCatalogStatus.Source {
        switch snapshot.sourceKind {
        case .production:
            return .production(snapshot.sourceURL)
        case .localDevelopment:
            return .localDevelopment(snapshot.sourceURL)
        }
    }
}

enum PluginCatalogManagerError: LocalizedError, Equatable {
    case catalogEntryNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .catalogEntryNotFound(id):
            return "插件列表中未找到插件：\(id)"
        }
    }
}
