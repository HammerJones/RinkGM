class_name Bench
extends RefCounted
## One team's bench during a game: three forward lines and two defence pairs
## rotate onto the five skater bodies on the ice. Forwards and defence change
## on their own shift clocks, at stoppages when they can, on the fly when the
## puck is out of their zone, and regardless once a shift drags on too long.
## Energy is kept per player, so a tired line comes back tired.
##
## The bodies (Skater nodes) stay on the ice; a change swaps which player
## (profile, skills, stamina) drives each body.

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
var energy := {}  # player id -> stamina 0..1
var hurt := {}  # player id -> true once injured in this game


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


func on_ice(bodies: Array) -> Array:
	return bodies.map(func(s): return s.profile)


## Puts the current lines on the bodies (start of game / after a goal).
func assign_all(bodies: Array) -> void:
	for i in bodies.size():
		_put(bodies[i], profile_for(i))


## Advances shift clocks; returns true if anyone changed.
## `stoppage`: play is dead (faceoff coming), so change if the shift is
## anywhere near done. `safe`: the puck isn't in our zone, so change on the fly.
func tick(dt: float, bodies: Array, stoppage: bool, safe: bool) -> bool:
	for pid in energy:
		if not _is_on(pid, bodies):
			energy[pid] = minf(1.0, energy[pid] + BENCH_RECOVERY * dt)
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
	if changed:
		for i in bodies.size():
			var want := profile_for(i)
			if bodies[i].profile != want:
				_put(bodies[i], want)
	return changed


func _due(t: float, shift: float, stoppage: bool, safe: bool) -> bool:
	if stoppage:
		return t > shift * 0.6
	return (safe and t > shift) or t > shift * 1.7


func _is_on(pid: int, bodies: Array) -> bool:
	for s in bodies:
		if s.profile and s.profile.id == pid:
			return true
	return false


func _put(body: Skater, p: PlayerProfile) -> void:
	if body.profile:
		energy[body.profile.id] = body.stamina
	body.apply_profile(p)
	body.stamina = energy.get(p.id, 1.0)


## A player got hurt: a spare of the same group takes their spot, or the
## top line double-shifts. Bodies they were driving get the replacement.
func injure(p: PlayerProfile, bodies: Array) -> void:
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
	for i in bodies.size():
		if bodies[i].profile == p:
			_put(bodies[i], profile_for(i))


func _healthy(candidate: PlayerProfile, lines: Array, slot: int) -> PlayerProfile:
	if candidate and not hurt.has(candidate.id):
		return candidate
	for l in lines:
		if l[slot] and not hurt.has(l[slot].id):
			return l[slot]
	return candidate
