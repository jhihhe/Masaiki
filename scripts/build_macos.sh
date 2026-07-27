#!/usr/bin/env bash
# Build Masaiki as a Universal Binary (arm64 + x86_64) macOS .app bundle
# from a Swift Package. Requires: Xcode Command Line Tools, macOS 13+ SDK.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_NAME="Masaiki"
BUNDLE_ID="com.example.masaiki"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

CONFIG=release

echo "==> Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building arm64"
swift build -c "$CONFIG" --arch arm64 --package-path "$ROOT"

echo "==> Building x86_64"
swift build -c "$CONFIG" --arch x86_64 --package-path "$ROOT"

ARM64_BIN=$(swift build -c "$CONFIG" --arch arm64 --package-path "$ROOT" --show-bin-path)/"$APP_NAME"
X86_64_BIN=$(swift build -c "$CONFIG" --arch x86_64 --package-path "$ROOT" --show-bin-path)/"$APP_NAME"

echo "==> Assembling .app bundle at $APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==> Creating Universal Binary via lipo"
lipo -create "$ARM64_BIN" "$X86_64_BIN" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "==> Copying Info.plist / PrivacyInfo.xcprivacy"
cp "$ROOT/Sources/Masaiki/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/Sources/Masaiki/Resources/PrivacyInfo.xcprivacy" "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"

echo "==> Building AppIcon.icns"
if [ -d "$ROOT/Resources/AppIcon.iconset" ]; then
    iconutil -c icns "$ROOT/Resources/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_BUNDLE/Contents/Info.plist"
fi

echo "==> Verifying architectures"
file "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
lipo -info "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "==> Done. App bundle: $APP_BUNDLE"
