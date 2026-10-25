#!/bin/zsh
# Builds MenuNote in Release, ad-hoc signs it, and zips it for a GitHub release.
#
# Usage: ./make-release.sh
# Output: dist/MenuNote-<version>.zip
#
# The app is ad-hoc signed (no Apple Developer ID), so users must approve it on first
# launch via System Settings › Privacy & Security › Open Anyway.

set -euo pipefail
cd "${0:A:h}"

PROJECT=MenuNote.xcodeproj
SCHEME=MenuNote
BUILD_DIR=build/release
DIST_DIR=dist

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION = / { print $2; exit }')
BUILD_NUMBER=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ CURRENT_PROJECT_VERSION = / { print $2; exit }')
ZIP="$DIST_DIR/MenuNote-$VERSION.zip"

echo "==> Building MenuNote $VERSION ($BUILD_NUMBER)"
rm -rf "$BUILD_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    clean build -quiet

APP="$BUILD_DIR/Build/Products/Release/MenuNote.app"

echo "==> Verifying signature"
codesign --verify --deep --strict "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q app-sandbox \
    || { echo "error: app is missing the sandbox entitlement" >&2; exit 1; }

echo "==> Zipping"
mkdir -p "$DIST_DIR"
rm -f "$ZIP"
# ditto preserves the bundle's symlinks and signature; plain `zip` can break them.
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $ZIP"
echo "    SHA-256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
