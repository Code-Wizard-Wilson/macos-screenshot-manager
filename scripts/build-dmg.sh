#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/ScreenshotManager.xcodeproj"
SCHEME="ScreenshotManager"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/build/DerivedData-dmg}"
BUILD_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/ScreenshotManager.app"
APP_NAME="Screenshot Manager"
STAGING_DIR="$ROOT/build/dmg-staging"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
DMG_PATH="${DMG_PATH:-$DIST_DIR/$APP_NAME.dmg}"
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

echo "Preparing DMG staging folder..."
/bin/rm -rf "$STAGING_DIR"
/bin/mkdir -p "$STAGING_DIR" "$DIST_DIR"
/usr/bin/ditto "$BUILD_APP" "$STAGING_DIR/$APP_NAME.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"

if ! /usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
  if [[ -x "$ROOT/scripts/create-local-signing-identity.sh" ]]; then
    CODESIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/create-local-signing-identity.sh"
  fi
fi

if /usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
  echo "Signing $APP_NAME.app with $SIGN_IDENTITY..."
  /usr/bin/codesign \
    --force \
    --deep \
    --timestamp=none \
    --sign "$SIGN_IDENTITY" \
    "$STAGING_DIR/$APP_NAME.app"
else
  echo "Warning: signing identity not found: $SIGN_IDENTITY" >&2
  echo "Using ad-hoc signing; macOS privacy permissions may reset between builds." >&2
  /usr/bin/codesign \
    --force \
    --deep \
    --timestamp=none \
    --sign - \
    "$STAGING_DIR/$APP_NAME.app"
fi

echo "Creating $DMG_PATH..."
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Done: $DMG_PATH"
