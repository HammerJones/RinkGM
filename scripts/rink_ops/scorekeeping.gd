class_name Scorekeeping
extends RefCounted
## Keeping score from the box (canvas "On-ice activities"): the referee skates
## over after each goal or penalty and calls it, and the scorekeeper writes it
## on the game sheet. A goal is the team, the scorer and up to two assists;
## a penalty is the team, the player, the minutes and the infraction, which
## also goes up on the scoreboard's penalty clock, started at the next whistle
## (the faceoff after the call), not before.
##
## This is the game's model: create() deals the calls for a game, check()
## marks what the player wrote for one, and result() sums it up. The UI is
## ScorekeepingView. RinkOps reads `quality` back: a clean sheet keeps the
## league happy, a messy one costs satisfaction like a missing scorekeeper.

const CALLS := 6
## Seconds from the call to the whistle the clock must be started on, and how
## close to the whistle a start still counts as on time.
const WHISTLE_MIN := 4.0
const WHISTLE_MAX := 9.0
const ON_TIME := 2.0
const INFRACTIONS := ["tripping", "hooking", "slashing", "interference", "holding", "roughing", "high-sticking", "too many men"]
const TEAMS := ["home", "away"]

## [{"kind": "goal"|"penalty", "team", "scorer", "assists": [], "player",
##   "minutes", "infraction", "time": "12:41", "whistle": seconds}]
var calls: Array = []
## Per call: {"ok": bool, "errors": [text]}.
var marks: Array = []
var rosters := {"home": [], "away": []}


## A game's calls, with jersey numbers from each side's roster (any numbers
## 1..99 when none are given).
static func create(seed_: int, home: Array = [], away: Array = [], count := CALLS) -> Scorekeeping:
	var s := Scorekeeping.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	s.rosters.home = home if not home.is_empty() else _numbers(rng)
	s.rosters.away = away if not away.is_empty() else _numbers(rng)
	var clock := 20 * 60
	for i in count:
		clock -= rng.randi_range(60, 200)
		var team: String = TEAMS[rng.randi() % 2]
		var roster: Array = s.rosters[team].duplicate()
		var c := {"team": team, "time": "%d:%02d" % [maxi(clock, 1) / 60, maxi(clock, 1) % 60], "whistle": 0.0}
		if rng.randf() < 0.55:
			c.kind = "goal"
			roster.shuffle()
			c.scorer = int(roster[0])
			var n := 2 if rng.randf() < 0.6 else (1 if rng.randf() < 0.7 else 0)
			c.assists = [int(roster[1]), int(roster[2])].slice(0, n)
		else:
			c.kind = "penalty"
			c.player = int(roster[rng.randi() % roster.size()])
			c.infraction = INFRACTIONS[rng.randi() % INFRACTIONS.size()]
			c.minutes = 5 if c.infraction == "roughing" and rng.randf() < 0.3 else 2
			c.whistle = rng.randf_range(WHISTLE_MIN, WHISTLE_MAX)
		s.calls.append(c)
	return s


static func _numbers(rng: RandomNumberGenerator) -> Array:
	var pool := range(2, 99)
	var out: Array = []
	for i in 15:
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## What the referee says for call `i`.
func call_text(i: int) -> String:
	var c: Dictionary = calls[i]
	var side := "home" if c.team == "home" else "visitors"
	if c.kind == "goal":
		var a := "unassisted"
		if c.assists.size() == 1:
			a = "assist %d" % c.assists[0]
		elif c.assists.size() == 2:
			a = "assists %d and %d" % [c.assists[0], c.assists[1]]
		return "Goal, %s, number %d, %s, at %s." % [side, c.scorer, a, c.time]
	return "%s, %s number %d, %d minutes for %s, at %s." % ["Major" if int(c.minutes) == 5 else "Minor", side, c.player, c.minutes, c.infraction, c.time]


## Marks what was written for call `i`: {"team", "scorer", "assists": [a, b]}
## for a goal; {"team", "player", "minutes", "infraction"} for a penalty,
## plus "clock_start": seconds after the call the penalty clock was started
## (-1 never). Returns {"ok", "errors"}.
func check(i: int, sheet: Dictionary) -> Dictionary:
	var c: Dictionary = calls[i]
	var errors: Array = []
	if str(sheet.get("team", "")) != c.team:
		errors.append("wrong team")
	if c.kind == "goal":
		if int(sheet.get("scorer", -1)) != int(c.scorer):
			errors.append("wrong scorer")
		var want: Array = c.assists.duplicate()
		var got: Array = (sheet.get("assists", []) as Array).filter(func(x) -> bool: return int(x) > 0).map(func(x) -> int: return int(x))
		want.sort()
		got.sort()
		if want != got:
			errors.append("wrong assists")
	else:
		if int(sheet.get("player", -1)) != int(c.player):
			errors.append("wrong player")
		if int(sheet.get("minutes", 0)) != int(c.minutes):
			errors.append("wrong minutes")
		var t := float(sheet.get("clock_start", -1.0))
		if t < 0.0:
			errors.append("penalty clock never started")
		elif t < float(c.whistle):
			errors.append("clock started before the whistle")
		elif t > float(c.whistle) + ON_TIME:
			errors.append("clock started late")
	var m := {"ok": errors.is_empty(), "errors": errors}
	while marks.size() <= i:
		marks.append({})
	marks[i] = m
	return m


## {"quality": 0..1, "clean": calls right, "of": calls}.
func result() -> Dictionary:
	var clean := 0
	for m in marks:
		if bool(m.get("ok", false)):
			clean += 1
	return {"quality": float(clean) / maxf(calls.size(), 1.0), "clean": clean, "of": calls.size()}
