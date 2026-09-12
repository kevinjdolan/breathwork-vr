#!/bin/sh
# Produce a signed debug APK using the configured Meta Quest export preset.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin=${GODOT_BIN:-"$project_dir/.tools/Godot.app/Contents/MacOS/Godot"}
mkdir -p "$project_dir/build"
exec "$godot_bin" --headless --path "$project_dir" --editor --export-debug 'Meta Quest' "$project_dir/build/BreathworkVR.apk"
