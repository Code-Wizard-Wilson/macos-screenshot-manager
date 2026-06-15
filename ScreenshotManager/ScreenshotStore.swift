import AppKit
import Foundation
import ImageIO

@MainActor
final class ScreenshotStore: ObservableObject {
    @Published private(set) var items: [ScreenshotItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedItem: ScreenshotItem?
    @Published var searchText = ""
    @Published private(set) var folderURL: URL

    private let folderDefaultsKey = "ScreenshotManager.folderURL"
    private let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "webp"]

    var filteredItems: [ScreenshotItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return items
        }

        return items.filter { item in
            item.fileName.localizedCaseInsensitiveContains(query)
                || item.createdAt.formatted(date: .abbreviated, time: .omitted).localizedCaseInsensitiveContains(query)
                || item.modifiedAt.formatted(date: .abbreviated, time: .shortened).localizedCaseInsensitiveContains(query)
        }
    }

    init() {
        if let savedPath = UserDefaults.standard.string(forKey: folderDefaultsKey) {
            folderURL = URL(filePath: savedPath)
        } else {
            folderURL = Self.defaultScreenshotFolder()
        }
    }

    func refresh() {
        isLoading = true
        errorMessage = nil

        let folderURL = folderURL
        let imageExtensions = imageExtensions

        Task.detached(priority: .userInitiated) {
            do {
                let scannedItems = try Self.scanFolder(folderURL, imageExtensions: imageExtensions)
                await MainActor.run {
                    self.items = scannedItems
                    self.selectedItem = self.selectedItem.flatMap { selected in
                        scannedItems.first(where: { $0.id == selected.id })
                    } ?? scannedItems.first
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.items = []
                    self.selectedItem = nil
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Screenshot Folder"
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = folderURL

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        folderURL = url
        UserDefaults.standard.set(url.path(percentEncoded: false), forKey: folderDefaultsKey)
        refresh()
    }

    func open(_ item: ScreenshotItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealInFinder(_ item: ScreenshotItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func copy(_ item: ScreenshotItem) {
        guard let image = NSImage(contentsOf: item.url) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func delete(_ item: ScreenshotItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func defaultScreenshotFolder() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
    }

    nonisolated private static func scanFolder(_ folderURL: URL, imageExtensions: Set<String>) throws -> [ScreenshotItem] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        return urls.compactMap { url in
            guard imageExtensions.contains(url.pathExtension.lowercased()) else {
                return nil
            }

            guard let resourceValues = try? url.resourceValues(forKeys: keys),
                  resourceValues.isRegularFile == true else {
                return nil
            }

            let dimensions = imageDimensions(url: url)
            let createdAt = resourceValues.creationDate ?? resourceValues.contentModificationDate ?? .distantPast
            let modifiedAt = resourceValues.contentModificationDate ?? createdAt
            let byteSize = Int64(resourceValues.fileSize ?? 0)

            return ScreenshotItem(
                id: url.path(percentEncoded: false),
                url: url,
                fileName: url.lastPathComponent,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                byteSize: byteSize,
                pixelWidth: dimensions.width,
                pixelHeight: dimensions.height
            )
        }
        .sorted { left, right in
            left.createdAt > right.createdAt
        }
    }

    nonisolated private static func imageDimensions(url: URL) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (0, 0)
        }

        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        return (width, height)
    }
}
