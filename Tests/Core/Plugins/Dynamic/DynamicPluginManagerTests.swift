import Foundation
import XCTest
import MacToolsPluginKit
@testable import MacTools

@MainActor
final class DynamicPluginManagerTests: XCTestCase {
    private var temporaryRoot: URL!
    private var defaults: UserDefaults!
    private let suiteName = "DynamicPluginManagerTests"

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DynamicPluginManagerTests-\(UUID().uuidString)", isDirectory: true)
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        temporaryRoot = nil
    }

    func testDisablingLoadedPluginRemovesItAndDefersReloadUntilRestart() throws {
        let sourceURL = try makePackage(id: "com.example.demo")
        let store = makeStore()
        _ = try store.installPackage(from: sourceURL)
        let plugin = MockDynamicPlugin(id: "com.example.demo")
        let loader = StubDynamicPluginLoader { records in
            records.map { record in
                DynamicPluginLoadResult(record: record, plugins: [plugin], errorMessage: nil)
            }
        }
        let manager = DynamicPluginManager(packageStore: store, pluginLoader: loader)

        XCTAssertEqual(manager.loadInstalledPlugins().map(\.metadata.id), ["com.example.demo"])

        manager.setPluginEnabled(false, pluginID: "com.example.demo")

        XCTAssertEqual(plugin.deactivationReasons, [.disabled])
        XCTAssertTrue(manager.loadInstalledPlugins().isEmpty)
        XCTAssertEqual(manager.pluginManagementItems.first?.state, .disabled)
        XCTAssertEqual(
            manager.pluginManagementItems.first?.detailText,
            "已移出界面，重启后彻底释放已加载代码。"
        )
    }

    func testReloadKeepsExistingLoadedPluginInstances() throws {
        let sourceURL = try makePackage(id: "com.example.demo")
        let store = makeStore()
        _ = try store.installPackage(from: sourceURL)
        let plugin = MockDynamicPlugin(id: "com.example.demo")
        let loader = StubDynamicPluginLoader { records in
            records.map { record in
                DynamicPluginLoadResult(record: record, plugins: [plugin], errorMessage: nil)
            }
        }
        let manager = DynamicPluginManager(packageStore: store, pluginLoader: loader)

        XCTAssertEqual(manager.loadInstalledPlugins().map(\.metadata.id), ["com.example.demo"])
        XCTAssertEqual(loader.receivedRecordIDBatches, [["com.example.demo"]])

        XCTAssertEqual(manager.loadInstalledPlugins().map(\.metadata.id), ["com.example.demo"])

        XCTAssertEqual(loader.receivedRecordIDBatches, [["com.example.demo"], []])
        XCTAssertTrue(plugin.deactivationReasons.isEmpty)
    }

    func testUpdatingLoadedPluginInstallsFilesButDoesNotReloadNativeCodeUntilRestart() throws {
        let firstPackageURL = try makePackage(id: "com.example.demo", version: "1.0.0")
        let updatePackageURL = try makePackage(id: "com.example.demo", version: "2.0.0")
        let store = makeStore()
        _ = try store.installPackage(from: firstPackageURL)
        let plugin = MockDynamicPlugin(id: "com.example.demo")
        let loader = StubDynamicPluginLoader { records in
            records.map { record in
                DynamicPluginLoadResult(record: record, plugins: [plugin], errorMessage: nil)
            }
        }
        let manager = DynamicPluginManager(packageStore: store, pluginLoader: loader)

        XCTAssertEqual(manager.loadInstalledPlugins().map(\.metadata.id), ["com.example.demo"])

        try manager.updatePluginPackage(from: updatePackageURL)

        XCTAssertEqual(plugin.deactivationReasons, [.updating])
        XCTAssertTrue(manager.loadInstalledPlugins().isEmpty)
        XCTAssertEqual(store.installedRecords().first?.manifest.version, "2.0.0")
        XCTAssertEqual(manager.pluginManagementItems.first?.state, .restartRequired)
        XCTAssertEqual(
            manager.pluginManagementItems.first?.detailText,
            "新版本将在重启后启用，旧代码将在重启后彻底释放。"
        )
    }

    func testUninstallingLoadedPluginDeletesPackageAndRemovesManagementItem() throws {
        let sourceURL = try makePackage(id: "com.example.demo")
        let store = makeStore()
        _ = try store.installPackage(from: sourceURL)
        let plugin = MockDynamicPlugin(id: "com.example.demo")
        let loader = StubDynamicPluginLoader { records in
            records.map { record in
                DynamicPluginLoadResult(record: record, plugins: [plugin], errorMessage: nil)
            }
        }
        let manager = DynamicPluginManager(packageStore: store, pluginLoader: loader)

        XCTAssertEqual(manager.loadInstalledPlugins().map(\.metadata.id), ["com.example.demo"])

        try manager.uninstallPlugin(pluginID: "com.example.demo")

        XCTAssertEqual(plugin.deactivationReasons, [.uninstalling])
        XCTAssertTrue(manager.loadInstalledPlugins().isEmpty)
        XCTAssertTrue(manager.pluginManagementItems.isEmpty)
        XCTAssertTrue(store.installedRecords().isEmpty)
    }

    func testCatalogEntryAddsAvailableManagementItem() throws {
        let store = makeStore()
        let manager = DynamicPluginManager(packageStore: store, pluginLoader: StubDynamicPluginLoader { _ in [] })
        let snapshot = makeCatalogSnapshot(entries: [makeCatalogEntry(id: "com.example.demo", version: "1.0.0")])

        manager.rebuildManagementItems(catalogSnapshot: snapshot)

        XCTAssertEqual(manager.pluginManagementItems.map(\.id), ["com.example.demo"])
        XCTAssertEqual(manager.pluginManagementItems.first?.state, .available)
        XCTAssertEqual(manager.pluginManagementItems.first?.canInstall, true)
    }

    func testCatalogEntryShowsUpdateWhenNewerThanInstalledVersion() throws {
        let sourceURL = try makePackage(id: "com.example.demo", version: "1.0.0")
        let store = makeStore()
        _ = try store.installPackage(from: sourceURL)
        let manager = DynamicPluginManager(packageStore: store, pluginLoader: StubDynamicPluginLoader { _ in [] })
        _ = manager.loadInstalledPlugins()
        let snapshot = makeCatalogSnapshot(entries: [makeCatalogEntry(id: "com.example.demo", version: "2.0.0")])

        manager.rebuildManagementItems(catalogSnapshot: snapshot)

        XCTAssertEqual(
            manager.pluginManagementItems.first?.state,
            .updateAvailable(installedVersion: "1.0.0", catalogVersion: "2.0.0")
        )
        XCTAssertEqual(manager.pluginManagementItems.first?.canUpdate, true)
    }

    func testLocalDevelopmentCatalogEntryUsesLocalDevelopmentState() throws {
        let store = makeStore()
        let manager = DynamicPluginManager(packageStore: store, pluginLoader: StubDynamicPluginLoader { _ in [] })
        let snapshot = makeCatalogSnapshot(
            entries: [makeCatalogEntry(id: "com.example.demo", version: "1.0.0")],
            sourceKind: .localDevelopment
        )

        manager.rebuildManagementItems(catalogSnapshot: snapshot)

        XCTAssertEqual(manager.pluginManagementItems.first?.state, .localDevelopment)
        XCTAssertEqual(manager.pluginManagementItems.first?.canInstall, true)
    }

    private func makeStore() -> PluginPackageStore {
        PluginPackageStore(
            rootDirectory: temporaryRoot,
            userDefaults: defaults,
            hostVersion: "1.0.0"
        )
    }

    private func makePackage(
        id: String,
        version: String = "1.0.0",
        bundleRelativePath: String = "Demo.bundle"
    ) throws -> URL {
        let packageURL = temporaryRoot
            .appendingPathComponent("Source", isDirectory: true)
            .appendingPathComponent("\(id)-\(version)", isDirectory: true)
            .appendingPathExtension("mactoolsplugin")
        let bundleURL = packageURL.appendingPathComponent(bundleRelativePath, isDirectory: true)

        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let manifest = PluginPackageManifest(
            id: id,
            displayName: "Demo",
            version: version,
            minHostVersion: "0.1.0",
            bundleRelativePath: bundleRelativePath
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: packageURL.appendingPathComponent("plugin.json"))

        return packageURL
    }

    private func makeCatalogEntry(id: String, version: String) -> PluginCatalogEntry {
        PluginCatalogEntry(
            id: id,
            displayName: "Demo",
            summary: "示例插件",
            version: version,
            minimumHostVersion: "0.1.0",
            package: PluginCatalogPackage(
                url: URL(fileURLWithPath: "/tmp/Demo.mactoolsplugin"),
                sha256: String(repeating: "a", count: 64),
                size: 42
            )
        )
    }

    private func makeCatalogSnapshot(
        entries: [PluginCatalogEntry],
        sourceKind: PluginCatalogSnapshot.SourceKind = .production
    ) -> PluginCatalogSnapshot {
        PluginCatalogSnapshot(
            catalog: PluginCatalog(
                catalogID: "com.example.catalog",
                generatedAt: Date(timeIntervalSince1970: 0),
                minimumHostVersion: "0.1.0",
                plugins: entries
            ),
            sourceURL: URL(string: "https://example.com/catalog.json")!,
            sourceKind: sourceKind,
            loadedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

@MainActor
private final class StubDynamicPluginLoader: DynamicPluginLoading {
    private let handler: ([PluginPackageRecord]) -> [DynamicPluginLoadResult]
    private(set) var receivedRecordIDBatches: [[String]] = []

    init(handler: @escaping ([PluginPackageRecord]) -> [DynamicPluginLoadResult]) {
        self.handler = handler
    }

    func loadInstalledPlugins(from records: [PluginPackageRecord]) -> [DynamicPluginLoadResult] {
        receivedRecordIDBatches.append(records.map(\.id))
        return handler(records)
    }
}

@MainActor
private final class MockDynamicPlugin: MacToolsPlugin {
    let metadata: PluginMetadata
    var onStateChange: (() -> Void)?
    var requestPermissionGuidance: ((String) -> Void)?
    var shortcutBindingResolver: ((String) -> ShortcutBinding?)?
    private(set) var deactivationReasons: [PluginDeactivationReason] = []

    init(id: String) {
        self.metadata = PluginMetadata(
            id: id,
            title: "Demo",
            iconName: "shippingbox",
            iconTint: .blue,
            order: 1,
            defaultDescription: "Demo"
        )
    }

    func deactivate(reason: PluginDeactivationReason) {
        deactivationReasons.append(reason)
    }
}
