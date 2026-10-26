#!/bin/bash
# Builds, signs and notarizes SpotKeys, and packages it as a DMG anyone can install.
#
# Needs a "Developer ID Application" identity in the keychain and notarization credentials, either
#   NOTARY_PROFILE                                    a profile saved with `xcrun notarytool store-credentials`
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID  an App Store Connect API key
#
# Usage: VERSION=1.2.0 scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

export VERSION="${VERSION:?Set VERSION, e.g. VERSION=1.2.0}"
export OUT_DIR="${OUT_DIR:-$HOME/Library/Caches/SpotKeys}"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning |
        awk -F'"' 'index($2, "Developer ID Application") == 1 { print $2; exit }')"
fi
[[ -n "$SIGN_IDENTITY" ]] || { echo "No Developer ID Application identity in the keychain" >&2; exit 1; }
export SIGN_IDENTITY

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
else
    NOTARY_AUTH=(--key "${NOTARY_KEY_PATH:?}" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER_ID:?}")
fi

./scripts/build.sh

APP="$OUT_DIR/SpotKeys.app"
DMG="$OUT_DIR/SpotKeys-$VERSION.dmg"
STAGING="$OUT_DIR/dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/SpotKeys.app"
ln -s /Applications "$STAGING/Applications"

# hdiutil occasionally fails with "Resource busy" on CI machines.
for attempt in 1 2 3; do
    hdiutil create -volname SpotKeys -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" && break
    [[ $attempt == 3 ]] && exit 1
    sleep 5
done
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "Notarizing ${DMG}..."
RESULT="$(xcrun notarytool submit "$DMG" "${NOTARY_AUTH[@]}" --wait --output-format json)"
STATUS="$(plutil -extract status raw -o - - <<< "$RESULT")"
if [[ "$STATUS" != "Accepted" ]]; then
    xcrun notarytool log "$(plutil -extract id raw -o - - <<< "$RESULT")" "${NOTARY_AUTH[@]}" >&2
    echo "Notarization failed: $STATUS" >&2
    exit 1
fi
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

echo "Released $DMG"
