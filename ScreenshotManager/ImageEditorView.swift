import AppKit
import SwiftUI

struct ImageEditorView: View {
    @ObservedObject var store: ScreenshotStore
    let item: ScreenshotItem

    @Environment(\.dismiss) private var dismiss
    @State private var workingImage: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Edit Image")
                        .font(AppTypography.paneTitle)
                    Text(item.fileName)
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(AppTheme.toolbarBackground)

            Divider()

            HStack(spacing: 0) {
                ZStack {
                    AppTheme.contentBackground

                    if let workingImage {
                        Image(nsImage: workingImage)
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                    } else {
                        ContentUnavailableView("Image unavailable", systemImage: "photo")
                    }
                }
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                editorControls
                    .frame(width: 250)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(AppTheme.windowBackground)
        .onAppear {
            workingImage = NSImage(contentsOf: item.url)
        }
    }

    private var editorControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adjust")
                .font(AppTypography.sectionTitle)

            HStack {
                Button {
                    transform { ImageEditingService.rotate($0, clockwise: false) }
                } label: {
                    Label("Left", systemImage: "rotate.left")
                }

                Button {
                    transform { ImageEditingService.rotate($0, clockwise: true) }
                } label: {
                    Label("Right", systemImage: "rotate.right")
                }
            }

            Button {
                transform(ImageEditingService.flipHorizontal)
            } label: {
                Label("Flip Horizontal", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Divider()

            Button {
                guard let workingImage else {
                    return
                }
                store.copyEditedImage(workingImage)
            } label: {
                Label("Copy Result", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                guard let workingImage else {
                    return
                }
                store.saveEditedCopy(workingImage, source: item)
            } label: {
                Label("Save Copy", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                guard let workingImage else {
                    return
                }
                store.replaceImage(workingImage, item: item)
            } label: {
                Label("Replace Original", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(18)
        .background(AppTheme.sidebarBackground)
    }

    private func transform(_ operation: (NSImage) -> NSImage) {
        guard let workingImage else {
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            self.workingImage = operation(workingImage)
        }
    }
}

struct CaptureAnnotationView: View {
    @ObservedObject var store: ScreenshotStore
    let session: CaptureAnnotationSession

    @StateObject private var document: AnnotationDocument
    @State private var tool: AnnotationTool = .arrow
    @State private var selectedColor: AnnotationColor = .red
    @State private var textValue = "Text"

    init(store: ScreenshotStore, session: CaptureAnnotationSession) {
        self.store = store
        self.session = session
        _document = StateObject(wrappedValue: AnnotationDocument(image: session.image))
    }

    var body: some View {
        VStack(spacing: 0) {
            AnnotationCanvasView(
                document: document,
                tool: tool,
                color: selectedColor.nsColor,
                textValue: textValue
            )
            .background(AppTheme.contentBackground)

            Divider()

            annotationToolbar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.toolbarBackground)
        }
        .frame(minWidth: 920, minHeight: 620)
        .background(AppTheme.windowBackground)
    }

    private var annotationToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                toolButton(.arrow, icon: "arrow.up.right", title: "Arrow")
                toolButton(.line, icon: "line.diagonal", title: "Line")
                toolButton(.marker, icon: "highlighter", title: "Marker")
                toolButton(.text, icon: "textformat", title: "Text")
                toolButton(.mosaic, icon: "square.grid.3x3.fill", title: "Mosaic")

                Spacer(minLength: 12)

                Button {
                    document.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(document.annotations.isEmpty)
                .help("Undo")

                Button {
                    store.closeCaptureEditor()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Close")

                Button {
                    store.finishAnnotatedCapture(document.renderedImage(), mode: session.mode)
                } label: {
                    Image(systemName: "checkmark")
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.borderedProminent)
                .help("Done")
            }

            HStack(spacing: 10) {
                colorPicker

                if tool == .text {
                    TextField("Text", text: $textValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }

                Spacer()
            }
        }
    }

    private func toolButton(_ value: AnnotationTool, icon: String, title: String) -> some View {
        Button {
            tool = value
        } label: {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 26)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
        .background(tool == value ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }

    private var colorPicker: some View {
        HStack(spacing: 6) {
            ForEach(AnnotationColor.allCases) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .stroke(selectedColor == color ? Color.primary : AppTheme.softBorder, lineWidth: selectedColor == color ? 2 : 1)
                        }
                }
                .buttonStyle(.plain)
                .help(color.name)
            }
        }
    }
}

private enum AnnotationTool: CaseIterable {
    case arrow
    case line
    case marker
    case text
    case mosaic
}

private enum AnnotationColor: String, CaseIterable, Identifiable {
    case red
    case yellow
    case blue
    case green
    case white
    case black

    var id: String { rawValue }

    var name: String {
        rawValue.capitalized
    }

    var nsColor: NSColor {
        switch self {
        case .red:
            return .systemRed
        case .yellow:
            return .systemYellow
        case .blue:
            return .systemBlue
        case .green:
            return .systemGreen
        case .white:
            return .white
        case .black:
            return .black
        }
    }

    var color: Color {
        Color(nsColor: nsColor)
    }
}

private final class AnnotationDocument: ObservableObject {
    let image: NSImage
    @Published var annotations: [ImageAnnotation] = []

    init(image: NSImage) {
        self.image = image
    }

    func undo() {
        guard !annotations.isEmpty else {
            return
        }

        annotations.removeLast()
    }

    func renderedImage() -> NSImage {
        let output = NSImage(size: image.size)

        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: image.size), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)

        for annotation in annotations {
            annotation.draw(baseImage: image, scale: 1)
        }

        output.unlockFocus()
        return output
    }
}

