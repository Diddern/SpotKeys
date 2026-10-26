#!/bin/bash
# Builds an Apple Silicon SpotKeys.app into ./build.
# Set SIGN_IDENTITY to a code signing identity to avoid re-granting permissions after every build.
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep SwiftPM's build cache out of iCloud Drive.
SCRATCH="${SCRATCH_PATH:-$HOME/Library/Caches/SpotKeys/build}"
SWIFT_FLAGS=(-c release --arch arm64 --scratch-path "$SCRATCH")
APP=build/SpotKeys.app

swift build "${SWIFT_FLAGS[@]}"
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SpotKeys" "$APP/Contents/MacOS/SpotKeys"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
