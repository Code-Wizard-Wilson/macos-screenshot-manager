import AppKit
import SwiftUI

enum AppTypography {
    static let productTitle = Font.system(size: 20, weight: .semibold, design: .default)
    static let sectionTitle = Font.system(size: 14, weight: .semibold, design: .default)
    static let paneTitle = Font.system(size: 22, weight: .semibold, design: .default)
    static let itemTitle = Font.system(size: 13, weight: .medium, design: .default)
    static let metadata = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let helper = Font.system(size: 12, weight: .regular, design: .default)
}

enum AppTheme {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let contentBackground = Color(nsColor: .textBackgroundColor)
    static let toolbarBackground = Color(nsColor: .controlBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let imageWellBackground = Color(nsColor: .underPageBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.55)
    static let softBorder = Color(nsColor: .separatorColor).opacity(0.32)
    static let selectedBackground = Color.accentColor.opacity(0.12)
}