private struct AnnotationCanvasView: NSViewRepresentable {
    @ObservedObject var document: AnnotationDocument
    let tool: AnnotationTool
    let color: NSColor
    let textValue: String

    func makeNSView(context: Context) -> AnnotationCanvasNSView {
        AnnotationCanvasNSView()
    }

    func updateNSView(_ nsView: AnnotationCanvasNSView, context: Context) {
        nsView.document = document
        nsView.tool = tool
        nsView.color = color
        nsView.textValue = textValue
        nsView.needsDisplay = true
    }
}

private final class AnnotationCanvasNSView: NSView {
    var document: AnnotationDocument? {
        didSet {
            needsDisplay = true
        }
    }
    var tool: AnnotationTool = .arrow
    var color: NSColor = .systemRed
    var textValue = "Text"

    private var dragStart: NSPoint?
    private var currentPoint: NSPoint?
    private var currentMarkerPoints: [NSPoint] = []

    override var acceptsFirstResponder: Bool {
        true
    }

    override var isFlipped: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        guard let imagePoint = imagePoint(for: event.locationInWindow) else {
            return
        }

        window?.makeFirstResponder(self)
        dragStart = imagePoint
        currentPoint = imagePoint
        currentMarkerPoints = [imagePoint]

        if tool == .text {
            let text = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let annotation = ImageAnnotation.text(
                text.isEmpty ? "Text" : text,
                imagePoint,
                color
            )
            document?.annotations.append(annotation)
            clearDraft()
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let imagePoint = imagePoint(for: event.locationInWindow), dragStart != nil else {
            return
        }

        currentPoint = imagePoint

        if tool == .marker {
            currentMarkerPoints.append(imagePoint)
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart,
              let end = imagePoint(for: event.locationInWindow) ?? currentPoint else {
            clearDraft()
            return
        }

        defer {
            clearDraft()
        }

        let distance = hypot(end.x - start.x, end.y - start.y)
        guard distance > 4 || tool == .marker else {
            return
        }

        switch tool {
        case .arrow:
            document?.annotations.append(.arrow(start, end, color))
        case .line:
            document?.annotations.append(.line(start, end, color))
        case .marker:
            guard currentMarkerPoints.count > 1 else {
                return
            }
            document?.annotations.append(.marker(currentMarkerPoints, color))
        case .mosaic:
            let rect = normalizedRect(from: start, to: end)
            guard rect.width > 6, rect.height > 6 else {
                return
            }
            document?.annotations.append(.mosaic(rect))
        case .text:
            break
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        guard let document else {
            return
        }

        let imageRect = fittedImageRect(for: document.image.size)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: imageRect).addClip()
        document.image.draw(in: imageRect, from: NSRect(origin: .zero, size: document.image.size), operation: .copy, fraction: 1)

        NSGraphicsContext.current?.cgContext.translateBy(x: imageRect.minX, y: imageRect.minY)
        NSGraphicsContext.current?.cgContext.scaleBy(
            x: imageRect.width / document.image.size.width,
            y: imageRect.height / document.image.size.height
        )

        for annotation in document.annotations {
            annotation.draw(baseImage: document.image, scale: 1)
        }

        drawDraft(baseImage: document.image)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawDraft(baseImage: NSImage) {
        guard let start = dragStart, let end = currentPoint else {
            return
        }

        switch tool {
        case .arrow:
            ImageAnnotation.arrow(start, end, color).draw(baseImage: baseImage, scale: 1)
        case .line:
            ImageAnnotation.line(start, end, color).draw(baseImage: baseImage, scale: 1)
        case .marker:
            ImageAnnotation.marker(currentMarkerPoints, color).draw(baseImage: baseImage, scale: 1)
        case .mosaic:
            ImageAnnotation.mosaic(normalizedRect(from: start, to: end)).draw(baseImage: baseImage, scale: 1)
        case .text:
            break
        }
    }

    private func imagePoint(for windowPoint: NSPoint) -> NSPoint? {
        guard let document else {
            return nil
        }

        let localPoint = convert(windowPoint, from: nil)
        let imageRect = fittedImageRect(for: document.image.size)

        guard imageRect.contains(localPoint) else {
            return nil
        }

        let scaleX = document.image.size.width / imageRect.width
        let scaleY = document.image.size.height / imageRect.height
        return NSPoint(
            x: (localPoint.x - imageRect.minX) * scaleX,
            y: (localPoint.y - imageRect.minY) * scaleY
        )
    }

    private func fittedImageRect(for imageSize: NSSize) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return bounds.insetBy(dx: 24, dy: 24)
        }

        let available = bounds.insetBy(dx: 24, dy: 24)
        let imageRatio = imageSize.width / imageSize.height
        let availableRatio = available.width / available.height

        if imageRatio > availableRatio {
            let height = available.width / imageRatio
            return NSRect(x: available.minX, y: available.midY - height / 2, width: available.width, height: height)
        }

        let width = available.height * imageRatio
        return NSRect(x: available.midX - width / 2, y: available.minY, width: width, height: available.height)
    }

