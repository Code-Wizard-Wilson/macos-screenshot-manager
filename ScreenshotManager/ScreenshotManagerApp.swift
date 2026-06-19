import AppKit
import SwiftUI

@main
struct ScreenshotManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Screenshot Manager", systemImage: "camera.viewfinder") {
            MenuBarPanelView(
                store: appDelegate.store,
                openManager: {
                    appDelegate.openManagerWindow()
                },
                openSettings: {
                    appDelegate.openSettingsWindow()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPanelView: View {
    @ObservedObject var store: ScreenshotStore
    let openManager: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void
    @AppStorage(AppPreferenceKeys.didCompleteOnboarding) private var didCompleteOnboarding = false
    @State private var didAnimateIn = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BrandMarkView(isActive: store.isCapturing)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Screenshot Manager")
                        .font(AppTypography.productTitle)

                    Text(statusText)
                        .font(AppTypography.helper)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Button(action: openManager) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(AppTheme.sidebarIconBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(AppTheme.softBorder, lineWidth: 1)
                }
                .help("Open Manager")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .menuBarFlyIn(didAnimateIn, delay: 0)

            Divider()

            VStack(spacing: 8) {
                MenuBarCaptureButton(
                    title: "Clipboard",
                    detail: store.clipboardHotkey.displayString,
                    systemImage: "doc.on.clipboard",
                    tint: AppTheme.libraryAmber,
                    isDisabled: store.isCapturing
                ) {
                    store.captureToClipboard()
                }

                MenuBarCaptureButton(
                    title: "Library",
                    detail: store.saveHotkey.displayString,
                    systemImage: "tray.and.arrow.down",
                    tint: AppTheme.successGreen,
                    isDisabled: store.isCapturing
                ) {
                    store.captureAndSaveToLibrary()
                }
            }
            .padding(12)
            .menuBarFlyIn(didAnimateIn, delay: 0.035)

            if !store.requiredPermissionsGranted {
                Divider()

                MenuBarPermissionView(store: store)
                    .padding(12)
                    .menuBarFlyIn(didAnimateIn, delay: 0.07)
            }

            Divider()

            HStack(spacing: 8) {
                MenuBarSecondaryButton(title: "\(store.items.count) item\(store.items.count == 1 ? "" : "s")", systemImage: "photo.stack") {
                    openManager()
                }

                MenuBarSecondaryButton(title: "Refresh", systemImage: "arrow.clockwise") {
                    store.refresh()
                }

                MenuBarSecondaryButton(title: "Guide", systemImage: "questionmark.circle") {
                    didCompleteOnboarding = false
                    openManager()
                }
            }
            .padding(12)
            .menuBarFlyIn(didAnimateIn, delay: 0.105)

            HStack(spacing: 8) {
                Button(action: openSettings) {
                    MenuBarSecondaryLabel(title: "Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)

                MenuBarSecondaryButton(title: "Quit", systemImage: "power") {
                    quit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .menuBarFlyIn(didAnimateIn, delay: 0.14)

            Divider()
        }
        .frame(width: 304)
        .background(AppTheme.windowBackground)
        .onAppear {
            store.refreshRequiredPermissions()
            didAnimateIn = false

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                    didAnimateIn = true
                }
            }
        }
    }

    private var statusText: String {
        if store.isCapturing {
            return "Capture in progress"
        }

        return store.requiredPermissionsGranted ? "Ready to capture" : "Permissions needed"
    }

    private var statusColor: Color {
        if store.isCapturing {
            return AppTheme.libraryAmber
        }

        return store.requiredPermissionsGranted ? AppTheme.successGreen : AppTheme.dangerCoral
    }
}

private struct MenuBarCaptureButton: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.itemTitle)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .offset(x: isHovering ? 2 : 0)
            }
            .padding(10)
            .frame(height: 54)
            .background(isHovering ? AppTheme.cardHoverBackground : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovering ? tint.opacity(0.55) : AppTheme.softBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering && !isDisabled ? 1.012 : 1)
        .animation(.easeInOut(duration: 0.13), value: isHovering)
    }
}

private struct MenuBarPermissionView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "lock.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.dangerCoral)

                Text("\(store.missingRequiredPermissionText) required")
                    .font(AppTypography.itemTitle)
            }

            Text("Allow required access in System Settings, then quit and reopen the app.")
                .font(AppTypography.helper)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Request") {
                    store.requestRequiredPermissions()
                }

                Button("Refresh") {
                    store.refreshRequiredPermissions()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.dangerCoral.opacity(0.38), lineWidth: 1)
        }
    }
}

private struct MenuBarSecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MenuBarSecondaryLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

private struct MenuBarSecondaryLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14)

            Text(title)
                .font(AppTypography.helper.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(AppTheme.sidebarIconBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(AppTheme.softBorder, lineWidth: 1)
        }
    }
}

private struct MenuBarFlyInModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : -10)
            .scaleEffect(isVisible ? 1 : 0.985, anchor: .top)
            .animation(.spring(response: 0.28, dampingFraction: 0.82).delay(delay), value: isVisible)
    }
}

