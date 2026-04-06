#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

cd "$PROJECT_DIR"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
ARTIFACT="$BUILD_DIR/DevPing-v${VERSION}.zip"
SIGN_IDENTITY_DEFAULT="Developer ID Application: Andrew Naegele (DTB456HJMJ)"
SIGN_IDENTITY="${SIGN_IDENTITY:-$SIGN_IDENTITY_DEFAULT}"

SIGN_IDENTITY="$SIGN_IDENTITY" "$SCRIPT_DIR/build-app.sh" --release

rm -f "$ARTIFACT"
cd "$BUILD_DIR"
/usr/bin/zip -qry "$ARTIFACT" "DevPing.app"

echo "Created release artifact: $ARTIFACT"
echo "Signed with: $SIGN_IDENTITY"

echo "NOTE: Notarization is handled separately by scripts/notarize-release.sh"
