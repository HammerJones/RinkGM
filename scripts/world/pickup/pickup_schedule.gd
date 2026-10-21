class_name PickupSchedule
extends RefCounted
## When pickup basketball happens in the gym. Nobody books it: people just
## turn up after work and school, and on weekend days. A day's runs come from
## a seeded RNG and the sim day, so the same Tuesday always has the same
## games. Pure logic (tested in tools/tests/test_pickup.gd).
##
##   var runs := PickupSchedule.sessions(seed, sim.day, sim.weekday())
##   var now := PickupSchedule.at(runs, sim.minute)   # {} when the gym is quiet

## Peak hours in minutes since midnight. Weekdays are 1..5 (0 = Sunday).
const WEEKDAY := Vector2i(15 * 60 + 30, 21 * 60)
const WEEKEND := Vector2i(10 * 60, 20 * 60)
const MIN_LEN := 30
const MAX_LEN := 90
## How many people turn up for a run: 5 is one short of 3 on 3.
const TURNOUT := Vector2i(5, 13)


static func window(weekday: int) -> Vector2i:
	return WEEKEND if weekday == 0 or weekday == 6 else WEEKDAY


static func in_peak(weekday: int, minute: int) -> bool:
	var w := window(weekday)
	return minute >= w.x and minute < w.y


## The day's runs, earliest first: [{"start", "end", "turnout", "seed", "day"}]
## in minutes since midnight. One or two on a weekday, two or three on a
## weekend day, never overlapping, each 30 to 90 minutes, all inside the
## peak window.
static func sessions(seed: int, day: int, weekday: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pickup:%d:%d" % [seed, day])
	var w := window(weekday)
	var weekend := weekday == 0 or weekday == 6
	var n := rng.randi_range(2, 3) if weekend else rng.randi_range(1, 2)
	var out: Array = []
	var span := float(w.y - w.x) / n
	for i in n:
		var a := w.x + roundi(span * i)
		var b := w.x + roundi(span * (i + 1))
		var len := mini(rng.randi_range(MIN_LEN, MAX_LEN), b - a)
		var start := rng.randi_range(a, b - len)
		out.append({"start": start, "end": start + len, "turnout": rng.randi_range(TURNOUT.x, TURNOUT.y),
			"seed": rng.randi(), "day": day})
	return out


## The run on at `minute`, or {}.
static func at(runs: Array, minute: int) -> Dictionary:
	for r: Dictionary in runs:
		if minute >= int(r.start) and minute < int(r.end):
			return r
	return {}
