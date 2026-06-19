import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ScreenshotStore()

    private var windowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
    private let clipboardHotkeyID: UInt32 = 1
    private let saveHotkeyID: UInt32 = 2

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        showWindow()
        registerGlobalHotkeys()

        store.hotkeysDidChange = { [weak self] in
            self?.registerGlobalHotkeys()
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            store.requestRequiredPermissions()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.unregister()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        store.refreshRequiredPermissions()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func openManagerWindow() {
        showWindow()
    }

    func openSettingsWindow() {
        let window = currentSettingsWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func registerGlobalHotkeys() {
        let didRegisterClipboard = GlobalHotkeyManager.shared.register(id: clipboardHotkeyID, hotkey: store.clipboardHotkey) { [weak self] in
            self?.store.captureToClipboard()
        }

        let didRegisterSave = GlobalHotkeyManager.shared.register(id: saveHotkeyID, hotkey: store.saveHotkey) { [weak self] in
            self?.store.captureAndSaveToLibrary()
        }

        if !didRegisterClipboard {
            store.showHotkeyRegistrationFailed(store.clipboardHotkey, name: "copy")
        }

        if !didRegisterSave {
            store.showHotkeyRegistrationFailed(store.saveHotkey, name: "library")
        }
    }

    private func makeWindow() -> NSWindow {
        let contentView = ContentView(store: store) { [weak self] in
            self?.openSettingsWindow()
        }
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Screenshot Manager"
        window.titleVisibility = .hidden
        window.identifier = NSUserInterfaceItemIdentifier("ScreenshotManager.MainWindow")
        window.titlebarAppearsTransparent = false
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.hasShadow = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 920, height: 580)
        window.contentViewController = hostingController
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller

        return window
    }

    private func makeSettingsWindow() -> NSWindow {
        let contentView = SettingsView(store: store)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Screenshot Manager Settings"
        window.titleVisibility = .hidden
        window.identifier = NSUserInterfaceItemIdentifier("ScreenshotManager.SettingsWindow")
        window.titlebarAppearsTransparent = false
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.hasShadow = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 760, height: 480)
        window.contentViewController = hostingController
        window.center()

        let controller = NSWindowController(window: window)
        settingsWindowController = controller

        return window
    }

    private func currentWindow() -> NSWindow {
        windowController?.window ?? makeWindow()
    }

    private func currentSettingsWindow() -> NSWindow {
        settingsWindowController?.window ?? makeSettingsWindow()
    }

    private func showWindow() {
        let window = currentWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toggleWindow() {
        let window = currentWindow()

        if window.isVisible, NSApp.isActive {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }
}