    private func clearDraft() {
        dragStart = nil
        currentPoint = nil
        currentMarkerPoints = []
        needsDisplay = true
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

private enum ImageAnnotation {
    case arrow(NSPoint, NSPoint, NSColor)
    case line(NSPoint, NSPoint, NSColor)
    case marker([NSPoint], NSColor)
    case text(String, NSPoint, NSColor)
    case mosaic(NSRect)

    func draw(baseImage: NSImage, scale: CGFloat) {
        switch self {
        case .arrow(let start, let end, let color):
            drawLine(start: start, end: end, color: color, lineWidth: 4)
            drawArrowHead(start: start, end: end, color: color, lineWidth: 4)
        case .line(let start, let end, let color):
            drawLine(start: start, end: end, color: color, lineWidth: 4)
        case .marker(let points, let color):
            drawMarker(points: points, color: color)
        case .text(let text, let point, let color):
            drawText(text, at: point, color: color)
        case .mosaic(let rect):
            drawMosaic(rect: rect, baseImage: baseImage)
        }
    }

    private func drawLine(start: NSPoint, end: NSPoint, color: NSColor, lineWidth: CGFloat) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    private func drawArrowHead(start: NSPoint, end: NSPoint, color: NSColor, lineWidth: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 18
        let spread = CGFloat.pi / 7
        let left = NSPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread))
        let right = NSPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread))
        let path = NSBezierPath()
        path.move(to: left)
        path.line(to: end)
        path.line(to: right)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    private func drawMarker(points: [NSPoint], color: NSColor) {
        guard let first = points.first else {
            return
        }

        let path = NSBezierPath()
        path.move(to: first)
        points.dropFirst().forEach { path.line(to: $0) }
        path.lineWidth = 10
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.withAlphaComponent(0.72).setStroke()
        path.stroke()
    }

    private func drawText(_ text: String, at point: NSPoint, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: color,
            .strokeColor: NSColor.black.withAlphaComponent(0.45),
            .strokeWidth: -2
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        attributedText.draw(at: point)
    }

    private func drawMosaic(rect: NSRect, baseImage: NSImage) {
        guard rect.width > 2, rect.height > 2 else {
            return
        }

        let blockSize: CGFloat = 14
        let smallSize = NSSize(width: max(1, ceil(rect.width / blockSize)), height: max(1, ceil(rect.height / blockSize)))
        let pixelatedImage = NSImage(size: smallSize)

        pixelatedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .low
        baseImage.draw(
            in: NSRect(origin: .zero, size: smallSize),
            from: rect,
            operation: .copy,
            fraction: 1
        )
        pixelatedImage.unlockFocus()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.imageInterpolation = .none
        pixelatedImage.draw(
            in: rect,
            from: NSRect(origin: .zero, size: smallSize),
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        NSColor.black.withAlphaComponent(0.12).setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()
    }
}

