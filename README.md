# Screenshot Manager

[English](README.md) · [Русский](README.ru.md) · [简体中文](README.zh-CN.md)

A native macOS screenshot manager for fast capture, annotation, clipboard workflows, and a local screenshot library.

![Library view](docs/screenshots/library.png)

## Features

- Global hotkeys for clipboard capture and library capture
- Area and window capture overlay
- Smooth annotation editor with crop, resize, arrows, shapes, pen, text, blur, and background styling
- Color and position picker inside the capture overlay
- Clipboard-first flow for quick screenshots
- Optional library flow for saved screenshots
- Searchable local screenshot library
- Quick preview, copy, edit, reveal in Finder, and delete actions
- OCR text recognition with copyable text selection
- Native Settings window for hotkeys, permissions, launch behavior, and menu bar visibility
- Local-first design with no telemetry

## Screenshots

| Library | Menu Bar |
| --- | --- |
| ![Screenshot library](docs/screenshots/library.png) | ![Menu bar controls](docs/screenshots/menubar.png) |

| Settings | Editor |
| --- | --- |
| ![Settings](docs/screenshots/settings.png) | ![Annotation editor](docs/screenshots/editor.png) |

## Requirements

- macOS 14 or newer
- Xcode 16 or newer for local builds
- Screen Recording permission for capture

Some features, such as text recognition, use native Apple frameworks available on macOS.

## Build

Open `ScreenshotManager.xcodeproj` in Xcode, or build from the terminal:

```bash
xcodebuild -project ScreenshotManager.xcodeproj -scheme ScreenshotManager -configuration Debug build
```

## Install A Local Debug Build

The helper script builds the app, installs it to `/Applications/Screenshot Manager.app`, signs it with a local development identity, and opens it:

```bash
./scripts/install-debug-app.sh
```

This keeps macOS privacy permissions attached to the installed app instead of random DerivedData builds.

## Create A DMG

```bash
./scripts/build-dmg.sh
```

The DMG is written to:

```text
dist/Screenshot Manager.dmg
```

For public distribution, sign and notarize with an Apple Developer ID certificate. The included local signing helper is only for development builds.

## Permissions

Screenshot Manager needs Screen Recording permission to capture the screen. The app checks permission before starting capture and opens the correct System Settings page when access is missing.

## Privacy

Screenshots stay local. The app does not include analytics, telemetry, remote logging, or network upload code.

## License

MIT License. See [LICENSE](LICENSE).
