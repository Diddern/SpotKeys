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
mkdir -p "$OUT_DIR/icon"
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SpotKeys" "$APP/Contents/MacOS/SpotKeys"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Liquid Glass icon for macOS 26+. Needs Xcode; older systems fall back to AppIcon.icns.
if ! xcrun actool Resources/AppIcon.icon --compile "$OUT_DIR/icon" --platform macosx \
        --minimum-deployment-target 13.0 --app-icon AppIcon \
        --output-partial-info-plist "$OUT_DIR/icon/partial.plist" >/dev/null 2>&1; then
    echo "actool unavailable, using AppIcon.icns only"
else
    cp "$OUT_DIR/icon/Assets.car" "$APP/Contents/Resources/Assets.car"
fi
xattr -cr "$APP"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
