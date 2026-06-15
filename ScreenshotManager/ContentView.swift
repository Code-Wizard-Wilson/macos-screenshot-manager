import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ScreenshotStore
    @State private var pendingDelete: ScreenshotItem?

    private let columns = [
        GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 14)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .underWindowBackground)

            HStack(spacing: 0) {
                SidebarView(store: store)
                    .frame(width: 246)

                Divider()

                LibraryView(store: store, columns: columns, pendingDelete: $pendingDelete)
                    .frame(minWidth: 460)

                Divider()

                PreviewPane(store: store, pendingDelete: $pendingDelete)
                    .frame(width: 340)
            }

            if let notice = store.captureNotice {
                CaptureNoticeView(notice: notice)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.captureNotice)
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
        .task {
            store.refresh()
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar)

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Screenshot Manager", systemImage: "camera.viewfinder")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Command + Option + 5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CaptureControlsView(store: store)

                VStack(spacing: 10) {
                    StatTile(title: "Indexed", value: "\(store.items.count)", icon: "square.grid.2x2")
                    StatTile(title: "Showing", value: "\(store.filteredItems.count)", icon: "line.3.horizontal.decrease.circle")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(store.folderURL.path(percentEncoded: false))
                        .font(.callout)
                        .lineLimit(3)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

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

                Spacer()

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

private struct CaptureControlsView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Capture")
                    .font(.headline)

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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: store.isCapturing)
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
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.16), value: value)
    }
}

private struct LibraryView: View {
    @ObservedObject var store: ScreenshotStore
    let columns: [GridItem]
    @Binding var pendingDelete: ScreenshotItem?

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
            .background(.bar)

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
                    .fill(Color(nsColor: .controlBackgroundColor))

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
                .font(.callout.weight(.medium))
                .lineLimit(1)

            HStack {
                Text(item.createdAt, style: .date)
                Spacer()
                Text(item.dimensionsText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(isSelected ? 0.5 : 0.25), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

private struct PreviewPane: View {
    @ObservedObject var store: ScreenshotStore
    @Binding var pendingDelete: ScreenshotItem?

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow)

            if let item = store.selectedItem {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Preview")
                        .font(.title2.weight(.semibold))

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))

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

                    VStack(alignment: .leading, spacing: 8) {
                        MetadataRow(title: "Name", value: item.fileName)
                        MetadataRow(title: "Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        MetadataRow(title: "Dimensions", value: item.dimensionsText)
                        MetadataRow(title: "File size", value: item.displaySize)
                    }

                    HStack {
                        Button {
                            store.open(item)
                        } label: {
                            Label("Open", systemImage: "arrow.up.right.square")
                        }

                        Button {
                            store.copy(item)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }

                    HStack {
                        Button {
                            store.revealInFinder(item)
                        } label: {
                            Label("Finder", systemImage: "folder")
                        }

                        Button(role: .destructive) {
                            pendingDelete = item
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    Spacer()
                }
                .padding(20)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
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
