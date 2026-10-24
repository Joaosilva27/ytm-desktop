#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
APP="$DIST_DIR/YTM.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
CC="${CC:-clang}"

echo "Building YTM…"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

# Native Objective-C app. ARC + modules, deployment target macOS 13.
xcrun "$CC" \
  -fobjc-arc \
  -fmodules \
  -mmacosx-version-min=13.0 \
  -O2 \
  -Wall \
  -Wextra \
  -Wno-unused-parameter \
  -I "$ROOT/Sources" \
  -framework AppKit \
  -framework WebKit \
  -framework MediaPlayer \
  -framework QuartzCore \
  "$ROOT"/Sources/*.m \
  -o "$MACOS/YTM"

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/PlayerBridge.js" "$RESOURCES/PlayerBridge.js"
cp "$ROOT/Resources/ChromeOffset.js" "$RESOURCES/ChromeOffset.js"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  "$ROOT/Tools/make-icon.sh"
fi
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

# Ad-hoc signature so macOS can keep permissions, notifications and media keys stable.
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"

if [[ "${1:-}" == "--open" ]]; then
  open "$APP"
elif [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/YTM.app"
  cp -R "$APP" "/Applications/YTM.app"
  echo "Installed /Applications/YTM.app"
  open "/Applications/YTM.app"
fi
