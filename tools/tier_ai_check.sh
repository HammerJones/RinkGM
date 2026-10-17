#!/usr/bin/env bash
# Checks that the on-ice AI plays to its tier: a mid-tier side (TierAI level
# MID, default 3 = Senior AAA) must outscore a low-tier side (LOW, default
# 0.5, beer league) over GAMES headless autoplay games, swapping ends every
# game so neither side keeps an edge from the rink. Both sides have the same
# ratings; only the TierAI knobs differ.
# Usage: GODOT=/path/to/godot [GAMES=8 LOW=0.5 MID=3 FRAMES=36000 JOBS=4] tools/tier_ai_check.sh
set -uo pipefail
GODOT=${GODOT:-godot}
GAMES=${GAMES:-8}
LOW=${LOW:-0.5}
MID=${MID:-3}
FRAMES=${FRAMES:-36000}
JOBS=${JOBS:-4}
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)

play() {
	local i=$1 levels
	if (( i % 2 == 0 )); then levels="$LOW,$MID"; else levels="$MID,$LOW"; fi
	timeout 600 "$GODOT" --headless --path . --fixed-fps 120 --quit-after "$FRAMES" -- --autoplay --ai-levels="$levels" \
		2>&1 | grep -E "autoplay stats|ai levels|SCRIPT ERROR|Invalid (call|access)" >"$OUT/$i.txt"
}
export -f play
export GODOT LOW MID FRAMES OUT
seq 0 $((GAMES - 1)) | xargs -P "$JOBS" -I{} bash -c 'play {}'

low_goals=0; mid_goals=0; low_wins=0; mid_wins=0; low_shots=0; mid_shots=0; fail=0
for i in $(seq 0 $((GAMES - 1))); do
	f="$OUT/$i.txt"
	if grep -qE "SCRIPT ERROR|Invalid" "$f"; then cat "$f"; fail=1; fi
	line=$(grep "autoplay stats" "$f")
	if [ -z "$line" ]; then echo "game $i did not report its stats"; fail=1; continue; fi
	read -r a b < <(echo "$line" | sed -E 's/.*score \[([0-9]+), ([0-9]+)\].*/\1 \2/')
	# team 0 is LOW on even games, MID on odd
	if (( i % 2 == 0 )); then lo=$a; mi=$b; else lo=$b; mi=$a; fi
	low_goals=$((low_goals + lo)); mid_goals=$((mid_goals + mi))
	(( mi > lo )) && mid_wins=$((mid_wins + 1))
	(( lo > mi )) && low_wins=$((low_wins + 1))
	extra=$(grep "ai levels" "$f" | sed -E 's/.*(shots.*)/\1/')
	echo "game $i: low $lo - mid $mi   (levels $( ((i % 2 == 0)) && echo "$LOW,$MID" || echo "$MID,$LOW"): $extra)"
done
echo "tier check over $GAMES games: low (level $LOW) $low_goals goals, $low_wins wins; mid (level $MID) $mid_goals goals, $mid_wins wins"
if (( fail == 0 && mid_goals > low_goals && mid_wins > low_wins )); then
	echo "== tier check passed"
else
	echo "== tier check FAILED"; exit 1
fi
