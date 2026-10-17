#!/bin/sh
# Writes a Sparkle appcast for one DMG. Usage: scripts/appcast.sh <dmg> <version> <build> <out.xml>
# Signs with the "pastely" key in the keychain, or with SPARKLE_PRIVATE_KEY_FILE when set (CI).
set -eu
DMG="$1"; VERSION="$2"; BUILD="$3"; OUT="$4"
SIGN_UPDATE="$(find .build/artifacts -type f -name sign_update | head -1)"
if [ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]; then
  SIG="$("$SIGN_UPDATE" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "$DMG")"
else
  SIG="$("$SIGN_UPDATE" --account pastely "$DMG")"
fi
URL="https://github.com/amenophis1er/pastely/releases/download/v$VERSION/$(basename "$DMG")"
NOTES="https://github.com/amenophis1er/pastely/releases/tag/v$VERSION"
NOTES_HTML="$(python3 scripts/release-notes.py "$VERSION" --html)"
cat > "$OUT" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Pastely</title>
    <item>
      <title>Pastely $VERSION</title>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <link>$NOTES</link>
      <description><![CDATA[
<style>body{font-family:-apple-system,system-ui,sans-serif;font-size:13px;line-height:1.5;margin:12px 16px;color:#222}@media(prefers-color-scheme:dark){body{color:#ddd}}h3{font-size:14px;margin:14px 0 6px}ul{padding-left:20px}li{margin:3px 0}code{font-family:ui-monospace,Menlo,monospace;font-size:12px}a{color:#5463f5}</style>
<h3>Pastely $VERSION</h3>
$NOTES_HTML
<p><a href="$NOTES">Full release on GitHub</a></p>
]]></description>
      <pubDate>$(date -u -R)</pubDate>
      <enclosure url="$URL" $SIG type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
echo "Wrote $OUT for $URL"
