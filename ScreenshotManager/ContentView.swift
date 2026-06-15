import AppKit
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
                VisualEffectView(material: .hudWindow)

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
        let minimum = width < 760 ? 132.0 : 168.0
        let maximum = width < 760 ? 180.0 : 220.0
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
                    Text(store.hotkey.displayString)
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button {
                    store.captureToClipboard()
                } label: {
                    Label(store.isCapturing ? "Capturing..." : "Capture & Copy", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isCapturing)

                Button {
                    store.captureAndSaveToLibrary()
                } label: {
                    Label("Save", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isCapturing)
            }

            HotkeyRecorderView(
                hotkey: Binding(
                    get: { store.hotkey },
                    set: { store.updateHotkey($0) }
                )
            )
            .frame(height: 34)
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }
}

private struct SidebarView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Screenshot Manager", systemImage: "camera.viewfinder")
                            .font(AppTypography.productTitle)

                        Text(store.hotkey.displayString)
                            .font(AppTypography.helper)
                            .foregroundStyle(.secondary)
                    }

                    CaptureControlsView(store: store)
                    HotkeySectionView(store: store)

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
        }
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
                Label(store.isCapturing ? "Capturing..." : "Capture & Copy", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isCapturing)

            Button {
                store.captureAndSaveToLibrary()
            } label: {
                Label("Capture & Save", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.isCapturing)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: store.isCapturing)
    }
}

private struct HotkeySectionView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hotkey")
                .font(AppTypography.sectionTitle)

            HotkeyRecorderView(
                hotkey: Binding(
                    get: { store.hotkey },
                    set: { store.updateHotkey($0) }
                )
            )
            .frame(height: 34)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct FolderSectionView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folder")
                .font(AppTypography.sectionTitle)

            Text(store.folderURL.path(percentEncoded: false))
                .font(.callout)
                .lineLimit(3)
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator.opacity(0.25), lineWidth: 1)
                }

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.3), lineWidth: 1)
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
            .background(.thinMaterial)

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
                            .transition(.opacity)
                        }
                    }
                    .padding(18)
                    .animation(.easeInOut(duration: 0.18), value: store.filteredItems)
                }
            }
        }
    }
}

private struct ScreenshotCard: View {
    let item: ScreenshotItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))

                if let image = NSImage(contentsOf: item.url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 118)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            }

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
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(isSelected ? 0.55 : 0.28), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

private struct PreviewPane: View {
    @ObservedObject var store: ScreenshotStore
    @Binding var pendingDelete: ScreenshotItem?
    @Binding var editingItem: ScreenshotItem?

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover)

            if let item = store.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preview")
                            .font(AppTypography.paneTitle)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))

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
                                .stroke(.separator.opacity(0.25), lineWidth: 1)
                        }

                        VStack(alignment: .leading, spacing: 8) {
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
                .transition(.opacity)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
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
