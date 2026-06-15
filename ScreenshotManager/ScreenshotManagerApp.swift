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
                LabeledContent("Global hotkey") {
                    HotkeyRecorderView(
                        hotkey: Binding(
                            get: { store.hotkey },
                            set: { store.updateHotkey($0) }
                        )
                    )
                    .frame(width: 220, height: 34)
                }
                LabeledContent("Default capture", value: "Clipboard only")
                LabeledContent("Saved captures", value: "Capture & Save writes to the indexed folder")
                LabeledContent("Indexed folder", value: store.folderURL.path(percentEncoded: false))
            }
        }
        .formStyle(.grouped)
        .font(AppTypography.itemTitle)
        .padding(24)
        .frame(width: 520)
    }
}
