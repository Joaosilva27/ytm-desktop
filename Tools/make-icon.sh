#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
ICONSET="$BUILD_DIR/AppIcon.iconset"
SOURCE="$ICONSET/icon_512x512@2x.png"
ICNS="$ROOT/Resources/AppIcon.icns"

mkdir -p "$ICONSET"
rm -f "$ICONSET"/*.png

echo "Rendering icon…"
xcrun clang \
  -fobjc-arc \
  -fmodules \
  -mmacosx-version-min=13.0 \
  -framework AppKit \
  "$ROOT/Tools/IconGen.m" \
  -o "$BUILD_DIR/icon-gen"

"$BUILD_DIR/icon-gen" "$SOURCE"

render() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/$name" >/dev/null
}

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Wrote $ICNS"
