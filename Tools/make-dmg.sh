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
#
# macOS 26 Tahoe can no longer mount HFS+ disk images, so the styled image is
# built on HFS+ where that still works and on APFS otherwise. If neither can be
# laid out by Finder (headless CI), a plain image is written instead.

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

echo "Packaging YouTube Music ${VERSION}..."

rm -rf "$STAGE" "$TMP_IMAGE" "$OUT"
mkdir -p "$ROOT/build" "$STAGE" "$(dirname "$OUT")"

# Contents of the disk image: the app, and a link to /Applications to drop it in.
cp -R "$APP" "$STAGE/YouTube Music.app"
ln -s /Applications "$STAGE/Applications"

if [[ -f "$BACKGROUND" ]]; then
  mkdir -p "$STAGE/.background"
  cp "$BACKGROUND" "$STAGE/.background/background.png"
fi

# Lay the window out from Finder. Headless sessions sometimes refuse to script
# Finder, so a failure here is a warning: the image still installs.
apply_layout() {
  local mount="$1"
  xcrun SetFile -a V "$mount/.background" >/dev/null 2>&1 || true
  [[ -f "$BACKGROUND" ]] || return 0
  # perl gives osascript a deadline: a session without Automation permission can
  # otherwise sit on the request instead of failing.
  perl -e 'alarm shift; exec @ARGV' 60 osascript >/dev/null 2>&1 <<EOF || echo "warning: Finder layout was not applied (image is still usable)" >&2
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
}

# Build a read-write image so Finder can record the window layout, then compress.
styled_image() {
  local fs_flags="$1"
  local mount

  echo "→ read-write image ${fs_flags:-(default filesystem)}"
  rm -f "$TMP_IMAGE"
  # shellcheck disable=SC2086 # fs_flags is an intentional flag list.
  hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" $fs_flags -format UDRW -ov \
    "$TMP_IMAGE" >/dev/null || return 1

  mount="$(mktemp -d)"
  echo "→ mounting"
  if ! hdiutil attach "$TMP_IMAGE" -mountpoint "$mount" -nobrowse -quiet; then
    rmdir "$mount" 2>/dev/null || true
    return 1
  fi

  apply_layout "$mount"

  sync
  # Finder sometimes still holds the volume after scripting it; force the detach.
  hdiutil detach "$mount" -quiet || hdiutil detach "$mount" -force -quiet || true
  rmdir "$mount" 2>/dev/null || true

  echo "→ compressing"
  hdiutil convert "$TMP_IMAGE" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT" >/dev/null || return 1
  rm -f "$TMP_IMAGE"
}

if styled_image "-fs HFS+"; then
  :
elif styled_image "-fs APFS"; then
  echo "note: HFS+ images are not mountable here; wrote an APFS image instead" >&2
else
  echo "warning: could not build the styled image; writing a plain image" >&2
  rm -f "$OUT"
  hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -format UDZO \
    -imagekey zlib-level=9 -ov "$OUT" >/dev/null
fi

(
  cd "$(dirname "$OUT")"
  shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256"
)

echo "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
echo "Wrote $OUT.sha256"
