#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

APPLE_ID="${APPLE_ID:-naegele412@gmail.com}"
TEAM_ID="${TEAM_ID:-DTB456HJMJ}"
APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")
ARCHIVE="$PROJECT_DIR/build/DevPing-v${VERSION}.zip"
APP_PATH="$PROJECT_DIR/build/DevPing.app"

if [[ -z "$APP_SPECIFIC_PASSWORD" ]]; then
  echo "Missing APPLE_APP_SPECIFIC_PASSWORD in environment or .env"
  exit 1
fi

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Release archive not found at $ARCHIVE"
  echo "Run ./scripts/package-release.sh first."
  exit 1
fi

echo "==> Submitting for notarization..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "$ARCHIVE" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --wait 2>&1)
STATUS=$?
echo "$SUBMIT_OUTPUT"
if [[ $STATUS -ne 0 ]]; then
  exit $STATUS
fi

echo "==> Checking Gatekeeper status..."
spctl -a -t exec -vv "$APP_PATH" || true

echo "==> Done."
