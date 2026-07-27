#!/usr/bin/env bash
# Sign and package Masaiki.app for Mac App Store submission (.pkg).
#
# Required environment variables:
#   MAS_APPLICATION_CERT   e.g. "3rd Party Mac Developer Application: Your Name (TEAMID)"
#                          or on newer accounts: "Apple Distribution: Your Name (TEAMID)"
#   MAS_INSTALLER_CERT     e.g. "3rd Party Mac Developer Installer: Your Name (TEAMID)"
#   PROVISIONING_PROFILE   path to embedded.provisionprofile downloaded from Apple Developer portal
#   APPLE_ID / APPLE_APP_SPECIFIC_PWD / APPLE_TEAM_ID  (for altool/notarytool upload; optional)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT/build/Masaiki.app"
PKG_PATH="$ROOT/build/Masaiki.pkg"
ENTITLEMENTS="$ROOT/Sources/Masaiki/Resources/Masaiki.entitlements"

: "${MAS_APPLICATION_CERT:?set MAS_APPLICATION_CERT}"
: "${MAS_INSTALLER_CERT:?set MAS_INSTALLER_CERT}"
: "${PROVISIONING_PROFILE:?set PROVISIONING_PROFILE to a .provisionprofile path}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE does not exist. Run scripts/build_macos.sh first." >&2
    exit 1
fi

echo "==> Embedding provisioning profile"
cp "$PROVISIONING_PROFILE" "$APP_BUNDLE/Contents/embedded.provisionprofile"

echo "==> Codesigning app for MAS (sandbox + hardened runtime)"
find "$APP_BUNDLE/Contents" -type f \( -name "*.dylib" -o -name "*.framework" \) -print0 |
    xargs -0 -I{} codesign --force --options runtime --timestamp \
        --sign "$MAS_APPLICATION_CERT" "{}" || true

codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$MAS_APPLICATION_CERT" \
    "$APP_BUNDLE"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> Building signed installer .pkg"
productbuild \
    --component "$APP_BUNDLE" /Applications \
    --sign "$MAS_INSTALLER_CERT" \
    "$PKG_PATH"

echo "==> Done: $PKG_PATH"
echo ""
echo "Next: submit to App Store Connect with either:"
echo "  1) Transporter.app (drag $PKG_PATH into it), or"
echo "  2) xcrun altool --upload-app -f '$PKG_PATH' \\"
echo "       -t osx -u \"\$APPLE_ID\" -p \"\$APPLE_APP_SPECIFIC_PWD\""
