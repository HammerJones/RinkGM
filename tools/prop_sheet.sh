#!/usr/bin/env bash
# Renders the prop contact sheet (framework/studio/prop_sheet.gd) under a
# virtual display with the software OpenGL driver, so it runs on a server
# or in CI. Usage: GODOT=/path/to/godot tools/prop_sheet.sh [ids...]
set -uo pipefail
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path . --rendering-driver opengl3 --rendering-method gl_compatibility \
	--script res://framework/studio/prop_sheet.gd -- "$@" 2>&1 | grep -vE "^Godot Engine|ALSA|audio_driver|dummy driver|^\s*$|^WARNING: All audio|^     at: initialize"
