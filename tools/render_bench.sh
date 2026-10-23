#!/usr/bin/env bash
# The render benchmark under a virtual display with the software OpenGL
# driver (framework/bench/render_bench.gd). Numbers are only comparable to
# the same machine's earlier runs. Usage: GODOT=... tools/render_bench.sh [--props=200] [--quality=medium]
set -uo pipefail
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --rendering-method gl_compatibility \
	res://scenes/dev/render_bench.tscn -- "$@" 2>&1 | grep -E "^render_bench"
