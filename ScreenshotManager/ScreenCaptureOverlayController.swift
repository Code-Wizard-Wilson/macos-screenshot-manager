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
        let windowTargets = Self.captureWindowTargets()
        windows = NSScreen.screens.map { screen in
            let window = ScreenCaptureOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            let overlayView = ScreenCaptureOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            overlayView.windowTargets = windowTargets
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

    private static func captureWindowTargets() -> [CaptureWindowTarget] {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier

        return windowInfo.compactMap { info in
            let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            guard ownerPID != currentPID else {
                return nil
            }

            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard layer == 0 else {
                return nil
            }

            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            guard alpha > 0.05 else {
                return nil
            }

            guard let boundsValue = info[kCGWindowBounds as String],
                  let cgBounds = CGRect(dictionaryRepresentation: boundsValue as! CFDictionary) else {
                return nil
            }

            let frame = appKitRect(fromCoreGraphicsWindowBounds: cgBounds)
            guard frame.width >= 80, frame.height >= 60 else {
                return nil
            }

            let title = info[kCGWindowName as String] as? String
            let appName = info[kCGWindowOwnerName as String] as? String
            return CaptureWindowTarget(frame: frame, title: title?.isEmpty == false ? title : appName)
        }
    }

    private static func appKitRect(fromCoreGraphicsWindowBounds rect: CGRect) -> NSRect {
        let desktopFrame = NSScreen.screens.reduce(NSRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }

        return NSRect(
            x: rect.minX,
            y: desktopFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

}

fileprivate struct CaptureWindowTarget {
    let frame: NSRect
    let title: String?
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
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hasShadow = false
    }
}

final class ScreenCaptureOverlayView: NSView {
    var onComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    fileprivate var windowTargets: [CaptureWindowTarget] = []

    private var dragStart: NSPoint?
    private var selectionRect: NSRect = .zero
    private var hoveredWindowTarget: CaptureWindowTarget?
    private var pressedWindowTarget: CaptureWindowTarget?
    private var trackingArea: NSTrackingArea?

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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoveredWindow(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        hoveredWindowTarget = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = event.locationInWindow
        updateHoveredWindow(at: point)
        dragStart = point
        pressedWindowTarget = hoveredWindowTarget
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else {
            return
        }

        let currentPoint = event.locationInWindow
        let distance = hypot(currentPoint.x - dragStart.x, currentPoint.y - dragStart.y)

        if distance > 4 {
            pressedWindowTarget = nil
            selectionRect = normalizedRect(from: dragStart, to: currentPoint)
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let dragStart else {
            onCancel?()
            return
        }

        let endPoint = event.locationInWindow
        let distance = hypot(endPoint.x - dragStart.x, endPoint.y - dragStart.y)
        selectionRect = normalizedRect(from: dragStart, to: endPoint)
        self.dragStart = nil

        if distance >= 8, selectionRect.width >= 8, selectionRect.height >= 8 {
            onComplete?(selectionRect)
            return
        }

        if let target = pressedWindowTarget ?? target(at: endPoint),
           let rect = localCaptureRect(for: target) {
            onComplete?(rect)
            return
        }

        onCancel?()
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
            drawSelection(selectionRect, title: nil)
        } else if let hoveredWindowTarget,
                  let rect = localCaptureRect(for: hoveredWindowTarget) {
            drawSelection(rect, title: hoveredWindowTarget.title)
        }

        drawHint()
    }

    private func updateHoveredWindow(at point: NSPoint) {
        guard dragStart == nil else {
            return
        }

        hoveredWindowTarget = target(at: point)
        needsDisplay = true
    }

    private func target(at localPoint: NSPoint) -> CaptureWindowTarget? {
        guard let window else {
            return nil
        }

        let globalPoint = NSPoint(
            x: window.frame.minX + localPoint.x,
            y: window.frame.minY + localPoint.y
        )

        return windowTargets.first { target in
            target.frame.contains(globalPoint) && target.frame.intersects(window.frame)
        }
    }

    private func localCaptureRect(for target: CaptureWindowTarget) -> NSRect? {
        guard let window else {
            return nil
        }

        let localRect = NSRect(
            x: target.frame.minX - window.frame.minX,
            y: target.frame.minY - window.frame.minY,
            width: target.frame.width,
            height: target.frame.height
        )
        let clipped = localRect.intersection(bounds)

        guard !clipped.isNull, clipped.width >= 8, clipped.height >= 8 else {
            return nil
        }

        return clipped
    }

    private func drawSelection(_ rect: NSRect, title: String?) {
        NSColor.white.withAlphaComponent(0.08).setFill()
        rect.fill()

        let path = NSBezierPath(rect: rect)
        NSColor.white.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 1.5
        path.stroke()

        guard let title, !title.isEmpty else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.96)
        ]
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        let titleSize = attributedTitle.size()
        let titleRect = NSRect(
            x: rect.minX + 8,
            y: min(rect.maxY - titleSize.height - 8, bounds.maxY - titleSize.height - 12),
            width: min(titleSize.width, max(40, rect.width - 16)),
            height: titleSize.height
        )
        attributedTitle.draw(in: titleRect)
    }

    private func drawHint() {
        let text = "Click a highlighted window or drag an area. Esc cancels."
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
