import Foundation
import SwiftUI
import MacToolsPluginKit

public final class HideNotchPluginFactory: NSObject, MacToolsPluginBundleFactory {
    public static func makeProvider(context: PluginRuntimeContext) throws -> any PluginProvider {
        HideNotchPluginProvider(context: context)
    }
}

@MainActor
private struct HideNotchPluginProvider: PluginProvider {
    let context: PluginRuntimeContext

    func makePlugins() -> [any MacToolsPlugin] {
        [HideNotchPlugin(context: context)]
    }
}

@MainActor
final class HideNotchPlugin: MacToolsPlugin, PluginPrimaryPanel {
    let metadata = PluginMetadata(
        id: "hide-notch",
        title: "隐藏刘海",
        iconName: "rectangle.topthird.inset.filled",
        iconTint: Color(nsColor: .labelColor),
        order: 40,
        defaultDescription: "自动遮挡刘海屏顶部区域"
    )

    let primaryPanelDescriptor = PluginPrimaryPanelDescriptor(
        controlStyle: .switch,
        menuActionBehavior: .keepPresented
    )

    var onStateChange: (() -> Void)?
    var requestPermissionGuidance: ((String) -> Void)?
    var shortcutBindingResolver: ((String) -> ShortcutBinding?)?

    private let controller: HideNotchWallpaperControlling

    init(
        context: PluginRuntimeContext = PluginRuntimeContext(pluginID: "hide-notch"),
        controller: HideNotchWallpaperControlling? = nil
    ) {
        self.controller = controller ?? HideNotchController(context: context)
        self.controller.onStateChange = { [weak self] in
            self?.onStateChange?()
        }
    }

    var primaryPanelState: PluginPanelState {
        let snapshot = controller.snapshot()

        if !snapshot.hasSupportedDisplay {
            let subtitle = snapshot.isEnabled ? "已开启" : "未检测到刘海屏"

            return PluginPanelState(
                subtitle: subtitle,
                isOn: snapshot.isEnabled,
                isExpanded: false,
                isEnabled: false,
                isVisible: true,
                detail: nil,
                errorMessage: snapshot.errorMessage
            )
        }

        let subtitle: String
        if snapshot.isEnabled {
            subtitle = "已开启"
        } else if snapshot.isProcessing {
            subtitle = "正在关闭"
        } else {
            subtitle = metadata.defaultDescription
        }

        return PluginPanelState(
            subtitle: subtitle,
            isOn: snapshot.isEnabled,
            isExpanded: false,
            isEnabled: !snapshot.isProcessing,
            isVisible: true,
            detail: nil,
            errorMessage: snapshot.errorMessage
        )
    }

    var permissionRequirements: [PluginPermissionRequirement] { [] }
    var settingsSections: [PluginSettingsSection] { [] }
    var shortcutDefinitions: [PluginShortcutDefinition] { [] }

    func refresh() {
        controller.refresh()
    }

    func handleAction(_ action: PluginPanelAction) {
        guard case let .setSwitch(isEnabled) = action else {
            return
        }

        controller.setEnabled(isEnabled)
        onStateChange?()
    }

    func permissionState(for permissionID: String) -> PluginPermissionState {
        PluginPermissionState(isGranted: true, footnote: nil)
    }

    func handlePermissionAction(id: String) {}
    func handleSettingsAction(id: String) {}
    func handleShortcutAction(id: String) {}
}
