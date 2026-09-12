#!/bin/sh
# Open the stationary desktop preview; Escape or Space held for 1.5 s exits.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin=${GODOT_BIN:-"$project_dir/.tools/Godot.app/Contents/MacOS/Godot"}
exec "$godot_bin" --path "$project_dir" --xr-mode off "$@"
