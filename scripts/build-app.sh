#!/bin/bash
set -euo pipefail

# Build DevPing.app bundle
# Usage: ./scripts/build-app.sh [--release]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG="debug"
SWIFT_FLAGS=""
if [[ "${1:-}" == "--release" ]]; then
    CONFIG="release"
    SWIFT_FLAGS="-c release"
fi

echo "==> Building devping ($CONFIG)..."
cd "$PROJECT_DIR"
swift build $SWIFT_FLAGS 2>&1

# Locate the built binary
BINARY="$(swift build $SWIFT_FLAGS --show-bin-path)/devping"
if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi
echo "    Binary: $BINARY"

# Assemble .app bundle
APP_DIR="$PROJECT_DIR/build/DevPing.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Assembling DevPing.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$BINARY" "$MACOS/devping"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$CONTENTS/Info.plist"

# Copy app icon if it exists
if [[ -f "$PROJECT_DIR/Resources/DevPing.icns" ]]; then
    cp "$PROJECT_DIR/Resources/DevPing.icns" "$RESOURCES/DevPing.icns"
    # Inject icon key into Info.plist if not present
    if ! grep -q "CFBundleIconFile" "$CONTENTS/Info.plist"; then
        sed -i '' 's|</dict>|    <key>CFBundleIconFile</key>\n    <string>DevPing</string>\n</dict>|' "$CONTENTS/Info.plist"
    fi
fi

# Sign (ad-hoc for local use)
echo "==> Signing (ad-hoc)..."
codesign --force --sign - "$APP_DIR" 2>&1 || echo "    Warning: codesign failed (non-fatal for local dev)"

echo ""
echo "==> DevPing.app built successfully!"
echo "    Location: $APP_DIR"
echo ""
echo "    To install:"
echo "      cp -R $APP_DIR /Applications/"
echo ""
echo "    To run:"
echo "      open $APP_DIR"
