#!/usr/bin/env bash
# Sign, package, and notarize Masaiki.app for Developer ID distribution
# (i.e. distributing outside the Mac App Store).
#
# For Mac App Store submission use scripts/export_appstore.sh instead.
#
# Required environment variables:
#   DEVELOPER_ID_APPLICATION  e.g. "Developer ID Application: Your Name (TEAMID)"
#   APPLE_ID                  Apple ID email used for notarization
#   APPLE_TEAM_ID             10-char team id, e.g. ABCDE12345
#   APPLE_APP_SPECIFIC_PWD    App-specific password for notarization
#   (or set APPLE_KEYCHAIN_PROFILE if you saved credentials with `notarytool store-credentials`)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT/build/Masaiki.app"
DMG_PATH="$ROOT/build/Masaiki.dmg"
ENTITLEMENTS="$ROOT/Sources/Masaiki/Resources/Masaiki.entitlements"

: "${DEVELOPER_ID_APPLICATION:?set DEVELOPER_ID_APPLICATION}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE does not exist. Run scripts/build_macos.sh first." >&2
    exit 1
fi

echo "==> Codesigning with hardened runtime + sandbox entitlements"
# Sign inner content first (any frameworks/dylibs), then the app bundle.
find "$APP_BUNDLE/Contents" -type f \( -name "*.dylib" -o -name "*.framework" \) -print0 |
    xargs -0 -I{} codesign --force --options runtime --timestamp \
        --sign "$DEVELOPER_ID_APPLICATION" "{}" || true

codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP_BUNDLE"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl --assess --type execute --verbose "$APP_BUNDLE" || true

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create -volname "Masaiki" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

echo "==> Notarizing DMG (this may take a few minutes)"
if [ -n "${APPLE_KEYCHAIN_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$APPLE_KEYCHAIN_PROFILE" \
        --wait
else
    : "${APPLE_ID:?set APPLE_ID}"
    : "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
    : "${APPLE_APP_SPECIFIC_PWD:?set APPLE_APP_SPECIFIC_PWD}"
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PWD" \
        --wait
fi

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler staple "$APP_BUNDLE"

echo "==> Done. Signed and notarized DMG: $DMG_PATH"
