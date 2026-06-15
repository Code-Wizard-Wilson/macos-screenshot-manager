# macOS Screenshot Manager

Native macOS screenshot manager built with SwiftUI and AppKit.

## MVP

- Global hotkey: `Command + Option + 5`
- Polished native screenshot library
- Folder picker for screenshot/image folders
- Search by filename and date
- Large preview pane
- Quick actions: open, reveal in Finder, copy, delete
- Menu bar item for opening, refreshing, and quitting

## Stack

- SwiftUI for the main interface
- AppKit for windows, menu bar integration, file actions, and panels
- Carbon hotkey API for the global shortcut

## Build

Open `ScreenshotManager.xcodeproj` in Xcode or run:

```bash
xcodebuild -project ScreenshotManager.xcodeproj -scheme ScreenshotManager -configuration Debug build
```

