#!/usr/bin/env bash
#
# make-release-dmg.sh, build a Release Capax, bundle the iOS tools, ad-hoc sign, and produce a
# distributable Capax.dmg.
#
# Open-source build: no paid Apple Developer ID, so the app is *ad-hoc signed* and NOT notarized.
# Users clear Gatekeeper once (right-click → Open, or `xattr -dr com.apple.quarantine Capax.app`).
#
# Requires: Xcode, and `brew install libimobiledevice` (the tools to bundle).
# Usage: scripts/make-release-dmg.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="$(mktemp -d)"
APP="$BUILD_DIR/Build/Products/Release/Capax.app"
OUT="Capax.dmg"

echo "→ building Release"
xcodebuild -project Capax.xcodeproj -scheme Capax -configuration Release \
  -derivedDataPath "$BUILD_DIR" -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

echo "→ bundling iOS device tools"
scripts/bundle-idevice.sh "$APP"

echo "→ ad-hoc signing the app (with entitlements so bundled dylibs load)"
codesign --force --deep --options runtime \
  --entitlements Capax/Capax.entitlements --sign - "$APP"

echo "→ building $OUT"
rm -f "$OUT"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Capax -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null

echo "✓ $OUT  ($(du -h "$OUT" | cut -f1))"
echo "  Users: right-click → Open the first time (unsigned/open-source build),"
echo "  or run:  xattr -dr com.apple.quarantine /Applications/Capax.app"
