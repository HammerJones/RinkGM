class_name Bench
extends RefCounted
## One team's bench during a game: three forward lines and two defence pairs
## rotate through the five skater slots on the ice. Forwards and defence change
## on their own shift clocks, at stoppages when they can, on the fly when the
## puck is out of their zone, and regardless once a shift drags on too long.
##
## Every dressed player has their own Skater body for the whole game (made the
## first time they're needed), so stamina and sticks stay with the player. The
## Bench only decides who *should* be out there (profile_for); Game moves the
## bodies: on the fly the tired skater skates to the bench door and the fresh
## one steps out of it, at a stoppage they swap before the faceoff. Players
## on the bench stand behind the boards and get their breath back.

## Body index -> position. The first three make sense for 3-on-3 too.
const SLOTS := ["C", "LD", "RW", "LW", "RD"]
const BENCH_RECOVERY := 0.07  # stamina per second on the bench

var team := 0
var settings: GameSettings
var f_lines: Array = []  # [[LW, C, RW] x3] PlayerProfiles
var d_pairs: Array = []  # [[LD, RD] x2]
var goalie: PlayerProfile
var spares: Array = []  # scratched players who can step in for an injury
var fi := 0
var di := 0
var f_time := 0.0
var d_time := 0.0
var energy := {}  # player id -> stamina 0..1 before their body exists
var hurt := {}  # player id -> true once injured in this game
var bodies := {}  # player id -> Skater, made on first use by make_body
var make_body: Callable  # (PlayerProfile) -> Skater, supplied by Game


func _init(team_: int, lineup: Dictionary, settings_: GameSettings) -> void:
	team = team_
	settings = settings_
	f_lines = lineup.F.map(func(l): return l.duplicate())
	d_pairs = lineup.D.map(func(l): return l.duplicate())
	goalie = lineup.G
	spares = lineup.get("scratched", []).duplicate()
	for l in f_lines + d_pairs:
		for p in l:
			if p:
				energy[p.id] = clampf(1.0 - p.fatigue * 0.5, 0.4, 1.0)


## The player the current lines put in body `i`.
func profile_for(i: int) -> PlayerProfile:
	match SLOTS[i % SLOTS.size()]:
		"LW": return f_lines[fi][0]
		"C": return f_lines[fi][1]
		"RW": return f_lines[fi][2]
		"LD": return d_pairs[di][0]
		_: return d_pairs[di][1]


func on_ice(on: Array) -> Array:
	return on.map(func(s): return s.player)


## Dressed players sitting on the bench right now (not on the ice, not
## hurt), for the venue to seat. The goalie isn't included.
func off_ice(on: Array) -> Array:
	var on_ids := on.map(func(s): return s.player.id if s.player else -1)
	var out: Array = []
	for l in f_lines + d_pairs:
		for p in l:
			if p and not hurt.has(p.id) and not on_ids.has(p.id) and not out.has(p):
				out.append(p)
	return out


## Player `p`'s body, made (and rested to their pre-game energy) the first
## time it's asked for.
func body(p: PlayerProfile) -> Skater:
	if not bodies.has(p.id):
		var s: Skater = make_body.call(p)
		s.apply_player(p)
		s.stamina = energy.get(p.id, 1.0)
		bodies[p.id] = s
	return bodies[p.id]


## The bodies the current lines put in slots 0..n-1.
func lineup_bodies(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(body(profile_for(i)))
	return out


## Advances shift clocks and rests the players on the bench; returns true
## when a line is called (Game then brings the bodies off and on).
## `stoppage`: play is dead (faceoff coming), so change if the shift is
## anywhere near done. `safe`: the puck isn't in our zone, so change on the fly.
func tick(dt: float, on: Array, stoppage: bool, safe: bool) -> bool:
	for pid in bodies:
		var s: Skater = bodies[pid]
		if not s in on:
			s.stamina = minf(1.0, s.stamina + BENCH_RECOVERY * dt)
	if not stoppage:
		f_time += dt
		d_time += dt
	var changed := false
	if _due(f_time, settings.shift_length("F"), stoppage, safe):
		fi = (fi + 1) % f_lines.size()
		f_time = 0.0
		changed = true
	if _due(d_time, settings.shift_length("D"), stoppage, safe):
		di = (di + 1) % d_pairs.size()
		d_time = 0.0
		changed = true
	return changed


func _due(t: float, shift: float, stoppage: bool, safe: bool) -> bool:
	if stoppage:
		return t > shift * 0.6
	return (safe and t > shift) or t > shift * 1.7


## A player got hurt: a spare of the same group takes their spot, or the
## next line's player double-shifts. Their body leaves at the next change.
func injure(p: PlayerProfile) -> void:
	hurt[p.id] = true
	var sub: PlayerProfile = null
	for s in spares:
		if s.group() == p.group():
			sub = s
			break
	if sub:
		spares.erase(sub)
		energy[sub.id] = 1.0
	for lines in [f_lines, d_pairs]:
		for li in lines.size():
			for slot in lines[li].size():
				if lines[li][slot] == p:
					var other_line: Array = lines[(li + 1) % lines.size()]
					lines[li][slot] = sub if sub else _healthy(other_line[slot], lines, slot)


func _healthy(candidate: PlayerProfile, lines: Array, slot: int) -> PlayerProfile:
	if candidate and not hurt.has(candidate.id):
		return candidate
	for l in lines:
		if l[slot] and not hurt.has(l[slot].id):
			return l[slot]
	return candidate
