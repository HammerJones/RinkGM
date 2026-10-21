#!/usr/bin/env bash
# The quality gate every PR must pass (run locally and in .github/workflows/ci.yml):
#   1. import the project and fail on any script/parse error
#   2. play a full AI-vs-AI game headless and fail on any runtime error,
#      or if the game never reports its end-of-game stats
#   3. run every tools/tests/test_*.gd headless; each must exit 0 to pass
#   3b. run the gdUnit4 suites in tests/unit
#   4. run each in-game test mode listed in tools/tests/game_tests.txt
#      (`-- --test=<name>`, with autoloads and the full scene, or the scene
#      named after it on the line); each must
#      exit 0 and print "<name> test: all passed"
#   5. tools/tier_ai_check.sh when present (mid-tier AI must beat low tier)
#   0. before all that, tools/lint.sh (gdlint + gdformat on the framework layer)
# Usage: GODOT=/path/to/godot tools/ci.sh
set -uo pipefail
GODOT=${GODOT:-godot}
FRAMES=${FRAMES:-36000}
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
fail=0
ERR_RE='SCRIPT ERROR|Parse Error|ERROR:|Failed to load script|Invalid call|Invalid access'
# Known noise from the headless dummy renderer at shutdown, not a game bug.
IGNORE_RE='Parameter "m" is null'
errors() { grep -E "$ERR_RE" "$1" | grep -vE "$IGNORE_RE"; }

echo "== lint (framework layer)"
bash tools/lint.sh || fail=1

echo "== import"
# On a fresh checkout the first import loads the project theme before its
# textures and fonts are imported and logs "No loader found"; a second
# import is clean, so only that one is checked.
"$GODOT" --headless --path . --import >"$LOG/import0.txt" 2>&1
"$GODOT" --headless --path . --import >"$LOG/import.txt" 2>&1
if errors "$LOG/import.txt"; then fail=1; fi

echo "== autoplay game ($FRAMES frames)"
timeout 900 "$GODOT" --headless --path . --fixed-fps 120 --quit-after "$FRAMES" -- --autoplay >"$LOG/game.txt" 2>&1
if errors "$LOG/game.txt" | sort | uniq -c | head -40 | grep .; then fail=1; fi
if ! grep -q "autoplay stats" "$LOG/game.txt"; then
	echo "game did not report its stats (crashed or hung?)"; tail -20 "$LOG/game.txt"; fail=1
else
	grep "autoplay stats" "$LOG/game.txt"
fi

shopt -s nullglob
for t in tools/tests/test_*.gd; do
	echo "== $t"
	# the budget test wants one physics step per frame and no real-time pacing
	extra=""
	case "$t" in *test_framework_props.gd) extra="--fixed-fps 120";; esac
	if ! timeout 300 "$GODOT" --headless --path . $extra --quit-after 6000 --script "res://$t" >"$LOG/t.txt" 2>&1 || errors "$LOG/t.txt" >/dev/null; then
		cat "$LOG/t.txt"; fail=1
	else
		tail -3 "$LOG/t.txt"
	fi
done

# gdUnit4 suites under tests/unit (the editor runs the same ones from its panel)
if [ -d tests/unit ]; then
	echo "== gdUnit4 (tests/unit)"
	# --remote-debug to an unbound port keeps a parse error from dropping into
	# the interactive debugger prompt (which would hang the run)
	if timeout 600 "$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit --ignoreHeadlessMode >"$LOG/unit.txt" 2>&1; then
		grep -E "Overall Summary|Executed test cases" "$LOG/unit.txt" | sed 's/\x1b\[[0-9;]*m//g'
	else
		sed 's/\x1b\[[0-9;]*m//g' "$LOG/unit.txt" | grep -vE "^\[ *[0-9]+%" | tail -40; fail=1
	fi
fi

if [ -f tools/tests/game_tests.txt ]; then
	# a line is "<name>" (runs the main scene) or "<name> res://scene.tscn"
	while read -r name scene; do
		[[ -z "$name" || "$name" == \#* ]] && continue
		echo "== --test=$name ${scene}"
		timeout 300 "$GODOT" --headless --path . --fixed-fps 120 --quit-after 72000 ${scene} -- --test="$name" >"$LOG/g.txt" 2>&1
		code=$?
		if [ $code -ne 0 ] || ! grep -q "$name test: all passed" "$LOG/g.txt" || errors "$LOG/g.txt" >/dev/null; then
			tail -40 "$LOG/g.txt"; echo "exit code $code"; fail=1
		else
			grep "$name test:" "$LOG/g.txt"
		fi
	done < tools/tests/game_tests.txt
fi

# 5. tiers feel different: a mid-tier AI side must beat a low-tier side
#    (Physics' check; skipped on branches that don't have it yet)
if [ -f tools/tier_ai_check.sh ]; then
	echo "== tier AI check (${TIER_GAMES:-24} games)"
	GAMES=${TIER_GAMES:-24} GODOT="$GODOT" bash tools/tier_ai_check.sh || fail=1
fi

[ $fail -eq 0 ] && echo "== CI passed" || echo "== CI FAILED"
exit $fail