private extension View {
    func menuBarFlyIn(_ isVisible: Bool, delay: Double) -> some View {
        modifier(MenuBarFlyInModifier(isVisible: isVisible, delay: delay))
    }
}

struct SettingsView: View {
    @ObservedObject var store: ScreenshotStore
    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        TabView(selection: $selectedSection) {
            ScrollView {
                generalSection
                    .frame(maxWidth: 580, alignment: .topLeading)
                    .padding(26)
            }
            .tabItem { Label("General", systemImage: SettingsSection.general.icon) }
            .tag(SettingsSection.general)

            ScrollView {
                hotkeysSection
                    .frame(maxWidth: 580, alignment: .topLeading)
                    .padding(26)
            }
            .tabItem { Label("Hotkeys", systemImage: SettingsSection.hotkeys.icon) }
            .tag(SettingsSection.hotkeys)

            ScrollView {
                permissionsSection
                    .frame(maxWidth: 580, alignment: .topLeading)
                    .padding(26)
            }
            .tabItem { Label("Permissions", systemImage: SettingsSection.permissions.icon) }
            .tag(SettingsSection.permissions)
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 400, idealHeight: 480)
        .font(AppTypography.itemTitle)
        .onAppear {
            store.refreshRequiredPermissions()
            store.refreshLaunchAtLoginStatus()
        }
    }

    private var generalSection: some View {
        SettingsPanel(title: "General") {
            SettingsRow(
                icon: "power",
                title: "Open at login",
                detail: "Start Screenshot Manager automatically."
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.launchAtLoginEnabled },
                        set: { store.updateLaunchAtLogin($0) }
                    )
                )
                .labelsHidden()
            }

            SettingsDivider()

            SettingsRow(
                icon: "folder",
                title: "Library folder",
                detail: store.folderURL.path(percentEncoded: false)
            ) {
                HStack(spacing: 8) {
                    Button("Choose") {
                        store.chooseFolder()
                    }

                    Button {
                        store.revealLibraryFolder()
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .help("Reveal in Finder")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var hotkeysSection: some View {
        SettingsPanel(title: "Hotkeys") {
            SettingsRow(
                icon: "doc.on.clipboard",
                title: "Capture to clipboard",
                detail: "Copy the edited capture and keep it in the library."
            ) {
                HotkeyRecorderView(
                    hotkey: Binding(
                        get: { store.clipboardHotkey },
                        set: { store.updateClipboardHotkey($0) }
                    )
                )
                .frame(width: 260, height: 34)
            }

            SettingsDivider()

            SettingsRow(
                icon: "tray.and.arrow.down",
                title: "Capture to library",
                detail: "Save the edited capture as a permanent file."
            ) {
                HotkeyRecorderView(
                    hotkey: Binding(
                        get: { store.saveHotkey },
                        set: { store.updateSaveHotkey($0) }
                    )
                )
                .frame(width: 260, height: 34)
            }

        }
    }

    private var permissionsSection: some View {
        SettingsPanel(title: "Permissions") {
            SettingsRow(
                icon: store.requiredPermissionsGranted ? "checkmark.shield" : "lock.rectangle",
                title: "Required permissions",
                detail: store.requiredPermissionsGranted
                    ? "Everything needed for capture is active."
                    : "Missing: \(store.missingRequiredPermissionText)."
            ) {
                HStack(spacing: 8) {
                    Button("Request All") {
                        store.requestRequiredPermissions()
                    }

                    Button("Refresh") {
                        store.refreshRequiredPermissions()
                    }
                }
                .buttonStyle(.bordered)
            }

            SettingsDivider()

            SettingsRow(
                icon: store.screenRecordingAccessGranted ? "checkmark.shield" : "lock.rectangle",
                title: "Screen Recording",
                detail: store.screenRecordingAccessGranted
                    ? "Screenshot Manager can capture the screen."
                    : "Allow access in System Settings, then restart the app."
            ) {
                HStack(spacing: 8) {
                    Button("Open Settings") {
                        store.openScreenRecordingSettings()
                    }

                    Button("Refresh") {
                        store.refreshScreenRecordingAccess()
                    }
                }
                .buttonStyle(.bordered)
            }

        }
    }
}

private enum SettingsSection: CaseIterable {
    case general
    case hotkeys
    case permissions

    var title: String {
        switch self {
        case .general:
            return "General"
        case .hotkeys:
            return "Hotkeys"
        case .permissions:
            return "Permissions"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .hotkeys:
            return "keyboard"
        case .permissions:
            return "lock.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .general:
            return AppTheme.settingsViolet
        case .hotkeys:
            return AppTheme.libraryAmber
        case .permissions:
            return AppTheme.captureBlue
        }
    }
}


private struct SettingsPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTypography.sectionTitle)

            VStack(spacing: 0) {
                content
            }
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.softBorder, lineWidth: 1)
            }
        }
    }
}

private struct SettingsRow<Controls: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder var controls: Controls

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))

                Text(detail)
                    .font(AppTypography.helper)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 20)

            controls
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 62)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 50)
    }
}
