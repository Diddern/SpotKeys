#!/bin/bash
# Builds an Apple Silicon SpotKeys.app and prints its path.
# Set SIGN_IDENTITY to a code signing identity to avoid re-granting permissions after every build.
set -euo pipefail
cd "$(dirname "$0")/.."

# Build outside iCloud Drive: iCloud tags files with extended attributes that codesign rejects.
OUT_DIR="${OUT_DIR:-$HOME/Library/Caches/SpotKeys}"
SWIFT_FLAGS=(-c release --arch arm64 --scratch-path "$OUT_DIR/build")
APP="$OUT_DIR/SpotKeys.app"

swift build "${SWIFT_FLAGS[@]}"
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SpotKeys" "$APP/Contents/MacOS/SpotKeys"
cp Resources/Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
