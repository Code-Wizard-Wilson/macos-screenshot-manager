import Foundation

struct ScreenshotItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let fileName: String
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

