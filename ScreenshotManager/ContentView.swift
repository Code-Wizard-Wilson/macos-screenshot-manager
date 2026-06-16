import AppKit
import ImageIO
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ScreenshotStore
    @State private var pendingDelete: ScreenshotItem?
    @State private var editingItem: ScreenshotItem?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isCompact = width < 860
            let showsPreview = width >= 1080

            ZStack(alignment: .top) {
                AppTheme.windowBackground
                    .ignoresSafeArea()

                if isCompact {
                    CompactLayoutView(
                        store: store,
                        columns: columns(for: width),
                        pendingDelete: $pendingDelete,
                        editingItem: $editingItem
                    )
                } else {
                    RegularLayoutView(
                        store: store,
                        columns: columns(for: showsPreview ? width - previewWidth(for: width) - sidebarWidth(for: width) : width - sidebarWidth(for: width)),
                        sidebarWidth: sidebarWidth(for: width),
                        previewWidth: previewWidth(for: width),
                        showsPreview: showsPreview,
                        pendingDelete: $pendingDelete,
                        editingItem: $editingItem
                    )
                }

                if let notice = store.captureNotice {
                    CaptureNoticeView(notice: notice)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: store.captureNotice)
            .animation(.easeInOut(duration: 0.18), value: isCompact)
            .animation(.easeInOut(duration: 0.18), value: showsPreview)
        }
        .alert(item: $pendingDelete) { item in
            Alert(
                title: Text("Delete screenshot?"),
                message: Text(item.fileName),
                primaryButton: .destructive(Text("Delete")) {
                    store.delete(item)
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(item: $editingItem) { item in
            ImageEditorView(store: store, item: item)
        }
        .task {
            store.refresh()
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        let minimum = width < 760 ? 170.0 : 220.0
        let maximum = width < 760 ? 230.0 : 260.0
        return [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: 14)]
    }

    private func sidebarWidth(for width: CGFloat) -> CGFloat {
        width < 1050 ? 224 : 246
    }

    private func previewWidth(for width: CGFloat) -> CGFloat {
        min(max(width * 0.29, 300), 380)
    }
}

private struct RegularLayoutView: View {
    @ObservedObject var store: ScreenshotStore
    let columns: [GridItem]
    let sidebarWidth: CGFloat
    let previewWidth: CGFloat
    let showsPreview: Bool
    @Binding var pendingDelete: ScreenshotItem?
    @Binding var editingItem: ScreenshotItem?

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(store: store)
                .frame(width: sidebarWidth)

            Divider()

            LibraryView(
                store: store,
                columns: columns,
                pendingDelete: $pendingDelete,
                editingItem: $editingItem
            )
            .frame(minWidth: 360)

            if showsPreview {
                Divider()

                PreviewPane(
                    store: store,
                    pendingDelete: $pendingDelete,
                    editingItem: $editingItem
                )
                .frame(width: previewWidth)
                .transition(.opacity)
            }
        }
    }
}

private struct CompactLayoutView: View {
    @ObservedObject var store: ScreenshotStore
    let columns: [GridItem]
    @Binding var pendingDelete: ScreenshotItem?
    @Binding var editingItem: ScreenshotItem?

    var body: some View {
        VStack(spacing: 0) {
            CompactHeaderView(store: store)

            Divider()

            LibraryView(
                store: store,
                columns: columns,
                pendingDelete: $pendingDelete,
                editingItem: $editingItem
            )
        }
    }
}

private struct CompactHeaderView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Screenshot Manager", systemImage: "camera.viewfinder")
                        .font(AppTypography.productTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    VStack(alignment: .leading, spacing: 2) {
                        Label(store.clipboardHotkey.displayString, systemImage: "doc.on.clipboard")
                        Label(store.saveHotkey.displayString, systemImage: "tray.and.arrow.down")
                    }
                    .font(AppTypography.helper)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .help("Settings")

                    Button {
                        store.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh")
                }
            }

            HStack(spacing: 10) {
                Button {
                    store.captureToClipboard()
                } label: {
                    Label(store.isCapturing ? "Capturing..." : "Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isCapturing)

                Button {
                    store.captureAndSaveToLibrary()
                } label: {
                    Label("Library", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isCapturing)
            }

            HotkeySummaryView(store: store)
        }
        .padding(14)
        .background(AppTheme.sidebarBackground)
    }
}

private struct SidebarView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Screenshot Manager", systemImage: "camera.viewfinder")
                        .font(AppTypography.productTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HotkeySummaryView(store: store)
                }

                CaptureControlsView(store: store)

                VStack(spacing: 10) {
                    StatTile(title: "Indexed", value: "\(store.items.count)", icon: "square.grid.2x2")
                    StatTile(title: "Showing", value: "\(store.filteredItems.count)", icon: "line.3.horizontal.decrease.circle")
                }

                FolderSectionView(store: store)

                if let errorMessage = store.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(4)
                }
            }
            .padding(18)
        }
        .background(AppTheme.sidebarBackground)
    }
}

private struct CaptureControlsView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Capture")
                    .font(AppTypography.sectionTitle)

                Spacer()

                if store.isCapturing {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                }
            }

            Button {
                store.captureToClipboard()
            } label: {
                Label(store.isCapturing ? "Capturing..." : "Clipboard", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isCapturing)

            Button {
                store.captureAndSaveToLibrary()
            } label: {
                Label("Library", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.isCapturing)
        }
        .padding(12)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.softBorder, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: store.isCapturing)
    }
}

