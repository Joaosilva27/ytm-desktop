#!/usr/bin/env bash
#
# Package dist/YouTube Music.app into a drag-to-install disk image.
#
#   ./Tools/make-dmg.sh                      # dist/YouTube-Music-<version>.dmg
#   ./Tools/make-dmg.sh path/to/output.dmg   # explicit destination
#
# The image opens as a small Finder window with the app on the left, an arrow,
# and an Applications shortcut on the right. The same script is used by the
# GitHub release workflow, so a local build and a release build match.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/YouTube Music.app"
VOL_NAME="YouTube Music"
STAGE="$ROOT/build/dmg"
BACKGROUND="$ROOT/Resources/dmg-background.png"

if [[ ! -d "$APP" ]]; then
  echo "error: $APP is missing — run ./Tools/build.sh first" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
OUT="${1:-$ROOT/dist/YouTube-Music-$VERSION.dmg}"
TMP_IMAGE="$ROOT/build/YouTubeMusic-rw.dmg"

echo "Packaging YouTube Music $VERSION…"

rm -rf "$STAGE" "$TMP_IMAGE" "$OUT"
mkdir -p "$STAGE" "$(dirname "$OUT")"

# Contents of the disk image: the app, and a link to /Applications to drop it in.
cp -R "$APP" "$STAGE/YouTube Music.app"
ln -s /Applications "$STAGE/Applications"

if [[ -f "$BACKGROUND" ]]; then
  mkdir -p "$STAGE/.background"
  cp "$BACKGROUND" "$STAGE/.background/background.png"
fi

# Build a read-write image first so Finder can record the window layout.
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$TMP_IMAGE" >/dev/null

MOUNT="$(mktemp -d)"
cleanup() {
  hdiutil detach "$MOUNT" -force -quiet >/dev/null 2>&1 || true
  rm -rf "$MOUNT"
}
trap cleanup EXIT

hdiutil attach "$TMP_IMAGE" -mountpoint "$MOUNT" -nobrowse -quiet

# Hide the background folder, as a hand-made disk image would.
xcrun SetFile -a V "$MOUNT/.background" >/dev/null 2>&1 || true

# Ask Finder to lay the window out. Headless CI sessions sometimes refuse to
# script Finder, so a failure here is a warning: the image still installs.
if [[ -f "$BACKGROUND" ]]; then
  osascript >/dev/null 2>&1 <<EOF || echo "warning: Finder layout was not applied (image is still usable)" >&2
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 200, 1000, 600}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 160
    set background picture of viewOptions to file ".background:background.png"
    set position of item "YouTube Music.app" of container window to {190, 170}
    set position of item "Applications" of container window to {610, 170}
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF
fi

sync
# Finder sometimes still holds the volume after scripting it; force the detach.
hdiutil detach "$MOUNT" -quiet || hdiutil detach "$MOUNT" -force -quiet
trap - EXIT
rm -rf "$MOUNT"

# Compress, then stamp the compressed image's checksum for release notes.
hdiutil convert "$TMP_IMAGE" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT" >/dev/null
rm -f "$TMP_IMAGE"

(
  cd "$(dirname "$OUT")"
  shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256"
)

echo "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
echo "Wrote $OUT.sha256"
