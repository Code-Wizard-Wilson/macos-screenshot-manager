import Foundation

struct ScreenshotItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let fileName: String
    let captureKind: CaptureKind
    let createdAt: Date
    let modifiedAt: Date
    let byteSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    var dimensionsText: String {
        guard pixelWidth > 0, pixelHeight > 0 else {
            return "Unknown size"
        }

        return "\(pixelWidth)x\(pixelHeight)"
    }
}

enum CaptureKind: String, Sendable {
    case clipboard
    case saved

    var displayName: String {
        switch self {
        case .clipboard:
            return "Copied"
        case .saved:
            return "Saved"
        }
    }

    var systemImage: String {
        switch self {
        case .clipboard:
            return "doc.on.clipboard"
        case .saved:
            return "tray.and.arrow.down"
        }
    }

    var filePrefix: String {
        switch self {
        case .clipboard:
            return "Copied"
        case .saved:
            return "Saved"
        }
    }

    static func detect(from fileName: String) -> CaptureKind {
        if fileName.hasPrefix("\(CaptureKind.clipboard.filePrefix) ") {
            return .clipboard
        }

        return .saved
    }
}
