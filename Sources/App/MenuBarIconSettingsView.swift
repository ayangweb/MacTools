import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarIconSettingsView: View {
    @ObservedObject var iconSettings: MenuBarIconSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            MenuBarIconEditorControls(iconSettings: iconSettings)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("状态栏图标")
                    .font(.system(size: 13, weight: .semibold))

                Text("为浅色和深色菜单栏统一设置图标，导入时会自动扣除纯色背景。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                iconSettings.resetToDefault()
            } label: {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
            }
            .disabled(!iconSettings.hasCustomIcon)
        }
    }
}

private struct MenuBarIconEditorControls: View {
    @ObservedObject var iconSettings: MenuBarIconSettings
    @State private var showsAnimationOptions = false

    private let rowLabelWidth: CGFloat = 76
    private let contentWidth: CGFloat = 520
    private var sourceButtonWidth: CGFloat {
        (contentWidth - 8) / 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            controlRow("菜单栏预览", alignment: .top) {
                MenuBarIconPreviewPair(
                    lightPayload: iconSettings.imagePayload(for: NSAppearance(named: .aqua)),
                    darkPayload: iconSettings.imagePayload(for: NSAppearance(named: .darkAqua))
                )
                .frame(width: contentWidth)
            }

            controlRow("图标来源") {
                actionButtons
            }

            Text("支持图片、轻量 GIF/MP4 和内置动态图标；导入时会自动扣除纯色背景。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: contentWidth, alignment: .leading)
                .padding(.leading, rowLabelWidth + 12)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showsAnimationOptions.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("动画播放")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(width: rowLabelWidth, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showsAnimationOptions ? 90 : 0))
                            .frame(width: 12)

                        Text(animationSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .frame(width: rowLabelWidth + 12 + contentWidth, alignment: .leading)
                }
                .buttonStyle(.plain)

                if showsAnimationOptions {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .padding(.leading, rowLabelWidth + 24)

                        animationSpeedControls
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            controlRow("最近使用", alignment: .top) {
                MenuBarIconRecentGrid(iconSettings: iconSettings)
                    .frame(width: contentWidth, alignment: .leading)
            }

            if let warningText = iconSettings.contrastReport(for: .light).warningText
                ?? iconSettings.contrastReport(for: .dark).warningText {
                contentOnlyRow {
                    Label(warningText, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if let errorMessage = iconSettings.lastErrorMessage {
                contentOnlyRow {
                    Label(errorMessage, systemImage: "xmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func controlRow<Content: View>(
        _ title: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: alignment, spacing: 12) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: rowLabelWidth, alignment: .leading)

            content()
        }
    }

    private func contentOnlyRow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Color.clear
                .frame(width: rowLabelWidth, height: 1)

            content()
                .frame(width: contentWidth, alignment: .leading)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                selectMedia()
            } label: {
                Label("上传图片或动画", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(width: sourceButtonWidth)

            MenuBarIconBuiltInPicker(iconSettings: iconSettings)
            .frame(width: sourceButtonWidth)
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private var animationSpeedControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            controlRow("播放速度") {
                Picker("播放速度", selection: Binding(
                    get: { iconSettings.animationSpeedMode },
                    set: { iconSettings.animationSpeedMode = $0 }
                )) {
                    ForEach(MenuBarIconAnimationSpeedMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: contentWidth)
            }

            contentOnlyRow {
                Text(speedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            controlRow("倍率") {
                HStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { iconSettings.manualAnimationSpeedMultiplier },
                            set: { iconSettings.manualAnimationSpeedMultiplier = $0 }
                        ),
                        in: MenuBarIconAnimationSpeedPolicy.minimumMultiplier...MenuBarIconAnimationSpeedPolicy.maximumMultiplier
                    )
                    .disabled(iconSettings.animationSpeedMode != .manual)
                    .frame(width: contentWidth - 50)

                    Text(String(format: "%.1fx", iconSettings.manualAnimationSpeedMultiplier))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    private var animationSummary: String {
        switch iconSettings.animationSpeedMode {
        case .manual:
            return String(format: "手动 %.1fx", iconSettings.manualAnimationSpeedMultiplier)
        case .adaptiveSystemLoad:
            return "随系统负载"
        }
    }

    private var speedDescription: String {
        switch iconSettings.animationSpeedMode {
        case .manual:
            return "固定倍率循环播放。"
        case .adaptiveSystemLoad:
            return "CPU、GPU、内存越高越快。"
        }
    }

    private func selectMedia() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = MenuBarIconProcessing.supportedImageContentTypes
            + MenuBarIconProcessing.supportedAnimationContentTypes
        panel.message = "选择图片、GIF 或 MP4 作为 MacTools 状态栏图标"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let contentType = UTType(filenameExtension: url.pathExtension)
        if let contentType,
           MenuBarIconProcessing.supportedAnimationContentTypes.contains(where: { contentType.conforms(to: $0) }) {
            Task {
                await iconSettings.importAnimation(from: url)
            }
        } else {
            iconSettings.importIcon(from: url)
        }
    }
}

private struct MenuBarIconPreviewPair: View {
    let lightPayload: MenuBarIconImagePayload
    let darkPayload: MenuBarIconImagePayload

    var body: some View {
        HStack(spacing: 8) {
            MenuBarIconPreviewStrip(
                title: "浅色",
                payload: lightPayload,
                backgroundColor: Color(nsColor: .windowBackgroundColor),
                foregroundColor: .black
            )
            .frame(maxWidth: .infinity)

            MenuBarIconPreviewStrip(
                title: "深色",
                payload: darkPayload,
                backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.13),
                foregroundColor: .white
            )
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MenuBarIconPreviewStrip: View {
    let title: String
    let payload: MenuBarIconImagePayload
    let backgroundColor: Color
    let foregroundColor: Color

    private var frameDuration: TimeInterval {
        switch payload.speedMode {
        case .manual:
            return max(payload.frameDuration / payload.manualSpeedMultiplier, 1.0 / 30.0)
        case .adaptiveSystemLoad:
            return max(payload.frameDuration, 1.0 / 30.0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(.yellow)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)

                Spacer()

                TimelineView(.periodic(from: .now, by: frameDuration)) { context in
                    Image(nsImage: frame(for: context.date))
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(foregroundColor)
                        .frame(width: 18, height: 18)
                }
                .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func frame(for date: Date) -> NSImage {
        guard payload.animationFrames.count > 1 else {
            return payload.image
        }

        let frameIndex = Int(date.timeIntervalSinceReferenceDate / frameDuration) % payload.animationFrames.count
        return payload.animationFrames[frameIndex]
    }
}

private struct MenuBarIconRecentGrid: View {
    @ObservedObject var iconSettings: MenuBarIconSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if iconSettings.recentItems.isEmpty {
                Text("上传或选择图标后会显示在这里。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    ForEach(iconSettings.recentItems.prefix(6)) { item in
                        Button {
                            iconSettings.useRecentIcon(item)
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                Image(nsImage: iconSettings.previewImage(for: item))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .frame(width: 42, height: 42)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )

                                if item.mediaKind == .animation {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 14, height: 14)
                                        .background(Color.accentColor)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(item.displayName)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuBarIconBuiltInPicker: View {
    @ObservedObject var iconSettings: MenuBarIconSettings
    @State private var selectedGroup: MenuBarIconBuiltInAnimationGroup = .featured
    @State private var isPickerPresented = false

    private var filteredAnimations: [MenuBarIconBuiltInAnimation] {
        iconSettings.builtInAnimations.filter { animation in
            animation.group == selectedGroup
        }
    }

    var body: some View {
        Button {
            isPickerPresented.toggle()
        } label: {
            Label("内置动态图标", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            pickerContent
        }
    }

    private var pickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("内置动态图标")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Picker("分组", selection: $selectedGroup) {
                    ForEach(MenuBarIconBuiltInAnimationGroup.allCases) { group in
                        Text(group.title).tag(group)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 110)
            }

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(70), spacing: 8), count: 6),
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(filteredAnimations) { animation in
                        Button {
                            iconSettings.useBuiltInAnimation(animation)
                            isPickerPresented = false
                        } label: {
                            VStack(spacing: 6) {
                                MenuBarIconAnimatedPreview(animation: animation)

                                Text(animation.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: 64)
                            }
                            .frame(width: 70, height: 64)
                        }
                        .buttonStyle(.plain)
                        .help("使用 \(animation.displayName)")
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(width: 460, height: 300)
        }
        .padding(14)
        .frame(width: 488)
    }
}

private struct MenuBarIconAnimatedPreview: View {
    let animation: MenuBarIconBuiltInAnimation
    @State private var frames: [NSImage] = []

    private var frameDuration: TimeInterval {
        max(animation.frameDuration, 1.0 / 30.0)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: frameDuration)) { context in
            Image(nsImage: frame(for: context.date))
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 32, height: 20)
                .frame(width: 54, height: 34)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .onAppear {
            if frames.isEmpty {
                frames = animation.loadFrames()
            }
        }
    }

    private func frame(for date: Date) -> NSImage {
        guard !frames.isEmpty else {
            return animation.loadFirstFrame() ?? NSImage(size: NSSize(width: 18, height: 18))
        }

        let frameIndex = Int(date.timeIntervalSinceReferenceDate / frameDuration) % frames.count
        return frames[frameIndex]
    }
}
