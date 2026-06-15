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

        GlobalHotkeyManager.shared.registerDefaultHotkey { [weak self] in
            self?.toggleWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.unregister()
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

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screenshot Manager")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Manager", action: #selector(openManager), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Refresh Library", action: #selector(refreshLibrary), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
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
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 980, height: 620)
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