private struct HotkeySummaryView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hotkeys")
                    .font(AppTypography.sectionTitle)

                Spacer()

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            Label(store.clipboardHotkey.displayString, systemImage: "doc.on.clipboard")
                .lineLimit(1)

            Label(store.saveHotkey.displayString, systemImage: "tray.and.arrow.down")
                .lineLimit(1)
        }
        .font(AppTypography.helper)
        .foregroundStyle(.secondary)
        .padding(12)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.softBorder, lineWidth: 1)
        }
    }
}

private struct SettingsShortcutButton: View {
    var body: some View {
        Button {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } label: {
            Label("Settings", systemImage: "gearshape")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

private struct FolderSectionView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library")
                .font(AppTypography.sectionTitle)

            Text(store.folderURL.path(percentEncoded: false))
                .font(.callout)
                .lineLimit(3)
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.contentBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.softBorder, lineWidth: 1)
                }

            Button {
                store.captureAndSaveToLibrary()
            } label: {
                Label("Capture to Library", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.isCapturing)

            Button {
                store.chooseFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            SettingsShortcutButton()
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(AppTypography.helper)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.softBorder, lineWidth: 1)
        }
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.16), value: value)
    }
}

private struct LibraryView: View {
    @ObservedObject var store: ScreenshotStore
    let columns: [GridItem]
    @Binding var pendingDelete: ScreenshotItem?
    @Binding var editingItem: ScreenshotItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search screenshots", text: $store.searchText)
                    .textFieldStyle(.plain)

                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(AppTheme.toolbarBackground)

            if store.filteredItems.isEmpty {
                EmptyStateView(isLoading: store.isLoading)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.filteredItems) { item in
                            ScreenshotCard(
                                item: item,
                                isSelected: item.id == store.selectedItem?.id
                            )
                            .onTapGesture {
                                store.selectedItem = item
                            }
                            .contextMenu {
                                Button("Edit") { editingItem = item }
                                Button("Open") { store.open(item) }
                                Button("Reveal in Finder") { store.revealInFinder(item) }
                                Button("Copy Image") { store.copy(item) }
                                Divider()
                                Button("Delete", role: .destructive) { pendingDelete = item }
                            }
                        }
                    }
                    .padding(18)
                }
            }
        }
        .background(AppTheme.contentBackground)
    }
}

private struct ScreenshotCard: View {
    let item: ScreenshotItem
    let isSelected: Bool
    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.imageWellBackground)

                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        HStack {
                            CaptureKindBadge(kind: item.captureKind)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                }
            }
            .aspectRatio(1.55, contentMode: .fit)
            .frame(maxWidth: .infinity)

            Text(item.fileName)
                .font(AppTypography.itemTitle)
                .lineLimit(1)

            HStack {
                Text(item.createdAt, style: .date)
                Spacer()
                Text(item.dimensionsText)
            }
            .font(AppTypography.metadata)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AppTheme.selectedBackground : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.72) : (isHovering ? AppTheme.border : AppTheme.softBorder), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .clipped()
        .onHover { isHovering = $0 }
        .task(id: item.url) {
            thumbnail = await ThumbnailLoader.thumbnail(for: item.url, maxPixelSize: 640)
        }
        .animation(.easeInOut(duration: 0.16), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}

private struct CaptureKindBadge: View {
    let kind: CaptureKind

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(badgeColor, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .help(kind.displayName)
    }

    private var badgeColor: Color {
        switch kind {
        case .clipboard:
            return .accentColor
        case .saved:
            return .green
        }
    }
}

private struct PreviewPane: View {
    @ObservedObject var store: ScreenshotStore
    @Binding var pendingDelete: ScreenshotItem?
    @Binding var editingItem: ScreenshotItem?

    var body: some View {
        ZStack {
            AppTheme.panelBackground

            if let item = store.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preview")
                            .font(AppTypography.paneTitle)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.imageWellBackground)

                            if let image = NSImage(contentsOf: item.url) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(8)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.2, contentMode: .fit)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.softBorder, lineWidth: 1)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            MetadataRow(title: "Type", value: item.captureKind.displayName)
                            MetadataRow(title: "Name", value: item.fileName)
                            MetadataRow(title: "Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            MetadataRow(title: "Dimensions", value: item.dimensionsText)
                            MetadataRow(title: "File size", value: item.displaySize)
                        }

                        HStack {
                            Button {
                                editingItem = item
                            } label: {
                                Label("Edit", systemImage: "slider.horizontal.3")
                            }

                            Button {
                                store.open(item)
                            } label: {
                                Label("Open", systemImage: "arrow.up.right.square")
                            }
                        }

                        HStack {
                            Button {
                                store.copy(item)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }

                            Button {
                                store.revealInFinder(item)
                            } label: {
                                Label("Finder", systemImage: "folder")
                            }
                        }

                        Button(role: .destructive) {
                            pendingDelete = item
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .padding(20)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)

                    Text("Select a screenshot")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.selectedItem?.id)
    }
}

private struct CaptureNoticeView: View {
    let notice: CaptureNotice

    private var tint: Color {
        switch notice.tone {
        case .success:
            return .accentColor
        case .neutral:
            return .secondary
        case .failure:
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: notice.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.callout.weight(.semibold))

                Text(notice.detail)
                    .font(AppTypography.helper)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .frame(maxWidth: 360)
    }
}

private struct MetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppTypography.helper)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.itemTitle)
                .lineLimit(2)
        }
    }
}

private struct EmptyStateView: View {
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
            } else {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No screenshots found")
                    .font(.title3.weight(.semibold))

                Text("Choose a folder with PNG, JPG, HEIC, TIFF, or WebP images.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum ThumbnailLoader {
    static func thumbnail(for url: URL, maxPixelSize: Int) async -> NSImage? {
        await Task.detached(priority: .utility) {
            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]

            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }

            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }.value
    }
}