enum ImageEditingService {
    static func rotate(_ image: NSImage, clockwise: Bool) -> NSImage {
        let sourceSize = image.size
        let targetSize = NSSize(width: sourceSize.height, height: sourceSize.width)
        let output = NSImage(size: targetSize)

        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        let transform = NSAffineTransform()
        if clockwise {
            transform.translateX(by: targetSize.width, yBy: 0)
            transform.rotate(byDegrees: 90)
        } else {
            transform.translateX(by: 0, yBy: targetSize.height)
            transform.rotate(byDegrees: -90)
        }
        transform.concat()

        image.draw(
            in: NSRect(origin: .zero, size: sourceSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1
        )
        output.unlockFocus()

        return output
    }

    static func flipHorizontal(_ image: NSImage) -> NSImage {
        let sourceSize = image.size
        let output = NSImage(size: sourceSize)

        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        let transform = NSAffineTransform()
        transform.translateX(by: sourceSize.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()

        image.draw(
            in: NSRect(origin: .zero, size: sourceSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1
        )
        output.unlockFocus()

        return output
    }

    static func saveCopy(_ image: NSImage, sourceURL: URL) throws -> URL {
        let destinationURL = uniqueEditedURL(for: sourceURL)
        try write(image, to: destinationURL)
        return destinationURL
    }

    static func write(_ image: NSImage, to url: URL) throws {
        let data = try imageData(for: image, url: url)
        try data.write(to: url, options: .atomic)
    }

    private static func imageData(for image: NSImage, url: URL) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageEditingError.renderFailed
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "jpg", "jpeg":
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
                throw ImageEditingError.renderFailed
            }
            return data
        case "tif", "tiff":
            guard let data = bitmap.representation(using: .tiff, properties: [:]) else {
                throw ImageEditingError.renderFailed
            }
            return data
        case "png":
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw ImageEditingError.renderFailed
            }
            return data
        default:
            throw ImageEditingError.unsupportedReplaceFormat
        }
    }

    private static func uniqueEditedURL(for sourceURL: URL) -> URL {
        let folderURL = sourceURL.deletingLastPathComponent()
        let baseName = "\(sourceURL.deletingPathExtension().lastPathComponent) Edited"
        var candidate = folderURL.appending(path: "\(baseName).png")
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = folderURL.appending(path: "\(baseName) \(suffix).png")
            suffix += 1
        }

        return candidate
    }
}

enum ImageEditingError: LocalizedError {
    case renderFailed
    case unsupportedReplaceFormat

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Could not render edited image."
        case .unsupportedReplaceFormat:
            return "This file type cannot be replaced directly. Use Save Copy."
        }
    }
}
