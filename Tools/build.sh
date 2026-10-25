#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
APP="$DIST_DIR/YouTube Music.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
CC="${CC:-clang}"

# Universal builds (release builds ship arm64 + x86_64). Local builds are host-only.
# Kept as a plain string so this script stays compatible with macOS's bash 3.2.
ARCH_FLAGS="${ARCH_FLAGS:-}"
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS="-arch arm64 -arch x86_64"
fi

echo "Building YouTube Music…"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

# Native Objective-C app. ARC + modules, deployment target macOS 13.
# shellcheck disable=SC2086 # ARCH_FLAGS is an intentional flag list.
xcrun "$CC" \
  $ARCH_FLAGS \
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
  -o "$MACOS/YouTube Music"

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/PlayerBridge.js" "$RESOURCES/PlayerBridge.js"
cp "$ROOT/Resources/AudioOnly.js" "$RESOURCES/AudioOnly.js"
cp "$ROOT/Resources/AdBlocker.js" "$RESOURCES/AdBlocker.js"
cp "$ROOT/Resources/AdBlockRules.json" "$RESOURCES/AdBlockRules.json"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  "$ROOT/Tools/make-icon.sh"
fi
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

# Release builds stamp the version from the git tag. Must happen before signing.
if [[ -n "${VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-$VERSION}" "$CONTENTS/Info.plist"
  echo "Version $VERSION (build ${BUILD_NUMBER:-$VERSION})"
fi

# Ad-hoc signature so macOS can keep permissions, notifications and media keys stable.
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"

if [[ "${1:-}" == "--open" ]]; then
  open "$APP"
elif [[ "${1:-}" == "--install" ]]; then
  # Remove the old bundle name so two copies of the same app cannot coexist.
  rm -rf "/Applications/YTM.app" "/Applications/YouTube Music.app"
  cp -R "$APP" "/Applications/YouTube Music.app"
  echo "Installed /Applications/YouTube Music.app"
  open "/Applications/YouTube Music.app"
fi
