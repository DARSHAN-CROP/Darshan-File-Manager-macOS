#!/bin/bash
# Best effort: launches the built app in demo mode and captures the window with screencapture.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=build/screenshots; mkdir -p "$OUT"
APP="build/Darshan File Manager.app"
BIN="$APP/Contents/MacOS/DarshanFileManager"
[ -x "$BIN" ] || { echo "no app"; exit 0; }

shot() {  # name tab theme accent lang
  "$BIN" -demo YES -tab "$2" -theme "$3" -accent "$4" -lang "$5" >/dev/null 2>&1 &
  PID=$!
  sleep 7
  osascript -e 'tell application "System Events" to set frontmost of (first process whose unix id is '"$PID"') to true' >/dev/null 2>&1 || true
  sleep 1
  screencapture -x "$OUT/$1.png" || true
  kill $PID >/dev/null 2>&1 || true
  sleep 1
}
shot macos_sort_light 0 light maroon en
shot macos_sort_dark 0 dark maroon en
shot macos_duplicates_light 1 light maroon en
shot macos_old_dark 2 dark blue en
shot macos_rename_light 3 light green en
shot macos_rules_dark 4 dark maroon en
shot macos_storage_light 5 light gold en
shot macos_settings_dark 6 dark purple en
shot macos_settings_gujarati_light 6 light maroon gu
shot macos_sort_gujarati_dark 0 dark orange gu
ls -l "$OUT"
