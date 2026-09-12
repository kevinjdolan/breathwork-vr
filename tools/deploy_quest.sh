#!/bin/sh
# Install only on the explicitly selected physical Quest; never select an emulator.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
adb_bin=${ADB_BIN:-"$project_dir/.tools/android-sdk/platform-tools/adb"}
quest_serial=${QUEST_SERIAL:-$("$adb_bin" devices -l | awk '$2 == "device" && /model:Quest/ { serial = $1; count++ } END { if (count == 1) print serial }')}
case "$quest_serial" in emulator-*) echo 'A physical Quest serial is required.' >&2; exit 1;; esac
if [ "$("$adb_bin" -s "$quest_serial" get-state 2>/dev/null)" != device ]; then
    echo 'Quest unavailable or unauthorized. Connect it and accept USB debugging in the headset.' >&2
    exit 1
fi
"$adb_bin" -s "$quest_serial" install -r "$project_dir/build/BreathworkVR.apk"
"$adb_bin" -s "$quest_serial" shell am force-stop com.kevin.breathworkvr
exec "$adb_bin" -s "$quest_serial" shell am start -W -n com.kevin.breathworkvr/com.godot.game.GodotAppLauncher
