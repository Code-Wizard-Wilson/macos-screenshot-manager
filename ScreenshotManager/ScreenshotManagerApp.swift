import SwiftUI

@main
struct ScreenshotManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.store)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: ScreenshotStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Global hotkey", value: "Command + Option + 5")
                LabeledContent("Default capture", value: "Clipboard only")
                LabeledContent("Saved captures", value: "Capture & Save writes to the indexed folder")
                LabeledContent("Indexed folder", value: store.folderURL.path(percentEncoded: false))
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 520)
    }
}
