import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ScreenshotStore()

    private var windowController: NSWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureStatusItem()
        showWindow()
        registerGlobalHotkey()

        store.hotkeyDidChange = { [weak self] _ in
            self?.registerGlobalHotkey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.unregister()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        store.refreshScreenRecordingAccess()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    @objc private func openManager() {
        showWindow()
    }

    @objc private func refreshLibrary() {
        store.refresh()
    }

    @objc private func captureToClipboard() {
        store.captureToClipboard()
    }

    @objc private func captureAndSave() {
        store.captureAndSaveToLibrary()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screenshot Manager")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture to Clipboard", action: #selector(captureToClipboard), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Capture & Save", action: #selector(captureAndSave), keyEquivalent: "s"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Manager", action: #selector(openManager), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Refresh Library", action: #selector(refreshLibrary), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }

    private func registerGlobalHotkey() {
        let didRegister = GlobalHotkeyManager.shared.register(hotkey: store.hotkey) { [weak self] in
            self?.store.captureToClipboard()
        }

        if !didRegister {
            store.showHotkeyRegistrationFailed(store.hotkey)
        }
    }

    private func makeWindow() -> NSWindow {
        let contentView = ContentView(store: store)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Screenshot Manager"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 520)
        window.contentViewController = hostingController
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller

        return window
    }

    private func currentWindow() -> NSWindow {
        windowController?.window ?? makeWindow()
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
