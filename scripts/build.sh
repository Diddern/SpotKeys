#!/bin/bash
# Builds an Apple Silicon SpotKeys.app.
#
# Signs with SIGN_IDENTITY if set, otherwise with the first "Developer ID Application" or
# "Apple Development" identity in the keychain, falling back to an ad-hoc signature.
# Set VERSION (e.g. 1.2.0) to stamp the version into the app.
set -euo pipefail
cd "$(dirname "$0")/.."

# Build outside iCloud Drive: iCloud tags files with extended attributes that codesign rejects.
OUT_DIR="${OUT_DIR:-$HOME/Library/Caches/SpotKeys}"
SWIFT_FLAGS=(-c release --arch arm64 --scratch-path "$OUT_DIR/build")
APP="$OUT_DIR/SpotKeys.app"

find_identity() {
    security find-identity -v -p codesigning | awk -F'"' -v kind="$1" 'index($2, kind) == 1 { print $2; exit }'
}
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY="$(find_identity "Developer ID Application")"
    [[ -n "$SIGN_IDENTITY" ]] || SIGN_IDENTITY="$(find_identity "Apple Development")"
    [[ -n "$SIGN_IDENTITY" ]] || SIGN_IDENTITY="-"
fi

swift build "${SWIFT_FLAGS[@]}"
mkdir -p "$OUT_DIR/icon"
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SpotKeys" "$APP/Contents/MacOS/SpotKeys"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
# Liquid Glass icon for macOS 26+. Needs Xcode; older systems fall back to AppIcon.icns.
if ! xcrun actool Resources/AppIcon.icon --compile "$OUT_DIR/icon" --platform macosx \
        --minimum-deployment-target 13.0 --app-icon AppIcon \
        --output-partial-info-plist "$OUT_DIR/icon/partial.plist" >/dev/null 2>&1; then
    echo "actool unavailable, using AppIcon.icns only"
else
    cp "$OUT_DIR/icon/Assets.car" "$APP/Contents/Resources/Assets.car"
fi

if [[ -n "${VERSION:-}" ]]; then
    # VERSION ends up in a PlistBuddy command, so only accept plain version numbers.
    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION: $VERSION" >&2; exit 1; }
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" \
        -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
fi

xattr -cr "$APP"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    TIMESTAMP=--timestamp=none
else
    TIMESTAMP=--timestamp
fi
codesign --force --options runtime "$TIMESTAMP" --entitlements Resources/SpotKeys.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP (signed with: $([[ "$SIGN_IDENTITY" == "-" ]] && echo ad-hoc || echo "$SIGN_IDENTITY"))"
