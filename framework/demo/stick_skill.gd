class_name StickSkill
extends RefCounted
## Stick handling as one continuous level, 1.0 to 10.0, earned by
## stickhandling (Sean, 2026-10-26): every handle you make with the puck
## (the stick changing direction across it) pays a little XP that takes
## effect at once, so the next handle is a touch easier. The level is the
## puck's retention on the blade (DemoSkater's bond) and, past 5, how
## quickly the stick answers the hands (DemoHands.response).
##
## The scale, in handles (a full-width handle with the puck kept is 1.0):
##   1 -> 2    30     the tutorial: move about, move the stick about
##   2 -> 3    40     ... level 3 by the end of it (70 handles, a few minutes)
##   3 -> 4   250     the first games: a game is 200 to 300 handles,
##   4 -> 5   350     ... so level 5 after two or three of them
##   5 -> 6  1250     the plateau: about five games
##   6 -> 7  2500     ten
##   7 -> 8  5000     twenty
##   8 -> 9 10000     forty
##   9 -> 10 20000    eighty: a career
## A narrow handle pays less (down to a quarter), a handle that loses the
## puck pays a quarter.

const COST := [30.0, 40.0, 250.0, 350.0, 1250.0, 2500.0, 5000.0, 10000.0, 20000.0]
const FULL_WIDTH := 0.5  # of the stick's travel (unit circle) for a full handle
const MIN_PAY := 0.25
const LOST_PAY := 0.25

var xp := 0.0  # handles' worth earned so far
var handles := 0  # handles made


## The level, 1.0 to 10.0, continuous.
func level() -> float:
	var left := xp
	for n in COST.size():
		if left < COST[n]:
			return 1.0 + n + left / COST[n]
		left -= COST[n]
	return 10.0


## Sets the XP to put the level here (the number keys, saves).
func set_level(l: float) -> void:
	l = clampf(l, 1.0, 10.0)
	var n := int(floor(l))
	xp = 0.0
	for i in mini(n - 1, COST.size()):
		xp += COST[i]
	if n < 10:
		xp += (l - n) * COST[n - 1]


## One handle: `width` is how far the stick travelled across before it
## turned (stick units), `kept` whether the puck was still on the blade.
## Returns what it paid.
func handle(width: float, kept: bool) -> float:
	var pay := clampf(width / FULL_WIDTH, MIN_PAY, 1.0) * (1.0 if kept else LOST_PAY)
	xp += pay
	handles += 1
	return pay


## Handles from level `a` to level `b` (docs, tests).
static func cost_between(a: float, b: float) -> float:
	var s := StickSkill.new()
	s.set_level(a)
	var xa := s.xp
	s.set_level(b)
	return s.xp - xa
