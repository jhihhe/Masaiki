#!/usr/bin/env bash
# Generate an Xcode project for the iOS app, then archive & export an .ipa
# for App Store submission.
#
# Requirements:
#   - Xcode 15+
#   - XcodeGen: `brew install xcodegen`
#   - Automatic signing set up in Xcode with your Apple Developer team
#
# Env:
#   DEVELOPMENT_TEAM        10-char team id, e.g. ABCDE12345
#   BUNDLE_ID               e.g. com.example.masaiki (must match provisioning)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/iOS"
BUILD_DIR="$ROOT/build/ios"
ARCHIVE_PATH="$BUILD_DIR/Masaiki.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

: "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM}"
: "${BUNDLE_ID:=com.example.masaiki}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Generating Xcode project via XcodeGen"
(cd "$IOS_DIR" && xcodegen generate)

echo "==> Archiving"
xcodebuild -project "$IOS_DIR/Masaiki.xcodeproj" \
    -scheme Masaiki \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    archive

echo "==> Writing export options"
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

echo "==> Exporting IPA"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

echo "==> Done: $EXPORT_PATH/Masaiki.ipa"
echo "Next: upload via Transporter or:"
echo "  xcrun altool --upload-app -f '$EXPORT_PATH/Masaiki.ipa' -t ios -u \"\$APPLE_ID\" -p \"\$APPLE_APP_SPECIFIC_PWD\""
