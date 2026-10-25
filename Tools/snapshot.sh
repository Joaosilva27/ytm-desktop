#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${YTM_APP:-$ROOT/dist/YouTube Music.app}"
OUT="${1:-$ROOT/build/snapshot.png}"
DELAY="${2:-10}"

if [[ ! -d "$APP" ]]; then
  echo "App not found at $APP. Run Tools/build.sh first." >&2
  exit 1
fi

OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

echo "Launching YouTube Music and capturing $OUT after ${DELAY}s…"
YTM_SNAPSHOT="$OUT" \
YTM_SNAPSHOT_DELAY="$DELAY" \
YTM_SNAPSHOT_EXIT=1 \
  "$APP/Contents/MacOS/YouTube Music"

echo "Snapshot: $OUT"
