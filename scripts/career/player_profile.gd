class_name PlayerProfile
extends RefCounted
## Everything persistent about one player: identity, position, age, ratings,
## potential, health and stats. The user's character is a PlayerProfile with
## `is_user = true`; AI players are the same thing, so anything the user can
## do (age, get hurt, get scouted) works for everyone.

const POSITIONS := ["C", "LW", "RW", "D", "G"]
const STAT_KEYS := ["gp", "g", "a", "shots", "hits", "pm", "toi", "sa", "ga", "w", "l", "otl", "so"]

var id := 0
var first_name := ""
var last_name := ""
var number := 0
var position := "C"
var shoots := "L"
var age := 20.0
var is_user := false
var team_id := -1
var skills: Skills
## Per-skill ceilings this player can train up to (talent). Ages lower them.
var potential := {}
var injury: Injury = null
## Out of the lineup for something other than injury (unpaid league dues).
## Not saved: Career re-reads it from `league_gate` before each round.
var benched := false
## 0..1, carried between games (back-to-backs, playing hurt).
var fatigue := 0.0
## What the player's training sessions focus on (a skill key or "balanced").
var training_focus := "balanced"
var xp_log := {}  # skill -> xp banked this season (for the season summary)
var season_stats := {}
var playoff_stats := {}
var career_stats := {}
## History rows: {"season", "tier", "team", stats...}
var history: Array = []
## Shots and stick moves this player knows, by catalog id ("snap_shot"); see
## MoveUnlocks for when each is learned.
var moves: Array = []


static func create(id_: int, pos: String, base: float, rng: RandomNumberGenerator) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.id = id_
	p.position = pos
	p.shoots = "L" if rng.randf() < 0.62 else "R"
	p.number = rng.randi_range(2, 98)
	var keys := Skills.GOALIE_KEYS if pos == "G" else Skills.SKATER_KEYS
	p.skills = Skills.create(keys, base, 7.0, rng)
	# position flavour
	if pos == "D":
		p._nudge({"hitting": 6, "toughness": 5, "pass_quality": 3, "shot_power": 3, "shot_release": -4, "speed": -2})
	elif pos == "C":
		p._nudge({"pass_quality": 4, "stick_handling": 3, "hitting": -3})
	elif pos == "LW" or pos == "RW":
		p._nudge({"shot_accuracy": 3, "shot_release": 4, "speed": 2, "hitting": -2})
	for k in keys:
		p.potential[k] = clampf(p.skills.values[k] + rng.randf_range(4.0, 30.0), 1.0, 100.0)
	p.reset_season_stats()
	p.career_stats = _blank_stats()
	p.moves = MoveUnlocks.STARTER.duplicate()
	MoveUnlocks.check(p)
	return p


func knows_move(move: String) -> bool:
	return moves.has(String(move))


## Teaches a move outright (dev menu, events). Returns false if already known.
func unlock_move(move: String) -> bool:
	if moves.has(move):
		return false
	moves.append(move)
	return true


func _nudge(d: Dictionary) -> void:
	for k in d:
		if skills.values.has(k):
			skills.values[k] = clampf(skills.values[k] + d[k], 1.0, 100.0)


static func _blank_stats() -> Dictionary:
	var d := {}
	for k in STAT_KEYS:
		d[k] = 0
	return d


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func short_name() -> String:
	return "%s. %s" % [first_name.left(1), last_name]


func is_goalie() -> bool:
	return position == "G"


## "F", "D" or "G": which line group and rating weights apply.
func group() -> String:
	if position == "G":
		return "G"
	return "D" if position == "D" else "F"


func overall() -> float:
	return skills.overall(group())


func can_play() -> bool:
	return injury == null or injury.can_play()


## Healthy and not benched: in the lineup for the next game.
func dressed() -> bool:
	return can_play() and not benched


## Re-applies injury and fatigue modifiers to the skills (call after changes).
func refresh_modifiers() -> void:
	skills.modifiers = {}
	if injury:
		for k in injury.modifiers():
			skills.modifiers[k] = injury.modifiers()[k]
	if fatigue > 0.3:
		for k in ["speed", "agility", "hitting"]:
			if skills.values.has(k):
				skills.modifiers[k] = skills.modifiers.get(k, 0.0) - (fatigue - 0.3) * 8.0


func add_injury(inj: Injury) -> void:
	# a new injury replaces a milder one
	if injury == null or inj.severity >= injury.severity or injury.is_healed():
		injury = inj
	for k in inj.permanent:
		skills.values[k] = clampf(skills.values[k] + inj.permanent[k], 1.0, 100.0)
		potential[k] = clampf(potential[k] + inj.permanent[k], 1.0, 100.0)
	refresh_modifiers()


func reset_season_stats() -> void:
	season_stats = _blank_stats()
	playoff_stats = _blank_stats()
	xp_log = {}


## Adds one game's box score line. `playoffs` keeps them separate like the pros.
func add_game_stats(line: Dictionary, playoffs: bool) -> void:
	var target := playoff_stats if playoffs else season_stats
	for k in line:
		if target.has(k):
			target[k] += line[k]
			career_stats[k] += line[k]


func points() -> int:
	return int(season_stats.g + season_stats.a)


func to_dict() -> Dictionary:
	return {
		"id": id, "first": first_name, "last": last_name, "number": number, "position": position,
		"shoots": shoots, "age": age, "is_user": is_user, "team_id": team_id,
		"skills": skills.to_dict(), "potential": potential, "fatigue": fatigue,
		"injury": injury.to_dict() if injury else null, "training_focus": training_focus,
		"season_stats": season_stats, "playoff_stats": playoff_stats, "career_stats": career_stats,
		"history": history, "xp_log": xp_log, "moves": moves,
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.id = int(d.id)
	p.first_name = d.first
	p.last_name = d.last
	p.number = int(d.number)
	p.position = d.position
	p.shoots = d.shoots
	p.age = float(d.age)
	p.is_user = d.is_user
	p.team_id = int(d.team_id)
	p.skills = Skills.from_dict(d.skills)
	p.potential = d.potential
	p.fatigue = float(d.get("fatigue", 0.0))
	p.injury = Injury.from_dict(d.injury) if d.get("injury") != null else null
	p.training_focus = d.get("training_focus", "balanced")
	p.season_stats = _ints(d.season_stats)
	p.playoff_stats = _ints(d.playoff_stats)
	p.career_stats = _ints(d.career_stats)
	p.history = d.get("history", [])
	p.moves = d.get("moves", []).map(func(m): return MoveUnlocks.OLD_NAMES.get(m, m))
	if p.moves.is_empty():
		p.moves = MoveUnlocks.STARTER.duplicate()
		MoveUnlocks.check(p)
	p.xp_log = d.get("xp_log", {})
	return p


## JSON turns ints into floats; stats are counts.
static func _ints(d: Dictionary) -> Dictionary:
	var out := _blank_stats()
	for k in d:
		out[k] = int(d[k]) if k != "toi" else float(d[k])
	return out
