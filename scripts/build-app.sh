#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
APP="$ROOT/dist/DiskPulse.app"
IDENTITY="${CODESIGN_IDENTITY:--}"

cd "$ROOT"

echo "==> Building DiskPulse app and CLI ($CONFIG)"
swift build -c "$CONFIG" --product DiskPulseApp
swift build -c "$CONFIG" --product diskpulse

BIN="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/DiskPulseApp" "$APP/Contents/MacOS/DiskPulseApp"
cp "$BIN/diskpulse" "$APP/Contents/Resources/diskpulse"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

xattr -cr "$APP"

echo "==> Signing with identity: $IDENTITY"
if [ "$IDENTITY" = "-" ]; then
    codesign --force --deep --sign - "$APP"
else
    codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi

echo "==> Built $APP"
