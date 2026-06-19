#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/ScreenshotManager.xcodeproj"
SCHEME="ScreenshotManager"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/ScreenshotManager-dev}"

BUNDLE_ID="com.herpojmi365.screenshotmanager"
BUILD_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/ScreenshotManager.app"
INSTALL_APP="/Applications/Screenshot Manager.app"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-Screenshot Manager Local Development}"

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$BUILD_APP" ]]; then
  echo "Build app was not found: $BUILD_APP" >&2
  exit 1
fi

echo "Stopping running copies..."
/usr/bin/osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 &
QUIT_PROCESS_ID=$!
sleep 0.35
/bin/kill "$QUIT_PROCESS_ID" >/dev/null 2>&1 || true
wait "$QUIT_PROCESS_ID" >/dev/null 2>&1 || true
/usr/bin/pkill -9 -x "ScreenshotManager" >/dev/null 2>&1 || true
/usr/bin/pkill -9 -x "Screenshot Manager" >/dev/null 2>&1 || true
sleep 0.4

while read -r PROCESS_ID PARENT_PROCESS_ID COMMAND; do
  if [[ "$COMMAND" == "$HOME"/Library/Developer/Xcode/DerivedData/*/ScreenshotManager.app/Contents/MacOS/ScreenshotManager ]]; then
    /bin/kill -9 "$PROCESS_ID" >/dev/null 2>&1 || true
    if [[ "$PARENT_PROCESS_ID" != "1" ]]; then
      /bin/kill -9 "$PARENT_PROCESS_ID" >/dev/null 2>&1 || true
    fi
  fi
done < <(/bin/ps ax -o pid=,ppid=,comm=)

echo "Installing fresh build to $INSTALL_APP..."
if [[ -d "$INSTALL_APP" ]]; then
  EXISTING_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$INSTALL_APP/Contents/Info.plist" 2>/dev/null || true)
  if [[ -n "$EXISTING_BUNDLE_ID" && "$EXISTING_BUNDLE_ID" != "$BUNDLE_ID" ]]; then
    echo "Refusing to replace $INSTALL_APP because it has bundle id: $EXISTING_BUNDLE_ID" >&2
    exit 1
  fi
fi

/bin/rm -rf "$INSTALL_APP"
/usr/bin/ditto "$BUILD_APP" "$INSTALL_APP"

if ! /usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
  if [[ -x "$ROOT/scripts/create-local-signing-identity.sh" ]]; then
    CODESIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/create-local-signing-identity.sh"
  fi
fi

if /usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
  echo "Signing installed app with $SIGN_IDENTITY..."
  /usr/bin/codesign \
    --force \
    --deep \
    --timestamp=none \
    --sign "$SIGN_IDENTITY" \
    "$INSTALL_APP"
else
  echo "Warning: signing identity not found: $SIGN_IDENTITY" >&2
  echo "The app will keep Xcode's ad-hoc signature, so Screen Recording may reset after rebuilds." >&2
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  echo "Registering app with LaunchServices..."
  "$LSREGISTER" -f -R -trusted "$INSTALL_APP" >/dev/null 2>&1 || true
fi

echo "Opening $INSTALL_APP..."
/usr/bin/open "$INSTALL_APP"

echo "Done. Screen Recording 'Quit and Reopen' will now relaunch this installed build."
