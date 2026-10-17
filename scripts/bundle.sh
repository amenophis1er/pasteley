#!/bin/sh
# Builds a release binary and wraps it into an app bundle under build.noindex/ (kept out of Spotlight).
#
# Signing: the keychain remembers "Always Allow" per code identity, and an ad-hoc
# signature changes on every build. So we sign with a stable identity by default:
# SIGN_IDENTITY env var, else the first "Apple Development" cert, else ad-hoc.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
APP="${APP_PATH:-build.noindex/dev/Pastely.app}"
rm -rf "$APP" && mkdir -p "$(dirname "$APP")"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pastely "$APP/Contents/MacOS/Pastely"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Sparkle: embed the framework next to the binary and make the binary look for it there.
mkdir -p "$APP/Contents/Frameworks"
cp -R .build/release/Sparkle.framework "$APP/Contents/Frameworks/"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Pastely" 2>/dev/null || true
PLIST="$APP/Contents/Info.plist"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
/usr/libexec/PlistBuddy -c "Add :PastelyCommit string $COMMIT" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :PastelyCommit $COMMIT" "$PLIST"

# Stamp the version when VERSION is set (CI sets it from the tag).
if [ -n "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}" "$PLIST"
fi

# Dev builds get their own identity so they never share preferences, permissions,
# keychain key, history or URL scheme with the installed release.
if [ "${PASTELY_DEV:-1}" = "1" ] && [ -z "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.amenophis.pastely.dev" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Pastely Dev" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLName com.amenophis.pastely.dev" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 pastely-dev" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")-dev" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(date +%Y%m%d%H%M)" "$PLIST"
  /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$PLIST" 2>/dev/null || true
fi
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')}"
if [ -z "$IDENTITY" ]; then IDENTITY="-"; fi
# For distribution: SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" ./scripts/bundle.sh
# Developer ID builds need a secure timestamp or the notary service rejects them.
TIMESTAMP=""
case "$IDENTITY" in *"Developer ID"*) TIMESTAMP="--timestamp" ;; esac
# Sparkle's nested helpers must carry our identity (and a timestamp) for notarization.
# Sign inside-out: XPC services and helpers, then the framework, then the app.
FW="$APP/Contents/Frameworks/Sparkle.framework"
for nested in "$FW/Versions/B/XPCServices/Installer.xpc" "$FW/Versions/B/XPCServices/Downloader.xpc" \
              "$FW/Versions/B/Autoupdate" "$FW/Versions/B/Updater.app"; do
  codesign --force --options runtime $TIMESTAMP --preserve-metadata=entitlements --sign "$IDENTITY" "$nested"
done
codesign --force --options runtime $TIMESTAMP --sign "$IDENTITY" "$FW"
codesign --force --options runtime $TIMESTAMP --sign "$IDENTITY" "$APP"
echo "Built $APP signed as: $IDENTITY"
