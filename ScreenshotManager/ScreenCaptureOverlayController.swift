import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenCaptureOverlayController {
    static let shared = ScreenCaptureOverlayController()

    private var windows: [ScreenCaptureOverlayWindow] = []
    private var completion: ((Result<NSImage, Error>) -> Void)?

    private init() {}

    static var hasScreenCaptureAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func start(completion: @escaping (Result<NSImage, Error>) -> Void) {
        cancel()

        self.completion = completion
        windows = NSScreen.screens.map { screen in
            let window = ScreenCaptureOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            let overlayView = ScreenCaptureOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            overlayView.onComplete = { [weak self, weak window] localRect in
                guard let window else {
                    self?.finish(.failure(ScreenCaptureOverlayError.captureFailed))
                    return
                }

                self?.capture(localRect: localRect, in: window)
            }
            overlayView.onCancel = { [weak self] in
                self?.finish(.failure(CancellationError()))
            }

            window.contentView = overlayView
            return window
        }

        windows.forEach { window in
            window.makeKeyAndOrderFront(nil)
        }
    }

    func cancel() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        completion = nil
    }

    private func capture(localRect: NSRect, in window: NSWindow) {
        let globalRect = NSRect(
            x: window.frame.minX + localRect.minX,
            y: window.frame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )

        windows.forEach { $0.orderOut(nil) }
        windows = []

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)

            do {
                let image = try await Self.captureImage(
                    localRect: localRect,
                    screen: window.screen,
                    fallbackGlobalRect: globalRect
                )
                finish(.success(image))
            } catch {
                finish(.failure(error))
            }
        }
    }

    private func finish(_ result: Result<NSImage, Error>) {
        windows.forEach { $0.orderOut(nil) }
        windows = []

        let completion = completion
        self.completion = nil
        completion?(result)
    }

    private static func coreGraphicsRect(from rect: NSRect) -> CGRect {
        let desktopFrame = NSScreen.screens.reduce(NSRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }

        return CGRect(
            x: rect.minX,
            y: desktopFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private static func captureImage(localRect: NSRect, screen: NSScreen?, fallbackGlobalRect: NSRect) async throws -> NSImage {
        if #available(macOS 14.0, *), let screen {
            return try await screenCaptureKitImage(localRect: localRect, screen: screen)
        }

        let globalRect = fallbackGlobalRect
        let captureRect = coreGraphicsRect(from: globalRect)

        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw ScreenCaptureOverlayError.captureFailed
        }

        return NSImage(cgImage: cgImage, size: globalRect.size)
    }

    @available(macOS 14.0, *)
    private static func screenCaptureKitImage(localRect: NSRect, screen: NSScreen) async throws -> NSImage {
        let content = try await SCShareableContent.current
        let screenDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let displayID = screenDisplayID.map { CGDirectDisplayID($0.uint32Value) }
        let displayForScreen = displayID.flatMap { id in
            content.displays.first { $0.displayID == id }
        }

        guard let display = displayForScreen ?? content.displays.first(where: { $0.frame.intersects(screen.frame) }) else {
            throw ScreenCaptureOverlayError.captureFailed
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }

        let scale = screen.backingScaleFactor
        let fullWidth = max(1, Int(round(screen.frame.width * scale)))
        let fullHeight = max(1, Int(round(screen.frame.height * scale)))
        let configuration = SCStreamConfiguration()
        configuration.width = fullWidth
        configuration.height = fullHeight
        configuration.scalesToFit = false
        configuration.showsCursor = false

        let displayImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let cropRect = pixelCropRect(localRect: localRect, scale: scale, imageSize: CGSize(width: displayImage.width, height: displayImage.height), screenSize: screen.frame.size)

        guard let croppedImage = displayImage.cropping(to: cropRect) else {
            throw ScreenCaptureOverlayError.captureFailed
        }

        return NSImage(cgImage: croppedImage, size: localRect.size)
    }

    private static func pixelCropRect(localRect: NSRect, scale: CGFloat, imageSize: CGSize, screenSize: CGSize) -> CGRect {
        let rect = CGRect(
            x: localRect.minX * scale,
            y: (screenSize.height - localRect.maxY) * scale,
            width: localRect.width * scale,
            height: localRect.height * scale
        ).integral

        let bounds = CGRect(origin: .zero, size: imageSize)
        let clipped = rect.intersection(bounds)

        if clipped.isNull || clipped.width < 1 || clipped.height < 1 {
            return bounds
        }

        return clipped
    }

}

final class ScreenCaptureOverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        configure()
    }

    convenience init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool,
        screen: NSScreen
    ) {
        self.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setFrame(screen.frame, display: true)
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hasShadow = false
    }
}

final class ScreenCaptureOverlayView: NSView {
    var onComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragStart: NSPoint?
    private var selectionRect: NSRect = .zero

    override var acceptsFirstResponder: Bool {
        true
    }

    override var isFlipped: Bool {
        false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else {
            return
        }

        selectionRect = normalizedRect(from: dragStart, to: event.locationInWindow)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let dragStart else {
            onCancel?()
            return
        }

        selectionRect = normalizedRect(from: dragStart, to: event.locationInWindow)
        self.dragStart = nil

        guard selectionRect.width >= 8, selectionRect.height >= 8 else {
            onCancel?()
            return
        }

        onComplete?(selectionRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()

        if selectionRect != .zero {
            NSColor.white.withAlphaComponent(0.08).setFill()
            selectionRect.fill()

            let path = NSBezierPath(rect: selectionRect)
            NSColor.white.withAlphaComponent(0.95).setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        drawHint()
    }

    private func drawHint() {
        let text = "Drag to capture. Esc to cancel."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let size = attributedText.size()
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.maxY - size.height - 28,
            width: size.width,
            height: size.height
        )
        attributedText.draw(in: rect)
    }

    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(start.x - end.x),
            height: abs(start.y - end.y)
        )
    }
}

enum ScreenCaptureOverlayError: LocalizedError {
    case captureFailed
    case screenRecordingPermissionRequired

    var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "Could not capture the selected area."
        case .screenRecordingPermissionRequired:
            return "Screen Recording access is not active. Allow Screenshot Manager in System Settings, then quit and reopen the app."
        }
    }
}
