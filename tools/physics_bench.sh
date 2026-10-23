#!/usr/bin/env bash
# Prints what each rating produces in the physics (speeds, stops, turns, puck
# control, shots, passes, hits). Usage: GODOT=/path/to/godot tools/physics_bench.sh [out.md]
set -e
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
OUT=${1:-}
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --fixed-fps 120 res://tools/bench/bench.tscn -- ${OUT:+--out="$(realpath -m "$OUT")"} 2>&1 | grep -v "^Godot Engine"
