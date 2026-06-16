import AppKit
import Foundation
import ImageIO
import ServiceManagement
import SwiftUI

@MainActor
final class ScreenshotStore: ObservableObject {
    @Published private(set) var items: [ScreenshotItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isCapturing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var captureNotice: CaptureNotice?
    @Published private(set) var screenRecordingAccessGranted = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published var selectedItem: ScreenshotItem?
    @Published var searchText = ""
    @Published private(set) var clipboardHotkey: AppHotkey
    @Published private(set) var saveHotkey: AppHotkey
    @Published private(set) var folderURL: URL

    private let folderDefaultsKey = "ScreenshotManager.folderURL"
    private let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "webp"]
    private var noticeClearTask: Task<Void, Never>?
    private var captureEditorWindowController: NSWindowController?

    var hotkeysDidChange: (() -> Void)?

    var filteredItems: [ScreenshotItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return items
        }

        return items.filter { item in
            item.fileName.localizedCaseInsensitiveContains(query)
                || item.captureKind.displayName.localizedCaseInsensitiveContains(query)
                || item.createdAt.formatted(date: .abbreviated, time: .omitted).localizedCaseInsensitiveContains(query)
                || item.modifiedAt.formatted(date: .abbreviated, time: .shortened).localizedCaseInsensitiveContains(query)
        }
    }

    init() {
        let legacyHotkey = AppHotkey.load()
        clipboardHotkey = AppHotkey.load(named: "clipboard", fallback: legacyHotkey)
        saveHotkey = AppHotkey.load(named: "save", fallback: .defaultSaveValue)

        let defaultFolderURL = Self.defaultScreenshotFolder()

        if let savedPath = UserDefaults.standard.string(forKey: folderDefaultsKey),
           !Self.isDesktopFolder(URL(filePath: savedPath)) {
            folderURL = URL(filePath: savedPath)
        } else {
            folderURL = defaultFolderURL
            UserDefaults.standard.set(defaultFolderURL.path(percentEncoded: false), forKey: folderDefaultsKey)
        }

        refreshScreenRecordingAccess()
        refreshLaunchAtLoginStatus()
    }

    func updateClipboardHotkey(_ hotkey: AppHotkey) {
        guard clipboardHotkey != hotkey else {
            return
        }

        clipboardHotkey = hotkey
        hotkey.save(named: "clipboard")
        hotkeysDidChange?()
        showNotice(
            title: "Copy Hotkey Updated",
            detail: hotkey.displayString,
            systemImage: "keyboard",
            tone: .success
        )
    }

    func updateSaveHotkey(_ hotkey: AppHotkey) {
        guard saveHotkey != hotkey else {
            return
        }

        saveHotkey = hotkey
        hotkey.save(named: "save")
        hotkeysDidChange?()
        showNotice(
            title: "Library Hotkey Updated",
            detail: hotkey.displayString,
            systemImage: "keyboard",
            tone: .success
        )
    }

    func refresh(selecting selectedURL: URL? = nil) {
        isLoading = true
        errorMessage = nil

        let folderURL = folderURL
        let imageExtensions = imageExtensions

        Task.detached(priority: .userInitiated) {
            do {
                let scannedItems = try Self.scanFolder(folderURL, imageExtensions: imageExtensions)
                await MainActor.run {
                    self.items = scannedItems
                    if let selectedURL {
                        self.selectedItem = scannedItems.first { $0.url == selectedURL } ?? scannedItems.first
                    } else {
                        self.selectedItem = self.selectedItem.flatMap { selected in
                            scannedItems.first(where: { $0.id == selected.id })
                        } ?? scannedItems.first
                    }
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

    func captureToClipboard() {
        runOverlayCapture(mode: .clipboard)
    }

    func captureAndSaveToLibrary() {
        runOverlayCapture(mode: .save)
    }

    func refreshScreenRecordingAccess() {
        screenRecordingAccessGranted = ScreenCaptureOverlayController.hasScreenCaptureAccess
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }

            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            errorMessage = error.localizedDescription
            showNotice(
                title: "Startup Setting Failed",
                detail: error.localizedDescription,
                systemImage: "exclamationmark.triangle",
                tone: .failure
            )
        }
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
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

    func revealLibraryFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
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

    func copyEditedImage(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func saveEditedCopy(_ image: NSImage, source item: ScreenshotItem) {
        do {
            let savedURL = try ImageEditingService.saveCopy(image, sourceURL: item.url)
            refresh(selecting: savedURL)
        } catch {
            errorMessage = error.localizedDescription
            showNotice(
                title: "Save Failed",
                detail: error.localizedDescription,
                systemImage: "exclamationmark.triangle",
                tone: .failure
            )
        }
    }

    func replaceImage(_ image: NSImage, item: ScreenshotItem) {
        do {
            try ImageEditingService.write(image, to: item.url)
            refresh(selecting: item.url)
        } catch {
            errorMessage = error.localizedDescription
            showNotice(
                title: "Replace Failed",
                detail: error.localizedDescription,
                systemImage: "exclamationmark.triangle",
                tone: .failure
            )
        }
    }

    func delete(_ item: ScreenshotItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showHotkeyRegistrationFailed(_ hotkey: AppHotkey, name: String) {
        let message = "Could not register \(name) hotkey \(hotkey.displayString). Try another shortcut."
        errorMessage = message
        showNotice(
            title: "Hotkey Unavailable",
            detail: message,
            systemImage: "keyboard.badge.eye",
            tone: .failure
        )
    }

    func finishAnnotatedCapture(_ image: NSImage, mode: CaptureMode) {
        switch mode {
        case .clipboard:
            do {
                let url = try ScreenshotCaptureService.save(image, in: folderURL, kind: .clipboard)
                refresh(selecting: url)
            } catch {
                errorMessage = error.localizedDescription
                showNotice(
                    title: "Library Write Failed",
                    detail: error.localizedDescription,
                    systemImage: "exclamationmark.triangle",
                    tone: .failure
                )
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            closeCaptureEditor()
        case .save:
            do {
                let url = try ScreenshotCaptureService.save(image, in: folderURL, kind: .saved)
                refresh(selecting: url)
                closeCaptureEditor()
            } catch {
                errorMessage = error.localizedDescription
                showNotice(
                    title: "Save Failed",
                    detail: error.localizedDescription,
                    systemImage: "exclamationmark.triangle",
                    tone: .failure
                )
            }
        }
    }

    func closeCaptureEditor() {
        captureEditorWindowController?.close()
        captureEditorWindowController = nil
    }

    private func runOverlayCapture(mode: CaptureMode) {
        guard !isCapturing else {
            return
        }

        refreshScreenRecordingAccess()

        isCapturing = true
        errorMessage = nil
        let hiddenWindows = hideVisibleAppWindowsForCapture()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)

            ScreenCaptureOverlayController.shared.start { [weak self] result in
                guard let self else {
                    return
                }

                isCapturing = false

                switch result {
                case .success(let image):
                    handleCapturedImage(image, mode: mode)
                case .failure(let error) where error is CancellationError:
                    restoreAppWindows(hiddenWindows)
                    showNotice(
                        title: "Capture Cancelled",
                        detail: "No changes made",
                        systemImage: "xmark.circle",
                        tone: .neutral
                    )
                case .failure(let error):
                    restoreAppWindows(hiddenWindows)
                    errorMessage = error.localizedDescription
                    showNotice(
                        title: "Capture Failed",
                        detail: error.localizedDescription,
                        systemImage: "exclamationmark.triangle",
                        tone: .failure
                    )
                }
            }
        }
    }

    private func handleCapturedImage(_ image: NSImage, mode: CaptureMode) {
        showCaptureEditor(image: image, mode: mode)
    }

    private func showCaptureEditor(image: NSImage, mode: CaptureMode) {
        closeCaptureEditor()

        let session = CaptureAnnotationSession(image: image, mode: mode)
        let contentView = CaptureAnnotationView(store: self, session: session)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Annotate"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.minSize = NSSize(width: 920, height: 620)
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        captureEditorWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideVisibleAppWindowsForCapture() -> [NSWindow] {
        let windows = NSApp.windows.filter { window in
            window.isVisible && window.level == .normal
        }
        windows.forEach { $0.orderOut(nil) }
        return windows
    }

    private func restoreAppWindows(_ windows: [NSWindow]) {
        guard !windows.isEmpty else {
            return
        }

        windows.forEach { $0.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showNotice(title: String, detail: String, systemImage: String, tone: CaptureNotice.Tone) {
        noticeClearTask?.cancel()
        captureNotice = CaptureNotice(title: title, detail: detail, systemImage: systemImage, tone: tone)

        noticeClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            guard !Task.isCancelled else {
                return
            }

            captureNotice = nil
        }
    }

    private static func defaultScreenshotFolder() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")

        return applicationSupportURL
            .appending(path: "Screenshot Manager", directoryHint: .isDirectory)
            .appending(path: "Captures", directoryHint: .isDirectory)
    }

    private static func isDesktopFolder(_ url: URL) -> Bool {
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
        return url.standardizedFileURL.path(percentEncoded: false) == desktopURL.standardizedFileURL.path(percentEncoded: false)
    }

    nonisolated private static func scanFolder(_ folderURL: URL, imageExtensions: Set<String>) throws -> [ScreenshotItem] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey]
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

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
                captureKind: CaptureKind.detect(from: url.lastPathComponent),
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

enum CaptureMode {
    case clipboard
    case save
}

struct CaptureAnnotationSession: Identifiable {
    let id = UUID()
    let image: NSImage
    let mode: CaptureMode
}

struct CaptureNotice: Identifiable, Equatable {
    enum Tone: Equatable {
        case success
        case neutral
        case failure
    }

    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tone: Tone
}
