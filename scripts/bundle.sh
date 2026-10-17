#!/bin/sh
# Builds a release binary and wraps it into Pasteley.app at the repo root.
#
# Signing: the keychain remembers "Always Allow" per code identity, and an ad-hoc
# signature changes on every build. So we sign with a stable identity by default:
# SIGN_IDENTITY env var, else the first "Apple Development" cert, else ad-hoc.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
APP=Pasteley.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pasteley "$APP/Contents/MacOS/Pasteley"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')}"
if [ -z "$IDENTITY" ]; then IDENTITY="-"; fi
# For distribution: SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" ./scripts/bundle.sh
codesign --force --options runtime --sign "$IDENTITY" "$APP"
echo "Built $APP signed as: $IDENTITY"
