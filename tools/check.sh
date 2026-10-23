#!/usr/bin/env bash
# Re-imports the project headless and runs the game for a few seconds,
# printing any script errors. Usage: GODOT=/path/to/godot tools/check.sh
set -e
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import 2>&1 | grep -E "ERROR|WARNING|error" || true
"$GODOT" --headless --path . --quit-after ${FRAMES:-600} 2>&1 | grep -v "^Godot Engine" || true
