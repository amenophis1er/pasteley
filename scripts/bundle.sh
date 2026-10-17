#!/bin/sh
# Builds a release binary and wraps it into Pasteley.app at the repo root.
#
# Signing: the keychain remembers "Always Allow" per code identity, and an ad-hoc
# signature changes on every build. So we sign with a stable identity by default:
# SIGN_IDENTITY env var, else the first "Apple Development" cert, else ad-hoc.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
APP="${APP_PATH:-Pasteley.app}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pasteley "$APP/Contents/MacOS/Pasteley"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Stamp the version when VERSION is set (CI sets it from the tag).
if [ -n "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}" "$APP/Contents/Info.plist"
fi
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')}"
if [ -z "$IDENTITY" ]; then IDENTITY="-"; fi
# For distribution: SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" ./scripts/bundle.sh
# Developer ID builds need a secure timestamp or the notary service rejects them.
TIMESTAMP=""
case "$IDENTITY" in *"Developer ID"*) TIMESTAMP="--timestamp" ;; esac
codesign --force --options runtime $TIMESTAMP --sign "$IDENTITY" "$APP"
echo "Built $APP signed as: $IDENTITY"
