#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/dist/DiskPulse.app"
INFO_PLIST="$APP/Contents/Info.plist"
APP_BINARY="$APP/Contents/MacOS/DiskPulseApp"

if [ ! -d "$APP" ]; then
    echo "error: $APP not found. Run 'make app' or ./scripts/build-app.sh first." >&2
    exit 1
fi

if [ ! -f "$INFO_PLIST" ]; then
    echo "error: $INFO_PLIST not found." >&2
    exit 1
fi

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
if [ -z "$VERSION" ]; then
    echo "error: CFBundleShortVersionString is missing from Info.plist." >&2
    exit 1
fi

ARCHS="$(/usr/bin/lipo -archs "$APP_BINARY" 2>/dev/null || true)"
if [ -z "$ARCHS" ]; then
    ARCHS="$(/usr/bin/uname -m)"
fi

ARCH_COUNT="$(printf '%s\n' "$ARCHS" | /usr/bin/wc -w | /usr/bin/tr -d ' ')"
if [ "$ARCH_COUNT" -gt 1 ]; then
    ARCH="universal"
else
    ARCH="$(printf '%s\n' "$ARCHS" | /usr/bin/awk '{print $1}')"
fi

DMG_NAME="DiskPulse-${VERSION}-macos-${ARCH}.dmg"
DMG_PATH="$ROOT/dist/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"
STAGING="$(/usr/bin/mktemp -d "$ROOT/dist/dmg-staging.XXXXXX")"

cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

echo "==> Preparing DiskPulse $VERSION ($ARCH)"
/usr/bin/ditto "$APP" "$STAGING/DiskPulse.app"
/bin/ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH" "$CHECKSUM_PATH"

echo "==> Creating $DMG_NAME"
/usr/bin/hdiutil create \
    -volname "DiskPulse $VERSION" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

(
    cd "$ROOT/dist"
    /usr/bin/shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

echo "Created  $DMG_PATH"
echo "Checksum $CHECKSUM_PATH"
