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
            .background(.thinMaterial)

            Divider()

            HStack(spacing: 0) {
                ZStack {
                    VisualEffectView(material: .underWindowBackground)

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
        .background(.ultraThinMaterial)
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
        .background(.ultraThinMaterial)
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
