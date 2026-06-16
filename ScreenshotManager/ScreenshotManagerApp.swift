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
            Section("General") {
                Toggle(
                    "Open at login",
                    isOn: Binding(
                        get: { store.launchAtLoginEnabled },
                        set: { store.updateLaunchAtLogin($0) }
                    )
                )

                LabeledContent("Library folder") {
                    HStack(spacing: 8) {
                        Text(store.folderURL.path(percentEncoded: false))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose") {
                            store.chooseFolder()
                        }

                        Button {
                            store.revealLibraryFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Reveal in Finder")
                    }
                }
            }

            Section("Hotkeys") {
                LabeledContent("Capture to clipboard") {
                    HotkeyRecorderView(
                        hotkey: Binding(
                            get: { store.clipboardHotkey },
                            set: { store.updateClipboardHotkey($0) }
                        )
                    )
                    .frame(width: 220, height: 34)
                }

                LabeledContent("Capture to library") {
                    HotkeyRecorderView(
                        hotkey: Binding(
                            get: { store.saveHotkey },
                            set: { store.updateSaveHotkey($0) }
                        )
                    )
                    .frame(width: 220, height: 34)
                }
            }

            Section("Permissions") {
                LabeledContent("Screen Recording") {
                    HStack(spacing: 10) {
                        Label(
                            store.screenRecordingAccessGranted ? "Allowed" : "Required",
                            systemImage: store.screenRecordingAccessGranted ? "checkmark.shield" : "lock.rectangle"
                        )
                        .foregroundStyle(store.screenRecordingAccessGranted ? .green : .orange)

                        Button("Open Settings") {
                            store.openScreenRecordingSettings()
                        }

                        Button("Refresh") {
                            store.refreshScreenRecordingAccess()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .font(AppTypography.itemTitle)
        .padding(24)
        .frame(width: 720, height: 620)
        .onAppear {
            store.refreshScreenRecordingAccess()
            store.refreshLaunchAtLoginStatus()
        }
    }
}
