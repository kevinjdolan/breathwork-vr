#!/bin/sh
# Run engine imports, session contracts, and independent audio/address tests.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
godot_bin=${GODOT_BIN:-"$project_dir/.tools/Godot.app/Contents/MacOS/Godot"}
python_bin=${PYTHON_BIN:-"$project_dir/.tools/venv/bin/python"}
run_engine() {
    engine_log=$(mktemp)
    engine_status=0
    "$godot_bin" "$@" > "$engine_log" 2>&1 || engine_status=$?
    cat "$engine_log"
    # Godot can return zero after a script or shader compilation failure.
    if rg -q '^(SCRIPT ERROR:|SHADER ERROR:|ERROR:)' "$engine_log"; then
        engine_status=1
    fi
    rm -f "$engine_log"
    return "$engine_status"
}
run_engine --headless --xr-mode off --editor --path "$project_dir" --quit
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_session.gd -- --test
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_session.gd -- --test --quest3
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_hands.gd -- --test
run_engine --headless --xr-mode off --path "$project_dir" --max-fps 90 --script tests/test_end.gd -- --test
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_suite.gd -- --test
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_session_menu.gd -- --test
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_palm_wave.gd -- --test
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_prismatic.gd -- --test
run_engine --headless --xr-mode off --path "$project_dir" --script tests/test_visionary.gd -- --test
"$python_bin" -m unittest discover -s tests -p 'test_*.py' -v
